import SwiftUI

enum HesaplamaTuru: String, CaseIterable {
    case emsal           = "Emsal"
    case ecriMisil       = "Ecri Misil"
    case emlakVergisi    = "Emlak Vergisi"
    case yatirimAnalizi  = "Yatırım"
}

struct QuickCalculatorView: View {
    @State private var aktifHesaplama: HesaplamaTuru = .emsal

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Hesaplama", selection: $aktifHesaplama) {
                    ForEach(HesaplamaTuru.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)

                switch aktifHesaplama {
                case .emsal:           EmsalHesaplamaView()
                case .ecriMisil:       EcriMisilHesaplamaView()
                case .emlakVergisi:    EmlakVergisiHesaplamaView()
                case .yatirimAnalizi:  YatirimAnaliziView()
                }
            }
            .navigationTitle("Hızlı Hesaplama")
        }
    }
}

// MARK: - Emsal Hesaplama

private struct EmsalHesaplamaView: View {
    @EnvironmentObject private var storeKit: StoreKitService
    @State private var parselAlani: String = ""
    @State private var taks: String = ""
    @State private var kaks: String = ""
    @State private var katSayisi: String = ""
    @State private var kullanimTuru: KullanimTuru = .konut
    @State private var binaTipi: BinaTipi = .ayrik
    @State private var yapiSinifi: YapiSinifi = .sinif3A
    @State private var sonuc: EmsalCalculator.HesaplamaSonucu?
    @State private var showPaywall = false

