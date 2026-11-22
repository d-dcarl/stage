import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/room_chrome.dart';

const maxPicks = 3;

class PicksScreen extends ConsumerStatefulWidget {
  const PicksScreen({super.key});
  @override
  ConsumerState<PicksScreen> createState() => _PicksScreenState();
}

class _PicksScreenState extends ConsumerState<PicksScreen> {
  final Map<String, bool> _picks = {}; // id -> heart
  bool _group = true;

  void _toggle(String id) => setState(() {
        if (_picks.containsKey(id)) {
          _picks.remove(id);
        } else if (_picks.length < maxPicks) {
          _picks[id] = false;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick up to 3. Unpick someone first.')));
        }
      });

  void _heart(String id) => setState(() {
        if (!_picks.containsKey(id)) {
          if (_picks.length >= maxPicks) return;
          _picks[id] = true;
        } else {
          _picks[id] = !_picks[id]!;
        }
      });

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: Text('Picks are private', style: TextStyle(color: StageColors.muted, fontSize: 13))),
              DefaultTextStyle(style: const TextStyle(color: StageColors.muted), child: Countdown(endsAt: s.endsAt)),
            ]),
            const SizedBox(height: 8),
            Text('Who would you play with again?', style: display(26)),
            const SizedBox(height: 4),
            const Text('Pick up to 3. Hearts mark dating interest and only work between two Open players. Only mutual picks are revealed.', style: TextStyle(color: StageColors.muted)),
            const SizedBox(height: 16),
            if (s.picksSent)
              const Expanded(child: Center(child: Text('Picks sent. Waiting for the reveal…')))
            else
              Expanded(
                child: ListView(children: [
                  for (final c in s.candidates)
                    if (s.player(c.id) != null)
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: _picks.containsKey(c.id) ? StageColors.accent : StageColors.line, width: _picks.containsKey(c.id) ? 2 : 1),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(children: [
                            Avatar(player: s.player(c.id)!),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Flexible(child: Text(s.player(c.id)!.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  const SizedBox(width: 6),
                                  StatusBadge(s.player(c.id)!.status),
                                ]),
                                if (!c.canHeart) const Text('Friend pick only', style: TextStyle(fontSize: 12, color: StageColors.muted)),
                              ]),
                            ),
                            IconButton(
                              tooltip: 'Dating interest',
                              isSelected: _picks[c.id] == true,
                              onPressed: c.canHeart ? () => _heart(c.id) : null,
                              icon: const Icon(Icons.favorite_border),
                              selectedIcon: const Icon(Icons.favorite, color: StageColors.accent),
                            ),
                            Checkbox(value: _picks.containsKey(c.id), onChanged: (_) => _toggle(c.id)),
                          ]),
                        ),
                      ),
                  CheckboxListTile(
                    value: _group,
                    onChanged: (v) => setState(() => _group = v ?? false),
                    title: const Text('The whole group was great. Up for a group hangout.'),
                    tileColor: StageColors.tint,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ]),
              ),
            const SizedBox(height: 12),
            FilledButton(onPressed: s.picksSent ? null : () => s.sendPicks(_picks, _group), child: const Text('Send picks')),
          ]),
        ),
      ),
    );
  }
}

class RevealScreen extends ConsumerWidget {
  const RevealScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final me = s.player(s.myId ?? '');
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('RESULTS ARE IN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1, color: StageColors.muted)),
          const SizedBox(height: 12),
          for (final id in s.matches)
            if (s.player(id) != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: StageColors.dark, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("IT'S A MATCH · MUTUAL DATING INTEREST", style: TextStyle(color: Color(0xFFC9BFFF), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(children: [
                    if (me != null) Avatar(player: me, isMe: true, size: 56),
                    const SizedBox(width: 10),
                    Avatar(player: s.player(id)!, size: 56),
                    const SizedBox(width: 12),
                    Text(s.player(id)!.name, style: display(22, color: Colors.white)),
                  ]),
                  if (s.takes[s.myId] != null && s.takes[id] != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      (s.takes[s.myId]! - s.takes[id]!).abs() < 20 ? 'Opener: you landed in the same spot on the Hot Take.' : 'Opener: you disagreed on the Hot Take. Settle it.',
                      style: const TextStyle(color: Color(0xFFD9D9DE)),
                    ),
                  ],
                ]),
              ),
          for (final id in s.friends)
            if (s.player(id) != null)
              Card(child: ListTile(leading: Avatar(player: s.player(id)!), title: Text('${s.player(id)!.name} picked you too'), subtitle: const Text('New friend'))),
          if (s.group.isNotEmpty)
            Card(
              color: StageColors.tint,
              child: ListTile(
                title: const Text('Group formed'),
                subtitle: Text('You, ${s.group.map((id) => s.player(id)?.name ?? '').join(', ')} all want to hang out again'),
              ),
            ),
          if (s.matches.isEmpty && s.friends.isEmpty && s.group.isEmpty)
            const Card(child: ListTile(title: Text('No mutual picks this time.'), subtitle: Text("That happens. Nobody sees who didn't pick them."))),
          const SizedBox(height: 24),
          FilledButton(onPressed: s.backToLobby, child: const Text('Play again')),
        ]),
      ),
    );
  }
}
