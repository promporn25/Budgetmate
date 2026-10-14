import 'additional_category_artwork.dart';
import 'package:flutter/material.dart';
import '../models/category_model.dart';

/// Stable artwork IDs are persisted with custom categories; never renumber them.
final extraCategoryArtwork = <(String, String, String)>[
  ('ครัวซองต์', 'Croissant', 'food'), ('เค้ก', 'Cake', 'food'),
  ('โดนัท', 'Donut', 'food'), ('ซูชิ', 'Sushi', 'food'),
  ('พิซซ่า', 'Pizza', 'food'), ('ไอศกรีม', 'Ice cream', 'food'),
  ('หูฟัง', 'Headphones', 'tech'), ('แล็ปท็อป', 'Laptop computer', 'tech'),
  ('กล้อง', 'Camera', 'tech'), ('นาฬิกาอัจฉริยะ', 'Smartwatch', 'tech'),
  ('คีย์บอร์ด', 'Keyboard', 'tech'), ('เครื่องพิมพ์', 'Printer', 'tech'),
  ('จักรยาน', 'Bicycle', 'travel'), ('รถไฟ', 'Train', 'travel'),
  ('สกู๊ตเตอร์', 'Scooter', 'travel'), ('กระเป๋าเดินทาง', 'Suitcase', 'travel'),
  ('เต็นท์', 'Tent camping', 'travel'), ('ชายหาด', 'Beach umbrella', 'travel'),
  ('ตุ๊กตาหมี', 'Teddy bear toy', 'life'), ('ขวดนม', 'Baby bottle', 'life'),
  ('ต้นกระบองเพชร', 'Cactus plant', 'life'), ('ช่อดอกไม้', 'Flower bouquet', 'life'),
  ('หนังสือ', 'Book reading', 'life'), ('วาดรูป', 'Painting palette art', 'life'),
  ('รองเท้า', 'Sneakers shoes', 'fashion'), ('กระเป๋าถือ', 'Handbag', 'fashion'),
  ('แว่นกันแดด', 'Sunglasses', 'fashion'), ('น้ำหอม', 'Perfume', 'fashion'),
  ('ไดร์เป่าผม', 'Hair dryer', 'fashion'), ('แหวน', 'Ring jewelry', 'fashion'),
  ('ดัมเบล', 'Dumbbell fitness', 'hobby'), ('บาสเกตบอล', 'Basketball', 'hobby'),
  ('เทนนิส', 'Tennis racket', 'hobby'), ('กีตาร์', 'Guitar music', 'hobby'),
  ('ไมโครโฟน', 'Microphone singing', 'hobby'), ('จิ๊กซอว์', 'Puzzle game', 'hobby'),
  for (final item in additionalCategoryArtwork) (item.$1, item.$2, item.$3),
];

List<CategoryModel> categoryArtworkCatalog(bool thai) => [
  // 33 and 34 share an atlas cell; retain legacy rendering but offer it once.
  for (final category in defaultCategories)
    if (category.id != 'c34')
      if (category.id == 'c18')
        CategoryModel(id: category.id, name: thai ? 'รับเงินออม' : 'Savings received',
          type: category.type, icon: category.icon, imagePath: category.imagePath)
      else category,
  for (var i = 0; i < extraCategoryArtwork.length; i++)
    CategoryModel(id: 'art${100 + i}',
      name: thai ? extraCategoryArtwork[i].$1 : extraCategoryArtwork[i].$2,
      type: CategoryType.expense, icon: Icons.category_outlined, artworkNumber: 100 + i),
];

int artworkNumberOf(CategoryModel c) => c.artworkNumber ?? int.parse(c.id.substring(1));
String artworkGroup(int number) {
  if (number >= 100 && number < 100 + extraCategoryArtwork.length) return extraCategoryArtwork[number - 100].$3;
  if ([1, 2, 35].contains(number)) return 'food';
  if ([45, 46, 47, 54, 55].contains(number)) return 'tech';
  if ([4, 8, 36, 37, 38, 39, 53].contains(number)) return 'travel';
  if ([6, 9, 44].contains(number)) return 'fashion';
  if ([10, 11, 48].contains(number)) return 'hobby';
  return 'life';
}
