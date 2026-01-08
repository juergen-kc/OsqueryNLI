#!/usr/bin/env swift

import AppKit
import Foundation

// Create a 1024x1024 app icon for Osquery NLI
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

// Background gradient (dark blue to purple)
let gradient = NSGradient(colors: [
    NSColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0),
    NSColor(red: 0.2, green: 0.1, blue: 0.4, alpha: 1.0),
    NSColor(red: 0.15, green: 0.15, blue: 0.35, alpha: 1.0)
])

// Draw rounded rectangle background
let bgRect = NSRect(x: 0, y: 0, width: 1024, height: 1024)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 180, yRadius: 180)
gradient?.draw(in: bgPath, angle: -45)

// Draw terminal-style icon
let terminalRect = NSRect(x: 180, y: 280, width: 664, height: 480)
let terminalPath = NSBezierPath(roundedRect: terminalRect, xRadius: 40, yRadius: 40)

// Terminal background (darker)
NSColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0).setFill()
terminalPath.fill()

// Terminal border
NSColor(red: 0.3, green: 0.4, blue: 0.8, alpha: 0.6).setStroke()
terminalPath.lineWidth = 8
terminalPath.stroke()

// Draw "prompt" cursor line (cyan/teal color)
let promptColor = NSColor(red: 0.0, green: 0.8, blue: 0.8, alpha: 1.0)
promptColor.setFill()

// > symbol
let chevronPath = NSBezierPath()
chevronPath.move(to: NSPoint(x: 240, y: 580))
chevronPath.line(to: NSPoint(x: 300, y: 520))
chevronPath.line(to: NSPoint(x: 240, y: 460))
chevronPath.lineWidth = 24
chevronPath.lineCapStyle = .round
promptColor.setStroke()
chevronPath.stroke()

// Cursor block
let cursorRect = NSRect(x: 340, y: 480, width: 30, height: 80)
let cursorPath = NSBezierPath(rect: cursorRect)
promptColor.setFill()
cursorPath.fill()

// Draw "SQL" text to represent query
let sqlColor = NSColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 0.9)
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 72, weight: .bold),
    .foregroundColor: sqlColor
]
let sqlText = "SELECT *"
sqlText.draw(at: NSPoint(x: 400, y: 485), withAttributes: attributes)

// Draw magnifying glass (search/query symbol) in top right
let glassColor = NSColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 0.9)
glassColor.setStroke()

// Glass circle
let glassCircle = NSBezierPath(ovalIn: NSRect(x: 620, y: 620, width: 200, height: 200))
glassCircle.lineWidth = 20
glassCircle.stroke()

// Glass handle
let handlePath = NSBezierPath()
handlePath.move(to: NSPoint(x: 760, y: 640))
handlePath.line(to: NSPoint(x: 840, y: 560))
handlePath.lineWidth = 24
handlePath.lineCapStyle = .round
handlePath.stroke()

// Draw "NLI" badge at bottom
let badgeRect = NSRect(x: 340, y: 120, width: 344, height: 100)
let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 20, yRadius: 20)
NSColor(red: 0.0, green: 0.6, blue: 0.9, alpha: 1.0).setFill()
badgePath.fill()

let badgeAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 56, weight: .bold),
    .foregroundColor: NSColor.white
]
let badgeText = "NLI"
let badgeTextSize = badgeText.size(withAttributes: badgeAttributes)
let badgeTextX = badgeRect.midX - badgeTextSize.width / 2
let badgeTextY = badgeRect.midY - badgeTextSize.height / 2
badgeText.draw(at: NSPoint(x: badgeTextX, y: badgeTextY), withAttributes: badgeAttributes)

image.unlockFocus()

// Save as PNG
guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG data")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Distribution/AppIcon.png"

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Icon saved to: \(outputPath)")
} catch {
    print("Failed to save icon: \(error)")
    exit(1)
}
