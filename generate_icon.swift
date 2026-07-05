#!/usr/bin/swift
import AppKit
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let SIZE = 1024
let cs = CGColorSpaceCreateDeviceRGB()

// Direct CGContext — no Retina scaling
guard let ctx = CGContext(
    data: nil,
    width: SIZE, height: SIZE,
    bitsPerComponent: 8,
    bytesPerRow: SIZE * 4,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { print("❌ Context failed"); exit(1) }

let S = CGFloat(SIZE)

// Flip so origin is top-left (y goes down)
ctx.translateBy(x: 0, y: S)
ctx.scaleBy(x: 1, y: -1)

// ── Background gradient ──
let bgColors = [
    CGColor(red: 0.036, green: 0.082, blue: 0.251, alpha: 1),
    CGColor(red: 0.094, green: 0.220, blue: 0.588, alpha: 1)
] as CFArray
let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0, 1])!
ctx.drawLinearGradient(bgGrad,
    start: CGPoint(x: 0, y: 0),
    end:   CGPoint(x: S, y: S), options: [])

// Top-right glow
let glowColors = [
    CGColor(red: 0.24, green: 0.50, blue: 0.98, alpha: 0.28),
    CGColor(red: 0.24, green: 0.50, blue: 0.98, alpha: 0.00)
] as CFArray
let glowGrad = CGGradient(colorsSpace: cs, colors: glowColors, locations: [0, 1])!
ctx.drawRadialGradient(glowGrad,
    startCenter: CGPoint(x: S*0.82, y: S*0.18), startRadius: 0,
    endCenter:   CGPoint(x: S*0.82, y: S*0.18), endRadius: S*0.52, options: [])

// ── Dot matrix ──
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.038))
var ry: CGFloat = 52
while ry < S {
    var rx: CGFloat = 52
    while rx < S {
        ctx.fillEllipse(in: CGRect(x: rx-2, y: ry-2, width: 4, height: 4))
        rx += 54
    }
    ry += 54
}

// ── Helpers ──
func fillR(_ r: CGRect, _ a: CGFloat) {
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: a))
    ctx.fill(r)
}
func fillP(_ p: CGPath, _ a: CGFloat) {
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: a))
    ctx.addPath(p); ctx.fillPath()
}
func win(_ r: CGRect, lit: Bool) {
    ctx.setFillColor(lit
        ? CGColor(red: 0.55, green: 0.80, blue: 1.00, alpha: 0.70)
        : CGColor(red: 0.05, green: 0.15, blue: 0.40, alpha: 0.85))
    ctx.fill(r)
}

let groundY: CGFloat = 762
let dx: CGFloat = -72, dy: CGFloat = -40

// ── Left building ──
let lbX: CGFloat = 192, lbY: CGFloat = 500, lbW: CGFloat = 138
fillR(CGRect(x: lbX, y: lbY, width: lbW, height: groundY-lbY), 0.48)
for r in 0..<4 { for c in 0..<2 {
    win(CGRect(x: lbX+16+CGFloat(c)*53, y: lbY+20+CGFloat(r)*55, width: 26, height: 23),
        lit: (r+c) % 2 == 0)
}}

// ── Right building ──
let rbX: CGFloat = 700, rbY: CGFloat = 400, rbW: CGFloat = 150
fillR(CGRect(x: rbX, y: rbY, width: rbW, height: groundY-rbY), 0.48)
for r in 0..<5 { for c in 0..<2 {
    win(CGRect(x: rbX+16+CGFloat(c)*56, y: rbY+20+CGFloat(r)*64, width: 28, height: 26),
        lit: (r+c) % 3 != 1)
}}

// ── Main tower ──
let tX: CGFloat = 348, tY: CGFloat = 228, tW: CGFloat = 328
let tH = groundY - tY

fillR(CGRect(x: tX, y: tY, width: tW, height: tH), 0.94)

let leftFace = CGMutablePath()
leftFace.move(to:    CGPoint(x: tX,      y: tY))
leftFace.addLine(to: CGPoint(x: tX+dx,   y: tY+dy))
leftFace.addLine(to: CGPoint(x: tX+dx,   y: groundY+dy))
leftFace.addLine(to: CGPoint(x: tX,      y: groundY))
leftFace.closeSubpath()
fillP(leftFace, 0.44)

let topFace = CGMutablePath()
topFace.move(to:    CGPoint(x: tX,       y: tY))
topFace.addLine(to: CGPoint(x: tX+tW,    y: tY))
topFace.addLine(to: CGPoint(x: tX+tW+dx, y: tY+dy))
topFace.addLine(to: CGPoint(x: tX+dx,    y: tY+dy))
topFace.closeSubpath()
fillP(topFace, 0.68)

ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.55))
ctx.setLineWidth(2)
ctx.move(to:    CGPoint(x: tX,       y: tY))
ctx.addLine(to: CGPoint(x: tX+tW,    y: tY))
ctx.addLine(to: CGPoint(x: tX+tW+dx, y: tY+dy))
ctx.strokePath()

// Windows
let wC = 5, wR = 10
let winW: CGFloat = 34, winH: CGFloat = 28
let padX = (tW - CGFloat(wC)*winW) / CGFloat(wC+1)
let padY = (tH - CGFloat(wR)*winH) / CGFloat(wR+1)
for r in 0..<wR { for c in 0..<wC {
    let wx = tX + padX*CGFloat(c+1) + winW*CGFloat(c)
    let wy = tY + padY*CGFloat(r+1) + winH*CGFloat(r)
    win(CGRect(x: wx, y: wy, width: winW-3, height: winH-3), lit: (r+c)%3 != 0)
}}

// ── Ground ──
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.30))
ctx.setLineWidth(2.5)
ctx.move(to: CGPoint(x: 108, y: groundY)); ctx.addLine(to: CGPoint(x: 916, y: groundY))
ctx.strokePath()

ctx.setLineDash(phase: 0, lengths: [18, 10])
ctx.setLineWidth(1.5)
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.13))
ctx.move(to: CGPoint(x: 108, y: groundY+38)); ctx.addLine(to: CGPoint(x: 916, y: groundY+38))
ctx.strokePath()
ctx.setLineDash(phase: 0, lengths: [])

// ── Compass ──
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
ctx.setLineWidth(1)
let cx: CGFloat = 88, cy: CGFloat = 88, cr: CGFloat = 26
ctx.addEllipse(in: CGRect(x: cx-cr, y: cy-cr, width: cr*2, height: cr*2))
ctx.strokePath()
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.50))
let arr = CGMutablePath()
arr.move(to: CGPoint(x: cx, y: cy-cr+4))
arr.addLine(to: CGPoint(x: cx-6, y: cy+cr-8))
arr.addLine(to: CGPoint(x: cx+6, y: cy+cr-8))
arr.closeSubpath()
ctx.addPath(arr); ctx.fillPath()

// ── Save as 1024×1024 PNG ──
guard let cgImage = ctx.makeImage() else { print("❌ Image failed"); exit(1) }

let outURL = URL(fileURLWithPath: "/Users/MacPro/My Cloud/EmsalMimar/EmsalMimar/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    print("❌ Destination failed"); exit(1)
}
CGImageDestinationAddImage(dest, cgImage, nil)
CGImageDestinationFinalize(dest)
print("✅ Saved 1024×1024: \(outURL.path)")
