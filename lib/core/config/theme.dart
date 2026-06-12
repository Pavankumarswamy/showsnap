import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Seat colours ─────────────────────────────────────────────────────────────

class SeatColors {
  static const Color silver = Color(0xFFFFFFFF);
  static const Color gold = Color(0xFFFFD54F);
  static const Color platinum = Color(0xFF90CAF9);

  static const Color available = Color(0xFFFFFFFF);
  static const Color selected = ShowSnapColors.primary;
  static const Color booked = Color(0xFF9E9E9E);
  static const Color accessible = Color(0xFF1565C0);
  static const Color availableBorder = Color(0xFFBDBDBD);
}

// ─── Palette ──────────────────────────────────────────────────────────────────

class ShowSnapColors {
  static const Color primary = Color(0xFF939450);
  static const Color primaryLight = Color(0xFFA7A864);
  static const Color primaryLighter = Color(0xFFBBBC78);
  static const Color secondary = Color(0xFF4A4B28);
  static const Color background = Color(0xFF121314);
  static const Color surface = Color(0xFF1E2124);
  static const Color error = Color(0xFFD32F2F);
  static const Color onPrimary = Color(0xFF000000);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color grey100 = Color(0xFF1C1E20);
  static const Color grey300 = Color(0xFF2D3135);
  static const Color grey600 = Color(0xFF9AA0A6);
}

// ─── V2 Design Tokens ─────────────────────────────────────────────────────────

class ShowSnapRadius {
  static const double xs = 12.0;
  static const double sm = 16.0;
  static const double md = 25.0; // PRIMARY — use everywhere
  static const double lg = 32.0;
  static const double xl = 40.0;
  static const double pill = 100.0; // fully rounded buttons/chips
}

class ShowSnapShadow {
  static List<BoxShadow> get card => [
        BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8)),
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2)),
      ];

  static List<BoxShadow> get elevated => [
        BoxShadow(
            color: const Color(0xFFF5A800).withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8)),
      ];

  static List<BoxShadow> get none => [];
}

class ShowSnapDuration {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 550);
  static const Duration xslow = Duration(milliseconds: 800);
  static const Duration page = Duration(milliseconds: 450);
}

// ─── Theme ────────────────────────────────────────────────────────────────────

class ShowSnapTheme {
  static ThemeData get lightTheme => _build();
  static ThemeData get light => _build(); // backwards-compat alias

  static ThemeData _build() {
    final base = ThemeData.dark(useMaterial3: false);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: ShowSnapColors.primary,
        secondary: ShowSnapColors.secondary,
        surface: ShowSnapColors.surface,
        error: ShowSnapColors.error,
        onPrimary: ShowSnapColors.onPrimary,
        onSecondary: ShowSnapColors.onSecondary,
        onSurface: ShowSnapColors.onSurface,
      ),
      scaffoldBackgroundColor: ShowSnapColors.background,
      cardColor: ShowSnapColors.surface,
      dialogBackgroundColor: ShowSnapColors.surface,
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ShowSnapColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(ShowSnapRadius.md),
          ),
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ShowSnapColors.primary,
          foregroundColor: ShowSnapColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ShowSnapColors.primary,
          side: const BorderSide(color: ShowSnapColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          ),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ShowSnapColors.primary,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: ShowSnapColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        ),
        margin: const EdgeInsets.all(4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: ShowSnapColors.grey300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: ShowSnapColors.grey300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide:
              const BorderSide(color: ShowSnapColors.primary, width: 2),
        ),
        filled: true,
        fillColor: ShowSnapColors.grey100,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: ShowSnapColors.grey600),
        hintStyle: const TextStyle(color: ShowSnapColors.grey600),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ShowSnapColors.grey100,
        selectedColor: ShowSnapColors.primaryLighter,
        secondarySelectedColor: ShowSnapColors.primaryLighter,
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
        secondaryLabelStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: ShowSnapColors.surface,
        selectedItemColor: ShowSnapColors.primary,
        unselectedItemColor: ShowSnapColors.grey600,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ShowSnapColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: ShowSnapColors.grey300,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ShowSnapColors.primary,
      ),
    );
  }

  static LinearGradient get appBarGradient => const LinearGradient(
        colors: [ShowSnapColors.primary, ShowSnapColors.primaryLight],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  static LinearGradient get heroGradient => const LinearGradient(
        colors: [ShowSnapColors.primaryLighter, ShowSnapColors.primary],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  static LinearGradient get splashGradient => const LinearGradient(
        colors: [ShowSnapColors.primary, ShowSnapColors.secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static BoxDecoration get primaryButtonDecoration => BoxDecoration(
        gradient: const LinearGradient(
          colors: [ShowSnapColors.primary, ShowSnapColors.primaryLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.elevated,
      );
}
