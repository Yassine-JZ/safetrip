/// Utilisateur SafeTrip authentifié.
///
/// Le compte est unique : aucune notion de rôle Conducteur / Passager ici.
/// La capacité conducteur s'active plus tard depuis le profil (UC12) et les
/// droits administrateur sont gérés côté serveur (custom claims), jamais dans
/// le profil.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.emailVerified = false,
  });

  final String uid;
  final String email;
  final String? displayName;

  /// Faux tant que l'utilisateur n'a pas cliqué sur le lien reçu par e-mail.
  final bool emailVerified;
}

class RegistrationData {
  const RegistrationData({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;

  String get displayName => '$firstName $lastName';
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> register(RegistrationData data);

  Future<void> sendPasswordReset(String email);

  Future<void> sendEmailVerification();

  /// Fetches the latest account state (e.g. after the verification link was
  /// clicked in another app).
  Future<AppUser?> reloadUser();

  Future<void> signOut();
}
