import SwiftUI

@main
struct BMWPhoneKeyApp: App {
    @StateObject private var ble = BLEManager()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(ble) }
    }
}
