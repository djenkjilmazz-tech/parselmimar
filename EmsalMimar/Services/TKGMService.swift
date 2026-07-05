import Foundation
import CoreLocation

// MARK: - İmar Bilgisi

struct ImarBilgisi {
    let taks: Double
    let kaks: Double
    let hmax: Double
    let katSayisi: Int
    let kullanim: String   // API'dan gelen kullanım türü (varsa)
    let kaynak: String     // "TKGM" / "CSB Mekanbul" / "İBB" / "Ankara" vb.
}

actor TKGMService {
    static let shared = TKGMService()

    private let parselAPIBase = "https://cbsapi.tkgm.gov.tr/megsiswebapi.v3/api/parsel"
    private let session: URLSession
    private let imarSession: URLSession  // kısa timeout — imar endpoint'leri spekülatif

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.timeoutIntervalForResource = 25
        self.session = URLSession(configuration: cfg)

        let imarCfg = URLSessionConfiguration.default
        imarCfg.timeoutIntervalForRequest = 5   // 5s per endpoint, max ~15s total
        imarCfg.timeoutIntervalForResource = 8
        self.imarSession = URLSession(configuration: imarCfg)
    }

    // MARK: - Parsel

    func fetchParsel(latitude: Double, longitude: Double) async throws -> ParselData {
        let urlString = "\(parselAPIBase)/\(latitude)/\(longitude)"
        guard let url = URL(string: urlString) else { throw TKGMError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TKGMError.serverError
        }
        return try parseFeature(from: data)
    }

    func fetchParselByAdaParsel(il: String, ilce: String, mahalle: String, ada: String, parsel: String) async throws -> ParselData {
        // Her path bileşenini ayrı encode et; boş mahalle URL'i bozmayacak şekilde atla
        var components = [il, ilce]
        if !mahalle.trimmingCharacters(in: .whitespaces).isEmpty {
            components.append(mahalle)
        }
        components.append(contentsOf: [ada, parsel])

        let encoded = components.map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
        let urlString = parselAPIBase + "/" + encoded.joined(separator: "/")

        guard let url = URL(string: urlString) else { throw TKGMError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TKGMError.serverError
        }
        // TKGM il/ilce yolunu WAF ile engelliyor: JSON yerine HTML döner
        if let prefix = String(data: data.prefix(30), encoding: .utf8),
           prefix.trimmingCharacters(in: .whitespaces).hasPrefix("<") {
            throw TKGMError.apiBlocked
        }
        return try parseFeature(from: data)
    }

    // MARK: - İmar Bilgisi (çoklu kaynak)

    /// Sırayla gerçek API'ları dener. Hiçbirinden veri gelmezse nil döner.
    func fetchImarBilgisi(latitude: Double, longitude: Double, il: String) async -> ImarBilgisi? {
        guard latitude != 0, longitude != 0 else { return nil }

        if let r = await queryTKGMImarSafe(lat: latitude, lon: longitude) { return r }

        if let r = try? await queryCSBMekanbul(lat: latitude, lon: longitude),
           r.taks > 0 || r.kaks > 0 { return r }

        if let r = try? await queryMunicipalWFS(lat: latitude, lon: longitude, il: il),
           r.taks > 0 || r.kaks > 0 { return r }

        return nil
    }

    // MARK: - Endpoint 1: TKGM imar (çoklu varyant)

    private func queryTKGMImarSafe(lat: Double, lon: Double) async -> ImarBilgisi? {
        let base = "https://cbsapi.tkgm.gov.tr/megsiswebapi.v3/api"
        for path in ["imarbilgisi", "parselimarbilgisi", "imar"] {
            guard let url = URL(string: "\(base)/\(path)/\(lat)/\(lon)"),
                  let (data, resp) = try? await imarSession.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let r = try? parseGenericImarJSON(data, kaynak: "TKGM"),
                  r.taks > 0 || r.kaks > 0 else { continue }
            return r
        }
        return nil
    }

    // MARK: - Endpoint 2: CSB Mekanbul ArcGIS REST (çoklu servis yolu)

    private func queryCSBMekanbul(lat: Double, lon: Double) async throws -> ImarBilgisi {
        let servicePaths = [
            "Imar/UygImarPl/MapServer/0",
            "IMAR/UygulanaImarPlani/MapServer/0",
            "ImarPlani/UygImarPlani/MapServer/0"
        ]
        for path in servicePaths {
            var c = URLComponents(string: "https://mekanbul.csb.gov.tr/arcgis/rest/services/\(path)/query")!
            c.queryItems = [
                .init(name: "geometry",       value: "\(lon),\(lat)"),
                .init(name: "geometryType",   value: "esriGeometryPoint"),
                .init(name: "inSR",           value: "4326"),
                .init(name: "spatialRel",     value: "esriSpatialRelIntersects"),
                .init(name: "outFields",      value: "*"),
                .init(name: "returnGeometry", value: "false"),
                .init(name: "f",              value: "json")
            ]
            guard let url = c.url,
                  let (data, resp) = try? await imarSession.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let r = try? parseArcGISFeatureJSON(data, kaynak: "CSB Mekanbul"),
                  r.taks > 0 || r.kaks > 0 else { continue }
            return r
        }
        throw TKGMError.parselNotFound
    }

    // MARK: - Endpoint 3: Belediye özgü WFS / ArcGIS

    private func queryMunicipalWFS(lat: Double, lon: Double, il: String) async throws -> ImarBilgisi {
        switch Self.normalizeIl(il) {
        case "istanbul":
            return try await queryIBBImar(lat: lat, lon: lon)
        case "ankara":
            return try await queryAnkaraImar(lat: lat, lon: lon)
        case "izmir":
            return try await queryWFS("https://webgis.izmir.bel.tr/geoserver/ows",
                                      layers: ["IMAR:PLAN", "IMAR:UYGULAMA_IMAR_PLANI", "izmir:imar"],
                                      lat: lat, lon: lon, kaynak: "İzmir Büyükşehir")
        case "bursa":
            return try await queryWFS("https://cbsportal.bursa.bel.tr/geoserver/ows",
                                      layers: ["IMAR:IMAR_PLAN", "bursa:uip"],
                                      lat: lat, lon: lon, kaynak: "Bursa Büyükşehir")
        case "antalya":
            return try await queryWFS("https://webgis.antalya.bel.tr/geoserver/ows",
                                      layers: ["IMAR:UYGULAMA_IMAR_PLANI", "imar:plan"],
                                      lat: lat, lon: lon, kaynak: "Antalya BB")
        case "kocaeli":
            return try await queryWFS("https://webgis.kocaeli.bel.tr/geoserver/ows",
                                      layers: ["IMAR:IMAR_PLAN", "imar:uip"],
                                      lat: lat, lon: lon, kaynak: "Kocaeli BB")
        case "adana":
            return try await queryWFS("https://webgis.adana.bel.tr/geoserver/ows",
                                      layers: ["IMAR:UYGULAMA_IMAR_PLANI"],
                                      lat: lat, lon: lon, kaynak: "Adana BB")
        case "konya":
            return try await queryWFS("https://webgis.konya.bel.tr/geoserver/ows",
                                      layers: ["IMAR:UYGULAMA_IMAR_PLANI"],
                                      lat: lat, lon: lon, kaynak: "Konya BB")
        case "mersin":
            return try await queryWFS("https://webgis.mersin.bel.tr/geoserver/ows",
                                      layers: ["IMAR:UIP", "IMAR:IMAR_PLANI"],
                                      lat: lat, lon: lon, kaynak: "Mersin BB")
        case "gaziantep":
            return try await queryWFS("https://webgis.gaziantep.bel.tr/geoserver/ows",
                                      layers: ["IMAR:UYGULAMA_IMAR_PLANI"],
                                      lat: lat, lon: lon, kaynak: "Gaziantep BB")
        case "samsun":
            return try await queryWFS("https://webgis.samsun.bel.tr/geoserver/ows",
                                      layers: ["IMAR:IMAR_PLANI", "samsun:uip"],
                                      lat: lat, lon: lon, kaynak: "Samsun BB")
        case "eskisehir":
            return try await queryWFS("https://webgis.eskisehir.bel.tr/geoserver/ows",
                                      layers: ["IMAR:UIP", "IMAR:UYGULAMA_IMAR_PLANI"],
                                      lat: lat, lon: lon, kaynak: "Eskişehir BB")
        case "diyarbakir":
            return try await queryWFS("https://webgis.diyarbakir.bel.tr/geoserver/ows",
                                      layers: ["IMAR:UYGULAMA_IMAR_PLANI"],
                                      lat: lat, lon: lon, kaynak: "Diyarbakır BB")
        default:
            throw TKGMError.parselNotFound
        }
    }

    // MARK: - WFS Yardımcı (BBOX — geometry sütun adından bağımsız)

    private func makeWFSBboxUrl(base: String, typeName: String, lat: Double, lon: Double) -> URL? {
        let d = 0.0003  // ~33 metre buffer
        var c = URLComponents(string: base)!
        c.queryItems = [
            .init(name: "service",      value: "WFS"),
            .init(name: "version",      value: "2.0.0"),
            .init(name: "request",      value: "GetFeature"),
            .init(name: "typeNames",    value: typeName),
            .init(name: "count",        value: "1"),
            .init(name: "outputFormat", value: "application/json"),
            .init(name: "bbox",         value: "\(lon-d),\(lat-d),\(lon+d),\(lat+d),EPSG:4326")
        ]
        return c.url
    }

    private func queryWFS(_ base: String, layers: [String], lat: Double, lon: Double, kaynak: String) async throws -> ImarBilgisi {
        for layer in layers {
            guard let url = makeWFSBboxUrl(base: base, typeName: layer, lat: lat, lon: lon),
                  let (data, resp) = try? await imarSession.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let r = try? parseGeoServerJSON(data, kaynak: kaynak),
                  r.taks > 0 || r.kaks > 0 else { continue }
            return r
        }
        throw TKGMError.parselNotFound
    }

    private func queryIBBImar(lat: Double, lon: Double) async throws -> ImarBilgisi {
        return try await queryWFS(
            "https://sehirharitasi.ibb.gov.tr/geoserver/ows",
            layers: ["IMAR:IMAR_PLAN", "ibplan:UYGULAMA_IMAR_PLANI", "ibplan:UIP", "sehirharitasi:imar_plankararalama"],
            lat: lat, lon: lon,
            kaynak: "İBB Şehir Haritası"
        )
    }

    private func queryAnkaraImar(lat: Double, lon: Double) async throws -> ImarBilgisi {
        // Önce ArcGIS REST dene
        for path in ["IMAR/UYGULAMA_IMAR_PLANI/MapServer/0", "IMARHizmetleri/UygImarPlani/MapServer/0"] {
            var c = URLComponents(string: "https://cbsservis.ankara.bel.tr/arcgis/rest/services/\(path)/query")!
            c.queryItems = [
                .init(name: "geometry",       value: "\(lon),\(lat)"),
                .init(name: "geometryType",   value: "esriGeometryPoint"),
                .init(name: "inSR",           value: "4326"),
                .init(name: "spatialRel",     value: "esriSpatialRelIntersects"),
                .init(name: "outFields",      value: "*"),
                .init(name: "returnGeometry", value: "false"),
                .init(name: "f",              value: "json")
            ]
            guard let url = c.url,
                  let (data, resp) = try? await imarSession.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let r = try? parseArcGISFeatureJSON(data, kaynak: "Ankara CBS"),
                  r.taks > 0 || r.kaks > 0 else { continue }
            return r
        }
        // WFS fallback
        return try await queryWFS(
            "https://cbsservis.ankara.bel.tr/geoserver/ows",
            layers: ["IMAR:UYGULAMA_IMAR_PLANI", "imar:uip"],
            lat: lat, lon: lon,
            kaynak: "Ankara CBS"
        )
    }

    // MARK: - Response Parsers

    /// Generic JSON: { properties: { taks, kaks, hmax, ... } }
    private func parseGenericImarJSON(_ data: Data, kaynak: String) throws -> ImarBilgisi {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let props = (json["properties"] as? [String: Any]) ?? (json["attributes"] as? [String: Any])
        else { throw TKGMError.parselNotFound }
        return extractImar(from: props, kaynak: kaynak)
    }

    /// ArcGIS REST: { features: [ { attributes: { TAKS, KAKS, ... } } ] }
    private func parseArcGISFeatureJSON(_ data: Data, kaynak: String) throws -> ImarBilgisi {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]],
              let first = features.first,
              let attrs = first["attributes"] as? [String: Any]
        else { throw TKGMError.parselNotFound }
        return extractImar(from: attrs, kaynak: kaynak)
    }

    /// GeoServer WFS GeoJSON: { features: [ { properties: { TAKS, KAKS, ... } } ] }
    private func parseGeoServerJSON(_ data: Data, kaynak: String) throws -> ImarBilgisi {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]],
              let first = features.first,
              let props = first["properties"] as? [String: Any]
        else { throw TKGMError.parselNotFound }
        return extractImar(from: props, kaynak: kaynak)
    }

    private func extractImar(from props: [String: Any], kaynak: String) -> ImarBilgisi {
        func dbl(_ keys: [String]) -> Double {
            for k in keys {
                if let v = props[k] as? Double, v > 0 { return v }
                if let v = props[k.uppercased()] as? Double, v > 0 { return v }
                if let v = props[k.lowercased()] as? Double, v > 0 { return v }
                if let s = (props[k] ?? props[k.uppercased()] ?? props[k.lowercased()]) as? String {
                    let v = TKGMService.parseLocaleDouble(s)
                    if v > 0 { return v }
                }
            }
            return 0
        }
        let taks = dbl(["taks", "TAKS", "tabanAlaniKatSayisi", "TABAN_ALANI_KAT_SAYISI"])
        let kaks = dbl(["kaks", "KAKS", "emsal", "EMSAL", "katAlaniKatSayisi", "KAT_ALANI_KAT_SAYISI"])
        let hmax = dbl(["hmax", "HMAX", "hMax", "maksimumYukseklik", "MAKS_YUKSEKLIK", "yukseklik"])
        let kat  = dbl(["katSayisi", "KAT_ADEDI", "maxKat", "MAX_KAT", "katAdedi"])
        let kullanim = (props["KULLANIMSEKLI"] ?? props["kullanimSekli"] ?? props["KULLANIMTURU"] ?? props["kullanim"]) as? String ?? ""
        let katSayisi = kat > 0 ? Int(kat) : (hmax > 0 ? max(1, Int((hmax - 3.0) / 3.0)) : 0)
        return ImarBilgisi(taks: taks, kaks: kaks, hmax: hmax, katSayisi: katSayisi, kullanim: kullanim, kaynak: kaynak)
    }

    // MARK: - WebGIS URL

    /// Belediyenin WebGIS imar haritası URL'ini döner (tarayıcıda açılmak için).
    static func webGISUrl(il: String, lat: Double, lon: Double) -> URL {
        let norm = normalizeIl(il)
        switch norm {
        case "istanbul":
            return URL(string: "https://sehirharitasi.ibb.gov.tr/#lat=\(lat)&lng=\(lon)&zoom=18")
                ?? URL(string: "https://sehirharitasi.ibb.gov.tr")!
        case "ankara":
            return URL(string: "https://cbsservis.ankara.bel.tr/mapi/?lat=\(lat)&lng=\(lon)&zoom=18")
                ?? URL(string: "https://cbsservis.ankara.bel.tr")!
        case "izmir":
            return URL(string: "https://webgis.izmir.bel.tr/")!
        case "bursa":
            return URL(string: "https://cbsportal.bursa.bel.tr/")!
        case "antalya":
            return URL(string: "https://webgis.antalya.bel.tr/")!
        case "konya":
            return URL(string: "https://webgis.konya.bel.tr/")!
        case "gaziantep":
            return URL(string: "https://webgis.gaziantep.bel.tr/")!
        case "kocaeli":
            return URL(string: "https://webgis.kocaeli.bel.tr/")!
        case "mersin":
            return URL(string: "https://webgis.mersin.bel.tr/")!
        case "samsun":
            return URL(string: "https://webgis.samsun.bel.tr/")!
        case "eskisehir":
            return URL(string: "https://webgis.eskisehir.bel.tr/")!
        default:
            // e-Devlet üzerinden tüm belediyeler için çalışır
            return URL(string: "https://eimar.gov.tr")!
        }
    }

    static func normalizeIl(_ il: String) -> String {
        // Büyük Türkçe harfleri önce değiştir (İ→i sorunu: .lowercased() ile i+U+0307 oluşur)
        il.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "İ", with: "i")
            .replacingOccurrences(of: "I", with: "i")
            .replacingOccurrences(of: "Ş", with: "s")
            .replacingOccurrences(of: "Ç", with: "c")
            .replacingOccurrences(of: "Ğ", with: "g")
            .replacingOccurrences(of: "Ü", with: "u")
            .replacingOccurrences(of: "Ö", with: "o")
            .lowercased()
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "ğ", with: "g")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ç", with: "c")
    }

    // MARK: - Parsing

    private func parseFeature(from data: Data) throws -> ParselData {
        let decoder = JSONDecoder()
        let feature = try decoder.decode(TKGMFeatureResponse.self, from: data)
        guard let props = feature.properties else { throw TKGMError.parselNotFound }
        let alanValue = parseAlan(from: props.alan, geometry: feature.geometry)
        let parsel = ParselData(
            il: props.ilAd ?? "",
            ilce: props.ilceAd ?? "",
            mahalle: props.mahalleAd ?? "",
            ada: props.adaNo ?? "",
            parsel: props.parselNo ?? "",
            alan: alanValue,
            nitelik: props.nitelik ?? "",
            mevkii: props.mevkii ?? ""
        )
        if let geometry = feature.geometry,
           let encoded = try? JSONEncoder().encode(geometry) {
            parsel.koordinatlar = encoded
        }
        return parsel
    }

    private func parseAlan(from alanString: String?, geometry: ParselGeometry?) -> Double {
        // GeoJSON geometrisi varsa ondan hesapla — TKGM bazen "alan" alanını
        // m² yerine are (1 are = 100 m²) olarak döndürüyor; geometri her zaman doğru.
        if let geometry {
            let geoArea = calculateAreaFromGeoJSON(geometry)
            if geoArea > 0 { return geoArea }
        }
        // Geometri yoksa string değerini kullan
        if let str = alanString {
            let value = Self.parseLocaleDouble(str)
            if value > 0 { return value }
        }
        return 0
    }

    /// Hem Türkçe ("1.234,56") hem uluslararası ("1234.56") ve binlik noktalı ("1.200") formatı doğru çözümler.
    static func parseLocaleDouble(_ s: String) -> Double {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return 0 }

        if t.contains(",") {
            // Türkçe format: nokta = binlik ayraç, virgül = ondalık
            let normalized = t
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
            return Double(normalized) ?? 0
        }

        // Nokta var ama virgül yok: ya ondalık ("1234.56") ya Türkçe binlik ("1.200", "12.345")
        let dotParts = t.components(separatedBy: ".")
        if dotParts.count == 2 {
            let beforeDot = dotParts[0], afterDot = dotParts[1]
            let allDigits = { (str: String) in str.allSatisfy(\.isNumber) }
            // Nokta sonrası tam 3 rakam ve her iki parça rakamdan oluşuyorsa → binlik ayraç
            if afterDot.count == 3 && allDigits(afterDot) && allDigits(beforeDot) && !beforeDot.isEmpty {
                return Double(beforeDot + afterDot) ?? 0  // "1.200" → 1200
            }
            return Double(t) ?? 0  // "1234.56" → 1234.56
        }
        if dotParts.count > 2 {
            // "1.234.567" → tüm noktalar binlik ayraç
            let joined = dotParts.joined()
            return Double(joined) ?? 0
        }
        return Double(t) ?? 0
    }

    private func calculateAreaFromGeoJSON(_ geometry: ParselGeometry) -> Double {
        guard let ring = geometry.coordinates.first, ring.count >= 3 else { return 0 }
        let earthRadius = 6_371_000.0
        let toRad = Double.pi / 180
        var area = 0.0
        let n = ring.count
        for i in 0..<n {
            let j = (i + 1) % n
            let lon1 = ring[i][0] * toRad, lat1 = ring[i][1] * toRad
            let lon2 = ring[j][0] * toRad, lat2 = ring[j][1] * toRad
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }
        return abs(area) * earthRadius * earthRadius / 2
    }
}

