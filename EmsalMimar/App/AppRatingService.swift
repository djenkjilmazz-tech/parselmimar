// AppRatingService.swift — App Store değerlendirme isteği
// Yalnızca doğru anlarda sorar: 4. ve 12. oturumda, 120 gün arayla en fazla bir kez.

import StoreKit
import SwiftUI

@MainActor
final class AppRatingService {
    static let shared = AppRatingService()
    private init() {}

    private let defaults = UserDefaults.standard
    private enum Key {
        static let sessions        = "parselmimar.rating.sessions"
        static let lastRequestDate = "parselmimar.rating.lastRequestDate"
    }

    /// İki istek arası minimum süre (Apple zaten yılda 3 ile sınırlar).
    private let cooldown: TimeInterval = 60 * 60 * 24 * 120 // 120 gün

    /// Uygulama her açılışta çağrılır — ilk açılışta asla sormaz.
    func registerSession() {
        let count = defaults.integer(forKey: Key.sessions) + 1
        defaults.set(count, forKey: Key.sessions)
        if count == 4 || count == 12 { requestIfAllowed() }
    }

    private func requestIfAllowed() {
        if let last = defaults.object(forKey: Key.lastRequestDate) as? Date,
           Date().timeIntervalSince(last) < cooldown {
            return
        }
        defaults.set(Date(), forKey: Key.lastRequestDate)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
