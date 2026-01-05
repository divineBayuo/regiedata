class UserModel {
  final String uid;
  final String email;
  final String firstname;
  final String surname;
  final String? othername;
  final String gender;
  final DateTime dateOfBirth;
  final String phoneNumber;
  final String? residence;
  final String? occupation;
  final bool isWorking;
  final bool isSchooling;
  final String? placeOfWork;
  final String? placeOfSchool;
  final String? courseOfStudy;
  final String? family;
  final String? department;
  final String role;
  final bool isApproved;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this. firstname,
    required this.surname,
    this.othername,
    required this.gender,
    required this.dateOfBirth,
    required this.phoneNumber,
    this.residence,
    this.occupation,
    this.isWorking = false,
    this.isSchooling = false,
    this.placeOfWork,
    this.placeOfSchool,
    this.courseOfStudy,
    this.family,
    this.department,
    this.role = 'user',
    this.isApproved = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return{
      'uid': uid,
      'email': email,
      'firstname': firstname,
      'surname': surname,
      'othername': othername,
      'gender': gender,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'phoneNumber': phoneNumber,
      'residence': residence,
      'occupation': occupation,
      'isWorking': isWorking,
      'isSchooling': isSchooling,
      'placeOfWork': placeOfWork,
      'placeOfSchool': placeOfSchool,
      'courseOfStudy': courseOfStudy,
      'family': family,
      'department': department,
      'role': role,
      'isApproved': isApproved,
      'createdAt': createdAt.toIso8601String()
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map){
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      firstname: map['firstname'] ?? '',
      surname: map['surname'] ?? '',
      othername: map['othername'],
      gender: map['gender'] ?? '',
      dateOfBirth: map['dateOfBirth'] != null ? DateTime.parse(map['dateOfBirth']) : DateTime.now(),
      phoneNumber: map['phoneNumber'] ?? '',
      residence: map['residence'],
      occupation: map['occupation'],
      isWorking: map['isWorking'] ?? false,
      isSchooling: map['isSchooling'] ?? false,
      placeOfWork: map['placeOfWork'],
      placeOfSchool: map['placeOfSchool'],
      courseOfStudy: map['courseOfStudy'],
      family: map['family'],
      department: map['department'],
      role: map['role'] ?? 'user',
      isApproved: map['isApproved'] ??false,
      createdAt: DateTime.parse(map['createdAt'])
    );
  }
}