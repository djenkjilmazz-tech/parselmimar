import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var storeKit: StoreKitService
    @State private var showPaywall = false
    @State private var showRestoreAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: storeKit.isPro ? "crown.fill" : "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(storeKit.isPro ? .yellow : .accent)

                        VStack(alignment: .leading) {
                            Text(storeKit.isPro ? "Pro Üye" : "Ücretsiz Plan")
                                .font(.headline)
                            Text(storeKit.isPro ? "Tüm özelliklere erişiminiz var" : "Günde 3 hesaplama hakkı")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !storeKit.isPro {
                            Spacer()
                            Button("Pro") { showPaywall = true }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Yasal uyarı banner
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Yasal Sorumluluk Reddi")
                                .font(.caption.bold())
                            Text("Parsel Mimar yalnızca bilgilendirme amaçlıdır. Hesaplamalar resmi imar kararları, harç tutarları veya yatırım tavsiyesi niteliği taşımaz. Kesin bilgi için yetkili belediye, tapu müdürlüğü veya serbest mimar/mühendise danışınız.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Uygulama") {
                    NavigationLink { AboutView() } label: {
                        Label("Hakkında", systemImage: "info.circle")
                    }
                    Link(destination: URL(string: "mailto:cenkyilmazdev@gmail.com")!) {
                        Label("Destek", systemImage: "envelope")
                    }
                    NavigationLink { PrivacyPolicyView() } label: {
                        Label("Gizlilik Politikası", systemImage: "lock.shield")
                    }
                    NavigationLink { TermsOfUseView() } label: {
                        Label("Kullanım Koşulları", systemImage: "doc.text")
                    }
                }

                Section("Hesap") {
                    Button {
                        Task { await storeKit.restorePurchases() }
                        showRestoreAlert = true
                    } label: {
                        Label("Satın Alımları Geri Yükle", systemImage: "arrow.clockwise")
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Parsel Mimar v1.0")
                                .font(.caption)
                            Text("Profesyonel Emsal Hesap Uygulaması")
                                .font(.caption2)
                        }
                        .foregroundStyle(.tertiary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Ayarlar")
            .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(storeKit) }
            .alert("Geri Yükleme", isPresented: $showRestoreAlert) {
                Button("Tamam") {}
            } message: {
                Text(storeKit.isPro ? "Pro üyeliğiniz geri yüklendi!" : "Aktif abonelik bulunamadı.")
            }
        }
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        List {
            Section("Parsel Mimar") {
                Text("Parsel Mimar, mimarlar ve inşaat mühendisleri için geliştirilmiş profesyonel emsal hesap uygulamasıdır.")
                    .font(.subheadline)
            }
            Section("Özellikler") {
                Label("TKGM Parsel Entegrasyonu", systemImage: "map")
                Label("PAİY Uyumlu Emsal Hesabı", systemImage: "function")
                Label("3D Bina Kütle Modeli", systemImage: "cube")
                Label("EK-1 2021 Otopark Hesabı", systemImage: "car.fill")
                Label("2026 Maliyet Tebliği", systemImage: "turkishlirasign")
                Label("Profesyonel PDF Rapor", systemImage: "doc.fill")
                Label("8 Kullanım Türü", systemImage: "square.grid.2x2")
                Label("Çekme Mesafesi Analizi", systemImage: "ruler")
            }
            Section("Yasal") {
                Text("Bu uygulama bilgilendirme amaçlıdır. Kesin hesaplar için yetkili bir mimara danışınız.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Hakkında")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Policy (native)

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                legalHeader(title: "Gizlilik Politikası",
                            subtitle: "Son güncelleme: Temmuz 2025")

                legalSection(title: "1. Toplanan Veriler") {
                    """
                    Parsel Mimar uygulaması cihazınızda aşağıdaki verileri yerel olarak saklar:
                    • Proje bilgileri (parsel, TAKS/KAKS, imar değerleri)
                    • Hesaplama sonuçları
                    • Uygulama tercihleri

                    Hiçbir kişisel veri sunucularımıza gönderilmez.
                    """
                }

                legalSection(title: "2. Üçüncü Taraf Servisler") {
                    """
                    Uygulama aşağıdaki harici servislere bağlantı kurabilir:
                    • TKGM (Tapu ve Kadastro Genel Müdürlüğü) — parsel sorgulama
                    • e-plan.gov.tr — imar bilgisi sorgulama
                    • Apple App Store — abonelik yönetimi (StoreKit)

                    Bu servislerin kendi gizlilik politikaları geçerlidir. Parsel Mimar bu servislerden dönen veriyi sunucularına aktarmaz.
                    """
                }

                legalSection(title: "3. Konum Verisi") {
                    """
                    Harita sekmesinde konum izni talep edilir. Konum verisi yalnızca haritanın merkezini konumunuza taşımak için kullanılır; kaydedilmez, paylaşılmaz.
                    """
                }

                legalSection(title: "4. Veri Güvenliği") {
                    """
                    Tüm proje verileri Apple'ın SwiftData altyapısıyla cihazınızda şifreli olarak saklanır. iCloud yedekleme aktifse Apple'ın güvenlik standartları uygulanır.
                    """
                }

                legalSection(title: "5. Çocukların Gizliliği") {
                    """
                    Uygulama 13 yaş altı bireylere yönelik değildir. Bu yaş grubuna ait veri bilinçli olarak toplanmaz.
                    """
                }

                legalSection(title: "6. İletişim") {
                    "Sorularınız için: cenkyilmazdev@gmail.com"
                }
            }
            .padding()
        }
        .navigationTitle("Gizlilik Politikası")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Terms of Use (native)

struct TermsOfUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                legalHeader(title: "Kullanım Koşulları",
                            subtitle: "Son güncelleme: Temmuz 2025")

                legalSection(title: "1. Kabul") {
                    "Parsel Mimar uygulamasını kullanarak bu koşulları kabul etmiş sayılırsınız."
                }

                legalSection(title: "2. Bilgilendirme Amaçlı Kullanım") {
                    """
                    Parsel Mimar yalnızca bilgilendirme ve ön hesaplama amacıyla tasarlanmıştır.

                    ⚠️ Uygulama içindeki hiçbir hesaplama:
                    • Resmi imar kararı yerine geçmez
                    • Yasal ruhsat belgesi niteliği taşımaz
                    • Yatırım, finansal veya hukuki tavsiye değildir
                    • Belediye ruhsat harçlarını kesin olarak belirlemez

                    Kesin bilgi için ilgili belediye, tapu müdürlüğü veya lisanslı mimar/mühendise başvurunuz.
                    """
                }

                legalSection(title: "3. Sorumluluk Reddi") {
                    """
                    Hesaplama sonuçlarına dayanılarak alınan kararlarda Parsel Mimar ve geliştiricisi herhangi bir sorumluluk kabul etmez.

                    Ruhsat harç tahminleri 2464 sayılı Belediye Gelirleri Kanunu Md.80 bazlı tahmini değerler içerir; yıllık güncellenen resmi tarifeden farklılık gösterebilir.
                    """
                }

                legalSection(title: "4. Fikri Mülkiyet") {
                    "Parsel Mimar uygulaması, arayüzü, algoritmaları ve içerikleri telif hakkıyla korunmaktadır. İzinsiz kopyalama, dağıtım veya tersine mühendislik yasaktır."
                }

                legalSection(title: "5. Abonelik") {
                    """
                    Pro abonelik; Apple App Store üzerinden sunulur ve Apple'ın abonelik koşullarına tabidir. Abonelik, mevcut dönem sona ermeden en az 24 saat önce iptal edilmediği sürece otomatik olarak yenilenir.
                    """
                }

                legalSection(title: "6. Değişiklikler") {
                    "Koşullar önceden bildirim yapılmaksızın güncellenebilir. Güncel versiyonu Ayarlar > Kullanım Koşulları bölümünden takip edebilirsiniz."
                }

                legalSection(title: "7. İletişim") {
                    "cenkyilmazdev@gmail.com"
                }
            }
            .padding()
        }
        .navigationTitle("Kullanım Koşulları")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Legal helpers

private func legalHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.title2.bold())
        Text(subtitle).font(.caption).foregroundStyle(.secondary)
        Divider()
    }
}

@ViewBuilder
private func legalSection(title: String, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.headline)
        content()
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

private func legalSection(title: String, content: () -> String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.headline)
        Text(content())
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}
