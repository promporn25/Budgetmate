import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/data_service.dart';
import 'screens/loading_screen.dart';

void main() {
  runApp(const BudgetMateApp());
}

class BudgetMateApp extends StatelessWidget {
  const BudgetMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DataService(),
      child: MaterialApp(
        title: 'BUDGETMATE',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.black,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
          scaffoldBackgroundColor: Colors.white,
        ),
        home: const LoadingScreen(),
      ),
    );
  }
}
