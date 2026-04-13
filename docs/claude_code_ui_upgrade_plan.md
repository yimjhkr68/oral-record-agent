# 전체 UI 업그레이드 Plan

## 디자인 방향

```
컨셉: "역사 아카이브 + 현대 분석 도구"
톤:   다크 베이스 + 따뜻한 앰버 강조 + 차분한 청록 보조
      → 무거운 역사적 무게감 + 정밀한 데이터 도구의 조합

기억에 남는 포인트:
  - 사이드바: 반투명 유리(Glassmorphism) 효과
  - 카드:     미세한 테두리 + 그림자 레이어
  - 색상:     다크 베이스(#0F1117) + 앰버(#F59E0B) + 청록(#14B8A6)
  - 타이포:   데이터는 모노스페이스, 제목은 명조 계열
```

---

## 디자인 시스템

### 색상 팔레트

```dart
// flutter/lib/theme/app_colors.dart

class AppColors {
  // ── 베이스 ──────────────────────────────────────
  static const background       = Color(0xFF0F1117);  // 최심 배경
  static const surface          = Color(0xFF171B26);  // 카드 배경
  static const surfaceElevated  = Color(0xFF1E2333);  // 올라온 카드
  static const surfaceHover     = Color(0xFF252A3D);  // 호버 상태
  static const border           = Color(0xFF2A2F45);  // 구분선
  static const borderLight      = Color(0xFF353B55);  // 밝은 구분선

  // ── 주 강조색 (앰버 — 역사·기록의 따뜻함) ──────
  static const primary          = Color(0xFFF59E0B);  // 기본 강조
  static const primaryDim       = Color(0xFFD97706);  // 어두운 강조
  static const primaryFaint     = Color(0x1AF59E0B);  // 배경용 희미한 강조

  // ── 보조 강조색 (청록 — 데이터·연결) ────────────
  static const secondary        = Color(0xFF14B8A6);  // 보조 강조
  static const secondaryDim     = Color(0xFF0D9488);  // 어두운 보조
  static const secondaryFaint   = Color(0x1A14B8A6);  // 배경용

  // ── 텍스트 ──────────────────────────────────────
  static const textPrimary      = Color(0xFFE8EAF2);  // 주 텍스트
  static const textSecondary    = Color(0xFF9CA3C8);  // 보조 텍스트
  static const textMuted        = Color(0xFF5C6385);  // 흐린 텍스트
  static const textAccent       = Color(0xFFF59E0B);  // 강조 텍스트

  // ── 상태 색상 ────────────────────────────────────
  static const success          = Color(0xFF10B981);
  static const warning          = Color(0xFFF59E0B);
  static const error            = Color(0xFFEF4444);
  static const info             = Color(0xFF3B82F6);

  // ── 상태 배지 ────────────────────────────────────
  static const draft            = Color(0xFFD97706);  // Draft = 앰버
  static const confirmed        = Color(0xFF10B981);  // Confirmed = 초록
  static const archived         = Color(0xFF5C6385);  // Archived = 회색
}
```

### 타이포그래피

```dart
// flutter/lib/theme/app_typography.dart
// pubspec.yaml: google_fonts 패키지 사용

// 제목: Noto Serif KR (역사적 무게감)
// 본문: Noto Sans KR (가독성)
// 데이터: Source Code Pro (정밀함)

static TextStyle heading1 = GoogleFonts.notoSerifKr(
  fontSize: 22, fontWeight: FontWeight.w700,
  color: AppColors.textPrimary, letterSpacing: -0.5,
);
static TextStyle heading2 = GoogleFonts.notoSerifKr(
  fontSize: 17, fontWeight: FontWeight.w600,
  color: AppColors.textPrimary,
);
static TextStyle body = GoogleFonts.notoSansKr(
  fontSize: 13, color: AppColors.textSecondary, height: 1.6,
);
static TextStyle caption = GoogleFonts.notoSansKr(
  fontSize: 11, color: AppColors.textMuted,
);
static TextStyle mono = GoogleFonts.sourceCodePro(
  fontSize: 12, color: AppColors.textSecondary,
);
static TextStyle badge = GoogleFonts.notoSansKr(
  fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5,
);
```

### 테마 정의

