import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/activity.dart';
import '../data/trip.dart';
import '../data/trip_repository.dart';

class TripChatPage extends StatefulWidget {
  const TripChatPage({super.key, required this.trip});

  final Trip trip;

  @override
  State<TripChatPage> createState() => _TripChatPageState();
}

class _TripChatPageState extends State<TripChatPage> {
  late final Stream<List<TripMessage>> _messages;
  final _text = TextEditingController();
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _messages = context.read<TripRepository>().watchMessages(widget.trip.id);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    final auth = context.read<AuthController>().user!;
    final profile = context.read<ProfileController>().profile;
    setState(() => _sending = true);
    try {
      await context.read<TripRepository>().sendMessage(
        tripId: widget.trip.id,
        authorId: auth.uid,
        authorName: profile?.fullName ?? auth.displayName ?? 'Membre',
        text: body,
      );
      _text.clear();
    } on TripFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthController>().user?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Messages du trajet')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<TripMessage>>(
              stream: _messages,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <TripMessage>[];
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucun message pour l\'instant.\n'
                        'Écrivez pour organiser le rendez-vous.',
                        key: Key('chat_empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  key: const Key('chat_list'),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final message = items[index];
                    final mine = message.authorId == uid;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: mine
                              ? const Color(0xFFDCE8FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5EAF2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(message.text),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Material(
            elevation: 2,
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('chat_input'),
                        controller: _text,
                        maxLength: 500,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Écrire un message…',
                          counterText: '',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const Key('chat_send'),
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
