import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  AuthController(this._repository) {
    _subscription = _repository.authStateChanges().listen((user) {
      _user = user;
      _status = user == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
      notifyListeners();
    });
  }

  final AuthRepository _repository;
  late final StreamSubscription<AppUser?> _subscription;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _busy = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get busy => _busy;
  bool get emailVerified => _user?.emailVerified ?? false;

  Future<void> signIn(String email, String password) =>
      _run(() => _repository.signIn(email: email, password: password));

  Future<void> register(RegistrationData data) =>
      _run(() => _repository.register(data));

  Future<void> sendPasswordReset(String email) =>
      _run(() => _repository.sendPasswordReset(email));

  Future<void> resendEmailVerification() =>
      _run(_repository.sendEmailVerification);

  /// Returns whether the address is now verified. Throws [AuthFailure].
  Future<bool> checkEmailVerified() async {
    final AppUser? user;
    try {
      user = await _repository.reloadUser();
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('Une erreur est survenue. Réessayez.');
    }
    if (user != null) {
      _user = user;
      notifyListeners();
    }
    return user?.emailVerified ?? false;
  }

  Future<void> signOut() => _repository.signOut();

  /// Throws [AuthFailure] so the calling page can show the message.
  Future<void> _run(Future<Object?> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('Une erreur est survenue. Réessayez.');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
