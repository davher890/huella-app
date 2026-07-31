class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.role,
  });

  final String id;
  final String email;
  final String role;

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as String,
        email: json['email'] as String? ?? '(sin email)',
        role: json['role'] as String? ?? 'user',
      );
}
