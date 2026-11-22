import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/room_chrome.dart';

const _gameNames = {'hotTake': 'Hot Take', 'whoSaid': 'Who Said It', 'roadTrip': 'Road Trip, Brunch, Rain Check'};

String roundTitle(SessionController s) => 'Round ${s.round + 1} of 3 · ${_gameNames[s.game] ?? s.game}';

Widget _waiting() => const Center(child: Text('Locked in. Waiting for the room…', style: TextStyle(color: Color(0xFFB9B9C3))));

Widget _prompt(String text, {double size = 30}) =>
    Text(text, textAlign: TextAlign.center, style: display(size, color: Colors.white));

/// Picks the right screen for the current round's answer phase.
class AnswerScreen extends ConsumerWidget {
  const AnswerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final body = switch (s.game) {
      'hotTake' => const HotTakeBody(),
      'whoSaid' => const WhoSaidBody(),
      'roadTrip' => const RoadTripBody(),
      _ => const SizedBox(),
    };
    return RoomScaffold(title: roundTitle(s), child: s.answered ? _waiting() : body);
  }
}

// ---------- Hot Take ----------

class HotTakeBody extends ConsumerStatefulWidget {
  const HotTakeBody({super.key});
  @override
  ConsumerState<HotTakeBody> createState() => _HotTakeBodyState();
}

class _HotTakeBodyState extends ConsumerState<HotTakeBody> {
  double _v = 50;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('HOT TAKE', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFC9BFFF), fontWeight: FontWeight.w600, letterSpacing: 1, fontSize: 12)),
      const SizedBox(height: 8),
      _prompt(s.prompt),
      const SizedBox(height: 32),
      Slider(value: _v, min: 0, max: 100, activeColor: StageColors.accentLight, label: 'Where you stand', onChanged: (v) => setState(() => _v = v)),
      const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Never', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        Text('Obviously', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 24),
      const ReactBar(),
      const Spacer(),
      FilledButton(onPressed: () => s.answerHotTake(_v.round()), child: const Text('Lock in')),
    ]);
  }
}

// ---------- Who Said It ----------

class WhoSaidBody extends ConsumerStatefulWidget {
  const WhoSaidBody({super.key});
  @override
  ConsumerState<WhoSaidBody> createState() => _WhoSaidBodyState();
}

class _WhoSaidBodyState extends ConsumerState<WhoSaidBody> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('ANSWER ANONYMOUSLY', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFC9BFFF), fontWeight: FontWeight.w600, letterSpacing: 1, fontSize: 12)),
      const SizedBox(height: 8),
      _prompt(s.prompt, size: 26),
      const SizedBox(height: 20),
      TextField(
        controller: _c,
        maxLength: 80,
        maxLines: 3,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(hintText: 'Make the room laugh…', hintStyle: TextStyle(color: Color(0xFF9E9EA8)), filled: true, fillColor: StageColors.dark2, border: OutlineInputBorder()),
      ),
      const Spacer(),
      FilledButton(onPressed: () { if (_c.text.trim().isNotEmpty) s.answerWhoSaid(_c.text); }, child: const Text('Submit answer')),
    ]);
  }
}

