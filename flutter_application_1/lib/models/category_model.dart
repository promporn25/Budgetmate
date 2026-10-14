import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'persisted_icons.dart';
import '../widgets/pastel_artwork.dart';

/// ประเภทของหมวดหมู่ สอดคล้องกับ Entity Category (category_type)
enum CategoryType { income, expense }

/// เอนทิตี้ Category ตามพจนานุกรมข้อมูลในเอกสารบทที่ 3
class CategoryModel {
  final String id; // category_id
  final String name; // category_name
  final CategoryType type; // category_type
  final IconData icon; // ไอคอน fallback เสมอ (ใช้ตอนยังไม่มีรูป หรือโหลดรูปไม่สำเร็จ)
  final String? description; // description

  /// path ไฟล์รูปภาพไอคอนหมวดหมู่ (เช่น 'assets/images/categories/c01.png')
  /// ถ้าเป็น null หรือโหลดไฟล์ไม่สำเร็จ (เช่น ยังไม่ได้ใส่ไฟล์จริงลง assets)
  /// ตัว CategoryIcon widget จะ fallback กลับไปแสดง [icon] แทนโดยอัตโนมัติ
  final String? imagePath;
  final int? artworkNumber;
  final int? colorValue;
  final List<String> subcategories;

  List<CategoryModel> get childCategories => [
    for (var i = 0; i < subcategories.length; i++)
      CategoryModel(id: '$id:sub:$i', name: '$name › ${subcategories[i]}',
        type: type, icon: icon, imagePath: imagePath,
        artworkNumber: artworkNumber, colorValue: colorValue),
  ];

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    this.description,
    this.imagePath,
    this.artworkNumber,
    this.colorValue,
    this.subcategories = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type == CategoryType.income ? 'income' : 'expense',
      'icon_code': icon.codePoint,
      'description': description,
      'image_path': imagePath,
      'artwork_number': artworkNumber,
      'color_value': colorValue,
      'subcategories': subcategories,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] == 'income' ? CategoryType.income : CategoryType.expense,
      // หมายเหตุ: ไอคอนมาตรฐานของ Icons.* ใช้ fontFamily 'MaterialIcons'
      icon: persistedIconFromCodePoint(map['icon_code'] as int),
      description: map['description'] as String?,
      imagePath: map['image_path'] as String?,
      artworkNumber: (map['artwork_number'] as num?)?.toInt(),
      colorValue: (map['color_value'] as num?)?.toInt(),
      subcategories: List<String>.from(map['subcategories'] as List? ?? const []),
    );
  }
}

/// วิดเจ็ตแสดงไอคอนของหมวดหมู่ — ใช้แทน `Icon(category.icon, ...)` ได้ทุกจุดในแอป
/// ถ้า [CategoryModel.imagePath] ตั้งไว้และโหลดรูปสำเร็จ จะแสดงรูปภาพนั้นแทน
/// ถ้าไม่ได้ตั้งไว้ (null) หรือโหลดรูปไม่สำเร็จ (เช่น ยังไม่มีไฟล์จริงใน assets)
/// จะ fallback กลับไปแสดง Material Icon (category.icon) โดยอัตโนมัติ ไม่ทำให้แอปพัง
///
/// หมายเหตุเรื่องสี: [color] จะถูกใช้ "ทาสีทับ" เฉพาะตอน fallback เป็น Material Icon
/// เท่านั้น (เช่น ตอนที่ยังไม่มีไฟล์รูปจริง) ส่วนตอนแสดงรูปภาพจริงจะ "ไม่" ทาสีทับ
/// เพราะรูปภาพหมวดหมู่มักเป็นภาพสีเต็ม/หลายสี ถ้า tint สีทับ (เช่นตอนเลือกแล้วเปลี่ยน
/// เป็นสีขาว) จะทำให้รูปเพี้ยนหรือมองไม่เห็นรายละเอียด จึงปล่อยให้รูปแสดงสีตามต้นฉบับ
/// แล้วใช้สีพื้นหลัง/ขอบกรอบรอบๆ แทนในการสื่อสถานะ selected/unselected
class CategoryIcon extends StatelessWidget {
  final CategoryModel category;
  final double size;
  final Color? color;

  /// ถ้า true: รูปภาพจะถูกวางอยู่ในกรอบขนาด [size] x [size] โดยใช้ BoxFit.contain
  /// นั่นคือรูปจะถูกย่อ/ขยายให้ "พอดีกับกรอบตามสัดส่วนจริงของไฟล์ภาพ" เสมอ
  /// (ไม่ครอบตัด ไม่บิดสัดส่วน) ต่างจากโหมดปกติที่วางรูปแบบไอคอนเล็กลอยตัว
  /// ใช้ตอนอยากให้เห็นรูปเต็มพื้นที่กรอบ เช่น ตะแกรงเลือกหมวดหมู่ใน Add Income/Expense
  final bool fill;

