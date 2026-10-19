import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/activity.dart';
import '../data/trip_repository.dart';
import 'trip_detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final Stream<List<AppNotification>> _notes;
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = context.read<AuthController>().user!.uid;
    _notes = context.read<TripRepository>().watchNotifications(_uid);
  }

  Future<void> _open(AppNotification note) async {
    final trips = context.read<TripRepository>();
    final trip = await trips.watchOne(note.tripId).first;
    if (!note.read) {
      await trips.markNotificationRead(note.id, _uid);
    }
    if (!mounted || trip == null) return;
    final profile = context.read<ProfileController>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: profile,
          child: TripDetailPage(trip: trip),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notes,
        builder: (context, snapshot) {
          final notes = snapshot.data ?? const <AppNotification>[];
          if (notes.isEmpty) {
            return const Center(
              child: Text(
                'Aucune notification.',
                key: Key('notifications_empty'),
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final note in notes)
                Card(
                  elevation: 0,
                  color: note.read ? Colors.white : const Color(0xFFE8F0FE),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    key: Key('note_${note.type}'),
                    onTap: () => _open(note),
                    title: Text(
                      note.title,
                      style: TextStyle(
                        fontWeight: note.read
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(note.body),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
