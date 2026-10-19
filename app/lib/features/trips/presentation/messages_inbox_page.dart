import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/places.dart';
import '../data/trip.dart';
import '../data/trip_repository.dart';
import 'trip_chat_page.dart';
import 'trip_format.dart';

/// Bottom-nav inbox: every trip where the user can already open the chat.
class MessagesInboxPage extends StatefulWidget {
  const MessagesInboxPage({super.key});

  @override
  State<MessagesInboxPage> createState() => _MessagesInboxPageState();
}

class _MessagesInboxPageState extends State<MessagesInboxPage> {
  late final Stream<List<Trip>> _conversations;
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = context.read<AuthController>().user!.uid;
    _conversations = context.read<TripRepository>().watchConversations(_uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messagerie')),
      body: StreamBuilder<List<Trip>>(
        stream: _conversations,
        builder: (context, snapshot) {
          final trips = snapshot.data ?? const <Trip>[];
          if (trips.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune conversation.\n'
                  'Elles apparaissent dès qu\'une réservation est acceptée.',
                  key: Key('messages_empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            );
          }
          return ListView.separated(
            key: const Key('messages_list'),
            padding: const EdgeInsets.all(12),
            itemCount: trips.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final trip = trips[index];
              final profile = context.read<ProfileController>();
              return Card(
                elevation: 0,
                color: Colors.white,
                child: ListTile(
                  key: Key('conversation_${trip.id}'),
                  leading: const CircleAvatar(
                    child: Icon(Icons.chat_bubble_outline),
                  ),
                  title: Text(
                    '${placeName(trip.departureId)} → ${placeName(trip.destinationId)}',
                  ),
                  subtitle: Text(
                    '${formatWhen(trip.departureAt)} · ${tripStatusLabel(trip.status)}'
                    '${trip.driverId == _uid ? '' : ' · ${trip.driverName}'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: profile,
                          child: TripChatPage(trip: trip),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
