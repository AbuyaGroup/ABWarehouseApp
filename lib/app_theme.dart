import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design token dari folder "New Design Scanner" (light theme).
/// Nama field ngikutin nama token di tailwind config design-nya.
class AppColors {
  // Primary (biru navy)
  static const primary = Color(0xFF1B2A5C);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF2E4A9E);
  static const onPrimaryContainer = Color(0xFFE3E9FF);

  // Secondary (hijau sukses)
  static const secondary = Color(0xFF006D30);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFF92F5A4);
  static const onSecondaryContainer = Color(0xFF007233);

  // Error
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Surface
  static const surface = Color(0xFFF3F5F9);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFEBEFF5);
  static const surfaceContainer = Color(0xFFE4E9F1);
  static const surfaceContainerHigh = Color(0xFFDDE3EC);
  static const surfaceContainerHighest = Color(0xFFD6DDE8);
  static const onSurface = Color(0xFF1A1F2E);
  static const onSurfaceVariant = Color(0xFF4A5468);
  static const outline = Color(0xFF7A8499);
  static const outlineVariant = Color(0xFFC9D1DE);

  // Dark surface (dipake di layar kamera)
  static const darkSurface = Color(0xFF10141F);
  static const darkSurfaceContainerLow = Color(0xFF1A1F2E);
  static const darkOnSurface = Color(0xFFE2E7F0);

  // Alias lama biar kode lain gak patah
  static const ink = onSurface;
  static const muted = onSurfaceVariant;
  static const border = outlineVariant;
  static const danger = error;
  static const dangerSoft = errorContainer;
  static const success = secondary;
  static const successSoft = secondaryContainer;
}

class AppRadius {
  static const sm = 4.0;
  static const base = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppShadow {
  static List<BoxShadow> sm = [
    BoxShadow(
      color: const Color(0xFF1A1F2E).withValues(alpha: .06),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF1A1F2E).withValues(alpha: .04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> lg = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: .18),
      blurRadius: 24,
      offset: const Offset(0, -6),
    ),
  ];
}

/// Typography token: Chivo (display/headline), Outfit (title/body/label),
/// JetBrains Mono (kode/angka).
class AppText {
  static TextStyle displayMobile({Color? color}) => GoogleFonts.chivo(
    fontSize: 28,
    height: 34 / 28,
    letterSpacing: -0.25,
    fontWeight: FontWeight.w700,
    color: color ?? AppColors.onSurface,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle headlineLg({Color? color}) => GoogleFonts.chivo(
    fontSize: 24,
    height: 30 / 24,
    letterSpacing: -0.25,
    fontWeight: FontWeight.w700,
    color: color ?? AppColors.onSurface,
  );

  static TextStyle headlineMd({Color? color}) => GoogleFonts.chivo(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    color: color ?? AppColors.onSurface,
  );

  static TextStyle titleMd({Color? color}) => GoogleFonts.outfit(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.onSurface,
  );

  static TextStyle bodyMd({Color? color}) => GoogleFonts.outfit(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: color ?? AppColors.onSurface,
  );

  static TextStyle bodySm({Color? color}) => GoogleFonts.outfit(
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w400,
    color: color ?? AppColors.onSurfaceVariant,
  );

  static TextStyle labelLg({Color? color}) => GoogleFonts.outfit(
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.onSurface,
  );

  static TextStyle labelSm({Color? color}) => GoogleFonts.outfit(
    fontSize: 11,
    height: 16 / 11,
    letterSpacing: 0.4,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.onSurfaceVariant,
  );

  static TextStyle monoMd({Color? color}) => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.onSurface,
  );

  static TextStyle monoSm({Color? color}) => GoogleFonts.jetBrainsMono(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: color ?? AppColors.onSurfaceVariant,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Format tanggal Indonesia tanpa perlu package intl.
class AppDate {
  static const _bulan = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static DateTime? parse(dynamic raw) =>
      raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();

  static String tanggal(DateTime d) =>
      '${d.day} ${_bulan[d.month - 1]} ${d.year}';

  static String jam(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true);
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.outlineVariant),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.surface,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      error: AppColors.error,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
    ),
    // GoogleFonts.outfitTextTheme() balikin TextTheme versi flutter/material,
    // beda tipe sama material_ui -- jadi cukup set fontFamily-nya aja.
    textTheme: base.textTheme.apply(
      fontFamily: GoogleFonts.outfit().fontFamily,
      bodyColor: AppColors.onSurface,
      displayColor: AppColors.onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.onSurface,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppText.titleMd(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainerLowest,
      constraints: const BoxConstraints(minHeight: 48),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: AppText.monoMd(color: AppColors.outline),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: AppText.labelLg(color: AppColors.onSurfaceVariant),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        textStyle: AppText.labelLg(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.onSurfaceVariant,
        textStyle: AppText.labelLg(),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      titleTextStyle: AppText.headlineMd(),
      contentTextStyle: AppText.bodyMd(color: AppColors.onSurfaceVariant),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2A3142),
      contentTextStyle: AppText.bodyMd(color: const Color(0xFFEEF1F7)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
  );
}
