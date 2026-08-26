import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens buat seluruh app -- disamain PERSIS sama variabel CSS
/// (`:root{...}`) di css/style.css punya web dashboard ABWarehouse, biar
/// app Flutter & web-nya keliatan senada, bukan dua produk yang beda.
class AppColors {
  static const ink = Color(0xFF17213A);
  static const surface0 = Color(0xFFF4F7FB); // background utama
  static const surface1 = Color(0xFFFFFFFF); // card/permukaan
  static const border = Color(0xFFE5EBF4);
  static const muted = Color(0xFF71809A);
  static const primary = Color(0xFF3455DB);
  static const primarySoft = Color(0xFFEEF1FF);
  static const primaryDeep = Color(0xFF223BAE);
  static const success = Color(0xFF117B58);
  static const successSoft = Color(0xFFE9F8F2);
  static const danger = Color(0xFFD64157);
  static const dangerSoft = Color(0xFFFFF0F2);

  // Gradient biru gelap yang dipake background login di web (loginScreen)
  static const loginGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF101A42), Color(0xFF172766), Color(0xFF233E90)],
  );

  // Gradient buat tombol utama & icon aksen (btn-primary, .dc-icon gradient)
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3D61E9), Color(0xFF2945C9)],
  );
}

class AppRadius {
  static const sm = 10.0; // input, chip kecil
  static const md = 14.0; // card kecil, list item
  static const lg = 18.0; // card besar (produk-toolbar, dll)
  static const xl = 22.0; // modal, login card
  static const xxl = 26.0;
}

class AppShadow {
  // Nyamain kira-kira sama --shadow di CSS: soft, menyebar, gak tajem
  static List<BoxShadow> soft = [
    BoxShadow(
      color: const Color(0xFF1D3269).withOpacity(.08),
      blurRadius: 35,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: const Color(0xFF1D3269).withOpacity(.04),
      blurRadius: 5,
      offset: const Offset(0, 2),
    ),
  ];
}

/// Space Grotesk buat heading/brand (sama kaya h1, .login-brand span di web),
/// Inter buat body text (default font web), IBM Plex Mono buat angka
/// (qty, dll -- kalau nanti dibutuhin).
class AppText {
  static TextStyle heading({double size = 22, Color? color, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.spaceGrotesk(fontWeight: w, fontSize: size, letterSpacing: -0.5, color: color ?? AppColors.ink);

  static TextStyle body({double size = 14, FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.inter(fontWeight: weight, fontSize: size, color: color ?? AppColors.ink);

  static TextStyle mono({double size = 16, FontWeight weight = FontWeight.w600, Color? color}) =>
      GoogleFonts.ibmPlexMono(fontWeight: weight, fontSize: size, color: color ?? AppColors.primary);
}

/// ThemeData global -- dipasang sekali di MaterialApp (main.dart), jadi
/// semua Scaffold/AppBar/Button di app otomatis kepake tanpa perlu di-style
/// manual satu-satu di tiap halaman.
ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.surface0,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.primaryDeep,
      error: AppColors.danger,
      surface: AppColors.surface1,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface1,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppText.heading(size: 18),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm + 1),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm + 1),
        borderSide: const BorderSide(color: Color(0xFFDCE4F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm + 1),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      labelStyle: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        textStyle: AppText.body(size: 14.5, weight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm + 1)),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface1,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
  );
}
