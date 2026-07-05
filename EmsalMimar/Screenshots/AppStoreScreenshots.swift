#if DEBUG
// MARK: - App Store Screenshot Generator
// Preview → canvas'ta sahne seçici ile gez → Option+tıkla → "Save Preview" → PNG
// Gerekli boyut: 6.7" → 1290×2796 px   (Preview device: iPhone 15 Pro Max)
//                6.5" → 1242×2688 px   (iPhone 11 Pro Max)
// Bu dosya Release build'a dahil edilmez (#if DEBUG).

import SwiftUI

// MARK: - Brand
private extension Color {
    static let ssNavy  = Color(red: 0.036, green: 0.082, blue: 0.251)
    static let ssBrand = Color(red: 0.094, green: 0.220, blue: 0.588)
    static let ssLight = Color(red: 0.22,  green: 0.42,  blue: 0.88)
    static let ssGold  = Color(red: 1.0,   green: 0.80,  blue: 0.18)
}

// MARK: - Copy (headline, subtitle)
private typealias Copy = (h: String, s: String)

private struct Locale10n {
    let isRTL: Bool
    let map:    Copy
    let calc:   Copy
    let model:  Copy
    let report: Copy
    let pro:    Copy
}

private let tr = Locale10n(isRTL: false,
    map:    ("Parseli\nSaniyede Bul",          "TKGM haritasından tek dokunuşla"),
    calc:   ("PAİY Uyumlu\nEmsal Hesabı",      "TAKS · KAKS · Hmax otomatik"),
    model:  ("Anında\n3D Bina Kütlesi",        "PBR malzeme · gerçekçi aydınlatma"),
    report: ("Profesyonel\nPDF Rapor",          "Ruhsat harç tahmini dahil"),
    pro:    ("Pro ile\nSınırları Aş",           "Sınırsız proje · KML · DXF · PDF")
)

private let en = Locale10n(isRTL: false,
    map:    ("Find Any Parcel\nInstantly",      "One tap on the TKGM map"),
    calc:   ("PAİY-Compliant\nFAR Calculation", "TAKS · KAKS · Hmax automated"),
    model:  ("Instant\n3D Building Mass",       "PBR materials · real-time lighting"),
    report: ("Professional\nPDF Report",         "Includes permit fee estimate"),
    pro:    ("Unlock\nPro Features",            "Unlimited projects · KML · DXF · PDF")
)

private let fa = Locale10n(isRTL: true,
    map:    ("قطعه را\nفوری پیدا کنید",         "با یک لمس روی نقشه TKGM"),
    calc:   ("محاسبه دقیق\nضریب اشغال زمین",   "TAKS · KAKS · Hmax خودکار"),
    model:  ("مدل سه‌بعدی\nآنی ساختمان",       "متریال PBR و نورپردازی واقعی"),
    report: ("گزارش\nحرفه‌ای PDF",              "شامل تخمین هزینه مجوز"),
    pro:    ("ویژگی‌های حرفه‌ای\nرا باز کنید",  "پروژه نامحدود · خروجی KML · DXF")
)

private let ar = Locale10n(isRTL: true,
    map:    ("ابحث عن أي\nقطعة فوراً",         "بلمسة واحدة على خريطة TKGM"),
    calc:   ("حساب نسبة البناء\nبدقة عالية",   "TAKS · KAKS · Hmax تلقائياً"),
    model:  ("نموذج ثلاثي\nالأبعاد فوري",      "مواد PBR وإضاءة في الوقت الفعلي"),
    report: ("تقرير PDF\nاحترافي",              "يشمل تقدير رسوم التصاريح"),
    pro:    ("افتح الميزات\nالمتقدمة",         "مشاريع غير محدودة · KML · DXF")
)

private let de = Locale10n(isRTL: false,
    map:    ("Flurstück\nsofort finden",        "Ein Tippen auf der TKGM-Karte"),
    calc:   ("GFZ-Berechnung\nnach Vorschrift", "TAKS · KAKS · Hmax automatisch"),
    model:  ("Sofortiges\n3D-Gebäudemodell",    "PBR-Materialien · Echtzeit-Licht"),
    report: ("Professioneller\nPDF-Bericht",     "Mit Baugenehmigungsgebühr-Schätzung"),
    pro:    ("Pro-Funktionen\nfreischalten",     "Unbegrenzte Projekte · KML · DXF")
)

