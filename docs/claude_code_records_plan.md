# 구술기록 관리 화면 개선 Plan

## 목표

```
기록 탭:
  1. 파일 업로드로 기록 등록
  2. 온톨로지/트리플 생성 시 업로드 파일 자동 등록
  3. 전체 등록 기록 목록 표시
  4. 등록된 파일 열어보기 + 다운로드
```

---

## 백엔드 변경

### 파일 저장 디렉토리

```
data/
├── records/
│   ├── records.json          ← 기록 메타데이터 (기존)
│   └── files/                ← 업로드 원본 파일 저장 (신규)
│       ├── {record_id}.docx
│       ├── {record_id}.pdf
│       └── {record_id}.txt
```

### API 수정/추가

```python
# api/router_records.py 수정

# 기존: 텍스트만 저장
POST /api/records/text
  body: { title, content, note }

# 수정: 파일 업로드 → 텍스트 추출 + 원본 파일 저장
POST /api/records/file
  body: multipart/form-data (file)
  → 텍스트 추출 (기존)
  → 원본 파일을 data/records/files/{record_id}.{ext} 에 저장
  → OralRecord 에 file_path, original_filename 필드 저장

# 신규: 파일 다운로드
GET /api/records/{id}/download
  → data/records/files/{record_id}.{ext} 파일 반환
  → Content-Disposition: attachment; filename="{original_filename}"

# 신규: 파일 내용 조회 (텍스트 미리보기)
GET /api/records/{id}/content
  → { id, content, char_count }
  → (기존 저장된 content 필드 반환)
```

### OralRecord 모델 확장

```python
# core/record_store.py

@dataclass
class OralRecord:
    id:                str
    title:             str
    source_type:       str    # "text" | "file"
    file_name:         str    # 원본 파일명
    file_path:         str    # 서버 저장 경로 (신규)
    file_ext:          str    # 확장자 (신규): "docx" | "pdf" | "txt"
    content:           str    # 추출된 텍스트
    char_count:        int
    note:              str
    created_at:        str
    source:            str    # "manual" | "ontology" | "triple" (신규)
                               # 어떤 작업에서 등록됐는지
    is_deleted:        int

# SQLite 스키마 수정
ALTER TABLE oral_records ADD COLUMN file_path TEXT DEFAULT '';
ALTER TABLE oral_records ADD COLUMN file_ext  TEXT DEFAULT '';
ALTER TABLE oral_records ADD COLUMN source    TEXT DEFAULT 'manual';
```

### 온톨로지/트리플 생성 시 자동 등록

```python
# 온톨로지 생성 시 (api/router_ontology.py)
@router.post("/generate")
async def generate_ontology(
    file: UploadFile = File(None),
    sample_text: str = Form(""),
    ...
):
    # 파일 업로드인 경우 기록 자동 등록
    if file:
        record = await record_store.create_file(
            file=file,
            source="ontology",
            note=f"온톨로지 생성용: {new_version_id}"
        )
        text = record.content
    else:
        text = sample_text

    # 기존 온톨로지 생성 로직
    ...

# 트리플 생성 시 (api/router_triple.py)
@router.post("/extract-from-file")
async def extract_triples_from_file(
    file: UploadFile = File(...),
    ...
):
    # 기록 자동 등록
    record = await record_store.create_file(
        file=file,
        source="triple",
        note=f"트리플 생성용"
    )
    text = record.content
    ...
```

---

## Flutter 기록 화면 개선

### 화면 구조

```
기록 탭
├── 상단 액션 바
│   ├── [+ 파일 등록] 버튼
│   ├── [+ 텍스트 입력] 버튼
│   └── 검색창
│
├── 필터 행
│   ├── [전체] [파일] [텍스트]
│   └── [수동등록] [온톨로지] [트리플]
│
└── 기록 목록 (카드)
    ├── 파일 아이콘 (확장자별)
    ├── 제목
    ├── 출처 배지 (수동/온톨로지/트리플)
    ├── 날짜 + 글자수
    └── [열기] [다운로드] [삭제] 버튼
```

### 파일 등록 다이얼로그

```dart
// flutter/lib/screens/records/record_list_screen.dart

Future<void> _showFileUploadDialog() async {
  // 파일 선택 (복수 가능)
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.custom,
    allowedExtensions: ['txt', 'pdf', 'docx'],
  );
  if (result == null) return;

  // 각 파일 업로드
  int uploaded = 0;
  for (final file in result.files) {
    try {
      final bytes = file.bytes ?? File(file.path!).readAsBytesSync();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
        'note': '',
        'source': 'manual',
      });
      await ref.read(apiClientProvider)
          .post('/api/records/file', data: formData);
      uploaded++;
    } catch (e) {
      // 개별 실패는 무시하고 계속
    }
  }

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$uploaded개 기록 등록 완료')),
  );
  _loadRecords();
}
```

### 기록 카드

