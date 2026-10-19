import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/places.dart';
import '../data/trip.dart';
import '../data/trip_repository.dart';
import 'trip_detail_page.dart';
import 'trip_format.dart';

class TripResultsPage extends StatefulWidget {
  const TripResultsPage({super.key, required this.query});

  final TripQuery query;

  @override
  State<TripResultsPage> createState() => _TripResultsPageState();
}

class _TripResultsPageState extends State<TripResultsPage> {
  late final Stream<List<Trip>> _feed;

  @override
  void initState() {
    super.initState();
    _feed = context.read<TripRepository>().watchFeed();
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
    return Scaffold(
      appBar: AppBar(title: const Text('Résultats')),
      body: StreamBuilder<List<Trip>>(
        stream: _feed,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger les trajets.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data!.where(query.matches).toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${placeName(query.departureId)} → ${placeName(query.destinationId)}'
                    ' · ${formatDay(query.date)} · ${query.seats} place(s)',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  if (trips.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Text(
                        'Aucun trajet ne correspond.',
                        key: Key('search_empty'),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final trip in trips) _TripCard(trip: trip),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) => _TripCard(trip: trip);
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          '${placeName(trip.departureId)} → ${placeName(trip.destinationId)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${formatWhen(trip.departureAt)}\n'
          '${trip.driverName} · ${trip.vehicleBrand}\n'
          '${trip.seatsAvailable} place(s) · ${formatPrice(trip.pricePerSeat)}'
          ' · ${tripStatusLabel(trip.status)}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final profile = context.read<ProfileController>();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChangeNotifierProvider.value(
                value: profile,
                child: TripDetailPage(trip: trip),
              ),
            ),
          );
        },
      ),
    );
  }
}