private let allLocales: [(String, Locale10n)] = [
    ("🇹🇷 Türkçe", tr), ("🇺🇸 English", en),
    ("🇮🇷 فارسی", fa),  ("🇸🇦 العربية", ar), ("🇩🇪 Deutsch", de)
]

// MARK: - Scene enum
private enum Scene: String, CaseIterable, Identifiable {
    case map    = "Harita"
    case calc   = "Hesaplama"
    case model  = "3D Model"
    case report = "PDF Rapor"
    case pro    = "Pro"
    var id: String { rawValue }

    func copy(from l: Locale10n) -> Copy {
        switch self {
        case .map:    return l.map
        case .calc:   return l.calc
        case .model:  return l.model
        case .report: return l.report
        case .pro:    return l.pro
        }
    }
}

// MARK: - Screenshot Wrapper (390×844 pt)

private struct AppStoreShot: View {
    let copy: Copy
    let isRTL: Bool
    let scene: Scene

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.ssNavy, .ssBrand, Color(red:0.05, green:0.15, blue:0.42), .ssNavy],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // Decorative bokeh
            Circle().fill(Color.ssLight.opacity(0.08)).frame(width: 280).offset(x: 140, y: -260)
            Circle().fill(Color.ssGold.opacity(0.05)).frame(width: 180).offset(x: -100, y: 260)

            VStack(spacing: 0) {
                // App mock (floating, no device chrome — modern style)
                mockView
                    .frame(width: 268, height: 488)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .shadow(color: .black.opacity(0.55), radius: 36, y: 18)
                    .overlay(RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.white.opacity(0.13), lineWidth: 1))
                    .padding(.top, 48)

                Spacer()

                // Marketing text
                VStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
                    // Gold accent line
                    Capsule()
                        .fill(Color.ssGold)
                        .frame(width: 36, height: 3)
                        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)

                    Text(copy.h)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineSpacing(3)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)

                    Text(copy.s)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(isRTL ? .trailing : .leading)

                    // App badge
                    HStack(spacing: 5) {
                        Image(systemName: "building.2.fill").font(.caption2)
                        Text("Parsel Mimar").font(.caption.bold())
                    }
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 11).padding(.vertical, 5)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                .padding(.horizontal, 30)
                .padding(.bottom, 52)
            }
        }
        .frame(width: 390, height: 844)
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder private var mockView: some View {
        switch scene {
        case .map:    MapMockScreen()
        case .calc:   CalcMockScreen()
        case .model:  Model3DMockScreen()
        case .report: PDFMockScreen()
        case .pro:    ProMockScreen()
        }
    }
}

// MARK: - Scene 1: Map

private struct MapMockScreen: View {
    private struct Block: Identifiable {
        let id: Int; let x, y, w, h: CGFloat
    }
    private let blocks = [
        Block(id: 0, x: 44, y: 82,  w: 62, h: 68),
        Block(id: 1, x: 44, y: 180, w: 58, h: 52),
        Block(id: 2, x: 180, y: 68, w: 76, h: 88),
        Block(id: 3, x: 250, y: 190, w: 66, h: 58),
        Block(id: 4, x: 130, y: 310, w: 88, h: 76),
        Block(id: 5, x: 48, y: 326, w: 58, h: 62),
        Block(id: 6, x: 252, y: 320, w: 72, h: 68),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.94, green: 0.91, blue: 0.86)

            // Road grid (white lines)
            Canvas { ctx, size in
                let lineW: CGFloat = 9
                for x in [0, size.width*0.38, size.width*0.72] {
                    var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                    ctx.stroke(p, with: .color(.white), lineWidth: lineW)
                }
                for y in [0, size.height*0.30, size.height*0.58, size.height*0.82] {
                    var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(p, with: .color(.white), lineWidth: lineW)
                }
            }

