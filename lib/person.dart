
class Person {
  final int id;
  String name;
  String gender;

  // Quan hệ gia đình
  int? fatherId;
  int? motherId;
  List<int> spouseIds;

  // Ngày tháng
  DateTime? birthDate;
  DateTime? deathDate;

  // Tương thích với code hiện tại đang sử dụng parentId
  int? get parentId => fatherId;

  set parentId(int? value) {
    fatherId = value;
  }

  Person({
    required this.id,
    required this.name,
    required this.gender,
    int? parentId,
    int? fatherId,
    this.motherId,
    List<int>? spouseIds,
    this.birthDate,
    this.deathDate,
  })  : fatherId = fatherId ?? parentId,
        spouseIds = spouseIds ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'fatherId': fatherId,
      'motherId': motherId,
      'spouseIds': spouseIds,
      'birthDate': birthDate?.toIso8601String(),
      'deathDate': deathDate?.toIso8601String(),
    };
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as int,
      name: json['name'] as String,
      gender: json['gender'] as String,
      fatherId: json['fatherId'] as int? ??
          json['parentId'] as int?,
      motherId: json['motherId'] as int?,
      spouseIds: (json['spouseIds'] as List<dynamic>?)
              ?.map((id) => id as int)
              .toList() ??
          [],
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.parse(json['birthDate'] as String),
      deathDate: json['deathDate'] == null
          ? null
          : DateTime.parse(json['deathDate'] as String),
    );
  }
}
