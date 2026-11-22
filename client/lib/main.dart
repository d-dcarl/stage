import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/lobby.dart';
import 'screens/picks.dart';
import 'screens/rounds.dart';
import 'state/session.dart';
import 'theme.dart';

void main() => runApp(const ProviderScope(child: StageApp()));

class StageApp extends StatelessWidget {
  const StageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stage',
      theme: stageTheme(),
      debugShowCheckedModeBanner: false,
      home: const SessionRouter(),
    );
  }
}

/// Shows the screen for the current phase and surfaces live events
/// (wingman hype notes, photo unlock) as overlays.
class SessionRouter extends ConsumerStatefulWidget {
  const SessionRouter({super.key});
  @override
  ConsumerState<SessionRouter> createState() => _SessionRouterState();
}

class _SessionRouterState extends ConsumerState<SessionRouter> {
  StreamSubscription<String>? _hypeSub;
  bool _shownUnlock = false;

  @override
  void initState() {
    super.initState();
    _hypeSub = ref.read(sessionProvider).hype.listen((text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Your wingman: $text'), duration: const Duration(seconds: 4)));
    });
  }

  @override
  void dispose() {
    _hypeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);

    if (s.photosUnlocked && !_shownUnlock) {
      _shownUnlock = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showModalBottomSheet(context: context, builder: (_) => const UnlockedProfiles());
      });
    }
    if (!s.photosUnlocked) _shownUnlock = false;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (s.phase) {
        Phase.lobby || Phase.connecting => const LobbyScreen(),
        Phase.queue => const QueueScreen(),
        Phase.answer => AnswerScreen(key: ValueKey('answer-${s.round}')),
        Phase.guess => const GuessScreen(),
        Phase.results => ResultsScreen(key: ValueKey('results-${s.round}')),
        Phase.picks => const PicksScreen(),
        Phase.reveal => const RevealScreen(),
      },
    );
  }
}