            // Building blocks
            ForEach(blocks) { b in
                Rectangle().fill(Color(white: 0.70))
                    .frame(width: b.w, height: b.h)
                    .position(x: b.x, y: b.y)
            }

            // Highlighted parcel
            Rectangle()
                .fill(Color.orange.opacity(0.22))
                .overlay(Rectangle().stroke(Color.orange, lineWidth: 2.5))
                .frame(width: 52, height: 46)
                .position(x: 155, y: 258)

            // Pin
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.red)
                .shadow(radius: 3)
                .position(x: 155, y: 236)

            // Info card
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ada 389 · Parsel 26").font(.caption.bold())
                    Text("Kadıköy, İstanbul · 350 m²").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Label("Getir", systemImage: "arrow.down.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.ssBrand)
                    .clipShape(Capsule())
            }
            .padding(12)
            .background(.regularMaterial)
            .padding(8)
        }
        .background(Color(red: 0.94, green: 0.91, blue: 0.86))
    }
}

// MARK: - Scene 2: Calculation

private struct CalcMockScreen: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                // Parcel chip
                HStack {
                    Label("Ada 389 / Parsel 26", systemImage: "mappin.circle.fill")
                        .font(.caption.bold())
                    Spacer()
                    Label("Kadıköy", systemImage: "location.fill")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 9))

                // İmar bilgileri
                sectionHeader("İMAR BİLGİLERİ")
                resultCard {
                    calcRow("Parsel Alanı", "350 m²", .primary, false)
                    Divider()
                    calcRow("TAKS",         "%40",     .blue,    true)
                    Divider()
                    calcRow("KAKS",         "2.50",    .blue,    false)
                    Divider()
                    calcRow("Hmax",         "9.50 m",  .orange,  true)
                }

                // Emsal hesabı
                sectionHeader("EMSAL HESABI")
                resultCard {
                    calcRow("Emsal Alanı",   "875.00 m²",  .green,   false)
                    Divider()
                    calcRow("Bodrum (emsal dışı)", "87.50 m²", .secondary, true)
                    Divider()
                    calcRow("Otopark",       "35.00 m²",   .secondary, false)
                }

                // Toplam highlight
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Toplam İnşaat Alanı").font(.caption).foregroundStyle(.secondary)
                        Text("997.50 m²").font(.title3.bold()).foregroundStyle(Color.ssNavy)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.title2)
                }
                .padding(12)
                .background(Color.ssBrand.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ssBrand.opacity(0.2)))

                // Maliyet
                sectionHeader("MALİYET TAHMİNİ")
                resultCard {
                    calcRow("Yapı Maliyeti (C)",  "₺2.625.000", .ssBrand, false)
                    Divider()
                    calcRow("Ruhsat Harcı",       "₺13.781",    .orange,   true)
                }
            }
            .padding(12)
        }
        .background(.white)
    }

    @ViewBuilder func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .black))
            .tracking(0.8)
            .foregroundStyle(Color.ssBrand)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder func resultCard<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 0.8))
    }

    @ViewBuilder func calcRow(_ label: String, _ value: String, _ color: Color, _ alt: Bool) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.primary)
            Spacer()
            Text(value).font(.caption.bold()).foregroundStyle(color)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(alt ? Color(.systemGray6) : .white)
    }
}

// MARK: - Scene 3: 3D Model

