import 'package:flutter_test/flutter_test.dart';
import 'package:stage/net/protocol.dart';

void main() {
  test('PublicPlayer parses status, cosmetics and unlocked profile', () {
    final p = PublicPlayer.fromJson({
      'id': 'p1',
      'name': 'Emma',
      'status': 'open',
      'cosmetics': {'frame': 'neon'},
      'profile': {'age': 24, 'prompts': ['Weekend: Timp hike']},
    });
    expect(p.status, Status.open);
    expect(p.cosmetics['frame'], 'neon');
    expect(p.age, 24);
    expect(p.prompts.first, 'Weekend: Timp hike');
  });

  test('unknown status falls back to friends', () {
    expect(statusFrom('nonsense'), Status.friends);
  });
}
