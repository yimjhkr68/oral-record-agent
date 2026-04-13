enum TripleStatus { pending, active, archived }

class Triple {
  final String id;
  final String subject;
  final String subjectType;
  final String predicate;
  final String object;
  final String objectType;
  final String ontologyVersion;
  final String sourceRecordId;
  final double confidence;
  final TripleStatus status;
  final String createdAt;
  final String createdBy;
  final String extractionMethod; // auto_extract | manual | edited
  final String? updatedAt;
  final String? updatedBy;
  final String note;

  const Triple({
    required this.id,
    required this.subject,
    required this.subjectType,
    required this.predicate,
    required this.object,
    required this.objectType,
    required this.ontologyVersion,
    this.sourceRecordId = '',
    this.confidence = 1.0,
    this.status = TripleStatus.active,
    required this.createdAt,
    this.createdBy = 'system',
    this.extractionMethod = 'auto_extract',
    this.updatedAt,
    this.updatedBy,
    this.note = '',
  });

  factory Triple.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] ?? 'active';
    return Triple(
      id: json['id'] ?? '',
      subject: json['subject'] ?? '',
      subjectType: json['subject_type'] ?? '',
      predicate: json['predicate'] ?? '',
      object: json['object'] ?? '',
      objectType: json['object_type'] ?? '',
      ontologyVersion: json['ontology_version'] ?? '',
      sourceRecordId: json['source_record_id'] ?? '',
      confidence: (json['confidence'] ?? 1.0).toDouble(),
      status: statusStr == 'archived'
          ? TripleStatus.archived
          : statusStr == 'pending'
              ? TripleStatus.pending
              : TripleStatus.active,
      createdAt: json['created_at'] ?? '',
      createdBy: json['created_by'] ?? 'system',
      extractionMethod: json['extraction_method'] ?? 'auto_extract',
      updatedAt: json['updated_at'] as String?,
      updatedBy: json['updated_by'] as String?,
      note: json['note'] ?? '',
    );
  }
}

class GraphNode {
  final String id;
  final String type;
  final int degree;

  const GraphNode({
    required this.id,
    required this.type,
    required this.degree,
  });

  factory GraphNode.fromJson(Map<String, dynamic> json) => GraphNode(
    id: json['id'] ?? '',
    type: json['type'] ?? '',
    degree: json['degree'] ?? 0,
  );
}

class GraphData {
  final List<GraphNode> nodes;
  final List<Triple> triples;

  const GraphData({required this.nodes, required this.triples});

  factory GraphData.fromJson(Map<String, dynamic> json) => GraphData(
    nodes: (json['nodes'] as List? ?? [])
        .map((n) => GraphNode.fromJson(n))
        .toList(),
    triples: (json['triples'] as List? ?? [])
        .map((t) => Triple.fromJson(t))
        .toList(),
  );
}

// ── 검토 대기 트리플 (DB 미저장, 편집 가능) ───────────────────────────────────

class PendingTriple {
  final String subject;
  final String subjectType;
  String predicate;
  String object;
  String objectType;
  double confidence;
  final String sourceRecordId;
  final String ontologyVersion;
  String note;

  PendingTriple({
    required this.subject,
    required this.subjectType,
    required this.predicate,
    required this.object,
    required this.objectType,
    required this.confidence,
    required this.sourceRecordId,
    required this.ontologyVersion,
    this.note = '',
  });

  factory PendingTriple.fromJson(Map<String, dynamic> json) => PendingTriple(
        subject: json['subject'] ?? '',
        subjectType:
            json['subjectType'] ?? json['subject_type'] ?? '',
        predicate: json['predicate'] ?? '',
        object: json['object'] ?? '',
        objectType: json['objectType'] ?? json['object_type'] ?? '',
        confidence: (json['confidence'] ?? 1.0).toDouble(),
        sourceRecordId: json['source_record_id'] ?? '',
        ontologyVersion: json['ontology_version'] ?? '',
        note: json['note'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'subjectType': subjectType,
        'predicate': predicate,
        'object': object,
        'objectType': objectType,
        'confidence': confidence,
        'source_record_id': sourceRecordId,
        'ontology_version': ontologyVersion,
        'note': note,
      };

  PendingTriple copyWith({
    String? predicate,
    String? object,
    String? objectType,
    double? confidence,
    String? note,
  }) => PendingTriple(
        subject: subject,
        subjectType: subjectType,
        predicate: predicate ?? this.predicate,
        object: object ?? this.object,
        objectType: objectType ?? this.objectType,
        confidence: confidence ?? this.confidence,
        sourceRecordId: sourceRecordId,
        ontologyVersion: ontologyVersion,
        note: note ?? this.note,
      );
}

// ── 구술기록 소스 ─────────────────────────────────────────────────────────────

class SourceRecord {
  final String id;
  final String content;

  const SourceRecord({required this.id, required this.content});
}
