enum OntologyStatus { draft, confirmed, archived }

class OntologyClass {
  final String name;
  final String labelKo;
  final String color;
  final String description;
  final List<String> examples;
  final String standardTag;

  const OntologyClass({
    required this.name,
    required this.labelKo,
    required this.color,
    this.description = '',
    this.examples = const [],
    this.standardTag = '',
  });

  factory OntologyClass.fromJson(Map<String, dynamic> json) => OntologyClass(
    name: json['name'] ?? '',
    labelKo: json['label_ko'] ?? '',
    color: json['color'] ?? '#888888',
    description: json['description'] ?? '',
    examples: List<String>.from(json['examples'] ?? []),
    standardTag: json['standard_tag'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'label_ko': labelKo,
    'color': color,
    'description': description,
    'examples': examples,
    'standard_tag': standardTag,
  };
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
