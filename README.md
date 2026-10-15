# SafeTrip

Application mobile multiplateforme de covoiturage étudiant — **Flutter, Dart et Firebase**
(cf. cahier des charges v4.0).

Ce dépôt contient l'**étape 1 : connexion et inscription** (UC01).

## Fonctionnalités de cette étape

- **Connexion** par e-mail / mot de passe, affichage/masquage du mot de passe,
  messages d'erreur en français, état de chargement.
- **Mot de passe oublié** : envoi d'un lien de réinitialisation (Firebase).
- **Inscription unique, sans choix de rôle** : prénom, nom, e-mail, téléphone,
  mot de passe (avec indicateur de robustesse) et confirmation, acceptation des conditions.
  Le mode conducteur s'activera plus tard depuis le profil (UC12).
- **Données séparées** : profil public dans `users/{uid}`, e-mail et téléphone privés
  dans `users_private/{uid}` (cahier des charges §7.3). Règles dans `firestore.rules`.
- Mise en page responsive : panneau de présentation sur grand écran, formulaire seul sur mobile.
- **Mode démo** sans Firebase (comptes en mémoire) : `demo@safetrip.tn` / `Demo1234`.

## Lancer le projet

Prérequis : [Flutter](https://docs.flutter.dev/get-started/install) 3.47+ (stable) et,
pour Android, le NDK 28.2 (Android Studio → SDK Manager → SDK Tools → NDK (Side by side)).

Le projet Flutter se trouve dans le dossier `app/` : toutes les commandes `flutter`
se lancent depuis ce dossier.

```bash
cd app
flutter pub get

# Mode démo (aucune configuration Firebase nécessaire)
flutter run -d chrome --web-port 47321
# ou sur un émulateur / téléphone
flutter run
```

### Brancher Firebase

1. Créer un projet sur la [console Firebase](https://console.firebase.google.com), activer
   **Authentication → E-mail/Mot de passe** et **Cloud Firestore**.
2. Installer les outils puis générer `app/lib/firebase_options.dart` (depuis `app/`) :
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
3. Déployer les règles : `firebase deploy --only firestore:rules`
4. Lancer avec Firebase :
   ```bash
   flutter run --dart-define=USE_FIREBASE=true
   ```

## Tests

```bash
cd app
flutter analyze
flutter test
```

## Structure

```
safetrip/
├── README.md
└── app/                          # projet Flutter (pubspec.yaml, android/, ios/, web/)
    ├── firestore.rules
    ├── test/
    └── lib/
```

```
app/lib/
├── main.dart                     # choix Firebase / démo
├── app.dart                      # MaterialApp + AuthGate (redirection selon session)
├── firebase_options.dart         # remplacé par `flutterfire configure`
├── core/
│   ├── theme/app_theme.dart
│   └── utils/validators.dart
└── features/
    ├── auth/
    │   ├── data/                 # AuthRepository, implémentations Firebase et démo
    │   └── presentation/         # AuthController, LoginPage, RegisterPage, widgets
    └── home/home_page.dart       # écran provisoire après connexion
```

## Feuille de route (sprints du cahier des charges)

| Étape | Contenu |
|------|---------|
| 1 ✅ | Connexion, inscription, mot de passe oublié |
| 2 | Profil, véhicule, activation / désactivation du mode conducteur (UC02, UC12) |
| 3 | Fil d'offres, publication et recherche de trajets (UC08, UC13) |
| 4 | Réservations atomiques via Cloud Functions, cycle du trajet (UC09, UC14, UC16, UC17) |
| 5 | Notifications FCM, historique, évaluations (UC03, UC04, UC07) |
| 6 | SOS avec instantané GPS, signalements, espace administrateur, journal d'accès |
| Phase 2 | Demandes de trajet, propositions, matching |
