import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/activity.dart';
import '../data/reservation.dart';
import '../data/trip.dart';
import '../data/trip_repository.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({
    super.key,
    required this.trip,
    required this.reservations,
  });

  final Trip trip;
  final List<Reservation> reservations;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String? _targetId;
  String _reason = reportReasons.first;
  final _details = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Map<String, String> _targets(String uid) {
    final map = <String, String>{};
    if (widget.trip.driverId != uid) {
      map[widget.trip.driverId] = widget.trip.driverName;
    }
    for (final item in widget.reservations) {
      if (item.status == ReservationStatus.accepted &&
          item.passengerId != uid) {
        map[item.passengerId] = item.passengerName;
      }
    }
    return map;
  }

  Future<void> _submit() async {
    final auth = context.read<AuthController>().user!;
    final profile = context.read<ProfileController>().profile;
    final targets = _targets(auth.uid);
    final targetId = _targetId;
    if (targetId == null || !targets.containsKey(targetId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez la personne à signaler.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<TripRepository>().report(
        tripId: widget.trip.id,
        reporterId: auth.uid,
        reporterName: profile?.fullName ?? auth.displayName ?? 'Membre',
        targetUserId: targetId,
        targetName: targets[targetId]!,
        reason: _reason,
        details: _details.text.trim().isEmpty ? null : _details.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signalement envoyé. Merci, l\'équipe le verra.'),
        ),
      );
      Navigator.of(context).pop();
    } on TripFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthController>().user!.uid;
    final targets = _targets(uid);
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Le signalement est confidentiel. Aucun téléphone, matricule '
            'ou position GPS n\'est joint.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: const Key('report_target'),
            initialValue: targets.containsKey(_targetId) ? _targetId : null,
            decoration: const InputDecoration(labelText: 'Personne concernée'),
            items: [
              for (final entry in targets.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _targetId = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('report_reason'),
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Motif'),
            items: [
              for (final reason in reportReasons)
                DropdownMenuItem(value: reason, child: Text(reason)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _reason = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('report_details'),
            controller: _details,
            maxLength: 500,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Détails (facultatif)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('report_send'),
            onPressed: _saving || targets.isEmpty ? null : _submit,
            child: Text(_saving ? 'Envoi…' : 'Envoyer le signalement'),
          ),
          if (targets.isEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Aucun autre participant à signaler pour ce trajet.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
