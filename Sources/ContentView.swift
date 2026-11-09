import SwiftUI

struct ContentView: View {
    @EnvironmentObject var ble: BLEManager
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "car.side.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(.blue)
                Text("BMW E39 Phone Key").font(.title2.bold())
                Text("Bluetooth deneme surumu • Kapi kilidi kontrol etmez")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                GroupBox("ESP32 Baglantisi") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(ble.deviceName, systemImage: "antenna.radiowaves.left.and.right")
                        Text(ble.status).font(.callout)
                        Text("Durum: \(ble.connected ? "Bagli" : "Bagli degil")")
                        Text("RSSI: \(ble.rssi)")
                        Text("Son yanit: \(ble.lastMessage)")
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Button("Bluetooth cihazini ara") { ble.scan() }
                    .buttonStyle(.bordered)
                HStack {
                    Button("PING") { ble.send("PING") }
                    Button("STATUS") { ble.send("STATUS") }
                }.buttonStyle(.borderedProminent)
                HStack {
                    Button("LED ON") { ble.send("LED_ON") }
                    Button("LED OFF") { ble.send("LED_OFF") }
                }.buttonStyle(.bordered)
                Text("Telefon kilitliyken baglanti geri gelmesini test edecegiz. RSSI ile arac kilidi acilmaz.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }.padding()
                .navigationTitle("Phone Key")
        }
    }
}
