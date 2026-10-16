import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/validators.dart';
import '../data/auth_repository.dart';
import '../data/mock_auth_repository.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/error_banner.dart';
import 'widgets/info_banner.dart';

/// Second activation step (UC01): the number must receive an SMS code, so
/// it really exists and belongs to the user. Firebase attaches a number to a
/// single account.
class VerifyPhonePage extends StatefulWidget {
  const VerifyPhonePage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<VerifyPhonePage> createState() => _VerifyPhonePageState();
}

class _VerifyPhonePageState extends State<VerifyPhonePage> {
  static const _resendCooldown = 60;

  final _phoneFormKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  String? _sentTo;
  String? _error;
  String? _info;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final phone = await context.read<AuthController>().registeredPhone();
    if (!mounted || phone == null || _phoneCtrl.text.isNotEmpty) return;
    _phoneCtrl.text = phone.replaceFirst('+216', '');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _info = null;
    });
    if (_sentTo == null && !_phoneFormKey.currentState!.validate()) return;
    final phone = _sentTo ?? Validators.normalizePhone(_phoneCtrl.text);
    try {
      final autoVerified = await context.read<AuthController>().sendPhoneCode(
        phone,
      );
      if (!mounted || autoVerified) return;
      setState(() {
        _sentTo = phone;
        _info = 'Code envoyé par SMS au ${_display(phone)}.';
      });
      _startCooldown();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _info = null;
    });
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Saisissez les 6 chiffres du code reçu.');
      return;
    }
    try {
      await context.read<AuthController>().confirmPhoneCode(code);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _changeNumber() {
    _timer?.cancel();
    setState(() {
      _sentTo = null;
      _secondsLeft = 0;
      _error = null;
      _info = null;
      _codeCtrl.clear();
    });
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

  static String _display(String phone) {
    final local = phone.replaceFirst('+216', '');
    if (local.length != 8) return phone;
    return '+216 ${local.substring(0, 2)} ${local.substring(2, 5)} '
        '${local.substring(5)}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final busy = auth.busy;
    final sentTo = _sentTo;

    return AuthScaffold(
      title: 'Vérifiez votre numéro',
      subtitle: sentTo == null
          ? 'Dernière étape : nous envoyons un code par SMS pour confirmer '
                'que ce numéro existe et vous appartient.'
          : 'Saisissez le code à 6 chiffres reçu au ${_display(sentTo)}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ErrorBanner(message: _error!),
          if (_info != null) InfoBanner(message: _info!),
          if (widget.demoMode) ...[
            const HintCard(
              icon: Icons.sms_outlined,
              text:
                  'Mode démo : aucun SMS n\'est envoyé. Le code est '
                  '${MockAuthRepository.demoSmsCode}.',
            ),
            const SizedBox(height: 20),
          ],
          if (sentTo == null) ..._phoneStep(busy) else ..._codeStep(busy),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('phone_sign_out'),
            onPressed: busy ? null : auth.signOut,
            child: const Text('Utiliser un autre compte'),
          ),
        ],
      ),
    );
  }

  List<Widget> _phoneStep(bool busy) => [
    Form(
      key: _phoneFormKey,
      child: TextFormField(
        key: const Key('phone_number'),
        controller: _phoneCtrl,
        enabled: !busy,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
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
        onFieldSubmitted: (_) => _sendCode(),
      ),
    ),
    const SizedBox(height: 24),
    FilledButton(
      key: const Key('phone_send'),
      onPressed: busy ? null : _sendCode,
      child: busy ? const _ButtonSpinner() : const Text('Recevoir le code'),
    ),
  ];

  List<Widget> _codeStep(bool busy) => [
    TextField(
      key: const Key('phone_code'),
      controller: _codeCtrl,
      enabled: !busy,
      autofocus: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: const TextStyle(fontSize: 24, letterSpacing: 10),
      decoration: const InputDecoration(
        labelText: 'Code reçu par SMS',
        counterText: '',
      ),
      onSubmitted: (_) => _confirm(),
    ),
    const SizedBox(height: 24),
    FilledButton(
      key: const Key('phone_confirm'),
      onPressed: busy ? null : _confirm,
      child: busy ? const _ButtonSpinner() : const Text('Valider'),
    ),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      key: const Key('phone_resend'),
      onPressed: busy || _secondsLeft > 0 ? null : _sendCode,
      icon: const Icon(Icons.refresh),
      label: Text(
        _secondsLeft > 0
            ? 'Renvoyer le code (${_secondsLeft}s)'
            : 'Renvoyer le code',
      ),
    ),
    TextButton(
      key: const Key('phone_change'),
      onPressed: busy ? null : _changeNumber,
      child: const Text('Modifier le numéro'),
    ),
  ];
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
    );
  }
}
