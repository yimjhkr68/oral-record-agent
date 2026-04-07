enum TripleStatus { active, archived }

class Triple {
  final String id;
  final String subject;
  final String subjectType;
  final String predicate;
  final String object;
  final String objectType;
  final String ontologyVersion;
  final double confidence;
  final TripleStatus status;
  final String createdAt;
  final String note;

  const Triple({
    required this.id,
    required this.subject,
    required this.subjectType,
    required this.predicate,
    required this.object,
    required this.objectType,
    required this.ontologyVersion,
    this.confidence = 1.0,
    this.status = TripleStatus.active,
    required this.createdAt,
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
      confidence: (json['confidence'] ?? 1.0).toDouble(),
      status: statusStr == 'archived' ? TripleStatus.archived : TripleStatus.active,
      createdAt: json['created_at'] ?? '',
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
