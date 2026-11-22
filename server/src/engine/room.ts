import type { ClientMsg, GameId, PublicPlayer, ServerMsg, Status, TripSlot } from '../../../shared/protocol.ts';
import { HOT_TAKES, SESSION, TRIP_SLOTS, UNLOCK_AFTER_ROUND, WHO_SAID_PROMPTS, cleanText, cleanTrip, clampTake, pickFrom, shuffle, tallyTrip } from './games.ts';
import { canHeart, resolvePicks, type PickInput, type Reveal } from './picks.ts';

export interface RoomPlayer {
  id: string;
  name: string;
  status: Status;
  partyCode: string;
  cosmetics: Record<string, string>;
  wingFor?: string;
  profile: { age: number; prompts: string[]; photoUrl?: string };
}

export interface RoomDeps {
  send(playerId: string, msg: ServerMsg): void;
  /** Runs fn after ms; returns a cancel function. Injected so tests can control time. */
  schedule(fn: () => void, ms: number): () => void;
  now(): number;
  rng(): number;
  onDone?(reveals: Map<string, Reveal>): void;
}

export interface RoomTimings {
  hotTake: number;
  whoSaid: number;
  guess: number;
  roadTrip: number;
  results: number;
  picks: number;
}

export const DEFAULT_TIMINGS: RoomTimings = { hotTake: 20_000, whoSaid: 40_000, guess: 30_000, roadTrip: 45_000, results: 5_000, picks: 60_000 };

type Phase = 'idle' | 'answer' | 'guess' | 'results' | 'picks' | 'done';

export class Room {
  readonly id: string;
  readonly players: RoomPlayer[];
  private deps: RoomDeps;
  private timings: RoomTimings;
  private phase: Phase = 'idle';
  private round = -1;
  private cancel: (() => void) | null = null;
  private answers = new Map<string, unknown>();
  private whoAuthors = new Map<string, string>(); // answerId -> playerId
  private guesses = new Map<string, Map<string, string>>(); // guesser -> answerId -> guessed playerId
  private picks = new Map<string, PickInput>();
  private lastReact = new Map<string, number>();
  readonly takes = new Map<string, number>();

  constructor(id: string, players: RoomPlayer[], deps: RoomDeps, timings: RoomTimings = DEFAULT_TIMINGS) {
    this.id = id;
    this.players = players;
    this.deps = deps;
    this.timings = timings;
  }

  get currentPhase(): Phase { return this.phase; }
  get currentRound(): number { return this.round; }

  start(): void {
    this.broadcast({ t: 'roomStart', roomId: this.id, players: this.players.map((p) => this.publicOf(p, false)) });
    this.startRound(0);
  }

  /** Handles one message from a player in this room. Bad input is ignored, never trusted. */
  handle(playerId: string, msg: ClientMsg): void {
    const me = this.players.find((p) => p.id === playerId);
    if (!me) return;
    switch (msg.t) {
      case 'react': {
        const last = this.lastReact.get(playerId) ?? 0;
        if (this.deps.now() - last < 700) return;
        const emote = cleanText(msg.emote, 24);
        if (!emote) return;
        this.lastReact.set(playerId, this.deps.now());
        this.broadcast({ t: 'react', playerId, emote });
        return;
      }
      case 'hype': {
        if (me.status !== 'wing' || !me.wingFor) return;
        const text = cleanText(msg.text, 120);
        if (text) this.deps.send(me.wingFor, { t: 'hype', from: me.id, text });
        return;
      }
      case 'answer': {
        if (this.phase !== 'answer' || msg.round !== this.round || this.answers.has(playerId)) return;
        const value = this.cleanAnswer(me, msg.value);
        if (value === null) return;
        this.answers.set(playerId, value);
        if (this.allAnswered()) this.endAnswerPhase();
        return;
      }
      case 'guess': {
        if (this.phase !== 'guess' || msg.round !== this.round) return;
        const author = this.whoAuthors.get(msg.answerId);
        if (!author || author === playerId) return;
        const mine = this.guesses.get(playerId) ?? new Map<string, string>();
        if (mine.has(msg.answerId)) return;
        mine.set(msg.answerId, msg.playerId);
        this.guesses.set(playerId, mine);
        if (this.allGuessed()) this.endGuessPhase();
        return;
      }
      case 'picks': {
        if (this.phase !== 'picks' || this.picks.has(playerId)) return;
        this.picks.set(playerId, { picks: Array.isArray(msg.picks) ? msg.picks : [], group: !!msg.group });
        if (this.picks.size === this.players.length) this.reveal();
        return;
      }
      default:
        return;
    }
  }

  /** A player dropped. They stay in the room as an empty seat so the game can finish. */
  leave(playerId: string): void {
    if (this.phase === 'answer' && this.allAnswered()) this.endAnswerPhase();
  }

  // ---------- flow ----------

  private game(): GameId { return SESSION[this.round]; }

