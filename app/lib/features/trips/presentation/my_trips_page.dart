import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/driver_mode_page.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/trip.dart';
import '../data/trip_repository.dart';
import 'publish_trip_page.dart';
import 'trip_results_page.dart';

class MyTripsPage extends StatefulWidget {
  const MyTripsPage({super.key});

  @override
  State<MyTripsPage> createState() => _MyTripsPageState();
}

class _MyTripsPageState extends State<MyTripsPage> {
  late final Stream<List<Trip>> _mine;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthController>().user!.uid;
    _mine = context.read<TripRepository>().watchMine(uid);
  }

  void _open(Widget page) {
    final profile = context.read<ProfileController>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChangeNotifierProvider.value(value: profile, child: page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    final ready = profile.driverEnabled && profile.vehicle != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes trajets'),
        actions: [
          if (ready)
            TextButton.icon(
              key: const Key('trip_publish'),
              onPressed: () => _open(const PublishTripPage()),
              icon: const Icon(Icons.add),
              label: const Text('Publier'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!ready)
            Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Activez le mode conducteur pour publier un trajet.',
                      key: Key('trips_need_driver'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('trips_enable_driver'),
                      onPressed: () => _open(const DriverModePage()),
                      child: const Text('Véhicule et mode conducteur'),
                    ),
                  ],
                ),
              ),
            ),
          StreamBuilder<List<Trip>>(
            stream: _mine,
            builder: (context, snapshot) {
              final trips = snapshot.data ?? const <Trip>[];
              final upcoming = trips.where(
                (trip) =>
                    trip.status == TripStatus.planned ||
                    trip.status == TripStatus.ongoing,
              );
              final past = trips.where(
                (trip) =>
                    trip.status == TripStatus.completed ||
                    trip.status == TripStatus.cancelled,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Heading('À venir'),
                  if (upcoming.isEmpty)
                    const _Empty('Aucun trajet à venir.')
                  else
                    for (final trip in upcoming) TripCard(trip: trip),
                  const _Heading('Passés'),
                  if (past.isEmpty)
                    const _Empty('Aucun trajet passé.')
                  else
                    for (final trip in past) TripCard(trip: trip),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
    );
  }
}
