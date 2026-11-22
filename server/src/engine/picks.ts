import type { Status } from '../../../shared/protocol.ts';

export interface PickPlayer {
  id: string;
  status: Status;
  partyCode: string;
}

export interface PickInput {
  picks: { id: string; heart: boolean }[];
  group: boolean;
}

export interface Reveal {
  matches: string[];
  friends: string[];
  group: string[];
}

export const MAX_PICKS = 3;

/** Dating interest only counts between two players who are both Open. */
export function canHeart(a: { status: Status }, b: { status: Status }): boolean {
  return a.status === 'open' && b.status === 'open';
}

/**
 * Turns everyone's private picks into what each player sees at the reveal.
 * - Mutual picks with mutual hearts (both Open) become matches.
 * - Any other mutual pick becomes a friend connection.
 * - Players who ticked "whole group" form a group when there are 3 or more of them.
 * - People in the same party never pick each other; those picks are ignored.
 * - Anything one-sided stays invisible.
 */
export function resolvePicks(players: PickPlayer[], inputs: Map<string, PickInput>): Map<string, Reveal> {
  const byId = new Map(players.map((p) => [p.id, p]));
  const clean = new Map<string, Map<string, boolean>>();

  for (const p of players) {
    const input = inputs.get(p.id);
    const chosen = new Map<string, boolean>();
    if (input) {
      for (const pick of input.picks) {
        if (chosen.size >= MAX_PICKS) break;
        const other = byId.get(pick.id);
        if (!other || other.id === p.id) continue;
        if (other.partyCode === p.partyCode) continue;
        chosen.set(other.id, pick.heart && canHeart(p, other));
      }
    }
    clean.set(p.id, chosen);
  }

  const groupIds = players.filter((p) => inputs.get(p.id)?.group).map((p) => p.id);
  const hasGroup = groupIds.length >= 3;

  const out = new Map<string, Reveal>();
  for (const p of players) {
    const mine = clean.get(p.id)!;
    const reveal: Reveal = { matches: [], friends: [], group: [] };
    for (const [otherId, myHeart] of mine) {
      const theirs = clean.get(otherId);
      if (!theirs || !theirs.has(p.id)) continue;
      if (myHeart && theirs.get(p.id)) reveal.matches.push(otherId);
      else reveal.friends.push(otherId);
    }
    if (hasGroup && groupIds.includes(p.id)) reveal.group = groupIds.filter((id) => id !== p.id);
    out.set(p.id, reveal);
  }
  return out;
}
