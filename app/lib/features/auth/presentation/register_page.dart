import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/error_banner.dart';

/// Inscription unique (UC01) : aucun choix Conducteur / Passager.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _acceptedTerms = false;
  bool _termsError = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl,
      _lastNameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _passwordCtrl,
      _confirmCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    setState(() {
      _error = null;
      _termsError = !_acceptedTerms;
    });
    if (!valid || !_acceptedTerms) return;

    try {
      await context.read<AuthController>().register(
        RegistrationData(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.replaceAll(RegExp(r'[\s.-]'), ''),
          password: _passwordCtrl.text,
        ),
      );
      // The AuthGate swaps the root to the home screen; drop this route too.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthController>().busy;
    final theme = Theme.of(context);

    return AuthScaffold(
      title: 'Créer un compte',
      subtitle:
          'Un seul compte pour réserver une place ou proposer vos '
          'propres trajets.',
      showBack: true,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ErrorBanner(message: _error!),
              LayoutBuilder(
                builder: (context, c) {
                  final first = TextFormField(
                    key: const Key('register_first_name'),
                    controller: _firstNameCtrl,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    decoration: const InputDecoration(
                      labelText: 'Prénom',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => Validators.name(v, 'Le prénom'),
                  );
                  final last = TextFormField(
                    key: const Key('register_last_name'),
                    controller: _lastNameCtrl,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (v) => Validators.name(v, 'Le nom'),
                  );
                  if (c.maxWidth < 380) {
                    return Column(
                      children: [first, const SizedBox(height: 16), last],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: first),
                      const SizedBox(width: 12),
                      Expanded(child: last),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('register_email'),
                controller: _emailCtrl,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  hintText: 'prenom.nom@exemple.tn',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: Validators.email,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('register_phone'),
                controller: _phoneCtrl,
                enabled: !busy,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d+ ]')),
                  LengthLimitingTextInputFormatter(13),
                ],
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  hintText: '20 123 456',
                  prefixIcon: Icon(Icons.phone_outlined),
                  prefixText: '+216 ',
                  helperText: 'Privé : jamais affiché dans le fil.',
                ),
                validator: Validators.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('register_password'),
                controller: _passwordCtrl,
                enabled: !busy,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Afficher' : 'Masquer',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: Validators.newPassword,
              ),
              _PasswordStrength(password: _passwordCtrl.text),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('register_confirm'),
                controller: _confirmCtrl,
                enabled: !busy,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Confirmez le mot de passe';
                  }
                  if (v != _passwordCtrl.text) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.directions_car_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vous avez un véhicule ? Vous pourrez activer le mode '
                        'conducteur depuis votre profil après l\'inscription.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                key: const Key('register_terms'),
                value: _acceptedTerms,
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        _acceptedTerms = v ?? false;
                        if (_acceptedTerms) _termsError = false;
                      }),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'J\'accepte les conditions d\'utilisation et la politique '
                  'de confidentialité de SafeTrip.',
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: _termsError
                    ? Text(
                        'Vous devez accepter les conditions pour continuer',
                        style: TextStyle(color: theme.colorScheme.error),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('register_submit'),
                onPressed: busy ? null : _submit,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Créer mon compte'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Déjà inscrit ?',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: const Text('Se connecter'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.password});

  final String password;

  static const _labels = ['', 'Faible', 'Moyen', 'Bon', 'Fort'];
  static const _colors = [
    Colors.transparent,
    Color(0xFFDC2626),
    Color(0xFFF59E0B),
    Color(0xFF65A30D),
    AppColors.primary,
  ];

  @override
  Widget build(BuildContext context) {
    final score = Validators.passwordStrength(password);
    if (score == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
      child: Row(
        children: [
          for (var i = 1; i <= 4; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: i <= score ? _colors[score] : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            _labels[score],
            style: TextStyle(fontSize: 12, color: _colors[score]),
          ),
        ],
      ),
    );
  }
}
