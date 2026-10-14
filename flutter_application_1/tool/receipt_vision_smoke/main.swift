// Synthetic SCB-style layout; no real account or transaction data.
// swiftc ios/Runner/ReceiptTextRecognizer.swift tool/receipt_vision_smoke/main.swift -o /tmp/receipt-vision-check
// /tmp/receipt-vision-check
import AppKit
import Foundation
let output = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("budgetmate-vision-test")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1290, pixelsHigh: 2017, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: 1290, height: 2017).fill()
func line(_ text: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat = 44) {
  (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor.black])
}
line("SCB", 450, 1770, 90)
line("โอนเงินสำเร็จ", 430, 1570, 55)
line("29 ก.ย. 2569 - 22:26", 430, 1470)
line("รหัสอ้างอิง: TEST20260929ABC", 240, 1390)
line("จาก", 70, 1220); line("ผู้ส่งทดสอบ", 820, 1220)
line("xxx-xxx123-4", 910, 1130)
line("ไปยัง", 70, 1020); line("ผู้รับทดสอบ", 820, 1020)
line("xxx-xxx-5678", 910, 920)
line("จำนวนเงิน", 70, 740)
if CommandLine.arguments.contains("--large-amount") {
  line("350.00", 920, 728, 80)
} else {
  line("350.00", 1050, 740)
}
line("ผู้รับเงินสามารถตรวจสอบสถานะการโอนเงิน", 70, 490)
NSGraphicsContext.restoreGraphicsState()
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: output.appendingPathComponent("scb-layout.png"))
let text = try ReceiptTextRecognizer.read(png) ?? "UNSUPPORTED"
try text.write(toFile: output.appendingPathComponent("ocr.txt").path, atomically: true, encoding: .utf8)
print(text)
guard text.components(separatedBy: "\n").contains("จำนวนเงิน 350.00"),
      text.contains("29 ก.ย. 2569") else { exit(1) }
