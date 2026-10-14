# Responsive layout review

## ขอบเขตและสาเหตุ

ตรวจโครงสร้างหน้าจอและ shared widgets ก่อนแก้ โดยเก็บงานที่มีอยู่ใน working tree เดิมไว้ ไม่แก้ Firebase, Firestore, Authentication, Provider, model, service หรือสูตรคำนวณทางการเงิน

ปัญหาที่พบ:

- `ResponsiveScale` จำลอง canvas กว้าง 360 แล้ว Transform ทั้งแอป ทำให้ breakpoint ไม่เห็นขนาดจอจริง และบีบ text scaling ของระบบ
- ความสูงกริดไม่รวมความสูงบรรทัดภาษาไทยจริง; การ์ดเป้าหมายใช้ความสูงคงที่และบีบหมายเหตุจนถูกตัด
- ฟอร์มตรึงหลายส่วนพร้อมกัน เมื่อคีย์บอร์ดเปิดบนจอเล็ก พื้นที่แนวตั้งไม่พอ
- หน้าแก้ไขรายการเผื่อ keyboard inset ซ้ำ และแทนปุ่มบันทึกด้วยแป้นตัวเลข
- ชื่อผู้ใช้วาดทับไอคอนท้องฟ้า; รายการสถิติมีข้อความและยอดเงินแย่งความกว้างใน Row

## ไฟล์ที่แก้

| ไฟล์ใต้ lib/ | สิ่งที่เปลี่ยน |
| --- | --- |
| widgets/responsive_scale.dart | ใช้ขนาดจริงและ text scaling ของระบบ; SafeArea เฉพาะแนวนอน ส่วนบน/ล่างยังให้แต่ละหน้าจัดการ |
| screens/app_theme.dart | PrimaryButton ใช้ minimum height และขยายตามข้อความแทน fixed height; ไม่เปลี่ยนชุดสีหรือธีม |
| screens/add_income_expense_screen.dart | ใช้ constraints เลือกการเลื่อนฟอร์มบนพื้นที่จำกัด; วัดความสูง label ของกริด; ช่องยอดเงินยาวเลื่อนแนวนอนได้โดยไม่ย่อฟอนต์; วางฟอร์มเหนือแป้นตัวเลข |
| screens/add_goal_saving_screen.dart | วัด label กริด; ฟอร์มเลื่อนได้เมื่อพื้นที่ไม่พอ; รองรับยอดเงินยาว; ใช้ TapRegion แทน overlay ที่ขวางการเลื่อน |
| screens/edit_transaction_screen.dart | ให้ frame จัดการ keyboard inset เพียงที่เดียว; ปุ่มบันทึกยังอยู่เมื่อเปิดแป้นตัวเลข; เปิด sheet ด้วย SafeArea |
| screens/transaction_details_sheet.dart | เปิด sheet ด้วย SafeArea เพื่อให้หัวเรื่องไม่อยู่ใต้ notch |
| screens/goal_saving_screen.dart | คงสองคอลัมน์ แต่ให้การ์ดสูงตามเนื้อหา; แยกยอดออม/เป้าหมายด้วย Wrap แทน ellipsis; จำกัดแถวจำนวนเงินใน dialog |
| screens/wallet_screen.dart | ยอดเงินในการ์ดรายรับ/รายจ่ายขึ้นบรรทัดได้ แทนการตัดด้วย ellipsis |
| screens/home_screen.dart | จองพื้นที่ไอคอนตกแต่งใน header เพื่อไม่ให้ทับชื่อผู้ใช้ |
| screens/statistic_screen.dart | ใช้พื้นที่การ์ดจริงและ Wrap สำหรับหมวดหมู่ที่ใช้จ่ายสูงสุด/ยอดเงิน |
| screens/language_setup_screen.dart | เนื้อหายังคงอยู่กลางจอ และเลื่อนเฉพาะเมื่อสูงเกินพื้นที่ |
| screens/account_setting_screen.dart | dialog แก้ชื่อเลื่อนได้เมื่อคีย์บอร์ดลดพื้นที่ |
| widgets/period_selector.dart | dialog เลือกวัน/เดือน/ปีเลื่อนได้เมื่อพื้นที่ไม่พอ |

