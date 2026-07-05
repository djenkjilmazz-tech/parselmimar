import SwiftUI
import StoreKit

// MARK: - Plan Definition

private struct PlanDef: Identifiable {
    let id: String          // productID
    let title: String
    let period: String
    let badge: String?
    let badgeColor: Color
    let fallbackPrice: String
    let monthlyEquiv: String?
    let isSubscription: Bool
}

private let subscriptionPlans: [PlanDef] = [
    PlanDef(id: "com.parselmimar.pro.monthly",
            title: "Aylık Pro",
            period: "/ ay",
            badge: "1 Hafta Ücretsiz",
            badgeColor: .green,
            fallbackPrice: "₺249,99",
            monthlyEquiv: nil,
            isSubscription: true),
    PlanDef(id: "com.parselmimar.pro.yearly",
            title: "Yıllık Pro",
            period: "/ yıl",
            badge: "EN İYİ DEĞER",
            badgeColor: .orange,
            fallbackPrice: "₺1.999,99",
            monthlyEquiv: "≈ ₺166,67 / ay",
            isSubscription: true),
    PlanDef(id: "com.parselmimar.pro.lifetime",
            title: "Ömür Boyu",
            period: "tek seferlik",
            badge: "SINIRSIZ",
            badgeColor: .purple,
            fallbackPrice: "₺6.999,99",
            monthlyEquiv: nil,
            isSubscription: false),
]

// MARK: - PaywallView

