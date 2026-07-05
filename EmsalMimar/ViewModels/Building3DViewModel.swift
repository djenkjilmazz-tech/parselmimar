import Foundation
import SceneKit
import SwiftUI
import CoreLocation

@Observable
class Building3DViewModel {
    var scene: SCNScene
    var buildingNode: SCNNode?
    var showParcelBoundary: Bool = true
    var showSetbackLines: Bool = true
    var showBalconies: Bool = true

    private let katYuksekligi: Float = 3.0

    init() {
        scene = SCNScene()
        setupScene()
    }

    // MARK: - Scene Setup

    private func setupScene() {
        // Nötr studio arka planı — SolidWorks'teki gibi gradient gri
        scene.background.contents = [
            UIColor(white: 0.92, alpha: 1),   // top
            UIColor(white: 0.82, alpha: 1),   // bottom
        ]

        // IBL için ortam ışığı kaynağı
        scene.lightingEnvironment.contents = UIColor(white: 0.85, alpha: 1)
        scene.lightingEnvironment.intensity = 1.2

        // Ambient (düşük tutulur, IBL zaten ambient'i karşılar)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 180
        ambient.light?.color = UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Ana güneş — yüksek intensity + keskin gölge
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 2200
        sun.light?.color = UIColor(red: 1.0, green: 0.97, blue: 0.92, alpha: 1)
        sun.light?.castsShadow = true
        sun.light?.shadowMode = .deferred
        sun.light?.shadowRadius = 1.5          // keskin gölge
        sun.light?.shadowSampleCount = 32
        sun.light?.shadowColor = UIColor(white: 0.0, alpha: 0.50)
        sun.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.eulerAngles = SCNVector3(-Float.pi / 3.2, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sun)

        // Fill ışığı — karşı açıdan soğuk mavi
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.intensity = 420
        fill.light?.color = UIColor(red: 0.72, green: 0.82, blue: 1.0, alpha: 1)
        fill.eulerAngles = SCNVector3(-Float.pi / 8, -Float.pi * 0.65, 0)
        scene.rootNode.addChildNode(fill)

        // Rim ışığı — arkadan parlak kenar vurgular
        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.intensity = 280
        rim.light?.color = UIColor(white: 0.95, alpha: 1)
        rim.eulerAngles = SCNVector3(Float.pi / 6, Float.pi * 1.2, 0)
        scene.rootNode.addChildNode(rim)
    }

    // MARK: - Build Model (type dispatcher)

    private struct SubLayout {
        let xOffset: Float
        let offsetZ: Float
        let width: Float
        let depth: Float
    }

