import 'package:budgetmate/firebase_options.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/data_service.dart';
import 'screens/loading_screen.dart';
import 'screens/app_theme.dart' show appFontFamily, AppColors, AppTheme;
import 'widgets/responsive_scale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // เตรียมข้อมูล locale ภาษาไทยสำหรับ DateFormat (เช่น ชื่อเดือน/วันภาษาไทย)
  // ต้องเรียกก่อน runApp ไม่งั้นจะเจอ LocaleDataException ตอนใช้ DateFormat(..., 'th')
  await initializeDateFormatting('th', null);

  runApp(const BudgetMateApp());
}

/// อนุญาตให้ลากด้วยเมาส์/ทัชแพด/ปากกา เพื่อเลื่อน list ได้ (Web/Desktop)
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
              ? Brightness.dark
              : Brightness.light;
          return MaterialApp(
            title: 'BUDGETMATE',
            debugShowCheckedModeBanner: false,
            scrollBehavior: AppScrollBehavior(),
            themeMode: service.themeMode,
            // ปรับขนาดทุกหน้าให้พอดีกับความกว้างจอจริง
            builder: (context, child) => ResponsiveScale(child: child!),
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.black,
              brightness: Brightness.light,
              fontFamily: appFontFamily,
              appBarTheme: const AppBarTheme(
                toolbarHeight: 56,
                titleTextStyle: TextStyle(
                  fontFamily: appFontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
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