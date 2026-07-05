import Foundation
import SwiftUI
import SwiftData
import CoreLocation

@MainActor
@Observable
class ProjectViewModel {
    var project: Project
    var hesaplamaSonucu: EmsalCalculator.HesaplamaSonucu?
    var parselData: ParselData?

    var isLoadingParsel = false
    var isGeneratingPDF = false
    var errorMessage: String?
    var showError = false

    var pdfData: Data?

    init(project: Project) {
        self.project = project
    }

    // MARK: - TKGM Parsel Sorgulama

    func fetchParselFromMap(latitude: Double, longitude: Double) async {
        isLoadingParsel = true
        errorMessage = nil

        do {
            let data = try await TKGMService.shared.fetchParsel(latitude: latitude, longitude: longitude)
            parselData = data
            applyParselData(data)
            isLoadingParsel = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoadingParsel = false
        }
    }

    func fetchParselByAddress() async {
        guard !project.il.isEmpty, !project.ada.isEmpty, !project.parsel.isEmpty else {
            errorMessage = "İl, ada ve parsel bilgilerini giriniz"
            showError = true
            return
        }

        isLoadingParsel = true
        errorMessage = nil

        do {
            let data = try await TKGMService.shared.fetchParselByAdaParsel(
                il: project.il,
                ilce: project.ilce,
                mahalle: project.mahalle,
                ada: project.ada,
                parsel: project.parsel
            )
            parselData = data
            applyParselData(data)
            isLoadingParsel = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoadingParsel = false
        }
    }

    private func applyParselData(_ data: ParselData) {
        project.il = data.il
        project.ilce = data.ilce
        project.mahalle = data.mahalle
        project.ada = data.ada
        project.parsel = data.parsel
        project.parselAlani = data.alan
        project.koordinatlar = data.koordinatlar
        project.updatedAt = Date()
    }

    // MARK: - Parsel Boyutları (GeoJSON'dan)

    var parselDimensions: (genislik: Double, derinlik: Double) {
        guard let data = project.koordinatlar,
              let geo = try? JSONDecoder().decode(ParselGeometry.self, from: data)
        else { return (0, 0) }
        return ParselGeometryAnalyzer.boundingBoxDimensions(geo)
    }

    var parselPolygon: [CLLocationCoordinate2D] {
        guard let data = project.koordinatlar,
              let geo = try? JSONDecoder().decode(ParselGeometry.self, from: data)
        else { return [] }
        return geo.coordinates.first?.map {
            CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
        } ?? []
    }

    // MARK: - Hesaplama

    func hesapla() {
        let dims = parselDimensions
        let girdi = EmsalCalculator.HesaplamaGirdisi(
            parselAlani: project.parselAlani,
            taks: project.taks,
            kaks: project.kaks,
            hmax: project.hmax,
            katSayisi: project.katSayisi,
            kullanimTuru: project.kullanimTuru,
            binaTipi: project.binaTipi,
            yapiSinifi: project.yapiSinifi,
            onCekme: project.onCekme,
            arkaCekme: project.arkaCekme,
            yanCekme: project.yanCekme,
            parselGenisligi: dims.genislik,
            parselDerinligi: dims.derinlik,
            binaSayisi: max(1, project.binaSayisi),
            ortDaireAlani: project.ortDaireAlani
        )

        let sonuc = EmsalCalculator.hesapla(girdi)
        hesaplamaSonucu = sonuc

        project.tabanAlani = sonuc.tabanAlani
        project.toplamInsaatAlani = sonuc.toplamInsaatAlani
        project.emsalDisiAlan = sonuc.emsalDisiToplam
        project.brutInsaatAlani = sonuc.brutInsaatAlani
        project.netInsaatAlani = sonuc.netInsaatAlani
        project.otoparkSayisi = sonuc.otoparkSayisi
        project.tahminiBedel = sonuc.tahminiBedel
        project.updatedAt = Date()
    }

    // MARK: - PDF Rapor

    func generatePDF() {
        guard let sonuc = hesaplamaSonucu else {
            hesapla()
            guard let s = hesaplamaSonucu else { return }
            generatePDFWithResult(s)
            return
        }
        generatePDFWithResult(sonuc)
    }

    private func generatePDFWithResult(_ sonuc: EmsalCalculator.HesaplamaSonucu) {
        isGeneratingPDF = true
        pdfData = PDFReportService.generateReport(project: project, sonuc: sonuc)
        isGeneratingPDF = false
    }

    // MARK: - Validation

    var isValidForCalculation: Bool {
        project.parselAlani > 0 &&
        project.taks > 0 &&
        project.kaks > 0 &&
        project.katSayisi > 0
    }
}

// MARK: - Parsel Geometry Analyzer

struct ParselGeometryAnalyzer {

    static func boundingBoxDimensions(_ geo: ParselGeometry) -> (Double, Double) {
        guard let ring = geo.coordinates.first, ring.count >= 3 else { return (0, 0) }
        let pts = metricPoints(ring)
        let xs = pts.map { $0.0 }
        let ys = pts.map { $0.1 }
        let w = (xs.max() ?? 0) - (xs.min() ?? 0)
        let d = (ys.max() ?? 0) - (ys.min() ?? 0)
        return (max(w, 1), max(d, 1))
    }

    // Ring coordinates in metres, centred at polygon centroid
    static func centeredMetricRing(_ geo: ParselGeometry) -> [(Double, Double)] {
        guard let ring = geo.coordinates.first, ring.count >= 3 else { return [] }
        let pts = metricPoints(ring)
        let cx = pts.map { $0.0 }.reduce(0, +) / Double(pts.count)
        let cy = pts.map { $0.1 }.reduce(0, +) / Double(pts.count)
        return pts.map { ($0.0 - cx, $0.1 - cy) }
    }

    private static func metricPoints(_ ring: [[Double]]) -> [(Double, Double)] {
        let centerLat = ring.map { $0[1] }.reduce(0, +) / Double(ring.count)
        let cosLat = cos(centerLat * .pi / 180)
        return ring.map { ($0[0] * 111_320 * cosLat, $0[1] * 110_540) }
    }
}
