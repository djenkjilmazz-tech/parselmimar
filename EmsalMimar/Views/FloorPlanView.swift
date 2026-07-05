import SwiftUI

// MARK: - Room Data

struct FPRoom: Identifiable {
    let id = UUID()
    /// Building-origin metre koordinatları (sol-alt = 0,0, Y yukarı artar).
    let meterRect: CGRect
    let label: String
    let area: Double
    let color: Color
}

// MARK: - Floor Plan Layout

struct FloorPlanLayoutData {
    let floorTitle: String
    let rooms: [FPRoom]
    let stairCore: CGRect?
    let elevatorCore: CGRect?
    let parkingSpots: [CGRect]
    let buildingW: Double
    let buildingD: Double

    var totalArea: Double { rooms.reduce(0) { $0 + $1.area } }
}

// MARK: - Generator

struct FloorPlanGenerator {
    let bW: Double
    let bD: Double
    let kullanimTuru: KullanimTuru
    let katSayisi: Int

    private let wt = 0.30   // dış duvar kalınlığı (m)

    func layout(for floorIndex: Int) -> FloorPlanLayoutData {
        let W = max(6, bW), D = max(5, bD)
        if floorIndex == 0 { return bodrum(W: W, D: D) }

        switch kullanimTuru {
        case .konut, .villa:
            return konutKat(W: W, D: D, katNo: floorIndex)
        case .ticaret:
            return ticaretKat(W: W, D: D, katNo: floorIndex, label: floorIndex == 1 ? "Zemin Kat" : "\(floorIndex - 1). Kat")
        case .karma:
            if floorIndex <= 2 {
                return ticaretKat(W: W, D: D, katNo: floorIndex, label: floorIndex == 1 ? "Zemin Kat" : "1. Kat")
            }
            return konutKat(W: W, D: D, katNo: floorIndex)
        default:
            return ticaretKat(W: W, D: D, katNo: floorIndex, label: floorIndex == 1 ? "Zemin Kat" : "\(floorIndex - 1). Kat")
        }
    }

    // MARK: Bodrum
    private func bodrum(W: Double, D: Double) -> FloorPlanLayoutData {
        let cW = 3.5, cD = 4.0
        let cX = (W - cW) / 2, cY = D - wt - cD
        let core = CGRect(x: cX, y: cY, width: cW, height: cD)

        let sW = max(3.0, W * 0.14)
        let siginak = CGRect(x: W - wt - sW, y: cY, width: sW, height: 3.5)
        let tW = max(2.5, W * 0.12)
        let tesisat = CGRect(x: wt, y: cY, width: tW, height: 3.5)

        let innerH = D - wt * 2 - cD - 0.5
        let innerW = W - wt * 2
        let parking = CGRect(x: wt, y: wt, width: innerW, height: innerH)

        var spots: [CGRect] = []
        let spotW = 2.5, spotD = 5.0, aisleD = 6.0
        let cols = max(1, Int(innerW / spotW))
        for c in 0..<cols {
            let sx = wt + Double(c) * spotW
            guard sx + spotW <= W - wt else { continue }
            spots.append(CGRect(x: sx, y: wt, width: spotW, height: min(spotD, innerH)))
            let r2y = wt + spotD + aisleD
            if r2y + spotD <= wt + innerH {
                spots.append(CGRect(x: sx, y: r2y, width: spotW, height: min(spotD, wt + innerH - r2y)))
            }
        }

        let rooms: [FPRoom] = [
            FPRoom(meterRect: parking,  label: "Otopark",       area: innerW * innerH, color: Color(red: 0.93, green: 0.93, blue: 0.87)),
            FPRoom(meterRect: siginak,  label: "Sığınak",       area: sW * 3.5,        color: Color(red: 0.80, green: 0.83, blue: 0.93)),
            FPRoom(meterRect: tesisat,  label: "Tesisat Odası", area: tW * 3.5,        color: Color(red: 0.82, green: 0.92, blue: 0.82)),
        ]
        let elev: CGRect? = katSayisi >= 4 ? CGRect(x: cX + cW * 0.55, y: cY, width: cW * 0.45, height: 2.2) : nil
        return FloorPlanLayoutData(floorTitle: "Bodrum Kat", rooms: rooms, stairCore: core,
                                    elevatorCore: elev, parkingSpots: spots, buildingW: W, buildingD: D)
    }

