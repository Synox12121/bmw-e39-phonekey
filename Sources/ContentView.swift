import SwiftUI

struct ContentView: View {
    @EnvironmentObject var ble: BLEManager
    @State private var secret = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue)
                    Text("BMW E39 Phone Key").font(.title2.bold())
                    Text("Kimlik dogrulama testi - ARAC KILIDI KONTROL ETMEZ")
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    GroupBox("Bluetooth") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(ble.deviceName)
                            Text("Baglanti: \(ble.connected ? "Bagli" : "Bagli degil")")
                            Text("Dogrulama: \(ble.authenticated ? "BASARILI" : "Bekleniyor")")
                            Text("Durum: \(ble.status)")
                            Text("RSSI: \(ble.rssi)")
                            Text("Son mesaj: \(ble.lastMessage)")
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GroupBox("Tek telefona ozel gizli anahtar") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(ble.hasKey ? "Anahtar Keychain'de kayitli" : "ESP32 Seri Monitor'deki 64 haneli anahtari gir")
                                .font(.footnote)
                            SecureField("64 karakter HEX anahtar", text: $secret)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Button("Anahtari telefona kaydet") {
                                if ble.saveKey(secret) { secret = "" }
                            }
                            .buttonStyle(.borderedProminent)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button("Bluetooth cihazini ara") { ble.scan() }
                        .buttonStyle(.bordered)
                    HStack {
                        Button("PING") { ble.send("PING") }
                        Button("STATUS") { ble.send("STATUS") }
                    }.buttonStyle(.bordered)
                    Text("Bu deneyde sadece Bluetooth dogrulamasi yapilir. RSSI ve HMAC, tek basina guvenli arac yaklasma ispatı degildir.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding()
            }
            .navigationTitle("Phone Key")
        }
    }
}
