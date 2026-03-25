import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  static const Color primary = Color(0xFF2A3763);
  static const Color secondary = Color(0xFFC53D57);
  static const Color accent = Color(0xFFD0B26F);
  static const Color canvas = Color(0xFFF3F6FB);
  static const Color textDark = Color(0xFF1A2140);
  static const Color muted = Color(0xFF6C748F);
  static const Color success = Color(0xFF19B66A);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppPalette.primary,
        primary: AppPalette.primary,
        secondary: AppPalette.secondary,
        surface: Colors.white,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppPalette.canvas,
      textTheme: GoogleFonts.redHatDisplayTextTheme(base.textTheme)
          .apply(
            bodyColor: AppPalette.textDark,
            displayColor: AppPalette.textDark,
          )
          .copyWith(
            bodyLarge: GoogleFonts.manrope(
              fontSize: 16,
              height: 1.45,
              color: AppPalette.textDark,
            ),
            bodyMedium: GoogleFonts.manrope(
              fontSize: 14,
              height: 1.4,
              color: AppPalette.textDark,
            ),
          ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppPalette.primary,
        titleTextStyle: GoogleFonts.redHatDisplay(
          color: AppPalette.primary,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: GoogleFonts.manrope(
          color: AppPalette.muted,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: GoogleFonts.manrope(
          color: AppPalette.primary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: GoogleFonts.manrope(
          color: AppPalette.muted.withValues(alpha: 0.85),
        ),
        prefixIconColor: AppPalette.muted,
        suffixIconColor: AppPalette.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppPalette.primary.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppPalette.primary.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppPalette.primary,
        selectionColor: AppPalette.primary.withValues(alpha: 0.22),
        selectionHandleColor: AppPalette.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppPalette.primary.withValues(alpha: 0.12),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _SmoothPageTransitionsBuilder(),
          TargetPlatform.iOS: _SmoothPageTransitionsBuilder(),
          TargetPlatform.linux: _SmoothPageTransitionsBuilder(),
          TargetPlatform.macOS: _SmoothPageTransitionsBuilder(),
          TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _SmoothPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class _SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> fade = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final Animation<Offset> slide = Tween<Offset>(
      begin: const Offset(0.03, 0),
      end: Offset.zero,
    ).animate(fade);

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: child,
      ),
    );
  }
}
