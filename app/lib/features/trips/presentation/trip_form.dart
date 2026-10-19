import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/places.dart';
import '../data/trip.dart';
import 'trip_format.dart';

/// Shared fields for publishing and editing a trip.
class TripForm extends StatefulWidget {
  const TripForm({
    super.key,
    required this.seatsMax,
    required this.onSubmit,
    required this.submitLabel,
    this.initial,
    this.busy = false,
  });

  final int seatsMax;
  final Trip? initial;
  final bool busy;
  final String submitLabel;
  final void Function(TripDraft draft) onSubmit;

  @override
  State<TripForm> createState() => TripFormState();
}

class TripFormState extends State<TripForm> {
  final _formKey = GlobalKey<FormState>();
  final _price = TextEditingController();
  final _description = TextEditingController();
  String? _from;
  String? _to;
  late DateTime _when;
  late int _seats;
  bool _luggage = false;
  bool _roundTrip = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final trip = widget.initial;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _from = trip?.departureId;
    _to = trip?.destinationId;
    _when =
        trip?.departureAt ??
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8);
    _seats = trip?.seatsTotal ?? 1;
    if (_seats > widget.seatsMax) _seats = widget.seatsMax;
    _luggage = trip?.luggage ?? false;
    _roundTrip = trip?.roundTrip ?? false;
    if (trip?.pricePerSeat != null) {
      _price.text = trip!.pricePerSeat!.toStringAsFixed(0);
    }
    _description.text = trip?.description ?? '';
  }

  @override
  void dispose() {
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      locale: const Locale('fr'),
    );
    if (picked == null) return;
    setState(() {
      _when = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _when.hour,
        _when.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (picked == null) return;
    setState(() {
      _when = DateTime(
        _when.year,
        _when.month,
        _when.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _submit() {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_when.isBefore(DateTime.now().add(const Duration(minutes: 10)))) {
      setState(() => _error = 'Choisissez une date et une heure à venir.');
      return;
    }
    final priceText = _price.text.trim();
    widget.onSubmit(
      TripDraft(
        driverId: '',
        driverName: '',
        vehicleBrand: '',
        departureId: _from!,
        destinationId: _to!,
        departureAt: _when,
        seatsTotal: _seats,
        pricePerSeat: priceText.isEmpty ? null : double.parse(priceText),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        luggage: _luggage,
        roundTrip: _roundTrip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                key: const Key('trip_form_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          DropdownButtonFormField<String>(
            key: const Key('trip_from'),
            initialValue: _from,
            decoration: const InputDecoration(labelText: 'Départ'),
            items: [
              for (final place in places)
                DropdownMenuItem(value: place.id, child: Text(place.name)),
            ],
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _from = value),
            validator: (value) =>
                value == null ? 'Le départ est obligatoire' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('trip_to'),
            initialValue: _to,
            decoration: const InputDecoration(labelText: 'Destination'),
            items: [
              for (final place in places)
                DropdownMenuItem(value: place.id, child: Text(place.name)),
            ],
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _to = value),
            validator: (value) {
              if (value == null) return 'La destination est obligatoire';
              if (value == _from) {
                return 'Le départ et la destination diffèrent';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('trip_date'),
                  onPressed: widget.busy ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(formatDay(_when)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('trip_time'),
                  onPressed: widget.busy ? null : _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(formatTime(_when)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: const Key('trip_seats'),
            initialValue: _seats,
            decoration: InputDecoration(
              labelText: 'Places passagers',
              helperText: 'Maximum : ${widget.seatsMax} (votre véhicule).',
            ),
            items: [
              for (var n = 1; n <= widget.seatsMax; n++)
                DropdownMenuItem(value: n, child: Text('$n')),
            ],
            onChanged: widget.busy
                ? null
                : (value) {
                    if (value != null) setState(() => _seats = value);
                  },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('trip_price'),
            controller: _price,
            enabled: !widget.busy,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Prix par place (DT)',
              hintText: 'Facultatif',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final price = int.tryParse(value.trim());
              if (price == null || price > 500) return 'Prix entre 0 et 500 DT';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('trip_description'),
            controller: _description,
            enabled: !widget.busy,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bagages acceptés'),
            value: _luggage,
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _luggage = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aller-retour'),
            value: _roundTrip,
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _roundTrip = value),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('trip_submit'),
            onPressed: widget.busy ? null : _submit,
            child: Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
