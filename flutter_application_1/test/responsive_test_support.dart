import 'package:budgetmate/screens/app_theme.dart';
import 'package:flutter/material.dart';

// Keep the viewport tests aligned with BudgetMateApp's current themes.
ThemeData phoneTheme(Brightness brightness) => brightness == Brightness.dark
    ? AppTheme.dark
    : ThemeData(
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
              color: Colors.black),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.white,
      );
