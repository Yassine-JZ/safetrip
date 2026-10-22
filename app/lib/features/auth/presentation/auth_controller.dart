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
  bool get phoneVerified => _user?.phoneVerified ?? false;

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
    final user = await _guard(_repository.reloadUser);
    if (user != null) _setUser(user);
    return user?.emailVerified ?? false;
  }

  Future<String?> registeredPhone() => _repository.registeredPhone();

  /// Returns `true` when the number was confirmed without typing a code.
  Future<bool> sendPhoneCode(String phone) async {
    final autoVerified = await _run(() => _repository.sendPhoneCode(phone));
    final current = _repository.currentUser;
    if (autoVerified && current != null) _setUser(current);
    return autoVerified;
  }

  Future<void> confirmPhoneCode(String code) async {
    _setUser(await _run(() => _repository.confirmPhoneCode(code)));
  }

  Future<void> changePassword(String currentPassword, String newPassword) =>
      _run(
        () => _repository.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      );

  Future<void> signOut() => _repository.signOut();

  void _setUser(AppUser user) {
    _user = user;
    notifyListeners();
  }

  /// Throws [AuthFailure] so the calling page can show the message.
  Future<T> _run<T>(Future<T> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      return await _guard(action);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('Une erreur est survenue. Réessayez.');
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
