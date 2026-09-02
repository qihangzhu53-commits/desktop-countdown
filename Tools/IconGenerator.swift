import AppKit

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: IconGenerator <output.png>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvasSize = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvasSize)

image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
    fputs("Unable to create graphics context\n", stderr)
    exit(3)
}

context.setShouldAntialias(true)
context.setAllowsAntialiasing(true)

let outerRect = NSRect(x: 58, y: 58, width: 908, height: 908)
let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 208, yRadius: 208)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
shadow.shadowBlurRadius = 44
shadow.shadowOffset = NSSize(width: 0, height: -18)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.black.setFill()
outerPath.fill()
NSGraphicsContext.restoreGraphicsState()

outerPath.addClip()
let gradient = NSGradient(colorsAndLocations:
    (NSColor(calibratedRed: 0.08, green: 0.30, blue: 0.66, alpha: 1), 0.0),
    (NSColor(calibratedRed: 0.20, green: 0.63, blue: 0.78, alpha: 1), 0.47),
    (NSColor(calibratedRed: 0.88, green: 0.16, blue: 0.12, alpha: 1), 1.0)
)
gradient?.draw(in: outerRect, angle: -34)

NSColor.white.withAlphaComponent(0.10).setFill()
NSBezierPath(ovalIn: NSRect(x: 540, y: 500, width: 560, height: 560)).fill()
NSBezierPath(ovalIn: NSRect(x: -80, y: -50, width: 580, height: 580)).fill()

let clockCenter = NSPoint(x: 512, y: 500)
let clockRadius: CGFloat = 276
let clock = NSBezierPath()
clock.appendArc(withCenter: clockCenter, radius: clockRadius, startAngle: 42, endAngle: 356, clockwise: false)
clock.lineWidth = 58
clock.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.96).setStroke()
clock.stroke()

let knob = NSBezierPath(roundedRect: NSRect(x: 446, y: 813, width: 132, height: 52), xRadius: 24, yRadius: 24)
NSColor.white.withAlphaComponent(0.96).setFill()
knob.fill()

let minuteHand = NSBezierPath()
minuteHand.move(to: clockCenter)
minuteHand.line(to: NSPoint(x: 512, y: 660))
minuteHand.lineWidth = 48
minuteHand.lineCapStyle = .round
NSColor.white.setStroke()
minuteHand.stroke()

let hourHand = NSBezierPath()
hourHand.move(to: clockCenter)
hourHand.line(to: NSPoint(x: 638, y: 424))
hourHand.lineWidth = 48
hourHand.lineCapStyle = .round
hourHand.stroke()

NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.27, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 467, y: 455, width: 90, height: 90)).fill()

let border = NSBezierPath(roundedRect: outerRect.insetBy(dx: 4, dy: 4), xRadius: 204, yRadius: 204)
border.lineWidth = 8
NSColor.white.withAlphaComponent(0.22).setStroke()
border.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode icon\n", stderr)
    exit(4)
}

try png.write(to: outputURL, options: .atomic)
