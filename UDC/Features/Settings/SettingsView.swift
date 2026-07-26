import SwiftUI

struct SettingsView: View {
    var body: some View { List { Section("Preferences") { Label("Units", systemImage: "ruler"); Label("Appearance", systemImage: "circle.lefthalf.filled") }; Section("Connections") { Label("OBD-II adapters", systemImage: "cable.connector") }; Section("Privacy") { Label("Data and privacy", systemImage: "hand.raised"); Text("UDC is intended to keep driving data on your device unless you explicitly enable a future sharing or cloud feature.").font(.footnote).foregroundStyle(.secondary) }; Section("About") { Label("About UDC", systemImage: "info.circle") } }.navigationTitle("Settings") }
}