private struct Model3DMockScreen: View {
    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.14)

            // Grid floor
            Canvas { ctx, size in
                for x in stride(from: CGFloat(0), to: size.width, by: 22) {
                    var p = Path(); p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: size.height))
                    ctx.stroke(p, with: .color(.white.opacity(0.07)), lineWidth: 0.5)
                }
                for y in stride(from: CGFloat(0), to: size.height, by: 22) {
                    var p = Path(); p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: size.width, y: y))
                    ctx.stroke(p, with: .color(.white.opacity(0.07)), lineWidth: 0.5)
                }
            }

            // Isometric building
            Canvas { ctx, size in
                let cx = size.width / 2 - 10
                let cy = size.height / 2 + 40
                let w: CGFloat = 108; let h: CGFloat = 150; let d: CGFloat = 38; let sl: CGFloat = d * 0.45

                // Front face
                var front = Path()
                front.move(to: .init(x: cx - w/2, y: cy))
                front.addLine(to: .init(x: cx + w/2, y: cy))
                front.addLine(to: .init(x: cx + w/2, y: cy - h))
                front.addLine(to: .init(x: cx - w/2, y: cy - h))
                front.closeSubpath()
                ctx.fill(front, with: .color(Color(red: 0.14, green: 0.30, blue: 0.78)))

                // Windows front (4 rows × 3 cols)
                for row in 0..<4 {
                    for col in 0..<3 {
                        let wx = cx - 32 + CGFloat(col) * 24
                        let wy = cy - 32 - CGFloat(row) * 32
                        var win = Path()
                        win.addRoundedRect(in: CGRect(x: wx - 8, y: wy - 10, width: 16, height: 20),
                                          cornerSize: CGSize(width: 2, height: 2))
                        let lit = (row == 1 && col == 1) || (row == 3 && col == 2)
                        ctx.fill(win, with: .color(lit ? Color(red:1, green:0.92, blue:0.6).opacity(0.95)
                                                       : Color.white.opacity(0.55)))
                    }
                }

                // Right face
                var right = Path()
                right.move(to: .init(x: cx + w/2, y: cy))
                right.addLine(to: .init(x: cx + w/2 + d, y: cy - sl))
                right.addLine(to: .init(x: cx + w/2 + d, y: cy - h - sl))
                right.addLine(to: .init(x: cx + w/2, y: cy - h))
                right.closeSubpath()
                ctx.fill(right, with: .color(Color(red: 0.07, green: 0.17, blue: 0.52)))

                // Top face
                var top = Path()
                top.move(to: .init(x: cx - w/2,     y: cy - h))
                top.addLine(to: .init(x: cx + w/2,     y: cy - h))
                top.addLine(to: .init(x: cx + w/2 + d, y: cy - h - sl))
                top.addLine(to: .init(x: cx - w/2 + d, y: cy - h - sl))
                top.closeSubpath()
                ctx.fill(top, with: .color(Color(red: 0.38, green: 0.57, blue: 0.93)))

                // Parcel dashed outline
                var parcel = Path()
                parcel.move(to: .init(x: cx - w/2 - 22, y: cy + 8))
                parcel.addLine(to: .init(x: cx + w/2 + 22, y: cy + 8))
                parcel.addLine(to: .init(x: cx + w/2 + d + 14, y: cy + 8 - sl))
                parcel.addLine(to: .init(x: cx - w/2 + d + 0, y: cy + 8 - sl))
                parcel.closeSubpath()
                ctx.stroke(parcel, with: .color(Color.orange.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))

                // Compass marker
                var compass = Path()
                compass.addEllipse(in: CGRect(x: cx + w/2 + d + 16, y: cy - sl - 8, width: 10, height: 10))
                ctx.fill(compass, with: .color(Color.orange))
            }

            VStack {
                // Toolbar
                HStack {
                    Label("3D Kütle Modeli", systemImage: "cube.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "rotate.3d").font(.caption2)
                        Image(systemName: "move.3d").font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.white.opacity(0.09))

                Spacer()

                // Bottom bar
                HStack {
                    Label("875 m²", systemImage: "square.dashed")
                        .font(.caption.bold()).foregroundStyle(.white)
                    Spacer()
                    Label("K+2 · 9.5 m", systemImage: "arrow.up.and.down")
                        .font(.caption.bold()).foregroundStyle(.white)
                    Spacer()
                    Label("3B", systemImage: "building.fill")
                        .font(.caption.bold()).foregroundStyle(Color.ssGold)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.black.opacity(0.45))
            }
        }
    }
}

// MARK: - Scene 4: PDF Report

