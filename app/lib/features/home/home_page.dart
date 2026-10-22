import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/safetrip_logo.dart';
import '../auth/presentation/auth_controller.dart';
import '../profile/presentation/profile_controller.dart';
import '../profile/presentation/widgets/profile_avatar.dart';

/// Home after sign-in. Trip search (UC08) will replace the placeholder.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  int _seats = 1;

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      locale: const Locale('fr'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _search() {
    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();
    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez le départ et la destination.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La recherche de trajets arrive à la prochaine étape.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profile = context.watch<ProfileController>().profile;
    final name = profile?.fullName ?? auth.user?.displayName ?? '';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: 250,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/images/splash_bg.jpg', fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x661E5BD8), Color(0xCC0F2A6B)],
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              SafeTripLogo(size: 36, inverted: true),
                              SizedBox(width: 10),
                              SafeTripWordmark(fontSize: 22, light: true),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bonjour $name',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Prêt pour une nouvelle aventure ?',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              ProfileAvatar(
                                initials: profile?.initials ?? '',
                                photoUrl: profile?.photoUrl,
                                radius: 22,
                                ring: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 56),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 210, 16, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _SearchCard(
                    fromCtrl: _fromCtrl,
                    toCtrl: _toCtrl,
                    date: _date,
                    seats: _seats,
                    onPickDate: _pickDate,
                    onSeats: (value) => setState(() => _seats = value),
                    onSearch: _search,
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _EmptyTrips(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.fromCtrl,
    required this.toCtrl,
    required this.date,
    required this.seats,
    required this.onPickDate,
    required this.onSeats,
    required this.onSearch,
  });

  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final DateTime date;
  final int seats;
  final VoidCallback onPickDate;
  final ValueChanged<int> onSeats;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              key: const Key('search_from'),
              controller: fromCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Départ',
                hintText: 'Tunis',
                prefixIcon: Icon(Icons.trip_origin, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('search_to'),
              controller: toCtrl,
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'Nabeul',
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                  color: AppColors.green,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(dateLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: seats,
                    decoration: const InputDecoration(
                      labelText: 'Places',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: [
                      for (var n = 1; n <= 4; n++)
                        DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                    onChanged: (value) {
                      if (value != null) onSeats(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('search_submit'),
              onPressed: onSearch,
              icon: const Icon(Icons.search),
              label: const Text('Rechercher'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trajets disponibles',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.route_outlined, color: AppColors.textMuted),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aucun trajet publié pour le moment. Le fil d\'offres '
                    'arrive à la prochaine étape.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
