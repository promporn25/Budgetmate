import 'package:budgetmate/services/data_service.dart';
import 'package:budgetmate/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'data_service_test.dart' show MemoryDB;

void main() {
  for (final width in [320.0, 390.0, 648.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('aligned navigation at width $width and text scale $scale', (tester) async {
        final service = DataService(database: MemoryDB());
        addTearDown(service.dispose);
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: service,
          child: MaterialApp(builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale),
              padding: const EdgeInsets.only(bottom: 34)), child: child!),
            home: const Scaffold(bottomNavigationBar: BottomNav(currentIndex: 2))),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final rects = List.generate(5, (i) => tester.getRect(find.byKey(ValueKey('nav-$i'))));
        for (final rect in rects) {
          expect(rect.top, closeTo(rects.first.top, 0.01));
          expect(rect.bottom, closeTo(rects.first.bottom, 0.01));
          expect(rect.width, closeTo(rects.first.width, 0.01));
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.bottom, lessThanOrEqualTo(766));
        }
        expect(rects.last.right - rects.first.left, lessThanOrEqualTo(640));
        expect((rects.first.left + rects.last.right) / 2, closeTo(width / 2, 0.01));
      });
    }
  }
}