class GuessScreen extends ConsumerWidget {
  const GuessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final others = s.players.where((p) => p.id != s.myId).toList();
    final answers = s.guessAnswers.where((a) => a.text != s.myAnswerText).toList();
    return RoomScaffold(
      title: 'Round 2 · Who said it?',
      child: ListView(children: [
        for (final a in answers)
          Card(
            color: const Color(0xFF221E40),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('"${a.text}"', style: display(18, color: Colors.white)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in others)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: s.myGuesses[a.answerId] == p.id,
                      onSelected: s.myGuesses.containsKey(a.answerId) ? null : (_) => s.guess(a.answerId, p.id),
                    ),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ---------- Road Trip, Brunch, Rain Check ----------

class RoadTripBody extends ConsumerStatefulWidget {
  const RoadTripBody({super.key});
  @override
  ConsumerState<RoadTripBody> createState() => _RoadTripBodyState();
}

class _RoadTripBodyState extends ConsumerState<RoadTripBody> {
  final Map<String, String?> _slots = {'road': null, 'brunch': null, 'rain': null};
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (s.tripCandidates.length < 3) {
      return const Center(child: Text('Not enough people to place this round. Sit back and enjoy.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)));
    }
    final used = _slots.values.whereType<String>().toSet();
    const labels = {'road': 'Road trip', 'brunch': 'Brunch', 'rain': 'Rain check'};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Tap a person, then a slot. Only totals are shared. Rain checks are never shown.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFB9B9C3))),
      const SizedBox(height: 16),
      Row(children: [
        for (final slot in labels.keys)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => setState(() {
                  if (_selected != null) {
                    _slots.updateAll((k, v) => v == _selected ? null : v);
                    _slots[slot] = _selected;
                    _selected = null;
                  } else {
                    _slots[slot] = null;
                  }
                }),
                child: Container(
                  height: 130,
                  decoration: BoxDecoration(
                    color: _slots[slot] != null ? const Color(0xFF221E40) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _slots[slot] != null ? StageColors.accentLight : StageColors.darkLine, width: 2),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(labels[slot]!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (_slots[slot] != null && s.player(_slots[slot]!) != null)
                      Avatar(player: s.player(_slots[slot]!)!)
                    else
                      const Text('Empty', style: TextStyle(color: Color(0xFF9E9EA8), fontSize: 12)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 20),
      Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
        for (final id in s.tripCandidates)
          if (s.player(id) != null)
            Opacity(
              opacity: used.contains(id) ? 0.35 : 1,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _selected = id),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _selected == id ? StageColors.accentLight : Colors.transparent, width: 2),
                  ),
                  child: Column(children: [
                    Avatar(player: s.player(id)!, size: 48),
                    const SizedBox(height: 4),
                    Text(s.player(id)!.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ]),
                ),
              ),
            ),
      ]),
      const Spacer(),
      FilledButton(
        onPressed: _slots.values.every((v) => v != null) ? () => s.answerRoadTrip(_slots['road']!, _slots['brunch']!, _slots['rain']!) : null,
        child: const Text('Lock in'),
      ),
    ]);
  }
}

// ---------- Results ----------

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final r = s.lastResult;
    Widget body;
    if (s.game == 'hotTake') {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _prompt(s.prompt, size: 22),
        const SizedBox(height: 24),
        SizedBox(
          height: 60,
          child: LayoutBuilder(builder: (context, c) {
            return Stack(children: [
              Positioned(left: 0, right: 0, top: 29, child: Container(height: 2, color: StageColors.darkLine)),
              for (final p in s.players)
                if (s.takes[p.id] != null)
                  Positioned(left: (c.maxWidth - 30) * s.takes[p.id]! / 100, top: 15, child: Avatar(player: p, size: 30, isMe: p.id == s.myId)),
            ]);
          }),
        ),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Never', style: TextStyle(color: Colors.white)),
          Text('Obviously', style: TextStyle(color: Colors.white)),
        ]),
      ]);
    } else if (s.game == 'whoSaid') {
      final answers = (r['answers'] as List?) ?? const [];
      final score = ((r['scores'] as Map?)?[s.myId] as num?)?.toInt() ?? 0;
      body = ListView(children: [
        Text('You guessed $score right', style: display(22, color: Colors.white)),
        const SizedBox(height: 12),
        for (final a in answers)
          ListTile(
            title: Text('"${a['text']}"', style: const TextStyle(color: Colors.white)),
            subtitle: Text(s.player(a['author'] as String)?.name ?? '', style: const TextStyle(color: Color(0xFFC9BFFF))),
          ),
      ]);
    } else {
      final mine = ((r['totals'] as Map?)?[s.myId] as Map?) ?? const {};
      final road = (mine['road'] as num?)?.toInt() ?? 0;
      final brunch = (mine['brunch'] as num?)?.toInt() ?? 0;
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('You got $road road trip${road == 1 ? '' : 's'} and $brunch brunch${brunch == 1 ? '' : 'es'}.', style: display(22, color: Colors.white)),
        const SizedBox(height: 8),
        const Text('Rain checks are never shown. Nobody sees who picked whom.', style: TextStyle(color: Color(0xFF9E9EA8))),
      ]);
    }
    return RoomScaffold(title: 'Round ${s.round + 1} results', showTimer: false, child: body);
  }
}

// ---------- Unlocked profiles (shown as a sheet when photos unlock) ----------

class UnlockedProfiles extends ConsumerWidget {
  const UnlockedProfiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Photos unlocked', style: display(22)),
        const Text("You've seen how they play. Now see who they are.", style: TextStyle(color: StageColors.muted)),
        const SizedBox(height: 12),
        for (final p in s.players.where((p) => p.id != s.myId))
          ListTile(
            leading: Avatar(player: p, size: 40),
            title: Row(children: [Text('${p.name}${p.age != null ? ', ${p.age}' : ''}'), const SizedBox(width: 6), StatusBadge(p.status)]),
            subtitle: Text(p.prompts.isEmpty ? '' : p.prompts.first),
          ),
      ]),
    );
  }
}
