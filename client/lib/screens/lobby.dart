import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/protocol.dart';
import '../state/session.dart';
import '../theme.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});
  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  late final TextEditingController _name;
  late final TextEditingController _party;

  @override
  void initState() {
    super.initState();
    final s = ref.read(sessionProvider);
    _name = TextEditingController(text: s.name);
    _party = TextEditingController(text: s.partyCodeInput);
  }

  @override
  void dispose() {
    _name.dispose();
    _party.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    const options = [
      (Status.open, 'Open to dating', 'Dating and friend picks'),
      (Status.friends, 'Here to play', 'Friends and games only'),
      (Status.taken, 'Taken', 'Solo or with your partner'),
      (Status.wing, 'Wingman', 'Hype up a friend'),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Stage', style: display(30)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: StageColors.dark, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('NEXT HOT HOUR', style: TextStyle(color: Color(0xFFC9BFFF), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
              Text('Sunday · 7–10 pm', style: display(22, color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'First name', border: OutlineInputBorder(), counterText: ''),
            onChanged: (v) => s.name = v.trim(),
          ),
          const SizedBox(height: 20),
          const Text("TONIGHT I'M…", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1, color: StageColors.muted)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.3,
            children: [
              for (final o in options)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => s.status = o.$1),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: s.status == o.$1 ? StageColors.accent : StageColors.line, width: s.status == o.$1 ? 2 : 1),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(o.$3, style: const TextStyle(fontSize: 12, color: StageColors.muted)),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _party,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            decoration: InputDecoration(
              labelText: s.status == Status.wing ? "Your friend's party code" : 'Party code (optional)',
              helperText: s.partyCode == null ? 'Join a friend by entering their code.' : 'Your code: ${s.partyCode}. Share it to play together.',
              border: const OutlineInputBorder(),
              counterText: '',
            ),
            onChanged: (v) => s.partyCodeInput = v,
          ),
          if (s.error != null) ...[
            const SizedBox(height: 12),
            Text(s.error!, style: const TextStyle(color: Color(0xFFB3261E))),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: s.phase == Phase.connecting ? null : () => s.play(),
            child: Text(s.phase == Phase.connecting ? 'Connecting…' : 'Play'),
          ),
        ]),
      ),
    );
  }
}

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: s.backToLobby, child: const Text('Cancel'))),
            const Spacer(),
            Text('Finding your room', textAlign: TextAlign.center, style: display(28)),
            const SizedBox(height: 8),
            Text('${s.waiting} of ${s.needed} in the queue', textAlign: TextAlign.center, style: const TextStyle(color: StageColors.muted)),
            if (s.partyCode != null) ...[
              const SizedBox(height: 8),
              Text('Party code: ${s.partyCode}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const Spacer(),
            const Text('Avatars and first names only. No photos until round 2.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: StageColors.muted)),
          ]),
        ),
      ),
    );
  }
}
