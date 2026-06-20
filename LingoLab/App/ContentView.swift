import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        if authViewModel.isAuthenticated {
            TabView {
                CoachView()
                    .tabItem { Label("Coach", systemImage: "waveform.and.person.filled") }

                PracticeView()
                    .tabItem { Label("Practice", systemImage: "mic.circle.fill") }

                AccentProfileView()
                    .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            }
            .tint(.indigo)
        } else {
            SignInView()
        }
    }
}