// MARK: - API Response Models

struct TKGMFeatureResponse: Decodable {
    let type: String?
    let properties: TKGMProperties?
    let geometry: ParselGeometry?
}

struct TKGMProperties: Decodable {
    let ilAd: String?
    let ilceAd: String?
    let mahalleAd: String?
    let adaNo: String?
    let parselNo: String?
    let alan: String?   // JSON'da String veya Number gelebilir
    let nitelik: String?
    let mevkii: String?

    enum CodingKeys: String, CodingKey {
        case ilAd, ilceAd, mahalleAd, adaNo, parselNo, alan, nitelik, mevkii
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ilAd      = try? c.decode(String.self, forKey: .ilAd)
        ilceAd    = try? c.decode(String.self, forKey: .ilceAd)
        mahalleAd = try? c.decode(String.self, forKey: .mahalleAd)
        adaNo     = try? c.decode(String.self, forKey: .adaNo)
        parselNo  = try? c.decode(String.self, forKey: .parselNo)
        nitelik   = try? c.decode(String.self, forKey: .nitelik)
        mevkii    = try? c.decode(String.self, forKey: .mevkii)

        // alan: API bazı versiyonlarda String, bazılarında Double/Int döndürür
        if let s = try? c.decode(String.self, forKey: .alan), !s.isEmpty {
            alan = s
        } else if let d = try? c.decode(Double.self, forKey: .alan) {
            alan = String(d)        // "500.0" — parseLocaleDouble bunu doğru okur
        } else if let i = try? c.decode(Int.self, forKey: .alan) {
            alan = String(i)
        } else {
            alan = nil
        }
    }
}

