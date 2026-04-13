import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  // 제목: Noto Serif KR (역사적 무게감)
  static TextStyle get heading1 => GoogleFonts.notoSerifKr(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get heading2 => GoogleFonts.notoSerifKr(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // 본문: Noto Sans KR (가독성)
  static TextStyle get body => GoogleFonts.notoSansKr(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.6,
      );

  static TextStyle get caption => GoogleFonts.notoSansKr(
        fontSize: 11,
        color: AppColors.textMuted,
      );

  // 데이터: Source Code Pro (정밀함)
  static TextStyle get mono => GoogleFonts.sourceCodePro(
        fontSize: 12,
        color: AppColors.textSecondary,
      );

  static TextStyle get badge => GoogleFonts.notoSansKr(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );
}
