import Foundation

struct EmsalCalculator {

    // MARK: - Ana Hesaplamalar

    struct HesaplamaGirdisi {
        let parselAlani: Double
        let taks: Double
        let kaks: Double
        let hmax: Double            // metre — 0 = sınırsız
        let katSayisi: Int
        let kullanimTuru: KullanimTuru
        let binaTipi: BinaTipi
        let yapiSinifi: YapiSinifi
        let onCekme: Double
        let arkaCekme: Double
        let yanCekme: Double
        let parselGenisligi: Double
        let parselDerinligi: Double
        let binaSayisi: Int          // Parseldeki bağımsız yapı adedi (ayrık/villa)
        let ortDaireAlani: Double    // 0 = otomatik (kullanım türüne göre)
    }

    /// Bağımsız bölüm / ünite özeti
    struct BirimOzet {
        let daireSayisi: Int
        let daireBirimiM2: Double
        let depoSayisi: Int
        let balkonSayisi: Int
        let otoparkSayisi: Int
        let otoparkBirimiM2: Double
    }

    /// Belediye yapı ruhsat ve kullanma izni harç tahmini (2464 sayılı BGB Md.80)
    struct RuhsatHarci {
        let yapiRuhsatHarci: Double      // brüt m² × birim değer
        let kullanmaIzinHarci: Double    // ruhsat harcının %50'si
        let zeminEtutHarci: Double       // ruhsat harcının %1'i
        let toplam: Double
        let birimDegeri: Double          // TL/m²
        let bazAlani: Double             // brüt inşaat alanı (m²)
    }

    /// Birden fazla ayrık yapı olduğunda her binanın kırılımı
    struct PerBinaOzet {
        let binaNo: Int
        let tabanAlani: Double
        let toplamInsaatAlani: Double
        let katSayisi: Int
    }

    struct HesaplamaSonucu {
        let tabanAlani: Double
        let toplamInsaatAlani: Double
        let emsalDisiKalemler: EmsalDisiKalemler
        let emsalDisiToplam: Double
        let brutInsaatAlani: Double
        let netInsaatAlani: Double
        let otoparkSayisi: Int
        let otoparkAlani: Double
        let zorunluOtoparkAlani: Double  // net + manevra (×2), md.5/8a
        let tahminiBedel: Double
        let katBilgileri: [KatBilgisi]
        let optimizasyon: EmsalOptimizasyon
        let perBinaOzetler: [PerBinaOzet]   // binaSayisi > 1 ise dolu
        let tahminiDaireSayisi: Int
        let asilKatSayisi: Int           // KAKS + Hmax kısıtlı gerçek kat adedi
        let birimOzet: BirimOzet
        let ruhsatHarci: RuhsatHarci
    }

    struct EmsalDisiKalemler {
        let siginak: Double
        let mescit: Double
        let otopark: Double
        let merdivenBoşlugu: Double  // PAİY Md.31 — 14.5 m²/kat × bina
        let bacaSaft: Double         // PAİY Md.32 — 1.5 m²/kat × bina
        let katHolu: Double          // PAİY Md.4  — 3.5 m²/kat × bina
        let asansorBoşlugu: Double
        let depo: Double
        let teknikAlan: Double
        let camasirlik: Double
        let kapiciDairesi: Double
        let balkon: Double           // PAİY Md.5/c
        let cocukOyunAlani: Double   // PAİY Md.63/b
        // Adet bilgisi için referanslar (kalemler açıklamaları için)
        let refBinaSayisi: Int
        let refKatSayisi: Int
        let refDaireSayisi: Int
        let refAsansorSayisi: Int

        var toplam: Double {
            siginak + mescit + otopark + merdivenBoşlugu + bacaSaft + katHolu +
            asansorBoşlugu + depo + teknikAlan + camasirlik +
            kapiciDairesi + balkon + cocukOyunAlani
        }

