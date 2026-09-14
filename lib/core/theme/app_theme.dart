import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ============================================================
  // PREMIUM RENTAL APP COLORS
  //
  // IMPORTANT:
  // These colors are FIXED.
  // Firebase tenant colors are NOT used here.
  // ============================================================

  static const Color primary =
      Color(0xFF0F766E);

  static const Color accent =
      Color(0xFF14B8A6);

  static const Color background =
      Color(0xFFF8FAF9);

  static const Color card =
      Color(0xFFFFFFFF);

  static const Color softAccent =
      Color(0xFFE6FFFB);

  static const Color heading =
      Color(0xFF17201F);

  static const Color body =
      Color(0xFF66706E);

  static const Color muted =
      Color(0xFF94A09D);

  static const Color border =
      Color(0xFFE5EBE9);

  // ============================================================
  // LIGHT THEME
  // ============================================================

  static ThemeData get light {
    final base =
        ThemeData.light();

    return base.copyWith(
      scaffoldBackgroundColor:
          background,

      colorScheme:
          const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: card,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: heading,
      ),

      textTheme:
          GoogleFonts.manropeTextTheme(
        base.textTheme,
      ).apply(
        bodyColor: body,
        displayColor: heading,
      ),

      appBarTheme:
          AppBarTheme(
        backgroundColor:
            background,

        foregroundColor:
            heading,

        elevation: 0,

        centerTitle: false,

        titleTextStyle:
            GoogleFonts.manrope(
          fontSize: 18,
          fontWeight:
              FontWeight.w800,
          color: heading,
        ),

        iconTheme:
            const IconThemeData(
          color: heading,
        ),
      ),

      elevatedButtonTheme:
          ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              primary,

          foregroundColor:
              Colors.white,

          elevation: 0,

          textStyle:
              GoogleFonts.manrope(
            fontSize: 14,
            fontWeight:
                FontWeight.w800,
          ),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(17),
          ),
        ),
      ),

      outlinedButtonTheme:
          OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              primary,

          textStyle:
              GoogleFonts.manrope(
            fontSize: 13,
            fontWeight:
                FontWeight.w800,
          ),

          side:
              const BorderSide(
            color: border,
          ),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15),
          ),
        ),
      ),

      inputDecorationTheme:
          InputDecorationTheme(
        filled: true,

        fillColor:
            background,

        hintStyle:
            GoogleFonts.manrope(
          color: muted,
          fontWeight:
              FontWeight.w500,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(17),

          borderSide:
              const BorderSide(
            color: border,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(17),

          borderSide:
              const BorderSide(
            color: border,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(17),

          borderSide:
              const BorderSide(
            color: primary,
            width: 1.4,
          ),
        ),
      ),

      snackBarTheme:
          SnackBarThemeData(
        backgroundColor:
            heading,

        contentTextStyle:
            GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 13,
          fontWeight:
              FontWeight.w600,
        ),

        behavior:
            SnackBarBehavior.floating,

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(16),
        ),
      ),
    );
  }

  // ============================================================
  // DARK THEME
  //
  // We keep this available because MaterialApp expects it,
  // but the customer app is currently forced to LIGHT mode.
  // ============================================================

  static ThemeData get dark {
    return light;
  }
}