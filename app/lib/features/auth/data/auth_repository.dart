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
    this.phoneNumber,
  });

  final String uid;
  final String email;
  final String? displayName;

  /// Faux tant que l'utilisateur n'a pas cliqué sur le lien reçu par e-mail.
  final bool emailVerified;

  /// Numéro confirmé par code SMS (format `+216XXXXXXXX`), sinon `null`.
  final String? phoneNumber;

  bool get phoneVerified => phoneNumber != null;

  AppUser copyWith({bool? emailVerified, String? phoneNumber}) => AppUser(
    uid: uid,
    email: email,
    displayName: displayName,
    emailVerified: emailVerified ?? this.emailVerified,
    phoneNumber: phoneNumber ?? this.phoneNumber,
  );
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

  /// Number typed at sign-up, used to prefill the SMS step.
  Future<String?> registeredPhone();

  /// Sends a 6-digit SMS code to [phone] (`+216XXXXXXXX`). Returns `true`
  /// when the device confirmed the number on its own (Android auto-retrieval)
  /// and no code needs to be typed.
  Future<bool> sendPhoneCode(String phone);

  /// Attaches the confirmed number to the account. A number can belong to a
  /// single account: Firebase refuses it otherwise.
  Future<AppUser> confirmPhoneCode(String code);

  Future<void> signOut();
}