    // MARK: Ticaret / Ofis
    private func ticaretKat(W: Double, D: Double, katNo: Int, label: String) -> FloorPlanLayoutData {
        let cW = 3.5, cD = 4.5
        let cX = (W - cW) / 2, cY = D - wt - cD
        let core = CGRect(x: cX, y: cY, width: cW, height: cD)

        let innerW = W - wt * 2
        let storeD = D - wt * 2 - cD - 0.5
        let count = max(1, Int(W / 7.0))
        let storeW = innerW / Double(count)

        var rooms: [FPRoom] = []
        for i in 0..<count {
            let sx = wt + Double(i) * storeW
            let rect = CGRect(x: sx, y: wt, width: storeW, height: storeD)
            rooms.append(FPRoom(meterRect: rect, label: "Dükkan \(i + 1)", area: storeW * storeD,
                                color: Color(red: 0.82, green: 0.92, blue: 1.0)))
        }
        let servD = cD + 0.5
        let servRect = CGRect(x: wt, y: D - wt - servD, width: innerW, height: servD)
        rooms.append(FPRoom(meterRect: servRect, label: "Servis / Depo", area: innerW * servD,
                            color: Color(red: 0.88, green: 0.88, blue: 0.84)))

        let elev: CGRect? = katSayisi >= 4 ? CGRect(x: cX + cW * 0.55, y: cY, width: cW * 0.45, height: 2.2) : nil
        return FloorPlanLayoutData(floorTitle: label, rooms: rooms, stairCore: core,
                                    elevatorCore: elev, parkingSpots: [], buildingW: W, buildingD: D)
    }

    // MARK: Konut / Villa
    private func konutKat(W: Double, D: Double, katNo: Int) -> FloorPlanLayoutData {
        let title = kullanimTuru == .villa
            ? (katNo == 1 ? "Zemin Kat (Villa)" : "\(katNo - 1). Kat (Villa)")
            : (katNo == 1 ? "Zemin Kat" : "\(katNo - 1). Kat")

        let cW = 3.5, cD = 4.0
        let cX = (W - cW) / 2, cY = D - wt - cD
        let core = CGRect(x: cX, y: cY, width: cW, height: cD)

        if kullanimTuru == .villa {
            let rooms = villaRooms(W: W, D: D)
            return FloorPlanLayoutData(floorTitle: title, rooms: rooms, stairCore: katSayisi > 1 ? core : nil,
                                        elevatorCore: nil, parkingSpots: [], buildingW: W, buildingD: D)
        }

        let innerH = D - wt * 2 - cD - 0.5
        let ndaire: Int = W < 10 ? 1 : W < 18 ? 2 : 3
        let corrW = 1.5
        let dW = (W - wt * 2 - corrW * Double(ndaire - 1)) / Double(ndaire)

        var rooms: [FPRoom] = []
        for i in 0..<ndaire {
            let dx = wt + Double(i) * (dW + corrW)
            rooms += daireRooms(x: dx, y: wt, w: dW, d: innerH, no: i + 1)
            if i < ndaire - 1 {
                let cr = CGRect(x: dx + dW, y: wt, width: corrW, height: innerH)
                rooms.append(FPRoom(meterRect: cr, label: "", area: corrW * innerH,
                                    color: Color(red: 0.90, green: 0.88, blue: 0.85)))
            }
        }
        let elev: CGRect? = katSayisi >= 4 ? CGRect(x: cX + cW * 0.55, y: cY, width: cW * 0.45, height: 2.2) : nil
        return FloorPlanLayoutData(floorTitle: title, rooms: rooms, stairCore: core,
                                    elevatorCore: elev, parkingSpots: [], buildingW: W, buildingD: D)
    }

