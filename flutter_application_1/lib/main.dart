import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/data_service.dart';
import 'screens/loading_screen.dart';

void main() {
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
          return MaterialApp(
            title: 'BUDGETMATE',
            debugShowCheckedModeBanner: false,
            scrollBehavior: AppScrollBehavior(),
            themeMode: service.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.black,
              brightness: Brightness.light,
              fontFamily: 'Roboto',
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              scaffoldBackgroundColor: Colors.white,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color.fromARGB(255, 253, 253, 252),
              brightness: Brightness.dark,
              fontFamily: 'Roboto',
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF121212),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              scaffoldBackgroundColor: const Color(0xFF121212),
            ),
            home: const LoadingScreen(),
          );
        },
      ),
    );
  }
}