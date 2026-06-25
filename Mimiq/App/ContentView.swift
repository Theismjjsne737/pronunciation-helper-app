import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showSplash = true
    @State private var selectedTab = 0

    private let tabs: [(label: String, icon: String, selectedIcon: String)] = [
        ("Coach",    "waveform",            "waveform"),
        ("Practice", "mic.circle",          "mic.circle.fill"),
        ("Progress", "chart.bar",           "chart.bar.fill"),
        ("Share",    "square.and.arrow.up", "square.and.arrow.up.fill"),
        ("Settings", "gearshape",           "gearshape.fill"),
    ]

    private let bg     = Color(red: 0.06, green: 0.06, blue: 0.10)
    private let violet = Color(red: 0.53, green: 0.39, blue: 0.98)
    private let muted  = Color(red: 0.55, green: 0.53, blue: 0.65)

    var body: some View {
        ZStack {
            if showSplash {
                SplashView { showSplash = false }
                    .transition(.opacity)
                    .zIndex(1)
            } else {
                TabView(selection: $selectedTab) {
                    CoachView()        .tag(0)
                    PracticeView()     .tag(1)
                    AccentProfileView().tag(2)
                    ShareTabView()     .tag(3)
                    SettingsView()     .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .safeAreaInset(edge: .bottom, spacing: 0) { customTabBar }
                .transition(.opacity)
                .zIndex(0)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplash)
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = i
                    }
                } label: {
                    Image(systemName: selectedTab == i ? tabs[i].selectedIcon : tabs[i].icon)
                        .font(.system(size: 26, weight: selectedTab == i ? .semibold : .regular))
                        .foregroundStyle(selectedTab == i ? violet : muted)
                        .scaleEffect(x: i == 2 ? 0.65 : 1.0, y: 1.0)
                        .scaleEffect(selectedTab == i ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 24)
        .background(
            bg.opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1),
            alignment: .top
        )
    }
}