    private func daireRooms(x: Double, y: Double, w: Double, d: Double, no: Int) -> [FPRoom] {
        guard w > 4, d > 4 else {
            return [FPRoom(meterRect: CGRect(x: x, y: y, width: w, height: d),
                           label: "Daire \(no)", area: w * d, color: Color(red: 0.96, green: 0.93, blue: 0.86))]
        }
        let sD = max(3.5, d * 0.42), bkD = d - sD
        let bedW = w * 0.62, srvW = w - bedW
        return [
            FPRoom(meterRect: CGRect(x: x,        y: y,              width: w,    height: sD),         label: "Salon",         area: w    * sD,         color: Color(red: 0.98, green: 0.95, blue: 0.86)),
            FPRoom(meterRect: CGRect(x: x,        y: y + sD,         width: bedW, height: bkD * 0.55), label: "Yatak Odası 1", area: bedW * bkD * 0.55, color: Color(red: 0.87, green: 0.93, blue: 1.00)),
            FPRoom(meterRect: CGRect(x: x,        y: y + sD + bkD * 0.55, width: bedW, height: bkD * 0.45), label: "Yatak Odası 2", area: bedW * bkD * 0.45, color: Color(red: 0.85, green: 0.91, blue: 1.00)),
            FPRoom(meterRect: CGRect(x: x + bedW, y: y + sD,         width: srvW, height: bkD * 0.50), label: "Mutfak",        area: srvW * bkD * 0.50, color: Color(red: 0.88, green: 0.97, blue: 0.88)),
            FPRoom(meterRect: CGRect(x: x + bedW, y: y + sD + bkD * 0.50, width: srvW, height: bkD * 0.30), label: "Banyo", area: srvW * bkD * 0.30, color: Color(red: 0.82, green: 0.92, blue: 0.97)),
            FPRoom(meterRect: CGRect(x: x + bedW, y: y + sD + bkD * 0.80, width: srvW, height: bkD * 0.20), label: "WC",    area: srvW * bkD * 0.20, color: Color(red: 0.82, green: 0.92, blue: 0.97)),
        ]
    }

    private func villaRooms(W: Double, D: Double) -> [FPRoom] {
        let iW = W - wt * 2, iD = D - wt * 2
        let lD = iD * 0.42, bD = iD * 0.36, sD = iD - lD - bD
        let mW = iW * 0.57
        return [
            FPRoom(meterRect: CGRect(x: wt,      y: wt,          width: iW,       height: lD), label: "Salon + Mutfak",  area: iW * lD,        color: Color(red: 0.98, green: 0.95, blue: 0.86)),
            FPRoom(meterRect: CGRect(x: wt,      y: wt + lD,     width: mW,       height: bD), label: "Ana Yatak",       area: mW * bD,        color: Color(red: 0.87, green: 0.93, blue: 1.00)),
            FPRoom(meterRect: CGRect(x: wt + mW, y: wt + lD,     width: iW - mW,  height: bD), label: "Yatak Odası",    area: (iW - mW) * bD, color: Color(red: 0.85, green: 0.91, blue: 1.00)),
            FPRoom(meterRect: CGRect(x: wt,      y: wt + lD + bD, width: iW * 0.38, height: sD), label: "Banyo / WC",  area: iW * 0.38 * sD, color: Color(red: 0.82, green: 0.92, blue: 0.97)),
            FPRoom(meterRect: CGRect(x: wt + iW * 0.38, y: wt + lD + bD, width: iW * 0.32, height: sD), label: "Hol",  area: iW * 0.32 * sD, color: Color(red: 0.92, green: 0.90, blue: 0.87)),
            FPRoom(meterRect: CGRect(x: wt + iW * 0.70, y: wt + lD + bD, width: iW * 0.30, height: sD), label: "Çamaşır", area: iW * 0.30 * sD, color: Color(red: 0.88, green: 0.93, blue: 0.90)),
        ]
    }
}

// MARK: - Canvas

struct FloorPlanCanvasView: View {
    let layout: FloorPlanLayoutData

    var body: some View {
        Canvas { ctx, size in draw(ctx: ctx, size: size) }
            .background(Color(white: 0.96))
    }