        var kalemler: [(ad: String, deger: Double, aciklama: String?)] {
            var list: [(String, Double, String?)] = []
            let b = refBinaSayisi, k = refKatSayisi, d = refDaireSayisi, a = refAsansorSayisi
            if siginak > 0 {
                list.append(("Sığınak (md.54)", siginak, "\(d) bağ.böl. × 2 m²"))
            }
            if merdivenBoşlugu > 0 {
                list.append(("Merdiven Evi (md.31)", merdivenBoşlugu, "\(b) bina × \(k) kat × 14.5 m²"))
            }
            if bacaSaft > 0 {
                list.append(("Baca / Şaft (md.32)", bacaSaft, "\(b) bina × \(k) kat × 1.5 m²"))
            }
            if katHolu > 0 {
                list.append(("Kat Holü (md.4)", katHolu, "\(b) bina × \(k) kat × 3.5 m²"))
            }
            if asansorBoşlugu > 0 {
                list.append(("Asansör Boşluğu", asansorBoşlugu, "\(b * a) shaft × \(k) kat × 6 m²"))
            }
            if teknikAlan > 0 {
                list.append(("Teknik Alan", teknikAlan, nil))
            }
            if depo > 0 {
                list.append(("Depo", depo, "\(d) adet × 4 m²"))
            }
            if camasirlik > 0 {
                list.append(("Çamaşırlık", camasirlik, nil))
            }
            if kapiciDairesi > 0 {
                list.append(("Kapıcı Dairesi", kapiciDairesi, "1 adet × 80 m²"))
            }
            if balkon > 0 {
                let balkonAdet = max(1, Int(balkon / 5.0))
                list.append(("Balkon (md.5/c)", balkon, "\(balkonAdet) adet × 5 m²"))
            }
            if cocukOyunAlani > 0 {
                let grupSayisi = max(1, d / 50)
                list.append(("Çocuk Oyun Alanı (md.63)", cocukOyunAlani, "\(grupSayisi) grup × 30 m²"))
            }
            if mescit > 0 {
                list.append(("Mescit", mescit, nil))
            }
            if otopark > 0 {
                list.append(("Otopark Alanı", otopark, nil))
            }
            return list
        }
    }

    struct KatBilgisi {
        let katNo: Int
        let katAdi: String
        let brutAlan: Double
        let netAlan: Double
        let kullanimAmaci: String
    }

    struct EmsalOptimizasyon {
        let kullanilanEmsal: Double
        let maksimumEmsal: Double
        let kalanPotansiyel: Double
        let kullanimYuzdesi: Double
        let oneriler: [String]
    }

    // MARK: - Hesaplama

