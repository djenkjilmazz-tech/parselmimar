import Foundation
import MapKit
import CoreLocation
import SwiftUI

@Observable
class MapViewModel: NSObject, CLLocationManagerDelegate {
    var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597), // Ankara
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    var selectedCoordinate: CLLocationCoordinate2D?
    var parselPolygon: [CLLocationCoordinate2D] = []
    var isLocating = false
    var searchText = ""
    var searchResults: [MKMapItem] = []

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        requestLocation()
    }

    func requestLocation() {
        isLocating = true
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            isLocating = false
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            if isLocating {
                manager.requestLocation()
            }
        } else if manager.authorizationStatus != .notDetermined {
            isLocating = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        isLocating = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
    }

    func selectLocation(_ coordinate: CLLocationCoordinate2D) {
        selectedCoordinate = coordinate
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
        )
    }

    func searchAddress() async {
        guard !searchText.isEmpty else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        request.resultTypes = .address

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            await MainActor.run {
                searchResults = response.mapItems
                if let first = response.mapItems.first {
                    selectLocation(first.placemark.coordinate)
                }
            }
        } catch {
            await MainActor.run {
                searchResults = []
            }
        }
    }

    func updatePolygon(from geometry: ParselGeometry) {
        parselPolygon = geometry.coordinates.first?.map { coord in
            CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        } ?? []
    }

    func updatePolygon(from data: Data) {
        guard let geometry = try? JSONDecoder().decode(ParselGeometry.self, from: data) else { return }
        updatePolygon(from: geometry)
    }
}
