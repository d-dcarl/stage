// Mirrors shared/protocol.ts. Keep the two in sync.

enum Status { open, friends, taken, wing }

Status statusFrom(String? s) => Status.values.firstWhere((v) => v.name == s, orElse: () => Status.friends);

String statusLabel(Status s) => switch (s) {
      Status.open => 'Open',
      Status.friends => 'Friends',
      Status.taken => 'Taken',
      Status.wing => 'Wing',
    };

class PublicPlayer {
  final String id;
  final String name;
  final Status status;
  final Map<String, String> cosmetics;
  final String? wingFor;
  final int? age;
  final List<String> prompts;

  const PublicPlayer({
    required this.id,
    required this.name,
    required this.status,
    this.cosmetics = const {},
    this.wingFor,
    this.age,
    this.prompts = const [],
  });

  factory PublicPlayer.fromJson(Map<String, dynamic> j) {
    final profile = j['profile'] as Map<String, dynamic>?;
    return PublicPlayer(
      id: j['id'] as String,
      name: j['name'] as String,
      status: statusFrom(j['status'] as String?),
      cosmetics: (j['cosmetics'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
      wingFor: j['wingFor'] as String?,
      age: (profile?['age'] as num?)?.toInt(),
      prompts: ((profile?['prompts'] as List?) ?? const []).map((e) => '$e').toList(),
    );
  }
}

class PickCandidate {
  final String id;
  final bool canHeart;
  const PickCandidate(this.id, this.canHeart);
}

class GuessAnswer {
  final String answerId;
  final String text;
  const GuessAnswer(this.answerId, this.text);
}
