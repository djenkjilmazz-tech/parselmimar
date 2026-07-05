import SwiftUI
import MapKit

// MARK: - Map Layer

enum MapLayer: String, CaseIterable, Identifiable {
    case standart = "Standart"
    case uydu = "Uydu"
    case hibrit = "Hibrit 3D"
    case parsel = "Parsel / İmar"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .standart: return "map"
        case .uydu:     return "globe.europe.africa.fill"
        case .hibrit:   return "cube.fill"
        case .parsel:   return "square.stack.3d.up.fill"
        }
    }

    var mapType: MKMapType {
        switch self {
        case .standart:         return .standard
        case .uydu:             return .satellite
        case .hibrit, .parsel:  return .hybrid
        }
    }
}

// MARK: - UIKit Map Wrapper

struct ParselMapUIKitView: UIViewRepresentable {
    var mapLayer: MapLayer
    var polygons: [[CLLocationCoordinate2D]]        // tüm GeoJSON poligonlar
    var selectedCoordinate: CLLocationCoordinate2D?
    var programmaticRegion: MKCoordinateRegion
    var programmaticRegionID: Int
    var onCenterChanged: (CLLocationCoordinate2D) -> Void
    var onTap: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isPitchEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.mapType = mapLayer.mapType

        let camera = MKMapCamera(
            lookingAtCenter: programmaticRegion.center,
            fromDistance: 1500, pitch: 60, heading: 0
        )
        mapView.setCamera(camera, animated: false)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.delegate = context.coordinator
        tap.cancelsTouchesInView = false   // haritanın kendi gesture'ının tap'i iptal etmesini önler
        mapView.addGestureRecognizer(tap)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let c = context.coordinator

        if mapView.mapType != mapLayer.mapType {
            mapView.mapType = mapLayer.mapType
        }

        // Poligonları güncelle (count değişince)
        let newCount = polygons.reduce(0) { $0 + $1.count }
        if c.lastPolygonHash != newCount {
            c.lastPolygonHash = newCount
            mapView.overlays.filter { $0 is MKPolygon }.forEach { mapView.removeOverlay($0) }
            for poly in polygons where poly.count >= 3 {
                var coords = poly
                mapView.addOverlay(
                    MKPolygon(coordinates: &coords, count: coords.count),
                    level: .aboveRoads
                )
            }
        }

        // İşaret noktası
        let newLat = selectedCoordinate?.latitude ?? .nan
        if c.lastSelectedLat != newLat {
            c.lastSelectedLat = newLat
            mapView.annotations.filter { !($0 is MKUserLocation) }.forEach { mapView.removeAnnotation($0) }
            if let sel = selectedCoordinate {
                let a = MKPointAnnotation()
                a.coordinate = sel
                mapView.addAnnotation(a)
            }
        }

        // Programatik kamera hareketi
        if c.lastRegionID != programmaticRegionID {
            c.lastRegionID = programmaticRegionID
            let camera = MKMapCamera(
                lookingAtCenter: programmaticRegion.center,
                fromDistance: 1500, pitch: 60, heading: 0
            )
            mapView.setCamera(camera, animated: true)
        }
    }

    // MARK: Coordinator

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: ParselMapUIKitView
        var lastRegionID = -1
        var lastPolygonHash = -1
        var lastSelectedLat: Double = .nan

        init(_ parent: ParselMapUIKitView) { self.parent = parent }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView, gesture.state == .ended else { return }
            let pt = gesture.location(in: mapView)
            let coord = mapView.convert(pt, toCoordinateFrom: mapView)
            parent.onTap(coord)
        }

        func gestureRecognizer(
            _ gr: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onCenterChanged(mapView.centerCoordinate)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let poly = overlay as? MKPolygon {
                let r = MKPolygonRenderer(polygon: poly)
                r.fillColor = UIColor.systemYellow.withAlphaComponent(0.25)
                r.strokeColor = UIColor.systemYellow
                r.lineWidth = 2
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let v = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
            v.markerTintColor = .systemRed
            return v
        }
    }
}

