import Foundation
import SwiftData

@Model
final class EmsalReport {
    var id: UUID
    var createdAt: Date
    var projectName: String
    var pdfData: Data?

    // Özet bilgiler
    var parselAlani: Double
    var taks: Double
    var kaks: Double
    var tabanAlani: Double
    var toplamInsaatAlani: Double
    var emsalDisiToplam: Double
    var brutInsaatAlani: Double
    var katSayisi: Int
    var otoparkSayisi: Int
    var tahminiBedel: Double

    // Emsal dışı kalemler
    var siginakAlani: Double
    var mescitAlani: Double
    var otoparkAlani: Double
    var merdivenAlani: Double
    var asansorAlani: Double
    var depoAlani: Double
    var teknikAlan: Double

    init(projectName: String = "") {
        self.id = UUID()
        self.createdAt = Date()
        self.projectName = projectName
        self.pdfData = nil
        self.parselAlani = 0
        self.taks = 0
        self.kaks = 0
        self.tabanAlani = 0
        self.toplamInsaatAlani = 0
        self.emsalDisiToplam = 0
        self.brutInsaatAlani = 0
        self.katSayisi = 0
        self.otoparkSayisi = 0
        self.tahminiBedel = 0
        self.siginakAlani = 0
        self.mescitAlani = 0
        self.otoparkAlani = 0
        self.merdivenAlani = 0
        self.asansorAlani = 0
        self.depoAlani = 0
        self.teknikAlan = 0
    }
}