Bottom Navigation เดิมยังคงเดิม: ตรวจการแบ่งพื้นที่ห้าแท็บ ขอบจอ ความสูงปุ่ม และ bottom safe inset ด้วย regression test

ไฟล์ทดสอบ:

- `test/phone_card_layout_test.dart`: 17 หน้าจอ × 6 ขนาด × 2 ธีม × 2 text scales = 408 screen renders; มีข้อมูลรายรับ/รายจ่าย ยอดเงินยาวและเป้าหมาย
- `test/responsive_interaction_test.dart`: keyboard เปิด/ปิด, แป้นตัวเลขที่กดได้จริง, ยอดเงิน 15 หลักรวมจุดทศนิยม, ฟอร์ม auth และรายการ, calendar, category sheet, details/edit sheet และตำแหน่งหัวเรื่องเหนือ notch
- `test/responsive_test_support.dart`: theme สำหรับการทดสอบตรงกับ theme ปัจจุบันของ BudgetMateApp

## ผลตรวจ

- ชุดทดสอบทั้งหมด: **98 ผ่าน**
- หลังเพิ่ม SafeArea ของ sheet: ทดสอบ interaction + Bottom Navigation ซ้ำ **12 ผ่าน**
- Widget tests ใช้ logical pixels: 320×568, 360×640, 375×667, 390×844, 402×874, 430×932
- Light/Dark, text scale 1.0/1.3, top inset 59, bottom inset 34, keyboard inset 260
- Bottom Navigation มีชุดทดสอบเดิมเพิ่มเติมที่ text scale 2.0
- ไม่พบ `RenderFlex overflowed` ในชุดทดสอบที่ผ่าน
- ตรวจภาพ render ของหน้าจอเล็กและขนาด 402 ทั้ง Light/Dark พร้อมปรับจุดข้อความทับกันที่การตรวจ RenderFlex อย่างเดียวไม่พบ
- Analyzer: **0 errors**, 2 warnings เรื่อง dynamic IconData ใน model เดิม และ 177 informational lints; ไม่เปลี่ยน model เพื่อกลบคำเตือน
- ใช้ Flutter SDK ของ IDE: `/Users/promporn/flutter/flutter/bin/flutter` เพราะเครื่องมี SDK อีกชุดใน Homebrew ที่ไม่ตรงกับ package configuration

คำสั่งตรวจ:

```sh
/Users/promporn/flutter/flutter/bin/flutter test --no-pub --concurrency=2
/Users/promporn/flutter/flutter/bin/flutter analyze --no-pub
```

ผลข้างต้นเป็น widget tests และภาพ render ไม่ใช่การทดสอบบน iPhone/Android จริงหรือ native release build จึงยังควรตรวจพฤติกรรมคีย์บอร์ดจริงและ system bars บนอุปกรณ์ก่อนเผยแพร่ ไม่รับรองทุกขนาดหน้าจอหรือ text scaling ที่อยู่นอก matrix นี้

## ปรับสัดส่วนหน้าเมนูและกระเป๋าเงินตาม feedback

- `wallet_screen.dart`: เพิ่มความสูงขั้นต่ำของการ์ดยอดคงเหลือเป็น 132 และการ์ดรายรับ/รายจ่ายเป็น 126 logical pixels; เพิ่มขนาดไอคอน ตัวเลข และ padding พร้อมคงการขยายตามเนื้อหาและการเลื่อนบนจอเล็ก
- `account_setting_screen.dart`: เพิ่มรูปโปรไฟล์ แถวเมนูขั้นต่ำ 58, label 15, icon 24 และปุ่มออกจากระบบขั้นต่ำ 48 logical pixels; คงกลุ่มเมนู สี และ navigation เดิม
- ตรวจ screen matrix เดิม 24 ชุด ผ่านทั้งหมด รวมจอ 320–430, Light/Dark และ text scaling 1.0/1.3; ตรวจภาพ render หน้าเมนูและกระเป๋าเงินขนาด 402