private struct PDFMockScreen: View {
    var body: some View {
        ZStack {
            Color(white: 0.91)

            VStack {
                Spacer()
                // Drop shadow doc
                VStack(spacing: 0) {
                    // Header
                    ZStack {
                        Color.ssNavy
                        VStack(spacing: 2) {
                            Text("EMSAL HESAP RAPORU")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white).tracking(1.2)
                            Text("Ada 389 / Parsel 26 · Kadıköy, İstanbul")
                                .font(.system(size: 6))
                                .foregroundStyle(.white.opacity(0.68))
                        }
                    }
                    .frame(height: 46)

                    // İmar
                    pdfBand("İMAR BİLGİLERİ")
                    pdfRow("TAKS",   "0.40", false)
                    pdfRow("KAKS",   "2.50", true)
                    pdfRow("Hmax",   "9.50 m", false)
                    pdfRow("Parsel Alanı", "350 m²", true)

                    // Emsal
                    pdfBand("EMSAL HESABI")
                    pdfRow("Emsal Alanı",        "875.00 m²",  false)
                    pdfRow("Bodrum (emsal dışı)", "87.50 m²",   true)
                    pdfRow("Toplam İnşaat",       "962.50 m²",  false)

                    // Total
                    HStack {
                        Text("NET İNŞAAT ALANI")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(Color.ssNavy)
                        Spacer()
                        Text("962.50 m²")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(Color.ssNavy)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.ssBrand.opacity(0.10))

                    // Maliyet
                    pdfBand("MALİYET TAHMİNİ")
                    pdfRow("Birim Maliyet (C)",  "₺3.000/m²",   false)
                    pdfRow("Yapı Maliyeti",      "₺2.887.500",  true)
                    pdfRow("Ruhsat Harcı",       "₺13.781",      false)
                    pdfRow("Toplam Tahmini",     "₺2.901.281",  true)

                    // Disclaimer
                    HStack(alignment: .top, spacing: 0) {
                        Rectangle().fill(Color.orange).frame(width: 3)
                        Text("Bu rapor bilgilendirme amaçlıdır. Kesin değerler için yetkili mimar / mühendise başvurunuz.")
                            .font(.system(size: 5.5))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7).padding(.vertical, 6)
                    }
                    .background(Color.orange.opacity(0.07))

                    Spacer()

                    // Footer
                    HStack {
                        Text("Parsel Mimar Pro")
                            .font(.system(size: 5.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("1 / 2")
                            .font(.system(size: 5.5))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .overlay(alignment: .top) { Color(.systemGray4).frame(height: 0.5) }
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                .padding(.horizontal, 18)
                Spacer()
            }
        }
    }

    func pdfBand(_ title: String) -> some View {
        HStack {
            Text(title).font(.system(size: 6, weight: .black))
                .foregroundStyle(.white).tracking(0.4)
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Color.ssBrand)
    }

    func pdfRow(_ label: String, _ value: String, _ alt: Bool) -> some View {
        HStack {
            Text(label).font(.system(size: 6.5)).foregroundStyle(.primary)
            Spacer()
            Text(value).font(.system(size: 6.5, weight: .medium)).foregroundStyle(.primary)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(alt ? Color(white: 0.97) : .white)
    }
}

// MARK: - Scene 5: Pro / Paywall

private struct ProMockScreen: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                // Hero
                ZStack {
                    LinearGradient(colors: [.ssNavy, .ssBrand],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 4) {
                        Image(systemName: "crown.fill").font(.title2).foregroundStyle(.yellow)
                        Text("Parsel Mimar Pro").font(.headline.bold()).foregroundStyle(.white)
                        Text("Profesyonel özellikler").font(.caption).foregroundStyle(.white.opacity(0.72))
                    }
                    .padding(.vertical, 16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Feature grid (2×4)
                let features = [
                    ("infinity", "Sınırsız proje"), ("doc.richtext.fill", "PDF rapor"),
                    ("cube.fill", "3D model"),       ("map.fill", "TKGM sorgu"),
                    ("floor.plans", "Kat planı"),    ("square.and.arrow.up", "KML/DXF çıktı"),
                    ("building.columns", "Ruhsat"),  ("chart.bar.fill", "Maliyet analizi"),
                ]
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(features, id: \.0) { icon, label in
                        HStack(spacing: 6) {
                            Image(systemName: icon).font(.caption2).foregroundStyle(Color.ssBrand)
                            Text(label).font(.system(size: 9))
                            Spacer()
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }

                // Plan cards
                miniPlan(title: "Aylık Pro",  price: "₺249,99",   period: "/ ay",
                         badge: "1 Hafta Ücretsiz", badgeColor: .green, selected: false, sub: nil)
                miniPlan(title: "Yıllık Pro", price: "₺1.999,99", period: "/ yıl",
                         badge: "EN İYİ DEĞER",    badgeColor: .orange, selected: true,  sub: "≈ ₺166,67 / ay")
                miniPlan(title: "Ömür Boyu",  price: "₺6.999,99", period: "tek seferlik",
                         badge: "SINIRSIZ",        badgeColor: .purple, selected: false, sub: nil)

                // CTA
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill").font(.caption)
                    Text("Yıllık Pro — ₺1.999,99").font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(LinearGradient(colors: [.ssBrand, .ssLight],
                                           startPoint: .leading, endPoint: .trailing))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(12)
        }
        .background(.white)
    }

    func miniPlan(title: String, price: String, period: String,
                  badge: String, badgeColor: Color, selected: Bool, sub: String?) -> some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(selected ? Color.accentColor : Color.gray.opacity(0.35), lineWidth: 1.8)
                        .frame(width: 17, height: 17)
                    if selected { Circle().fill(Color.accentColor).frame(width: 9, height: 9) }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.caption.bold())
                    if let s = sub { Text(s).font(.system(size: 9)).foregroundStyle(.secondary) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(price).font(.caption.bold())
                        .foregroundStyle(selected ? Color.accentColor : Color.primary)
                    Text(period).font(.system(size: 8)).foregroundStyle(.secondary)
                }
            }
            .padding(10).padding(.top, 7)
            .background(selected ? Color.accentColor.opacity(0.08) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11)
                .stroke(selected ? Color.accentColor : badgeColor.opacity(0.4),
                        lineWidth: selected ? 1.8 : 1))

