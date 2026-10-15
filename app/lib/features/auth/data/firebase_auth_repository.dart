import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AppUser? _map(User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
        );

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);

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
        'phone': data.phone.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      return AppUser(
        uid: user.uid,
        email: user.email ?? data.email,
        displayName: data.displayName,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    } on FirebaseException {
      throw const AuthFailure(
        'Compte créé, mais le profil n\'a pas pu être enregistré. '
        'Réessayez depuis votre profil.',
      );
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

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
