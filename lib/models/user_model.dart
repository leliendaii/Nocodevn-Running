enum UserRole { user, admin }

class AppUser {
  final String id;
  final String name;
  final String username;
  final String email;
  final UserRole role;
  final String avatarUrl;

  const AppUser({
    required this.id,
    required this.name,
    this.username = '',
    required this.email,
    required this.role,
    this.avatarUrl = '',
  });

  bool get isAdmin => role == UserRole.admin;

  String get displayHandle => username.isNotEmpty ? '@$username' : email;
}