```dart
// flutter/lib/theme/app_theme.dart

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,

    colorScheme: const ColorScheme.dark(
      surface:          AppColors.surface,
      primary:          AppColors.primary,
      secondary:        AppColors.secondary,
      onPrimary:        Colors.black,
      onSecondary:      Colors.black,
      onSurface:        AppColors.textPrimary,
      outline:          AppColors.border,
      surfaceContainerHighest: AppColors.surfaceElevated,
    ),

    // Card
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: AppTypography.heading2,
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      shape: const Border(
        bottom: BorderSide(color: AppColors.border, width: 1),
      ),
    ),

    // Input
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
    ),

    // ElevatedButton
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        textStyle: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600, color: Colors.black),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceElevated,
      selectedColor: AppColors.primaryFaint,
      side: const BorderSide(color: AppColors.border),
      labelStyle: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.border, thickness: 1, space: 1,
    ),

    // TabBar
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: AppTypography.body,
    ),
  );
}
```

---

## 컴포넌트 라이브러리

### AppCard — 통일된 카드

```dart
// flutter/lib/widgets/common/app_card.dart

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final bool elevated;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primaryFaint
            : elevated ? AppColors.surfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: elevated ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: AppColors.surfaceHover.withOpacity(0.5),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(14),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

### StatusBadge — 상태 배지

```dart
// flutter/lib/widgets/common/status_badge.dart

class StatusBadge extends StatelessWidget {
  final String status;  // 'draft' | 'confirmed' | 'archived' | 'active' | 'pending'

  static const _configs = {
    'draft':     (AppColors.draft,    '작업 중'),
    'confirmed': (AppColors.confirmed,'확정'),
    'archived':  (AppColors.archived, '아카이브'),
    'active':    (AppColors.success,  '활성'),
    'pending':   (AppColors.warning,  '검토 중'),
    'running':   (AppColors.info,     '처리 중'),
  };

  @override
  Widget build(BuildContext context) {
    final (color, label) = _configs[status.toLowerCase()]
        ?? (AppColors.textMuted, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: AppTypography.badge.copyWith(color: color)),
    );
  }
}
```

### SectionHeader — 섹션 헤더

```dart
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
        ],
        Text(title, style: AppTypography.heading2),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
```

---

## 화면별 UI 개선

### 사이드 네비게이션 (AppShell)

```dart
// 세련된 사이드바
Container(
  width: 64,
  decoration: BoxDecoration(
    color: AppColors.surface,
    border: const Border(
      right: BorderSide(color: AppColors.border, width: 1),
    ),
  ),
  child: Column(children: [
    // 앱 로고 영역
    Container(
      height: 56,
      alignment: Alignment.center,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.hub, size: 18, color: Colors.black),
      ),
    ),
    const Divider(height: 1),
    const SizedBox(height: 8),

    // 네비게이션 아이템
    ...navItems.map((item) => _NavItem(
      icon: item.icon, label: item.label,
      selected: currentIndex == item.index,
      onTap: () => onTap(item.index),
    )),
  ]),
)

// 네비게이션 아이템
class _NavItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44, height: 44,
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryFaint : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: AppColors.primary.withOpacity(0.4))
              : null,
        ),
        child: Icon(icon, size: 20,
            color: selected ? AppColors.primary : AppColors.textMuted),
      ),
    );
  }
}
```

### 온톨로지 화면

```dart
// 좌측 패널 — 버전 카드
AppCard(
  selected: isSelected,
  onTap: () => onSelect(version),
  child: Row(children: [
    // 체크박스
    Checkbox(
      value: isChecked,
      activeColor: AppColors.primary,
      side: const BorderSide(color: AppColors.border),
      onChanged: onCheck,
    ),
    const SizedBox(width: 8),
    // 버전 정보
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(version.versionId,
              style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 3),
          Row(children: [
            StatusBadge(status: version.status),
            const SizedBox(width: 6),
            Text(version.createdAt.substring(0, 10),
                style: AppTypography.caption),
          ]),
        ],
      ),
    ),
    // 클래스/속성 수
    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('${version.classCount}개',
          style: AppTypography.mono.copyWith(color: AppColors.primary)),
      Text('클래스', style: AppTypography.caption),
    ]),
  ]),
)

