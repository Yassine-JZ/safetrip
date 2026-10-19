import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../data/profile_models.dart';
import 'profile_controller.dart';

/// Vehicle and driver capability (UC12). The plate stays on this screen.
class DriverModePage extends StatefulWidget {
  const DriverModePage({super.key});

  @override
  State<DriverModePage> createState() => _DriverModePageState();
}

class _DriverModePageState extends State<DriverModePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _brand;
  late final TextEditingController _plate;
  late int _seats;
  String? _error;

  @override
  void initState() {
    super.initState();
    final vehicle = context.read<ProfileController>().vehicle;
    _brand = TextEditingController(text: vehicle?.brand ?? '');
    _plate = TextEditingController(text: vehicle?.plate ?? '');
    _seats = vehicle?.seats ?? 3;
  }

  @override
  void dispose() {
    _brand.dispose();
    _plate.dispose();
    super.dispose();
  }

  Vehicle? _vehicle() {
    if (!_formKey.currentState!.validate()) return null;
    return Vehicle(
      brand: _brand.text.trim(),
      plate: Validators.normalizePlate(_plate.text),
      seats: _seats,
    );
  }

  Future<void> _save({required bool enable}) async {
    setState(() => _error = null);
    final vehicle = _vehicle();
    if (vehicle == null) return;
    try {
      await context.read<ProfileController>().saveVehicle(
        vehicle,
        enableDriver: enable,
      );
      if (mounted && enable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mode conducteur activé.')),
        );
      }
    } on ProfileFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _disable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Désactiver le mode conducteur ?'),
        content: const Text(
          'Vous ne pourrez plus proposer de trajet. Votre compte, votre '
          'historique et vos réservations en tant que passager sont conservés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const Key('driver_disable_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _error = null);
    try {
      await context.read<ProfileController>().setDriverEnabled(false);
    } on ProfileFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    final enabled = controller.driverEnabled;
    final busy = controller.busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Véhicule')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    key: const Key('driver_error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (enabled ? AppColors.green : AppColors.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_car,
                      color: enabled ? AppColors.green : AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        enabled
                            ? 'Mode conducteur actif. Vous pourrez proposer '
                                  'des trajets.'
                            : 'Renseignez votre véhicule pour activer le '
                                  'mode conducteur.',
                        style: const TextStyle(color: AppColors.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      key: const Key('driver_brand'),
                      controller: _brand,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Marque et modèle',
                        hintText: 'Peugeot 208',
                      ),
                      validator: Validators.vehicleBrand,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('driver_plate'),
                      controller: _plate,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Matricule',
                        hintText: '123 TU 4567',
                        helperText: 'Privé : jamais affiché dans le fil.',
                      ),
                      validator: Validators.plate,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      key: const Key('driver_seats'),
                      initialValue: _seats,
                      decoration: const InputDecoration(
                        labelText: 'Places passagers',
                        helperText: 'Sans compter le conducteur.',
                      ),
                      items: [
                        for (var n = 1; n <= 8; n++)
                          DropdownMenuItem(
                            value: n,
                            child: Text(n == 1 ? '1 place' : '$n places'),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) {
                              if (value != null) setState(() => _seats = value);
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!enabled)
                FilledButton.icon(
                  key: const Key('driver_enable'),
                  onPressed: busy ? null : () => _save(enable: true),
                  icon: const Icon(Icons.check),
                  label: const Text('Enregistrer et activer'),
                )
              else ...[
                FilledButton(
                  key: const Key('driver_save'),
                  onPressed: busy ? null : () => _save(enable: false),
                  child: const Text('Enregistrer'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('driver_disable'),
                  onPressed: busy ? null : _disable,
                  child: const Text('Désactiver le mode conducteur'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
