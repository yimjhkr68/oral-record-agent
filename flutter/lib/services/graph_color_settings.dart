import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 클래스별 기본 색상 — 구술기록 도메인 의미 기반
const Map<String, Color> kDefaultClassColors = {
  // ── 구술자 (진파랑 — 핵심 주체) ─────────────────
  'Narrator':                Color(0xFF1565C0),
  'OralNarrator':            Color(0xFF1565C0),
  'OralHistoryNarrator':     Color(0xFF1565C0),

  // ── 면담자/보조 인물 (연파랑) ────────────────────
  'Interviewer':             Color(0xFF42A5F5),

  // ── 일반 인물 (주황) ─────────────────────────────
  'Person':                  Color(0xFFEF6C00),

  // ── 피해자/생존자 (붉은 계열) ────────────────────
  'Victim':                  Color(0xFFC62828),
  'Survivor':                Color(0xFFE53935),
  'SurvivorFamily':          Color(0xFFEF9A9A),
  'Witness':                 Color(0xFFFF7043),

  // ── 가해자/군경 (어두운 회청) ────────────────────
  'MilitaryUnit':            Color(0xFF37474F),
  'HistoricalActor':         Color(0xFF546E7A),
  'Perpetrator':             Color(0xFF4527A0),

  // ── 사건 계열 (자주/보라) ────────────────────────
  'HistoricalEvent':         Color(0xFF880E4F),
  'HistoricalMassacreEvent': Color(0xFF4A148C),
  'ArrestEvent':             Color(0xFF6A1B9A),
  'TraumaticEvent':          Color(0xFFAD1457),
  'ColonialViolence':        Color(0xFFB71C1C),
  'Event':                   Color(0xFF8D6E63),

  // ── 장소 계열 (초록) ─────────────────────────────
  'Place':                   Color(0xFF2E7D32),
  'Location':                Color(0xFF388E3C),
  'AdministrativeRegion':    Color(0xFF66BB6A),
  'PrisonCamp':              Color(0xFF1B5E20),
  'BodyOfWater':             Color(0xFF0097A7),

  // ── 시간 계열 (보라) ─────────────────────────────
  'Time':                    Color(0xFF6A1B9A),
  'Date':                    Color(0xFF7B1FA2),
  'HistoricalPeriod':        Color(0xFF8E24AA),

  // ── 구술 기록물 (청록) ───────────────────────────
  'OralHistoryRecord':       Color(0xFF00695C),
  'NarrativeSession':        Color(0xFF00796B),
  'Collection':              Color(0xFF009688),
  'Document':                Color(0xFF26A69A),

  // ── 심리/감정 (핑크) ─────────────────────────────
  'Emotion':                 Color(0xFFD81B60),
  'TraumaticExperience':     Color(0xFFAD1457),
  'Trauma':                  Color(0xFFAD1457),
  'PersonalExperience':      Color(0xFFF06292),
  'CognitiveConcept':        Color(0xFFEC407A),

  // ── 기관/조직 (파랑) ─────────────────────────────
  'Organization':            Color(0xFF1976D2),
  'Community':               Color(0xFF0288D1),
  'FamilyGroup':             Color(0xFF388E3C),

  // ── 사물/문서 (갈색) ─────────────────────────────
  'Object':                  Color(0xFF795548),
  'LiteraryWork':            Color(0xFF6D4C41),

  // ── 주제/개념/정책 (회색 계열) ───────────────────
  'Topic':                   Color(0xFF616161),
  'Policy':                  Color(0xFF455A64),

  // ── 기타 ─────────────────────────────────────────
  'HumanDamage':             Color(0xFFB71C1C),
  'Comment':                 Color(0xFF9E9E9E),
};

/// 그래프 클래스 색상 — SharedPreferences 영속 + 런타임 캐시
class GraphColorSettings {
  GraphColorSettings._();

  static const String _prefix = 'graph_color_';
  static final Map<String, Color> _cache = {};

  /// 앱 시작 시 저장된 커스텀 색상 로드
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cache.clear();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        final className = key.replaceFirst(_prefix, '');
        final value = prefs.getInt(key);
        if (value != null) _cache[className] = Color(value);
      }
    }
  }

  /// 클래스 색상 반환 (커스텀 우선 → 기본값)
  static Color colorFor(String className) =>
      _cache[className] ??
      kDefaultClassColors[className] ??
      const Color(0xFF94a3b8);

  /// 클래스 색상 저장
  static Future<void> setColor(String className, Color color) async {
    _cache[className] = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$className', color.toARGB32());
  }

  /// 특정 클래스 색상 초기화 (기본값으로)
  static Future<void> resetColor(String className) async {
    _cache.remove(className);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$className');
  }

  /// 전체 색상 초기화
  static Future<void> resetAll() async {
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_prefix)) await prefs.remove(key);
    }
  }

  /// 현재 유효한 전체 색상 맵 (기본값 + 커스텀 오버라이드)
  static Map<String, Color> get currentColors {
    final result = Map<String, Color>.from(kDefaultClassColors);
    result.addAll(_cache);
    return result;
  }

  /// 커스텀 색상이 설정된 클래스 목록
  static Set<String> get customizedClasses => _cache.keys.toSet();
}