    // swiftlint:disable:next function_body_length
    private func draw(ctx: GraphicsContext, size: CGSize) {
        let W = layout.buildingW, D = layout.buildingD
        let ml: CGFloat = 32, mr: CGFloat = 62, mt: CGFloat = 18, mb: CGFloat = 54
        let scale = min((size.width - ml - mr) / CGFloat(W), (size.height - mt - mb) / CGFloat(D))
        let dW = CGFloat(W) * scale, dH = CGFloat(D) * scale
        let ox = ml + ((size.width - ml - mr) - dW) / 2
        let oy = mt + ((size.height - mt - mb) - dH) / 2

        // metre → canvas (Y flipped)
        func px(_ mx: Double, _ my: Double) -> CGPoint {
            CGPoint(x: ox + CGFloat(mx) * scale, y: oy + dH - CGFloat(my) * scale)
        }
        func cRect(_ mr: CGRect) -> CGRect {
            let tl = px(mr.minX, mr.maxY)
            return CGRect(x: tl.x, y: tl.y, width: CGFloat(mr.width) * scale, height: CGFloat(mr.height) * scale)
        }

        // İç duvar yarı-kalınlığı (15 cm): oda rektleri bu kadar küçültülünce aralar duvar rengi gösterir
        let iw: CGFloat = max(1.2, 0.075 * scale)
        let wallColor = Color(red: 0.16, green: 0.16, blue: 0.20)
        let wallShading: GraphicsContext.Shading = .color(wallColor)

        // 1 — Sayfa arka planı
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.94)))

        // 2 — Çizim gölgesi
        ctx.fill(Path(CGRect(x: ox + 3, y: oy + 3, width: dW, height: dH)),
                 with: .color(Color(white: 0.50).opacity(0.30)))

        // 3 — Bina alanı tamamen duvar rengiyle doldurulur; odalar üstüne kazınır
        ctx.fill(Path(CGRect(x: ox, y: oy, width: dW, height: dH)), with: wallShading)

        // 4 — Oda dolguları (içe çekilmiş → aralar = duvar)
        for room in layout.rooms {
            let rr = cRect(room.meterRect).insetBy(dx: iw, dy: iw)
            guard rr.width > 0, rr.height > 0 else { continue }
            ctx.fill(Path(rr), with: .color(room.color.opacity(0.90)))
        }

        // 5 — Pencere açıklıkları dış duvarda cam rengi kesit
        if layout.parkingSpots.isEmpty {
            drawWindowOpenings(ctx: ctx, ox: ox, oy: oy, dW: dW, dH: dH, scale: scale)
        }

        // 6 — Park yeri çizgileri (bodrum)
        for spot in layout.parkingSpots {
            let sr = cRect(spot)
            var p = Path(); p.addRect(sr)
            ctx.stroke(p, with: .color(.gray.opacity(0.42)), style: StrokeStyle(lineWidth: 0.75))
        }

        // 7 — Merdiven çekirdeği
        if let core = layout.stairCore {
            let cr = cRect(core).insetBy(dx: iw * 0.5, dy: iw * 0.5)
            if cr.width > 0, cr.height > 0 {
                ctx.fill(Path(cr), with: .color(Color(white: 0.68)))
                let steps = 10
                for s in 1..<steps {
                    let sy = cr.minY + CGFloat(s) * cr.height / CGFloat(steps)
                    var sl = Path()
                    sl.move(to: CGPoint(x: cr.minX + 1.5, y: sy))
                    sl.addLine(to: CGPoint(x: cr.maxX - 1.5, y: sy))
                    ctx.stroke(sl, with: .color(Color(white: 0.30).opacity(0.55)), style: StrokeStyle(lineWidth: 0.65))
                }
                let mx = cr.midX
                var arr = Path()
                arr.move(to: CGPoint(x: mx, y: cr.maxY - 4)); arr.addLine(to: CGPoint(x: mx, y: cr.minY + 5))
                arr.addLine(to: CGPoint(x: mx - 4, y: cr.minY + 11))
                arr.move(to: CGPoint(x: mx, y: cr.minY + 5))
                arr.addLine(to: CGPoint(x: mx + 4, y: cr.minY + 11))
                ctx.stroke(arr, with: .color(.black.opacity(0.60)), style: StrokeStyle(lineWidth: 1))
                var ol = Path(); ol.addRect(cr)
                ctx.stroke(ol, with: wallShading, style: StrokeStyle(lineWidth: 2.0))
                if cr.width > 22 {
                    ctx.draw(Text("MERDİVEN").font(.system(size: min(7, cr.width / 8))).foregroundStyle(.black),
                             at: CGPoint(x: cr.midX, y: cr.midY + 7))
                }
            }
        }

        // 8 — Asansör
        if let elev = layout.elevatorCore {
            let er = cRect(elev).insetBy(dx: iw * 0.4, dy: iw * 0.4)
            if er.width > 0, er.height > 0 {
                ctx.fill(Path(er), with: .color(Color(white: 0.50)))
                var cross = Path()
                cross.move(to: CGPoint(x: er.minX + 2, y: er.minY + 2)); cross.addLine(to: CGPoint(x: er.maxX - 2, y: er.maxY - 2))
                cross.move(to: CGPoint(x: er.maxX - 2, y: er.minY + 2)); cross.addLine(to: CGPoint(x: er.minX + 2, y: er.maxY - 2))
                ctx.stroke(cross, with: .color(Color(white: 0.22)), style: StrokeStyle(lineWidth: 1))
                var ep = Path(); ep.addRect(er)
                ctx.stroke(ep, with: wallShading, style: StrokeStyle(lineWidth: 1.5))
            }
        }

        // 9 — Kapı sembolleri (yay + kanat)
        drawDoorSymbols(ctx: ctx, cRect: cRect, iw: iw, wallColor: wallColor)

        // 10 — Oda etiketleri ve alanlar
        for room in layout.rooms {
            guard !room.label.isEmpty else { continue }
            let rr = cRect(room.meterRect).insetBy(dx: iw, dy: iw)
            guard rr.width > 24, rr.height > 16 else { continue }
            let fs = max(6.0, min(10.5, min(rr.width / CGFloat(max(5, room.label.count)) * 1.4, rr.height / 3.5)))
            let lines = splitLabel(room.label, maxW: rr.width, fs: fs)
            let lh = fs * 1.25
            var ly = rr.midY - lh * CGFloat(lines.count) / 2
            for line in lines {
                ctx.draw(Text(line).font(.system(size: fs, weight: .semibold)).foregroundStyle(.black),
                         at: CGPoint(x: rr.midX, y: ly + lh / 2))
                ly += lh
            }
            let afs = max(5.5, fs * 0.76)
            let ay = rr.midY + lh * CGFloat(lines.count) / 2 + afs * 0.6
            if ay + afs < rr.maxY - 3 {
                ctx.draw(Text(String(format: "%.1f m²", room.area)).font(.system(size: afs)).foregroundStyle(Color(white: 0.35)),
                         at: CGPoint(x: rr.midX, y: ay))
            }
        }

        // 11 — Dış duvar çift çizgi (mimari)
        let wallPx = max(2.8, CGFloat(0.30) * scale)
        var outerA = Path(); outerA.addRect(CGRect(x: ox, y: oy, width: dW, height: dH))
        ctx.stroke(outerA, with: wallShading, style: StrokeStyle(lineWidth: wallPx))
        var outerB = Path(); outerB.addRect(CGRect(x: ox - 1.5, y: oy - 1.5, width: dW + 3, height: dH + 3))
        ctx.stroke(outerB, with: .color(wallColor.opacity(0.50)), style: StrokeStyle(lineWidth: 0.55))

        // 12 — Ölçü çizgileri
        let dimC: GraphicsContext.Shading = .color(Color(red: 0.10, green: 0.20, blue: 0.72))
        let tick: CGFloat = 5
        let dimY = oy + dH + 16
        var wl = Path()
        wl.move(to: CGPoint(x: ox, y: dimY)); wl.addLine(to: CGPoint(x: ox + dW, y: dimY))
        wl.move(to: CGPoint(x: ox, y: dimY - tick)); wl.addLine(to: CGPoint(x: ox, y: dimY + tick))
        wl.move(to: CGPoint(x: ox + dW, y: dimY - tick)); wl.addLine(to: CGPoint(x: ox + dW, y: dimY + tick))
        ctx.stroke(wl, with: dimC, style: StrokeStyle(lineWidth: 0.85))
        ctx.draw(Text(String(format: "%.1f m", W)).font(.system(size: 9, weight: .medium)).foregroundStyle(.blue),
                 at: CGPoint(x: ox + dW / 2, y: dimY + 11))

        let dimX = ox + dW + 14
        var dl = Path()
        dl.move(to: CGPoint(x: dimX, y: oy)); dl.addLine(to: CGPoint(x: dimX, y: oy + dH))
        dl.move(to: CGPoint(x: dimX - tick, y: oy)); dl.addLine(to: CGPoint(x: dimX + tick, y: oy))
        dl.move(to: CGPoint(x: dimX - tick, y: oy + dH)); dl.addLine(to: CGPoint(x: dimX + tick, y: oy + dH))
        ctx.stroke(dl, with: dimC, style: StrokeStyle(lineWidth: 0.85))
        ctx.draw(Text(String(format: "%.1f m", D)).font(.system(size: 9, weight: .medium)).foregroundStyle(.blue),
                 at: CGPoint(x: dimX + 19, y: oy + dH / 2))

        // 13 — Kuzey oku
        let nx = size.width - 22, ny = mt + 22
        var nf = Path()
        nf.move(to: CGPoint(x: nx, y: ny - 15)); nf.addLine(to: CGPoint(x: nx - 5, y: ny + 6)); nf.addLine(to: CGPoint(x: nx, y: ny + 1)); nf.closeSubpath()
        ctx.fill(nf, with: .color(.black))
        var no_ = Path()
        no_.move(to: CGPoint(x: nx, y: ny - 15)); no_.addLine(to: CGPoint(x: nx + 5, y: ny + 6)); no_.addLine(to: CGPoint(x: nx, y: ny + 1)); no_.closeSubpath()
        ctx.stroke(no_, with: .color(.black), lineWidth: 0.8)
        ctx.draw(Text("K").font(.system(size: 9, weight: .bold)).foregroundStyle(.black), at: CGPoint(x: nx, y: ny - 24))

        // 14 — Plan başlığı
        ctx.draw(Text(layout.floorTitle).font(.system(size: 11, weight: .bold)).foregroundStyle(.black),
                 at: CGPoint(x: ox + dW / 2, y: oy + dH + mb - 17))
        ctx.draw(Text("Şematik Plan — Ölçeksiz").font(.system(size: 7.5)).foregroundStyle(Color(white: 0.50)),
                 at: CGPoint(x: ox + dW / 2, y: oy + dH + mb - 5))
    }

    /// Dış duvarlarda cam rengi pencere açıklıkları (bölücü çizgili)
    private func drawWindowOpenings(ctx: GraphicsContext, ox: CGFloat, oy: CGFloat,
                                     dW: CGFloat, dH: CGFloat, scale: CGFloat) {
        let wallThk = max(2.5, CGFloat(0.30) * scale)
        let glassColor = Color(red: 0.70, green: 0.88, blue: 0.98).opacity(0.88)
        let frameColor = Color(white: 0.55)
        let intervalM = max(2.5, layout.buildingW / 5)
        let wPx = CGFloat(intervalM * 0.55) * scale
        let margin = CGFloat(0.35) * scale + 6

        for face in 0..<2 {
            var x = ox + margin
            while x + wPx < ox + dW - margin {
                let winRect: CGRect
                if face == 0 {
                    // Ön cephe — canvas alt kenar
                    winRect = CGRect(x: x, y: oy + dH - wallThk, width: wPx, height: wallThk)
                } else {
                    // Arka cephe — canvas üst kenar
                    winRect = CGRect(x: x, y: oy, width: wPx, height: wallThk)
                }
                ctx.fill(Path(winRect), with: .color(glassColor))
                // Orta bölücü çizgi
                var div = Path()
                div.move(to: CGPoint(x: x + wPx / 2, y: winRect.minY))
                div.addLine(to: CGPoint(x: x + wPx / 2, y: winRect.maxY))
                ctx.stroke(div, with: .color(frameColor), style: StrokeStyle(lineWidth: 0.6))
                // Çerçeve
                var fr = Path(); fr.addRect(winRect)
                ctx.stroke(fr, with: .color(frameColor.opacity(0.5)), style: StrokeStyle(lineWidth: 0.5))
                x += CGFloat(intervalM) * scale
            }
        }
    }

    /// Oda kapıları — yay + kanat sembolü
    private func drawDoorSymbols(ctx: GraphicsContext,
                                   cRect: (CGRect) -> CGRect,
                                   iw: CGFloat,
                                   wallColor: Color) {
        let doorColor = Color(white: 0.85)
        let arcColor = Color(white: 0.50).opacity(0.55)

        for room in layout.rooms {
            guard !room.label.isEmpty else { continue }
            let rr = cRect(room.meterRect).insetBy(dx: iw, dy: iw)
            guard rr.width > 18, rr.height > 18 else { continue }

            // Kapı her odanın sol alt köşesine yatay yerleştir
            let dw: CGFloat = min(rr.width * 0.28, 18)  // kapı genişliği canvas px
            let dx = rr.minX
            let dy = rr.maxY - iw * 0.5  // odanın alt duvarında

            // Kapı kanadı (yatay çizgi)
            var leaf = Path()
            leaf.move(to: CGPoint(x: dx, y: dy))
            leaf.addLine(to: CGPoint(x: dx + dw, y: dy))
            ctx.stroke(leaf, with: .color(doorColor), style: StrokeStyle(lineWidth: 1.1))

            // Kapı yayı (dörtte bir çember)
            var arc = Path()
            arc.addArc(center: CGPoint(x: dx, y: dy),
                       radius: dw,
                       startAngle: .degrees(0),
                       endAngle: .degrees(-90),
                       clockwise: true)
            ctx.stroke(arc, with: .color(arcColor), style: StrokeStyle(lineWidth: 0.65, dash: [2, 1.5]))
        }
    }

    private func splitLabel(_ s: String, maxW: CGFloat, fs: CGFloat) -> [String] {
        let words = s.split(separator: " ").map(String.init)
        guard words.count > 1, Double(s.count) * Double(fs) * 0.58 > Double(maxW) else { return [s] }
        let mid = words.count / 2
        return [words[0..<mid].joined(separator: " "), words[mid...].joined(separator: " ")]
    }
}

