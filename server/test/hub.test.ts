import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Hub } from '../src/hub.ts';
import type { ServerMsg } from '../../shared/protocol.ts';

function fakeClock() {
  let now = 0;
  let pending: { at: number; fn: () => void; dead: boolean }[] = [];
  return {
    now: () => now,
    schedule(fn: () => void, ms: number) {
      const job = { at: now + ms, fn, dead: false };
      pending.push(job);
      return () => { job.dead = true; };
    },
    advance(ms: number) {
      const target = now + ms;
      for (;;) {
        pending = pending.filter((j) => !j.dead);
        const next = pending.sort((a, b) => a.at - b.at)[0];
        if (!next || next.at > target) break;
        now = next.at;
        next.dead = true;
        next.fn();
      }
      now = target;
    },
  };
}

test('one human plus bots plays a whole session and gets a reveal', () => {
  const clock = fakeClock();
  let seed = 7;
  const rng = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
  const hub = new Hub({ botFillAfterMs: 3000, now: clock.now, schedule: clock.schedule, rng });
  const inbox: ServerMsg[] = [];
  const me = hub.connect({ send: (m) => inbox.push(m) });

  hub.receive(me, JSON.stringify({ t: 'hello', name: 'Dallin', status: 'open' }));
  hub.receive(me, 'not json'); // ignored
  hub.receive(me, JSON.stringify({ t: 'queue' }));
  assert.ok(inbox.some((m) => m.t === 'welcome'));

  for (let s = 0; s < 4; s++) { clock.advance(1000); hub.tick(); }
  const start = inbox.find((m) => m.t === 'roomStart');
  assert.ok(start, 'room starts once bots fill it');

  // Play every round as the human.
  for (let step = 0; step < 400 && !inbox.some((m) => m.t === 'reveal'); step++) {
    const last = inbox[inbox.length - 1];
    if (last.t === 'roundStart' && last.game === 'hotTake') hub.handle(me, { t: 'answer', round: last.round, value: 70 });
    if (last.t === 'roundStart' && last.game === 'whoSaid') hub.handle(me, { t: 'answer', round: last.round, value: 'A silent retreat' });
    if (last.t === 'roundStart' && last.game === 'roadTrip') {
      const c = (last.data as { candidates: string[] }).candidates;
      hub.handle(me, { t: 'answer', round: last.round, value: { road: c[0], brunch: c[1], rain: c[2] } });
    }
    if (last.t === 'picksStart') hub.handle(me, { t: 'picks', picks: last.candidates.slice(0, 3).map((c) => ({ id: c.id, heart: c.canHeart })), group: true });
    clock.advance(1000);
  }
  assert.ok(inbox.some((m) => m.t === 'unlock'));
  assert.ok(inbox.some((m) => m.t === 'reveal'));
});
