class OntologyEvent {
  final String id;
  final String eventType;
  final String versionId;
  final String detail;
  final String createdAt;
  final String userNote;

  const OntologyEvent({
    required this.id,
    required this.eventType,
    required this.versionId,
    required this.detail,
    required this.createdAt,
    required this.userNote,
  });

  factory OntologyEvent.fromJson(Map<String, dynamic> json) => OntologyEvent(
        id: json['id'] ?? '',
        eventType: json['event_type'] ?? '',
        versionId: json['version_id'] ?? '',
        detail: json['detail'] ?? '',
        createdAt: json['created_at'] ?? '',
        userNote: json['user_note'] ?? '',
      );

  String get dateLabel =>
      createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;

  bool get isConfirmed => eventType == 'confirmed';
}

class ExtractionSession {
  final String id;
  final String ontologyVersionId;
  final String status; // running | completed | failed
  final int totalRecords;
  final int processedRecords;
  final int extractedCount;
  final int confirmedCount;
  final int rejectedCount;
  final int modifiedCount;
  final String note;
  final String createdAt;
  final String completedAt;
  final List<SessionRecord> records;

  const ExtractionSession({
    required this.id,
    required this.ontologyVersionId,
    required this.status,
    required this.totalRecords,
    required this.processedRecords,
    required this.extractedCount,
    required this.confirmedCount,
    required this.rejectedCount,
    required this.modifiedCount,
    required this.note,
    required this.createdAt,
    required this.completedAt,
    required this.records,
  });

  factory ExtractionSession.fromJson(Map<String, dynamic> json) =>
      ExtractionSession(
        id: json['id'] ?? '',
        ontologyVersionId: json['ontology_version_id'] ?? '',
        status: json['status'] ?? '',
        totalRecords: (json['total_records'] as num?)?.toInt() ?? 0,
        processedRecords: (json['processed_records'] as num?)?.toInt() ?? 0,
        extractedCount: (json['extracted_count'] as num?)?.toInt() ?? 0,
        confirmedCount: (json['confirmed_count'] as num?)?.toInt() ?? 0,
        rejectedCount: (json['rejected_count'] as num?)?.toInt() ?? 0,
        modifiedCount: (json['modified_count'] as num?)?.toInt() ?? 0,
        note: json['note'] ?? '',
        createdAt: json['created_at'] ?? '',
        completedAt: json['completed_at'] ?? '',
        records: (json['records'] as List? ?? [])
            .map((r) => SessionRecord.fromJson(r))
            .toList(),
      );

  String get dateLabel =>
      createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}

class SessionRecord {
  final String recordId;
  final int extracted;
  final String title;
  final String sourceType;

  const SessionRecord({
    required this.recordId,
    required this.extracted,
    required this.title,
    required this.sourceType,
  });

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        recordId: json['record_id'] ?? '',
        extracted: (json['extracted'] as num?)?.toInt() ?? 0,
        title: json['title'] ?? json['record_id'] ?? '',
        sourceType: json['source_type'] ?? 'text',
      );
}

class HistorySummary {
  final int records;
  final int ontologyVersions;
  final int confirmedOntologies;
  final int extractionSessions;
  final String lastActivity;

  const HistorySummary({
    required this.records,
    required this.ontologyVersions,
    required this.confirmedOntologies,
    required this.extractionSessions,
    required this.lastActivity,
  });

  factory HistorySummary.fromJson(Map<String, dynamic> json) => HistorySummary(
        records: (json['records'] as num?)?.toInt() ?? 0,
        ontologyVersions: (json['ontology_versions'] as num?)?.toInt() ?? 0,
        confirmedOntologies:
            (json['confirmed_ontologies'] as num?)?.toInt() ?? 0,
        extractionSessions:
            (json['extraction_sessions'] as num?)?.toInt() ?? 0,
        lastActivity: json['last_activity'] ?? '',
      );
}
