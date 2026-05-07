import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  // Primary — vivid indigo / violet (game-like)
  static const primary = Color(0xFF7C5CFF);
  static const primaryStrong = Color(0xFF5B3DDB);
  static const primaryContainer = Color(0xFF2A1F5C);

  // Streak / energy
  static const streak = Color(0xFFFF8A2B);   // warm orange
  static const streakSoft = Color(0x33FF8A2B);

  // Success / completed
  static const success = Color(0xFF4ADE80);   // lime green
  static const successSoft = Color(0x334ADE80);

  // Warn / partial / wrong
  static const warn = Color(0xFFFACC15);     // amber
  static const warnSoft = Color(0x33FACC15);
  static const danger = Color(0xFFF472B6);   // hot pink
  static const dangerSoft = Color(0x33F472B6);

  // Backgrounds (warm dark — not pure black)
  static const bg = Color(0xFF15132B);
  static const surface = Color(0xFF1F1B3F);
  static const surfaceHigh = Color(0xFF2B2655);

  // Text
  static const textHigh = Color(0xFFF8FAFC);
  static const textMid = Color(0xFFC7C9D9);
  static const textLow = Color(0xFF8B8DAA);

  // Per-category accents — slight hue shifts on top of the base violet theme.
  // Saturation kept moderate so categories feel related, not jarring.
  static const Map<String, Color> categoryAccents = {
    'stories-for-kids':      Color(0xFFFED7AA),  // soft peach — kid-friendly
    'short-stories':         Color(0xFFFFB76B),  // warm amber — bedtime story
    'english-conversations': Color(0xFF67E8F9),  // breezy cyan — chat
    'english-pronunciation': Color(0xFFDDD6FE),  // lilac — tongue / phonics
    'ted-ed':                Color(0xFFFDE68A),  // soft gold — ideas / TED light
    'news':                  Color(0xFFA5B4FC),  // light indigo — trust / news
    'toeic':                 Color(0xFF7DD3FC),  // sky blue — exam confidence
    'youtube':               Color(0xFFF87171),  // soft red — video brand cue
    'ielts-listening':       Color(0xFFA78BFA),  // soft violet — premium
    'toefl-listening':       Color(0xFF86EFAC),  // mint — academic calm
    'medical-english-oet':   Color(0xFFBBF7D0),  // pale green — clinical
    'spelling-names':        Color(0xFFF9A8D4),  // pink — friendly
    'numbers':               Color(0xFFFCD34D),  // yellow — energetic
  };

  static Color categoryAccent(String slug) =>
      categoryAccents[slug] ?? primary;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.primary,
    onPrimary: Colors.white,
    primaryContainer: AppPalette.primaryContainer,
    onPrimaryContainer: AppPalette.textHigh,
    secondary: AppPalette.streak,
    onSecondary: Colors.black,
    secondaryContainer: AppPalette.streakSoft,
    onSecondaryContainer: AppPalette.textHigh,
    tertiary: AppPalette.success,
    onTertiary: Colors.black,
    tertiaryContainer: AppPalette.successSoft,
    onTertiaryContainer: AppPalette.textHigh,
    error: AppPalette.danger,
    onError: Colors.black,
    surface: AppPalette.surface,
    onSurface: AppPalette.textHigh,
    onSurfaceVariant: AppPalette.textMid,
    surfaceContainerHighest: AppPalette.surfaceHigh,
    outline: AppPalette.textLow,
    outlineVariant: const Color(0xFF3A356B),
  );

  final base = TextTheme(
    displayLarge: GoogleFonts.lexend(fontWeight: FontWeight.w800),
    displayMedium: GoogleFonts.lexend(fontWeight: FontWeight.w800),
    displaySmall: GoogleFonts.lexend(fontWeight: FontWeight.w700),
    headlineLarge: GoogleFonts.lexend(fontWeight: FontWeight.w700),
    headlineMedium: GoogleFonts.lexend(fontWeight: FontWeight.w700),
    headlineSmall: GoogleFonts.lexend(fontWeight: FontWeight.w700),
    titleLarge: GoogleFonts.lexend(fontWeight: FontWeight.w700),
    titleMedium: GoogleFonts.lexend(fontWeight: FontWeight.w600),
    titleSmall: GoogleFonts.lexend(fontWeight: FontWeight.w600),
    bodyLarge: GoogleFonts.notoSansKr(fontWeight: FontWeight.w400),
    bodyMedium: GoogleFonts.notoSansKr(fontWeight: FontWeight.w400),
    bodySmall: GoogleFonts.notoSansKr(fontWeight: FontWeight.w400),
    labelLarge: GoogleFonts.lexend(fontWeight: FontWeight.w600),
    labelMedium: GoogleFonts.lexend(fontWeight: FontWeight.w600),
    labelSmall: GoogleFonts.lexend(fontWeight: FontWeight.w600),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppPalette.bg,
    textTheme: base.apply(
      bodyColor: AppPalette.textHigh,
      displayColor: AppPalette.textHigh,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppPalette.bg,
      foregroundColor: AppPalette.textHigh,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.lexend(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: AppPalette.textHigh,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: GoogleFonts.lexend(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.textHigh,
        side: BorderSide(color: AppPalette.primary.withValues(alpha: 0.5), width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: GoogleFonts.lexend(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppPalette.primary,
        textStyle: GoogleFonts.lexend(fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppPalette.textHigh,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppPalette.surfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppPalette.primary, width: 2),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppPalette.primary,
      linearTrackColor: Color(0xFF2B2655),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.lexend(fontWeight: FontWeight.w600),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppPalette.primary;
          }
          return AppPalette.surfaceHigh;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppPalette.textMid;
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppPalette.surfaceHigh,
      contentTextStyle: GoogleFonts.lexend(color: AppPalette.textHigh),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppPalette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dividerColor: const Color(0xFF3A356B),
  );
}
