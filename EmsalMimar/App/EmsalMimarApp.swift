import SwiftUI
import SwiftData

@main
struct EmsalMimarApp: App {
    @StateObject private var storeKit = StoreKitService.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Project.self,
            ParselData.self,
            EmsalReport.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            if let dir = dir {
                let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
                files.filter { f in
                    let n = f.lastPathComponent
                    return n.hasSuffix(".store") || n.contains(".sqlite")
                }.forEach { try? FileManager.default.removeItem(at: $0) }
            }
            guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
                fatalError("ModelContainer oluşturulamadı")
            }
            return container
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storeKit)
                .onAppear { AppRatingService.shared.registerSession() }
                .fullScreenCover(isPresented: .constant(!hasSeenOnboarding)) {
                    OnboardingView()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
