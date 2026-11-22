import 'package:flutter/material.dart';

import '../net/protocol.dart';
import '../theme.dart';

const _palette = [Color(0xFFF2A65A), Color(0xFF5AA9E6), Color(0xFF7BC47F), Color(0xFFC792EA), Color(0xFFFF8FA3), Color(0xFFE8C468)];

Color colorFor(String id) => _palette[id.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];

List<BoxShadow> frameShadows(String frame) => switch (frame) {
      'neon' => const [BoxShadow(color: Color(0xFF8E7BFF), spreadRadius: 3), BoxShadow(color: Color(0xCC8E7BFF), blurRadius: 14, spreadRadius: 3)],
      'sunset' => const [BoxShadow(color: Color(0xFFF2A65A), spreadRadius: 3), BoxShadow(color: Color(0xFFE85D75), spreadRadius: 6)],
      'gold' => const [BoxShadow(color: Color(0xFFE8C468), spreadRadius: 3), BoxShadow(color: Color(0xCCE8C468), blurRadius: 16, spreadRadius: 4)],
      'twin' => const [BoxShadow(color: Color(0xFFFF7AB6), spreadRadius: 3), BoxShadow(color: Colors.white, spreadRadius: 6)],
      _ => const [],
    };

/// A player's avatar. Wingmen render smaller and muted; the friend they're
/// winging for gets a spotlight ring, so attention goes to the friend.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.player, this.size = 44, this.isMe = false, this.spotlight = false, this.emote});

  final PublicPlayer player;
  final double size;
  final bool isMe;
  final bool spotlight;
  final String? emote;

  @override
  Widget build(BuildContext context) {
    final wing = player.status == Status.wing;
    final shadows = [
      ...frameShadows(player.cosmetics['frame'] ?? 'none'),
      if (spotlight) const BoxShadow(color: Color(0x66FFFFFF), blurRadius: 18, spreadRadius: 8),
    ];
    Widget circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMe ? StageColors.tint : colorFor(player.id),
        boxShadow: shadows,
        border: spotlight ? Border.all(color: Colors.white, width: 2) : null,
      ),
      child: Text(
        isMe ? 'YOU' : player.name.characters.first.toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.w700, color: StageColors.ink, fontSize: isMe ? size * 0.26 : size * 0.4),
      ),
    );
    if (wing) {
      circle = Opacity(
        opacity: 0.5,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0, 0, 0, 1, 0]),
          child: Transform.scale(scale: 0.68, child: circle),
        ),
      );
    }
    return Semantics(
      label: '${isMe ? 'You' : player.name}, ${statusLabel(player.status)}',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          circle,
          if (emote != null)
            Positioned(
              top: -18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6)]),
                child: Text(emote!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: StageColors.ink)),
              ),
            ),
        ]),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.dark = false});
  final Status status;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      Status.open => dark ? (const Color(0xFF3A3270), const Color(0xFFE2DCFF)) : (StageColors.tint, const Color(0xFF3F24C9)),
      Status.friends => dark ? (const Color(0xFF24402A), const Color(0xFFCDEBD0)) : (const Color(0xFFE3F1E4), const Color(0xFF2F6B34)),
      Status.taken => dark ? (const Color(0xFF44284A), const Color(0xFFF1D8F6)) : (const Color(0xFFF4E6F7), const Color(0xFF7A3F86)),
      Status.wing => dark ? (const Color(0xFF33333A), const Color(0xFFD9D9DE)) : (const Color(0xFFEEEDEA), const Color(0xFF46464E)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(statusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