    private func computeLayouts(count: Int, buildW: Float, buildD: Float,
                                 gapX: Float, gapZ: Float, centerZ: Float) -> [SubLayout] {
        guard count > 0 else { return [] }
        if count == 1 { return [SubLayout(xOffset: 0, offsetZ: centerZ, width: buildW, depth: buildD)] }
        let cols = count <= 2 ? count : Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(cols)))
        let subW = max(0.04, (buildW - gapX * Float(cols - 1)) / Float(cols))
        let subD = max(0.04, (buildD - gapZ * Float(rows - 1)) / Float(rows))
        let totalGroupD = Float(rows) * subD + Float(rows - 1) * gapZ
        let groupTopZ = centerZ + totalGroupD / 2 - subD / 2
        return (0..<count).map { i in
            let c = i % cols, r = i / cols
            let x = -buildW / 2 + Float(c) * (subW + gapX) + subW / 2
            let z = groupTopZ - Float(r) * (subD + gapZ)
            return SubLayout(xOffset: x, offsetZ: z, width: subW, depth: subD)
        }
    }

    func buildModel(
        tabanAlani: Double,
        katSayisi: Int,
        kullanimTuru: KullanimTuru,
        binaTipi: BinaTipi,
        binaSayisi: Int = 1,
        onCekme: Double,
        arkaCekme: Double,
        yanCekme: Double,
        parselKoordinatlar: Data? = nil,
        parselAlani: Double = 0,
        toplamInsaatAlani: Double = 0,  // KAKS kısıtı için
        hmax: Double = 0                // Hmax kısıtı için
    ) {
        scene.rootNode.childNodes
            .filter { $0.name?.hasPrefix("emsal_") == true }
            .forEach { $0.removeFromParentNode() }
        buildingNode = nil

        let root = SCNNode()
        root.name = "emsal_root"

        let ring = decodedRing(from: parselKoordinatlar)
        let (pW, pD) = parselSize(ring: ring, fallbackArea: parselAlani > 0 ? parselAlani : max(tabanAlani * 3, 100))
        let maxDim = max(pW, pD)
        let scale = Float(maxDim > 1 ? 2.0 / maxDim : 0.05)

        let scaledPW = Float(pW) * scale
        let scaledPD = Float(pD) * scale
        let availW = max(0.05, scaledPW - Float(yanCekme * 2) * scale)
        let availD = max(0.05, scaledPD - Float(onCekme + arkaCekme) * scale)
        // TAKS uyumu: mevcut çekme alanını taban alanıyla eşle
        let availAreaM2 = Double(availW) * Double(availD) / (Double(scale) * Double(scale))
        let taksRatio: Float = tabanAlani > 0 && availAreaM2 > tabanAlani + 1.0
            ? Float(sqrt(tabanAlani / availAreaM2)) : 1.0
        let buildW = availW * taksRatio
        let buildD = availD * taksRatio
        let buildOffsetZ = Float(onCekme - arkaCekme) / 2.0 * scale

        let context = makeContextGround(scaledPW: scaledPW, scaledPD: scaledPD)
        context.name = "emsal_context"
        root.addChildNode(context)

        let groundNode = makeParcelGround(ring: ring, scaledW: scaledPW, scaledPD: scaledPD, scale: scale)
        groundNode.name = "emsal_parcel"
        root.addChildNode(groundNode)

        let setbackNode = makeSetbackLines(
            scaledPW: scaledPW, scaledPD: scaledPD, scale: scale,
            onCekme: onCekme, arkaCekme: arkaCekme, yanCekme: yanCekme
        )
        setbackNode.name = "emsal_setback"
        root.addChildNode(setbackNode)

        // Architectural context — street, neighboring buildings, greenery
        let streetNode = makeStreetAndSidewalk(scaledPW: scaledPW, scaledPD: scaledPD)
        streetNode.name = "emsal_street"
        root.addChildNode(streetNode)

        let ctxNode = makeContextBuildings(scaledPW: scaledPW, scaledPD: scaledPD)
        ctxNode.name = "emsal_ctx_bldg"
        root.addChildNode(ctxNode)

        let vegNode = makeSiteVegetation(scaledPW: scaledPW, scaledPD: scaledPD, scale: scale,
                                          onCekme: onCekme, arkaCekme: arkaCekme, yanCekme: yanCekme)
        vegNode.name = "emsal_vegetation"
        root.addChildNode(vegNode)

        let compassNode = makeCompassMarkers(scaledPW: scaledPW, scaledPD: scaledPD)
        compassNode.name = "emsal_compass"
        root.addChildNode(compassNode)

        let buildingRoot = SCNNode()
        buildingRoot.name = "emsal_building"

        // Gerçek kat adedi: KAKS ve Hmax kısıtlarını 3D'de de uygula
        let maxKatKaks: Int = (toplamInsaatAlani > 0 && tabanAlani > 0)
            ? max(1, Int(toplamInsaatAlani / tabanAlani)) : katSayisi
        let maxKatHmax: Int = hmax > 0 ? max(1, Int(hmax / 3.0)) : katSayisi
        let effectiveKat = min(katSayisi, min(maxKatKaks, maxKatHmax))

        let n = max(1, binaSayisi)
        let gapX = Float(yanCekme) * scale
        let gapZ = gapX
        let layouts = computeLayouts(count: n, buildW: buildW, buildD: buildD,
                                      gapX: gapX, gapZ: gapZ, centerZ: buildOffsetZ)

        for layout in layouts {
            let container = SCNNode()
            container.position.x = layout.xOffset
            switch kullanimTuru {
            case .villa:
                buildVilla(on: container, buildW: layout.width, buildD: layout.depth,
                           katSayisi: effectiveKat, scale: scale, offsetZ: layout.offsetZ)
            case .sanayi:
                buildSanayi(on: container, buildW: layout.width, buildD: layout.depth,
                            katSayisi: effectiveKat, scale: scale, offsetZ: layout.offsetZ)
            case .ticaret:
                buildTicaret(on: container, buildW: layout.width, buildD: layout.depth,
                             katSayisi: effectiveKat, scale: scale, offsetZ: layout.offsetZ)
            case .karma:
                buildKarma(on: container, buildW: layout.width, buildD: layout.depth,
                           katSayisi: effectiveKat, scale: scale, offsetZ: layout.offsetZ)
            case .turizm:
                buildTurizm(on: container, buildW: layout.width, buildD: layout.depth,
                            katSayisi: effectiveKat, scale: scale, offsetZ: layout.offsetZ)
            default:
                buildStandard(on: container, buildW: layout.width, buildD: layout.depth,
                              katSayisi: effectiveKat, scale: scale, offsetZ: layout.offsetZ,
                              tur: kullanimTuru)
            }
            buildingRoot.addChildNode(container)
        }

        root.addChildNode(buildingRoot)
        scene.rootNode.addChildNode(root)
        buildingNode = root
        updateNodeVisibility()
    }

    // MARK: - Villa

    private func buildVilla(on parent: SCNNode, buildW: Float, buildD: Float,
                            katSayisi: Int, scale: Float, offsetZ: Float) {
        let renderedFloors = min(katSayisi, 3)
        let floorH = katYuksekligi * scale

        // Stone sokle
        let sokleH = floorH * 0.16
        addBox(to: parent, size: (buildW + 0.022, sokleH, buildD + 0.022),
               pos: (0, sokleH / 2, offsetZ),
               color: UIColor(red: 0.60, green: 0.56, blue: 0.50, alpha: 1), roughness: 0.88)

        var topY: Float = sokleH
        for kat in 0..<renderedFloors {
            let y = sokleH + Float(kat) * floorH + floorH / 2
            let katNode = addBox(to: parent, size: (buildW, floorH, buildD),
                                 pos: (0, y, offsetZ),
                                 color: UIColor(red: 0.96, green: 0.92, blue: 0.83, alpha: 1), roughness: 0.65)
            katNode.name = "emsal_floor_\(kat)"
            addVillaWindows(to: katNode, width: buildW, height: floorH, depth: buildD, isGround: kat == 0)
            if kat > 0 {
                addBalcony(to: katNode, width: buildW, height: floorH, depth: buildD)
            }
            topY = sokleH + Float(kat + 1) * floorH
        }

        // Hip roof — wide, low pitch
        let roofH = buildW * 0.30
        let overhang: Float = 0.022
        let roofGeo = SCNPyramid(width: CGFloat(buildW + overhang * 2),
                                  height: CGFloat(roofH),
                                  length: CGFloat(buildD + overhang * 2))
        roofGeo.materials = [makeMat(UIColor(red: 0.60, green: 0.28, blue: 0.12, alpha: 1), rough: 0.78)]
        let roofNode = SCNNode(geometry: roofGeo)
        roofNode.name = "emsal_roof"
        // SCNPyramid pivot is at base (Y=0), not centered — place directly at building top
        roofNode.position = SCNVector3(0, topY, offsetZ)
        parent.addChildNode(roofNode)

        // Eave fascia band
        let fasciaH = floorH * 0.045
        addBox(to: parent, size: (buildW + overhang * 2 + 0.010, fasciaH, buildD + overhang * 2 + 0.010),
               pos: (0, topY + fasciaH / 2, offsetZ),
               color: UIColor(red: 0.87, green: 0.83, blue: 0.75, alpha: 1), roughness: 0.60)

        // Front entrance porch
        let porchW = buildW * 0.36
        let porchD = floorH * 0.42
        let porchH = floorH * 0.82
        let frontZ = buildD / 2 + offsetZ
        // Porch floor slab
        addBox(to: parent, size: (porchW, floorH * 0.04, porchD),
               pos: (0, sokleH + floorH * 0.02, frontZ + porchD / 2),
               color: UIColor(red: 0.83, green: 0.80, blue: 0.74, alpha: 1), roughness: 0.70)
        // Canopy
        addBox(to: parent, size: (porchW + 0.014, floorH * 0.030, porchD + 0.010),
               pos: (0, sokleH + porchH, frontZ + porchD / 2),
               color: UIColor(red: 0.80, green: 0.76, blue: 0.68, alpha: 1), roughness: 0.65)
        // Columns
        let colW: Float = 0.011
        let colMat = makeMat(UIColor(red: 0.92, green: 0.90, blue: 0.86, alpha: 1), rough: 0.52)
        for sign: Float in [-1, 1] {
            let colGeo = SCNBox(width: CGFloat(colW), height: CGFloat(porchH),
                                length: CGFloat(colW), chamferRadius: 0.002)
            colGeo.materials = [colMat]
            let colNode = SCNNode(geometry: colGeo)
            colNode.position = SCNVector3(sign * porchW * 0.36, sokleH + porchH / 2,
                                          frontZ + porchD - colW / 2)
            parent.addChildNode(colNode)
        }
        // Door
        let doorW = porchW * 0.44
        let doorH = floorH * 0.63
        addBox(to: parent, size: (doorW, doorH, 0.002),
               pos: (0, sokleH + doorH / 2, frontZ + 0.001),
               color: UIColor(red: 0.38, green: 0.22, blue: 0.10, alpha: 1), roughness: 0.62)

        // Chimney
        let chimW: Float = 0.017
        let chimH = roofH * 0.55
        addBox(to: parent, size: (chimW, chimH, chimW),
               pos: (buildW * 0.20, topY + roofH * 0.52, offsetZ - 0.018),
               color: UIColor(red: 0.54, green: 0.30, blue: 0.22, alpha: 1), roughness: 0.90)

        // Garden trees — placed in front garden (negative Z = street side)
        let trunkMat = makeMat(UIColor(red: 0.38, green: 0.24, blue: 0.14, alpha: 1), rough: 0.95)
        let foliageMat = makeMat(UIColor(red: 0.22, green: 0.52, blue: 0.22, alpha: 1), rough: 0.85)
        let frontEdge = offsetZ - buildD / 2  // building's street-facing edge (negative Z side)
        let treePositions: [(Float, Float)] = [
            (-buildW * 0.35, frontEdge - 0.08),
            ( buildW * 0.35, frontEdge - 0.08),
            ( buildW / 2 + 0.07, offsetZ - buildD * 0.20)
        ]
        for (tx, tz) in treePositions {
            let trunkH: Float = 0.055
            let trunkGeo = SCNCylinder(radius: 0.006, height: CGFloat(trunkH))
            trunkGeo.materials = [trunkMat]
            let trunkNode = SCNNode(geometry: trunkGeo)
            trunkNode.position = SCNVector3(tx, trunkH / 2, tz)
            parent.addChildNode(trunkNode)
            let foliageR: Float = 0.042
            let foliageGeo = SCNSphere(radius: CGFloat(foliageR))
            foliageGeo.materials = [foliageMat]
            let foliageNode = SCNNode(geometry: foliageGeo)
            foliageNode.position = SCNVector3(tx, trunkH + foliageR * 0.75, tz)
            parent.addChildNode(foliageNode)
        }
    }

    private func addVillaWindows(to node: SCNNode, width: Float, height: Float,
                                  depth: Float, isGround: Bool) {
        let mat = windowMaterial()
        let wW = height * (isGround ? 0.46 : 0.40)
        let wH = height * (isGround ? 0.54 : 0.50)
        let spacing = width * 0.30
        for xOff: Float in [-spacing, spacing] {
            for (sign, zOff): (Float, Float) in [(1, depth / 2 + 0.001), (-1, -(depth / 2 + 0.001))] {
                _ = sign
                let geo = SCNBox(width: CGFloat(wW), height: CGFloat(wH), length: 0.001, chamferRadius: 0)
                geo.materials = [mat]
                let n = SCNNode(geometry: geo)
                n.position = SCNVector3(xOff, height * 0.05, zOff)
                node.addChildNode(n)
            }
        }
        // Side windows
        for sign: Float in [-1, 1] {
            let geo = SCNBox(width: CGFloat(wW * 0.82), height: CGFloat(wH), length: 0.001, chamferRadius: 0)
            geo.materials = [mat]
            let n = SCNNode(geometry: geo)
            n.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
            n.position = SCNVector3(sign * (width / 2 + 0.001), height * 0.05, 0)
            node.addChildNode(n)
        }
    }

    // MARK: - Sanayi

    private func buildSanayi(on parent: SCNNode, buildW: Float, buildD: Float,
                              katSayisi: Int, scale: Float, offsetZ: Float) {
        let renderedFloors = min(katSayisi, 2)
        let floorH = katYuksekligi * scale * 1.30  // industrial height

        let bodyH = Float(renderedFloors) * floorH
        let bodyNode = addBox(to: parent, size: (buildW, bodyH, buildD),
                              pos: (0, bodyH / 2, offsetZ),
                              color: UIColor(red: 0.58, green: 0.60, blue: 0.62, alpha: 1), roughness: 0.86)
        bodyNode.name = "emsal_floor_0"

        // Clerestory windows near top
        let winH = bodyH * 0.09
        let winW = buildW * 0.11
        let yLocal = bodyH * 0.36
        let wCount = max(2, Int(buildW / (winW * 2.0)))
        let wSpacing = buildW / Float(wCount + 1)
        let winMat = windowMaterial()
        for i in 1...wCount {
            let xPos = -buildW / 2 + wSpacing * Float(i)
            for sign: Float in [1, -1] {
                let geo = SCNBox(width: CGFloat(winW), height: CGFloat(winH), length: 0.001, chamferRadius: 0)
                geo.materials = [winMat]
                let n = SCNNode(geometry: geo)
                n.position = SCNVector3(xPos, yLocal, sign * (buildD / 2 + 0.001))
                bodyNode.addChildNode(n)
            }
        }

        // Metal cladding bands
        let bandH = bodyH * 0.022
        let bandMat = makeMat(UIColor(red: 0.42, green: 0.44, blue: 0.47, alpha: 1), rough: 0.80)
        for i in 1..<renderedFloors {
            let yPos = Float(i) * floorH
            let bandGeo = SCNBox(width: CGFloat(buildW + 0.006), height: CGFloat(bandH),
                                 length: CGFloat(buildD + 0.006), chamferRadius: 0)
            bandGeo.materials = [bandMat]
            let bn = SCNNode(geometry: bandGeo)
            bn.position = SCNVector3(0, yPos, offsetZ)
            parent.addChildNode(bn)
        }

        // Large loading door at front
        let doorW = buildW * 0.40
        let doorH = floorH * 0.70
        let frontZ = buildD / 2 + offsetZ
        addBox(to: parent, size: (doorW, doorH, 0.002),
               pos: (0, doorH / 2, frontZ + 0.001),
               color: UIColor(red: 0.28, green: 0.30, blue: 0.33, alpha: 1), roughness: 0.72)
        // Door frame
        let ft: Float = 0.009
        let frameMat = makeMat(UIColor(red: 0.22, green: 0.24, blue: 0.26, alpha: 1), rough: 0.80)
        let topGeo = SCNBox(width: CGFloat(doorW + ft * 2), height: CGFloat(ft), length: 0.003, chamferRadius: 0)
        topGeo.materials = [frameMat]
        let topNode = SCNNode(geometry: topGeo)
        topNode.position = SCNVector3(0, doorH + ft / 2, frontZ + 0.002)
        parent.addChildNode(topNode)

        // Gabled roof (wide pyramid, low profile)
        let roofH = buildD * 0.18
        let roofGeo = SCNPyramid(width: CGFloat(buildW * 1.02),
                                  height: CGFloat(roofH),
                                  length: CGFloat(buildD * 1.02))
        roofGeo.materials = [makeMat(UIColor(red: 0.40, green: 0.42, blue: 0.45, alpha: 1), rough: 0.92)]
        let roofNode = SCNNode(geometry: roofGeo)
        roofNode.name = "emsal_roof"
        roofNode.position = SCNVector3(0, bodyH, offsetZ)
        parent.addChildNode(roofNode)
    }

    // MARK: - Ticaret

    private func buildTicaret(on parent: SCNNode, buildW: Float, buildD: Float,
                               katSayisi: Int, scale: Float, offsetZ: Float) {
        let floorH = katYuksekligi * scale
        let totalH = Float(katSayisi) * floorH

        // Concrete/steel frame body
        addBox(to: parent, size: (buildW, totalH, buildD),
               pos: (0, totalH / 2, offsetZ),
               color: UIColor(red: 0.76, green: 0.78, blue: 0.80, alpha: 1), roughness: 0.55)

        // Full-height curtain glass — front and back
        let glassMat = SCNMaterial()
        glassMat.diffuse.contents = UIColor(red: 0.40, green: 0.65, blue: 0.90, alpha: 1.0)
        glassMat.specular.contents = UIColor.white
        glassMat.transparency = 0.42
        glassMat.isDoubleSided = true
        let glassH = totalH * 0.88
        for sign: Float in [1, -1] {
            let geo = SCNBox(width: CGFloat(buildW * 0.92), height: CGFloat(glassH),
                             length: 0.001, chamferRadius: 0)
            geo.materials = [glassMat]
            let n = SCNNode(geometry: geo)
            n.position = SCNVector3(0, totalH * 0.06 + glassH / 2, offsetZ + sign * (buildD / 2 + 0.0005))
            parent.addChildNode(n)
        }
        // Side glass strips
        let sideGlassMat = SCNMaterial()
        sideGlassMat.diffuse.contents = UIColor(red: 0.35, green: 0.58, blue: 0.85, alpha: 0.48)
        sideGlassMat.transparency = 0.54
        sideGlassMat.isDoubleSided = true
        let sideH = totalH * 0.70
        for sign: Float in [-1, 1] {
            let geo = SCNBox(width: 0.001, height: CGFloat(sideH),
                             length: CGFloat(buildD * 0.84), chamferRadius: 0)
            geo.materials = [sideGlassMat]
            let n = SCNNode(geometry: geo)
            n.position = SCNVector3(sign * (buildW / 2 + 0.0005), totalH * 0.12 + sideH / 2, offsetZ)
            parent.addChildNode(n)
        }

        // Horizontal floor bands
        let bandMat = makeMat(UIColor(red: 0.58, green: 0.60, blue: 0.64, alpha: 1), rough: 0.60)
        for kat in 1..<katSayisi {
            let bandH = floorH * 0.07
            let bandGeo = SCNBox(width: CGFloat(buildW + 0.010), height: CGFloat(bandH),
                                 length: CGFloat(buildD + 0.010), chamferRadius: 0)
            bandGeo.materials = [bandMat]
            let bn = SCNNode(geometry: bandGeo)
            bn.position = SCNVector3(0, Float(kat) * floorH, offsetZ)
            parent.addChildNode(bn)
        }

        // Teras döşemesi
        let slabH = floorH * 0.09
        addBox(to: parent, size: (buildW + 0.012, slabH, buildD + 0.012),
               pos: (0, totalH + slabH / 2, offsetZ),
               color: UIColor(red: 0.64, green: 0.66, blue: 0.70, alpha: 1), roughness: 0.82)
        let topY = totalH + slabH

        // Çıkma kornişi (modernist overhanging cornice)
        let cornH = floorH * 0.055
        let ovhg: Float = 0.020
        addBox(to: parent, size: (buildW + ovhg * 2, cornH, buildD + ovhg * 2),
               pos: (0, topY + cornH / 2, offsetZ),
               color: UIColor(red: 0.48, green: 0.50, blue: 0.55, alpha: 1), roughness: 0.50)
        let crowTopY = topY + cornH

        // Rooftop teknik hacim (çelik kutu)
        let phW = buildW * 0.45, phH = floorH * 0.62, phD = buildD * 0.42
        addBox(to: parent, size: (phW, phH, phD),
               pos: (-buildW * 0.15, crowTopY + phH / 2, offsetZ),
               color: UIColor(red: 0.54, green: 0.57, blue: 0.62, alpha: 1), roughness: 0.70)

        // HVAC ünitesi (küçük gri kutu)
        let hvW = phW * 0.32, hvH = phH * 0.42
        addBox(to: parent, size: (hvW, hvH, phD * 0.55),
               pos: (buildW * 0.26, crowTopY + hvH / 2, offsetZ + buildD * 0.08),
               color: UIColor(red: 0.40, green: 0.42, blue: 0.45, alpha: 1), roughness: 0.85)

        // Cam korkuluk — ön ve arka
        let railH = floorH * 0.11
        let railMat = makeMat(UIColor(red: 0.55, green: 0.72, blue: 0.90, alpha: 1), rough: 0.06)
        for sign: Float in [-1, 1] {
            let rGeo = SCNBox(width: CGFloat(buildW * 0.92), height: CGFloat(railH), length: 0.003, chamferRadius: 0)
            rGeo.materials = [railMat]
            let rn = SCNNode(geometry: rGeo)
            rn.position = SCNVector3(0, crowTopY + railH / 2, offsetZ + sign * (buildD / 2 + 0.001))
            parent.addChildNode(rn)
        }
    }

    // MARK: - Karma

    private func buildKarma(on parent: SCNNode, buildW: Float, buildD: Float,
                             katSayisi: Int, scale: Float, offsetZ: Float) {
        let floorH = katYuksekligi * scale
        let totalH = Float(katSayisi) * floorH
        let commercialFloors = min(2, katSayisi)
        let residentialFloors = max(0, katSayisi - commercialFloors)

        let sokleH = floorH * 0.12
        addBox(to: parent, size: (buildW + 0.020, sokleH, buildD + 0.020),
               pos: (0, sokleH / 2, offsetZ),
               color: UIColor(red: 0.52, green: 0.52, blue: 0.54, alpha: 1), roughness: 0.88)

        for kat in 0..<commercialFloors {
            let y = sokleH + Float(kat) * floorH + floorH / 2
            let katNode = addBox(to: parent, size: (buildW, floorH, buildD),
                                 pos: (0, y, offsetZ),
                                 color: UIColor(red: 0.68, green: 0.73, blue: 0.82, alpha: 1), roughness: 0.55)
            addCurtainGlass(to: katNode, width: buildW, height: floorH, depth: buildD)
        }

        for kat in 0..<residentialFloors {
            let idx = commercialFloors + kat
            let y = sokleH + Float(idx) * floorH + floorH / 2
            let katNode = addBox(to: parent, size: (buildW, floorH, buildD),
                                 pos: (0, y, offsetZ),
                                 color: UIColor(red: 0.92, green: 0.88, blue: 0.80, alpha: 1), roughness: 0.65)
            addWindowsFrontBack(to: katNode, width: buildW, height: floorH, depth: buildD)
            addWindowsSides(to: katNode, width: buildW, height: floorH, depth: buildD)
            addBalcony(to: katNode, width: buildW, height: floorH, depth: buildD)
        }

        if commercialFloors > 0 && residentialFloors > 0 {
            let bandY = sokleH + Float(commercialFloors) * floorH
            addBox(to: parent, size: (buildW + 0.018, floorH * 0.055, buildD + 0.018),
                   pos: (0, bandY, offsetZ),
                   color: UIColor(red: 0.52, green: 0.54, blue: 0.58, alpha: 1), roughness: 0.75)
        }

        // Teras döşemesi
        let slabH = floorH * 0.09
        addBox(to: parent, size: (buildW + 0.012, slabH, buildD + 0.012),
               pos: (0, totalH + sokleH + slabH / 2, offsetZ),
               color: UIColor(red: 0.66, green: 0.68, blue: 0.70, alpha: 1), roughness: 0.80)
        let kTopY = totalH + sokleH + slabH

        // Setback penthouse katı (rezidans bölümü üstü)
        let phW = buildW * 0.56, phH = floorH * 0.75, phD = buildD * 0.60
        addBox(to: parent, size: (phW, phH, phD),
               pos: (buildW * 0.14, kTopY + phH / 2, offsetZ),
               color: UIColor(red: 0.91, green: 0.87, blue: 0.79, alpha: 1), roughness: 0.60)
        // Penthouse üstü alçak kırma çatı
        let phRoofH = phH * 0.28
        let phRoofGeo = SCNPyramid(width: CGFloat(phW * 1.03), height: CGFloat(phRoofH), length: CGFloat(phD * 1.03))
        phRoofGeo.materials = [makeMat(UIColor(red: 0.50, green: 0.48, blue: 0.46, alpha: 1), rough: 0.80)]
        let phRoofNode = SCNNode(geometry: phRoofGeo)
        phRoofNode.position = SCNVector3(buildW * 0.14, kTopY + phH, offsetZ)
        parent.addChildNode(phRoofNode)

        // Teras cam korkuluk (ön cephe)
        let kRailH = floorH * 0.10
        let kRailMat = makeMat(UIColor(red: 0.55, green: 0.72, blue: 0.90, alpha: 1), rough: 0.06)
        let kRfGeo = SCNBox(width: CGFloat(buildW * 0.90), height: CGFloat(kRailH), length: 0.003, chamferRadius: 0)
        kRfGeo.materials = [kRailMat]
        let kRfn = SCNNode(geometry: kRfGeo)
        kRfn.position = SCNVector3(0, kTopY + kRailH / 2, offsetZ - buildD / 2 - 0.001)
        parent.addChildNode(kRfn)
    }

    // MARK: - Turizm

    private func buildTurizm(on parent: SCNNode, buildW: Float, buildD: Float,
                              katSayisi: Int, scale: Float, offsetZ: Float) {
        let floorH = katYuksekligi * scale
        let totalH = Float(katSayisi) * floorH

        let sokleH = floorH * 0.14
        addBox(to: parent, size: (buildW + 0.022, sokleH, buildD + 0.022),
               pos: (0, sokleH / 2, offsetZ),
               color: UIColor(red: 0.82, green: 0.80, blue: 0.78, alpha: 1), roughness: 0.80)

        let slabMat = makeMat(UIColor(red: 0.60, green: 0.60, blue: 0.62, alpha: 1), rough: 0.85)
        for kat in 0..<katSayisi {
            let y = sokleH + Float(kat) * floorH + floorH / 2
            let katNode = addBox(to: parent, size: (buildW, floorH, buildD),
                                 pos: (0, y, offsetZ),
                                 color: UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1), roughness: 0.60)
            katNode.name = "emsal_floor_\(kat)"
            addWindowsFrontBack(to: katNode, width: buildW, height: floorH, depth: buildD)
            addWindowsSides(to: katNode, width: buildW, height: floorH, depth: buildD)
            addBalcony(to: katNode, width: buildW, height: floorH, depth: buildD)

            if kat < katSayisi - 1 {
                let slabThick = floorH * 0.08
                let slabGeo = SCNBox(width: CGFloat(buildW + 0.018), height: CGFloat(slabThick),
                                     length: CGFloat(buildD + 0.018), chamferRadius: 0)
                slabGeo.materials = [slabMat]
                let slab = SCNNode(geometry: slabGeo)
                slab.position = SCNVector3(0, sokleH + Float(kat + 1) * floorH, offsetZ)
                parent.addChildNode(slab)
            }
        }
        // Teras döşemesi
        let slabH = floorH * 0.10
        addBox(to: parent, size: (buildW + 0.012, slabH, buildD + 0.012),
               pos: (0, totalH + sokleH + slabH / 2, offsetZ),
               color: UIColor(red: 0.75, green: 0.75, blue: 0.77, alpha: 1), roughness: 0.80)
        let tTopY = totalH + sokleH + slabH

        // Yeşil çatı dolgusu (otel terası)
        let greenH = slabH * 0.30
        addBox(to: parent, size: (buildW * 0.88, greenH, buildD * 0.88),
               pos: (0, tTopY + greenH / 2, offsetZ),
               color: UIColor(red: 0.42, green: 0.62, blue: 0.32, alpha: 1), roughness: 0.95)

        // Merkezi asansör/tesisat kulesi
        let towW = buildW * 0.22, towH = floorH * 0.78, towD = buildD * 0.18
        addBox(to: parent, size: (towW, towH, towD),
               pos: (0, tTopY + towH / 2, offsetZ),
               color: UIColor(red: 0.80, green: 0.78, blue: 0.76, alpha: 1), roughness: 0.70)
        let capH = towH * 0.12
        addBox(to: parent, size: (towW + 0.010, capH, towD + 0.010),
               pos: (0, tTopY + towH + capH / 2, offsetZ),
               color: UIColor(red: 0.58, green: 0.56, blue: 0.54, alpha: 1), roughness: 0.65)

        // Pergola direkleri
        let postH = floorH * 0.42, postW: Float = 0.008
        let postMat = makeMat(UIColor(red: 0.82, green: 0.78, blue: 0.72, alpha: 1), rough: 0.55)
        for px: Float in [-buildW * 0.35, -buildW * 0.10, buildW * 0.10, buildW * 0.35] {
            for pz: Float in [-buildD * 0.30, buildD * 0.30] {
                let pGeo = SCNBox(width: CGFloat(postW), height: CGFloat(postH), length: CGFloat(postW), chamferRadius: 0)
                pGeo.materials = [postMat]
                let pn = SCNNode(geometry: pGeo)
                pn.position = SCNVector3(px, tTopY + postH / 2, offsetZ + pz)
                parent.addChildNode(pn)
            }
        }

        // Cam parapet (ön + arka)
        let tRailH = floorH * 0.12
        let tRailMat = makeMat(UIColor(red: 0.55, green: 0.72, blue: 0.90, alpha: 1), rough: 0.06)
        for sign: Float in [-1, 1] {
            let rGeo = SCNBox(width: CGFloat(buildW * 0.94), height: CGFloat(tRailH), length: 0.003, chamferRadius: 0)
            rGeo.materials = [tRailMat]
            let rn = SCNNode(geometry: rGeo)
            rn.position = SCNVector3(0, tTopY + tRailH / 2, offsetZ + sign * (buildD / 2 + 0.001))
            parent.addChildNode(rn)
        }
    }

    // MARK: - Standard (konut, saglik, egitim, diger)

    private func buildStandard(on parent: SCNNode, buildW: Float, buildD: Float,
                                katSayisi: Int, scale: Float, offsetZ: Float, tur: KullanimTuru) {
        let floorH = katYuksekligi * scale
        let totalH = Float(katSayisi) * floorH

        let sokleH = floorH * 0.14
        addBox(to: parent, size: (buildW + 0.024, sokleH, buildD + 0.024),
               pos: (0, sokleH / 2, offsetZ),
               color: UIColor(red: 0.50, green: 0.50, blue: 0.52, alpha: 1), roughness: 0.92)

        let slabMat = makeMat(UIColor(red: 0.58, green: 0.58, blue: 0.60, alpha: 1), rough: 0.88)
        for kat in 0..<katSayisi {
            let y = sokleH + Float(kat) * floorH + floorH / 2
            let katNode = addBox(to: parent, size: (buildW, floorH, buildD),
                                 pos: (0, y, offsetZ),
                                 color: standardColor(tur: tur), roughness: 0.62)
            katNode.name = "emsal_floor_\(kat)"
            addWindowsFrontBack(to: katNode, width: buildW, height: floorH, depth: buildD)
            addWindowsSides(to: katNode, width: buildW, height: floorH, depth: buildD)
            if kat > 0 && tur == .konut {
                addBalcony(to: katNode, width: buildW, height: floorH, depth: buildD)
            }
            if kat < katSayisi - 1 {
                let slabThick = floorH * 0.09
                let slabGeo = SCNBox(width: CGFloat(buildW + 0.020), height: CGFloat(slabThick),
                                     length: CGFloat(buildD + 0.020), chamferRadius: 0)
                slabGeo.materials = [slabMat]
                let slab = SCNNode(geometry: slabGeo)
                slab.position = SCNVector3(0, sokleH + Float(kat + 1) * floorH, offsetZ)
                parent.addChildNode(slab)
            }
        }

        // Corner pilasters for residential/institutional
        let pilH = totalH + sokleH
        let pilW: Float = 0.024
        let pilMat = makeMat(UIColor(red: 0.76, green: 0.74, blue: 0.72, alpha: 1), rough: 0.58)
        for (sx, sz): (Float, Float) in [(-1, -1), (-1, 1), (1, -1), (1, 1)] {
            let pilGeo = SCNBox(width: CGFloat(pilW), height: CGFloat(pilH),
                                length: CGFloat(pilW), chamferRadius: 0.002)
            pilGeo.materials = [pilMat]
            let pn = SCNNode(geometry: pilGeo)
            pn.name = "emsal_pilaster"
            pn.position = SCNVector3(sx * (buildW / 2 + pilW * 0.5), pilH / 2,
                                     offsetZ + sz * (buildD / 2 + pilW * 0.5))
            parent.addChildNode(pn)
        }

        if tur == .konut {
            // Kırma çatı — tek katlı bile olsa konut her zaman alır
            let rh = katYuksekligi * scale * (katSayisi >= 3 ? 0.36 : 0.48)
            let roofGeo = SCNPyramid(width: CGFloat(buildW * 1.04), height: CGFloat(rh),
                                      length: CGFloat(buildD * 1.04))
            roofGeo.materials = [makeMat(UIColor(red: 0.55, green: 0.22, blue: 0.10, alpha: 1), rough: 0.75)]
            let roofNode = SCNNode(geometry: roofGeo)
            roofNode.name = "emsal_roof"
            roofNode.position = SCNVector3(0, totalH + sokleH, offsetZ)
            parent.addChildNode(roofNode)
        } else {
            // Düz çatı + çıkma kornişi (saglik, egitim, diger)
            let slabH = floorH * 0.09
            addBox(to: parent, size: (buildW + 0.012, slabH, buildD + 0.012),
                   pos: (0, totalH + sokleH + slabH / 2, offsetZ),
                   color: UIColor(red: 0.70, green: 0.70, blue: 0.72, alpha: 1), roughness: 0.85)
            let sTopY = totalH + sokleH + slabH
            let cornH = floorH * 0.042
            addBox(to: parent, size: (buildW + 0.030, cornH, buildD + 0.030),
                   pos: (0, sTopY + cornH / 2, offsetZ),
                   color: UIColor(red: 0.52, green: 0.54, blue: 0.58, alpha: 1), roughness: 0.58)
            addParapet(to: parent, width: buildW, depth: buildD,
                       y: sTopY + cornH, offsetZ: offsetZ,
                       height: floorH * 0.10, thickness: 0.007)
        }
    }

    private func standardColor(tur: KullanimTuru) -> UIColor {
        switch tur {
        case .konut:  return UIColor(red: 0.92, green: 0.87, blue: 0.78, alpha: 1)
        case .saglik: return UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1)
        case .egitim: return UIColor(red: 0.88, green: 0.80, blue: 0.65, alpha: 1)
        default:      return UIColor(red: 0.84, green: 0.84, blue: 0.86, alpha: 1)
        }
    }

    // MARK: - Architectural Context

    private func makeStreetAndSidewalk(scaledPW: Float, scaledPD: Float) -> SCNNode {
        let node = SCNNode()
        // Parcel: Z from -scaledPD/2 (front/street side) to +scaledPD/2 (back)
        let frontZ = -scaledPD / 2

        // Sidewalk
        let swD: Float = scaledPD * 0.13
        let swGeo = SCNBox(width: CGFloat(scaledPW * 1.9), height: 0.007, length: CGFloat(swD), chamferRadius: 0)
        swGeo.materials = [makeMat(UIColor(red: 0.82, green: 0.80, blue: 0.75, alpha: 1), rough: 0.88)]
        let sw = SCNNode(geometry: swGeo)
        sw.position = SCNVector3(0, 0.0035, frontZ - swD / 2)
        node.addChildNode(sw)

        // Curb
        let curbH: Float = 0.012
        let curbGeo = SCNBox(width: CGFloat(scaledPW * 1.9), height: CGFloat(curbH), length: 0.008, chamferRadius: 0)
        curbGeo.materials = [makeMat(UIColor(red: 0.60, green: 0.60, blue: 0.62, alpha: 1), rough: 0.75)]
        let curb = SCNNode(geometry: curbGeo)
        curb.position = SCNVector3(0, curbH / 2, frontZ)
        node.addChildNode(curb)

        // Road asphalt
        let roadD: Float = scaledPD * 0.44
        let roadGeo = SCNBox(width: CGFloat(scaledPW * 1.9), height: 0.004, length: CGFloat(roadD), chamferRadius: 0)
        roadGeo.materials = [makeMat(UIColor(red: 0.30, green: 0.30, blue: 0.33, alpha: 1), rough: 0.96)]
        let road = SCNNode(geometry: roadGeo)
        road.position = SCNVector3(0, 0.001, frontZ - swD - roadD / 2)
        node.addChildNode(road)

        // Yellow center-line dashes
        let dashZ = frontZ - swD - roadD / 2
        let dashW: Float = scaledPW * 0.07
        let dashStep: Float = scaledPW * 0.30
        for i in -2...2 {
            let dashGeo = SCNBox(width: CGFloat(dashW), height: 0.001, length: 0.007, chamferRadius: 0)
            dashGeo.materials = [makeMat(UIColor(red: 0.96, green: 0.88, blue: 0.16, alpha: 1), rough: 0.7)]
            let dash = SCNNode(geometry: dashGeo)
            dash.position = SCNVector3(Float(i) * dashStep, 0.003, dashZ)
            node.addChildNode(dash)
        }

        // Parked cars (three simple boxes with chamfer)
        let carColors: [UIColor] = [
            UIColor(red: 0.70, green: 0.18, blue: 0.18, alpha: 1),
            UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1),
            UIColor(red: 0.22, green: 0.38, blue: 0.65, alpha: 1)
        ]
        let carL = scaledPW * 0.12
        let carWd = scaledPW * 0.055
        let carH = scaledPD * 0.038
        let carZ = frontZ - swD - carWd / 2 - 0.012
        for i in 0..<3 {
            let carGeo = SCNBox(width: CGFloat(carL), height: CGFloat(carH), length: CGFloat(carWd),
                                chamferRadius: CGFloat(carH * 0.28))
            carGeo.materials = [makeMat(carColors[i], rough: 0.22)]
            let car = SCNNode(geometry: carGeo)
            car.position = SCNVector3((Float(i) - 1.0) * carL * 1.35, carH / 2 + 0.001, carZ)
            node.addChildNode(car)
            // Windshield tint
            let wsGeo = SCNBox(width: CGFloat(carL * 0.42), height: CGFloat(carH * 0.38),
                               length: 0.002, chamferRadius: 0)
            wsGeo.materials = [makeMat(UIColor(red: 0.55, green: 0.72, blue: 0.88, alpha: 0.70), rough: 0.05)]
            let ws = SCNNode(geometry: wsGeo)
            ws.position = SCNVector3((Float(i) - 1.0) * carL * 1.35, carH * 0.62, carZ - carWd * 0.28)
            node.addChildNode(ws)
        }
        return node
    }

    private func makeContextBuildings(scaledPW: Float, scaledPD: Float) -> SCNNode {
        let node = SCNNode()
        let bldgMat = makeMat(UIColor(red: 0.80, green: 0.78, blue: 0.74, alpha: 1), rough: 0.75)
        let roofMat = makeMat(UIColor(red: 0.62, green: 0.60, blue: 0.58, alpha: 1), rough: 0.88)
        let winMat  = makeMat(UIColor(red: 0.55, green: 0.72, blue: 0.90, alpha: 0.78), rough: 0.12)

        let sideHeights: [Float] = [scaledPD * 0.50, scaledPD * 0.38]
        for (idx, side) in [Float(-1), Float(1)].enumerated() {
            let bH = sideHeights[idx]
            let bW = scaledPW * 0.74
            let bD = scaledPD * 0.64
            let bX = side * (scaledPW / 2 + bW / 2 + 0.04)

            // Body
            let bGeo = SCNBox(width: CGFloat(bW), height: CGFloat(bH), length: CGFloat(bD), chamferRadius: 0.004)
            bGeo.materials = [bldgMat]
            let bNode = SCNNode(geometry: bGeo)
            bNode.position = SCNVector3(bX, bH / 2, 0)
            node.addChildNode(bNode)

            // Roof slab
            let rsGeo = SCNBox(width: CGFloat(bW + 0.012), height: CGFloat(bH * 0.048),
                               length: CGFloat(bD + 0.012), chamferRadius: 0)
            rsGeo.materials = [roofMat]
            let rs = SCNNode(geometry: rsGeo)
            rs.position = SCNVector3(bX, bH * 1.024, 0)
            node.addChildNode(rs)

            // Windows on front face (negative Z)
            let winW = bW * 0.14, winH = bH * 0.095
            for r in 0..<3 {
                for c in 0..<3 {
                    let wx = bX + (Float(c) - 1.0) * bW * 0.28
                    let wy = bH * 0.14 + Float(r) * bH * 0.72 / 3.0
                    let winGeo = SCNBox(width: CGFloat(winW), height: CGFloat(winH), length: 0.002, chamferRadius: 0)
                    winGeo.materials = [winMat]
                    let win = SCNNode(geometry: winGeo)
                    win.position = SCNVector3(wx, wy, -bD / 2 - 0.001)
                    node.addChildNode(win)
                }
            }
        }

        // Back context building
        let bbH = scaledPD * 0.28
        let bbW = scaledPW * 1.15
        let bbD = scaledPD * 0.36
        let bbGeo = SCNBox(width: CGFloat(bbW), height: CGFloat(bbH), length: CGFloat(bbD), chamferRadius: 0.004)
        bbGeo.materials = [bldgMat]
        let bb = SCNNode(geometry: bbGeo)
        bb.position = SCNVector3(0, bbH / 2, scaledPD / 2 + bbD / 2 + 0.05)
        node.addChildNode(bb)

        return node
    }

    private func makeSiteVegetation(scaledPW: Float, scaledPD: Float, scale: Float,
                                     onCekme: Double, arkaCekme: Double, yanCekme: Double) -> SCNNode {
        let node = SCNNode()
        let trunkMat = makeMat(UIColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1), rough: 0.95)
        let foliagePalette: [UIColor] = [
            UIColor(red: 0.20, green: 0.50, blue: 0.20, alpha: 1),
            UIColor(red: 0.24, green: 0.56, blue: 0.22, alpha: 1),
            UIColor(red: 0.18, green: 0.44, blue: 0.24, alpha: 1)
        ]

        func addTree(x: Float, z: Float, colorIdx: Int) {
            let tH: Float = 0.075
            let tGeo = SCNCylinder(radius: 0.006, height: CGFloat(tH))
            tGeo.materials = [trunkMat]
            let tNode = SCNNode(geometry: tGeo)
            tNode.position = SCNVector3(x, tH / 2, z)
            node.addChildNode(tNode)
            let fR: Float = 0.043
            let fGeo = SCNSphere(radius: CGFloat(fR))
            fGeo.materials = [makeMat(foliagePalette[colorIdx % 3], rough: 0.88)]
            let fNode = SCNNode(geometry: fGeo)
            fNode.position = SCNVector3(x, tH + fR * 0.72, z)
            node.addChildNode(fNode)
        }

        // Front setback row (along negative Z, inside parcel)
        let frontZ = -scaledPD / 2 + Float(onCekme) * scale * 0.45
        addTree(x: -scaledPW * 0.25, z: frontZ, colorIdx: 0)
        addTree(x: 0,                z: frontZ, colorIdx: 1)
        addTree(x:  scaledPW * 0.25, z: frontZ, colorIdx: 2)

        // Side setback trees
        let yanL = -scaledPW / 2 + Float(yanCekme) * scale * 0.45
        let yanR =  scaledPW / 2 - Float(yanCekme) * scale * 0.45
        addTree(x: yanL, z: -scaledPD * 0.18, colorIdx: 0)
        addTree(x: yanL, z:  scaledPD * 0.18, colorIdx: 2)
        addTree(x: yanR, z: -scaledPD * 0.18, colorIdx: 1)
        addTree(x: yanR, z:  scaledPD * 0.18, colorIdx: 0)

        // Back setback tree
        let backZ = scaledPD / 2 - Float(arkaCekme) * scale * 0.45
        addTree(x: 0, z: backZ, colorIdx: 1)

        return node
    }

    // MARK: - Visibility Toggle

    func updateNodeVisibility() {
        scene.rootNode.enumerateChildNodes { node, _ in
            if node.name == "emsal_parcel"  { node.isHidden = !self.showParcelBoundary }
            if node.name == "emsal_setback" { node.isHidden = !self.showSetbackLines }
            if node.name == "emsal_balcony" { node.isHidden = !self.showBalconies }
        }
    }

    // MARK: - Compass Markers

    private func makeCompassMarkers(scaledPW: Float, scaledPD: Float) -> SCNNode {
        let group = SCNNode()
        let yBase: Float = 0.003
        let pad = max(scaledPW, scaledPD) * 0.10
        let hx = scaledPW / 2 + pad
        let hz = scaledPD / 2 + pad
        let fontSize = CGFloat(min(scaledPW, scaledPD)) * 0.11

        // Sahne sözleşmesi: +Z = Kuzey (arka), -Z = Güney (yol/ön)
        let dirs: [(label: String, x: Float, z: Float, color: UIColor)] = [
            ("K", 0,   hz,  UIColor(red: 0.82, green: 0.12, blue: 0.12, alpha: 1)),
            ("G", 0,  -hz,  UIColor(red: 0.20, green: 0.38, blue: 0.82, alpha: 1)),
            ("D",  hx, 0,   UIColor(red: 0.18, green: 0.58, blue: 0.22, alpha: 1)),
            ("B", -hx, 0,   UIColor(red: 0.62, green: 0.42, blue: 0.12, alpha: 1))
        ]

        for d in dirs {
            let text = SCNText(string: d.label, extrusionDepth: 0.004)
            text.font = UIFont.boldSystemFont(ofSize: fontSize)
            text.flatness = 0.004
            text.materials = [makeMat(d.color, rough: 0.85)]
            let node = SCNNode(geometry: text)
            let (bMin, bMax) = node.boundingBox
            node.pivot = SCNMatrix4MakeTranslation(
                (bMin.x + bMax.x) / 2,
                (bMin.y + bMax.y) / 2,
                0
            )
            node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            node.position = SCNVector3(d.x, yBase + 0.012, d.z)
            group.addChildNode(node)
        }

        // Kuzey ok işareti (kırmızı çubuk)
        let arrowLen: Float = pad * 0.60
        let arrowGeo = SCNBox(width: 0.011, height: 0.007, length: CGFloat(arrowLen), chamferRadius: 0.001)
        arrowGeo.materials = [makeMat(UIColor(red: 0.82, green: 0.12, blue: 0.12, alpha: 1), rough: 0.70)]
        let arrowNode = SCNNode(geometry: arrowGeo)
        arrowNode.position = SCNVector3(0, yBase + 0.003, scaledPD / 2 + arrowLen / 2 + 0.005)
        group.addChildNode(arrowNode)

        return group
    }

    // MARK: - Context & Parcel Ground

    private func makeContextGround(scaledPW: Float, scaledPD: Float) -> SCNNode {
        let size = max(scaledPW, scaledPD) * 5
        let plane = SCNPlane(width: CGFloat(size), height: CGFloat(size))
        // SolidWorks zemin: açık gri-bej, hafif mat yüzey
        plane.materials = [makeMat(UIColor(red: 0.82, green: 0.82, blue: 0.82, alpha: 1), rough: 0.78)]
        let node = SCNNode(geometry: plane)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.position = SCNVector3(0, -0.002, 0)
        return node
    }

    private func makeParcelGround(ring: [(Float, Float)], scaledW: Float,
                                   scaledPD: Float, scale: Float) -> SCNNode {
        let path: UIBezierPath
        if ring.count >= 3 {
            path = UIBezierPath()
            for (i, pt) in ring.enumerated() {
                let p = CGPoint(x: CGFloat(pt.0) * CGFloat(scale), y: CGFloat(pt.1) * CGFloat(scale))
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.close()
        } else {
            path = UIBezierPath(rect: CGRect(x: -CGFloat(scaledW / 2), y: -CGFloat(scaledPD / 2),
                                             width: CGFloat(scaledW), height: CGFloat(scaledPD)))
        }
        let shape = SCNShape(path: path, extrusionDepth: 0.004)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.35, green: 0.62, blue: 0.35, alpha: 1)
        mat.isDoubleSided = true
        shape.materials = [mat]
        let node = SCNNode(geometry: shape)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.position = SCNVector3(0, 0.002, 0)
        return node
    }

    // MARK: - Setback Lines

    private func makeSetbackLines(scaledPW: Float, scaledPD: Float, scale: Float,
                                   onCekme: Double, arkaCekme: Double, yanCekme: Double) -> SCNNode {
        let node = SCNNode()
        let inW = scaledPW - Float(yanCekme * 2) * scale
        let inD = scaledPD - Float(onCekme + arkaCekme) * scale
        guard inW > 0.01, inD > 0.01 else { return node }
        let offsetZ = Float(onCekme - arkaCekme) / 2.0 * scale
        let y: Float = 0.006
        let thick: Float = 0.006
        node.addChildNode(lineBox(w: inW, h: thick, d: thick,
                                  at: SCNVector3(0, y,  inD / 2 + offsetZ), color: .systemOrange))
        node.addChildNode(lineBox(w: inW, h: thick, d: thick,
                                  at: SCNVector3(0, y, -inD / 2 + offsetZ), color: .systemOrange))
        node.addChildNode(lineBox(w: thick, h: thick, d: inD,
                                  at: SCNVector3(-inW / 2, y, offsetZ), color: .systemOrange))
        node.addChildNode(lineBox(w: thick, h: thick, d: inD,
                                  at: SCNVector3( inW / 2, y, offsetZ), color: .systemOrange))
        return node
    }

    private func lineBox(w: Float, h: Float, d: Float, at pos: SCNVector3, color: UIColor) -> SCNNode {
        let box = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: 0)
        box.materials = [makeMat(color, rough: 0.6)]
        let node = SCNNode(geometry: box)
        node.position = pos
        return node
    }

    // MARK: - Parapet

    private func addParapet(to node: SCNNode, width: Float, depth: Float,
                             y: Float, offsetZ: Float, height: Float, thickness: Float) {
        let mat = makeMat(UIColor(red: 0.78, green: 0.78, blue: 0.80, alpha: 1), rough: 0.70)
        let walls: [(Float, Float, Float, Float)] = [
            (width,     thickness, 0.0,        depth / 2 + offsetZ),
            (width,     thickness, 0.0,       -depth / 2 + offsetZ),
            (thickness, depth,    -width / 2,  offsetZ),
            (thickness, depth,     width / 2,  offsetZ),
        ]
        for (w, d, x, z) in walls {
            let box = SCNBox(width: CGFloat(w), height: CGFloat(height), length: CGFloat(d), chamferRadius: 0)
            box.materials = [mat]
            let n = SCNNode(geometry: box)
            n.position = SCNVector3(x, y + height / 2, z)
            node.addChildNode(n)
        }
    }

    // MARK: - Windows

    private func addWindowsFrontBack(to floorNode: SCNNode, width: Float, height: Float, depth: Float) {
        let mat = windowMaterial()
        let wW = height * 0.32
        let wH = height * 0.44
        let count = max(1, Int(width / (wW * 2.4)))
        let spacing = width / Float(count + 1)
        for i in 1...count {
            let xPos = -width / 2 + spacing * Float(i)
            for sign: Float in [1, -1] {
                let geo = SCNBox(width: CGFloat(wW), height: CGFloat(wH), length: 0.001, chamferRadius: 0)
                geo.materials = [mat]
                let n = SCNNode(geometry: geo)
                n.position = SCNVector3(xPos, height * 0.08, sign * (depth / 2 + 0.0005))
                floorNode.addChildNode(n)
            }
        }
    }

    private func addWindowsSides(to floorNode: SCNNode, width: Float, height: Float, depth: Float) {
        let mat = windowMaterial()
        let wW = height * 0.32
        let wH = height * 0.44
        let count = max(1, Int(depth / (wW * 2.4)))
        let spacing = depth / Float(count + 1)
        for i in 1...count {
            let zPos = -depth / 2 + spacing * Float(i)
            for sign: Float in [1, -1] {
                let geo = SCNBox(width: CGFloat(wW), height: CGFloat(wH), length: 0.001, chamferRadius: 0)
                geo.materials = [mat]
                let n = SCNNode(geometry: geo)
                n.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
                n.position = SCNVector3(sign * (width / 2 + 0.0005), height * 0.08, zPos)
                floorNode.addChildNode(n)
            }
        }
    }

    private func addCurtainGlass(to floorNode: SCNNode, width: Float, height: Float, depth: Float) {
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(red: 0.30, green: 0.52, blue: 0.78, alpha: 0.60)
        mat.metalness.contents = 0.65      // yüksek yansıma — SolidWorks cam
        mat.roughness.contents = 0.04
        mat.transparency = 0.48
        mat.isDoubleSided = true
        let glassH = height * 0.72
        let chamfer = CGFloat(width) * 0.008
        for sign: Float in [1, -1] {
            let geo = SCNBox(width: CGFloat(width * 0.88), height: CGFloat(glassH),
                             length: 0.0015, chamferRadius: chamfer)
            geo.materials = [mat]
            let n = SCNNode(geometry: geo)
            n.position = SCNVector3(0, height * 0.12, sign * (depth / 2 + 0.0008))
            floorNode.addChildNode(n)
        }
    }

    private func windowMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(red: 0.42, green: 0.65, blue: 0.90, alpha: 0.65)
        mat.metalness.contents = 0.60
        mat.roughness.contents = 0.04
        mat.transparency = 0.45
        mat.isDoubleSided = true
        return mat
    }

    // MARK: - Balconies

    private func addBalcony(to floorNode: SCNNode, width: Float, height: Float, depth: Float) {
        let group = SCNNode()
        group.name = "emsal_balcony"
        let slabThick = height * 0.06
        let slabDepth = height * 0.35
        let slabW = width * 0.55
        let slabMat = makeMat(UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1), rough: 0.70)
        let slab = SCNBox(width: CGFloat(slabW), height: CGFloat(slabThick),
                          length: CGFloat(slabDepth), chamferRadius: 0.001)
        slab.materials = [slabMat]
        let slabNode = SCNNode(geometry: slab)
        slabNode.position = SCNVector3(0, -height / 2 + slabThick / 2, depth / 2 + slabDepth / 2)
        group.addChildNode(slabNode)
        let railH = height * 0.26
        let railThick: Float = 0.003
        let railMat = makeMat(UIColor(red: 0.68, green: 0.68, blue: 0.70, alpha: 0.85), rough: 0.50)
        let frontRail = SCNBox(width: CGFloat(slabW), height: CGFloat(railH),
                               length: CGFloat(railThick), chamferRadius: 0)
        frontRail.materials = [railMat]
        let fr = SCNNode(geometry: frontRail)
        fr.position = SCNVector3(0, -height / 2 + railH / 2, depth / 2 + slabDepth - railThick / 2)
        group.addChildNode(fr)
        for sign: Float in [-1, 1] {
            let sideRail = SCNBox(width: CGFloat(railThick), height: CGFloat(railH),
                                  length: CGFloat(slabDepth), chamferRadius: 0)
            sideRail.materials = [railMat]
            let sr = SCNNode(geometry: sideRail)
            sr.position = SCNVector3(sign * slabW / 2, -height / 2 + railH / 2, depth / 2 + slabDepth / 2)
            group.addChildNode(sr)
        }
        floorNode.addChildNode(group)
    }

    // MARK: - Helpers

    @discardableResult
    private func addBox(to parent: SCNNode, size: (Float, Float, Float),
                        pos: (Float, Float, Float), color: UIColor, roughness: Double,
                        metalness: Double = 0.0) -> SCNNode {
        // Chamfer: en küçük boyutun %5'i — SolidWorks kenar vurgusunu verir
        let chamfer = CGFloat(min(size.0, size.1, size.2) * 0.05)
        let geo = SCNBox(width: CGFloat(size.0), height: CGFloat(size.1),
                         length: CGFloat(size.2), chamferRadius: max(0.003, chamfer))
        geo.materials = [makeMat(color, rough: roughness, metalness: metalness)]
        let node = SCNNode(geometry: geo)
        node.position = SCNVector3(pos.0, pos.1, pos.2)
        parent.addChildNode(node)
        return node
    }

    private func makeMat(_ color: UIColor, rough: Double, metalness: Double = 0.0) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.roughness.contents = max(0.18, rough)   // minimum 0.18 — SolidWorks plastik/beton görünümü
        m.metalness.contents = metalness
        m.isDoubleSided = false
        return m
    }

    private func decodedRing(from data: Data?) -> [(Float, Float)] {
        guard let data = data,
              let geo = try? JSONDecoder().decode(ParselGeometry.self, from: data)
        else { return [] }
        let centered = ParselGeometryAnalyzer.centeredMetricRing(geo)
        guard !centered.isEmpty else { return [] }
        return centered.map { (Float($0.0), Float($0.1)) }
    }

    private func parselSize(ring: [(Float, Float)], fallbackArea: Double) -> (Double, Double) {
        if ring.count >= 3 {
            let xs = ring.map { Double($0.0) }
            let ys = ring.map { Double($0.1) }
            let w = (xs.max() ?? 0) - (xs.min() ?? 0)
            let d = (ys.max() ?? 0) - (ys.min() ?? 0)
            if w > 1 && d > 1 { return (w, d) }
        }
        let side = sqrt(max(fallbackArea, 100))
        return (side, side * 1.3)
    }
}
