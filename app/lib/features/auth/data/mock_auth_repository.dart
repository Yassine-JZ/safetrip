import 'dart:async';

import 'auth_repository.dart';

/// In-memory implementation used when Firebase is not configured
/// (run without `--dart-define=USE_FIREBASE=true`).
class MockAuthRepository implements AuthRepository {
  MockAuthRepository() {
    _accounts['demo@safetrip.tn'] = _MockAccount(
      user: const AppUser(
        uid: 'demo-uid',
        email: 'demo@safetrip.tn',
        displayName: 'Amine Ben Salah',
      ),
      password: 'Demo1234',
    );
  }

  static const demoEmail = 'demo@safetrip.tn';
  static const demoPassword = 'Demo1234';
  static const _latency = Duration(milliseconds: 900);

  final _accounts = <String, _MockAccount>{};
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

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
    _setUser(user);
    return user;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future<void>.delayed(_latency);
  }

  @override
  Future<void> signOut() async {
    _setUser(null);
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
