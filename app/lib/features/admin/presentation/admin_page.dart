import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/data/profile_models.dart';
import '../../sos/data/sos_models.dart';
import '../../trips/data/activity.dart';
import '../data/admin_repository.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administration'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(key: Key('admin_tab_users'), text: 'Utilisateurs'),
              Tab(key: Key('admin_tab_reports'), text: 'Signalements'),
              Tab(key: Key('admin_tab_sos'), text: 'SOS'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_UsersTab(), _ReportsTab(), _SosTab()],
        ),
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminRepository>();
    final me = context.watch<AuthController>().user?.uid;
    return StreamBuilder<List<UserProfile>>(
      stream: admin.watchUsers(),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <UserProfile>[];
        if (users.isEmpty) {
          return const Center(
            child: Text(
              'Aucun utilisateur.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.separated(
          key: const Key('admin_users'),
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final user = users[index];
            final self = user.uid == me;
            return Card(
              elevation: 0,
              child: ListTile(
                title: Text(user.fullName),
                subtitle: Text(
                  [
                    if (user.driverEnabled) 'Conducteur',
                    if (user.suspended) 'Suspendu',
                    if (!user.suspended) 'Actif',
                  ].join(' · '),
                ),
                trailing: self
                    ? const Text(
                        'Vous',
                        style: TextStyle(color: AppColors.textMuted),
                      )
                    : TextButton(
                        key: Key('admin_suspend_${user.uid}'),
                        onPressed: () async {
                          try {
                            await admin.setSuspended(
                              targetUid: user.uid,
                              suspended: !user.suspended,
                            );
                          } on AdminFailure catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.message)),
                              );
                            }
                          }
                        },
                        child: Text(user.suspended ? 'Réactiver' : 'Suspendre'),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminRepository>();
    return StreamBuilder<List<Report>>(
      stream: admin.watchReports(),
      builder: (context, snapshot) {
        final reports = snapshot.data ?? const <Report>[];
        if (reports.isEmpty) {
          return const Center(
            child: Text(
              'Aucun signalement.',
              key: Key('admin_reports_empty'),
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.separated(
          key: const Key('admin_reports'),
          padding: const EdgeInsets.all(12),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final report = reports[index];
            return Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.reason,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${report.reporterName} → ${report.targetName}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    if (report.details != null &&
                        report.details!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(report.details!),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Statut : ${report.status}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (report.status == 'open') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton(
                            key: Key('admin_resolve_${report.id}'),
                            onPressed: () => admin.setReportStatus(
                              reportId: report.id,
                              status: 'resolved',
                            ),
                            child: const Text('Résolu'),
                          ),
                          TextButton(
                            key: Key('admin_dismiss_${report.id}'),
                            onPressed: () => admin.setReportStatus(
                              reportId: report.id,
                              status: 'dismissed',
                            ),
                            child: const Text('Rejeter'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SosTab extends StatelessWidget {
  const _SosTab();

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminRepository>();
    return StreamBuilder<List<SosAlert>>(
      stream: admin.watchSosAlerts(),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? const <SosAlert>[];
        if (alerts.isEmpty) {
          return const Center(
            child: Text(
              'Aucune alerte SOS.',
              key: Key('admin_sos_empty'),
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.separated(
          key: const Key('admin_sos_list'),
          padding: const EdgeInsets.all(12),
          itemCount: alerts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final alert = alerts[index];
            return Card(
              elevation: 0,
              color: alert.status == 'open'
                  ? const Color(0xFFFFF1F2)
                  : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.userName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${alert.latitude.toStringAsFixed(5)}, '
                      '${alert.longitude.toStringAsFixed(5)}'
                      '${alert.accuracyMeters == null ? '' : ' (±${alert.accuracyMeters!.round()} m)'}',
                    ),
                    if (alert.note != null && alert.note!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(alert.note!),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Statut : ${alert.status}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          key: Key('admin_sos_map_${alert.id}'),
                          onPressed: () => launchUrl(Uri.parse(alert.mapsUrl)),
                          child: const Text('Carte'),
                        ),
                        if (alert.status == 'open')
                          TextButton(
                            key: Key('admin_sos_close_${alert.id}'),
                            onPressed: () => admin.setSosStatus(
                              alertId: alert.id,
                              status: 'closed',
                            ),
                            child: const Text('Clôturer'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