// MARK: - Site Plan Mini View (çoklu bina vaziyet şeması)

struct SitePlanMiniView: View {
    let binaSayisi: Int
    let selectedBuilding: Int
    let buildingW: Double
    let buildingD: Double

    private var cols: Int { binaSayisi <= 2 ? binaSayisi : Int(ceil(sqrt(Double(binaSayisi)))) }
    private var rows: Int { Int(ceil(Double(binaSayisi) / Double(cols))) }

    var body: some View {
        Canvas { ctx, size in
            let gap: CGFloat = 6
            let totalCols = CGFloat(cols), totalRows = CGFloat(rows)
            let cellW = (size.width - gap * (totalCols + 1)) / totalCols
            let cellH = (size.height - gap * (totalRows + 1)) / totalRows
            // Oran: bina eni/derinliği
            let ratio = buildingD > 0 ? CGFloat(buildingW / buildingD) : 1.0
            let (_, bH): (CGFloat, CGFloat) = ratio >= 1
                ? (min(cellW, cellH * ratio), min(cellH, cellW / ratio))
                : (min(cellW, cellH * ratio), min(cellH, cellW / ratio))
            let adjW = min(cellW, bH * ratio)
            let adjH = min(cellH, adjW / max(ratio, 0.01))

            for i in 0..<binaSayisi {
                let c = i % cols, r = i / cols
                let cx = gap + CGFloat(c) * (cellW + gap) + cellW / 2
                let cy = gap + CGFloat(r) * (cellH + gap) + cellH / 2
                let rect = CGRect(x: cx - adjW / 2, y: cy - adjH / 2, width: adjW, height: adjH)
                let isSelected = (i + 1) == selectedBuilding
                ctx.fill(Path(roundedRect: rect, cornerRadius: 2),
                         with: .color(isSelected ? Color.accentColor : Color(white: 0.72)))
                if isSelected {
                    var border = Path(); border.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
                    ctx.stroke(border, with: .color(.accentColor), style: StrokeStyle(lineWidth: 1.5))
                    ctx.draw(Text("\(i + 1)").font(.system(size: 8, weight: .bold)).foregroundStyle(.white),
                             at: CGPoint(x: rect.midX, y: rect.midY))
                } else {
                    ctx.draw(Text("\(i + 1)").font(.system(size: 7)).foregroundStyle(Color(white: 0.35)),
                             at: CGPoint(x: rect.midX, y: rect.midY))
                }
            }
        }
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .topLeading) {
            Text("Vaziyet")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(5)
        }
    }
}

