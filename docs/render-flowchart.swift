// Run: swift -module-cache-path /tmp/budgetmate-swift-cache docs/render-flowchart.swift
import AppKit

let width = 1800, height = 2100
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let cg = NSGraphicsContext.current!.cgContext
cg.translateBy(x: 0, y: CGFloat(height)); cg.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
let ink = NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.28, alpha: 1)
func text(_ value: String, _ rect: NSRect, size: CGFloat = 24, bold: Bool = false) {
    let style = NSMutableParagraphStyle(); style.alignment = .center
    let font = NSFont(name: bold ? "Thonburi-Bold" : "Thonburi", size: size) ?? NSFont.systemFont(ofSize: size)
    (value as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: [.font: font, .foregroundColor: ink, .paragraphStyle: style])
}
func box(_ value: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat = 90, decision: Bool = false) {
    let rect = NSRect(x: x, y: y, width: w, height: h)
    let path = NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16)
    (decision ? NSColor(calibratedRed: 1, green: 0.94, blue: 0.78, alpha: 1) : NSColor(calibratedRed: 0.89, green: 0.95, blue: 0.98, alpha: 1)).setFill(); path.fill()
    ink.withAlphaComponent(0.4).setStroke(); path.lineWidth = 1.5; path.stroke()
    text(value, NSRect(x: x + 12, y: y + 12, width: w - 24, height: h - 16))
}
func arrow(_ x: CGFloat, _ y: CGFloat) {
    ink.setStroke(); ink.setFill()
    let p = NSBezierPath(); p.move(to: NSPoint(x: x, y: y)); p.line(to: NSPoint(x: x, y: y + 24)); p.lineWidth = 2; p.stroke()
    let a = NSBezierPath(); a.move(to: NSPoint(x: x - 6, y: y + 18)); a.line(to: NSPoint(x: x, y: y + 27)); a.line(to: NSPoint(x: x + 6, y: y + 18)); a.close(); a.fill()
}
text("BudgetMate — App Flowchart", NSRect(x: 40, y: 25, width: 1720, height: 65), size: 44, bold: true)
text("แผนผังฉบับย่อ • ตรวจเทียบโค้ดใน workspace วันที่ 10 ตุลาคม 2026", NSRect(x: 40, y: 90, width: 1720, height: 50), size: 24)
box("เปิดแอป → เตรียมข้อมูลและกู้คืน Session", x: 400, y: 150, w: 1000, h: 65)
arrow(900, 218)
box("มีผู้ใช้ในระบบ → หน้าหลัก     |     ไม่มีผู้ใช้ → หน้าเข้าสู่ระบบ (ขั้นตอน 1)", x: 180, y: 250, w: 1440, h: 65, decision: true)
arrow(900, 318)
box("5 แท็บหลัก: หน้าหลัก • กระเป๋าเงิน • เพิ่มรายการ • สถิติ • เมนูบัญชี", x: 100, y: 350, w: 1600, h: 65)
text("ทางลัดในหน้าหลัก / กระเป๋าเงิน / เมนูบัญชี: จดรายจ่าย • สลิป/ใบเสร็จ • ธุรกรรม • ออมเงิน", NSRect(x: 60, y: 435, width: 1680, height: 50), size: 23)

