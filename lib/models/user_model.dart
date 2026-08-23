enum UserRole { user, admin }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String avatarUrl;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl = '',
  });

  bool get isAdmin => role == UserRole.admin;
}
