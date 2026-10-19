import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../profile/presentation/profile_controller.dart';
import '../data/trip.dart';
import '../data/trip_repository.dart';
import 'trip_form.dart';

class PublishTripPage extends StatelessWidget {
  const PublishTripPage({super.key});

  Future<void> _publish(BuildContext context, TripDraft draft) async {
    final profile = context.read<ProfileController>();
    final vehicle = profile.vehicle;
    final user = profile.profile;
    if (user == null || vehicle == null || !user.driverEnabled) return;
    try {
      await context.read<TripRepository>().publish(
        TripDraft(
          driverId: user.uid,
          driverName: user.fullName,
          vehicleBrand: vehicle.brand,
          departureId: draft.departureId,
          destinationId: draft.destinationId,
          departureAt: draft.departureAt,
          seatsTotal: draft.seatsTotal,
          pricePerSeat: draft.pricePerSeat,
          description: draft.description,
          luggage: draft.luggage,
          roundTrip: draft.roundTrip,
        ),
      );
      if (context.mounted) Navigator.of(context).pop();
    } on TripFailure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    final vehicle = profile.vehicle;
    final ready = profile.driverEnabled && vehicle != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Publier un trajet')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!ready)
                const Text(
                  'Activez le mode conducteur et enregistrez votre véhicule '
                  'avant de publier un trajet.',
                )
              else
                TripForm(
                  seatsMax: vehicle.seats,
                  submitLabel: 'Publier',
                  onSubmit: (draft) => _publish(context, draft),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
