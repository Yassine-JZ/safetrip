import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/places.dart';
import '../data/reservation.dart';
import '../data/trip.dart';
import '../data/trip_repository.dart';
import 'trip_format.dart';

class MyReservationsPage extends StatefulWidget {
  const MyReservationsPage({super.key});

  @override
  State<MyReservationsPage> createState() => _MyReservationsPageState();
}

class _MyReservationsPageState extends State<MyReservationsPage> {
  late final Stream<List<Reservation>> _mine;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthController>().user!.uid;
    _mine = context.read<TripRepository>().watchMyReservations(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes réservations')),
      body: StreamBuilder<List<Reservation>>(
        stream: _mine,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <Reservation>[];
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Vous n\'avez pas encore demandé de place.',
                key: Key('bookings_empty'),
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [for (final item in items) _ReservationTile(item: item)],
          );
        },
      ),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({required this.item});

  final Reservation item;

  @override
  Widget build(BuildContext context) {
    final open =
        item.status == ReservationStatus.pending ||
        item.status == ReservationStatus.accepted;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(reservationStatusLabel(item.status)),
        subtitle: StreamBuilder<Trip?>(
          stream: context.read<TripRepository>().watchOne(item.tripId),
          builder: (context, snapshot) {
            final trip = snapshot.data;
            final route = trip == null ? 'Trajet' : routeLabel(trip);
            return Text('$route\n${item.seats} place(s)');
          },
        ),
        isThreeLine: true,
        trailing: open
            ? TextButton(
                key: Key('booking_cancel_${item.tripId}'),
                onPressed: () async {
                  try {
                    await context.read<TripRepository>().cancelReservation(
                      item.tripId,
                      item.passengerId,
                    );
                  } on TripFailure catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(error.message)));
                    }
                  }
                },
                child: const Text('Annuler'),
              )
            : null,
      ),
    );
  }
}

String routeLabel(Trip trip) =>
    '${placeName(trip.departureId)} → ${placeName(trip.destinationId)} · ${formatWhen(trip.departureAt)}';
