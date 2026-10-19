import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/presentation/auth_controller.dart';
import '../profile/data/profile_repository.dart';
import '../profile/presentation/profile_controller.dart';
import '../profile/presentation/profile_page.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
            const ProfilePage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: const [
            NavigationDestination(
              key: Key('nav_home'),
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
            NavigationDestination(
              key: Key('nav_trips'),
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route),
              label: 'Mes trajets',
            ),
            NavigationDestination(
              key: Key('nav_profile'),
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