  /// ระดับซูมภาพ (ใช้เฉพาะตอน fill = true) สำหรับปรับภาพให้เต็มกรอบมากขึ้นเล็กน้อย
  /// โดยยังคงสัดส่วนเดิมของภาพไว้ (ไม่ยืด/บิด) ค่า 1.0 = ไม่ซูม
  /// มากกว่า 1.0 = ซูมเข้าเล็กน้อย แต่รูปจะยังคงแสดงตามสัดส่วนจริงเสมอ
  final double zoom;

  /// รัศมีมุมโค้งของกรอบตัดภาพตอน fill = true ให้เข้ากับทรงกรอบสี่เหลี่ยมมุมโค้ง
  /// ของ container ด้านนอก (ค่าเริ่มต้นอ้างอิงจาก AppRadius.md ของดีไซน์ระบบ)
  final double? clipRadius;

  const CategoryIcon({
    super.key,
    required this.category,
    this.size = 24,
    this.color,
    this.fill = false,
    this.zoom = 1.0,
    this.clipRadius,
  });

  @override
  Widget build(BuildContext context) {
    final number = int.tryParse(category.id.replaceFirst('c', ''));
    if (number != null && category.id == 'c${number.toString().padLeft(2, '0')}' && number >= 1 && number <= 55) {
      return PastelArtwork(categoryNumber: number, size: size);
    }
    if (category.artworkNumber != null) {
      return PastelArtwork(categoryNumber: category.artworkNumber!, size: size);
    }
    final path = category.imagePath;
    if (path == null || path.isEmpty) {
      return GoalArtwork(category.icon, size: size, color: color);
    }
    if (fill) {
      // ใช้ BoxFit.contain แทน cover เพื่อให้ "ขนาดที่แสดงจริงของรูปปรับตามสัดส่วน
      // ต้นฉบับของไฟล์ภาพที่ใส่เข้ามา" เสมอ ไม่ว่าไฟล์จะเป็นแนวตั้ง แนวนอน หรือจัตุรัส
      // ก็จะถูกย่อ/ขยายให้พอดีกับกรอบ [size] x [size] โดยไม่ครอบตัดหรือบิดสัดส่วน
      return ClipRRect(
        borderRadius: BorderRadius.circular(clipRadius ?? AppRadius.md),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Transform.scale(
              scale: zoom,
              child: Image.asset(
                path,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(category.icon, size: size * 0.55, color: color),
              ),
            ),
          ),
        ),
      );
    }
    return Image.asset(
      path,
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) =>
          Icon(category.icon, size: size, color: color),
    );
  }
}

