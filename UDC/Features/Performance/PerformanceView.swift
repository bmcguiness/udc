import SwiftUI

struct PerformanceView: View {
    let tests = ["0–30 mph", "0–40 mph", "0–60 mph", "Eighth mile", "Quarter mile"]
    var body: some View { NavigationStack { ScrollView { LazyVGrid(columns: [.init(.adaptive(minimum: 150))], spacing: AppSpacing.medium) { ForEach(tests, id: \.self) { test in AppCard { Label(test, systemImage: "stopwatch").font(.headline); Text("Coming later").font(.caption).foregroundStyle(.secondary).padding(.top, 4) } } }.padding() }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Performance") } }
}
