import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../admin/data/admin_repository.dart';
import '../../admin/presentation/admin_page.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../trips/data/activity.dart';
import '../../trips/data/trip_repository.dart';
import 'change_password_page.dart';
import 'driver_mode_page.dart';
import 'edit_profile_page.dart';
import 'profile_controller.dart';
import 'widgets/profile_avatar.dart';

/// "Profil" tab (UC02).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _open(BuildContext context, Widget page) {
    final controller = context.read<ProfileController>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChangeNotifierProvider.value(value: controller, child: page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    final auth = context.watch<AuthController>();
    final profile = controller.profile;

    if (controller.loading || profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final vehicle = controller.vehicle;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 150,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: const SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    'Mon profil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 96, 16, 0),
              child: _Centered(
                child: _HeaderCard(
                  name: profile.fullName,
                  email: auth.user?.email ?? '',
                  initials: profile.initials,
                  photoUrl: profile.photoUrl,
                  driverEnabled: profile.driverEnabled,
                  onEdit: () => _open(context, const EditProfilePage()),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: _Centered(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatsRow(
                  uid: profile.uid,
                  driverEnabled: profile.driverEnabled,
                ),
                const SizedBox(height: 16),
                _MenuCard(
                  children: [
                    _MenuTile(
                      key: const Key('menu_info'),
                      icon: Icons.badge_outlined,
                      title: 'Mes informations',
                      subtitle: 'Nom, photo, e-mail et téléphone',
                      onTap: () => _open(context, const EditProfilePage()),
                    ),
                    _MenuTile(
                      key: const Key('menu_driver'),
                      icon: Icons.directions_car_outlined,
                      title: 'Véhicule et mode conducteur',
                      subtitle: vehicle == null
                          ? 'Aucun véhicule enregistré'
                          : '${vehicle.brand} · ${_seats(vehicle.seats)}',
                      onTap: () => _open(context, const DriverModePage()),
                    ),
                    _MenuTile(
                      key: const Key('menu_password'),
                      icon: Icons.lock_outline,
                      title: 'Changer le mot de passe',
                      onTap: () => _open(context, const ChangePasswordPage()),
                    ),
                    StreamBuilder<bool>(
                      stream: context
                          .read<AdminRepository>()
                          .watchIsAdmin(profile.uid),
                      builder: (context, snapshot) {
                        if (snapshot.data != true) {
                          return const SizedBox.shrink();
                        }
                        return _MenuTile(
                          key: const Key('menu_admin'),
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'Espace administrateur',
                          subtitle: 'Utilisateurs et signalements',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AdminPage(),
                            ),
                          ),
                        );
                      },
                    ),
                    _MenuTile(
                      icon: Icons.info_outline,
                      title: 'À propos de SafeTrip',
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'SafeTrip',
                        applicationVersion: '1.0.0',
                        children: const [
                          Text(
                            'Covoiturage étudiant entre domicile et '
                            'université. Pas de paiement en ligne : le prix '
                            'informe seulement les participants.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  key: const Key('logout'),
                  onPressed: auth.signOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _seats(int n) => n == 1 ? '1 place' : '$n places';
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: child,
    ),
  );
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.name,
    required this.email,
    required this.initials,
    required this.photoUrl,
    required this.driverEnabled,
    required this.onEdit,
  });

  final String name;
  final String email;
  final String initials;
  final String? photoUrl;
  final bool driverEnabled;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProfileAvatar(
              initials: initials,
              photoUrl: photoUrl,
              radius: 34,
              ring: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    key: const Key('profile_name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DriverChip(enabled: driverEnabled),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Modifier le profil',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverChip extends StatelessWidget {
  const _DriverChip({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.green : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.directions_car : Icons.directions_car_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            enabled ? 'Mode conducteur actif' : 'Mode conducteur inactif',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatefulWidget {
  const _StatsRow({required this.uid, required this.driverEnabled});

  final String uid;
  final bool driverEnabled;

  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> {
  late final Stream<List<Rating>> _ratings;

  @override
  void initState() {
    super.initState();
    _ratings = context.read<TripRepository>().watchRatings(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Rating>>(
      stream: _ratings,
      builder: (context, snapshot) {
        final ratings = snapshot.data ?? const <Rating>[];
        final average = ratings.isEmpty
            ? null
            : ratings.map((rating) => rating.stars).reduce((a, b) => a + b) /
                  ratings.length;
        return _MenuCard(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  _Stat(
                    value: average == null
                        ? '—'
                        : '★ ${average.toStringAsFixed(1)}',
                    label: 'Note',
                  ),
                  _Stat(value: '${ratings.length}', label: 'Avis'),
                  _Stat(
                    value: widget.driverEnabled ? 'Oui' : 'Non',
                    label: 'Conducteur',
                  ),
                ],
              ),
            ),
            if (ratings.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  'Aucune évaluation pour le moment. Les avis arrivent après vos '
                  'premiers trajets terminés.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
