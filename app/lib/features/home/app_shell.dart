import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/presentation/auth_controller.dart';
import '../profile/data/profile_repository.dart';
import '../profile/presentation/profile_controller.dart';
import '../profile/presentation/profile_page.dart';
import '../trips/data/activity.dart';
import '../trips/data/trip_repository.dart';
import '../trips/presentation/my_reservations_page.dart';
import '../trips/presentation/notifications_page.dart';
import '../trips/presentation/my_trips_page.dart';
import 'home_page.dart';

/// Bottom navigation shown once the account is activated.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialSearchDate});

  final DateTime? initialSearchDate;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  Stream<List<AppNotification>>? _notes;
  String? _notesUid;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_notesUid != user.uid) {
      _notesUid = user.uid;
      _notes = context.read<TripRepository>().watchNotifications(user.uid);
    }
    final notes = _notes!;

    return ChangeNotifierProvider(
      create: (_) => ProfileController(
        context.read<ProfileRepository>(),
        uid: user.uid,
        displayName: user.displayName ?? '',
      ),
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            HomePage(initialDate: widget.initialSearchDate),
            const MyTripsPage(),
            const MyReservationsPage(),
            const NotificationsPage(),
            const ProfilePage(),
          ],
        ),
        bottomNavigationBar: StreamBuilder(
          stream: notes,
          builder: (context, snapshot) {
            final unread = (snapshot.data ?? const [])
                .where((note) => !note.read)
                .length;
            return NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() => _index = index),
              destinations: [
                const NavigationDestination(
                  key: Key('nav_home'),
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Accueil',
                ),
                const NavigationDestination(
                  key: Key('nav_trips'),
                  icon: Icon(Icons.route_outlined),
                  selectedIcon: Icon(Icons.route),
                  label: 'Mes trajets',
                ),
                const NavigationDestination(
                  key: Key('nav_bookings'),
                  icon: Icon(Icons.event_seat_outlined),
                  selectedIcon: Icon(Icons.event_seat),
                  label: 'Réservations',
                ),
                NavigationDestination(
                  key: const Key('nav_alerts'),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  selectedIcon: const Icon(Icons.notifications),
                  label: 'Alertes',
                ),
                const NavigationDestination(
                  key: Key('nav_profile'),
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
