/// Minimal stand‑in for user model used by routing logic.
///
/// In the actual application the user model would contain many more
/// properties pulled from Firestore. Here we only include the role
/// necessary for determining which dashboard to display.
enum UserRole { teacher, student, admin }

class UserModel {
  final UserRole? role;
  const UserModel({this.role});
}