// MARK: - MapParselView

struct MapParselView: View {
    @State private var viewModel = MapViewModel()
    @State private var projectVM: ProjectViewModel?
    @State private var showParselInfo = false
    @State private var mapCenter = CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597)
    @State private var selectedLayer: MapLayer = .hibrit
    @State private var showLayerPicker = false
    @State private var programmaticRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var programmaticRegionID = 0
    @State private var showNewProject = false

    // Parsel katmanı için toplanan GeoJSON poligonlar
    @State private var fetchedPolygons: [[CLLocationCoordinate2D]] = []
    @State private var fetchedKeys: Set<String> = []
    @State private var parselFetchTask: Task<Void, Never>?
    @State private var isFetchingLayer = false
    @State private var selectLocationTask: Task<Void, Never>?

    // Haritada gösterilecek tüm poligonlar
    private var allPolygons: [[CLLocationCoordinate2D]] {
        var result = fetchedPolygons
        if !viewModel.parselPolygon.isEmpty {
            result.append(viewModel.parselPolygon)
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ParselMapUIKitView(
                    mapLayer: selectedLayer,
                    polygons: allPolygons,
                    selectedCoordinate: viewModel.selectedCoordinate,
                    programmaticRegion: programmaticRegion,
                    programmaticRegionID: programmaticRegionID,
                    onCenterChanged: { coord in
                        mapCenter = coord
                        scheduleParselLayerFetch(at: coord)
                    },
                    onTap: { coord in selectLocation(coord) }
                )
                .ignoresSafeArea()

                if !showParselInfo {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .allowsHitTesting(false)
                }

                if isFetchingLayer {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.8)
                                Text("Parseller yükleniyor").font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThickMaterial)
                            .clipShape(Capsule())
                            .padding(.trailing)
                            .padding(.top, 8)
                        }
                        Spacer()
                    }
                }

                VStack {
                    Spacer()
                    VStack(spacing: 0) {
                        searchBar
                        if showParselInfo, let pvm = projectVM {
                            parselInfoCard(pvm)
                        }
                    }
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button { showLayerPicker = true } label: {
                            VStack(spacing: 2) {
                                Image(systemName: selectedLayer.icon).font(.body)
                                Text("Katman").font(.caption2)
                            }
                            .padding(8)
                            .background(.ultraThickMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 3)
                        }
                        .padding(.trailing)
                        .padding(.bottom, showParselInfo ? 280 : 100)
                    }
                }
            }
            .navigationTitle("Parsel Haritası")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.requestLocation()
                    } label: {
                        Image(systemName: viewModel.isLocating ? "location.fill" : "location")
                    }
                }
            }
            .onAppear {
                programmaticRegion = viewModel.region
                programmaticRegionID += 1
            }
            .onChange(of: viewModel.region.center.latitude) { _, _ in
                programmaticRegion = viewModel.region
                programmaticRegionID += 1
            }
            .onChange(of: selectedLayer) { _, newLayer in
                if newLayer != .parsel {
                    fetchedPolygons = []
                    fetchedKeys = []
                    parselFetchTask?.cancel()
                    isFetchingLayer = false
                } else {
                    scheduleParselLayerFetch(at: mapCenter)
                }
            }
            .sheet(isPresented: $showLayerPicker) {
                layerPickerSheet
            }
            .sheet(isPresented: $showNewProject, onDismiss: {
                showParselInfo = false
            }) {
                if let data = projectVM?.parselData {
                    NewProjectView(parselData: data)
                }
            }
        }
    }

    // MARK: - Parsel Layer Auto-Fetch

    private func scheduleParselLayerFetch(at coord: CLLocationCoordinate2D) {
        guard selectedLayer == .parsel else { return }
        parselFetchTask?.cancel()
        parselFetchTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled, selectedLayer == .parsel else { return }
            await fetchParselGeoJSON(at: coord)
        }
    }

    private func fetchParselGeoJSON(at coord: CLLocationCoordinate2D) async {
        isFetchingLayer = true
        defer { isFetchingLayer = false }

        guard let data = try? await TKGMService.shared.fetchParsel(
            latitude: coord.latitude, longitude: coord.longitude
        ) else { return }

        let key = "\(data.ada)/\(data.parsel)/\(data.il)"
        guard !fetchedKeys.contains(key), !data.ada.isEmpty else { return }

        if let koordinatlar = data.koordinatlar,
           let geometry = try? JSONDecoder().decode(ParselGeometry.self, from: koordinatlar) {
            let polygon = geometry.coordinates.first?.map {
                CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
            } ?? []

            guard polygon.count >= 3 else { return }

            fetchedKeys.insert(key)
            fetchedPolygons.append(polygon)

            // Bellek için üst limit
            if fetchedPolygons.count > 80 {
                fetchedPolygons.removeFirst(10)
            }
        }
    }

    // MARK: - Layer Picker Sheet

    private var layerPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(MapLayer.allCases) { layer in
                    Button {
                        selectedLayer = layer
                        showLayerPicker = false
                    } label: {
                        HStack {
                            Label(layer.rawValue, systemImage: layer.icon)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedLayer == layer {
                                Image(systemName: "checkmark").foregroundStyle(.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Harita Katmanı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { showLayerPicker = false }
                }
            }
        }
        .presentationDetents([.height(300)])
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Adres veya konum ara...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.searchAddress() } }
            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Parsel Info Card

    private func parselInfoCard(_ pvm: ProjectViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if pvm.isLoadingParsel {
                HStack {
                    ProgressView()
                    Text("Parsel bilgisi sorgulanıyor...").font(.subheadline)
                }
                .padding()
            } else if let data = pvm.parselData {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Parsel Bulundu").font(.headline)
                        Spacer()
                        Button { showParselInfo = false } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        GridRow {
                            Text("Konum").foregroundStyle(.secondary)
                            Text("\(data.il) / \(data.ilce)")
                        }
                        GridRow {
                            Text("Mahalle").foregroundStyle(.secondary)
                            Text(data.mahalle)
                        }
                        GridRow {
                            Text("Ada/Parsel").foregroundStyle(.secondary)
                            Text("\(data.ada) / \(data.parsel)")
                        }
                        GridRow {
                            Text("Alan").foregroundStyle(.secondary)
                            Text(EmsalCalculator.formatAlan(data.alan)).bold()
                        }
                        if !data.nitelik.isEmpty {
                            GridRow {
                                Text("Nitelik").foregroundStyle(.secondary)
                                Text(data.nitelik)
                            }
                        }
                    }
                    .font(.subheadline)
                    Button("Proje Oluştur") {
                        showNewProject = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding()
            } else if pvm.showError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(pvm.errorMessage ?? "Parsel bulunamadı").font(.subheadline)
                    Spacer()
                    Button("Kapat") { showParselInfo = false }.font(.caption)
                }
                .padding()
            }
        }
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
        .shadow(radius: 8)
    }

    // MARK: - Select Location (Tap)

    private func selectLocation(_ coord: CLLocationCoordinate2D) {
        selectLocationTask?.cancel()

        viewModel.selectedCoordinate = coord
        viewModel.parselPolygon = []

        let project = Project(name: "Haritadan Seçim")
        let pvm = ProjectViewModel(project: project)
        projectVM = pvm
        showParselInfo = true

        selectLocationTask = Task {
            await pvm.fetchParselFromMap(latitude: coord.latitude, longitude: coord.longitude)
            guard !Task.isCancelled else { return }
            if let data = pvm.parselData,
               let koordinatlar = data.koordinatlar,
               let geometry = try? JSONDecoder().decode(ParselGeometry.self, from: koordinatlar) {
                viewModel.updatePolygon(from: geometry)
            }
        }
    }
}
