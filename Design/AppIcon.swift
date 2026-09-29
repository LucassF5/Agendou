import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Draws the Agendou app icon: a white calendar outline with five dots on a teal gradient, in a
// 1024-point space with the origin at the top left. The PNG is 1024 × 1024 px, sRGB and without alpha,
// as App Store Connect requires.
//
// Usage: swift Design/AppIcon.swift Agendou/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func makeContext(_ size: Int, alpha: Bool = false) -> CGContext {
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (alpha ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast).rawValue)!
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1, y: -1)
    return context
}

func gradient(_ context: CGContext, _ top: UInt32, _ bottom: UInt32) {
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(top), color(bottom)] as CFArray,
        locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 1024), options: [])
}

/// Minimal glyph: white outlined calendar with bold dots, reads well at small sizes.
func glyph(_ context: CGContext) {
    let card = CGRect(x: 212, y: 262, width: 600, height: 560)
    context.setStrokeColor(color(0xFFFFFF))
    context.setLineWidth(56)
    context.addPath(rounded(card, 110))
    context.strokePath()
    context.setFillColor(color(0xFFFFFF))
    context.fill(CGRect(x: card.minX, y: card.minY + 110, width: card.width, height: 56))
    context.addPath(rounded(CGRect(x: card.minX, y: card.minY - 28, width: card.width, height: 190), 110))
    context.fillPath()
    for x in [362.0, 606.0] {
        context.addPath(rounded(CGRect(x: x, y: 190, width: 56, height: 130), 28))
        context.fillPath()
    }
    let dot: CGFloat = 92
    let positions: [(CGFloat, CGFloat)] = [(300, 470), (466, 470), (632, 470), (383, 626), (549, 626)]
    for (x, y) in positions {
        context.addEllipse(in: CGRect(x: x, y: y, width: dot, height: dot))
        context.fillPath()
    }
}

func write(_ image: CGImage, to path: String) {
    let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

let context = makeContext(1024)
gradient(context, 0x14B8A6, 0x155E75)
glyph(context)
write(context.makeImage()!, to: CommandLine.arguments[1])
