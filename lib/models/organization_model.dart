class OrganizationModel {
  final String id;
  final String name;
  final String code;
  final String createdBy;
  final DateTime createdAt;
  final Map<String, dynamic>? settings;

  OrganizationModel(
      {required this.id,
      required this.name,
      required this.code,
      required this.createdBy,
      required this.createdAt,
      this.settings});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'settings': settings,
    };
  }

  factory OrganizationModel.fromMap(Map<String, dynamic> map, String id) {
    return OrganizationModel(
      id: id,
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      settings: map['settings'],
    );
  }
}