/// หมวดหมู่เริ่มต้นของระบบ (จะถูก seed ลง SQLite อัตโนมัติครั้งแรกที่เปิดแอป)
/// imagePath เตรียม path ไว้ล่วงหน้าตาม id (เช่น c01 -> c01.png) พอมีไฟล์รูปจริง
/// แค่นำไปวางที่ assets/images/categories/ ตามชื่อไฟล์นี้ได้เลย ไม่ต้องแก้โค้ดเพิ่ม
/// (ถ้ายังไม่มีไฟล์ตอนนี้ก็ไม่เป็นไร CategoryIcon จะ fallback ไปใช้ icon เดิมให้อัตโนมัติ)
const String _catImgBase = 'assets/images/categories';
final List<CategoryModel> defaultCategories = [
  CategoryModel(id: 'c01', name: 'อาหาร', type: CategoryType.expense, icon: Icons.restaurant, imagePath: '$_catImgBase/c01.png'),
  CategoryModel(id: 'c02', name: 'เครื่องดื่ม', type: CategoryType.expense, icon: Icons.local_cafe, imagePath: '$_catImgBase/c02.png'),
  CategoryModel(id: 'c03', name: 'ที่พัก', type: CategoryType.expense, icon: Icons.home, imagePath: '$_catImgBase/c03.png'),
  CategoryModel(id: 'c04', name: 'ยานพาหนะ', type: CategoryType.expense, icon: Icons.directions_car, imagePath: '$_catImgBase/c04.png'),
  CategoryModel(id: 'c05', name: 'ภาษี', type: CategoryType.expense, icon: Icons.receipt_long, imagePath: '$_catImgBase/c05.png'),
  CategoryModel(id: 'c06', name: 'ช้อปปิ้ง', type: CategoryType.expense, icon: Icons.shopping_bag, imagePath: '$_catImgBase/c06.png'),
  CategoryModel(id: 'c07', name: 'ของขวัญ', type: CategoryType.expense, icon: Icons.card_giftcard, imagePath: '$_catImgBase/c07.png'),
  CategoryModel(id: 'c08', name: 'ท่องเที่ยว', type: CategoryType.expense, icon: Icons.flight, imagePath: '$_catImgBase/c08.png'),
  CategoryModel(id: 'c09', name: 'ความงาม', type: CategoryType.expense, icon: Icons.spa, imagePath: '$_catImgBase/c09.png'),
  CategoryModel(id: 'c10', name: 'บันเทิง', type: CategoryType.expense, icon: Icons.music_note, imagePath: '$_catImgBase/c10.png'),
  CategoryModel(id: 'c11', name: 'กีฬา', type: CategoryType.expense, icon: Icons.sports_soccer, imagePath: '$_catImgBase/c11.png'),
  CategoryModel(id: 'c12', name: 'สัตว์เลี้ยง', type: CategoryType.expense, icon: Icons.pets, imagePath: '$_catImgBase/c12.png'),
  CategoryModel(id: 'c13', name: 'การศึกษา', type: CategoryType.expense, icon: Icons.school, imagePath: '$_catImgBase/c13.png'),
  CategoryModel(id: 'c14', name: 'เงินเดือน', type: CategoryType.income, icon: Icons.payments, imagePath: '$_catImgBase/c14.png'),
  CategoryModel(id: 'c15', name: 'รายได้เสริม', type: CategoryType.income, icon: Icons.trending_up, imagePath: '$_catImgBase/c15.png'),
  CategoryModel(id: 'c16', name: 'โบนัส', type: CategoryType.income, icon: Icons.card_membership, imagePath: '$_catImgBase/c16.png'),

  // หมวดหมู่รายจ่ายพิเศษ: ใช้บันทึกอัตโนมัติเมื่อผู้ใช้ "โอนเงินจริง" เข้าเป้าหมายการออม
  // (ต้องใช้ id คงที่ 'c17' เพื่อให้ DataService ค้นหา/สร้างซ้ำได้อย่างสม่ำเสมอ)
  CategoryModel(id: 'c17', name: 'เงินออม', type: CategoryType.expense, icon: Icons.savings, imagePath: '$_catImgBase/c17.png'),

  // ===== หมวดหมู่รายรับเพิ่มเติม (ตามชุดไอคอนอ้างอิง) =====
  CategoryModel(id: 'c18', name: 'เงินออม', type: CategoryType.income, icon: Icons.savings, imagePath: '$_catImgBase/c18.png'),
  CategoryModel(id: 'c19', name: 'ค่าคอมมิชชั่น', type: CategoryType.income, icon: Icons.handshake, imagePath: '$_catImgBase/c19.png'),
  CategoryModel(id: 'c20', name: 'ลงทุน', type: CategoryType.income, icon: Icons.currency_bitcoin, imagePath: '$_catImgBase/c20.png'),
  CategoryModel(id: 'c21', name: 'ปันผล', type: CategoryType.income, icon: Icons.insights, imagePath: '$_catImgBase/c21.png'),
  CategoryModel(id: 'c22', name: 'ค่าเช่ารับ', type: CategoryType.income, icon: Icons.home_work, imagePath: '$_catImgBase/c22.png'),
  CategoryModel(id: 'c23', name: 'รายได้ธุรกิจ', type: CategoryType.income, icon: Icons.storefront, imagePath: '$_catImgBase/c23.png'),
  CategoryModel(id: 'c24', name: 'ทุนการศึกษา', type: CategoryType.income, icon: Icons.school, imagePath: '$_catImgBase/c24.png'),
  CategoryModel(id: 'c25', name: 'เงินคืน/คืนภาษี', type: CategoryType.income, icon: Icons.request_quote, imagePath: '$_catImgBase/c25.png'),
  CategoryModel(id: 'c26', name: 'รางวัล', type: CategoryType.income, icon: Icons.emoji_events, imagePath: '$_catImgBase/c26.png'),
  CategoryModel(id: 'c27', name: 'รับจากครอบครัว', type: CategoryType.income, icon: Icons.family_restroom, imagePath: '$_catImgBase/c27.png'),
  CategoryModel(id: 'c28', name: 'รับจากเพื่อน', type: CategoryType.income, icon: Icons.people_alt, imagePath: '$_catImgBase/c28.png'),
  CategoryModel(id: 'c29', name: 'ขายของออนไลน์', type: CategoryType.income, icon: Icons.sell, imagePath: '$_catImgBase/c29.png'),
  CategoryModel(id: 'c30', name: 'รายได้จากงานอดิเรก', type: CategoryType.income, icon: Icons.camera_alt, imagePath: '$_catImgBase/c30.png'),
  CategoryModel(id: 'c31', name: 'ลิขสิทธิ์/ค่าสิทธิ์', type: CategoryType.income, icon: Icons.copyright, imagePath: '$_catImgBase/c31.png'),
  CategoryModel(id: 'c32', name: 'รายได้อื่นๆ', type: CategoryType.income, icon: Icons.star_rounded, imagePath: '$_catImgBase/c32.png'),
  CategoryModel(id: 'c33', name: 'เงินสนับสนุน', type: CategoryType.income, icon: Icons.volunteer_activism, imagePath: '$_catImgBase/c33.png'),
  CategoryModel(id: 'c34', name: 'เงินช่วยเหลือ', type: CategoryType.income, icon: Icons.support, imagePath: '$_catImgBase/c34.png'),

  // ===== หมวดหมู่รายจ่ายเพิ่มเติม (ตามชุดไอคอนอ้างอิง) =====
  CategoryModel(id: 'c35', name: 'กาแฟ', type: CategoryType.expense, icon: Icons.local_cafe, imagePath: '$_catImgBase/c35.png'),
  CategoryModel(id: 'c36', name: 'ค่าเดินทาง', type: CategoryType.expense, icon: Icons.commute, imagePath: '$_catImgBase/c36.png'),
  CategoryModel(id: 'c37', name: 'แท็กซี่', type: CategoryType.expense, icon: Icons.local_taxi, imagePath: '$_catImgBase/c37.png'),
  CategoryModel(id: 'c38', name: 'น้ำมันรถ', type: CategoryType.expense, icon: Icons.local_gas_station, imagePath: '$_catImgBase/c38.png'),
  CategoryModel(id: 'c39', name: 'ค่าจอดรถ', type: CategoryType.expense, icon: Icons.local_parking, imagePath: '$_catImgBase/c39.png'),
  CategoryModel(id: 'c40', name: 'ที่อยู่อาศัย', type: CategoryType.expense, icon: Icons.apartment, imagePath: '$_catImgBase/c40.png'),
  CategoryModel(id: 'c41', name: 'ค่าน้ำไฟ', type: CategoryType.expense, icon: Icons.lightbulb, imagePath: '$_catImgBase/c41.png'),
  CategoryModel(id: 'c42', name: 'ค่าน้ำ', type: CategoryType.expense, icon: Icons.water_drop, imagePath: '$_catImgBase/c42.png'),
  CategoryModel(id: 'c43', name: 'ของใช้ในบ้าน', type: CategoryType.expense, icon: Icons.shopping_cart, imagePath: '$_catImgBase/c43.png'),
  CategoryModel(id: 'c44', name: 'เสื้อผ้า', type: CategoryType.expense, icon: Icons.checkroom, imagePath: '$_catImgBase/c44.png'),
  CategoryModel(id: 'c45', name: 'โทรศัพท์', type: CategoryType.expense, icon: Icons.smartphone, imagePath: '$_catImgBase/c45.png'),
  CategoryModel(id: 'c46', name: 'อินเทอร์เน็ต', type: CategoryType.expense, icon: Icons.wifi, imagePath: '$_catImgBase/c46.png'),
  CategoryModel(id: 'c47', name: 'สตรีมมิ่ง', type: CategoryType.expense, icon: Icons.subscriptions, imagePath: '$_catImgBase/c47.png'),
  CategoryModel(id: 'c48', name: 'สุขภาพ', type: CategoryType.expense, icon: Icons.fitness_center, imagePath: '$_catImgBase/c48.png'),
  CategoryModel(id: 'c49', name: 'ค่ารักษาพยาบาล', type: CategoryType.expense, icon: Icons.local_hospital, imagePath: '$_catImgBase/c49.png'),
  CategoryModel(id: 'c50', name: 'ยา', type: CategoryType.expense, icon: Icons.medication, imagePath: '$_catImgBase/c50.png'),
  CategoryModel(id: 'c51', name: 'ประกัน', type: CategoryType.expense, icon: Icons.health_and_safety, imagePath: '$_catImgBase/c51.png'),
  CategoryModel(id: 'c52', name: 'อุปกรณ์การเรียน', type: CategoryType.expense, icon: Icons.edit_note, imagePath: '$_catImgBase/c52.png'),
  CategoryModel(id: 'c53', name: 'ทริป/กิจกรรม', type: CategoryType.expense, icon: Icons.camera_alt, imagePath: '$_catImgBase/c53.png'),
  CategoryModel(id: 'c54', name: 'ดูหนัง', type: CategoryType.expense, icon: Icons.local_movies, imagePath: '$_catImgBase/c54.png'),
  CategoryModel(id: 'c55', name: 'เกม', type: CategoryType.expense, icon: Icons.sports_esports, imagePath: '$_catImgBase/c55.png'),

];