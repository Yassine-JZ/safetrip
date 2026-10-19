import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/presentation/auth_controller.dart';
import '../profile/data/profile_repository.dart';
import '../profile/presentation/profile_controller.dart';
import '../profile/presentation/profile_page.dart';
import 'home_page.dart';

/// Bottom navigation shown once the account is activated.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

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
          children: const [HomePage(), ProfilePage()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil',
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
