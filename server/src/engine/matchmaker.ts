import type { Status } from '../../../shared/protocol.ts';

export interface QueueEntry {
  id: string;
  status: Status;
  partyCode: string;
  joinedAt: number;
  /** Keyed hash of this player's own phone number (never the raw number). */
  phoneHash?: string;
  /** Keyed hashes of numbers this player has blocked. */
  blocked: Set<string>;
}

export interface MatchOptions {
  roomSize: number;
  minSize: number;
  /** After the oldest player has waited this long, a room may start below roomSize. */
  waitMs: number;
  /** Rooms aim for at least this many Open players when the queue allows it. */
  minOpen: number;
}

export const DEFAULT_MATCH: MatchOptions = { roomSize: 6, minSize: 4, waitMs: 60_000, minOpen: 4 };

function blocks(a: QueueEntry, b: QueueEntry): boolean {
  return (!!b.phoneHash && a.blocked.has(b.phoneHash)) || (!!a.phoneHash && b.blocked.has(a.phoneHash));
}

/** Players in the same party always travel together. */
function units(queue: QueueEntry[]): QueueEntry[][] {
  const byParty = new Map<string, QueueEntry[]>();
  for (const e of [...queue].sort((a, b) => a.joinedAt - b.joinedAt)) {
    const list = byParty.get(e.partyCode) ?? [];
    list.push(e);
    byParty.set(e.partyCode, list);
  }
  return [...byParty.values()];
}

function fits(room: QueueEntry[], unit: QueueEntry[], size: number): boolean {
  if (room.length + unit.length > size) return false;
  return unit.every((u) => room.every((r) => !blocks(u, r)));
}

const openCount = (es: QueueEntry[]) => es.filter((e) => e.status === 'open').length;

/**
 * Greedy room builder. Oldest players are seated first; parties stay together;
 * blocked pairs never share a room. Open players are seated before others until
 * the room reaches minOpen, so daters get enough options.
 */
export function formRooms(queue: QueueEntry[], now: number, opts: MatchOptions = DEFAULT_MATCH) {
  let pool = units(queue);
  const rooms: QueueEntry[][] = [];

  while (pool.length) {
    const room: QueueEntry[] = [];
    const used = new Set<number>();
    const seed = 0;
    room.push(...pool[seed]);
    used.add(seed);

    const tryAdd = (pred: (u: QueueEntry[]) => boolean) => {
      for (let i = 0; i < pool.length && room.length < opts.roomSize; i++) {
        if (used.has(i) || !pred(pool[i]) || !fits(room, pool[i], opts.roomSize)) continue;
        room.push(...pool[i]);
        used.add(i);
      }
    };
    // First pass: fill up Open seats, then everyone else.
    tryAdd((u) => openCount(room) < opts.minOpen && openCount(u) > 0);
    tryAdd(() => true);

    const oldest = Math.min(...room.map((e) => e.joinedAt));
    const ready = room.length === opts.roomSize || (room.length >= opts.minSize && now - oldest >= opts.waitMs);
    if (!ready) break; // the oldest player can't be seated yet; keep everyone queued in order
    rooms.push(room);
    pool = pool.filter((_, i) => !used.has(i));
  }

  const seated = new Set(rooms.flat().map((e) => e.id));
  return { rooms, remaining: queue.filter((e) => !seated.has(e.id)) };
}
