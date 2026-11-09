import Foundation
import CoreBluetooth
import Combine
import CryptoKit
import Security

final class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var status = "Bluetooth baslatiliyor"
    @Published var deviceName = "Cihaz araniyor"
    @Published var connected = false
    @Published var authenticated = false
    @Published var lastMessage = "-"
    @Published var rssi = "-"
    @Published var hasKey = false

    private let serviceID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let rxID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    private let storedPeripheral = "BMWPhoneKeyPeripheralID"
    private let keyAccount = "phone-key-secret-v1"
    private let keyService = "com.bmwe39.test.phonekey"
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rx: CBCharacteristic?
    private var tx: CBCharacteristic?
    private var pendingAuthSecondHalf: String?

    override init() {
        super.init()
        hasKey = loadKey() != nil
        central = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionRestoreIdentifierKey: "BMWPhoneKeyCentralRestore"
        ])
    }

    // 32 rastgele bayt = 64 hex karakter. Kullanici bunu sadece kendi telefonuna girer.
    func saveKey(_ hex: String) -> Bool {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleaned.count == 64, Data(hexString: cleaned)?.count == 32 else {
            status = "Anahtar 64 hexadecimal karakter olmali"
            return false
        }
        guard let data = Data(hexString: cleaned) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyService,
            kSecAttrAccount as String: keyAccount
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let result = SecItemAdd(add as CFDictionary, nil)
        hasKey = result == errSecSuccess
        status = hasKey ? "Anahtar telefona kaydedildi" : "Anahtar kaydedilemedi: \(result)"
        if hasKey && connected { beginAuthentication() }
        return hasKey
    }

    private func loadKey() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyService,
            kSecAttrAccount as String: keyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            status = "Bluetooth hazir degil"
            connected = false
            authenticated = false
            return
        }
        reconnectOrScan()
    }

    private func reconnectOrScan() {
        guard central.state == .poweredOn else { return }
        if let device = peripheral {
            if device.state == .connected { return }
            connect(device)
            return
        }
        if let stored = UserDefaults.standard.string(forKey: storedPeripheral),
           let id = UUID(uuidString: stored),
           let found = central.retrievePeripherals(withIdentifiers: [id]).first {
            connect(found)
        } else {
            scan()
        }
    }

    func scan() {
        guard central.state == .poweredOn else { return }
        status = "BMW ESP32 araniyor"
        central.scanForPeripherals(withServices: [serviceID], options: nil)
    }

    private func connect(_ device: CBPeripheral) {
        guard central.state == .poweredOn else { return }
        guard device.state == .disconnected else { return }
        peripheral = device
        device.delegate = self
        deviceName = device.name ?? "BMW_E39_PHONE_KEY"
        status = "Baglanti bekleniyor"
        central.stopScan()
        central.connect(device, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
    }

    func centralManager(_ central: CBCentralManager, didDiscover device: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if let name = device.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String,
           !name.hasPrefix("BMW_E39_PHONE_KEY") { return }
        rssi = "\(RSSI) dBm"
        connect(device)
    }

    func centralManager(_ central: CBCentralManager, didConnect device: CBPeripheral) {
        peripheral = device
        device.delegate = self
        connected = true
        authenticated = false
        status = "Baglandi - servis araniyor"
        UserDefaults.standard.set(device.identifier.uuidString, forKey: storedPeripheral)
        device.discoverServices([serviceID])
        device.readRSSI()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect device: CBPeripheral, error: Error?) {
        connected = false
        authenticated = false
        pendingAuthSecondHalf = nil
        rx = nil
        tx = nil
        status = "Baglanti basarisiz"
        reconnectOrScan()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral device: CBPeripheral, error: Error?) {
        connected = false
        authenticated = false
        pendingAuthSecondHalf = nil
        rx = nil
        tx = nil
        status = "Baglanti kesildi; yeniden baglaniyor"
        reconnectOrScan()
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let devices = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
              let device = devices.first else { return }
        peripheral = device
        device.delegate = self
        deviceName = device.name ?? "BMW_E39_PHONE_KEY"
        if device.state == .connected {
            connected = true
            authenticated = false
            device.discoverServices([serviceID])
        } else {
            status = "Bluetooth baglantisi geri yukleniyor"
            reconnectOrScan()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { status = "Servis hatasi"; return }
        for service in peripheral.services ?? [] where service.uuid == serviceID {
            peripheral.discoverCharacteristics([rxID, txID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { status = "Karakteristik hatasi"; return }
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == rxID { rx = characteristic }
            if characteristic.uuid == txID {
                tx = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        if rx != nil && tx != nil && tx?.isNotifying == true {
            beginAuthentication()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil && characteristic.uuid == txID && characteristic.isNotifying && rx != nil {
            beginAuthentication()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == txID,
              let data = characteristic.value,
              let message = String(data: data, encoding: .utf8) else { return }
        lastMessage = message
        if message.hasPrefix("C:") {
            respondToChallenge(String(message.dropFirst(2)))
        } else if message == "AUTH_OK" {
            authenticated = true
            status = "Telefon dogrulandi (test modu)"
        } else if message == "AUTH_FAIL" {
            authenticated = false
            status = "Kimlik dogrulamasi basarisiz"
        }
    }

    private func beginAuthentication() {
        authenticated = false
        guard hasKey else { status = "Once 64 karakterli gizli anahtari gir"; return }
        status = "Kimlik dogrulamasi bekleniyor"
        sendRaw("HELLO")
    }

    private func respondToChallenge(_ nonceHex: String) {
        guard let key = loadKey(), key.count == 32,
              let nonce = Data(hexString: nonceHex), nonce.count == 8 else {
            status = "Gecersiz challenge veya anahtar"
            return
        }
        // Must match ESP32: HMAC-SHA256(key, ASCII("BMWKEY1:") || raw_nonce)
        let payload = Data("BMWKEY1:".utf8) + nonce
        let mac = HMAC<SHA256>.authenticationCode(for: payload, using: SymmetricKey(data: key))
        let first16 = Data(mac.prefix(16)).map { String(format: "%02x", $0) }.joined()
        // BLE default 20-byte ATT payload limit: split 32 hex chars into two 16-char writes.
        // Wait for the acknowledged write before sending the second chunk.
        pendingAuthSecondHalf = "A1:" + String(first16.suffix(16))
        sendRaw("A0:" + String(first16.prefix(16)))
        status = "Dogrulama yaniti gonderiliyor"
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == rxID else { return }
        if let error = error {
            pendingAuthSecondHalf = nil
            status = "Bluetooth yazma hatasi: \(error.localizedDescription)"
            return
        }
        if let second = pendingAuthSecondHalf {
            pendingAuthSecondHalf = nil
            sendRaw(second)
        }
    }

    private func sendRaw(_ command: String) {
        guard let device = peripheral, device.state == .connected, let characteristic = rx,
              let data = command.data(using: .utf8) else { return }
        let type: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        device.writeValue(data, for: characteristic, type: type)
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if error == nil { rssi = "\(RSSI) dBm" }
    }

    func send(_ command: String) {
        guard connected else { status = "Bagli degil"; return }
        sendRaw(command)
        peripheral?.readRSSI()
    }
}

private extension Data {
    init?(hexString: String) {
        guard hexString.count.isMultiple(of: 2) else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hexString.count / 2)
        var i = hexString.startIndex
        while i < hexString.endIndex {
            let j = hexString.index(i, offsetBy: 2)
            guard let b = UInt8(hexString[i..<j], radix: 16) else { return nil }
            bytes.append(b)
            i = j
        }
        self.init(bytes)
    }
}
