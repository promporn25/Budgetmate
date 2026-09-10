import 'package:budgetmate/firebase_options.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/data_service.dart';
import 'screens/loading_screen.dart';
import 'screens/app_theme.dart' show appFontFamily, AppColors, AppTheme;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // เตรียมข้อมูล locale ภาษาไทยสำหรับ DateFormat (เช่น ชื่อเดือน/วันภาษาไทย)
  // ต้องเรียกก่อน runApp ไม่งั้นจะเจอ LocaleDataException ตอนใช้ DateFormat(..., 'th')
  await initializeDateFormatting('th', null);

  runApp(const BudgetMateApp());
}

/// ค่า default ของ Flutter (โดยเฉพาะบน Web/Desktop) จะไม่อนุญาตให้ "ลากด้วยเมาส์"
/// เพื่อเลื่อนดู ListView ในแนวนอน/แนวตั้งได้ (บนมือถือใช้นิ้วสัมผัสจะเลื่อนได้ปกติอยู่แล้ว)
/// คลาสนี้เพิ่ม PointerDeviceKind.mouse เข้าไปในอุปกรณ์ที่อนุญาตให้ลาก
/// เพื่อให้ทุกหน้าที่มี list เลื่อนแนวนอน (เช่น Categories) ลากด้วยเมาส์ได้ด้วย
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class BudgetMateApp extends StatelessWidget {
  const BudgetMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DataService(),
      child: Consumer<DataService>(
        builder: (context, service, _) {
          AppColors.brightness = service.themeMode == ThemeMode.dark
              ? Brightness.dark : Brightness.light;
          return MaterialApp(
            title: 'BUDGETMATE',
            debugShowCheckedModeBanner: false,
            scrollBehavior: AppScrollBehavior(),
            themeMode: service.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.black,
              brightness: Brightness.light,
              fontFamily: appFontFamily,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              scaffoldBackgroundColor: Colors.white,
            ),
            darkTheme: AppTheme.dark,
            home: const LoadingScreen(),
          );
        },
      ),
    );
  }
}