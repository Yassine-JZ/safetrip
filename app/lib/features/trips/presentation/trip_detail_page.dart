import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/places.dart';
import '../data/reservation.dart';
import '../data/trip.dart';
import '../data/trip_repository.dart';
import 'edit_trip_page.dart';
import 'trip_format.dart';

class TripDetailPage extends StatefulWidget {
  const TripDetailPage({super.key, required this.trip});

  final Trip trip;

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  late final Stream<Trip?> _tripStream;
  late final Stream<List<Reservation>> _reservations;

  @override
  void initState() {
    super.initState();
    final trips = context.read<TripRepository>();
    _tripStream = trips.watchOne(widget.trip.id);
    _reservations = trips.watchTripReservations(widget.trip.id);
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on TripFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _reserve(Trip trip) async {
    var seats = 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Réserver une place'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const Key('reserve_minus'),
                onPressed: seats > 1 ? () => setLocal(() => seats -= 1) : null,
                icon: const Icon(Icons.remove),
              ),
              Text('$seats', key: const Key('reserve_seats')),
              IconButton(
                key: const Key('reserve_plus'),
                onPressed: seats < trip.seatsAvailable
                    ? () => setLocal(() => seats += 1)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Retour'),
            ),
            FilledButton(
              key: const Key('reserve_confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Envoyer la demande'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final auth = context.read<AuthController>().user;
    final profile = context.read<ProfileController>().profile;
    await _run(
      () => context.read<TripRepository>().requestSeat(
        trip: trip,
        passengerId: auth!.uid,
        passengerName: profile?.fullName ?? auth.displayName ?? 'Passager',
        seats: seats,
      ),
    );
  }

  Future<void> _cancelTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler ce trajet ?'),
        content: const Text(
          'Le trajet reste dans votre historique avec l\'état Annulé. '
          'Les demandes en cours sont annulées aussi.',
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
    if (confirmed != true || !mounted) return;
    final uid = context.read<AuthController>().user!.uid;
    await _run(
      () => context.read<TripRepository>().cancel(widget.trip.id, uid),
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _edit() {
    final profile = context.read<ProfileController>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: profile,
          child: EditTripPage(trip: widget.trip),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trip?>(
      stream: _tripStream,
      builder: (context, snapshot) {
        final trip = snapshot.data ?? widget.trip;
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
                  Text(
                    tripStatusLabel(trip.status),
                    key: const Key('trip_status'),
                  ),
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
                  if (trip.description != null &&
                      trip.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(trip.description!),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Le matricule du véhicule n\'est jamais affiché ici.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  if (mine)
                    ..._driverActions(trip)
                  else
                    ..._passengerActions(trip),
                  if (mine) _Requests(tripId: trip.id, stream: _reservations),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _driverActions(Trip trip) {
    final uid = context.read<AuthController>().user!.uid;
    final trips = context.read<TripRepository>();
    return [
      if (trip.status == TripStatus.planned)
        FilledButton(
          key: const Key('trip_start'),
          onPressed: () => _run(() => trips.start(trip.id, uid)),
          child: const Text('Démarrer le trajet'),
        ),
      if (trip.status == TripStatus.ongoing) ...[
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('trip_finish'),
          onPressed: () => _run(() => trips.finish(trip.id, uid)),
          child: const Text('Terminer le trajet'),
        ),
      ],
      if (trip.editable) ...[
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('trip_edit'),
          onPressed: _edit,
          child: const Text('Modifier'),
        ),
      ],
      if (trip.status == TripStatus.planned) ...[
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('trip_cancel'),
          onPressed: _cancelTrip,
          child: const Text('Annuler le trajet'),
        ),
      ],
    ];
  }

  List<Widget> _passengerActions(Trip trip) {
    if (trip.status != TripStatus.planned) return const [];
    if (trip.seatsAvailable < 1) {
      return const [Text('Complet.')];
    }
    return [
      FilledButton(
        key: const Key('reserve_open'),
        onPressed: () => _reserve(trip),
        child: const Text('Réserver une place'),
      ),
    ];
  }
}

class _Requests extends StatelessWidget {
  const _Requests({required this.tripId, required this.stream});

  final String tripId;
  final Stream<List<Reservation>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reservation>>(
      stream: stream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Reservation>[];
        final pending = items.where(
          (item) => item.status == ReservationStatus.pending,
        );
        final accepted = items.where(
          (item) => item.status == ReservationStatus.accepted,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Passagers confirmés (${accepted.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (accepted.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Aucun passager confirmé.',
                  key: Key('no_passengers'),
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              for (final item in accepted)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.passengerName),
                  subtitle: Text('${item.seats} place(s)'),
                ),
            const SizedBox(height: 12),
            const Text(
              'Demandes en attente',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (pending.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Aucune demande.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              for (final item in pending)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.passengerName),
                  subtitle: Text('${item.seats} place(s)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        key: Key('refuse_${item.passengerId}'),
                        onPressed: () => context
                            .read<TripRepository>()
                            .refuseReservation(tripId, item.passengerId),
                        child: const Text('Refuser'),
                      ),
                      TextButton(
                        key: Key('accept_${item.passengerId}'),
                        onPressed: () => context
                            .read<TripRepository>()
                            .acceptReservation(tripId, item.passengerId),
                        child: const Text('Accepter'),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
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