    static func hesapla(_ girdi: HesaplamaGirdisi) -> HesaplamaSonucu {
        let tabanAlani = girdi.parselAlani * girdi.taks
        let toplamInsaatAlani = girdi.parselAlani * girdi.kaks

        // Gerçek kat adedi: KAKS ve Hmax kısıtlarını uygula
        let maxKatKaks: Int = (tabanAlani > 0 && girdi.kaks > 0)
            ? max(1, Int(toplamInsaatAlani / tabanAlani)) : girdi.katSayisi
        let maxKatHmax: Int = girdi.hmax > 0
            ? max(1, Int(girdi.hmax / 3.0)) : girdi.katSayisi
        let asilKatSayisi = min(girdi.katSayisi, min(maxKatKaks, maxKatHmax))

        let emsalDisi = hesaplaEmsalDisi(
            tabanAlani: tabanAlani,
            toplamInsaatAlani: toplamInsaatAlani,
            katSayisi: asilKatSayisi,
            kullanimTuru: girdi.kullanimTuru,
            binaSayisi: max(1, girdi.binaSayisi),
            ortDaireAlani: girdi.ortDaireAlani
        )

        let brutInsaatAlani = toplamInsaatAlani + emsalDisi.toplam
        let netInsaatAlani = brutInsaatAlani * netBrutOrani(girdi.kullanimTuru)

        let otoparkSayisi = hesaplaOtopark(
            toplamInsaatAlani: toplamInsaatAlani,
            kullanimTuru: girdi.kullanimTuru
        )
        let otoparkAlani = Double(otoparkSayisi) * 25.0
        let zorunluOtoparkAlani = otoparkAlani * 2.0  // net + manevra payı (md.5/8a)

        let tahminiBedel = brutInsaatAlani * girdi.yapiSinifi.birimMaliyet2026

        let katBilgileri = olusturKatBilgileri(
            tabanAlani: tabanAlani,
            katSayisi: girdi.katSayisi,
            kullanimTuru: girdi.kullanimTuru,
            emsalDisi: emsalDisi
        )

        let optimizasyon = hesaplaOptimizasyon(
            parselAlani: girdi.parselAlani,
            taks: girdi.taks,
            kaks: girdi.kaks,
            katSayisi: girdi.katSayisi,
            kullanimTuru: girdi.kullanimTuru,
            tabanAlani: tabanAlani,
            toplamInsaatAlani: toplamInsaatAlani
        )

        let n = max(1, girdi.binaSayisi)
        let perBinaOzetler: [PerBinaOzet] = n > 1 ? (1...n).map { i in
            PerBinaOzet(
                binaNo: i,
                tabanAlani: tabanAlani / Double(n),
                toplamInsaatAlani: toplamInsaatAlani / Double(n),
                katSayisi: asilKatSayisi    // ← KAKS/Hmax kısıtlı
            )
        } : []

        let gercekDaireBuyuklugu = girdi.ortDaireAlani > 0
            ? girdi.ortDaireAlani : daireBuyuklugu(girdi.kullanimTuru)
        let tahminiDaireSayisi = max(1, Int(toplamInsaatAlani / gercekDaireBuyuklugu))

        let depoSayisi: Int = (girdi.kullanimTuru == .konut || girdi.kullanimTuru == .villa || girdi.kullanimTuru == .karma)
            ? tahminiDaireSayisi : 0
        let balkonSayisi: Int = (girdi.kullanimTuru == .konut || girdi.kullanimTuru == .villa || girdi.kullanimTuru == .karma)
            ? max(1, Int(emsalDisi.balkon / 5.0)) : 0

        let birimOzet = BirimOzet(
            daireSayisi: tahminiDaireSayisi,
            daireBirimiM2: gercekDaireBuyuklugu,
            depoSayisi: depoSayisi,
            balkonSayisi: balkonSayisi,
            otoparkSayisi: otoparkSayisi,
            otoparkBirimiM2: 25.0
        )

        let harcBirim = girdi.yapiSinifi.harcBirimDegeri2025
        let yapiRuhsatHarci = brutInsaatAlani * harcBirim
        let ruhsatHarci = RuhsatHarci(
            yapiRuhsatHarci: yapiRuhsatHarci,
            kullanmaIzinHarci: yapiRuhsatHarci * 0.50,
            zeminEtutHarci: yapiRuhsatHarci * 0.01,
            toplam: yapiRuhsatHarci * 1.51,
            birimDegeri: harcBirim,
            bazAlani: brutInsaatAlani
        )

        return HesaplamaSonucu(
            tabanAlani: tabanAlani,
            toplamInsaatAlani: toplamInsaatAlani,
            emsalDisiKalemler: emsalDisi,
            emsalDisiToplam: emsalDisi.toplam,
            brutInsaatAlani: brutInsaatAlani,
            netInsaatAlani: netInsaatAlani,
            otoparkSayisi: otoparkSayisi,
            otoparkAlani: otoparkAlani,
            zorunluOtoparkAlani: zorunluOtoparkAlani,
            tahminiBedel: tahminiBedel,
            katBilgileri: katBilgileri,
            optimizasyon: optimizasyon,
            perBinaOzetler: perBinaOzetler,
            tahminiDaireSayisi: tahminiDaireSayisi,
            asilKatSayisi: asilKatSayisi,
            birimOzet: birimOzet,
            ruhsatHarci: ruhsatHarci
        )
    }

