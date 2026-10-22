import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../data/profile_models.dart';
import 'photo_codec.dart';
import 'profile_controller.dart';
import 'widgets/profile_avatar.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  String? _photoUrl;
  bool _photoChanged = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileController>().profile;
    _firstName = TextEditingController(text: profile?.firstName ?? '');
    _lastName = TextEditingController(text: profile?.lastName ?? '');
    _photoUrl = profile?.photoUrl;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final url = photoDataUrl(await file.readAsBytes());
    if (!mounted) return;
    if (url == null) {
      setState(() => _error = 'Image illisible ou trop lourde.');
      return;
    }
    setState(() {
      _photoUrl = url;
      _photoChanged = true;
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final controller = context.read<ProfileController>();
    try {
      await controller.updateName(_firstName.text, _lastName.text);
      if (_photoChanged) await controller.updatePhoto(_photoUrl);
      if (mounted) Navigator.of(context).pop();
    } on ProfileFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    final info = controller.privateInfo;
    final busy = controller.busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes informations')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Stack(
                  children: [
                    ProfileAvatar(
                      initials: controller.profile?.initials ?? '',
                      photoUrl: _photoUrl,
                      radius: 48,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton.filled(
                        key: const Key('profile_photo'),
                        tooltip: 'Choisir une photo',
                        onPressed: busy ? null : _pickPhoto,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              if (_photoUrl != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          _photoUrl = null;
                          _photoChanged = true;
                        }),
                  child: const Text('Retirer la photo'),
                ),
              const SizedBox(height: 16),
              if (_error != null) _Error(message: _error!),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      key: const Key('profile_first_name'),
                      controller: _firstName,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                      validator: (v) => Validators.name(v, 'Le prénom'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('profile_last_name'),
                      controller: _lastName,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      validator: (v) => Validators.name(v, 'Le nom'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _LockedField(
                label: 'E-mail',
                value: info?.email ?? '…',
                icon: Icons.mail_outline,
              ),
              const SizedBox(height: 12),
              _LockedField(
                label: 'Téléphone',
                value: info == null ? '…' : _phone(info.phone),
                icon: Icons.phone_outlined,
              ),
              const SizedBox(height: 8),
              const Text(
                'L\'e-mail et le téléphone ne se modifient pas ici.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('profile_save'),
                onPressed: busy ? null : _save,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _phone(String phone) {
    final local = phone.replaceFirst('+216', '');
    if (local.length != 8) return phone;
    return '+216 ${local.substring(0, 2)} ${local.substring(2, 5)} '
        '${local.substring(5)}';
  }
}

class _LockedField extends StatelessWidget {
  const _LockedField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.surface,
      ),
      child: Text(value),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
