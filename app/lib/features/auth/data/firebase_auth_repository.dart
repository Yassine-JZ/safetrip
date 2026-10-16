import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const _emailLanguage = 'fr';

  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmation;

  AppUser? _map(User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          emailVerified: user.emailVerified,
          phoneNumber: user.phoneNumber,
        );

  // userChanges (not authStateChanges) so that linking the phone number,
  // possibly in the background on Android, reaches the UI.
  @override
  Stream<AppUser?> authStateChanges() => _auth.userChanges().map(_map);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _map(cred.user)!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  @override
  Future<AppUser> register(RegistrationData data) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: data.email.trim(),
        password: data.password,
      );
      final user = cred.user!;
      await user.updateDisplayName(data.displayName);

      // Public profile and private contact data live in separate documents
      // so Firestore rules can expose the former without leaking the latter.
      // The phone stays unconfirmed until the SMS step.
      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(user.uid), {
        'firstName': data.firstName.trim(),
        'lastName': data.lastName.trim(),
        'photoUrl': null,
        'driverEnabled': false,
        'ratingAverage': null,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('users_private').doc(user.uid), {
        'email': data.email.trim(),
        'phone': data.phone,
        'createdAt': FieldValue.serverTimestamp(),
      });
      try {
        await batch.commit();
      } on FirebaseException {
        // Without its profile the account is unusable and would lock the
        // e-mail address, so it is removed.
        await _deleteQuietly(user);
        throw const AuthFailure(
          'Inscription impossible pour le moment. Réessayez.',
        );
      }

      try {
        await _auth.setLanguageCode(_emailLanguage);
        await user.sendEmailVerification();
      } on FirebaseAuthException {
        // The verification screen offers a resend button.
      }

      return AppUser(
        uid: user.uid,
        email: user.email ?? data.email,
        displayName: data.displayName,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  Future<void> _deleteQuietly(User user) async {
    try {
      await user.delete();
    } on FirebaseAuthException {
      await _auth.signOut();
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.setLanguageCode(_emailLanguage);
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _requireUser();
    try {
      await _auth.setLanguageCode(_emailLanguage);
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  @override
  Future<AppUser?> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;
      // Firestore rules read `email_verified` from the ID token, which keeps
      // the old value until it is refreshed.
      if (user != null && user.emailVerified) await user.getIdToken(true);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
    return _map(_auth.currentUser);
  }

  @override
  Future<String?> registeredPhone() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final snap = await _firestore
          .collection('users_private')
          .doc(user.uid)
          .get();
      return snap.data()?['phone'] as String?;
    } on FirebaseException {
      return null;
    }
  }

  @override
  Future<bool> sendPhoneCode(String phone) async {
    final user = _requireUser();
    await _auth.setLanguageCode(_emailLanguage);

    if (kIsWeb) {
      try {
        _webConfirmation = await user.linkWithPhoneNumber(phone);
        return false;
      } on FirebaseAuthException catch (e) {
        throw AuthFailure(_phoneMessageFor(e));
      }
    }

    final result = Completer<bool>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Android read the SMS itself. If the code screen is already shown,
        // the link still happens and userChanges updates the UI.
        try {
          await _link(credential);
          if (!result.isCompleted) result.complete(true);
        } on AuthFailure catch (e) {
          if (!result.isCompleted) result.completeError(e);
        }
      },
      verificationFailed: (e) {
        if (!result.isCompleted) {
          result.completeError(AuthFailure(_phoneMessageFor(e)));
        }
      },
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        if (!result.isCompleted) result.complete(false);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
    return result.future;
  }

  @override
  Future<AppUser> confirmPhoneCode(String code) async {
    final web = _webConfirmation;
    if (kIsWeb && web != null) {
      try {
        await web.confirm(code);
      } on FirebaseAuthException catch (e) {
        throw AuthFailure(_phoneMessageFor(e));
      }
      return _afterPhoneLinked();
    }
    final verificationId = _verificationId;
    if (verificationId == null) {
      throw const AuthFailure('Demandez d\'abord un code.');
    }
    return _link(
      PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      ),
    );
  }

  Future<AppUser> _link(PhoneAuthCredential credential) async {
    final user = _requireUser();
    if (user.phoneNumber == null) {
      try {
        await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        throw AuthFailure(_phoneMessageFor(e));
      }
    }
    return _afterPhoneLinked();
  }

  Future<AppUser> _afterPhoneLinked() async {
    final user = _requireUser();
    _verificationId = null;
    _webConfirmation = null;
    // The new `phone_number` claim is only in a refreshed ID token.
    await user.getIdToken(true);
    try {
      await _firestore.collection('users_private').doc(user.uid).update({
        'phone': user.phoneNumber,
      });
    } on FirebaseException {
      // Firebase Auth holds the confirmed number and enforces uniqueness;
      // this Firestore copy is only a convenience for the profile.
    }
    return _map(_auth.currentUser)!;
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Session expirée. Reconnectez-vous.');
    }
    return user;
  }

  @override
  Future<void> signOut() {
    _verificationId = null;
    _resendToken = null;
    _webConfirmation = null;
    return _auth.signOut();
  }

  static String _phoneMessageFor(FirebaseAuthException e) {
    final details = '${e.code} ${e.message}'.toUpperCase();
    if (details.contains('BILLING_NOT_ENABLED')) {
      return 'L\'envoi de SMS n\'est pas activé sur ce projet Firebase '
          '(offre Blaze requise). Utilisez un numéro de test.';
    }
    switch (e.code) {
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return 'Ce numéro est déjà associé à un autre compte SafeTrip.';
      case 'invalid-verification-code':
        return 'Code incorrect.';
      case 'session-expired':
      case 'code-expired':
        return 'Code expiré. Demandez un nouveau code.';
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide.';
      case 'quota-exceeded':
        return 'Limite de SMS atteinte pour aujourd\'hui. Réessayez demain.';
      case 'operation-not-allowed':
        return 'La vérification par SMS n\'est pas activée dans la console '
            'Firebase.';
      case 'app-not-authorized':
      case 'missing-client-identifier':
      case 'invalid-app-credential':
        return 'Application non reconnue par Firebase : ajoutez ses '
            'empreintes SHA-1 et SHA-256 dans la console.';
      default:
        return _messageFor(e.code);
    }
  }

  static String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Adresse e-mail invalide.';
      case 'user-disabled':
        return 'Ce compte a été suspendu. Contactez l\'administration.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet e-mail.';
      case 'weak-password':
        return 'Mot de passe trop faible.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      case 'network-request-failed':
        return 'Pas de connexion réseau. Vérifiez votre connexion.';
      default:
        return 'Une erreur est survenue. Réessayez.';
    }
  }
}
