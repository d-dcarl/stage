import type { ServerMsg, Status } from '../../shared/protocol.ts';
import type { Hub } from './hub.ts';

// Development-only players so one person can test a full room.
// Never enable bots in production: real users must only ever meet real users.

const CAST: { name: string; status: Status; age: number; prompts: string[]; frame: string }[] = [
  { name: 'Emma', status: 'open', age: 24, prompts: ['Weekend: Timp hike', "Can't stop: sourdough"], frame: 'sunset' },
  { name: 'Tyler', status: 'open', age: 26, prompts: ["Can't stop: pickleball", 'Best date: drive-in'], frame: 'neon' },
  { name: 'Sam', status: 'friends', age: 27, prompts: ['Ask me about: board games'], frame: 'none' },
  { name: 'Jake', status: 'taken', age: 25, prompts: ['Known for: bold takes'], frame: 'gold' },
  { name: 'Lily', status: 'open', age: 23, prompts: ['Weekend: Bear Lake'], frame: 'neon' },
  { name: 'Ben', status: 'open', age: 28, prompts: ['Hot take: cold pizza wins'], frame: 'none' },
];

const LINES = [
  'Watching them do their taxes',
  'A 6 a.m. hike with no snacks',
  'Their family reunion',
  'Building IKEA furniture together',
  'Swig run, then Temple Square lights',
  'I can name every Pixar movie in order',
];

export class Bot {
  private id = '';
  private hub: Hub;
  private rng: () => number;
  private later: (fn: () => void, ms: number) => () => void;

  private constructor(hub: Hub, rng: () => number, later: (fn: () => void, ms: number) => () => void) {
    this.hub = hub;
    this.rng = rng;
    this.later = later;
  }

  static spawn(hub: Hub, index: number, rng: () => number, later: (fn: () => void, ms: number) => () => void): void {
    const bot = new Bot(hub, rng, later);
    const who = CAST[index % CAST.length];
    bot.id = hub.connect({ send: (m) => bot.onMessage(m) }, true);
    hub.handle(bot.id, { t: 'hello', name: who.name, status: who.status, cosmetics: { frame: who.frame }, profile: { age: who.age, prompts: who.prompts } });
    hub.handle(bot.id, { t: 'queue' });
  }

  private soon(fn: () => void): void {
    this.later(fn, 800 + Math.floor(this.rng() * 3000));
  }

  private onMessage(msg: ServerMsg): void {
    const r = this.rng;
    switch (msg.t) {
      case 'roundStart':
        if (msg.game === 'hotTake') this.soon(() => this.hub.handle(this.id, { t: 'answer', round: msg.round, value: Math.round(r() * 100) }));
        if (msg.game === 'whoSaid') this.soon(() => this.hub.handle(this.id, { t: 'answer', round: msg.round, value: LINES[Math.floor(r() * LINES.length)] }));
        if (msg.game === 'roadTrip') {
          const c = [...((msg.data as { candidates: string[] }).candidates)].sort(() => r() - 0.5);
          if (c.length >= 3) this.soon(() => this.hub.handle(this.id, { t: 'answer', round: msg.round, value: { road: c[0], brunch: c[1], rain: c[2] } }));
        }
        if (r() < 0.6) this.soon(() => this.hub.handle(this.id, { t: 'react', emote: ['Ha', 'Same', 'No way', 'Oh my heck'][Math.floor(r() * 4)] }));
        return;
      case 'guessStart':
        // Bots guess randomly; they don't know who wrote what.
        return;
      case 'picksStart': {
        const picks = msg.candidates.filter(() => r() < 0.5).slice(0, 3).map((c) => ({ id: c.id, heart: c.canHeart && r() < 0.6 }));
        this.soon(() => this.hub.handle(this.id, { t: 'picks', picks, group: r() < 0.5 }));
        return;
      }
      default:
        return;
    }
  }
}
