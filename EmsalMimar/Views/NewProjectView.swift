import SwiftUI
import SwiftData
import MapKit

struct NewProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var il = ""
    @State private var ilce = ""
    @State private var mahalle = ""
    @State private var ada = ""
    @State private var parsel = ""
    @State private var parselAlani = ""
    @State private var taks = ""
    @State private var kaks = ""
    @State private var hmax = ""
    @State private var katSayisi = ""
    @State private var kullanimTuru: KullanimTuru = .konut
    @State private var binaTipi: BinaTipi = .ayrik
    @State private var binaSayisi: Int = 1
    @State private var yapiSinifi: YapiSinifi = .sinif3A
    @State private var onCekme = "5"
    @State private var arkaCekme = "3"
    @State private var yanCekme = "3"
    @State private var ortDaireAlani = ""

    @State private var showMapPicker = false
    @State private var isLoadingParsel = false
    @State private var parselFetchSuccess = false
    @State private var parselFetchError: String?
    @State private var cachedKoordinatlar: Data?
    @State private var fetchTask: Task<Void, Never>?

    // İmar durumu
    @State private var imarKaynak: String? = nil       // nil = henüz sorgulanmadı
    @State private var imarBulunamadi = false
    @State private var imarWebGISUrl: URL? = nil
    @State private var lastFetchLat: Double = 0
    @State private var lastFetchLon: Double = 0

    var parselData: ParselData?

    var canQueryByAddress: Bool { !il.isEmpty && !ada.isEmpty && !parsel.isEmpty }

    var parselSorguURL: URL? {
        var comps = URLComponents(string: "https://parselsorgu.tkgm.gov.tr")
        if !ada.isEmpty || !parsel.isEmpty {
            comps?.queryItems = [
                URLQueryItem(name: "ada", value: ada),
                URLQueryItem(name: "parsel", value: parsel)
            ]
        }
        return comps?.url
    }

    var body: some View {
        NavigationStack {
            Form {
                quickFetchSection
                projectNameSection
                parselSection
                imarSection
                yapiSection
                cekmeMesafeleriSection
            }
            .navigationTitle("Yeni Proje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Oluştur") { createProject() }
                        .bold()
                        .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let data = parselData { applyParselData(data) }
            }
            .sheet(isPresented: $showMapPicker) {
                MapPickerSheet { coordinate in
                    showMapPicker = false
                    Task { await fetchFromCoordinate(coordinate) }
                }
            }
        }
    }

    // MARK: - Sections

    private var quickFetchSection: some View {
        Section {
            Button {
                showMapPicker = true
            } label: {
                Label("Haritadan Konum Seç", systemImage: "map.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Text("Otomatik Getir")
        } footer: {
            Text("Haritadan konuma dokunarak parsel ve imar bilgileri otomatik çekilir.")
                .font(.caption)
        }
    }

    private var projectNameSection: some View {
        Section("Proje Adı") {
            TextField("Proje adı girin", text: $name)
        }
    }

    private var parselSection: some View {
        Section("Parsel Bilgileri") {
            TextField("İl", text: $il).autocorrectionDisabled()
            TextField("İlçe", text: $ilce).autocorrectionDisabled()
            TextField("Mahalle", text: $mahalle).autocorrectionDisabled()
            HStack {
                TextField("Ada", text: $ada).keyboardType(.numberPad)
                TextField("Parsel", text: $parsel).keyboardType(.numberPad)
            }
            HStack {
                Text("Parsel Alanı")
                Spacer()
                TextField("m²", text: $parselAlani)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }

            Button {
                fetchTask?.cancel()
                fetchTask = Task { await queryTKGMByAddress() }
            } label: {
                HStack {
                    if isLoadingParsel {
                        ProgressView().scaleEffect(0.85)
                        Text("Parsel sorgulanıyor...")
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("TKGM'den Parsel + İmar Bilgisi Getir")
                    }
                }
            }
            .disabled(isLoadingParsel || !canQueryByAddress)

            if parselFetchSuccess {
                Label("Parsel bilgileri güncellendi", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.caption)
            }
            if let error = parselFetchError {
                if error.contains("haritadan konum seçin") {
                    // TKGM WAF engeli — parselsorgu.tkgm.gov.tr linki göster
                    VStack(alignment: .leading, spacing: 6) {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.caption)
                        if let url = parselSorguURL {
                            Link(destination: url) {
                                Label("parselsorgu.tkgm.gov.tr'da açın", systemImage: "safari")
                                    .font(.caption.bold())
                            }
                        }
                    }
                } else {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.caption)
                }
            }
        }
    }

    private var imarSection: some View {
        Section {
            if let kaynak = imarKaynak {
                Label("İmar değerleri \(kaynak) üzerinden alındı.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.caption)
            } else if imarBulunamadi {
                // Parsel bulunduktan sonra imar planı linkleri
                VStack(alignment: .leading, spacing: 10) {
                    Text("TAKS, KAKS, H\u{200B}max değerlerini aşağıdaki resmi portallardan bularak giriniz:")
                        .font(.caption).foregroundStyle(.secondary)
                    // e-Plan (resmi TKGM imar portalı)
                    Link(destination: URL(string: "https://eplan.tkgm.gov.tr")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("e-Plan — Resmi İmar Planı (TKGM)")
                                .font(.subheadline.bold())
                        }
                    }
                    // Şehre özel belediye WebGIS
                    if let url = imarWebGISUrl {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "map")
                                Text("Belediye WebGIS Haritası")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                // Henüz parsel seçilmedi
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle").foregroundStyle(.secondary).padding(.top, 1)
                    Text("Haritadan konum veya ada/parsel seçtikten sonra imar linki görünür.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            numericRow("TAKS", text: $taks)
            numericRow("KAKS (Emsal)", text: $kaks)
            numericRow("H max (m)", text: $hmax)
            HStack {
                Text("Kat Sayısı")
                Spacer()
                TextField("0", text: $katSayisi)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }
        } header: {
            Text("İmar Bilgileri")
        }
    }

    private var yapiSection: some View {
        Section("Yapı Özellikleri") {
            Picker("Kullanım Türü", selection: $kullanimTuru) {
                ForEach(KullanimTuru.allCases) { tur in
                    Label(tur.rawValue, systemImage: tur.icon).tag(tur)
                }
            }
            Picker("Bina Tipi", selection: $binaTipi) {
                ForEach(BinaTipi.allCases) { tip in Text(tip.rawValue).tag(tip) }
            }
            if binaTipi == .ayrik || kullanimTuru == .villa {
                Stepper("Yapı Adedi: \(binaSayisi)", value: $binaSayisi, in: 1...8)
            }
            Picker("Yapı Sınıfı", selection: $yapiSinifi) {
                ForEach(YapiSinifi.allCases) { sinif in
                    Text("\(sinif.rawValue) — \(sinif.description)").tag(sinif)
                }
            }
            if kullanimTuru == .konut || kullanimTuru == .villa || kullanimTuru == .karma {
                numericRow("Ort. Daire Alanı (m²)", text: $ortDaireAlani)
            }
        }
    }

    private var cekmeMesafeleriSection: some View {
        Section("Çekme Mesafeleri") {
            numericRow("Ön Çekme (m)", text: $onCekme)
            numericRow("Arka Çekme (m)", text: $arkaCekme)
            numericRow("Yan Çekme (m)", text: $yanCekme)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func numericRow(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
        }
    }

    // MARK: - Fetch

    private func fetchFromCoordinate(_ coord: CLLocationCoordinate2D) async {
        resetImarState()
        isLoadingParsel = true
        parselFetchError = nil
        parselFetchSuccess = false
        do {
            let data = try await TKGMService.shared.fetchParsel(latitude: coord.latitude, longitude: coord.longitude)
            applyParselData(data)
            lastFetchLat = coord.latitude
            lastFetchLon = coord.longitude
            parselFetchSuccess = true
            isLoadingParsel = false
            await fetchImar(lat: coord.latitude, lon: coord.longitude, il: data.il, nitelik: data.nitelik)
        } catch {
            parselFetchError = error.localizedDescription
            isLoadingParsel = false
        }
    }

    private func queryTKGMByAddress() async {
        resetImarState()
        isLoadingParsel = true
        parselFetchError = nil
        parselFetchSuccess = false
        do {
            let data = try await TKGMService.shared.fetchParselByAdaParsel(
                il: il, ilce: ilce, mahalle: mahalle, ada: ada, parsel: parsel
            )
            applyParselData(data)
            let (lat, lon) = centroidFromKoordinatlar(cachedKoordinatlar)
            lastFetchLat = lat; lastFetchLon = lon
            parselFetchSuccess = true
            isLoadingParsel = false
            await fetchImar(lat: lat, lon: lon, il: data.il, nitelik: data.nitelik)
        } catch {
            parselFetchError = error.localizedDescription
            isLoadingParsel = false
        }
    }

    private func fetchImar(lat: Double, lon: Double, il: String, nitelik: String = "") async {
        // TKGM parsel niteliğinden TAKS/KAKS tahmini yap (API çağrısı gerektirmez)
        if let imar = TKGMService.imarFromNitelik(nitelik, il: il) {
            applyImarBilgisi(imar)
            return
        }
        // Nitelik yoksa veya eşleşme bulunamadıysa resmi portale yönlendir
        imarBulunamadi = true
        imarWebGISUrl = TKGMService.webGISUrl(il: il, lat: lat, lon: lon)
    }

    private func resetImarState() {
        imarKaynak = nil
        imarBulunamadi = false
        imarWebGISUrl = nil
    }

    private func applyParselData(_ data: ParselData) {
        if !data.il.isEmpty { il = data.il }
        if !data.ilce.isEmpty { ilce = data.ilce }
        if !data.mahalle.isEmpty { mahalle = data.mahalle }
        if !data.ada.isEmpty { ada = data.ada }
        if !data.parsel.isEmpty { parsel = data.parsel }
        if data.alan > 0 { parselAlani = String(format: "%.2f", data.alan).replacingOccurrences(of: ".", with: ",") }
        if let k = data.koordinatlar { cachedKoordinatlar = k }
        if name.isEmpty { name = "\(data.il) \(data.ada)/\(data.parsel)" }
    }

    private func applyImarBilgisi(_ imar: ImarBilgisi) {
        taks = String(format: "%.2f", imar.taks)
        kaks = String(format: "%.2f", imar.kaks)
        if imar.hmax > 0 { hmax = String(format: "%.1f", imar.hmax) }
        if imar.katSayisi > 0 { katSayisi = "\(imar.katSayisi)" }
        imarKaynak = imar.kaynak
        imarBulunamadi = false
    }

    private func centroidFromKoordinatlar(_ data: Data?) -> (Double, Double) {
        guard let data, let geo = try? JSONDecoder().decode(ParselGeometry.self, from: data),
              let ring = geo.coordinates.first, !ring.isEmpty else { return (0, 0) }
        return (ring.map { $0[1] }.reduce(0, +) / Double(ring.count),
                ring.map { $0[0] }.reduce(0, +) / Double(ring.count))
    }

    // MARK: - Create

    private func createProject() {
        fetchTask?.cancel()
        fetchTask = nil
        isLoadingParsel = false
        let project = Project(name: name, il: il, ilce: ilce, mahalle: mahalle, ada: ada, parsel: parsel)
        let parse = TKGMService.parseLocaleDouble
        project.parselAlani  = parse(parselAlani)
        project.taks         = parse(taks)
        project.kaks         = parse(kaks)
        project.hmax         = parse(hmax)
        project.katSayisi    = Int(katSayisi) ?? 0
        project.kullanimTuru = kullanimTuru
        project.binaTipi     = binaTipi
        project.binaSayisi   = binaSayisi
        project.yapiSinifi   = yapiSinifi
        project.onCekme      = { let v = parse(onCekme);   return v > 0 ? v : 5 }()
        project.arkaCekme    = { let v = parse(arkaCekme); return v > 0 ? v : 3 }()
        project.yanCekme     = { let v = parse(yanCekme);  return v > 0 ? v : 3 }()
        project.ortDaireAlani = parse(ortDaireAlani)
        project.koordinatlar = cachedKoordinatlar
        modelContext.insert(project)
        dismiss()
    }
}

// MARK: - Map Picker Sheet

struct MapPickerSheet: View {
    let onSelect: (CLLocationCoordinate2D) -> Void

    @State private var mapVM = MapViewModel()
    @State private var mapCenter = CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597)
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597),
                  distance: 1500, heading: 0, pitch: 60)
    )
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition)
                    .mapStyle(.hybrid(elevation: .realistic))
                    .onMapCameraChange(frequency: .continuous) { ctx in mapCenter = ctx.region.center }
                    .onChange(of: mapVM.region.center.latitude) { _, _ in
                        cameraPosition = .camera(
                            MapCamera(centerCoordinate: mapVM.region.center, distance: 1500, heading: 0, pitch: 60)
                        )
                    }
                    .ignoresSafeArea()

                Image(systemName: "plus").font(.title2).foregroundStyle(.red.opacity(0.9))
                    .padding(8).background(.ultraThinMaterial).clipShape(Circle())

                VStack {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Adres ara...", text: $searchText)
                            .textFieldStyle(.plain).submitLabel(.search)
                            .onSubmit { Task { await searchAddress() } }
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(10).background(.ultraThickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal).padding(.top, 8)

                    Spacer()

                    Button { onSelect(mapCenter) } label: {
                        Label("Bu Konumu Seç", systemImage: "scope")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .background(.accent).foregroundStyle(.white)
                            .clipShape(Capsule()).shadow(radius: 4)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Konum Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { mapVM.requestLocation() } label: {
                        Image(systemName: mapVM.isLocating ? "location.fill" : "location")
                    }
                }
            }
        }
    }

    private func searchAddress() async {
        guard !searchText.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = .address
        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first else { return }
        cameraPosition = .camera(
            MapCamera(centerCoordinate: item.placemark.coordinate, distance: 1500, heading: 0, pitch: 60)
        )
    }
}
