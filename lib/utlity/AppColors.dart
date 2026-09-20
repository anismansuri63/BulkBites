
// Theme color class
import 'package:flutter/material.dart';

class AppColors {

  // static const Color primary = Color(0xFF01579B); // Vibrant purple
  // static const Color primary2 = Color(0xFF0288D1); // Darker purple
  // static const Color secondary = Color(0xFF4FC3F7); // Teal accent
  static const Color primary = Color(0xFFB71C1C); // Vibrant purple
  static const Color primary2 = Color(0xFFD32F2F); // Darker purple
  static const Color secondary = Color(0xFFFF8A65); // Teal accent
  static const Color textColor = Color(0xFF2D2D2D); // Dark gray
  static const Color backgroundColor = Color(0xFFF8F9FA); // Light gray
  static const Color cardColor = Color(0xFFFFFFFF); // White
  static const Color success = Color(0xFF0A5E2A); // Green
  static const Color error = Color(0xFFF44336); // Red
}

class AppTheme {
  final String themeName;
  final Color primary;
  final Color primary2;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color cardBorder;
  final Color textBlack;
  final Color textWhite;
  final Color grey = Colors.grey;

  const AppTheme({
    required this.themeName,
    required this.primary,
    required this.primary2,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.cardBorder,
    this.textBlack = Colors.black,
    this.textWhite = Colors.white,
  });
}
const List<AppTheme> appThemes = [
  // Your original 10 themes
  AppTheme(
    themeName: "Forest Green",
    primary: Color(0xFF0A5E2A),
    primary2: Color(0xFF1B7942),
    secondary: Color(0xFFD4A017),
    accent: Color(0xFFF8F5F0),
    background: Color(0xFFE8E3D7),
    cardBorder: Color(0xFFD4A017),
  ),
  AppTheme(
    themeName: "Blossom Pink",
    primary: Color(0xFFAD1457),
    primary2: Color(0xFFD81B60),
    secondary: Color(0xFFF48FB1),
    accent: Color(0xFFFFF0F5),
    background: Color(0xFFFFE4EC),
    cardBorder: Color(0xFFF06292),
  ),
  AppTheme(
    themeName: "Ocean Blue",
    primary: Color(0xFF01579B),
    primary2: Color(0xFF0288D1),
    secondary: Color(0xFF4FC3F7),
    accent: Color(0xFFE1F5FE),
    background: Color(0xFFF0F8FF),
    cardBorder: Color(0xFF03A9F4),
  ),
  AppTheme(
    themeName: "Desert Sun",
    primary: Color(0xFF6D4C41),
    primary2: Color(0xFF8D6E63),
    secondary: Color(0xFFF9A825),
    accent: Color(0xFFFFF8E1),
    background: Color(0xFFFFF3E0),
    cardBorder: Color(0xFFFFB300),
  ),
  AppTheme(
    themeName: "Glacier",
    primary: Color(0xFF37474F),
    primary2: Color(0xFF607D8B),
    secondary: Color(0xFFB0BEC5),
    accent: Color(0xFFECEFF1),
    background: Color(0xFFFAFAFA),
    cardBorder: Color(0xFF90A4AE),
  ),
  AppTheme(
    themeName: "Mint Fresh",
    primary: Color(0xFF004D40),
    primary2: Color(0xFF00796B),
    secondary: Color(0xFF4DB6AC),
    accent: Color(0xFFE0F2F1),
    background: Color(0xFFF1F8E9),
    cardBorder: Color(0xFF80CBC4),
  ),
  AppTheme(
    themeName: "Retro Pop",
    primary: Color(0xFF3F51B5),
    primary2: Color(0xFF5C6BC0),
    secondary: Color(0xFFFF4081),
    accent: Color(0xFFFFF9C4),
    background: Color(0xFFFFFDE7),
    cardBorder: Color(0xFFFFC107),
  ),
  AppTheme(
    themeName: "Crimson Fire",
    primary: Color(0xFFB71C1C),
    primary2: Color(0xFFD32F2F),
    secondary: Color(0xFFFF8A65),
    accent: Color(0xFFFFEBEE),
    background: Color(0xFFFFE5E5),
    cardBorder: Color(0xFFE57373),
  ),
  AppTheme(
    themeName: "Earth & Clay",
    primary: Color(0xFF5D4037),
    primary2: Color(0xFF8D6E63),
    secondary: Color(0xFFD7CCC8),
    accent: Color(0xFFFFF8F6),
    background: Color(0xFFF5F5F5),
    cardBorder: Color(0xFFBCAAA4),
  ),
  AppTheme(
    themeName: "Pastel Candy",
    primary: Color(0xFFCE93D8),
    primary2: Color(0xFFBA68C8),
    secondary: Color(0xFFFFAB91),
    accent: Color(0xFFFFF3F0),
    background: Color(0xFFFFF8E1),
    cardBorder: Color(0xFFE1BEE7),
  ),

  // My suggested 10 additional themes
  AppTheme(
    themeName: "Classic Olive",
    primary: Color(0xFF556B2F),
    primary2: Color(0xFF6B8E23),
    secondary: Color(0xFFB8860B),
    accent: Color(0xFFF5F5DC),
    background: Color(0xFFF8F8F0),
    cardBorder: Color(0xFFD2B48C),
  ),
  AppTheme(
    themeName: "Royal Islamic",
    primary: Color(0xFF1E3A8A),
    primary2: Color(0xFF3B82F6),
    secondary: Color(0xFFF59E0B),
    accent: Color(0xFFFEF3C7),
    background: Color(0xFFEFF6FF),
    cardBorder: Color(0xFFBFDBFE),
  ),
  AppTheme(
    themeName: "Ottoman Crimson",
    primary: Color(0xFF800020),
    primary2: Color(0xFF9D2933),
    secondary: Color(0xFFD4AF37),
    accent: Color(0xFFFFF8E1),
    background: Color(0xFFF9F2E7),
    cardBorder: Color(0xFFC19A6B),
  ),
  AppTheme(
    themeName: "Oceanic Serenity",
    primary: Color(0xFF005F73),
    primary2: Color(0xFF0A9396),
    secondary: Color(0xFFE9C46A),
    accent: Color(0xFFE9F5F9),
    background: Color(0xFFF0F9FB),
    cardBorder: Color(0xFFA8DADC),
  ),
  AppTheme(
    themeName: "Golden Sand",
    primary: Color(0xFFA67C52),
    primary2: Color(0xFFC2A476),
    secondary: Color(0xFF996515),
    accent: Color(0xFFFFFCF0),
    background: Color(0xFFFDF5E6),
    cardBorder: Color(0xFFE6D5B8),
  ),
  AppTheme(
    themeName: "Andalusian",
    primary: Color(0xFF5D4037),
    primary2: Color(0xFF8D6E63),
    secondary: Color(0xFFAF7A2A),
    accent: Color(0xFFEFEBE9),
    background: Color(0xFFF5EFE6),
    cardBorder: Color(0xFFBCAAA4),
  ),
  AppTheme(
    themeName: "Fresh Mint",
    primary: Color(0xFF2D7D46),
    primary2: Color(0xFF38A169),
    secondary: Color(0xFFD69E2E),
    accent: Color(0xFFF0FFF4),
    background: Color(0xFFF8FFFA),
    cardBorder: Color(0xFF9AE6B4),
  ),
  AppTheme(
    themeName: "Cool Breeze",
    primary: Color(0xFF4A5568),
    primary2: Color(0xFF718096),
    secondary: Color(0xFFB7793F),
    accent: Color(0xFFF7FAFC),
    background: Color(0xFFEDF2F7),
    cardBorder: Color(0xFFCBD5E0),
  ),
  AppTheme(
    themeName: "Vibrant Jewel",
    primary: Color(0xFF2C5282),
    primary2: Color(0xFF4299E1),
    secondary: Color(0xFFB83227),
    accent: Color(0xFFEBF8FF),
    background: Color(0xFFF0F9FF),
    cardBorder: Color(0xFF90CDF4),
  ),
  AppTheme(
    themeName: "Desert Mirage",
    primary: Color(0xFFB38B6D),
    primary2: Color(0xFFD4A373),
    secondary: Color(0xFF8B4513),
    accent: Color(0xFFFAF8F1),
    background: Color(0xFFF5EDE0),
    cardBorder: Color(0xFFE7D5B9),
  ),
  AppTheme(
    themeName: "Aqua",
    primary: Color(0xFF54A7BC),
    primary2: Color(0xCC54A7BC),
    secondary: Color(0xFFF5CB5C),
    accent: Color(0xFFE8F4F8),        // Very pale blue (lightest variation of primary)
    background: Color(0xFFF5F9FA),    // Ice white with subtle blue undertone
    cardBorder: Color(0xFFB8D8E6),
  )
];

