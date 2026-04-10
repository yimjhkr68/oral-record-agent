// 공표된 온톨로지 관련 모델 (CIDOC-CRM, Schema.org, FOAF, Dublin Core 등)

class ClassMapping {
  final String curie;       // e.g. "crm:E21_Person"
  final String ontologyId;  // e.g. "cidoc-crm"
  final bool isPrimary;
  final double confidence;
  final String note;

  const ClassMapping({
    required this.curie,
    required this.ontologyId,
    this.isPrimary = true,
    this.confidence = 1.0,
    this.note = '',
  });

  factory ClassMapping.fromJson(Map<String, dynamic> json) => ClassMapping(
        curie: json['curie'] as String? ?? '',
        ontologyId: json['ontology_id'] as String? ?? '',
        isPrimary: json['is_primary'] as bool? ?? true,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
        note: json['note'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'curie': curie,
        'ontology_id': ontologyId,
        'is_primary': isPrimary,
        'confidence': confidence,
        'note': note,
      };

  ClassMapping copyWith({
    String? curie,
    String? ontologyId,
    bool? isPrimary,
    double? confidence,
    String? note,
  }) =>
      ClassMapping(
        curie: curie ?? this.curie,
        ontologyId: ontologyId ?? this.ontologyId,
        isPrimary: isPrimary ?? this.isPrimary,
        confidence: confidence ?? this.confidence,
        note: note ?? this.note,
      );
}

class PublishedClass {
  final String id;
  final String curie;
  final String uri;
  final String label;
  final String labelKo;
  final String description;

  const PublishedClass({
    required this.id,
    required this.curie,
    required this.uri,
    required this.label,
    required this.labelKo,
    this.description = '',
  });

  factory PublishedClass.fromJson(Map<String, dynamic> json) => PublishedClass(
        id: json['id'] as String? ?? '',
        curie: json['curie'] as String? ?? '',
        uri: json['uri'] as String? ?? '',
        label: json['label'] as String? ?? '',
        labelKo: json['label_ko'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'curie': curie,
        'uri': uri,
        'label': label,
        'label_ko': labelKo,
        'description': description,
      };

  PublishedClass copyWith({
    String? curie,
    String? uri,
    String? label,
    String? labelKo,
    String? description,
  }) =>
      PublishedClass(
        id: id,
        curie: curie ?? this.curie,
        uri: uri ?? this.uri,
        label: label ?? this.label,
        labelKo: labelKo ?? this.labelKo,
        description: description ?? this.description,
      );
}

class PublishedOntology {
  final String id;
  final String name;
  final String prefix;
  final String namespaceUri;
  final String description;
  final String version;
  final List<PublishedClass> classes;

  const PublishedOntology({
    required this.id,
    required this.name,
    required this.prefix,
    required this.namespaceUri,
    this.description = '',
    this.version = '',
    this.classes = const [],
  });

  factory PublishedOntology.fromJson(Map<String, dynamic> json) =>
      PublishedOntology(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        prefix: json['prefix'] as String? ?? '',
        namespaceUri: json['namespace_uri'] as String? ?? '',
        description: json['description'] as String? ?? '',
        version: json['version'] as String? ?? '',
        classes: (json['classes'] as List? ?? [])
            .map((c) => PublishedClass.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'prefix': prefix,
        'namespace_uri': namespaceUri,
        'description': description,
        'version': version,
        'classes': classes.map((c) => c.toJson()).toList(),
      };
}