    // MARK: - PAİY Emsal Dışı Alanlar

    private static func hesaplaEmsalDisi(
        tabanAlani: Double,
        toplamInsaatAlani: Double,
        katSayisi: Int,
        kullanimTuru: KullanimTuru,
        binaSayisi: Int = 1,
        ortDaireAlani: Double = 0
    ) -> EmsalDisiKalemler {
        let gercekDaireBuyuklugu = ortDaireAlani > 0 ? ortDaireAlani : daireBuyuklugu(kullanimTuru)
        let tahminiDaireSayisi = max(1, Int(toplamInsaatAlani / gercekDaireBuyuklugu))

        // Sığınak: PAİY Md.54 — ≥5 bağımsız bölüm, bölüm başına 2 m², min 10 m²,
        // max(600 m², toplam alanın %2'si) — bu iki sınırın küçüğü alınır
        let siginak: Double
        if tahminiDaireSayisi >= 5 {
            let hesaplanan = Double(tahminiDaireSayisi) * 2.0
            let tavan = min(600.0, toplamInsaatAlani * 0.02)
            siginak = min(max(hesaplanan, 10.0), max(tavan, 10.0))
        } else {
            siginak = 0
        }

        // Mescit: ticaret/karma/turizm/sağlık/eğitim binalarda 2000 m²+ zorunlu
        // min 20 m², max 200 m² (toplam alanın binde-5'i)
        let mescitGerektiren: [KullanimTuru] = [.ticaret, .karma, .turizm, .saglik, .egitim]
        let mescit: Double = mescitGerektiren.contains(kullanimTuru) && toplamInsaatAlani > 2000
            ? min(max(20, toplamInsaatAlani * 0.005), 200)
            : 0

        // Merdiven evi: PAİY Md.31 — her bina için 14.5 m²/kat
        let merdivenBoşlugu = katSayisi > 1 ? Double(katSayisi) * 14.5 * Double(binaSayisi) : 0
        // Baca/Şaft: PAİY Md.32 — her bina için 1.5 m²/kat
        let bacaSaft = katSayisi > 1 ? Double(katSayisi) * 1.5 * Double(binaSayisi) : 0
        // Kat holü/koridor: PAİY Md.4 — her bina için 3.5 m²/kat
        let katHolu = katSayisi > 1 ? Double(katSayisi) * 3.5 * Double(binaSayisi) : 0

        // Asansör boşluğu: 4+ katta zorunlu; her bina için ayrı shaft
        let asansorSayisi = katSayisi >= 4 ? max(1, katSayisi / 5) : 0
        let asansorBoşlugu = Double(asansorSayisi) * Double(katSayisi) * 6.0 * Double(binaSayisi)

        // Depo: yalnızca konut/villa/karma binalarda emsal dışı (PAİY Md.5)
        let depo: Double = (kullanimTuru == .konut || kullanimTuru == .villa || kullanimTuru == .karma)
            ? Double(tahminiDaireSayisi) * 4.0 : 0

        // Teknik alan: kazan dairesi, tesisat odası, jeneratör — taban alanının %5'i
        let teknikAlan = tabanAlani * 0.05

        // Çamaşırlık: konut/villa binalarda, min 8 m², max 30 m²
        let camasirlik: Double = (kullanimTuru == .konut || kullanimTuru == .villa)
            ? min(max(tabanAlani * 0.02, 8), 30) : 0

        // Kapıcı dairesi: PAİY Md.63 — ≥50 bağımsız bölümlü binalarda 1 adet, max 80 m²
        let kapiciDairesi: Double = tahminiDaireSayisi >= 50 ? 80 : 0

        // Balkon: PAİY Md.5/c — konut/villa/karma, bağımsız bölüm başına 5 m²,
        // toplam konut alanının %20'sini geçemez
        let balkon: Double
        if kullanimTuru == .konut || kullanimTuru == .villa || kullanimTuru == .karma {
            let konutOrani: Double = kullanimTuru == .karma ? 0.70 : 1.0
            let konutAlani = toplamInsaatAlani * konutOrani
            let balkonHesap = Double(tahminiDaireSayisi) * 5.0
            balkon = min(balkonHesap, konutAlani * 0.20)
        } else {
            balkon = 0
        }

        // Çocuk oyun alanı: PAİY Md.63/b — konut/karma, ≥50 bağımsız bölüm,
        // her 50 bölüm için 30 m²
        let cocukOyunAlani: Double
        if (kullanimTuru == .konut || kullanimTuru == .karma) && tahminiDaireSayisi >= 50 {
            let grupSayisi = max(1, tahminiDaireSayisi / 50)
            cocukOyunAlani = Double(grupSayisi) * 30.0
        } else {
            cocukOyunAlani = 0
        }

        return EmsalDisiKalemler(
            siginak: siginak,
            mescit: mescit,
            otopark: 0,               // otopark bağımsız hesaplanır
            merdivenBoşlugu: merdivenBoşlugu,
            bacaSaft: bacaSaft,
            katHolu: katHolu,
            asansorBoşlugu: asansorBoşlugu,
            depo: depo,
            teknikAlan: teknikAlan,
            camasirlik: camasirlik,
            kapiciDairesi: kapiciDairesi,
            balkon: balkon,
            cocukOyunAlani: cocukOyunAlani,
            refBinaSayisi: binaSayisi,
            refKatSayisi: katSayisi,
            refDaireSayisi: tahminiDaireSayisi,
            refAsansorSayisi: asansorSayisi
        )
    }