let panels: [(String, [String])] = [
 ("1  เข้าสู่ระบบและสมัครสมาชิก", [
 "อีเมล + รหัสผ่าน\nสำเร็จ → หน้าหลัก / ผิดพลาด → แก้ไข",
 "Google สำเร็จ: บัญชีเดิม → หน้าหลัก\nสร้างบัญชีใหม่ → เลือกภาษาและสกุลเงิน",
 "สมัครสมาชิก → ตรวจข้อมูลและสร้างบัญชี\nสำเร็จ → เลือกภาษาและสกุลเงิน",
 "บันทึกการตั้งค่าสำเร็จ → หน้าหลัก\nหากไม่มีผู้ใช้ในระบบ → หน้าเข้าสู่ระบบ",
 "ลืมรหัสผ่าน → ขอส่งลิงก์ทางอีเมล\nตั้งรหัสใหม่ผ่านลิงก์ → กลับมาเข้าสู่ระบบ"
 ]),
 ("2  เพิ่มรายรับ / รายจ่าย", [
 "เลือกประเภทรายการ\nกรอกจำนวนเงิน หมวดหมู่ และหมายเหตุ",
 "จำนวนเงิน > 0 และเลือกหมวดหมู่?\nไม่ผ่าน → แก้ไข / ผ่าน → รายการรอบันทึก",
 "เพิ่มอีก / แก้ไข / ลบรายการรอบันทึก\nเมื่อพร้อม → กดยืนยันบันทึก",
 "บันทึกทีละรายการ\nผิดพลาด → ตรวจรายการที่ยังรอบันทึก",
 "สำเร็จทั้งหมด → รายการธุรกรรม\nIncomeExpenseScreen"
 ]),
 ("3  สลิป / ใบเสร็จ", [
 "เปิดจากทางลัด หรือหน้าเพิ่มรายการ\nถ่ายรูป / เลือกรูปภาพ",
 "อ่านข้อมูลจากภาพสำเร็จ?\nไม่สำเร็จ → ลองใหม่หรือเลือกรูปใหม่",
 "สำเร็จ → ตรวจแก้ยอดเงิน วันที่ หมายเหตุ\nและเลือกหมวดหมู่รายจ่าย",
 "ตรวจข้อมูล → บันทึกรายจ่ายพร้อมรูป\nผิดพลาด → แก้ไข / ลองบันทึกอีกครั้ง",
 "บันทึกสำเร็จ → ประวัติรายการ\nHistoryScreen"
 ]),
 ("4  เป้าหมายการออม", [
 "เปิดจากทางลัด / หน้าหลัก / กระเป๋าเงิน\nดูเป้าหมายการออม",
 "สร้าง / แก้ไข / ยืนยันลบ / ปักหมุด\nหรือเลือกโอนเงินเข้าเป้าหมาย",
 "กรอกจำนวนเงิน > 0\nไม่เกินยอดคงเหลือและยอดที่ยังขาด",
 "ไม่ผ่าน / บันทึกผิดพลาด → แก้ไขหรือลองใหม่\nผ่าน → บันทึกการโอน",
 "เพิ่มยอดออม + สร้างรายจ่ายการออม\nยอดคงเหลือลดลง → หน้าเป้าหมาย"
 ]),
 ("5  กระเป๋าเงิน / ธุรกรรม / สถิติ", [
 "กระเป๋าเงิน → ดูยอดคงเหลือ\nและสรุปรายรับ–รายจ่าย",
 "แตะสรุป หรือทางลัดธุรกรรม\n→ รายการรายรับ–รายจ่าย",
 "เลือกรายการ → ดูรายละเอียด\nแก้ไข / ทำสำเนา / ยืนยันลบ",
 "หน้าหลัก → ประวัติรายการ\nดูรายการย้อนหลัง",
 "แท็บสถิติ → เลือกช่วงเวลา\nดูกราฟและความคืบหน้าการออม"
 ]),
 ("6  เมนูบัญชี", [
 "แก้ไขชื่อและรูปโปรไฟล์\nเปลี่ยนรหัสผ่าน",
 "เลือกภาษา\nเปลี่ยนธีมสว่าง / มืด",
 "เปิด / ปิดการแจ้งบันทึกสำเร็จ\nดูข้อมูลเกี่ยวกับแอป",
 "กดออกจากระบบ\nล้างสถานะเข้าสู่ระบบ",
 "กลับหน้าเข้าสู่ระบบ\nLoginScreen"
 ])
]
for (index, panel) in panels.enumerated() {
    let x = CGFloat(40 + (index % 3) * 590), y = CGFloat(510 + (index / 3) * 740)
    text(panel.0, NSRect(x: x, y: y, width: 540, height: 55), size: 25, bold: true)
    for (i, label) in panel.1.enumerated() {
        let top = y + 62 + CGFloat(i) * 123
        box(label, x: x, y: top, w: 540, h: 94, decision: label.contains("?") || label.contains("ไม่ผ่าน"))
        // Independent alternatives are intentionally not connected as a sequence.
        if i < 4 && [1, 2, 3].contains(index) { arrow(x + 270, top + 96) }
        if index == 5 && i == 3 { arrow(x + 270, top + 96) }
    }
}
text("ลูกศรแสดงลำดับขั้นตอน • กล่องที่ไม่มีลูกศรเชื่อมเป็นตัวเลือกหรือเส้นทางแยก\nรายละเอียด เงื่อนไข และไฟล์อ้างอิงเพิ่มเติม: docs/app-flowchart.md", NSRect(x: 50, y: 1990, width: 1700, height: 90), size: 23)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/app-flowchart.png"))
