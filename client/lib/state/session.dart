import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/protocol.dart';
import '../net/stage_socket.dart';

enum Phase { lobby, connecting, queue, answer, guess, results, picks, reveal }

final sessionProvider = ChangeNotifierProvider<SessionController>((ref) => SessionController(StageSocket()));

/// Holds everything about the current session and talks to the server.
/// Screens read from it and call its methods; they never touch the socket.
class SessionController extends ChangeNotifier {
  SessionController(this._socket);

  final StageSocket _socket;
  StreamSubscription? _msgSub;
  StreamSubscription? _closeSub;

  // Who I am (set in the lobby).
  String name = '';
  Status status = Status.open;
  String partyCodeInput = '';
  Map<String, String> cosmetics = {'frame': 'none'};

  // Server-assigned.
  String? myId;
  String? partyCode;
  String? error;

  Phase phase = Phase.lobby;
  int waiting = 0;
  int needed = 6;
  List<PublicPlayer> players = [];
  bool photosUnlocked = false;

  // Current round.
  int round = -1;
  String game = '';
  String prompt = '';
  DateTime endsAt = DateTime.now();
  List<String> tripCandidates = [];
  bool answered = false;
  String myAnswerText = '';
  List<GuessAnswer> guessAnswers = [];
  final Map<String, String> myGuesses = {};
  Map<String, dynamic> lastResult = {};
  final Map<String, int> takes = {};

  // Picks and reveal.
  List<PickCandidate> candidates = [];
  bool picksSent = false;
  List<String> matches = [];
  List<String> friends = [];
  List<String> group = [];

  // Live extras.
  final Map<String, String> emotes = {};
  final _hype = StreamController<String>.broadcast();
  Stream<String> get hype => _hype.stream;

  PublicPlayer? player(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool get isMeWing => status == Status.wing;

  /// The friend a wingman is hyping, from my point of view (used for spotlight styling).
  String? get spotlightId {
    for (final p in players) {
      if (p.status == Status.wing && p.wingFor != null) return p.wingFor;
    }
    return null;
  }

  Future<void> play() async {
    error = null;
    phase = Phase.connecting;
    notifyListeners();
    try {
      if (!_socket.isOpen) {
        await _socket.connect();
        _msgSub = _socket.messages.listen(_onMessage);
        _closeSub = _socket.closed.listen((_) {
          error = 'Lost connection to the server.';
          phase = Phase.lobby;
          notifyListeners();
        });
      }
      _socket.send({
        't': 'hello',
        'name': name.isEmpty ? 'Player' : name,
        'status': status.name,
        'cosmetics': cosmetics,
        if (partyCodeInput.trim().isNotEmpty) 'partyCode': partyCodeInput.trim().toUpperCase(),
      });
      _socket.send({'t': 'queue'});
      phase = Phase.queue;
    } catch (e) {
      error = 'Could not reach the server at $serverUrl';
      phase = Phase.lobby;
    }
    notifyListeners();
  }

  void backToLobby() {
    _socket.send({'t': 'leave'});
    _resetSession();
    phase = Phase.lobby;
    notifyListeners();
  }

  // ---------- actions from screens ----------

  void answerHotTake(int value) {
    takes[myId ?? ''] = value;
    _answer(value);
  }

  void answerWhoSaid(String text) {
    myAnswerText = text.trim();
    _answer(myAnswerText);
  }

  void answerRoadTrip(String road, String brunch, String rain) => _answer({'road': road, 'brunch': brunch, 'rain': rain});

  void _answer(Object value) {
    if (answered) return;
    answered = true;
    _socket.send({'t': 'answer', 'round': round, 'value': value});
    notifyListeners();
  }

  void guess(String answerId, String playerId) {
    if (myGuesses.containsKey(answerId)) return;
    myGuesses[answerId] = playerId;
    _socket.send({'t': 'guess', 'round': round, 'answerId': answerId, 'playerId': playerId});
    notifyListeners();
  }

  void react(String emote) => _socket.send({'t': 'react', 'emote': emote});

  void sendHype(String text) => _socket.send({'t': 'hype', 'text': text});

  void sendPicks(Map<String, bool> picks, bool wholeGroup) {
    if (picksSent) return;
    picksSent = true;
    _socket.send({
      't': 'picks',
      'picks': [for (final e in picks.entries) {'id': e.key, 'heart': e.value}],
      'group': wholeGroup,
    });
    notifyListeners();
  }

  // ---------- server messages ----------

  void _onMessage(Map<String, dynamic> m) {
    switch (m['t']) {
      case 'welcome':
        myId = m['playerId'] as String;
        partyCode = m['partyCode'] as String;
      case 'queueUpdate':
        waiting = (m['waiting'] as num).toInt();
        needed = (m['needed'] as num).toInt();
      case 'roomStart':
        _resetSession();
        players = (m['players'] as List).map((p) => PublicPlayer.fromJson(p as Map<String, dynamic>)).toList();
      case 'roundStart': {
        round = (m['round'] as num).toInt();
        game = m['game'] as String;
        prompt = m['prompt'] as String;
        endsAt = DateTime.fromMillisecondsSinceEpoch((m['endsAt'] as num).toInt());
        answered = false;
        final data = (m['data'] as Map?)?.cast<String, dynamic>();
        tripCandidates = ((data?['candidates'] as List?) ?? const []).map((e) => '$e').toList();
        phase = Phase.answer;
      }
      case 'guessStart':
        guessAnswers = (m['answers'] as List)
            .map((a) => GuessAnswer(a['answerId'] as String, a['text'] as String))
            .toList();
        myGuesses.clear();
        endsAt = DateTime.fromMillisecondsSinceEpoch((m['endsAt'] as num).toInt());
        phase = Phase.guess;
      case 'roundResult':
        lastResult = (m['result'] as Map?)?.cast<String, dynamic>() ?? {};
        if (m['game'] == 'hotTake') {
          final pos = (lastResult['positions'] as Map?) ?? {};
          pos.forEach((k, v) => takes['$k'] = (v as num).toInt());
        }
        phase = Phase.results;
      case 'unlock':
        players = (m['players'] as List).map((p) => PublicPlayer.fromJson(p as Map<String, dynamic>)).toList();
        photosUnlocked = true;
      case 'picksStart':
        candidates = (m['candidates'] as List)
            .map((c) => PickCandidate(c['id'] as String, c['canHeart'] as bool))
            .toList();
        endsAt = DateTime.fromMillisecondsSinceEpoch((m['endsAt'] as num).toInt());
        picksSent = false;
        phase = Phase.picks;
      case 'reveal':
        matches = List<String>.from(m['matches'] as List);
        friends = List<String>.from(m['friends'] as List);
        group = List<String>.from(m['group'] as List);
        phase = Phase.reveal;
      case 'react': {
        final pid = m['playerId'] as String;
        final emote = m['emote'] as String;
        emotes[pid] = emote;
        Timer(const Duration(milliseconds: 1600), () {
          if (emotes[pid] == emote) {
            emotes.remove(pid);
            notifyListeners();
          }
        });
      }
      case 'hype':
        _hype.add(m['text'] as String);
      case 'error':
        error = m['message'] as String?;
    }
    notifyListeners();
  }

  void _resetSession() {
    players = [];
    photosUnlocked = false;
    round = -1;
    answered = false;
    myAnswerText = '';
    guessAnswers = [];
    myGuesses.clear();
    lastResult = {};
    takes.clear();
    candidates = [];
    picksSent = false;
    matches = [];
    friends = [];
    group = [];
    emotes.clear();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _closeSub?.cancel();
    _socket.close();
    _hype.close();
    super.dispose();
  }
}
