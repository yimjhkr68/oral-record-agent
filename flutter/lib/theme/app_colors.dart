import 'package:flutter/material.dart';

class AppColors {
  // ── 베이스 ──────────────────────────────────────
  static const background      = Color(0xFFF5F6FA);  // 최심 배경 (연회색)
  static const surface         = Color(0xFFFFFFFF);  // 카드 배경 (흰색)
  static const surfaceElevated = Color(0xFFF0F2F8);  // 올라온 카드
  static const surfaceHover    = Color(0xFFE8EBF5);  // 호버 상태
  static const border          = Color(0xFFDDE1F0);  // 구분선
  static const borderLight     = Color(0xFFEEF0F8);  // 밝은 구분선

  // ── 주 강조색 (앰버 — 역사·기록의 따뜻함) ──────
  static const primary         = Color(0xFFF59E0B);  // 기본 강조
  static const primaryDim      = Color(0xFFD97706);  // 어두운 강조
  static const primaryFaint    = Color(0x1AF59E0B);  // 배경용 희미한 강조

  // ── 보조 강조색 (청록 — 데이터·연결) ────────────
  static const secondary       = Color(0xFF0D9488);  // 보조 강조
  static const secondaryDim    = Color(0xFF0F766E);  // 어두운 보조
  static const secondaryFaint  = Color(0x1A14B8A6);  // 배경용

  // ── 텍스트 ──────────────────────────────────────
  static const textPrimary     = Color(0xFF1A1F2E);  // 주 텍스트
  static const textSecondary   = Color(0xFF4B5563);  // 보조 텍스트
  static const textMuted       = Color(0xFF9CA3AF);  // 흐린 텍스트
  static const textAccent      = Color(0xFFD97706);  // 강조 텍스트

  // ── 상태 색상 ────────────────────────────────────
  static const success         = Color(0xFF059669);
  static const warning         = Color(0xFFF59E0B);
  static const error           = Color(0xFFDC2626);
  static const info            = Color(0xFF2563EB);

  // ── 상태 배지 ────────────────────────────────────
  static const draft           = Color(0xFFD97706);  // Draft = 앰버
  static const confirmed       = Color(0xFF059669);  // Confirmed = 초록
  static const archived        = Color(0xFF6B7280);  // Archived = 회색
}