// MARK: - Nitelik → İmar Tahmini (Endexer tablosu)

extension TKGMService {

    /// TKGM parsel niteliğinden TAKS/KAKS/kat tahmini üretir.
    /// Gerçek imar planı verisi değil — resmi onay için belediyeye başvurun.
    static func imarFromNitelik(_ nitelik: String, il: String) -> ImarBilgisi? {
        guard !nitelik.isEmpty else { return nil }
        // Büyük + küçük Türkçe harfleri önce değiştir, sonra lowercase yap
        let norm = nitelik.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "İ", with: "i")
            .replacingOccurrences(of: "I", with: "i")
            .replacingOccurrences(of: "Ş", with: "s")
            .replacingOccurrences(of: "Ç", with: "c")
            .replacingOccurrences(of: "Ğ", with: "g")
            .replacingOccurrences(of: "Ü", with: "u")
            .replacingOccurrences(of: "Ö", with: "o")
            .lowercased()
            .replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "ç", with: "c")
            .replacingOccurrences(of: "ğ", with: "g")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ı", with: "i")

        // Şehre göre arsa değerleri
        let ilZone: (kaks: Double, maxKat: Int) = {
            switch normalizeIl(il) {
            case "istanbul":  return (2.0, 8)
            case "ankara":    return (1.8, 6)
            case "izmir":     return (1.8, 6)
            case "bursa":     return (1.5, 5)
            case "antalya":   return (1.5, 5)
            case "adana":     return (1.5, 5)
            case "konya":     return (1.5, 5)
            case "kocaeli":   return (1.8, 6)
            case "mersin":    return (1.5, 5)
            case "gaziantep": return (1.5, 5)
            default:          return (1.5, 4)
            }
        }()

        struct NitelikKural { let anahtar: String; let taks: Double; let kaks: Double; let maxKat: Int; let amac: String }
        // Daha özel (uzun) anahtarlar önce gelir — "mesken" hem "bahceli mesken" hem de "mesken"'e uyar
        let tablo: [NitelikKural] = [
            NitelikKural(anahtar: "kat irtifakli arsa",  taks: 0.40, kaks: 2.5, maxKat: 10, amac: "Yoğun Konut"),
            NitelikKural(anahtar: "kat mulkiyeti",       taks: 0.40, kaks: 2.5, maxKat: 10, amac: "Yoğun Konut"),
            NitelikKural(anahtar: "kat irtifaki",        taks: 0.40, kaks: 2.5, maxKat: 10, amac: "Yoğun Konut"),
            NitelikKural(anahtar: "bahceli mesken",      taks: 0.30, kaks: 0.8, maxKat:  3, amac: "Bahçeli Konut"),
            NitelikKural(anahtar: "bahceli ev",          taks: 0.30, kaks: 0.8, maxKat:  3, amac: "Bahçeli Konut"),
            NitelikKural(anahtar: "mesken",              taks: 0.40, kaks: 1.5, maxKat:  5, amac: "Konut"),
            NitelikKural(anahtar: "villa",               taks: 0.25, kaks: 0.8, maxKat:  3, amac: "Villa / Müstakil"),
            NitelikKural(anahtar: "dukkan",              taks: 0.50, kaks: 3.0, maxKat: 12, amac: "Ticari"),
            NitelikKural(anahtar: "isyeri",              taks: 0.50, kaks: 3.0, maxKat: 12, amac: "Ticari"),
            NitelikKural(anahtar: "plaza",               taks: 0.50, kaks: 4.0, maxKat: 20, amac: "Ticari"),
            NitelikKural(anahtar: "otel",                taks: 0.50, kaks: 3.0, maxKat: 15, amac: "Turizm / Otel"),
            NitelikKural(anahtar: "fabrika",             taks: 0.50, kaks: 1.0, maxKat:  3, amac: "Sanayi"),
            NitelikKural(anahtar: "depo",                taks: 0.50, kaks: 1.0, maxKat:  3, amac: "Sanayi / Depo"),
            NitelikKural(anahtar: "zeytinlik",           taks: 0.00, kaks: 0.0, maxKat:  0, amac: "Zeytinlik"),
            NitelikKural(anahtar: "tarla",               taks: 0.00, kaks: 0.0, maxKat:  0, amac: "Tarım (Yapılaşmaz)"),
            NitelikKural(anahtar: "bahce",               taks: 0.10, kaks: 0.2, maxKat:  1, amac: "Tarım / Bahçe"),
            NitelikKural(anahtar: "bag",                 taks: 0.10, kaks: 0.2, maxKat:  1, amac: "Bağ / Bahçe"),
            // "arsa" son — diğer eşleşmeler önce denenmeli
            NitelikKural(anahtar: "arsa",                taks: 0.40, kaks: ilZone.kaks, maxKat: ilZone.maxKat, amac: "Konut / Karma"),
        ]

        for kural in tablo {
            if norm.contains(kural.anahtar) {
                return ImarBilgisi(
                    taks: kural.taks,
                    kaks: kural.kaks,
                    hmax: Double(kural.maxKat) * 3.0,
                    katSayisi: kural.maxKat,
                    kullanim: kural.amac,
                    kaynak: "Nitelik tahmini (\(nitelik))"
                )
            }
        }
        return nil
    }
}

// MARK: - Errors

enum TKGMError: LocalizedError {
    case invalidURL
    case serverError
    case parselNotFound
    case decodingError
    case apiBlocked

    var errorDescription: String? {
        switch self {
        case .invalidURL:      return "Geçersiz URL"
        case .serverError:     return "TKGM sunucusuna bağlanılamadı"
        case .parselNotFound:  return "Bu konumda parsel bulunamadı"
        case .decodingError:   return "Veri okunamadı"
        case .apiBlocked:      return "TKGM ada/parsel servisi erişilemez — haritadan konum seçin"
        }
    }
}
