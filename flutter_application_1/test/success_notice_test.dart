import 'package:budgetmate/services/data_service.dart';
import 'package:budgetmate/widgets/success_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'data_service_test.dart' show MemoryDB;

void main() {
  for (final action in [
    'stay',
    'replace',
    'pop',
    'disabled',
    'close',
    'repeat'
  ]) {
    testWidgets('success notice after $action', (tester) async {
      final service = DataService(database: MemoryDB())
        ..successNotesEnabled = action != 'disabled';
      addTearDown(service.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: service,
        child: MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Home')),
        ),
      ));
      navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: Center(
              child: TextButton(
            onPressed: () {
              showSuccessNotice(context, 'transaction_saved');
              if (action == 'replace') {
                Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('History')),
                ));
              } else if (action == 'pop') {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          )),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text(service.t('transaction_saved')),
          action == 'disabled' ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
      if (action != 'disabled') {
        final notice = find.text(service.t('transaction_saved'));
        expect(tester.getTopLeft(notice).dy, lessThan(150));
        if (action == 'close') {
          await tester.tap(find.byIcon(Icons.close));
          await tester.pumpAndSettle();
          expect(notice, findsNothing);
        } else if (action == 'repeat') {
          await tester.pump(const Duration(seconds: 3));
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 2));
          expect(notice, findsOneWidget);
        }
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(notice, findsNothing);
      }
    });
  }
}
