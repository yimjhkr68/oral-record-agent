// 파일 목적: 앱 전체 테마 정의 (전문적/기업용 네이비+골드 스타일)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── 색상 팔레트 ──────────────────────────────────────────────
  static const Color primary = Color(0xFF1A2B5E);      // 네이비 (주색)
  static const Color primaryLight = Color(0xFF2D4A8A); // 밝은 네이비
  static const Color accent = Color(0xFFC9A84C);       // 골드 (강조색)
  static const Color accentLight = Color(0xFFE8C97A);  // 밝은 골드
  static const Color background = Color(0xFFF4F6FA);   // 배경
  static const Color surface = Color(0xFFFFFFFF);      // 카드/서피스
  static const Color error = Color(0xFFD32F2F);        // 오류
  static const Color textPrimary = Color(0xFF1A2035);  // 주 텍스트
  static const Color textSecondary = Color(0xFF546485); // 보조 텍스트
  static const Color textDisabled = Color(0xFF94A3B8);  // 비활성 텍스트
  static const Color border = Color(0xFFE0E4EF);        // 테두리
  static const Color divider = Color(0xFFECEFF6);       // 구분선
  static const Color cardShadow = Color(0x14000000);    // 카드 그림자

  // 의미적 색상 (파일 형식 배지 등)
  static const Color audioColor = Color(0xFF1A2B5E);  // 음성: 네이비
  static const Color videoColor = Color(0xFF7B1FA2);  // 영상: 보라
  static const Color docColor = Color(0xFFD32F2F);    // 문서: 빨강
  static const Color textFileColor = Color(0xFF546485); // 텍스트: 회색

  // ── 테마 ────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDDE3F4),
      onPrimaryContainer: primary,
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFF5EDD0),
      onSecondaryContainer: Color(0xFF5C3D00),
      error: error,
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: Color(0xFFEEF1F8),
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: divider,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF1A2035),
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFFB0C4FF),
    );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.notoSansKr(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        shape: const Border(
          bottom: BorderSide(color: accent, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB0BEC5),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          textStyle: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          side: const BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 6,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFC8CDD8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFC8CDD8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle: GoogleFonts.notoSansKr(
          color: textSecondary,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.notoSansKr(
          color: textDisabled,
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textDisabled,
        selectedLabelStyle: GoogleFonts.notoSansKr(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: GoogleFonts.notoSansKr(fontSize: 11),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: Color(0xFFDDE3F4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEEF1F8),
        labelStyle: GoogleFonts.notoSansKr(
          color: primary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: Color(0xFFB8C4E0)),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primary,
        contentTextStyle: GoogleFonts.notoSansKr(
          color: Colors.white,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: GoogleFonts.notoSansKr(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.notoSansKr(
          color: textPrimary,
          fontSize: 14,
          height: 1.6,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        titleTextStyle: GoogleFonts.notoSansKr(
          fontSize: 14,
          color: textPrimary,
        ),
        subtitleTextStyle: GoogleFonts.notoSansKr(
          fontSize: 12,
          color: textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.4);
          }
          return const Color(0xFFCDD0D8);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: Color(0xFFC8CDD8), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: GoogleFonts.notoSansKr(
        fontSize: 57, fontWeight: FontWeight.w400, color: textPrimary,
      ),
      displayMedium: GoogleFonts.notoSansKr(
        fontSize: 45, fontWeight: FontWeight.w400, color: textPrimary,
      ),
      displaySmall: GoogleFonts.notoSansKr(
        fontSize: 36, fontWeight: FontWeight.w400, color: textPrimary,
      ),
      headlineLarge: GoogleFonts.notoSansKr(
        fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary,
      ),
      headlineMedium: GoogleFonts.notoSansKr(
        fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary,
      ),
      headlineSmall: GoogleFonts.notoSansKr(
        fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary,
      ),
      titleLarge: GoogleFonts.notoSansKr(
        fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary,
        letterSpacing: -0.3,
      ),
      titleMedium: GoogleFonts.notoSansKr(
        fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary,
        letterSpacing: -0.2,
      ),
      titleSmall: GoogleFonts.notoSansKr(
        fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary,
      ),
      bodyLarge: GoogleFonts.notoSansKr(
        fontSize: 15, fontWeight: FontWeight.w400, color: textPrimary,
        height: 1.6,
      ),
      bodyMedium: GoogleFonts.notoSansKr(
        fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.notoSansKr(
        fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary,
      ),
      labelLarge: GoogleFonts.notoSansKr(
        fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary,
      ),
      labelMedium: GoogleFonts.notoSansKr(
        fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary,
      ),
      labelSmall: GoogleFonts.notoSansKr(
        fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}