  private startRound(index: number): void {
    this.round = index;
    this.answers.clear();
    this.phase = 'answer';
    const game = this.game();
    const ms = this.timings[game];
    const endsAt = this.deps.now() + ms;
    if (game === 'hotTake') {
      this.broadcast({ t: 'roundStart', round: index, game, prompt: pickFrom(HOT_TAKES, this.deps.rng), endsAt });
    } else if (game === 'whoSaid') {
      this.broadcast({ t: 'roundStart', round: index, game, prompt: pickFrom(WHO_SAID_PROMPTS, this.deps.rng), endsAt });
    } else {
      // Each player gets their own list of people they may place.
      for (const p of this.players) {
        this.deps.send(p.id, { t: 'roundStart', round: index, game, prompt: 'Road Trip, Brunch, Rain Check', endsAt, data: { candidates: [...this.tripCandidates(p)], slots: TRIP_SLOTS } });
      }
    }
    this.timer(ms, () => this.endAnswerPhase());
  }

  private endAnswerPhase(): void {
    if (this.phase !== 'answer') return;
    const game = this.game();
    if (game === 'whoSaid') return this.startGuessPhase();
    let result: unknown;
    if (game === 'hotTake') {
      for (const [id, v] of this.answers) this.takes.set(id, v as number);
      result = { positions: Object.fromEntries(this.answers) };
    } else {
      result = { totals: tallyTrip(this.answers as Map<string, Record<TripSlot, string>>) };
    }
    this.showResults(game, result);
  }

  private startGuessPhase(): void {
    this.phase = 'guess';
    this.whoAuthors.clear();
    this.guesses.clear();
    const list = shuffle([...this.answers.entries()], this.deps.rng).map(([playerId, text], i) => {
      const answerId = `a${i}`;
      this.whoAuthors.set(answerId, playerId);
      return { answerId, text: text as string };
    });
    if (list.length === 0) return this.showResults('whoSaid', { answers: [], scores: {} });
    this.broadcast({ t: 'guessStart', round: this.round, answers: list, endsAt: this.deps.now() + this.timings.guess });
    this.timer(this.timings.guess, () => this.endGuessPhase());
  }

  private endGuessPhase(): void {
    if (this.phase !== 'guess') return;
    const scores: Record<string, number> = {};
    for (const [guesser, map] of this.guesses) {
      for (const [answerId, guessed] of map) {
        if (this.whoAuthors.get(answerId) === guessed) scores[guesser] = (scores[guesser] ?? 0) + 1;
      }
    }
    const answers = [...this.whoAuthors.entries()].map(([answerId, author]) => ({ answerId, author, text: this.answers.get(author) }));
    this.showResults('whoSaid', { answers, scores });
  }

  private showResults(game: GameId, result: unknown): void {
    this.phase = 'results';
    this.broadcast({ t: 'roundResult', round: this.round, game, result });
    this.timer(this.timings.results, () => {
      if (this.round === UNLOCK_AFTER_ROUND) {
        this.broadcast({ t: 'unlock', players: this.players.map((p) => this.publicOf(p, true)) });
      }
      if (this.round + 1 < SESSION.length) this.startRound(this.round + 1);
      else this.startPicks();
    });
  }

  private startPicks(): void {
    this.phase = 'picks';
    this.picks.clear();
    const endsAt = this.deps.now() + this.timings.picks;
    for (const p of this.players) {
      const candidates = this.players
        .filter((o) => o.id !== p.id && o.partyCode !== p.partyCode)
        .map((o) => ({ id: o.id, canHeart: canHeart(p, o) }));
      this.deps.send(p.id, { t: 'picksStart', endsAt, candidates });
    }
    this.timer(this.timings.picks, () => this.reveal());
  }

  private reveal(): void {
    if (this.phase !== 'picks') return;
    this.phase = 'done';
    this.cancel?.();
    const reveals = resolvePicks(this.players, this.picks);
    for (const [id, r] of reveals) this.deps.send(id, { t: 'reveal', ...r });
    this.deps.onDone?.(reveals);
  }

  // ---------- helpers ----------

  private timer(ms: number, fn: () => void): void {
    this.cancel?.();
    this.cancel = this.deps.schedule(fn, ms);
  }

  private broadcast(msg: ServerMsg): void {
    for (const p of this.players) this.deps.send(p.id, msg);
  }

  private tripCandidates(p: RoomPlayer): Set<string> {
    return new Set(this.players.filter((o) => o.id !== p.id && o.partyCode !== p.partyCode && o.status !== 'wing').map((o) => o.id));
  }

  /** Players who can answer this round. Road Trip needs at least 3 people to place. */
  private eligible(): RoomPlayer[] {
    if (this.game() === 'roadTrip') return this.players.filter((p) => this.tripCandidates(p).size >= 3);
    return this.players;
  }

  private allAnswered(): boolean { return this.eligible().every((p) => this.answers.has(p.id)); }

  private allGuessed(): boolean {
    const total = this.whoAuthors.size;
    return this.players.every((p) => {
      const own = [...this.whoAuthors.values()].includes(p.id) ? 1 : 0;
      return (this.guesses.get(p.id)?.size ?? 0) >= total - own;
    });
  }

  private cleanAnswer(p: RoomPlayer, v: unknown): unknown {
    switch (this.game()) {
      case 'hotTake': return clampTake(v);
      case 'whoSaid': return cleanText(v, 80);
      case 'roadTrip': return cleanTrip(v, this.tripCandidates(p));
    }
  }

  private publicOf(p: RoomPlayer, withProfile: boolean): PublicPlayer {
    const out: PublicPlayer = { id: p.id, name: p.name, status: p.status, cosmetics: p.cosmetics };
    if (p.wingFor) out.wingFor = p.wingFor;
    if (withProfile) out.profile = p.profile;
    return out;
  }
}
