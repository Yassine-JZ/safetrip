class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final _tnPhoneRegex = RegExp(r'^(\+216)?[2-9]\d{7}$');

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label est obligatoire';
    return null;
  }

  static String? name(String? value, String label) {
    final err = required(value, label);
    if (err != null) return err;
    if (value!.trim().length < 2) return '$label trop court';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'L\'e-mail est obligatoire';
    }
    if (!_emailRegex.hasMatch(value.trim())) return 'Adresse e-mail invalide';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le téléphone est obligatoire';
    }
    final normalized = value.replaceAll(RegExp(r'[\s.-]'), '');
    if (!_tnPhoneRegex.hasMatch(normalized)) {
      return 'Numéro tunisien à 8 chiffres attendu';
    }
    return null;
  }

  /// E.164 form (`+216XXXXXXXX`), also used as the uniqueness key.
  static String normalizePhone(String value) {
    final compact = value.replaceAll(RegExp(r'[\s.-]'), '');
    return compact.startsWith('+216') ? compact : '+216$compact';
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est obligatoire';
    }
    return null;
  }

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est obligatoire';
    }
    if (value.length < 8) return 'Au moins 8 caractères';
    if (!value.contains(RegExp(r'[A-Za-z]')) ||
        !value.contains(RegExp(r'\d'))) {
      return 'Doit contenir des lettres et des chiffres';
    }
    if (_commonPasswords.contains(value.toLowerCase())) {
      return 'Mot de passe trop courant, choisissez-en un autre';
    }
    return null;
  }

  // Passwords that pass the format rules but are among the first tried by
  // attackers (international and local variants).
  static const _commonPasswords = {
    'password1',
    'password12',
    'password123',
    'passw0rd',
    'p4ssw0rd',
    'motdepasse1',
    'motdepasse123',
    'azerty123',
    'azerty1234',
    'azertyuiop1',
    'qwerty123',
    'qwerty1234',
    'qwertyuiop1',
    'abc12345',
    'abcd1234',
    'abc123456',
    '1234abcd',
    '12345abc',
    '123456abc',
    '12345678a',
    'a1234567',
    'a12345678',
    'aa123456',
    'aa12345678',
    'admin123',
    'admin1234',
    'welcome1',
    'welcome123',
    'iloveyou1',
    'iloveyou123',
    'bonjour1',
    'bonjour123',
    'soleil123',
    'loulou123',
    'chouchou1',
    'doudou123',
    'tunisie1',
    'tunisie123',
    'tunis123',
    'tunisia123',
    'safetrip1',
    'safetrip123',
    'safetrip2026',
    'etudiant1',
    'etudiant123',
    'student123',
    'football1',
    'football123',
    'test1234',
    'test12345',
  };

  /// 0 (vide) à 4 (fort).
  static int passwordStrength(String value) {
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= 8) score++;
    if (value.contains(RegExp(r'[a-z]')) && value.contains(RegExp(r'[A-Z]'))) {
      score++;
    }
    if (value.contains(RegExp(r'\d'))) score++;
    if (value.contains(RegExp(r'[^A-Za-z0-9]'))) score++;
    return score.clamp(1, 4);
  }
}
