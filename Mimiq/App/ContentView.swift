import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    showSplash = false
                }
                .transition(.opacity)
                .zIndex(1)
            } else {
                TabView {
                    CoachView()
                        .tabItem { Label("Coach", systemImage: "waveform.and.person.filled") }

                    PracticeView()
                        .tabItem { Label("Practice", systemImage: "mic.circle.fill") }

                    AccentProfileView()
                        .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

                    ShareTabView()
                        .tabItem { Label("Share", systemImage: "square.and.arrow.up") }

                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                }
                .tint(.indigo)
                .transition(.opacity)
                .zIndex(0)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplash)
    }
}
