import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../profile/presentation/profile_controller.dart';
import '../data/trip.dart';
import '../data/trip_repository.dart';
import 'trip_form.dart';

class EditTripPage extends StatelessWidget {
  const EditTripPage({super.key, required this.trip});

  final Trip trip;

  Future<void> _save(BuildContext context, TripDraft draft) async {
    final seatsMax =
        context.read<ProfileController>().vehicle?.seats ?? trip.seatsTotal;
    if (draft.seatsTotal > seatsMax) return;
    try {
      await context.read<TripRepository>().update(
        trip.copyWith(
          departureId: draft.departureId,
          destinationId: draft.destinationId,
          departureAt: draft.departureAt,
          seatsTotal: draft.seatsTotal,
          seatsAvailable: draft.seatsTotal,
          pricePerSeat: () => draft.pricePerSeat,
          description: () => draft.description,
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
    final seats =
        context.watch<ProfileController>().vehicle?.seats ?? trip.seatsTotal;
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le trajet')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TripForm(
                initial: trip,
                seatsMax: seats < trip.seatsTotal ? trip.seatsTotal : seats,
                submitLabel: 'Enregistrer',
                onSubmit: (draft) => _save(context, draft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
