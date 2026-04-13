import 'published_ontology.dart';

// ── 표준 매핑 모델 ──────────────────────────────────────────────────────────────

class MappingSuggestion {
  final String uri;
  final String label;
  final int priority;
  final double confidence;

  const MappingSuggestion({
    required this.uri,
    required this.label,
    required this.priority,
    this.confidence = 0.0,
  });

  factory MappingSuggestion.fromJson(Map<String, dynamic> json) =>
      MappingSuggestion(
        uri: json['uri'] ?? '',
        label: json['label'] ?? '',
        priority: json['priority'] ?? 99,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      );
}

class MappingItem {
  final String name;
  final String labelKo;
  final String color;
  final String currentTag;
  final List<MappingSuggestion> suggestions;
  final bool isConfirmed;

  const MappingItem({
    required this.name,
    required this.labelKo,
    required this.currentTag,
    required this.suggestions,
    required this.isConfirmed,
    this.color = '#888888',
  });

  factory MappingItem.fromJson(Map<String, dynamic> json) => MappingItem(
        name: json['name'] ?? '',
        labelKo: json['label_ko'] ?? '',
        color: json['color'] ?? '#888888',
        currentTag: json['current_tag'] ?? '',
        suggestions: (json['suggestions'] as List? ?? [])
            .map((s) => MappingSuggestion.fromJson(s as Map<String, dynamic>))
            .toList(),
        isConfirmed: json['is_confirmed'] ?? false,
      );

  MappingItem copyWith({String? currentTag, bool? isConfirmed}) => MappingItem(
        name: name,
        labelKo: labelKo,
        color: color,
        currentTag: currentTag ?? this.currentTag,
        suggestions: suggestions,
        isConfirmed: isConfirmed ?? this.isConfirmed,
      );
}

enum OntologyStatus { draft, confirmed, archived }

class OntologyClass {
  final String name;
  final String labelKo;
  final String color;
  final String description;
  final List<String> examples;
  final String standardTag;
  final List<ClassMapping> mappings;

  const OntologyClass({
    required this.name,
    required this.labelKo,
    required this.color,
    this.description = '',
    this.examples = const [],
    this.standardTag = '',
    this.mappings = const [],
  });

  factory OntologyClass.fromJson(Map<String, dynamic> json) => OntologyClass(
    name: json['name'] ?? '',
    labelKo: json['label_ko'] ?? '',
    color: json['color'] ?? '#888888',
    description: json['description'] ?? '',
    examples: List<String>.from(json['examples'] ?? []),
    standardTag: json['standard_tag'] ?? '',
    mappings: (json['mappings'] as List? ?? [])
        .map((m) => ClassMapping.fromJson(m as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'label_ko': labelKo,
    'color': color,
    'description': description,
    'examples': examples,
    'standard_tag': standardTag,
    'mappings': mappings.map((m) => m.toJson()).toList(),
  };

  OntologyClass copyWith({
    String? name,
    String? labelKo,
    String? color,
    String? description,
    List<String>? examples,
    String? standardTag,
    List<ClassMapping>? mappings,
  }) => OntologyClass(
    name: name ?? this.name,
    labelKo: labelKo ?? this.labelKo,
    color: color ?? this.color,
    description: description ?? this.description,
    examples: examples ?? this.examples,
    standardTag: standardTag ?? this.standardTag,
    mappings: mappings ?? this.mappings,
  );
}

class OntologyPredicate {
  final String name;
  final List<String> domain;
  final List<String> range;
  final String description;
  final String standardTag;

  const OntologyPredicate({
    required this.name,
    this.domain = const [],
    this.range = const [],
    this.description = '',
    this.standardTag = '',
  });

  factory OntologyPredicate.fromJson(Map<String, dynamic> json) =>
      OntologyPredicate(
        name: json['name'] ?? '',
        domain: List<String>.from(json['domain'] ?? []),
        range: List<String>.from(json['range_'] ?? []),
        description: json['description'] ?? '',
        standardTag: json['standard_tag'] ?? '',
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'domain': domain,
    'range_': range,
    'description': description,
    'standard_tag': standardTag,
  };
}

class OntologyVersion {
  final String versionId;
  final OntologyStatus status;
  final List<OntologyClass> classes;
  final List<OntologyPredicate> predicates;
  final String createdAt;
  final String? confirmedAt;
  final String description;

  const OntologyVersion({
    required this.versionId,
    required this.status,
    required this.classes,
    required this.predicates,
    required this.createdAt,
    this.confirmedAt,
    this.description = '',
  });

  factory OntologyVersion.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] ?? 'draft';
    final status = OntologyStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => OntologyStatus.draft,
    );
    return OntologyVersion(
      versionId: json['version_id'] ?? '',
      status: status,
      classes: (json['classes'] as List? ?? [])
          .map((c) => OntologyClass.fromJson(c))
          .toList(),
      predicates: (json['predicates'] as List? ?? [])
          .map((p) => OntologyPredicate.fromJson(p))
          .toList(),
      createdAt: json['created_at'] ?? '',
      confirmedAt: json['confirmed_at'],
      description: json['description'] ?? '',
    );
  }
}
