class OralRecord {
  final String id;
  final String title;
  final String sourceType; // 'text' | 'file'
  final String fileName;
  final String filePath;   // 서버 저장 경로
  final String fileExt;    // 'docx' | 'pdf' | 'txt' | ''
  final String source;     // 'manual' | 'ontology' | 'triple'
  final String? contentPreview; // 목록용 (200자)
  final String? content;        // 상세용 전문
  final int charCount;
  final String note;
  final String createdAt;
  final int isDeleted;

  const OralRecord({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.fileName,
    this.filePath = '',
    this.fileExt = '',
    this.source = 'manual',
    this.contentPreview,
    this.content,
    required this.charCount,
    required this.note,
    required this.createdAt,
    this.isDeleted = 0,
  });

  factory OralRecord.fromJson(Map<String, dynamic> json) => OralRecord(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        sourceType: json['source_type'] ?? 'text',
        fileName: json['file_name'] ?? '',
        filePath: json['file_path'] ?? '',
        fileExt: json['file_ext'] ?? '',
        source: json['source'] ?? 'manual',
        contentPreview: json['content_preview'] as String?,
        content: json['content'] as String?,
        charCount: (json['char_count'] as num?)?.toInt() ?? 0,
        note: json['note'] ?? '',
        createdAt: json['created_at'] ?? '',
        isDeleted: (json['is_deleted'] as num?)?.toInt() ?? 0,
      );

  String get dateLabel => createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
  bool get isFile => sourceType == 'file';
  bool get hasFile => fileExt.isNotEmpty;
}
