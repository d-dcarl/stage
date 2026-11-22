import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import '../theme.dart';
import 'avatar.dart';

/// Dark game-room scaffold: header with round + timer, the player row, then the game body.
class RoomScaffold extends ConsumerWidget {
  const RoomScaffold({super.key, required this.title, required this.child, this.showTimer = true});
  final String title;
  final Widget child;
  final bool showTimer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    return Scaffold(
      backgroundColor: StageColors.dark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(color: Color(0xFFC9C9D1), fontSize: 13))),
              if (showTimer) Countdown(endsAt: s.endsAt),
            ]),
            const SizedBox(height: 14),
            const PlayerRow(),
            if (s.isMeWing) const HypeBox(),
            const SizedBox(height: 16),
            Expanded(child: child),
          ]),
        ),
      ),
    );
  }
}

class PlayerRow extends ConsumerWidget {
  const PlayerRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final spot = s.spotlightId;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final p in s.players)
          Column(mainAxisSize: MainAxisSize.min, children: [
            Avatar(player: p, isMe: p.id == s.myId, spotlight: p.id == spot, emote: s.emotes[p.id]),
            const SizedBox(height: 4),
            Text(p.id == s.myId ? 'You' : p.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            StatusBadge(p.status, dark: true),
          ]),
      ],
    );
  }
}

class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.endsAt});
  final DateTime endsAt;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  late Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.endsAt.difference(DateTime.now()).inSeconds.clamp(0, 999);
    return Text('0:${left.toString().padLeft(2, '0')}', style: display(20, color: const Color(0xFFC9BFFF)));
  }
}

/// Emote buttons. Cosmetic emote packs would add to this list.
class ReactBar extends ConsumerWidget {
  const ReactBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.read(sessionProvider);
    return Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
      for (final e in const ['Ha', 'Same', 'No way', 'Oh my heck'])
        OutlinedButton(
          onPressed: () => s.react(e),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: StageColors.darkLine), minimumSize: const Size(44, 44)),
          child: Text(e),
        ),
    ]);
  }
}

/// Wingmen get a private line to their friend.
class HypeBox extends ConsumerStatefulWidget {
  const HypeBox({super.key});
  @override
  ConsumerState<HypeBox> createState() => _HypeBoxState();
}

class _HypeBoxState extends ConsumerState<HypeBox> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _c,
            maxLength: 120,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              counterText: '',
              hintText: 'Private hype note to your friend',
              hintStyle: TextStyle(color: Color(0xFF9E9EA8)),
              filled: true,
              fillColor: StageColors.dark2,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Send hype',
          onPressed: () {
            if (_c.text.trim().isEmpty) return;
            ref.read(sessionProvider).sendHype(_c.text.trim());
            _c.clear();
          },
          icon: const Icon(Icons.send),
        ),
      ]),
    );
  }
}
