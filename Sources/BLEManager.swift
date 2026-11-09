import Foundation
import CoreBluetooth

final class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var status = "Bluetooth baslatiliyor"
    @Published var deviceName = "Cihaz aranıyor"
    @Published var connected = false
    @Published var lastMessage = "-"
    @Published var rssi = "-"

    private let serviceID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let rxID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    private let storedKey = "BMWPhoneKeyPeripheralID"
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rx: CBCharacteristic?
    private var tx: CBCharacteristic?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionRestoreIdentifierKey: "BMWPhoneKeyCentralRestore"
        ])
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            status = "Bluetooth hazir degil: \(central.state.rawValue)"
            connected = false
            return
        }
        reconnectOrScan()
    }

    private func reconnectOrScan() {
        guard central.state == .poweredOn else { return }
        if let peripheral = peripheral {
            connect(peripheral)
            return
        }
        if let stored = UserDefaults.standard.string(forKey: storedKey),
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
        peripheral = device
        device.delegate = self
        deviceName = device.name ?? "BMW_E39_PHONE_KEY"
        status = "Baglanti bekleniyor"
        central.stopScan()
        // Outstanding connection request may continue while app is suspended.
        central.connect(device, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
    }

    func centralManager(_ central: CBCentralManager, didDiscover device: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Service UUID is the filter; name is an additional sanity check when present.
        if let name = device.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String,
           !name.hasPrefix("BMW_E39_PHONE_KEY") { return }
        rssi = "\(RSSI) dBm"
        connect(device)
    }

    func centralManager(_ central: CBCentralManager, didConnect device: CBPeripheral) {
        peripheral = device
        device.delegate = self
        connected = true
        status = "Baglandi – karakteristikler araniyor"
        UserDefaults.standard.set(device.identifier.uuidString, forKey: storedKey)
        device.discoverServices([serviceID])
        device.readRSSI()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect device: CBPeripheral, error: Error?) {
        connected = false
        rx = nil
        tx = nil
        status = "Baglanamadi: \(error?.localizedDescription ?? "bilinmeyen")"
        // Keep a pending request to the known BLE device.
        reconnectOrScan()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral device: CBPeripheral, error: Error?) {
        connected = false
        rx = nil
        tx = nil
        status = "Baglanti kesildi – yeniden baglanma bekleniyor"
        reconnectOrScan()
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        if let devices = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let device = devices.first {
            peripheral = device
            device.delegate = self
            deviceName = device.name ?? "BMW_E39_PHONE_KEY"
            if device.state == .connected {
                connected = true
                status = "Bluetooth durumu geri yuklendi"
                device.discoverServices([serviceID])
            } else {
                status = "Bluetooth baglantisi geri yukleniyor"
            }
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
        if rx != nil {
            status = "Hazir – test komutlari gonderilebilir"
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == txID,
              let data = characteristic.value else { return }
        lastMessage = String(data: data, encoding: .utf8) ?? "Okunamayan veri"
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if error == nil { rssi = "\(RSSI) dBm" }
    }

    func send(_ command: String) {
        guard let device = peripheral, device.state == .connected, let characteristic = rx else {
            status = "Komut gonderilemedi: bagli degil"
            return
        }
        guard let data = command.data(using: .utf8) else { return }
        let type: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        device.writeValue(data, for: characteristic, type: type)
        status = "Gonderildi: \(command)"
        device.readRSSI()
    }
}