    // MARK: - Emsal Optimizasyon

    private static func hesaplaOptimizasyon(
        parselAlani: Double,
        taks: Double,
        kaks: Double,
        katSayisi: Int,
        kullanimTuru: KullanimTuru,
        tabanAlani: Double,
        toplamInsaatAlani: Double
    ) -> EmsalOptimizasyon {
        let maksimum = parselAlani * kaks
        let kullanilanYuzde = maksimum > 0 ? (toplamInsaatAlani / maksimum) * 100 : 0
        let kalan = max(0, maksimum - toplamInsaatAlani)

        var oneriler: [String] = []

        if kullanilanYuzde < 80 && kalan > 50 {
            let katBasi = tabanAlani > 10 ? tabanAlani : parselAlani * max(taks, 0.30)
            let ekKat = max(1, Int(kalan / katBasi))
            oneriler.append("KAKS'ın %\(String(format: "%.0f", kullanilanYuzde))'i kullanılıyor. \(ekKat) kat ekleyerek +\(formatAlan(kalan)) kazanılabilir.")
        }

        let maksimumTaban = parselAlani * taks
        if tabanAlani > 0 && maksimumTaban > 0 && tabanAlani < maksimumTaban * 0.85 {
            let ekTaban = maksimumTaban - tabanAlani
            oneriler.append("Taban alanı maksimum TAKS'ın %\(String(format: "%.0f", (tabanAlani / maksimumTaban) * 100))'i. \(formatAlan(ekTaban)) daha genişletilebilir.")
        }

        if kullanimTuru == .konut && katSayisi >= 5 {
            oneriler.append("Zemin kata ticari birim ekleyerek karma kullanım getirisi artırılabilir.")
        }

        if kalan < 50 && kullanilanYuzde >= 95 {
            oneriler.append("Parsel emsal potansiyeli %\(String(format: "%.0f", kullanilanYuzde)) kullanılıyor — tam kapasite.")
        }

        return EmsalOptimizasyon(
            kullanilanEmsal: toplamInsaatAlani,
            maksimumEmsal: maksimum,
            kalanPotansiyel: kalan,
            kullanimYuzdesi: kullanilanYuzde,
            oneriler: oneriler
        )
    }

