import SwiftUI

@main
struct NizarScanApp: App {
    @StateObject private var library = DocumentLibrary()
    var body: some Scene {
        WindowGroup {
            MainView().environmentObject(library)
                .preferredColorScheme(.light)
        }
    }
}