// MARK: - Floor Plan View (Tab İçeriği)

struct FloorPlanView: View {
    let buildingW: Double
    let buildingD: Double
    let binaSayisi: Int
    let project: Project
    let hesaplamaSonucu: EmsalCalculator.HesaplamaSonucu?

    @State private var selectedFloor = 1
    @State private var selectedBuilding = 1

    // KAKS/Hmax kısıtlı gerçek kat adedi — hesaplama sonucu varsa oradan al
    private var effectiveKatSayisi: Int {
        hesaplamaSonucu?.asilKatSayisi ?? project.katSayisi
    }
    private var totalFloors: Int { max(2, 1 + effectiveKatSayisi) }
    private var isMulti: Bool { binaSayisi > 1 }

    private func floorName(_ i: Int) -> String {
        if i == 0 { return "Bodrum Kat" }
        if i == 1 { return "Zemin Kat" }
        return "\(i - 1). Kat"
    }

    private func generator() -> FloorPlanGenerator {
        FloorPlanGenerator(bW: buildingW, bD: buildingD,
                           kullanimTuru: project.kullanimTuru,
                           katSayisi: effectiveKatSayisi)
    }

    var body: some View {
        let gen = generator()
        let layout = gen.layout(for: min(selectedFloor, totalFloors - 1))

        VStack(spacing: 12) {
            // Yapı seçici (çoklu bina varsa)
            if isMulti {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(1...binaSayisi, id: \.self) { i in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { selectedBuilding = i }
                            } label: {
                                Text("Yapı \(i)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 7)
                                    .background(selectedBuilding == i ? Color.green : Color.secondary.opacity(0.13))
                                    .foregroundStyle(selectedBuilding == i ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Çoklu bina vaziyet planı özeti
            if isMulti {
                SitePlanMiniView(binaSayisi: binaSayisi, selectedBuilding: selectedBuilding,
                                 buildingW: buildingW, buildingD: buildingD)
                    .frame(height: 72)
                    .padding(.horizontal)
            }

            // Kat seçici
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<totalFloors, id: \.self) { i in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { selectedFloor = i }
                        } label: {
                            Text(floorName(i))
                                .font(.caption.bold())
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background(selectedFloor == i ? Color.accentColor : Color.secondary.opacity(0.13))
                                .foregroundStyle(selectedFloor == i ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            // Canvas
            FloorPlanCanvasView(layout: layout)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
                .padding(.horizontal)
                .id("\(selectedFloor)-\(selectedBuilding)")

            // Oda listesi
            GroupBox {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Oda / Bölüm").font(.caption.bold()).foregroundStyle(.secondary)
                        Spacer()
                        Text("Alan").font(.caption.bold()).foregroundStyle(.secondary)
                    }
                    Divider()
                    ForEach(layout.rooms.filter { !$0.label.isEmpty && $0.area > 0.5 }) { room in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2).fill(room.color).frame(width: 10, height: 10)
                            Text(room.label).font(.caption)
                            Spacer()
                            Text(String(format: "%.1f m²", room.area))
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    HStack {
                        Text("Kat Toplam").font(.caption.bold())
                        Spacer()
                        Text(String(format: "%.0f m²", layout.totalArea))
                            .font(.caption.monospacedDigit().bold()).foregroundStyle(.blue)
                    }
                }
            }
            .padding(.horizontal)

            // EmsalCalculator tüm katlar özeti
            if let sonuc = hesaplamaSonucu {
                GroupBox {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Tüm Katlar Özeti", systemImage: "building.2")
                            .font(.caption.bold()).foregroundStyle(.secondary)
                        Divider()
                        ForEach(sonuc.katBilgileri, id: \.katNo) { kat in
                            HStack {
                                Text(kat.katAdi)
                                    .font(.caption)
                                    .foregroundStyle(kat.katNo < 0 ? .secondary : .primary)
                                Text("·").font(.caption).foregroundStyle(.tertiary)
                                Text(kat.kullanimAmaci).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(EmsalCalculator.formatAlan(kat.brutAlan))
                                        .font(.caption.monospacedDigit().bold())
                                    Text("Net: \(EmsalCalculator.formatAlan(kat.netAlan))")
                                        .font(.system(size: 9)).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Divider()
                        HStack {
                            Text("Toplam Brüt").font(.caption.bold())
                            Spacer()
                            Text(EmsalCalculator.formatAlan(sonuc.brutInsaatAlani))
                                .font(.caption.monospacedDigit().bold()).foregroundStyle(.green)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
