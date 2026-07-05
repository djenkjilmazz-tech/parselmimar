import Foundation
import SwiftData
import CoreLocation

@Model
final class Project {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var notes: String

    // Parsel bilgileri
    var il: String
    var ilce: String
    var mahalle: String
    var ada: String
    var parsel: String
    var parselAlani: Double // m²
    var latitude: Double
    var longitude: Double
    var koordinatlar: Data?

    // İmar bilgileri
    var taks: Double // 0.0 - 1.0
    var kaks: Double // emsal
    var hmax: Double // metre
    var katSayisi: Int
    var binaYuksekligi: Double
    var kullanimTuru: KullanimTuru
    var binaTipi: BinaTipi
    var yapiSinifi: YapiSinifi

    // Çekme mesafeleri
    var onCekme: Double
    var arkaCekme: Double
    var yanCekme: Double

    // Parseldeki bağımsız yapı adedi (ayrık yapı / villa için)
    var binaSayisi: Int

    // Ortalama daire alanı (kullanıcı girişi, otopark hesabı için)
    var ortDaireAlani: Double

    // Hesaplama sonuçları
    var tabanAlani: Double // TAKS * parselAlani
    var toplamInsaatAlani: Double // KAKS * parselAlani
    var emsalDisiAlan: Double
    var brutInsaatAlani: Double
    var netInsaatAlani: Double
    var otoparkSayisi: Int
    var tahminiBedel: Double

    // Rapor
    @Relationship(deleteRule: .cascade) var reports: [EmsalReport]

    init(
        name: String = "",
        il: String = "",
        ilce: String = "",
        mahalle: String = "",
        ada: String = "",
        parsel: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.notes = ""
        self.il = il
        self.ilce = ilce
        self.mahalle = mahalle
        self.ada = ada
        self.parsel = parsel
        self.parselAlani = 0
        self.latitude = 0
        self.longitude = 0
        self.koordinatlar = nil
        self.taks = 0
        self.kaks = 0
        self.hmax = 0
        self.katSayisi = 0
        self.binaYuksekligi = 0
        self.kullanimTuru = .konut
        self.binaTipi = .ayrik
        self.yapiSinifi = .sinif3A
        self.onCekme = 5
        self.arkaCekme = 3
        self.yanCekme = 3
        self.binaSayisi = 1
        self.ortDaireAlani = 0
        self.tabanAlani = 0
        self.toplamInsaatAlani = 0
        self.emsalDisiAlan = 0
        self.brutInsaatAlani = 0
        self.netInsaatAlani = 0
        self.otoparkSayisi = 0
        self.tahminiBedel = 0
        self.reports = []
    }
}

enum KullanimTuru: String, Codable, CaseIterable, Identifiable {
    case konut = "Konut"
    case ticaret = "Ticaret"
    case sanayi = "Sanayi"
    case karma = "Karma"
    case villa = "Villa"
    case turizm = "Turizm"
    case saglik = "Sağlık"
    case egitim = "Eğitim"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .konut: return "house.fill"
        case .ticaret: return "building.2.fill"
        case .sanayi: return "gearshape.2.fill"
        case .karma: return "square.grid.2x2.fill"
        case .villa: return "house.lodge.fill"
        case .turizm: return "bed.double.fill"
        case .saglik: return "cross.case.fill"
        case .egitim: return "graduationcap.fill"
        }
    }
}

enum BinaTipi: String, Codable, CaseIterable, Identifiable {
    case ayrik = "Ayrık"
    case bitisik = "Bitişik"
    case ikiz = "İkiz"
    case blok = "Blok"

    var id: String { rawValue }
}

enum YapiSinifi: String, Codable, CaseIterable, Identifiable {
    case sinif1 = "I. Sınıf"
    case sinif2 = "II. Sınıf"
    case sinif3A = "III-A Sınıf"
    case sinif3B = "III-B Sınıf"
    case sinif4 = "IV. Sınıf"
    case sinif5 = "V. Sınıf"

    var id: String { rawValue }

    var birimMaliyet2026: Double {
        switch self {
        case .sinif1: return 4_850
        case .sinif2: return 7_200
        case .sinif3A: return 10_500
        case .sinif3B: return 13_800
        case .sinif4: return 18_500
        case .sinif5: return 25_000
        }
    }

    var description: String {
        switch self {
        case .sinif1: return "Basit yapılar"
        case .sinif2: return "Normal yapılar"
        case .sinif3A: return "Lüks konut / ticari"
        case .sinif3B: return "Yüksek kalite"
        case .sinif4: return "Özel yapılar"
        case .sinif5: return "Süper lüks"
        }
    }

    // 2464 sayılı BGB Md.80 — 2025 tahmini harç birimi değerleri (TL/m²)
    var harcBirimDegeri2025: Double {
        switch self {
        case .sinif1:  return 11.0
        case .sinif2:  return 18.0
        case .sinif3A: return 27.0
        case .sinif3B: return 40.0
        case .sinif4:  return 58.0
        case .sinif5:  return 85.0
        }
    }
}
