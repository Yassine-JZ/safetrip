import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/places.dart';
import '../data/trip.dart';
import '../data/trip_repository.dart';
import 'edit_trip_page.dart';
import 'trip_format.dart';

class TripDetailPage extends StatelessWidget {
  const TripDetailPage({super.key, required this.trip});

  final Trip trip;

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler ce trajet ?'),
        content: const Text(
          'Le trajet reste dans votre historique avec l\'état Annulé. '
          'Il disparaît du fil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            key: const Key('trip_cancel_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler le trajet'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final uid = context.read<AuthController>().user!.uid;
      await context.read<TripRepository>().cancel(trip.id, uid);
      if (context.mounted) Navigator.of(context).pop();
    } on TripFailure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _edit(BuildContext context) {
    final profile = context.read<ProfileController>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: profile,
          child: EditTripPage(trip: trip),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthController>().user?.uid;
    final mine = uid == trip.driverId;
    return Scaffold(
      appBar: AppBar(title: const Text('Détail du trajet')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '${placeName(trip.departureId)} → ${placeName(trip.destinationId)}',
                key: const Key('trip_route'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(formatWhen(trip.departureAt)),
              const SizedBox(height: 4),
              Text(tripStatusLabel(trip.status), key: const Key('trip_status')),
              const SizedBox(height: 16),
              _Line(
                icon: Icons.event_seat_outlined,
                text:
                    '${trip.seatsAvailable} place(s) libre(s) sur ${trip.seatsTotal}',
              ),
              _Line(
                icon: Icons.payments_outlined,
                text: formatPrice(trip.pricePerSeat),
              ),
              _Line(
                icon: Icons.directions_car_outlined,
                text: trip.vehicleBrand,
              ),
              _Line(icon: Icons.person_outline, text: trip.driverName),
              if (trip.luggage)
                const _Line(
                  icon: Icons.luggage_outlined,
                  text: 'Bagages acceptés',
                ),
              if (trip.roundTrip)
                const _Line(icon: Icons.sync_alt, text: 'Aller-retour'),
              if (trip.description != null && trip.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(trip.description!),
              ],
              const SizedBox(height: 16),
              const Text(
                'Le matricule du véhicule n\'est jamais affiché ici.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              if (mine && trip.editable) ...[
                FilledButton(
                  key: const Key('trip_edit'),
                  onPressed: () => _edit(context),
                  child: const Text('Modifier'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('trip_cancel'),
                  onPressed: () => _cancel(context),
                  child: const Text('Annuler le trajet'),
                ),
              ] else if (!mine && trip.status == TripStatus.planned)
                const FilledButton(
                  onPressed: null,
                  child: Text('La réservation arrive à la prochaine étape'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