```dart
// flutter/lib/screens/records/record_card.dart

class RecordCard extends StatelessWidget {
  final OralRecord record;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(children: [
        // 파일 타입 아이콘
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_fileIcon, size: 20, color: _iconColor),
        ),
        const SizedBox(width: 12),

        // 제목 + 메타데이터
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                // 출처 배지
                _SourceBadge(source: record.source),
                const SizedBox(width: 6),
                Text('${record.charCount}자',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted,
                        fontFamily: 'monospace')),
                const SizedBox(width: 6),
                Text(record.createdAt.substring(0, 10),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ]),
            ],
          ),
        ),

        // 액션 버튼
        Row(mainAxisSize: MainAxisSize.min, children: [
          // 열기 (내용 미리보기)
          IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 18),
            tooltip: '내용 보기',
            onPressed: onView,
          ),
          // 다운로드 (파일이 있을 때만)
          if (record.fileExt.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_outlined, size: 18),
              tooltip: '파일 다운로드',
              onPressed: onDownload,
            ),
          // 삭제
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.error),
            tooltip: '삭제',
            onPressed: onDelete,
          ),
        ]),
      ]),
    );
  }

  IconData get _fileIcon {
    switch (record.fileExt.toLowerCase()) {
      case 'docx': return Icons.description_outlined;
      case 'pdf':  return Icons.picture_as_pdf_outlined;
      case 'txt':  return Icons.text_snippet_outlined;
      default:     return Icons.article_outlined;
    }
  }

  Color get _iconColor {
    switch (record.fileExt.toLowerCase()) {
      case 'docx': return Colors.blue;
      case 'pdf':  return Colors.red;
      case 'txt':  return Colors.green;
      default:     return AppColors.textMuted;
    }
  }
}

// 출처 배지
class _SourceBadge extends StatelessWidget {
  final String source;  // "manual" | "ontology" | "triple"

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      'ontology' => ('온톨로지', AppColors.primary),
      'triple'   => ('트리플', AppColors.secondary),
      _          => ('수동', AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}
```

### 내용 보기 다이얼로그

```dart
void _showContentDialog(OralRecord record) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        Expanded(child: Text(record.title,
            overflow: TextOverflow.ellipsis)),
        // 다운로드 버튼 (파일 있을 때)
        if (record.fileExt.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.download_outlined, size: 18),
            tooltip: '파일 다운로드',
            onPressed: () {
              Navigator.of(ctx).pop();
              _downloadFile(record);
            },
          ),
      ]),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(children: [
          // 메타데이터
          Row(children: [
            _SourceBadge(source: record.source),
            const SizedBox(width: 8),
            Text('${record.charCount}자',
                style: const TextStyle(fontSize: 12,
                    color: AppColors.textMuted)),
            const SizedBox(width: 8),
            Text(record.createdAt.substring(0, 16),
                style: const TextStyle(fontSize: 12,
                    color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          // 텍스트 내용
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                child: SelectableText(
                  record.content,
                  style: const TextStyle(
                      fontSize: 13, height: 1.7),
                ),
              ),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}
```

### 파일 다운로드

```dart
Future<void> _downloadFile(OralRecord record) async {
  // 저장 경로 선택
  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: '파일 저장',
    fileName: record.fileName.isNotEmpty
        ? record.fileName
        : '${record.title}.${record.fileExt}',
    allowedExtensions: [record.fileExt],
    type: FileType.custom,
  );
  if (savePath == null) return;

  // 파일 다운로드
  final response = await ref.read(apiClientProvider).get(
    '/api/records/${record.id}/download',
    options: Options(responseType: ResponseType.bytes),
  );

  await File(savePath).writeAsBytes(response.data as List<int>);

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('다운로드 완료: $savePath')),
  );
}
```

---

## 구현 순서

```
Phase 1 — 백엔드
  1-1. data/records/files/ 디렉토리 생성
  1-2. OralRecord 모델에 file_path, file_ext, source 필드 추가
  1-3. SQLite 스키마 마이그레이션
  1-4. record_store.create_file() 에 파일 저장 로직 추가
  1-5. GET /api/records/{id}/download 엔드포인트 추가
  1-6. 온톨로지/트리플 생성 시 자동 등록 연결

Phase 2 — Flutter
  2-1. OralRecord 모델 업데이트
  2-2. record_api.dart: downloadFile(), loadRecords() 수정
  2-3. RecordCard 위젯 신규 (파일 아이콘 + 출처 배지)
  2-4. record_list_screen.dart:
       - [+ 파일 등록] 버튼
       - 필터 (타입/출처)
       - 내용 보기 다이얼로그
       - 다운로드 기능

Phase 3 — 테스트
  □ .docx 파일 등록 → 목록에 표시 → 내용 보기 → 다운로드
  □ 온톨로지 생성 시 파일 업로드 → 기록 탭 자동 등록
  □ 트리플 생성 시 파일 업로드 → 기록 탭 자동 등록
  □ 복수 파일 한 번에 등록
```

---

## 완료 기준

```
Phase 1:
  □ POST /api/records/file → data/records/files/ 에 원본 저장
  □ GET /api/records/{id}/download → 파일 반환
  □ 온톨로지 AI 생성 시 파일 업로드 → /api/records/ 에 자동 등록

Phase 2:
  □ [+ 파일 등록] → 파일 선택 → 목록에 즉시 추가
  □ 카드: 파일 아이콘(docx=파랑/pdf=빨강/txt=초록) + 출처 배지
  □ [내용 보기] → 텍스트 전문 + 복사 가능
  □ [다운로드] → 원본 파일 저장
  □ 출처 필터: 수동/온톨로지/트리플 각각 필터링
```
