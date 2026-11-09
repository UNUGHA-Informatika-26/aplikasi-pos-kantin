import 'package:flutter/material.dart';

const green = Color(0xFF237A57);

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme:
      ColorScheme.fromSeed(seedColor: green, surface: const Color(0xFFF7F8F5)),
  scaffoldBackgroundColor: const Color(0xFFF7F8F5),
  appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF7F8F5), foregroundColor: Color(0xFF173B2C)),
  inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
  cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
);
