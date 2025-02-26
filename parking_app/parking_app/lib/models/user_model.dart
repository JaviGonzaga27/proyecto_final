class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? photoURL;
  final String role;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.photoURL,
    required this.role,
    required this.createdAt,
    this.updatedAt,
  });

  String get fullName => '$firstName $lastName';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      photoURL: json['photoURL'],
      role: json['role'] ?? 'user',
      createdAt:
          json['createdAt'] != null
              ? (json['createdAt'] is DateTime
                  ? json['createdAt']
                  : DateTime.parse(json['createdAt']))
              : DateTime.now(),
      updatedAt:
          json['updatedAt'] != null
              ? (json['updatedAt'] is DateTime
                  ? json['updatedAt']
                  : DateTime.parse(json['updatedAt']))
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'photoURL': photoURL,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
