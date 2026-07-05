import SwiftUI

// MARK: - Onboarding Model

struct OnboardingPage {
    let icon: String
    let accent: Color
    let title: String
    let subtitle: String
    let detail: String
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        icon: "building.2.fill",
        accent: Color(red: 0.12, green: 0.30, blue: 0.75),
        title: "Parsel Mimar'a\nHoş Geldiniz",
        subtitle: "Profesyonel Emsal Hesabı",
        detail: "Mimarlar ve inşaat mühendisleri için PAİY uyumlu emsal hesap, 3D model ve raporlama uygulaması."
    ),
    OnboardingPage(
        icon: "map.fill",
        accent: .green,
        title: "Haritadan\nParsel Seç",
        subtitle: "TKGM Entegrasyonu",
        detail: "Haritada parsele dokun — ada, parsel, ilçe ve alan bilgileri TKGM'den otomatik gelir."
    ),
    OnboardingPage(
        icon: "function",
        accent: .orange,
        title: "Anlık Emsal\nHesabı",
        subtitle: "PAİY Uyumlu",
        detail: "TAKS, KAKS ve Hmax kısıtları otomatik uygulanır. Emsal dışı kalemler, otopark ve birim sayıları hesaplanır."
    ),
    OnboardingPage(
        icon: "cube.fill",
        accent: .purple,
        title: "3D Bina Modeli",
        subtitle: "SolidWorks Kalitesinde",
        detail: "PBR malzeme ve gerçekçi aydınlatmayla bina kütlesini anlık 3D olarak görüntüle, döndür, incele."
    ),
    OnboardingPage(
        icon: "doc.richtext.fill",
        accent: .red,
        title: "PDF Rapor &\nDışa Aktarım",
        subtitle: "Profesyonel Çıktı",
        detail: "Belediye harç tahmini dahil profesyonel PDF rapor oluştur. KML, DXF ve GeoJSON formatlarında dışa aktar."
    ),
]

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var animate = false

    var body: some View {
        ZStack {
            pages[currentPage].accent
                .opacity(0.07)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: currentPage)

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Atla") {
                            withAnimation(.spring(response: 0.4)) { hasSeenOnboarding = true }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    } else {
                        Color.clear.frame(height: 44).padding(.top, 16)
                    }
                }

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        OBPageCard(page: pages[i], animate: animate && currentPage == i)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom controls
                VStack(spacing: 20) {
                    // Progress dots
                    HStack(spacing: 7) {
                        ForEach(pages.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage
                                      ? pages[currentPage].accent
                                      : Color.secondary.opacity(0.22))
                                .frame(width: i == currentPage ? 26 : 8, height: 8)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                        }
                    }

                    // Action button
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.4)) { currentPage += 1 }
                        } else {
                            withAnimation(.spring(response: 0.4)) { hasSeenOnboarding = true }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentPage < pages.count - 1 ? "İleri" : "Başla")
                                .font(.headline)
                            Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(pages[currentPage].accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .animation(.easeInOut(duration: 0.25), value: currentPage)
                    }
                    .padding(.horizontal, 28)

                    // Legal line on last page
                    if currentPage == pages.count - 1 {
                        OBLegalLine()
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { animate = true }
        }
        .onChange(of: currentPage) { _, _ in
            animate = false
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.08)) { animate = true }
        }
    }
}

// MARK: - Page Card

private struct OBPageCard: View {
    let page: OnboardingPage
    let animate: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated icon stack
            ZStack {
                Circle()
                    .stroke(page.accent.opacity(0.20), lineWidth: 1.5)
                    .frame(width: 196, height: 196)
                    .scaleEffect(animate ? 1.0 : 0.55)
                    .opacity(animate ? 1 : 0)

                Circle()
                    .fill(page.accent.opacity(0.12))
                    .frame(width: 164, height: 164)
                    .scaleEffect(animate ? 1.0 : 0.5)
                    .opacity(animate ? 1 : 0)

                Image(systemName: page.icon)
                    .font(.system(size: 70, weight: .medium))
                    .foregroundStyle(page.accent)
                    .scaleEffect(animate ? 1.0 : 0.35)
                    .opacity(animate ? 1 : 0)
                    .symbolEffect(.pulse, options: .repeating, value: animate)
            }
            .animation(.spring(response: 0.58, dampingFraction: 0.66), value: animate)

            Spacer().frame(height: 40)

            // Subtitle chip
            Text(page.subtitle.uppercased())
                .font(.caption.bold())
                .tracking(1.4)
                .foregroundStyle(page.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(page.accent.opacity(0.11))
                .clipShape(Capsule())
                .offset(y: animate ? 0 : 18)
                .opacity(animate ? 1 : 0)
                .animation(.easeOut(duration: 0.42).delay(0.10), value: animate)

            Spacer().frame(height: 16)

            Text(page.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .offset(y: animate ? 0 : 22)
                .opacity(animate ? 1 : 0)
                .animation(.easeOut(duration: 0.42).delay(0.17), value: animate)

            Spacer().frame(height: 14)

            Text(page.detail)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 34)
                .offset(y: animate ? 0 : 22)
                .opacity(animate ? 1 : 0)
                .animation(.easeOut(duration: 0.42).delay(0.25), value: animate)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Legal Line

private struct OBLegalLine: View {
    @State private var showPrivacy = false
    @State private var showTerms = false

    var body: some View {
        VStack(spacing: 2) {
            Text("Başla'ya basarak")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Button("Kullanım Koşulları") { showTerms = true }
                    .font(.caption2)
                Text("ve")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Gizlilik Politikası") { showPrivacy = true }
                    .font(.caption2)
            }
            Text("kabul etmiş sayılırsınız.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showTerms) {
            NavigationStack { TermsOfUseView() }
        }
        .sheet(isPresented: $showPrivacy) {
            NavigationStack { PrivacyPolicyView() }
        }
    }
}
