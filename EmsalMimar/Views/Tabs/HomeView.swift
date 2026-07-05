import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeKit: StoreKitService
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]
    @State private var showNewProject = false
    @State private var showPaywall = false
    @State private var searchText = ""

    private var filteredProjects: [Project] {
        if searchText.isEmpty { return projects }
        return projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.il.localizedCaseInsensitiveContains(searchText) ||
            $0.ilce.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 0) {
                        heroHeader

                        // Ücretsiz kullanıcı: kalan hesaplama hakkı
                        if !storeKit.isPro {
                            Button { showPaywall = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: storeKit.canCalculate ? "chart.bar.fill" : "lock.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(storeKit.canCalculate ? .blue : .red)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(storeKit.canCalculate
                                             ? "Bugün \(storeKit.remainingFreeCalcs) hesaplama hakkı"
                                             : "Günlük limit doldu")
                                            .font(.caption.bold())
                                            .foregroundStyle(storeKit.canCalculate ? Color.primary : Color.red)
                                        Text(storeKit.canCalculate
                                             ? "Rapor ve dışa aktarım için Pro'ya geç"
                                             : "Yarın sıfırlanır · Pro ile sınırsız")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("Pro →")
                                        .font(.caption.bold())
                                        .foregroundStyle(.accent)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray6))
                            }
                            .buttonStyle(.plain)
                        }

                        if !projects.isEmpty {
                            statsRow
                                .padding(.horizontal)
                                .padding(.top, 20)

                            recentProjectsSection
                                .padding(.top, 8)
                        }

                        Color.clear.frame(height: 90)
                    }
                }
                .searchable(text: $searchText, prompt: "Proje ara...")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)

                // FAB
                Button {
                    showNewProject = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.title3.bold())
                        Text("Yeni Proje")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.indigo],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .blue.opacity(0.40), radius: 12, y: 6)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 32)
            }
            .sheet(isPresented: $showNewProject) {
                NewProjectView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView().environmentObject(storeKit)
            }
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.14, blue: 0.38),
                         Color(red: 0.12, green: 0.28, blue: 0.72)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            // Dekoratif arka plan şekilleri
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 220)
                .offset(x: 180, y: -30)

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 140)
                .offset(x: -40, y: 10)

            VStack(alignment: .leading, spacing: 6) {
                if projects.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "building.2.crop.circle.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.white.opacity(0.90))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Parsel Mimar")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("İmar · TAKS KAKS · 3D Yapı Modeli")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.70))
                        }
                    }
                    Text("İlk projenizi oluşturarak emsal hesabına başlayın.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.80))
                        .padding(.top, 4)

                    Button {
                        showNewProject = true
                    } label: {
                        Label("Proje Oluştur", systemImage: "plus.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 6)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "building.2.crop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.90))
                        Text("Parsel Mimar")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    Text("\(projects.count) aktif proje · Son güncelleme bugün")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .padding(.top, 16)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            MiniStatCard(
                icon: "folder.fill",
                value: "\(projects.count)",
                label: "Proje",
                color: .blue
            )
            MiniStatCard(
                icon: "calendar",
                value: "\(thisMonthCount)",
                label: "Bu Ay",
                color: .green
            )
            MiniStatCard(
                icon: "turkishlirasign.circle.fill",
                value: toplamBedelKompakt,
                label: "Toplam",
                color: .orange
            )
        }
    }

    private var toplamBedelKompakt: String {
        let total = projects.map(\.tahminiBedel).reduce(0, +)
        if total >= 1_000_000_000 { return String(format: "%.1f Mr", total / 1_000_000_000) }
        if total >= 1_000_000 { return String(format: "%.0f M", total / 1_000_000) }
        if total > 0 { return String(format: "%.0f K", total / 1_000) }
        return "—"
    }

    private var thisMonthCount: Int {
        let calendar = Calendar.current
        return projects.filter {
            calendar.isDate($0.createdAt, equalTo: Date(), toGranularity: .month)
        }.count
    }

    // MARK: - Projects

    private var recentProjectsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Projeler")
                    .font(.title3.bold())
                Spacer()
                Text("\(filteredProjects.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.bottom, 10)

            LazyVStack(spacing: 2) {
                ForEach(filteredProjects) { project in
                    NavigationLink(destination: ProjectDetailView(project: project)) {
                        ProjectCard(project: project)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(project)
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Mini Stat Card

private struct MiniStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Project Card

private struct ProjectCard: View {
    let project: Project

    private var accentColor: Color {
        switch project.kullanimTuru {
        case .konut:   return .blue
        case .ticaret: return .orange
        case .sanayi:  return .gray
        case .karma:   return .purple
        case .villa:   return .teal
        case .turizm:  return .pink
        case .saglik:  return .red
        case .egitim:  return .green
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sol renk çizgisi
            accentColor
                .frame(width: 4)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4, bottomLeadingRadius: 4,
                        bottomTrailingRadius: 0, topTrailingRadius: 0
                    )
                )

            HStack(spacing: 14) {
                // İkon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: project.kullanimTuru.icon)
                        .font(.title3)
                        .foregroundStyle(accentColor)
                }

                // İçerik
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name.isEmpty ? "İsimsiz Proje" : project.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if !project.il.isEmpty {
                            Label("\(project.il)/\(project.ilce)", systemImage: "mappin.circle")
                                .labelStyle(.titleAndIcon)
                        }
                        if !project.ada.isEmpty {
                            Text("Ada \(project.ada)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    if project.parselAlani > 0 {
                        HStack(spacing: 10) {
                            Tag(text: EmsalCalculator.formatAlan(project.parselAlani), color: accentColor)
                            Tag(text: "KAKS \(String(format: "%.2f", project.kaks))", color: .secondary)
                            Tag(text: "\(project.katSayisi) Kat", color: .secondary)
                        }
                    }
                }

                Spacer()

                // Sağ: bedel + chevron
                VStack(alignment: .trailing, spacing: 4) {
                    if project.tahminiBedel > 0 {
                        Text(compactBedel(project.tahminiBedel))
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .padding(.vertical, 3)
    }

    private func compactBedel(_ v: Double) -> String {
        if v >= 1_000_000_000 { return String(format: "%.1f Mr ₺", v / 1_000_000_000) }
        if v >= 1_000_000     { return String(format: "%.0f M ₺", v / 1_000_000) }
        return EmsalCalculator.formatPara(v)
    }
}

// MARK: - Tag

private struct Tag: View {
    let text: String
    let color: Color

    init(text: String, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color == .secondary ? Color.secondary : color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((color == .secondary ? Color.secondary : color).opacity(0.10))
            .clipShape(Capsule())
    }
}
