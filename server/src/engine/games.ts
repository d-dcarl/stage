import type { GameId, TripSlot } from '../../../shared/protocol.ts';

export const HOT_TAKES = [
  'Fry sauce belongs on everything.',
  'Pineapple belongs on pizza.',
  'A Costco hot dog is a great first date.',
  'Board games beat a movie for a first date.',
  'You should text back within 5 minutes.',
  'Skiing beats snowboarding.',
];

export const WHO_SAID_PROMPTS = [
  'Worst possible first-date activity?',
  'The most Utah date imaginable?',
  'Your hidden talent nobody believes?',
  'The pickup line that would actually work on you?',
];

export const TRIP_SLOTS: TripSlot[] = ['road', 'brunch', 'rain'];

/** Order of rounds in a standard session. Photos unlock after round index 1. */
export const SESSION: GameId[] = ['hotTake', 'whoSaid', 'roadTrip'];
export const UNLOCK_AFTER_ROUND = 1;

export function pickFrom<T>(list: T[], rng: () => number): T {
  return list[Math.floor(rng() * list.length)];
}

export function shuffle<T>(list: T[], rng: () => number): T[] {
  const a = list.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export function clampTake(v: unknown): number | null {
  if (typeof v !== 'number' || !Number.isFinite(v)) return null;
  return Math.max(0, Math.min(100, Math.round(v)));
}

export function cleanText(v: unknown, max = 80): string | null {
  if (typeof v !== 'string') return null;
  const s = v.replace(/\s+/g, ' ').trim().slice(0, max);
  return s.length ? s : null;
}

/** Valid roadTrip answer: three different players from the allowed set, one per slot. */
export function cleanTrip(v: unknown, allowed: Set<string>): Record<TripSlot, string> | null {
  if (!v || typeof v !== 'object') return null;
  const o = v as Record<string, unknown>;
  const ids = TRIP_SLOTS.map((s) => o[s]);
  if (!ids.every((id) => typeof id === 'string' && allowed.has(id))) return null;
  if (new Set(ids).size !== 3) return null;
  return { road: ids[0] as string, brunch: ids[1] as string, rain: ids[2] as string };
}

/**
 * Public roadTrip result: road trip and brunch totals per player.
 * Rain checks are never revealed, to anyone.
 */
export function tallyTrip(answers: Map<string, Record<TripSlot, string>>) {
  const totals: Record<string, { road: number; brunch: number }> = {};
  for (const a of answers.values()) {
    for (const slot of ['road', 'brunch'] as const) {
      const id = a[slot];
      totals[id] ??= { road: 0, brunch: 0 };
      totals[id][slot]++;
    }
  }
  return totals;
}
