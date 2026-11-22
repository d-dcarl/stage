import type { ClientMsg, ServerMsg, Status } from '../../shared/protocol.ts';
import { DEFAULT_MATCH, formRooms, type MatchOptions, type QueueEntry } from './engine/matchmaker.ts';
import { DEFAULT_TIMINGS, Room, type RoomPlayer, type RoomTimings } from './engine/room.ts';
import { Bot } from './bots.ts';

/** Anything that can receive a message: a WebSocket, or an in-process bot. */
export interface Conn {
  send(msg: ServerMsg): void;
}

interface Session {
  id: string;
  conn: Conn;
  name: string;
  status: Status;
  partyCode: string;
  cosmetics: Record<string, string>;
  profile: { age: number; prompts: string[] };
  blocked: Set<string>;
  phoneHash?: string;
  room?: Room;
  queuedAt?: number;
  isBot: boolean;
}

export interface HubOptions {
  match: MatchOptions;
  timings: RoomTimings;
  /** Fill rooms with bots once a real player has waited this long. 0 = no bots. */
  botFillAfterMs: number;
  now(): number;
  schedule(fn: () => void, ms: number): () => void;
  rng(): number;
}

export const DEFAULT_HUB: HubOptions = {
  match: DEFAULT_MATCH,
  timings: DEFAULT_TIMINGS,
  botFillAfterMs: 0,
  now: () => Date.now(),
  schedule: (fn, ms) => { const t = setTimeout(fn, ms); return () => clearTimeout(t); },
  rng: Math.random,
};

const STATUSES: Status[] = ['open', 'friends', 'taken', 'wing'];

export class Hub {
  private sessions = new Map<string, Session>();
  private queue: string[] = [];
  private seq = 0;
  private opts: HubOptions;

  constructor(opts: Partial<HubOptions> = {}) {
    this.opts = { ...DEFAULT_HUB, ...opts };
  }

  connect(conn: Conn, isBot = false): string {
    const id = `${isBot ? 'bot' : 'p'}${++this.seq}`;
    this.sessions.set(id, {
      id, conn, isBot, name: 'Player', status: 'friends', partyCode: this.code(), cosmetics: {},
      profile: { age: 25, prompts: [] }, blocked: new Set(),
    });
    return id;
  }

  disconnect(id: string): void {
    const s = this.sessions.get(id);
    if (!s) return;
    this.queue = this.queue.filter((q) => q !== id);
    s.room?.leave(id);
    this.sessions.delete(id);
  }

  /** Raw text from a socket. Anything malformed is dropped. */
  receive(id: string, raw: string): void {
    let msg: ClientMsg;
    try { msg = JSON.parse(raw); } catch { return; }
    if (!msg || typeof msg !== 'object' || typeof (msg as { t?: unknown }).t !== 'string') return;
    this.handle(id, msg);
  }

  handle(id: string, msg: ClientMsg): void {
    const s = this.sessions.get(id);
    if (!s) return;
    switch (msg.t) {
      case 'hello': {
        s.name = String(msg.name ?? '').trim().slice(0, 20) || 'Player';
        s.status = STATUSES.includes(msg.status) ? msg.status : 'friends';
        if (typeof msg.partyCode === 'string' && /^[A-Z0-9]{4,8}$/.test(msg.partyCode)) s.partyCode = msg.partyCode;
        s.cosmetics = msg.cosmetics && typeof msg.cosmetics === 'object' ? msg.cosmetics : {};
        if (msg.profile) s.profile = { age: Number(msg.profile.age) || 25, prompts: (msg.profile.prompts ?? []).slice(0, 3).map(String) };
        s.conn.send({ t: 'welcome', playerId: id, partyCode: s.partyCode });
        return;
      }
      case 'queue': {
        if (s.room || this.queue.includes(id)) return;
        s.queuedAt = this.opts.now();
        this.queue.push(id);
        if (!s.isBot) this.tick();
        return;
      }
      case 'leave': {
        this.queue = this.queue.filter((q) => q !== id);
        s.room = undefined;
        return;
      }
      default:
        s.room?.handle(id, msg);
    }
  }

  /** Call about once a second: forms rooms and adds bots when allowed. */
  tick(): void {
    const now = this.opts.now();
    if (this.opts.botFillAfterMs > 0) this.fillWithBots(now);
    const entries: QueueEntry[] = this.queue.map((id) => {
      const s = this.sessions.get(id)!;
      return { id, status: s.status, partyCode: s.partyCode, joinedAt: s.queuedAt ?? now, blocked: s.blocked, phoneHash: s.phoneHash };
    });
    const { rooms } = formRooms(entries, now, this.opts.match);
    for (const r of rooms) this.startRoom(r.map((e) => e.id));
    for (const id of this.queue) {
      const s = this.sessions.get(id);
      s?.conn.send({ t: 'queueUpdate', waiting: this.queue.length, needed: this.opts.match.roomSize });
    }
  }

  private startRoom(ids: string[]): void {
    this.queue = this.queue.filter((q) => !ids.includes(q));
    const members = ids.map((id) => this.sessions.get(id)!);
    const players: RoomPlayer[] = members.map((s) => ({
      id: s.id, name: s.name, status: s.status, partyCode: s.partyCode, cosmetics: s.cosmetics, profile: s.profile,
      wingFor: s.status === 'wing' ? members.find((m) => m.partyCode === s.partyCode && m.id !== s.id && m.status !== 'wing')?.id : undefined,
    }));
    const room = new Room(`r${++this.seq}`, players, {
      send: (pid, msg) => this.sessions.get(pid)?.conn.send(msg),
      schedule: this.opts.schedule,
      now: this.opts.now,
      rng: this.opts.rng,
      onDone: () => {
        for (const m of members) {
          if (m.isBot) this.disconnect(m.id);
          else m.room = undefined;
        }
      },
    }, this.opts.timings);
    for (const s of members) s.room = room;
    room.start();
  }

  private fillWithBots(now: number): void {
    const humans = this.queue.map((id) => this.sessions.get(id)!).filter((s) => !s.isBot);
    if (!humans.length) return;
    const oldest = Math.min(...humans.map((s) => s.queuedAt ?? now));
    if (now - oldest < this.opts.botFillAfterMs) return;
    const missing = this.opts.match.roomSize - this.queue.length;
    for (let i = 0; i < missing; i++) Bot.spawn(this, i, this.opts.rng, this.opts.schedule);
  }

  private code(): string {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let c = '';
    for (let i = 0; i < 6; i++) c += chars[Math.floor(this.opts.rng() * chars.length)];
    return c;
  }
}
