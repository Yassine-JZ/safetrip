# SafeTrip

Application mobile multiplateforme de covoiturage étudiant — **Flutter, Dart et Firebase**
(cf. cahier des charges v4.0).

Ce dépôt contient l'**étape 1 : connexion et inscription** (UC01).

## Fonctionnalités de cette étape

- **Connexion** par e-mail / mot de passe, affichage/masquage du mot de passe,
  messages d'erreur en français, état de chargement.
- **Mot de passe oublié** : envoi d'un lien de réinitialisation (Firebase).
- **Vérification de l'adresse e-mail** : un lien d'activation est envoyé (en français)
  dès l'inscription ; tant qu'il n'est pas cliqué, l'utilisateur reste sur l'écran
  « Vérifiez votre e-mail » (renvoi du lien avec délai de 60 s, changement de compte).
  Seule une boîte e-mail réelle permet donc d'accéder à l'application.
- **Vérification du téléphone par SMS (désactivée pour le moment)** : écran prêt qui envoie
  un code à 6 chiffres au numéro (`+216XXXXXXXX`) ; Firebase refuse un numéro déjà rattaché
  à un autre compte. Activable avec `--dart-define=REQUIRE_PHONE=true` une fois l'envoi de
  SMS fonctionnel (voir plus bas). Sans cette option, seul l'e-mail est vérifié.
- **Mots de passe trop courants refusés** (`azerty123`, `password1`…).
- **Inscription unique, sans choix de rôle** : prénom, nom, e-mail, téléphone,
  mot de passe (avec indicateur de robustesse) et confirmation, acceptation des conditions.
  Le mode conducteur s'activera plus tard depuis le profil (UC12).
- **Données séparées** : profil public dans `users/{uid}`, e-mail et téléphone privés
  dans `users_private/{uid}` (cahier des charges §7.3). Règles dans `firestore.rules`.
- Mise en page responsive : panneau de présentation sur grand écran, formulaire seul sur mobile.
- **Profil (UC02)** : nom, photo facultative, e-mail et téléphone en lecture seule,
  changement de mot de passe.
- **Véhicule et mode conducteur (UC12)** : marque, matricule et places passagers.
  Le matricule n'est lisible que par le propriétaire et les administrateurs.
  La désactivation est refusée si un trajet à venir a des réservations acceptées
  ou si un trajet est en cours (ces trajets arrivent avec UC13 ; le contrôle est
  déjà branché).
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

### Vérification par SMS (optionnelle)

1. Console → **Authentication → Méthode de connexion → Téléphone** : activer, et ajouter
   des **numéros de test** (numéro + code fixe) pour essayer sans envoyer de vrai SMS.
2. Android : ajouter les empreintes **SHA-1** et **SHA-256** de la clé de signature dans
   Paramètres du projet → Vos applications → application Android.
3. Lancer avec `--dart-define=REQUIRE_PHONE=true` ; en cas d'échec, la cause exacte
   s'affiche dans le terminal (`SafeTrip SMS: …`).
4. Dans `firestore.rules`, ajouter `confirmedPhone() != null` à `verified()`.
5. En mode démo, le code SMS est `123456`.

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
    │   └── presentation/         # AuthController, LoginPage, RegisterPage, VerifyEmailPage, widgets
    ├── home/                     # accueil et barre de navigation
    └── profile/                  # profil, véhicule, mode conducteur (UC02, UC12)
```

## Feuille de route (sprints du cahier des charges)

| Étape | Contenu |
|------|---------|
| 1 ✅ | Connexion, inscription, mot de passe oublié, vérification de l'e-mail |
| 2 ✅ | Profil, véhicule, activation / désactivation du mode conducteur (UC02, UC12) |
| 3 | Fil d'offres, publication et recherche de trajets (UC08, UC13) |
| 4 | Réservations atomiques via Cloud Functions, cycle du trajet (UC09, UC14, UC16, UC17) |
| 5 | Notifications FCM, historique, évaluations (UC03, UC04, UC07) |
| 6 | SOS avec instantané GPS, signalements, espace administrateur, journal d'accès |
| Phase 2 | Demandes de trajet, propositions, matching |
