import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../admin/data/admin_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/location_service.dart';
import '../data/sos_models.dart';

class SosSheet extends StatefulWidget {
  const SosSheet({super.key, required this.userName});

  final String userName;

  @override
  State<SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<SosSheet> {
  final _note = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    final auth = context.read<AuthController>().user!;
    final locationService = context.read<LocationService>();
    final admin = context.read<AdminRepository>();
    setState(() => _busy = true);
    try {
      final location = await locationService.currentSnapshot();
      final alert = await admin.sendSos(
        userId: auth.uid,
        userName: widget.userName,
        location: location,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('SOS envoyé'),
          content: Text(
            'Position : ${alert.latitude.toStringAsFixed(5)}, '
            '${alert.longitude.toStringAsFixed(5)}'
            '${alert.accuracyMeters == null ? '' : ' (±${alert.accuracyMeters!.round()} m)'}.\n'
            'Les administrateurs sont prévenus.',
          ),
          actions: [
            TextButton(
              onPressed: () => launchUrl(Uri.parse(alert.mapsUrl)),
              child: const Text('Ouvrir la carte'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on SosFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on AdminFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SOS',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Un instantané GPS est envoyé aux administrateurs. '
            'Pas de suivi continu : une seule position.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('sos_note'),
            controller: _note,
            maxLength: 200,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Message (facultatif)',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('sos_confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _busy ? null : _send,
            child: Text(_busy ? 'Envoi…' : 'Envoyer le SOS'),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}

Future<void> openSosSheet(BuildContext context) {
  final auth = context.read<AuthController>().user;
  final profile = context.read<ProfileController>().profile;
  final name = profile?.fullName ?? auth?.displayName ?? 'Membre';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SosSheet(userName: name),
  );
}