    // MARK: - EK-1 2021 Otopark Yönetmeliği

    private static func hesaplaOtopark(
        toplamInsaatAlani: Double,
        kullanimTuru: KullanimTuru
    ) -> Int {
        switch kullanimTuru {
        case .konut:
            return max(1, Int(toplamInsaatAlani / 120))
        case .ticaret:
            return max(1, Int(toplamInsaatAlani / 30))
        case .sanayi:
            return max(1, Int(toplamInsaatAlani / 60))
        case .karma:
            let konutAlani = toplamInsaatAlani * 0.7
            let ticaretAlani = toplamInsaatAlani * 0.3
            return max(1, Int(konutAlani / 120) + Int(ticaretAlani / 30))
        case .villa:
            return 2
        case .turizm:
            return max(1, Int(toplamInsaatAlani / 50))
        case .saglik:
            return max(1, Int(toplamInsaatAlani / 40))
        case .egitim:
            return max(1, Int(toplamInsaatAlani / 50))
        }
    }

    // MARK: - Kat Bilgileri

    private static func olusturKatBilgileri(
        tabanAlani: Double,
        katSayisi: Int,
        kullanimTuru: KullanimTuru,
        emsalDisi: EmsalDisiKalemler
    ) -> [KatBilgisi] {
        var katlar: [KatBilgisi] = []

        katlar.append(KatBilgisi(
            katNo: -1,
            katAdi: "Bodrum Kat",
            brutAlan: tabanAlani,
            netAlan: tabanAlani * 0.85,
            kullanimAmaci: "Otopark / Sığınak / Depo"
        ))

        let zeminAmac = kullanimTuru == .karma ? "Ticaret" : kullanimTuru.rawValue
        katlar.append(KatBilgisi(
            katNo: 0,
            katAdi: "Zemin Kat",
            brutAlan: tabanAlani,
            netAlan: tabanAlani * netBrutOrani(kullanimTuru),
            kullanimAmaci: zeminAmac
        ))

        for i in 1..<katSayisi {
            let katAmac = kullanimTuru == .karma && i <= 1 ? "Ticaret" : kullanimTuru.rawValue
            katlar.append(KatBilgisi(
                katNo: i,
                katAdi: "\(i). Kat",
                brutAlan: tabanAlani,
                netAlan: tabanAlani * netBrutOrani(kullanimTuru),
                kullanimAmaci: katAmac
            ))
        }

        if katSayisi >= 4 {
            katlar.append(KatBilgisi(
                katNo: katSayisi,
                katAdi: "Çatı Katı",
                brutAlan: tabanAlani * 0.6,
                netAlan: tabanAlani * 0.6 * 0.8,
                kullanimAmaci: "Teknik / Teras"
            ))
        }

        return katlar
    }

    // MARK: - Yardımcı

    private static func netBrutOrani(_ tur: KullanimTuru) -> Double {
        switch tur {
        case .konut: return 0.80
        case .ticaret: return 0.65
        case .sanayi: return 0.90
        case .karma: return 0.75
        case .villa: return 0.85
        case .turizm: return 0.70
        case .saglik: return 0.65
        case .egitim: return 0.70
        }
    }

    private static func daireBuyuklugu(_ tur: KullanimTuru) -> Double {
        switch tur {
        case .konut: return 120
        case .ticaret: return 80
        case .sanayi: return 200
        case .karma: return 100
        case .villa: return 250
        case .turizm: return 35
        case .saglik: return 50
        case .egitim: return 60
        }
    }
}

// MARK: - Formatters

extension EmsalCalculator {
    static func formatAlan(_ alan: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return (fmt.string(from: NSNumber(value: alan)) ?? String(format: "%.2f", alan)) + " m²"
    }

    static func formatPara(_ bedel: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: bedel)) ?? "₺0"
    }
}
