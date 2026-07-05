import SwiftUI
import SceneKit
import MapKit

// MARK: - SolidWorks-grade SCNView (PBR + 8× MSAA + HDR)

private struct SCNViewWrapper: UIViewRepresentable {
    let scene: SCNScene

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = UIColor(white: 0.87, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = false
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = scene
    }
}

struct ProjectDetailView: View {
    @Bindable var project: Project
    @EnvironmentObject private var storeKit: StoreKitService
    @State private var viewModel: ProjectViewModel
    @State private var building3D = Building3DViewModel()
    @State private var selectedSegment = 0
    @State private var showShareSheet = false
    @State private var showPaywall = false
    @State private var shareItems: [Any] = []
    @State private var haritaRegionID = 0

    // Editable imar text fields
    @State private var taksText = ""
    @State private var kaksText = ""
    @State private var hmaxText = ""
    @State private var katSayisiText = ""
    @State private var onCekmeText = ""
    @State private var arkaCekmeText = ""
    @State private var yanCekmeText = ""
    @State private var ortDaireAlaniText = ""

    init(project: Project) {
        self.project = project
        _viewModel = State(initialValue: ProjectViewModel(project: project))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Görünüm", selection: $selectedSegment) {
                    Text("Özet").tag(0)
                    Text("3D").tag(1)
                    Text("Kat Planı").tag(2)
                    Text("Maliyet").tag(3)
                    Text("Harita").tag(4)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch selectedSegment {
                case 0: summaryView
                case 1: building3DView
                case 2: floorPlanView
                case 3: costView
                case 4: parselMapView
                default: summaryView
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(project.name.isEmpty ? "Proje Detay" : project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // PDF Rapor — Pro only
                    Button {
                        if storeKit.isPro {
                            viewModel.generatePDF()
                            if let data = viewModel.pdfData {
                                shareItems = [data]
                                showShareSheet = true
                            }
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Label(
                            storeKit.isPro ? "PDF Rapor" : "PDF Rapor  🔒 Pro",
                            systemImage: "doc.fill"
                        )
                    }

                    if project.koordinatlar != nil {
                        Divider()

                        Button {
                            if storeKit.isPro { shareExport(format: "kml") }
                            else { showPaywall = true }
                        } label: {
                            Label(
                                storeKit.isPro ? "KML — Google Earth" : "KML  🔒 Pro",
                                systemImage: "globe"
                            )
                        }

                        Button {
                            if storeKit.isPro { shareExport(format: "dxf") }
                            else { showPaywall = true }
                        } label: {
                            Label(
                                storeKit.isPro ? "DXF — AutoCAD / CAD" : "DXF  🔒 Pro",
                                systemImage: "square.and.pencil"
                            )
                        }

                        Button {
                            if storeKit.isPro { shareExport(format: "geojson") }
                            else { showPaywall = true }
                        } label: {
                            Label(
                                storeKit.isPro ? "GeoJSON — CBS / QGIS" : "GeoJSON  🔒 Pro",
                                systemImage: "map.fill"
                            )
                        }
                    }

                    Divider()

                    Button {
                        if storeKit.canCalculate {
                            storeKit.recordCalculation()
                            applyAndRecalc()
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Label("Yeniden Hesapla", systemImage: "arrow.clockwise")
                    }
                    .disabled(!viewModel.isValidForCalculation)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            syncTextsFromProject()
            if viewModel.isValidForCalculation {
                viewModel.hesapla()
            }
            update3DModel()
            haritaRegionID = 1
        }
        // Auto-recalc when pickers change
        .onChange(of: project.kullanimTuru) { applyAndRecalc() }
        .onChange(of: project.binaTipi) { applyAndRecalc() }
        .onChange(of: project.yapiSinifi) { applyAndRecalc() }
        // 3D'ye geçince her zaman yeniden çiz
        .onChange(of: selectedSegment) { _, newVal in
            if newVal == 1 { update3DModel() }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(storeKit)
        }
    }

    // MARK: - Özet

    private var summaryView: some View {
        VStack(spacing: 16) {
            // Parsel — read-only
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Parsel Bilgileri", systemImage: "map")
                        .font(.headline)
                    Divider()
                    InfoGrid(items: [
                        ("İl/İlçe", "\(project.il)/\(project.ilce)"),
                        ("Mahalle", project.mahalle),
                        ("Ada/Parsel", "\(project.ada)/\(project.parsel)"),
                        ("Parsel Alanı", EmsalCalculator.formatAlan(project.parselAlani))
                    ])
                }
            }
            .padding(.horizontal)

            // İmar — editable
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("İmar Bilgileri", systemImage: "building.2")
                        .font(.headline)
                    Divider()
                    editRow("TAKS", text: $taksText)
                    editRow("KAKS (Emsal)", text: $kaksText)
                    editRow("H max (m)", text: $hmaxText)
                    editRowInt("Kat Sayısı", text: $katSayisiText)
                }
            }
            .padding(.horizontal)

            // Yapı özellikleri — editable pickers
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Yapı Özellikleri", systemImage: "house.fill")
                        .font(.headline)
                    Divider()
                    Picker("Kullanım Türü", selection: $project.kullanimTuru) {
                        ForEach(KullanimTuru.allCases) { tur in
                            Label(tur.rawValue, systemImage: tur.icon).tag(tur)
                        }
                    }
                    Picker("Bina Tipi", selection: $project.binaTipi) {
                        ForEach(BinaTipi.allCases) { tip in
                            Text(tip.rawValue).tag(tip)
                        }
                    }
                    // Ayrık yapı veya villa seçiliyse yapı adedi göster
                    if project.binaTipi == .ayrik || project.kullanimTuru == .villa {
                        Stepper(
                            "Yapı Adedi: \(project.binaSayisi)",
                            value: Binding(
                                get: { project.binaSayisi },
                                set: { project.binaSayisi = $0; applyAndRecalc() }
                            ),
                            in: 1...8
                        )
                        .font(.subheadline)
                    }
                    Picker("Yapı Sınıfı", selection: $project.yapiSinifi) {
                        ForEach(YapiSinifi.allCases) { sinif in
                            Text("\(sinif.rawValue) — \(sinif.description)").tag(sinif)
                        }
                    }
                    if project.kullanimTuru == .konut || project.kullanimTuru == .villa || project.kullanimTuru == .karma {
                        editRow("Ort. Daire Alanı (m²)", text: $ortDaireAlaniText)
                    }
                }
            }
            .padding(.horizontal)

            // Çekme mesafeleri — editable
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Çekme Mesafeleri", systemImage: "ruler")
                        .font(.headline)
                    Divider()
                    editRow("Ön Çekme (m)", text: $onCekmeText)
                    editRow("Arka Çekme (m)", text: $arkaCekmeText)
                    editRow("Yan Çekme (m)", text: $yanCekmeText)
                }
            }
            .padding(.horizontal)

            // Kalan hesaplama hakkı (ücretsiz kullanıcı)
            if !storeKit.isPro {
                Button { showPaywall = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: storeKit.canCalculate ? "clock.badge" : "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(storeKit.canCalculate ? .orange : .red)
                        if storeKit.canCalculate {
                            Text("Bugün **\(storeKit.remainingFreeCalcs)** hesaplama hakkınız kaldı")
                                .font(.caption)
                        } else {
                            Text("Günlük hesaplama limitine ulaştınız")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        Spacer()
                        Text("Pro →")
                            .font(.caption.bold())
                            .foregroundStyle(.accent)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        storeKit.canCalculate
                            ? Color.orange.opacity(0.08)
                            : Color.red.opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                storeKit.canCalculate ? Color.orange.opacity(0.25) : Color.red.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }

            // Sonuçlar
            if let sonuc = viewModel.hesaplamaSonucu {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Hesaplama Sonuçları", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Divider()
                        ResultBar(label: "Taban Alanı", value: sonuc.tabanAlani, max: sonuc.brutInsaatAlani, color: .blue)
                        ResultBar(label: "Toplam İnşaat", value: sonuc.toplamInsaatAlani, max: sonuc.brutInsaatAlani, color: .orange)
                        ResultBar(label: "Emsal Dışı", value: sonuc.emsalDisiToplam, max: sonuc.brutInsaatAlani, color: .purple)
                        ResultBar(label: "Brüt İnşaat", value: sonuc.brutInsaatAlani, max: sonuc.brutInsaatAlani, color: .green)
                        ResultBar(label: "Net İnşaat", value: sonuc.netInsaatAlani, max: sonuc.brutInsaatAlani, color: .teal)
                        Divider()
                        HStack {
                            Label("\(sonuc.otoparkSayisi) araç · \(EmsalCalculator.formatAlan(sonuc.zorunluOtoparkAlani)) otopark", systemImage: "car.fill")
                                .font(.caption)
                            Spacer()
                            Text(EmsalCalculator.formatPara(sonuc.tahminiBedel))
                                .font(.title3.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(.horizontal)

                birimOzetSection(sonuc)
                if !sonuc.perBinaOzetler.isEmpty {
                    perBinaTabloSection(sonuc)
                }
                emsalDisiKalemlerSection(sonuc)
                ruhsatHarciSection(sonuc)
                emsalOptimizasyonSection(sonuc)
            } else if !viewModel.isValidForCalculation {
                GroupBox {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle").foregroundStyle(.secondary)
                        Text("TAKS, KAKS ve kat sayısını girerek hesaplama başlatın.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Per-Bina Tablo (ayrık yapı / villa)

    private func perBinaTabloSection(_ sonuc: EmsalCalculator.HesaplamaSonucu) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label("Yapı Bazında Kırılım", systemImage: "building.2")
                    .font(.headline)
                Divider()

                // Başlık satırı
                HStack {
                    Text("Yapı").font(.caption).bold().foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                    Spacer()
                    Text("Taban Alanı").font(.caption).bold().foregroundStyle(.secondary)
                    Spacer()
                    Text("İnşaat Alanı").font(.caption).bold().foregroundStyle(.secondary)
                    Spacer()
                    Text("Kat").font(.caption).bold().foregroundStyle(.secondary).frame(width: 32, alignment: .trailing)
                }

                ForEach(sonuc.perBinaOzetler, id: \.binaNo) { bina in
                    HStack {
                        Text("Yapı \(bina.binaNo)").font(.subheadline).frame(width: 44, alignment: .leading)
                        Spacer()
                        Text(EmsalCalculator.formatAlan(bina.tabanAlani)).font(.subheadline)
                        Spacer()
                        Text(EmsalCalculator.formatAlan(bina.toplamInsaatAlani)).font(.subheadline)
                        Spacer()
                        Text("\(bina.katSayisi)").font(.subheadline).frame(width: 32, alignment: .trailing)
                    }
                    if bina.binaNo < sonuc.perBinaOzetler.count { Divider() }
                }

                // Toplam satırı
                HStack {
                    Text("Toplam").font(.subheadline).bold().frame(width: 44, alignment: .leading)
                    Spacer()
                    Text(EmsalCalculator.formatAlan(sonuc.tabanAlani)).font(.subheadline).bold()
                    Spacer()
                    Text(EmsalCalculator.formatAlan(sonuc.toplamInsaatAlani)).font(.subheadline).bold()
                    Spacer()
                    Text("").frame(width: 32)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Emsal Dışı Kalemler

    private func birimOzetSection(_ sonuc: EmsalCalculator.HesaplamaSonucu) -> some View {
        let oz = sonuc.birimOzet
        return GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("Bağımsız Bölüm Özeti", systemImage: "house.and.flag.fill")
                    .font(.headline)
                Divider()
                birimSatir(icon: "bed.double.fill", label: "Daire",
                           adet: oz.daireSayisi, birimM2: oz.daireBirimiM2, color: .blue)
                if oz.depoSayisi > 0 {
                    birimSatir(icon: "archivebox.fill", label: "Depo",
                               adet: oz.depoSayisi, birimM2: 4.0, color: .brown)
                }
                if oz.balkonSayisi > 0 {
                    birimSatir(icon: "square.stack.3d.up", label: "Balkon",
                               adet: oz.balkonSayisi, birimM2: 5.0, color: .teal)
                }
                birimSatir(icon: "car.fill", label: "Otopark",
                           adet: oz.otoparkSayisi, birimM2: oz.otoparkBirimiM2, color: .orange)
                if sonuc.asilKatSayisi < project.katSayisi && project.katSayisi > 0 {
                    Divider()
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("Girilen \(project.katSayisi) kat, KAKS/Hmax nedeniyle \(sonuc.asilKatSayisi) kata kısıtlandı.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func birimSatir(icon: String, label: String, adet: Int, birimM2: Double, color: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("\(adet) adet")
                .font(.caption.bold())
            Text("×")
                .font(.caption2).foregroundStyle(.tertiary)
            Text(EmsalCalculator.formatAlan(birimM2))
                .font(.caption).foregroundStyle(.secondary)
            Text("=")
                .font(.caption2).foregroundStyle(.tertiary)
            Text(EmsalCalculator.formatAlan(Double(adet) * birimM2))
                .font(.caption.bold()).foregroundStyle(color)
        }
    }

    private func emsalDisiKalemlerSection(_ sonuc: EmsalCalculator.HesaplamaSonucu) -> some View {
        let kalemler = sonuc.emsalDisiKalemler.kalemler
        return Group {
            if !kalemler.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Emsal Dışı Kalemler (PAİY)", systemImage: "list.bullet.rectangle")
                            .font(.headline)
                        Divider()
                        ForEach(kalemler, id: \.ad) { kalem in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(kalem.ad)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(EmsalCalculator.formatAlan(kalem.deger))
                                        .font(.caption.bold())
                                }
                                if let aciklama = kalem.aciklama {
                                    Text(aciklama)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        Divider()
                        HStack {
                            Text("Toplam Emsal Dışı")
                                .font(.caption.bold())
                            Spacer()
                            Text(EmsalCalculator.formatAlan(sonuc.emsalDisiToplam))
                                .font(.caption.bold())
                                .foregroundStyle(.purple)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Belediye Ruhsat Harçları

    private func ruhsatHarciSection(_ sonuc: EmsalCalculator.HesaplamaSonucu) -> some View {
        let h = sonuc.ruhsatHarci
        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label("Belediye Ruhsat Harçları", systemImage: "building.columns.fill")
                    .font(.headline)
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)
                    Text("Tahmini 2025 değerleri (BGB Md.80 bazlı). Kesin tutar için ilgili belediyeye danışınız. Bu hesap yatırım tavsiyesi değildir.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Divider()
                HarcSatiri(label: "Yapı Ruhsat Harcı",
                           value: h.yapiRuhsatHarci,
                           detail: "\(EmsalCalculator.formatAlan(h.bazAlani)) × \(String(format: "%.0f", h.birimDegeri)) TL/m²")
                HarcSatiri(label: "Yapı Kullanma İzni",
                           value: h.kullanmaIzinHarci,
                           detail: "Ruhsat harcının %50'si")
                HarcSatiri(label: "Zemin Etüt Harcı",
                           value: h.zeminEtutHarci,
                           detail: "Ruhsat harcının %1'i")
                Divider()
                HStack {
                    Text("Toplam Tahmini Harç")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(EmsalCalculator.formatPara(h.toplam))
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Emsal Optimizasyon

    private func emsalOptimizasyonSection(_ sonuc: EmsalCalculator.HesaplamaSonucu) -> some View {
        let opt = sonuc.optimizasyon
        return Group {
            if opt.maksimumEmsal > 0 {
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Emsal Optimizasyonu", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("KAKS Kullanımı")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.0f%%", min(opt.kullanimYuzdesi, 100)))
                                    .font(.caption.bold())
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange.opacity(0.2))
                                        .frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(opt.kullanimYuzdesi >= 95 ? Color.green : Color.orange)
                                        .frame(
                                            width: geo.size.width * CGFloat(min(opt.kullanimYuzdesi, 100) / 100),
                                            height: 8
                                        )
                                }
                            }
                            .frame(height: 8)
                        }
                        if opt.kalanPotansiyel > 0 {
                            HStack {
                                Text("Kalan Potansiyel")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(EmsalCalculator.formatAlan(opt.kalanPotansiyel))
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                        if !opt.oneriler.isEmpty {
                            Divider()
                            ForEach(opt.oneriler, id: \.self) { oneri in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                    Text(oneri)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - 3D Model

    private var building3DView: some View {
        VStack(spacing: 12) {
            SCNViewWrapper(scene: building3D.scene)
            .frame(height: 380)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Görünüm Seçenekleri")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Toggle(isOn: $building3D.showParcelBoundary) {
                        Label("Parsel Sınırı", systemImage: "square.dashed")
                    }
                    .tint(.green)
                    .onChange(of: building3D.showParcelBoundary) { _, _ in
                        building3D.updateNodeVisibility()
                    }

                    Toggle(isOn: $building3D.showSetbackLines) {
                        Label("Çekme Mesafesi Çizgileri", systemImage: "ruler")
                    }
                    .tint(.orange)
                    .onChange(of: building3D.showSetbackLines) { _, _ in
                        building3D.updateNodeVisibility()
                    }

                    if project.kullanimTuru == .konut || project.kullanimTuru == .villa {
                        Toggle(isOn: $building3D.showBalconies) {
                            Label("Balkonlar", systemImage: "square.stack.3d.up")
                        }
                        .tint(.indigo)
                        .onChange(of: building3D.showBalconies) { _, _ in
                            building3D.updateNodeVisibility()
                        }
                    }
                }
            }
            .padding(.horizontal)

            let dims = viewModel.parselDimensions
            if dims.genislik > 0 {
                HStack(spacing: 20) {
                    Label(String(format: "%.1f m genişlik", dims.genislik), systemImage: "arrow.left.and.right")
                    Label(String(format: "%.1f m derinlik", dims.derinlik), systemImage: "arrow.up.and.down")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Text("Dokunarak döndürün · İki parmakla yakınlaştırın")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Kat Planı

    private var floorPlanView: some View {
        let dims = viewModel.parselDimensions
        let pW = dims.genislik > 0 ? dims.genislik : (project.parselAlani > 0 ? sqrt(project.parselAlani) * 0.85 : 15.0)
        let pD = dims.derinlik > 0 ? dims.derinlik : (project.parselAlani > 0 ? sqrt(project.parselAlani) * 1.15 : 20.0)
        let bW = max(5.0, pW - project.yanCekme * 2)
        let bD = max(5.0, pD - project.onCekme - project.arkaCekme)

        // Per-building dimensions when multiple buildings in a grid
        let isMultiBina = (project.binaTipi == .ayrik || project.kullanimTuru == .villa) && project.binaSayisi > 1
        let n = isMultiBina ? max(1, project.binaSayisi) : 1
        let cols = n <= 2 ? n : Int(ceil(sqrt(Double(n))))
        let rows = Int(ceil(Double(n) / Double(cols)))
        let gapM = project.yanCekme > 0 ? project.yanCekme : 3.0
        let perW = isMultiBina ? max(5.0, (bW - gapM * Double(cols - 1)) / Double(cols)) : bW
        let perD = isMultiBina ? max(5.0, (bD - gapM * Double(rows - 1)) / Double(rows)) : bD

        return FloorPlanView(
            buildingW: perW, buildingD: perD,
            binaSayisi: n,
            project: project,
            hesaplamaSonucu: viewModel.hesaplamaSonucu
        )
    }

    // MARK: - Maliyet

    private var costView: some View {
        VStack(spacing: 16) {
            if let sonuc = viewModel.hesaplamaSonucu {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Yapı Maliyet Analizi", systemImage: "turkishlirasign.circle")
                            .font(.headline)
                        Divider()
                        InfoRow(label: "Yapı Sınıfı", value: project.yapiSinifi.rawValue)
                        InfoRow(label: "Birim Maliyet (2026)", value: EmsalCalculator.formatPara(project.yapiSinifi.birimMaliyet2026) + "/m²")
                        InfoRow(label: "Brüt İnşaat Alanı", value: EmsalCalculator.formatAlan(sonuc.brutInsaatAlani))
                        Divider()
                        HStack {
                            Text("TAHMİNİ TOPLAM").font(.headline)
                            Spacer()
                            Text(EmsalCalculator.formatPara(sonuc.tahminiBedel))
                                .font(.title.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(.horizontal)

                Text("2026 Yapı Yaklaşık Birim Maliyetleri Tebliği'ne göre hesaplanmıştır.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Harita (Parsel Konumu)

    private var parselMapView: some View {
        VStack(spacing: 12) {
            let polygon = viewModel.parselPolygon

            if !polygon.isEmpty {
                let center = CLLocationCoordinate2D(
                    latitude: polygon.map(\.latitude).reduce(0, +) / Double(polygon.count),
                    longitude: polygon.map(\.longitude).reduce(0, +) / Double(polygon.count)
                )
                let region = MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                )

                ParselMapUIKitView(
                    mapLayer: .hibrit,
                    polygons: [polygon],
                    selectedCoordinate: center,
                    programmaticRegion: region,
                    programmaticRegionID: haritaRegionID,
                    onCenterChanged: { _ in },
                    onTap: { _ in }
                )
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                GroupBox {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        GridRow {
                            Text("Konum").foregroundStyle(.secondary)
                            Text("\(project.il) / \(project.ilce)")
                        }
                        GridRow {
                            Text("Ada / Parsel").foregroundStyle(.secondary)
                            Text("\(project.ada) / \(project.parsel)")
                        }
                        GridRow {
                            Text("Alan").foregroundStyle(.secondary)
                            Text(EmsalCalculator.formatAlan(project.parselAlani)).bold()
                        }
                        let dims = viewModel.parselDimensions
                        if dims.genislik > 0 {
                            GridRow {
                                Text("Boyutlar").foregroundStyle(.secondary)
                                Text(String(format: "%.1f × %.1f m", dims.genislik, dims.derinlik))
                            }
                        }
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal)

            } else {
                ContentUnavailableView {
                    Label("Parsel Geometrisi Yok", systemImage: "map.slash")
                } description: {
                    Text("TKGM'den parsel sorgulayarak harita verisi yükleyin.")
                }
                .padding()
            }
        }
    }

    // MARK: - Editable Row Helpers

    @ViewBuilder
    private func editRow(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .onChange(of: text.wrappedValue) { applyAndRecalc() }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func editRowInt(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .onChange(of: text.wrappedValue) { applyAndRecalc() }
        }
        .font(.subheadline)
    }

    // MARK: - Calc Helpers

    private func syncTextsFromProject() {
        taksText = project.taks > 0 ? String(format: "%.2f", project.taks) : ""
        kaksText = project.kaks > 0 ? String(format: "%.2f", project.kaks) : ""
        hmaxText = project.hmax > 0 ? String(format: "%.1f", project.hmax) : ""
        katSayisiText = project.katSayisi > 0 ? "\(project.katSayisi)" : ""
        onCekmeText = String(format: "%.1f", project.onCekme)
        arkaCekmeText = String(format: "%.1f", project.arkaCekme)
        yanCekmeText = String(format: "%.1f", project.yanCekme)
        ortDaireAlaniText = project.ortDaireAlani > 0 ? String(format: "%.0f", project.ortDaireAlani) : ""
    }

    private func applyAndRecalc() {
        let fmt = { (s: String) -> Double in Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        project.taks = fmt(taksText)
        project.kaks = fmt(kaksText)
        project.hmax = fmt(hmaxText)
        project.katSayisi = Int(katSayisiText) ?? 0
        project.onCekme = fmt(onCekmeText)
        project.arkaCekme = fmt(arkaCekmeText)
        project.yanCekme = fmt(yanCekmeText)
        project.ortDaireAlani = fmt(ortDaireAlaniText)

        guard viewModel.isValidForCalculation else { return }
        viewModel.hesapla()
        update3DModel()
    }

    private func update3DModel() {
        let alan   = project.parselAlani > 0 ? project.parselAlani : 400.0
        let taban  = project.tabanAlani > 0
            ? project.tabanAlani
            : (project.taks > 0 ? alan * project.taks : alan * 0.40)
        building3D.buildModel(
            tabanAlani: taban,
            katSayisi: max(1, project.katSayisi),
            kullanimTuru: project.kullanimTuru,
            binaTipi: project.binaTipi,
            binaSayisi: max(1, project.binaSayisi),
            onCekme: max(project.onCekme, 3),
            arkaCekme: max(project.arkaCekme, 3),
            yanCekme: max(project.yanCekme, 2),
            parselKoordinatlar: project.koordinatlar,
            parselAlani: alan,
            toplamInsaatAlani: project.toplamInsaatAlani,
            hmax: project.hmax
        )
    }

    private func shareExport(format: String) {
        let label = project.name.isEmpty ? "\(project.il)_\(project.ada)_\(project.parsel)" : project.name
        let safeName = label.replacingOccurrences(of: "/", with: "_")
                            .replacingOccurrences(of: " ", with: "_")

        let data: Data?
        let ext: String

        switch format {
        case "kml":
            data = ParselExportService.generateKML(
                name: label,
                il: project.il, ilce: project.ilce, ada: project.ada, parsel: project.parsel,
                taks: project.taks, kaks: project.kaks,
                koordinatlar: project.koordinatlar
            )
            ext = "kml"
        case "dxf":
            data = ParselExportService.generateDXF(
                name: label,
                koordinatlar: project.koordinatlar
            )
            ext = "dxf"
        default: // geojson
            data = ParselExportService.generateGeoJSON(
                name: label,
                il: project.il, ilce: project.ilce, ada: project.ada, parsel: project.parsel,
                taks: project.taks, kaks: project.kaks, alan: project.parselAlani,
                koordinatlar: project.koordinatlar
            )
            ext = "geojson"
        }

        guard let data else { return }

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName).\(ext)")
        try? data.write(to: tmp)

        shareItems = [tmp]
        showShareSheet = true
    }
}

// MARK: - Components

struct InfoGrid: View {
    let items: [(String, String)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0).font(.caption).foregroundStyle(.secondary)
                    Text(item.1).font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold()
        }
        .font(.subheadline)
    }
}

struct ResultBar: View {
    let label: String
    let value: Double
    let max: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(EmsalCalculator.formatAlan(value)).font(.caption.bold())
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.2))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: max > 0 ? geo.size.width * CGFloat(value / max) : 0, height: 8)
                    }
            }
            .frame(height: 8)
        }
    }
}

private struct HarcSatiri: View {
    let label: String
    let value: Double
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(EmsalCalculator.formatPara(value)).font(.subheadline)
            }
            Text(detail).font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
