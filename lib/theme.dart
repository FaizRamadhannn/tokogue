import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Palette mengikuti brand Sahaja Catering: marun, emas, krem.
class AppColors {
  // Brand
  static const primary = Color(0xFF9E1B1B);
  static const primaryDark = Color(0xFF6F1010);
  static const primarySoft = Color(0xFFF6E7E3);
  static const gold = Color(0xFFC9A04A);
  static const goldLight = Color(0xFFE6C77E);
  static const goldSoft = Color(0xFFF5ECD7);
  /// Latar kartu utama (absen, profil, cuti): marun gelap.
  static const hero = Color(0xFF5A1212);

  // Netral hangat
  static const ink = Color(0xFF241615);
  static const muted = Color(0xFF7A6A66);
  static const line = Color(0xFFEDE4D8);
  static const bg = Color(0xFFFAF6F0);

  // Status
  static const green = Color(0xFF2F8F57);
  static const greenSoft = Color(0xFFE5F3EA);
  static const red = Color(0xFFD93025);
  static const redSoft = Color(0xFFFCEBE9);
  static const orange = Color(0xFFD9822B);
  static const orangeSoft = Color(0xFFFBF0E1);
  static const blue = Color(0xFF3B6EA8);
  static const blueSoft = Color(0xFFEAF0F7);
  static const purple = Color(0xFF7A4A8C);
  static const purpleSoft = Color(0xFFF2EBF4);
  static const teal = Color(0xFF2E8079);
  static const tealSoft = Color(0xFFE5F1EF);
  static const pink = Color(0xFFB8456B);
  static const pinkSoft = Color(0xFFF8E9EE);
}

/// Durasi & kurva animasi yang dipakai di seluruh app.
class Motion {
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 480);
  static const curve = Curves.easeOutCubic;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: Colors.white,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const btnText = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: -0.1);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: InkSparkle.splashFactory,
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
    }),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.line,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shape: shape,
        textStyle: btnText,
        animationDuration: Motion.fast,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.line),
        shape: shape,
        textStyle: btnText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: btnText.copyWith(fontSize: 14)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.muted),
      prefixIconColor: AppColors.muted,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.ink,
      unselectedLabelColor: AppColors.muted,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      indicatorSize: TabBarIndicatorSize.label,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.primary, width: 3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
      ),
      dividerColor: AppColors.line,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.goldSoft,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(color: AppColors.ink, fontSize: 13),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(surfaceTintColor: Colors.transparent),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.muted),
  );
}
