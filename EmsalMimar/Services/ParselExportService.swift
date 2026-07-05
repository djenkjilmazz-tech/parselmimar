import Foundation
import CoreLocation

// MARK: - Parsel Export (KML / DXF / GeoJSON)

enum ParselExportService {

    // MARK: - KML

    /// Parsel poligonundan Google Earth / Maps uyumlu KML dosyası üretir.
    static func generateKML(
        name: String,
        il: String, ilce: String, ada: String, parsel: String,
        taks: Double, kaks: Double,
        koordinatlar: Data?
    ) -> Data? {
        guard let coords = polygon(from: koordinatlar), coords.count >= 3 else { return nil }

        let coordStr = coords
            .map { String(format: "%.6f,%.6f,0", $0.longitude, $0.latitude) }
            .joined(separator: "\n              ")

        let desc = [
            il.isEmpty ? "" : "İl: \(il)",
            ilce.isEmpty ? "" : "İlçe: \(ilce)",
            ada.isEmpty ? "" : "Ada/Parsel: \(ada)/\(parsel)",
            taks > 0 ? String(format: "TAKS: %.2f", taks) : "",
            kaks > 0 ? String(format: "KAKS: %.2f", kaks) : "",
        ].filter { !$0.isEmpty }.joined(separator: "&#10;")

        let kml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2">
          <Document>
            <name>\(xmlEscape(name))</name>
            <Style id="parselStyle">
              <LineStyle>
                <color>ff00aaff</color>
                <width>3</width>
              </LineStyle>
              <PolyStyle>
                <color>3300aaff</color>
              </PolyStyle>
            </Style>
            <Placemark>
              <name>\(xmlEscape(name))</name>
              <description>\(desc)</description>
              <styleUrl>#parselStyle</styleUrl>
              <Polygon>
                <tessellate>1</tessellate>
                <outerBoundaryIs>
                  <LinearRing>
                    <coordinates>
              \(coordStr)
                    </coordinates>
                  </LinearRing>
                </outerBoundaryIs>
              </Polygon>
            </Placemark>
          </Document>
        </kml>
        """
        return kml.data(using: .utf8)
    }

    // MARK: - DXF

    /// Parsel poligonundan AutoCAD / LibreCAD uyumlu DXF dosyası üretir (R12 format).
    static func generateDXF(
        name: String,
        koordinatlar: Data?
    ) -> Data? {
        guard let coords = polygon(from: koordinatlar), coords.count >= 3 else { return nil }

        var dxf = ""

        // Header
        dxf += "0\nSECTION\n2\nHEADER\n"
        dxf += "9\n$ACADVER\n1\nAC1009\n"
        dxf += "0\nENDSEC\n"

        // Tables
        dxf += "0\nSECTION\n2\nTABLES\n"
        dxf += "0\nTABLE\n2\nLAYER\n70\n1\n"
        dxf += "0\nLAYER\n2\nPARSEL\n70\n0\n62\n3\n6\nCONTINUOUS\n"
        dxf += "0\nENDTAB\n"
        dxf += "0\nENDSEC\n"

        // Entities
        dxf += "0\nSECTION\n2\nENTITIES\n"

        // LWPOLYLINE (closed polygon)
        dxf += "0\nLWPOLYLINE\n"
        dxf += "8\nPARSEL\n"
        dxf += "90\n\(coords.count)\n"
        dxf += "70\n1\n"

        for c in coords {
            dxf += String(format: "10\n%.6f\n20\n%.6f\n", c.longitude, c.latitude)
        }

        // Parsel adı metin etiketi
        let center = centroid(of: coords)
        dxf += "0\nTEXT\n"
        dxf += "8\nPARSEL\n"
        dxf += String(format: "10\n%.6f\n20\n%.6f\n30\n0.0\n", center.longitude, center.latitude)
        dxf += "40\n0.00005\n"
        dxf += "1\n\(name)\n"

        dxf += "0\nENDSEC\n"
        dxf += "0\nEOF\n"

        return dxf.data(using: .utf8)
    }

    // MARK: - GeoJSON

    /// Ham GeoJSON polygon verisini CBS/QGIS uyumlu FeatureCollection olarak üretir.
    static func generateGeoJSON(
        name: String,
        il: String, ilce: String, ada: String, parsel: String,
        taks: Double, kaks: Double, alan: Double,
        koordinatlar: Data?
    ) -> Data? {
        guard let rawGeom = koordinatlar,
              let geometry = try? JSONDecoder().decode(ParselGeometry.self, from: rawGeom)
        else { return nil }

        let coordArrays = geometry.coordinates.map { ring in
            ring.map { p in "[\(String(format: "%.6f", p[0])), \(String(format: "%.6f", p[1]))]" }
                .joined(separator: ",")
        }.map { "[\($0)]" }.joined(separator: ",")

        let json = """
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "Polygon",
                "coordinates": [\(coordArrays)]
              },
              "properties": {
                "name": "\(jsonEscape(name))",
                "il": "\(jsonEscape(il))",
                "ilce": "\(jsonEscape(ilce))",
                "ada": "\(jsonEscape(ada))",
                "parsel": "\(jsonEscape(parsel))",
                "alan_m2": \(String(format: "%.2f", alan)),
                "taks": \(taks),
                "kaks": \(kaks),
                "kaynak": "TKGM MEGSİS CBS"
              }
            }
          ]
        }
        """
        return json.data(using: .utf8)
    }

    // MARK: - Helpers

    private static func polygon(from data: Data?) -> [CLLocationCoordinate2D]? {
        guard let data,
              let geo = try? JSONDecoder().decode(ParselGeometry.self, from: data),
              let ring = geo.coordinates.first, !ring.isEmpty
        else { return nil }
        return ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
    }

    private static func centroid(of coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        let lat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let lon = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func jsonEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
