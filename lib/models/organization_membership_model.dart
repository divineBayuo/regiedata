class OrganizationMembershipModel {
  final String id;
  final String userId;
  final String organizationId;
  final String role;
  final bool isApproved;
  final DateTime joinedAt;
  final Map<String, dynamic>? personalData;

  OrganizationMembershipModel({
    required this.id,
    required this.userId,
    required this.organizationId,
    required this.role,
    required this.isApproved,
    required this.joinedAt,
    this.personalData,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'organizationId': organizationId,
      'role': role,
      'isApproved': isApproved,
      'joinedAt': joinedAt.toIso8601String(),
      'personalData': personalData,
    };
  }

  factory OrganizationMembershipModel.fromMap(
      Map<String, dynamic> map, String id) {
    return OrganizationMembershipModel(
      id: id,
      userId: map['userId'] ?? '',
      organizationId: map['organizationId'] ?? '',
      role: map['role'] ?? 'user',
      isApproved: map['isApproved'] ?? false,
      joinedAt: DateTime.parse(map['joinedAt']),
      personalData: map['personalData'],
    );
  }
}
