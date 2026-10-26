import AppKit
import Foundation

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let bounds = NSRect(x: 40, y: 40, width: 944, height: 944)
let background = NSBezierPath(roundedRect: bounds, xRadius: 215, yRadius: 215)
let gradient = NSGradient(starting: NSColor(red: 0.04, green: 0.65, blue: 0.62, alpha: 1),
                          ending: NSColor(red: 0.015, green: 0.32, blue: 0.42, alpha: 1))!
gradient.draw(in: background, angle: -55)
let waveform = NSBezierPath()
waveform.move(to: NSPoint(x: 185, y: 500))
waveform.line(to: NSPoint(x: 335, y: 500))
waveform.line(to: NSPoint(x: 405, y: 660))
waveform.line(to: NSPoint(x: 500, y: 335))
waveform.line(to: NSPoint(x: 595, y: 590))
waveform.line(to: NSPoint(x: 660, y: 500))
waveform.line(to: NSPoint(x: 840, y: 500))
waveform.lineWidth = 48
waveform.lineCapStyle = .round
waveform.lineJoinStyle = .round
NSColor.white.setStroke()
waveform.stroke()
image.unlockFocus()
guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("Could not render app icon") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
