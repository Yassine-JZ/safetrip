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
    return null;
  }

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
