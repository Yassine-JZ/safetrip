import 'dart:async';

import 'auth_repository.dart';

/// In-memory implementation used when Firebase is not configured
/// (run without `--dart-define=USE_FIREBASE=true`).
class MockAuthRepository implements AuthRepository {
  MockAuthRepository() {
    _accounts[demoEmail] = _MockAccount(
      user: const AppUser(
        uid: 'demo-uid',
        email: demoEmail,
        displayName: 'Amine Ben Salah',
        emailVerified: true,
        phoneNumber: demoPhone,
      ),
      password: demoPassword,
    );
    _phoneOwners[demoPhone] = 'demo-uid';
    _registeredPhones['demo-uid'] = demoPhone;
  }

  static const demoEmail = 'demo@safetrip.tn';
  static const demoPassword = 'Demo1234';
  static const demoPhone = '+21698111222';
  static const demoSmsCode = '123456';
  static const _latency = Duration(milliseconds: 900);

  final _accounts = <String, _MockAccount>{};
  final _phoneOwners = <String, String>{};
  final _registeredPhones = <String, String>{};
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;
  String? _pendingPhone;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_latency);
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw const AuthFailure('E-mail ou mot de passe incorrect.');
    }
    _setUser(account.user);
    return account.user;
  }

  @override
  Future<AppUser> register(RegistrationData data) async {
    await Future<void>.delayed(_latency);
    final key = data.email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw const AuthFailure('Un compte existe déjà avec cet e-mail.');
    }
    final user = AppUser(
      uid: 'mock-${DateTime.now().microsecondsSinceEpoch}',
      email: key,
      displayName: data.displayName,
    );
    _accounts[key] = _MockAccount(user: user, password: data.password);
    _registeredPhones[user.uid] = data.phone;
    _setUser(user);
    return user;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future<void>.delayed(_latency);
  }

  /// In demo mode no e-mail is sent: the next [reloadUser] behaves as if the
  /// link had been clicked.
  @override
  Future<void> sendEmailVerification() async {
    await Future<void>.delayed(_latency);
  }

  @override
  Future<AppUser?> reloadUser() async {
    await Future<void>.delayed(_latency);
    final current = _current;
    if (current == null) return null;
    return _update(current.copyWith(emailVerified: true));
  }

  @override
  Future<String?> registeredPhone() async {
    final current = _current;
    return current == null ? null : _registeredPhones[current.uid];
  }

  /// In demo mode no SMS is sent: the code is always [demoSmsCode].
  @override
  Future<bool> sendPhoneCode(String phone) async {
    await Future<void>.delayed(_latency);
    _pendingPhone = phone;
    return false;
  }

  @override
  Future<AppUser> confirmPhoneCode(String code) async {
    await Future<void>.delayed(_latency);
    final current = _current;
    final phone = _pendingPhone;
    if (current == null || phone == null) {
      throw const AuthFailure('Session expirée. Reconnectez-vous.');
    }
    if (code != demoSmsCode) throw const AuthFailure('Code incorrect.');
    final owner = _phoneOwners[phone];
    if (owner != null && owner != current.uid) {
      throw const AuthFailure(
        'Ce numéro est déjà associé à un autre compte SafeTrip.',
      );
    }
    _phoneOwners[phone] = current.uid;
    final user = _update(current.copyWith(phoneNumber: phone));
    _controller.add(user);
    return user;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future<void>.delayed(_latency);
    final current = _current;
    final account = current == null ? null : _accounts[current.email];
    if (account == null) {
      throw const AuthFailure('Session expirée. Reconnectez-vous.');
    }
    if (account.password != currentPassword) {
      throw const AuthFailure('Mot de passe actuel incorrect.');
    }
    _accounts[current!.email] = _MockAccount(
      user: account.user,
      password: newPassword,
    );
  }

  /// Used by the demo profile repository when the name is edited.
  void updateDisplayName(String displayName) {
    final current = _current;
    if (current == null) return;
    final user = _update(
      AppUser(
        uid: current.uid,
        email: current.email,
        displayName: displayName,
        emailVerified: current.emailVerified,
        phoneNumber: current.phoneNumber,
      ),
    );
    _controller.add(user);
  }

  @override
  Future<void> signOut() async {
    _setUser(null);
  }

  AppUser _update(AppUser user) {
    _accounts[user.email] = _MockAccount(
      user: user,
      password: _accounts[user.email]!.password,
    );
    _current = user;
    return user;
  }

  void _setUser(AppUser? user) {
    _current = user;
    _controller.add(user);
  }
}

class _MockAccount {
  const _MockAccount({required this.user, required this.password});

  final AppUser user;
  final String password;
}