    var body: some View {
        Form {
            Section("Parsel Bilgileri") {
                qNumRow("Parsel Alanı (m²)", text: $parselAlani, keyboard: .decimalPad)
            }

            Section("İmar Değerleri") {
                qNumRow("TAKS", text: $taks, keyboard: .decimalPad)
                qNumRow("KAKS (Emsal)", text: $kaks, keyboard: .decimalPad)
                qNumRow("Kat Sayısı", text: $katSayisi, keyboard: .numberPad)
            }

            Section("Yapı Özellikleri") {
                Picker("Kullanım Türü", selection: $kullanimTuru) {
                    ForEach(KullanimTuru.allCases) { t in
                        Label(t.rawValue, systemImage: t.icon).tag(t)
                    }
                }
                Picker("Bina Tipi", selection: $binaTipi) {
                    ForEach(BinaTipi.allCases) { t in Text(t.rawValue).tag(t) }
                }
                Picker("Yapı Sınıfı", selection: $yapiSinifi) {
                    ForEach(YapiSinifi.allCases) { s in
                        VStack(alignment: .leading) {
                            Text(s.rawValue)
                            Text(s.description).font(.caption).foregroundStyle(.secondary)
                        }.tag(s)
                    }
                }
            }

            if !storeKit.isPro {
                Section {
                    Button { showPaywall = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: storeKit.canCalculate ? "clock.badge" : "lock.fill")
                                .foregroundStyle(storeKit.canCalculate ? Color.orange : Color.red)
                            Text(storeKit.canCalculate
                                 ? "Bugün **\(storeKit.remainingFreeCalcs)** hesaplama hakkınız kaldı"
                                 : "Günlük limit doldu — Pro'ya geç")
                                .font(.caption)
                            Spacer()
                            Text("Pro →")
                                .font(.caption.bold())
                                .foregroundStyle(.accent)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section {
                Button { hesapla() } label: {
                    HStack { Spacer(); Label("Hesapla", systemImage: "function").font(.headline); Spacer() }
                }
                .disabled(!isValid || !storeKit.canCalculate)
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }

            if let s = sonuc {
                emsalSonucSection(s)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(storeKit)
        }
    }

    @ViewBuilder
    private func emsalSonucSection(_ s: EmsalCalculator.HesaplamaSonucu) -> some View {
        Section("Sonuçlar") {
            ResultRow(label: "Taban Alanı",         value: EmsalCalculator.formatAlan(s.tabanAlani), highlight: true)
            ResultRow(label: "Toplam İnşaat Alanı", value: EmsalCalculator.formatAlan(s.toplamInsaatAlani), highlight: true)
            ResultRow(label: "Emsal Dışı Toplam",   value: EmsalCalculator.formatAlan(s.emsalDisiToplam))
            ResultRow(label: "Brüt İnşaat Alanı",  value: EmsalCalculator.formatAlan(s.brutInsaatAlani), highlight: true)
            ResultRow(label: "Net İnşaat Alanı",    value: EmsalCalculator.formatAlan(s.netInsaatAlani))
            ResultRow(label: "Otopark Sayısı",      value: "\(s.otoparkSayisi) adet")
        }

        Section("Emsal Dışı Kalemler (PAİY)") {
            let k = s.emsalDisiKalemler
            ResultRow(label: "Sığınak",          value: EmsalCalculator.formatAlan(k.siginak))
            ResultRow(label: "Mescit",           value: EmsalCalculator.formatAlan(k.mescit))
            ResultRow(label: "Merdiven Boşluğu", value: EmsalCalculator.formatAlan(k.merdivenBoşlugu))
            ResultRow(label: "Asansör Boşluğu",  value: EmsalCalculator.formatAlan(k.asansorBoşlugu))
            ResultRow(label: "Depo",             value: EmsalCalculator.formatAlan(k.depo))
            ResultRow(label: "Teknik Alan",      value: EmsalCalculator.formatAlan(k.teknikAlan))
            ResultRow(label: "Çamaşırlık",       value: EmsalCalculator.formatAlan(k.camasirlik))
            ResultRow(label: "Kapıcı Dairesi",   value: EmsalCalculator.formatAlan(k.kapiciDairesi))
            ResultRow(label: "Balkon",           value: EmsalCalculator.formatAlan(k.balkon))
            ResultRow(label: "Çocuk Oyun Alanı", value: EmsalCalculator.formatAlan(k.cocukOyunAlani))
        }

        Section("Tahmini Maliyet") {
            HStack {
                Image(systemName: "turkishlirasign.circle.fill")
                    .font(.title2).foregroundStyle(.green)
                VStack(alignment: .leading) {
                    Text("Yapı Maliyeti").font(.caption).foregroundStyle(.secondary)
                    Text(EmsalCalculator.formatPara(s.tahminiBedel))
                        .font(.title2.bold()).foregroundStyle(.green)
                }
            }
        }
    }

    private var isValid: Bool {
        guard let a = qDbl(parselAlani), a > 0,
              let t = qDbl(taks), t > 0,
              let k = qDbl(kaks), k > 0,
              let kat = Int(katSayisi), kat > 0 else { return false }
        return true
    }

    private func hesapla() {
        guard storeKit.canCalculate else { showPaywall = true; return }
        guard let alan = qDbl(parselAlani), let t = qDbl(taks),
              let k = qDbl(kaks), let kat = Int(katSayisi) else { return }
        storeKit.recordCalculation()
        let girdi = EmsalCalculator.HesaplamaGirdisi(
            parselAlani: alan, taks: t, kaks: k, hmax: 0, katSayisi: kat,
            kullanimTuru: kullanimTuru, binaTipi: binaTipi, yapiSinifi: yapiSinifi,
            onCekme: 5, arkaCekme: 3, yanCekme: 3,
            parselGenisligi: 0, parselDerinligi: 0,
            binaSayisi: 1, ortDaireAlani: 0
        )
        withAnimation { sonuc = EmsalCalculator.hesapla(girdi) }
    }
}

// MARK: - Ecri Misil Hesaplayıcısı

private struct EcriMisilHesaplamaView: View {
    @State private var parselAlani: String = ""
    @State private var m2RayicBedeli: String = ""
    @State private var isGalSuresi: String = "1"
    @State private var ecriMisilOrani: String = "5"
    @State private var sonuc: EcriMisilSonucu?

    var body: some View {
        Form {
            Section {
                qNumRow("Parsel Alanı (m²)", text: $parselAlani, keyboard: .decimalPad)
                qNumRow("Rayiç Bedel (₺/m²)", text: $m2RayicBedeli, keyboard: .decimalPad)
                qNumRow("İşgal Süresi (Yıl)", text: $isGalSuresi, keyboard: .decimalPad)
                qNumRow("Ecri Misil Oranı (%)", text: $ecriMisilOrani, keyboard: .decimalPad)
            } header: {
                Text("Ecri Misil Bilgileri")
            } footer: {
                Text("Ecri misil, haksız işgal veya izinsiz kullanım durumunda talep edilen tazminattır. Hazine taşınmazları için yıllık oran genellikle %2–10 arasındadır.")
                    .font(.caption)
            }

            Section {
                Button { hesapla() } label: {
                    HStack { Spacer(); Label("Hesapla", systemImage: "function").font(.headline); Spacer() }
                }
                .disabled(!isValid)
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }

            if let s = sonuc {
                Section("Sonuç") {
                    ResultRow(label: "Taşınmaz Toplam Değeri",
                              value: qFormatTL(s.toplamDeger))
                    ResultRow(label: "Yıllık Ecri Misil",
                              value: qFormatTL(s.yillikEcriMisil), highlight: true)
                    ResultRow(label: "Aylık Ecri Misil",
                              value: qFormatTL(s.aylikEcriMisil))
                    ResultRow(label: "Toplam (\(String(format: "%.0f", s.sure)) Yıl)",
                              value: qFormatTL(s.toplamEcriMisil), highlight: true)
                }
                Section {
                    qInfoRow(icon: "info.circle", color: .blue,
                             text: "Bu hesaplama bilgi amaçlıdır. Resmi ecri misil tespiti için Hazine veya ilgili idare kararı gerekir.")
                }
            }
        }
    }

    private var isValid: Bool {
        qDbl(parselAlani) != nil && qDbl(m2RayicBedeli) != nil &&
        qDbl(isGalSuresi) != nil && qDbl(ecriMisilOrani) != nil
    }

    private func hesapla() {
        guard let alan  = qDbl(parselAlani),
              let rayic = qDbl(m2RayicBedeli),
              let sure  = qDbl(isGalSuresi),
              let oran  = qDbl(ecriMisilOrani) else { return }
        let toplamDeger = alan * rayic
        let yillik = toplamDeger * (oran / 100)
        withAnimation {
            sonuc = EcriMisilSonucu(
                toplamDeger: toplamDeger,
                yillikEcriMisil: yillik,
                aylikEcriMisil: yillik / 12,
                toplamEcriMisil: yillik * sure,
                sure: sure
            )
        }
    }

    struct EcriMisilSonucu {
        let toplamDeger: Double
        let yillikEcriMisil: Double
        let aylikEcriMisil: Double
        let toplamEcriMisil: Double
        let sure: Double
    }
}

// MARK: - Emlak Vergisi Hesaplayıcısı

private struct EmlakVergisiHesaplamaView: View {
    @State private var tasinmazTuru: TasinmazTuru = .arsa
    @State private var rayicDeger: String = ""
    @State private var buyuksehirMi: Bool = false
    @State private var sonuc: EmlakVergisiSonucu?

    enum TasinmazTuru: String, CaseIterable, Identifiable {
        case arsa      = "Arsa"
        case arazi     = "Arazi"
        case mesken    = "Mesken"
        case digerBina = "Diğer Bina"
        var id: String { rawValue }

        func vergiOrani(buyuksehir: Bool) -> Double {
            switch self {
            case .arsa:      return buyuksehir ? 0.004 : 0.002
            case .arazi:     return buyuksehir ? 0.002 : 0.001
            case .mesken:    return buyuksehir ? 0.002 : 0.001
            case .digerBina: return buyuksehir ? 0.004 : 0.002
            }
        }

        var icon: String {
            switch self {
            case .arsa:      return "square.on.square"
            case .arazi:     return "leaf"
            case .mesken:    return "house"
            case .digerBina: return "building.2"
            }
        }
    }

    var body: some View {
        Form {
            Section("Taşınmaz Bilgileri") {
                Picker("Tür", selection: $tasinmazTuru) {
                    ForEach(TasinmazTuru.allCases) { t in
                        Label(t.rawValue, systemImage: t.icon).tag(t)
                    }
                }
                qNumRow("Vergi Değeri (₺)", text: $rayicDeger, keyboard: .decimalPad)
                Toggle("Büyükşehir Belediyesi Sınırı", isOn: $buyuksehirMi)
            }

            Section {
                HStack {
                    Text("Uygulanacak Oran")
                    Spacer()
                    let oran = tasinmazTuru.vergiOrani(buyuksehir: buyuksehirMi)
                    Text("‰\(String(format: "%.1f", oran * 1000))")
                        .font(.headline).foregroundStyle(.accent)
                }
            }

            Section {
                Button { hesapla() } label: {
                    HStack { Spacer(); Label("Hesapla", systemImage: "function").font(.headline); Spacer() }
                }
                .disabled(qDbl(rayicDeger) == nil)
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }

            if let s = sonuc {
                Section("Sonuç") {
                    ResultRow(label: "Vergi Değeri",
                              value: qFormatTL(s.vergiDegeri))
                    ResultRow(label: "Uygulanan Oran",
                              value: "‰\(String(format: "%.1f", s.oran * 1000))")
                    ResultRow(label: "Yıllık Emlak Vergisi",
                              value: qFormatTL(s.yillikVergi), highlight: true)
                    ResultRow(label: "1. Taksit (Mayıs)",
                              value: qFormatTL(s.yillikVergi / 2))
                    ResultRow(label: "2. Taksit (Kasım)",
                              value: qFormatTL(s.yillikVergi / 2))
                }
                Section {
                    qInfoRow(icon: "info.circle", color: .blue,
                             text: "1319 sayılı Emlak Vergisi Kanunu'na göredir. Gerçek vergi tutarı için belediyenize başvurun.")
                }
            }
        }
    }

    private func hesapla() {
        guard let deger = qDbl(rayicDeger) else { return }
        let oran = tasinmazTuru.vergiOrani(buyuksehir: buyuksehirMi)
        withAnimation { sonuc = EmlakVergisiSonucu(vergiDegeri: deger, oran: oran, yillikVergi: deger * oran) }
    }

    struct EmlakVergisiSonucu {
        let vergiDegeri: Double
        let oran: Double
        let yillikVergi: Double
    }
}

// MARK: - Yatırım Analizi (Amortisman + Kira Getirisi)

private struct YatirimAnaliziView: View {
    @State private var satisFiyati: String = ""
    @State private var aylikKira: String = ""
    @State private var aylikGider: String = ""
    @State private var sonuc: YatirimSonucu?

    var body: some View {
        Form {
            Section {
                qNumRow("Satış / Piyasa Değeri (₺)", text: $satisFiyati, keyboard: .decimalPad)
                qNumRow("Aylık Kira (₺, aidat hariç)", text: $aylikKira, keyboard: .decimalPad)
            } header: {
                Text("Taşınmaz Bilgileri")
            }

            Section {
                qNumRow("Aylık Gider (₺, opsiyonel)", text: $aylikGider, keyboard: .decimalPad)
            } header: {
                Text("Giderler")
            } footer: {
                Text("Aidat, sigorta, yönetim ücreti vb. Boş bırakırsanız brüt hesap yapılır.")
                    .font(.caption)
            }

            Section {
                Button { hesapla() } label: {
                    HStack { Spacer(); Label("Hesapla", systemImage: "function").font(.headline); Spacer() }
                }
                .disabled(!isValid)
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }

            if let s = sonuc {
                Section("Kira Getirisi") {
                    ResultRow(label: "Yıllık Kira Geliri",
                              value: qFormatTL(s.yillikKira))
                    ResultRow(label: "Brüt Getiri Oranı",
                              value: String(format: "%%%.2f", s.brutGetiriOrani), highlight: true)
                    if s.aylikGider > 0 {
                        ResultRow(label: "Aylık Net Kira",
                                  value: qFormatTL(s.aylikNetKira))
                        ResultRow(label: "Net Getiri Oranı",
                                  value: String(format: "%%%.2f", s.netGetiriOrani), highlight: true)
                    }
                }

                Section("Amortisman") {
                    ResultRow(label: "Brüt Amortisman",
                              value: String(format: "%.1f yıl", s.brutAmortisman), highlight: true)
                    if s.aylikGider > 0 {
                        ResultRow(label: "Net Amortisman",
                                  value: String(format: "%.1f yıl", s.netAmortisman), highlight: true)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill").foregroundStyle(.secondary)
                        let fark = s.brutAmortisman - 18
                        let deger = fark <= 0
                            ? "Türkiye ortalamasından \(String(format: "%.1f", abs(fark))) yıl iyi"
                            : "Türkiye ortalamasından \(String(format: "%.1f", fark)) yıl uzun"
                        Text("Referans: Türkiye ort. ~18 yıl — \(deger)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    qInfoRow(icon: "info.circle", color: .blue,
                             text: "Hesaplama bilgi amaçlıdır. Vergi, tapu masrafı ve boş kalma süreleri dahil edilmemiştir.")
                }
            }
        }
    }

    private var isValid: Bool {
        qDbl(satisFiyati) != nil && qDbl(aylikKira) != nil
    }

    private func hesapla() {
        guard let fiyat = qDbl(satisFiyati),
              let aylik = qDbl(aylikKira) else { return }
        let gider = qDbl(aylikGider) ?? 0
        let yillik = aylik * 12
        let yillikNet = (aylik - gider) * 12
        let brut = (yillik / fiyat) * 100
        let net  = gider > 0 ? (yillikNet / fiyat) * 100 : 0
        withAnimation {
            sonuc = YatirimSonucu(
                yillikKira:       yillik,
                brutGetiriOrani:  brut,
                netGetiriOrani:   net,
                aylikNetKira:     aylik - gider,
                aylikGider:       gider,
                brutAmortisman:   fiyat / yillik,
                netAmortisman:    yillikNet > 0 ? fiyat / yillikNet : 0
            )
        }
    }

    struct YatirimSonucu {
        let yillikKira:      Double
        let brutGetiriOrani: Double
        let netGetiriOrani:  Double
        let aylikNetKira:    Double
        let aylikGider:      Double
        let brutAmortisman:  Double
        let netAmortisman:   Double
    }
}

// MARK: - Shared Components

struct ResultRow: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack {
            Text(label).foregroundStyle(highlight ? .primary : .secondary)
            Spacer()
            Text(value).bold(highlight).foregroundStyle(highlight ? .accent : .primary)
        }
    }
}

// Prefix with q to avoid collisions with any top-level declarations
private func qNumRow(_ label: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
    HStack {
        Text(label)
        Spacer()
        TextField("0", text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.trailing)
            .frame(width: 140)
    }
}

private func qInfoRow(icon: String, color: Color, text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
        Image(systemName: icon).foregroundStyle(color).padding(.top, 1)
        Text(text).font(.caption).foregroundStyle(.secondary)
    }
}

private func qDbl(_ s: String) -> Double? {
    let v = Double(s.replacingOccurrences(of: ",", with: "."))
    return (v != nil && v! > 0) ? v : nil
}

private func qFormatTL(_ v: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "TRY"
    f.currencySymbol = "₺"
    f.maximumFractionDigits = 2
    f.minimumFractionDigits = 2
    f.groupingSeparator = "."
    f.decimalSeparator = ","
    return f.string(from: NSNumber(value: v)) ?? "₺\(String(format: "%.2f", v))"
}
