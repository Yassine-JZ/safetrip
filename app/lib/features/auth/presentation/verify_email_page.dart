import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/error_banner.dart';

/// Shown to signed-in users whose address is not verified yet (UC01):
/// only a real mailbox can receive the activation link.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage>
    with WidgetsBindingObserver {
  static const _resendCooldown = 60;

  String? _error;
  String? _info;
  bool _checking = false;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user usually comes back from the mail app after clicking the link.
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      if (!silent) {
        _error = null;
        _info = null;
      }
    });
    try {
      final verified = await context
          .read<AuthController>()
          .checkEmailVerified();
      if (!mounted || verified || silent) return;
      setState(
        () => _error =
            'Adresse pas encore vérifiée. Ouvrez le lien reçu par e-mail '
            'puis réessayez.',
      );
    } on AuthFailure catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await context.read<AuthController>().resendEmailVerification();
      if (!mounted) return;
      setState(() => _info = 'Nouvel e-mail envoyé.');
      _startCooldown();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final email = auth.user?.email ?? '';
    final theme = Theme.of(context);
    final busy = auth.busy || _checking;

    return AuthScaffold(
      title: 'Vérifiez votre e-mail',
      subtitle:
          'Nous avons envoyé un lien d\'activation à $email. '
          'Cliquez dessus pour activer votre compte.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ErrorBanner(message: _error!),
          if (_info != null) _InfoBanner(message: _info!),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.demoMode
                        ? 'Mode démo : aucun e-mail n\'est envoyé. Appuyez '
                              'sur « J\'ai vérifié mon e-mail » pour simuler '
                              'le clic sur le lien.'
                        : 'Pas reçu ? Regardez dans le dossier Spam ou '
                              'Promotions, puis renvoyez l\'e-mail si besoin.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('verify_check'),
            onPressed: busy ? null : _check,
            child: _checking
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('J\'ai vérifié mon e-mail'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('verify_resend'),
            onPressed: busy || _secondsLeft > 0 ? null : _resend,
            icon: const Icon(Icons.refresh),
            label: Text(
              _secondsLeft > 0
                  ? 'Renvoyer l\'e-mail (${_secondsLeft}s)'
                  : 'Renvoyer l\'e-mail',
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('verify_sign_out'),
            onPressed: busy ? null : auth.signOut,
            child: const Text('Utiliser un autre compte'),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.green),
            ),
          ),
        ],
      ),
    );
  }
}
