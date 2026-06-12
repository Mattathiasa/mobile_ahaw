/// Mirrors the web's User type from src/types/index.ts
class UserModel {
  final String id;
  final String username;
  final String email;
  final String role;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? fullNameEnglish;
  final String? fullNameAmharic;
  final String? phone;
  final String? dateOfBirth;
  final String hierarchyLevel;
  final String? ministryType;
  final List<String>? churchRoles;
  final String? workSchool;
  final String? maritalStatus;
  final bool hasChildren;
  final int childrenCount;
  final String? gender;
  final Map<String, dynamic>? address;
  final dynamic createdAt;
  final dynamic updatedAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.fullName,
    this.fullNameEnglish,
    this.fullNameAmharic,
    this.phone,
    this.dateOfBirth,
    this.hierarchyLevel = 'HiyawanMahderat',
    this.ministryType,
    this.churchRoles,
    this.workSchool,
    this.maritalStatus,
    this.hasChildren = false,
    this.childrenCount = 0,
    this.gender,
    this.address,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromFirestore(String uid, Map<String, dynamic> data, String firebaseEmail) {
    final firstName = data['firstName'] as String?;
    final lastName = data['lastName'] as String?;
    final fullNameFromParts = (firstName != null || lastName != null)
        ? '${firstName ?? ''} ${lastName ?? ''}'.trim()
        : null;

    return UserModel(
      id: uid,
      username: data['username'] as String? ?? firebaseEmail.split('@')[0],
      email: data['email'] as String? ?? firebaseEmail,
      role: data['role'] as String? ?? 'user',
      firstName: firstName,
      lastName: lastName,
      fullName: data['fullNameEnglish'] as String? ??
          data['fullName'] as String? ??
          fullNameFromParts ??
          'Church Member',
      fullNameEnglish: data['fullNameEnglish'] as String?,
      fullNameAmharic: data['fullNameAmharic'] as String?,
      phone: data['phone'] as String? ?? data['phoneNumber'] as String?,
      dateOfBirth: data['dateOfBirth'] as String?,
      hierarchyLevel: data['hierarchyLevel'] as String? ?? 'HiyawanMahderat',
      ministryType: data['ministryType'] is List
          ? (data['ministryType'] as List).join(', ')
          : data['ministryType'] as String?,
      churchRoles: data['churchRoles'] != null
          ? List<String>.from(data['churchRoles'])
          : null,
      workSchool: data['workSchool'] as String?,
      maritalStatus: data['maritalStatus'] as String?,
      hasChildren: data['hasChildren'] as bool? ?? false,
      childrenCount: (data['childrenCount'] as num?)?.toInt() ?? 0,
      gender: data['gender'] as String?,
      address: data['address'] as Map<String, dynamic>?,
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  /// Display name: prefer Amharic, then English, then email prefix
  String get displayName =>
      fullNameAmharic ?? fullNameEnglish ?? fullName ?? email.split('@')[0];

  /// Initials for avatar
  String get initials {
    final name = fullNameEnglish ?? fullName ?? email;
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
