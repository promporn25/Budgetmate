import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:budgetmate/models/category_model.dart';
import 'package:budgetmate/widgets/additional_category_artwork.dart';
import 'package:budgetmate/widgets/category_artwork_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('410 new image cells are nonempty and have distinct pixels', () async {
    final fingerprints = <String>{};
    for (var sheet = 0; sheet < 12; sheet++) {
      final path = 'assets/images/categories/pastel_collection_${sheet.toString().padLeft(2, '0')}_transparent.png';
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      expect(image.width, image.height);
      final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer.asUint8List();
      for (var cell = 0; cell < (sheet == 11 ? 14 : 36); cell++) {
        final x0 = ((cell % 6) * image.width / 6).round();
        final x1 = ((cell % 6 + 1) * image.width / 6).round();
        final y0 = ((cell ~/ 6) * image.height / 6).round();
        final y1 = ((cell ~/ 6 + 1) * image.height / 6).round();
        final bytes = BytesBuilder(copy: false);
        var coloredPixels = 0;
        var transparentPixels = 0;
        for (var y = y0; y < y1; y++) {
          final row = Uint8List.sublistView(pixels,
              (y * image.width + x0) * 4, (y * image.width + x1) * 4);
          bytes.add(row);
          for (var x = 0; x < row.length; x += 4) {
            if (row[x + 3] == 0) transparentPixels++;
            if (row[x + 3] > 200 &&
                (row[x] < 200 || row[x + 1] < 200 || row[x + 2] < 200)) {
              coloredPixels++;
            }
          }
        }
        expect(coloredPixels, greaterThan(500), reason: '$path cell $cell is empty');
        expect(transparentPixels, greaterThan(500),
            reason: '$path cell $cell still has an opaque background');
        expect(fingerprints.add(sha256.convert(bytes.takeBytes()).toString()), isTrue,
            reason: '$path cell $cell repeats another illustration');
      }
      image.dispose();
      codec.dispose();
    }
    expect(fingerprints, hasLength(410));
  });

  test('500 distinct choices with stable artwork IDs and valid groups', () {
    for (final thai in [true, false]) {
      final catalog = categoryArtworkCatalog(thai);
      expect(catalog, hasLength(500));
      expect(catalog.map((c) => c.id).toSet(), hasLength(500));
      expect(catalog.map((c) => c.name).toSet(), hasLength(500));
      expect(catalog.map(artworkNumberOf).toSet(), hasLength(500));
      for (final category in catalog) {
        expect(['food', 'tech', 'travel', 'life', 'fashion', 'hobby'],
            contains(artworkGroup(artworkNumberOf(category))));
        expect(artworkNumberOf(CategoryModel.fromMap(category.toMap())),
            artworkNumberOf(category));
      }
      expect(catalog.any((c) => artworkNumberOf(c) == 34), isFalse);
      expect(catalog.firstWhere((c) => c.id == 'art100').artworkNumber, 100);
      expect(catalog.firstWhere((c) => c.id == 'art135').artworkNumber, 135);
    }
    expect(additionalCategoryArtwork.map((a) => a.$2).toSet(), hasLength(410));
  });

  testWidgets('all illustrated cells use their own atlas position without emoji', (tester) async {
    for (final size in [24.0, 58.0]) {
      for (var sheet = 0; sheet < 12; sheet++) {
        final start = sheet * 36;
        final end = (start + 36).clamp(0, additionalCategoryArtwork.length);
        final path = 'assets/images/categories/pastel_collection_${sheet.toString().padLeft(2, '0')}_transparent.png';
        await tester.pumpWidget(MaterialApp(home: Scaffold(body:
          Wrap(children: [
            for (var i = start; i < end; i++)
              CategoryIcon(category: CategoryModel.fromMap(CategoryModel(
                id: 'saved-$i', name: additionalCategoryArtwork[i].$1,
                type: CategoryType.expense, icon: Icons.category_outlined,
                artworkNumber: 136 + i,
              ).toMap()), size: size),
          ]),
        )));
        await tester.runAsync(() async {
          await precacheImage(AssetImage(path),
              tester.element(find.byType(Scaffold)));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Text), findsNothing);
        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        expect(images, hasLength(end - start));
        expect(images.every((image) => image.image == AssetImage(path)), isTrue);
        final cells = tester.widgetList<Positioned>(find.byType(Positioned))
            .where((cell) => cell.width == size * 6).toList();
        for (var cell = 0; cell < cells.length; cell++) {
          expect(cells[cell].left, -(cell % 6) * size);
          expect(cells[cell].top, -(cell ~/ 6) * size);
        }
      }
    }
  });
}
