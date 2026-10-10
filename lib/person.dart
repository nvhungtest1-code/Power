class Person {
  final int id;
  String name;
  String gender;
  String description;
  int? fatherId;
  int? motherId;
  List<int> spouseIds;
  DateTime? birthDate;
  DateTime? deathDate;

  int? get parentId => fatherId ?? motherId;
  set parentId(int? value) => fatherId = value;

  Person({
    required this.id,
    required this.name,
    required this.gender,
    this.description = '',
    int? parentId,
    this.fatherId,
    this.motherId,
    List<int>? spouseIds,
    this.birthDate,
    this.deathDate,
  }) : spouseIds = spouseIds ?? [] {
    fatherId ??= parentId;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gender': gender,
        'description': description,
        'fatherId': fatherId,
        'motherId': motherId,
        'spouseIds': spouseIds,
        'birthDate': birthDate?.toIso8601String(),
        'deathDate': deathDate?.toIso8601String(),
      };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? json['fullName'] as String? ?? '',
        gender: json['gender'] as String? ?? 'unknown',
        description: json['description'] as String? ?? '',
        fatherId: (json['fatherId'] ?? json['parentId']) is num
            ? ((json['fatherId'] ?? json['parentId']) as num).toInt()
            : null,
        motherId: json['motherId'] is num
            ? (json['motherId'] as num).toInt()
            : null,
        spouseIds: (json['spouseIds'] as List<dynamic>? ?? [])
            .whereType<num>()
            .map((id) => id.toInt())
            .toList(),
        birthDate: _parseDate(json['birthDate']),
        deathDate: _parseDate(json['deathDate']),
      );

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
