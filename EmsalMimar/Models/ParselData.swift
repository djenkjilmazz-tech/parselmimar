import Foundation
import SwiftData
import CoreLocation

@Model
final class ParselData {
    var id: UUID
    var il: String
    var ilce: String
    var mahalle: String
    var ada: String
    var parsel: String
    var alan: Double
    var nitelik: String
    var mevkii: String
    var koordinatlar: Data? // GeoJSON polygon encoded
    var fetchedAt: Date

    init(
        il: String = "",
        ilce: String = "",
        mahalle: String = "",
        ada: String = "",
        parsel: String = "",
        alan: Double = 0,
        nitelik: String = "",
        mevkii: String = ""
    ) {
        self.id = UUID()
        self.il = il
        self.ilce = ilce
        self.mahalle = mahalle
        self.ada = ada
        self.parsel = parsel
        self.alan = alan
        self.nitelik = nitelik
        self.mevkii = mevkii
        self.koordinatlar = nil
        self.fetchedAt = Date()
    }
}

struct TKGMParselResponse: Codable {
    let properties: ParselProperties?
    let geometry: ParselGeometry?
}

struct ParselProperties: Codable {
    let il: String?
    let ilce: String?
    let mahalle: String?
    let ada: String?
    let parsel: String?
    let alan: Double?
    let nitelik: String?
    let mevkii: String?
}

struct ParselGeometry: Codable {
    let type: String
    let coordinates: [[[Double]]]
}

struct GeoJSONFeature: Codable {
    let type: String
    let geometry: ParselGeometry
    let properties: ParselProperties?
}

struct GeoJSONFeatureCollection: Codable {
    let type: String
    let features: [GeoJSONFeature]
}