struct PaywallView: View {
    @EnvironmentObject private var storeKit: StoreKitService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = "com.parselmimar.pro.yearly"
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    private func product(for id: String) -> Product? {
        storeKit.products.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // ── Hero Header ──
                    heroHeader

                    VStack(spacing: 20) {
                        // Feature grid
                        featureGrid

                        // Subscription plan cards
                        VStack(spacing: 10) {
                            ForEach(subscriptionPlans) { plan in
                                PlanCard(
                                    plan: plan,
                                    product: product(for: plan.id),
                                    isSelected: selectedID == plan.id
                                ) { selectedID = plan.id }
                            }
                        }

                        // Main CTA
                        purchaseCTA

                        // Single report divider
                        HStack {
                            Rectangle().fill(Color(.systemGray4)).frame(height: 0.5)
                            Text("veya tek proje için")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                                .padding(.horizontal, 8)
                            Rectangle().fill(Color(.systemGray4)).frame(height: 0.5)
                        }

                        // Single report card
                        singleReportCard

                        // Legal
                        legalFooter
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
            .alert("Hata", isPresented: $showError) {
                Button("Tamam") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.036, green: 0.082, blue: 0.251),
                    Color(red: 0.094, green: 0.220, blue: 0.588)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative circles
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 200)
                .offset(x: 130, y: -40)
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 150)
                .offset(x: -100, y: 50)

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.18))
                        .frame(width: 72, height: 72)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.yellow)
                }

                Text("Parsel Mimar Pro")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text("Tüm profesyonel özelliklerin kilidi açılsın")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 36)
        }
    }

    // MARK: - Feature Grid

    private let features: [(String, String)] = [
        ("infinity",                 "Sınırsız hesaplama"),
        ("doc.richtext.fill",        "Profesyonel PDF rapor"),
        ("cube.fill",                "3D PBR bina modeli"),
        ("map.fill",                 "TKGM parsel sorgulama"),
        ("floor.plans",              "PAİY kat planı"),
        ("square.and.arrow.up",      "KML / DXF / GeoJSON çıktı"),
        ("building.columns.fill",    "Ruhsat harç tahmini"),
        ("chart.bar.fill",           "Maliyet & optimizasyon"),
    ]

    private var featureGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(features, id: \.0) { icon, text in
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(.accent)
                        .frame(width: 20)
                    Text(text)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Main CTA

    private var purchaseCTA: some View {
        VStack(spacing: 10) {
            Button { purchase() } label: {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.subheadline)
                    }
                    Text(isPurchasing ? "İşleniyor…" : ctaLabel)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.094, green: 0.220, blue: 0.588),
                                 Color(red: 0.12, green: 0.30, blue: 0.75)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isPurchasing)

            Button("Satın alımları geri yükle") {
                Task { await storeKit.restorePurchases() }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var ctaLabel: String {
        guard let plan = subscriptionPlans.first(where: { $0.id == selectedID }) else {
            return "Satın Al"
        }
        let price = product(for: selectedID)?.displayPrice ?? plan.fallbackPrice
        if plan.isSubscription, let p = product(for: selectedID),
           p.subscription?.introductoryOffer != nil {
            return "1 Hafta Ücretsiz Dene"
        }
        return "\(plan.title) — \(price)"
    }

    // MARK: - Single Report Card

    private var singleReportCard: some View {
        let prod = product(for: "com.parselmimar.report.single")
        let price = prod?.displayPrice ?? "₺129,99"

        return Button {
            Task {
                guard let p = prod else { return }
                isPurchasing = true
                do {
                    _ = try await storeKit.purchase(p)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
                isPurchasing = false
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: "doc.badge.plus")
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tek Rapor")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("Bir proje için PDF rapor + parsel dışa aktarımı")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(price)
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
            }
            .padding(14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(prod == nil || isPurchasing)
    }

    // MARK: - Legal Footer

    private var legalFooter: some View {
        VStack(spacing: 6) {
            Text("Abonelik süresi dolmadan en az 24 saat önce iptal edilmezse otomatik olarak yenilenir. App Store > Ayarlar > Abonelikler bölümünden yönetebilirsiniz.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                NavigationLink("Kullanım Koşulları") { TermsOfUseView() }
                    .font(.caption2)
                NavigationLink("Gizlilik Politikası") { PrivacyPolicyView() }
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Purchase

    private func purchase() {
        guard let prod = product(for: selectedID) else { return }
        isPurchasing = true
        Task {
            do {
                let success = try await storeKit.purchase(prod)
                if success { dismiss() }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isPurchasing = false
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: PlanDef
    let product: Product?
    let isSelected: Bool
    let onTap: () -> Void

    var displayPrice: String { product?.displayPrice ?? plan.fallbackPrice }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .center, spacing: 14) {
                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.accentColor : Color(.systemGray3), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 12, height: 12)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(plan.title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let equiv = plan.monthlyEquiv {
                            Text(equiv)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if plan.isSubscription, product?.subscription?.introductoryOffer != nil {
                            Text("1 hafta ücretsiz")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(displayPrice)
                            .font(.title3.bold())
                            .foregroundStyle(isSelected ? .accent : .primary)
                        Text(plan.period)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .padding(.top, plan.badge != nil ? 10 : 0)
                .background(isSelected ? Color.accentColor.opacity(0.09) : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(
                            isSelected ? Color.accentColor
                            : (plan.badge != nil ? plan.badgeColor.opacity(0.45) : Color.clear),
                            lineWidth: isSelected ? 2 : 1.5
                        )
                )

                // Badge
                if let badge = plan.badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(plan.badgeColor)
                        .clipShape(Capsule())
                        .offset(x: -14, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Feature Row (kept for compatibility)

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.accent)
                .frame(width: 24)
            Text(text).font(.subheadline)
        }
    }
}

// MARK: - Plan Comparison Table (updated)

struct PlanComparisonTable: View {
    private let cols = ["Ücretsiz", "Aylık", "Yıllık", "Ömür B."]
    private let features: [(String, String, String, String, String)] = [
        ("Hesaplama",       "3 proje",  "∞",  "∞",  "∞"),
        ("PDF rapor",       "—",        "✓",  "✓",  "✓"),
        ("3D model",        "—",        "✓",  "✓",  "✓"),
        ("Kat planı",       "—",        "✓",  "✓",  "✓"),
        ("TKGM sorgulama",  "—",        "✓",  "✓",  "✓"),
        ("KML/DXF çıktı",  "—",        "✓",  "✓",  "✓"),
        ("Ruhsat harcı",    "—",        "✓",  "✓",  "✓"),
        ("Ömür boyu",       "—",        "—",  "—",  "✓"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Özellik").font(.caption.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(cols, id: \.self) { col in
                    Text(col).font(.caption.bold())
                        .foregroundStyle(col == "Yıllık" ? Color.orange : .primary)
                        .frame(width: 54, alignment: .center)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color(.systemGray5))

            ForEach(Array(features.enumerated()), id: \.offset) { i, row in
                HStack {
                    Text(row.0).font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    cell(row.1); cell(row.2); cell(row.3); cell(row.4)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(i.isMultiple(of: 2) ? Color(.systemGray6) : Color.clear)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 1))
    }

    @ViewBuilder
    private func cell(_ val: String) -> some View {
        Text(val).font(.caption)
            .foregroundStyle(val == "—" ? Color.secondary : (val == "∞" || val == "✓" ? Color.green : .primary))
            .frame(width: 54, alignment: .center)
    }
}