            Text(badge)
                .font(.system(size: 7.5, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(badgeColor)
                .clipShape(Capsule())
                .offset(x: -10, y: -6)
        }
    }
}

// MARK: - Preview Container

private struct ScreenshotBrowser: View {
    let localeLabel: String
    let locale: Locale10n
    @State private var scene: Scene = .map

    var body: some View {
        VStack(spacing: 0) {
            // Scene picker
            Picker("Sahne", selection: $scene) {
                ForEach(Scene.allCases) { s in Text(s.rawValue).tag(s) }
            }
            .pickerStyle(.segmented)
            .padding(10)
            .background(Color(white: 0.12))

            AppStoreShot(copy: scene.copy(from: locale), isRTL: locale.isRTL, scene: scene)
        }
        .background(Color(white: 0.08))
        .navigationTitle(localeLabel)
    }
}

// MARK: - Previews (1 per locale — use scene picker to cycle)

#Preview("🇹🇷 Türkçe  — 390×844 pt") {
    ScreenshotBrowser(localeLabel: "🇹🇷 Türkçe", locale: tr)
}

#Preview("🇺🇸 English  — 390×844 pt") {
    ScreenshotBrowser(localeLabel: "🇺🇸 English", locale: en)
}

#Preview("🇮🇷 فارسی  — 390×844 pt") {
    ScreenshotBrowser(localeLabel: "🇮🇷 فارسی", locale: fa)
}

#Preview("🇸🇦 العربية  — 390×844 pt") {
    ScreenshotBrowser(localeLabel: "🇸🇦 العربية", locale: ar)
}

#Preview("🇩🇪 Deutsch  — 390×844 pt") {
    ScreenshotBrowser(localeLabel: "🇩🇪 Deutsch", locale: de)
}

// MARK: - All-locales grid (quick review)

#Preview("📐 Tüm Diller — Harita") {
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            ForEach(allLocales, id: \.0) { label, loc in
                VStack(spacing: 4) {
                    Text(label).font(.caption2).foregroundStyle(.white.opacity(0.6))
                    AppStoreShot(copy: loc.map, isRTL: loc.isRTL, scene: .map)
                        .scaleEffect(0.45)
                        .frame(width: 390 * 0.45, height: 844 * 0.45)
                }
            }
        }
        .padding(16)
    }
    .background(Color(white: 0.05))
}

#endif
