import Foundation
import PDFKit
import UIKit

struct PDFReportService {

    // MARK: - Design Tokens

    private static let navy    = UIColor(red: 0.055, green: 0.122, blue: 0.314, alpha: 1)
    private static let accent  = UIColor(red: 0.118, green: 0.282, blue: 0.710, alpha: 1)
    private static let rowAlt  = UIColor(red: 0.945, green: 0.945, blue: 0.968, alpha: 1)
    private static let green_  = UIColor(red: 0.047, green: 0.478, blue: 0.212, alpha: 1)
    private static let orange_ = UIColor(red: 0.878, green: 0.431, blue: 0.000, alpha: 1)
    private static let dimText = UIColor(red: 0.38,  green: 0.38,  blue: 0.42,  alpha: 1)

    private static let PW: CGFloat = 595
    private static let PH: CGFloat = 842
    private static let M:  CGFloat = 44
    private static var CW: CGFloat { PW - M * 2 }
    private static let rowH:  CGFloat = 20
    private static let secH:  CGFloat = 26
    private static let hdrH:  CGFloat = 108

    // MARK: - Public API

    static func generateReport(project: Project, sonuc: EmsalCalculator.HesaplamaSonucu) -> Data {
        let fmt = UIGraphicsPDFRendererFormat()
        fmt.documentInfo = [
            kCGPDFContextCreator: "Parsel Mimar" as CFString,
            kCGPDFContextTitle:   "Emsal Raporu – \(project.name)" as CFString,
            kCGPDFContextAuthor:  "Parsel Mimar" as CFString,
        ] as [String: Any]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: PW, height: PH),
            format: fmt
        )
        return renderer.pdfData { ctx in
            render(ctx: ctx, project: project, sonuc: sonuc)
        }
    }

    // MARK: - Render Pipeline

    private static func render(
        ctx: UIGraphicsPDFRendererContext,
        project: Project,
        sonuc: EmsalCalculator.HesaplamaSonucu
    ) {
        var y: CGFloat = 0
        var pageNum = 1

        func newPage() {
            drawFooter(in: ctx.cgContext, page: pageNum)
            ctx.beginPage()
            pageNum += 1
            y = drawContinuationHeader(in: ctx.cgContext, project: project, page: pageNum)
        }

        func ensure(_ needed: CGFloat) {
            if y + needed > PH - 50 { newPage() }
        }

        // ── Page 1 ──
        ctx.beginPage()
        y = drawFirstHeader(in: ctx.cgContext, project: project)

        // ── Proje & Parsel ──
        ensure(secH + rowH * 6)
        y = sectionBand(in: ctx.cgContext, title: "PROJE & PARSEL BİLGİLERİ", y: y)
        let parselRows: [(String, String)] = [
            ("Proje Adı",       project.name.isEmpty ? "—" : project.name),
            ("İl / İlçe",      project.il.isEmpty   ? "—" : "\(project.il) / \(project.ilce)"),
            ("Mahalle",         project.mahalle.isEmpty ? "—" : project.mahalle),
            ("Ada / Parsel",    project.ada.isEmpty  ? "—" : "\(project.ada) / \(project.parsel)"),
            ("Parsel Alanı",    EmsalCalculator.formatAlan(project.parselAlani)),
            ("Rapor Tarihi",    trDate(Date())),
        ]
        y = table(in: ctx.cgContext, rows: parselRows, y: y)
        y += 10

        // ── İmar ──
        ensure(secH + rowH * 10)
        y = sectionBand(in: ctx.cgContext, title: "İMAR BİLGİLERİ", y: y)
        let imarRows: [(String, String)] = [
            ("TAKS",                    String(format: "%.2f", project.taks)),
            ("KAKS (Emsal)",            String(format: "%.2f", project.kaks)),
            ("H max",                   project.hmax > 0
                                            ? String(format: "%.1f m", project.hmax)
                                            : "Belirtilmemiş"),
            ("İstenen Kat Sayısı",      "\(project.katSayisi) kat"),
            ("Uygulanabilir Kat (KAKS/Hmax)", "\(sonuc.asilKatSayisi) kat"),
            ("Kullanım Türü",           project.kullanimTuru.rawValue),
            ("Bina Tipi",               project.binaTipi.rawValue),
            ("Yapı Sınıfı",             "\(project.yapiSinifi.rawValue) · \(project.yapiSinifi.description)"),
            ("Bina Sayısı",             "\(project.binaSayisi) adet"),
            ("Çekme Mesafeleri",        "Ön \(fmt1(project.onCekme))m · Arka \(fmt1(project.arkaCekme))m · Yan \(fmt1(project.yanCekme))m"),
        ]
        y = table(in: ctx.cgContext, rows: imarRows, y: y)
        y += 10

        // ── Hesaplama ──
        ensure(secH + rowH * 7)
        y = sectionBand(in: ctx.cgContext, title: "HESAPLAMA SONUÇLARI", y: y)
        let hesapRows: [(String, String, Bool)] = [
            ("Taban Alanı  (TAKS × Parsel)",             EmsalCalculator.formatAlan(sonuc.tabanAlani),            false),
            ("Toplam İnşaat Alanı  (KAKS × Parsel)",     EmsalCalculator.formatAlan(sonuc.toplamInsaatAlani),     true),
            ("Emsal Dışı Alanlar Toplamı",               EmsalCalculator.formatAlan(sonuc.emsalDisiToplam),       false),
            ("Brüt İnşaat Alanı",                        EmsalCalculator.formatAlan(sonuc.brutInsaatAlani),       true),
            ("Net İnşaat Alanı",                         EmsalCalculator.formatAlan(sonuc.netInsaatAlani),        true),
            ("Zorunlu Otopark",                          "\(sonuc.otoparkSayisi) araç · \(EmsalCalculator.formatAlan(sonuc.zorunluOtoparkAlani))", false),
        ]
        y = highlightTable(in: ctx.cgContext, rows: hesapRows, y: y)
        y += 10

        // ── Birim Özeti ──
        let bo = sonuc.birimOzet
        if bo.daireSayisi > 0 {
            ensure(secH + rowH * 4 + 4)
            y = sectionBand(in: ctx.cgContext, title: "BAĞIMSIZ BİRİM ÖZETİ", y: y)
            let birimRows: [(String, String)] = [
                ("Daire",    "\(bo.daireSayisi) adet · ort. \(fmt0(bo.daireBirimiM2)) m²/daire"),
                ("Depo",     "\(bo.depoSayisi) adet"),
                ("Balkon",   "\(bo.balkonSayisi) adet"),
                ("Otopark",  "\(bo.otoparkSayisi) araç · \(fmt0(bo.otoparkBirimiM2)) m²/araç"),
            ]
            y = table(in: ctx.cgContext, rows: birimRows, y: y)
            y += 10
        }

        // ── Emsal Dışı Kalemler ──
        let kalemler = sonuc.emsalDisiKalemler.kalemler
        if !kalemler.isEmpty {
            ensure(secH + rowH * CGFloat(kalemler.count + 2) + 4)
            y = sectionBand(in: ctx.cgContext, title: "EMSAL DIŞI KALEMLER  (PAİY)", y: y)
            let edk = kalemler.map { k -> (String, String) in
                let detail = k.aciklama.map { " (\($0))" } ?? ""
                return (k.ad + detail, EmsalCalculator.formatAlan(k.deger))
            }
            y = table(in: ctx.cgContext, rows: edk, y: y)
            y = totalRow(in: ctx.cgContext,
                         label: "Toplam Emsal Dışı",
                         value: EmsalCalculator.formatAlan(sonuc.emsalDisiToplam),
                         color: accent, y: y)
            y += 10
        }

        // ── Ruhsat Harç Tahmini ──
        let h = sonuc.ruhsatHarci
        ensure(secH + rowH * 4 + 32 + 10)
        y = sectionBand(in: ctx.cgContext,
                        title: "BELEDİYE RUHSAT HARÇ TAHMİNİ",
                        y: y, color: orange_)
        let harcRows: [(String, String)] = [
            ("Yapı Ruhsat Harcı  · \(EmsalCalculator.formatAlan(h.bazAlani)) × \(fmt0(h.birimDegeri)) TL/m²",
             EmsalCalculator.formatPara(h.yapiRuhsatHarci)),
            ("Yapı Kullanma İzin Harcı  (%50)",  EmsalCalculator.formatPara(h.kullanmaIzinHarci)),
            ("Zemin Açma ve Temel Etüt Harcı  (%1)", EmsalCalculator.formatPara(h.zeminEtutHarci)),
        ]
        y = table(in: ctx.cgContext, rows: harcRows, y: y)
        y = totalRow(in: ctx.cgContext,
                     label: "Toplam Tahmini Harç",
                     value: EmsalCalculator.formatPara(h.toplam),
                     color: orange_, y: y)
        y = disclaimer(in: ctx.cgContext,
                       text: "⚠  Tahmini 2025 değerleri (2464 sayılı BGB Md.80 bazlı). Kesin tutar için ilgili belediyeden teyit alınız. Bu hesap yatırım tavsiyesi değildir.",
                       y: y)
        y += 12

        // ── Maliyet ──
        ensure(48)
        costBox(in: ctx.cgContext,
                label: "TAHMİNİ YAPI MALİYETİ  (2026 Birim Maliyet Tebliği)",
                value: EmsalCalculator.formatPara(sonuc.tahminiBedel), y: y)

        drawFooter(in: ctx.cgContext, page: pageNum)
    }

    // MARK: - Page Headers

    private static func drawFirstHeader(in ctx: CGContext, project: Project) -> CGFloat {
        // Navy background
        ctx.setFillColor(navy.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: PW, height: hdrH))

        // Accent diagonal shape
        ctx.setFillColor(accent.withAlphaComponent(0.45).cgColor)
        let tri = CGMutablePath()
        tri.move(to: CGPoint(x: PW - 140, y: 0))
        tri.addLine(to: CGPoint(x: PW, y: 0))
        tri.addLine(to: CGPoint(x: PW, y: hdrH))
        tri.addLine(to: CGPoint(x: PW - 60, y: hdrH))
        tri.closeSubpath()
        ctx.addPath(tri); ctx.fillPath()

        // Title
        "EMSAL HESAP RAPORU".draw(
            at: CGPoint(x: M, y: 20),
            withAttributes: [.font: UIFont.boldSystemFont(ofSize: 20),
                             .foregroundColor: UIColor.white])

        // Project name
        let projName = project.name.isEmpty ? "İsimsiz Proje" : project.name
        projName.draw(
            at: CGPoint(x: M, y: 48),
            withAttributes: [.font: UIFont.systemFont(ofSize: 13, weight: .medium),
                             .foregroundColor: UIColor.white.withAlphaComponent(0.88)])

        // Location
        if !project.il.isEmpty {
            "\(project.il) / \(project.ilce)  ·  Ada: \(project.ada)  Parsel: \(project.parsel)".draw(
                at: CGPoint(x: M, y: 68),
                withAttributes: [.font: UIFont.systemFont(ofSize: 10),
                                 .foregroundColor: UIColor.white.withAlphaComponent(0.62)])
        }

        // Parsel Mimar badge — right side
        let badge = "Parsel Mimar"
        let badgeAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.white
        ]
        let bW = (badge as NSString).size(withAttributes: badgeAttr).width
        badge.draw(at: CGPoint(x: PW - M - bW, y: 20), withAttributes: badgeAttr)

        // Date — right side
        let dateStr = trDate(Date())
        let dateAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.white.withAlphaComponent(0.65)
        ]
        let dW = (dateStr as NSString).size(withAttributes: dateAttr).width
        dateStr.draw(at: CGPoint(x: PW - M - dW, y: 38), withAttributes: dateAttr)

        // Bottom line
        ctx.setStrokeColor(accent.cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: 0, y: hdrH - 1))
        ctx.addLine(to: CGPoint(x: PW, y: hdrH - 1))
        ctx.strokePath()

        return hdrH + 16
    }

    private static func drawContinuationHeader(
        in ctx: CGContext, project: Project, page: Int
    ) -> CGFloat {
        ctx.setFillColor(navy.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: PW, height: 34))

        "EMSAL HESAP RAPORU".draw(
            at: CGPoint(x: M, y: 10),
            withAttributes: [.font: UIFont.boldSystemFont(ofSize: 10),
                             .foregroundColor: UIColor.white])

        let pStr = "Sayfa \(page)"
        let pAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.white.withAlphaComponent(0.75)
        ]
        let pW = (pStr as NSString).size(withAttributes: pAttr).width
        pStr.draw(at: CGPoint(x: PW - M - pW, y: 12), withAttributes: pAttr)

        return 34 + 14
    }

    // MARK: - Section Band

    private static func sectionBand(
        in ctx: CGContext, title: String, y: CGFloat, color: UIColor? = nil
    ) -> CGFloat {
        let c = color ?? navy
        ctx.setFillColor(c.cgColor)
        ctx.fill(CGRect(x: M, y: y, width: CW, height: secH))

        // Left accent pip
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.25).cgColor)
        ctx.fill(CGRect(x: M, y: y, width: 3, height: secH))

        title.draw(
            at: CGPoint(x: M + 10, y: y + 7),
            withAttributes: [.font: UIFont.boldSystemFont(ofSize: 9.5),
                             .foregroundColor: UIColor.white,
                             .kern: 0.6])
        return y + secH + 2
    }

    // MARK: - Table helpers

    private static func table(
        in ctx: CGContext, rows: [(String, String)], y: CGFloat
    ) -> CGFloat {
        var cy = y
        for (i, row) in rows.enumerated() {
            if i % 2 == 1 {
                ctx.setFillColor(rowAlt.cgColor)
                ctx.fill(CGRect(x: M, y: cy, width: CW, height: rowH))
            }
            row.0.draw(
                at: CGPoint(x: M + 8, y: cy + 5),
                withAttributes: [.font: UIFont.systemFont(ofSize: 9.5),
                                 .foregroundColor: dimText])
            let vAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9.5, weight: .medium),
                .foregroundColor: UIColor.black
            ]
            let vW = (row.1 as NSString).size(withAttributes: vAttr).width
            row.1.draw(at: CGPoint(x: M + CW - vW - 8, y: cy + 5), withAttributes: vAttr)
            cy += rowH
        }
        hairline(in: ctx, y: cy)
        return cy + 2
    }

    private static func highlightTable(
        in ctx: CGContext, rows: [(String, String, Bool)], y: CGFloat
    ) -> CGFloat {
        var cy = y
        for (i, row) in rows.enumerated() {
            if i % 2 == 1 {
                ctx.setFillColor(rowAlt.cgColor)
                ctx.fill(CGRect(x: M, y: cy, width: CW, height: rowH))
            }
            let isKey = row.2
            row.0.draw(
                at: CGPoint(x: M + 8, y: cy + 5),
                withAttributes: [
                    .font: isKey ? UIFont.boldSystemFont(ofSize: 9.5) : UIFont.systemFont(ofSize: 9.5),
                    .foregroundColor: isKey ? navy : dimText
                ])
            let vAttr: [NSAttributedString.Key: Any] = [
                .font: isKey ? UIFont.boldSystemFont(ofSize: 9.5) : UIFont.systemFont(ofSize: 9.5),
                .foregroundColor: isKey ? navy : UIColor.black
            ]
            let vW = (row.1 as NSString).size(withAttributes: vAttr).width
            row.1.draw(at: CGPoint(x: M + CW - vW - 8, y: cy + 5), withAttributes: vAttr)
            cy += rowH
        }
        hairline(in: ctx, y: cy)
        return cy + 2
    }

    private static func totalRow(
        in ctx: CGContext, label: String, value: String, color: UIColor, y: CGFloat
    ) -> CGFloat {
        ctx.setFillColor(color.withAlphaComponent(0.10).cgColor)
        ctx.fill(CGRect(x: M, y: y, width: CW, height: rowH))
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: M, y: y, width: 3, height: rowH))

        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9.5),
            .foregroundColor: color
        ]
        label.draw(at: CGPoint(x: M + 8, y: y + 5), withAttributes: attr)
        let vW = (value as NSString).size(withAttributes: attr).width
        value.draw(at: CGPoint(x: M + CW - vW - 8, y: y + 5), withAttributes: attr)
        return y + rowH + 2
    }

    private static func disclaimer(in ctx: CGContext, text: String, y: CGFloat) -> CGFloat {
        let h: CGFloat = 30
        ctx.setFillColor(orange_.withAlphaComponent(0.07).cgColor)
        ctx.fill(CGRect(x: M, y: y, width: CW, height: h))
        text.draw(
            in: CGRect(x: M + 8, y: y + 7, width: CW - 16, height: h - 8),
            withAttributes: [.font: UIFont.italicSystemFont(ofSize: 7.5),
                             .foregroundColor: orange_])
        return y + h + 4
    }

    private static func costBox(in ctx: CGContext, label: String, value: String, y: CGFloat) {
        let h: CGFloat = 42
        ctx.setFillColor(green_.withAlphaComponent(0.07).cgColor)
        ctx.fill(CGRect(x: M, y: y, width: CW, height: h))
        ctx.setFillColor(green_.cgColor)
        ctx.fill(CGRect(x: M, y: y, width: 4, height: h))

        label.draw(
            at: CGPoint(x: M + 12, y: y + 7),
            withAttributes: [.font: UIFont.systemFont(ofSize: 8.5),
                             .foregroundColor: green_])
        let vAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: green_
        ]
        let vW = (value as NSString).size(withAttributes: vAttr).width
        value.draw(at: CGPoint(x: M + CW - vW - 8, y: y + 12), withAttributes: vAttr)
    }

    // MARK: - Footer

    private static func drawFooter(in ctx: CGContext, page: Int) {
        let fy = PH - 34
        hairline(in: ctx, y: fy)

        "Parsel Mimar · bilgilendirme amaçlıdır · ruhsat, imar kararı veya yatırım tavsiyesi değildir · kesin bilgi için yetkili mimar/müh. ve belediyeye danışınız".draw(
            in: CGRect(x: M, y: fy + 6, width: CW - 55, height: 20),
            withAttributes: [.font: UIFont.italicSystemFont(ofSize: 6.5),
                             .foregroundColor: UIColor.gray])

        let pStr = "Sayfa \(page)"
        let pAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.gray
        ]
        let pW = (pStr as NSString).size(withAttributes: pAttr).width
        pStr.draw(at: CGPoint(x: PW - M - pW, y: fy + 9), withAttributes: pAttr)
    }

    // MARK: - Utilities

    private static func hairline(in ctx: CGContext, y: CGFloat) {
        ctx.setStrokeColor(UIColor.lightGray.cgColor)
        ctx.setLineWidth(0.35)
        ctx.move(to: CGPoint(x: M, y: y))
        ctx.addLine(to: CGPoint(x: M + CW, y: y))
        ctx.strokePath()
    }

    private static func trDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = Locale(identifier: "tr_TR")
        return f.string(from: date)
    }

    private static func fmt0(_ v: Double) -> String { String(format: "%.0f", v) }
    private static func fmt1(_ v: Double) -> String { String(format: "%.1f", v) }
}