// 클래스 카드
AppCard(
  elevated: true,
  child: Row(children: [
    // 색상 도트
    Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
        color: Color(int.parse('0xFF${cls.color.replaceAll("#", "")}')),
        shape: BoxShape.circle,
      ),
    ),
    const SizedBox(width: 10),
    // 이름
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(cls.name,
              style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 6),
          Text('(${cls.labelKo})',
              style: AppTypography.caption),
        ]),
        if (cls.standardTag.isNotEmpty)
          Text(cls.standardTag,
              style: AppTypography.mono.copyWith(
                  color: AppColors.secondary, fontSize: 11)),
      ]),
    ),
    // 액션 버튼 (호버 시 표시)
    _HoverActions(onEdit: ..., onDelete: ...),
  ]),
)
```

### 트리플 카드

```dart
// Step 3 트리플 행
AppCard(
  selected: isSelected,
  child: Row(children: [
    // 체크박스
    Checkbox(value: isSelected, onChanged: onSelect,
        activeColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border)),
    const SizedBox(width: 10),

    // 주어
    Expanded(
      flex: 3,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ClassBadge(type: triple.subjectType),
        const SizedBox(height: 3),
        Text(triple.subject,
            style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500)),
      ]),
    ),

    // 술어 (화살표)
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        Text(triple.predicate,
            style: AppTypography.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600)),
        const Icon(Icons.arrow_forward, size: 14,
            color: AppColors.textMuted),
      ]),
    ),

    // 목적어
    Expanded(
      flex: 3,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ClassBadge(type: triple.objectType),
        const SizedBox(height: 3),
        Text(triple.object,
            style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500)),
      ]),
    ),

    // 신뢰도
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondaryFaint,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('${(triple.confidence * 100).toInt()}%',
          style: AppTypography.mono.copyWith(
              color: AppColors.secondary, fontSize: 11)),
    ),
  ]),
)
```

### 빈 상태 화면 (EmptyState)

```dart
// 공통 빈 상태 위젯
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 32, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description!,
                style: AppTypography.caption,
                textAlign: TextAlign.center),
          ],
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    );
  }
}
```

### 로딩 상태

```dart
// 스켈레톤 로딩 (shimmer 효과)
// pubspec.yaml: shimmer: ^3.0.0

class SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceHover,
      child: AppCard(
        child: Column(children: [
          Row(children: [
            Container(width: 10, height: 10,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Container(width: 120, height: 14,
                color: Colors.white),
            const Spacer(),
            Container(width: 50, height: 14, color: Colors.white),
          ]),
          const SizedBox(height: 8),
          Container(width: double.infinity, height: 12,
              color: Colors.white),
        ]),
      ),
    );
  }
}
```

---

## 구현 순서

```
Phase 1 — 기반 시스템
  1-1. pubspec.yaml: google_fonts, shimmer 패키지 추가
  1-2. flutter/lib/theme/app_colors.dart
  1-3. flutter/lib/theme/app_typography.dart
  1-4. flutter/lib/theme/app_theme.dart (다크 테마)
  1-5. main.dart: theme 적용
  1-6. flutter run -d windows → 기본 색상/타이포 확인

Phase 2 — 공통 컴포넌트
  2-1. widgets/common/app_card.dart
  2-2. widgets/common/status_badge.dart
  2-3. widgets/common/section_header.dart
  2-4. widgets/common/empty_state.dart
  2-5. widgets/common/skeleton_card.dart

Phase 3 — 네비게이션
  3-1. AppShell: 사이드바 글래스모피즘 스타일
  3-2. 네비게이션 아이콘 툴팁 + 선택 애니메이션

Phase 4 — 온톨로지 화면
  4-1. 버전 카드 AppCard 적용
  4-2. 클래스/속성 카드 개선
  4-3. 탭 스타일 통일

Phase 5 — 트리플 화면
  5-1. 트리플 카드 리디자인
  5-2. 패싯 버튼 스타일
  5-3. 검색창 스타일

Phase 6 — 기록/이력/설정 화면
  6-1. 기록 카드
  6-2. 이력 타임라인
  6-3. 설정 섹션 카드

Phase 7 — 전체 polish
  7-1. 빈 상태 EmptyState 모든 화면 적용
  7-2. 로딩 Skeleton 적용
  7-3. 에러 표시 통일
  7-4. 스크롤바 스타일
  7-5. 전체 spacing 검토
```

---

## 완료 기준

```
□ 앱 전체 배경: #0F1117 다크 베이스
□ 카드: 테두리 + 미세 그림자
□ 버튼: 앰버 강조색
□ 상태 배지: Draft(앰버)/Confirmed(초록)/Archived(회색)
□ 텍스트: 계층 구분 명확 (Primary/Secondary/Muted)
□ 한글 폰트: Noto Serif KR (제목) / Noto Sans KR (본문)
□ 빈 상태: 아이콘 + 설명 + 액션 버튼
□ 로딩: Shimmer 스켈레톤
□ 모든 화면 스타일 일관성
```
