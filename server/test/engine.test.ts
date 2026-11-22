import { test } from 'node:test';
import assert from 'node:assert/strict';
import { resolvePicks, type PickInput } from '../src/engine/picks.ts';
import { formRooms, type QueueEntry } from '../src/engine/matchmaker.ts';
import { Room, type RoomPlayer, type RoomTimings } from '../src/engine/room.ts';
import { cleanTrip, tallyTrip } from '../src/engine/games.ts';
import type { ServerMsg, Status } from '../../shared/protocol.ts';

// ---------- picks ----------

const P = (id: string, status: Status, partyCode = id) => ({ id, status, partyCode });

test('mutual hearts between two Open players become a match', () => {
  const players = [P('a', 'open'), P('b', 'open')];
  const inputs = new Map<string, PickInput>([
    ['a', { picks: [{ id: 'b', heart: true }], group: false }],
    ['b', { picks: [{ id: 'a', heart: true }], group: false }],
  ]);
  const r = resolvePicks(players, inputs);
  assert.deepEqual(r.get('a')!.matches, ['b']);
  assert.deepEqual(r.get('a')!.friends, []);
});

test('a heart toward a Taken player can never become a match', () => {
  const players = [P('a', 'open'), P('b', 'taken')];
  const inputs = new Map<string, PickInput>([
    ['a', { picks: [{ id: 'b', heart: true }], group: false }],
    ['b', { picks: [{ id: 'a', heart: true }], group: false }],
  ]);
  const r = resolvePicks(players, inputs);
  assert.deepEqual(r.get('a')!.matches, []);
  assert.deepEqual(r.get('a')!.friends, ['b']);
});

test('one-sided picks stay invisible', () => {
  const players = [P('a', 'open'), P('b', 'open')];
  const inputs = new Map<string, PickInput>([['a', { picks: [{ id: 'b', heart: true }], group: false }]]);
  const r = resolvePicks(players, inputs);
  assert.deepEqual(r.get('a'), { matches: [], friends: [], group: [] });
  assert.deepEqual(r.get('b'), { matches: [], friends: [], group: [] });
});

test('party members cannot pick each other, and picks cap at 3', () => {
  const players = [P('a', 'open', 'x'), P('w', 'wing', 'x'), P('b', 'open'), P('c', 'open'), P('d', 'open'), P('e', 'open')];
  const all = ['w', 'b', 'c', 'd', 'e'].map((id) => ({ id, heart: false }));
  const back = (id: string) => ({ picks: [{ id: 'a', heart: false }, { id: 'w', heart: false }], group: false });
  const inputs = new Map<string, PickInput>([['a', { picks: all, group: false }], ['w', back('w')], ['b', back('b')], ['c', back('c')], ['d', back('d')], ['e', back('e')]]);
  const r = resolvePicks(players, inputs);
  // 'w' is ignored (same party), so a's first three valid picks are b, c, d.
  assert.deepEqual(r.get('a')!.friends.sort(), ['b', 'c', 'd']);
  assert.ok(!r.get('w')!.friends.includes('a'));
});

test('three or more "whole group" ticks form a group', () => {
  const players = [P('a', 'open'), P('b', 'friends'), P('c', 'taken'), P('d', 'open')];
  const g = { picks: [], group: true };
  const inputs = new Map<string, PickInput>([['a', g], ['b', g], ['c', g], ['d', { picks: [], group: false }]]);
  const r = resolvePicks(players, inputs);
  assert.deepEqual(r.get('a')!.group.sort(), ['b', 'c']);
  assert.deepEqual(r.get('d')!.group, []);
});

// ---------- matchmaker ----------

const Q = (id: string, status: Status, joinedAt: number, extra: Partial<QueueEntry> = {}): QueueEntry => ({ id, status, partyCode: id, joinedAt, blocked: new Set(), ...extra });

test('a full room forms and parties stay together', () => {
  const q = [Q('a', 'open', 1, { partyCode: 'p' }), Q('k', 'wing', 2, { partyCode: 'p' }), Q('b', 'open', 3), Q('c', 'open', 4), Q('d', 'friends', 5), Q('e', 'taken', 6), Q('f', 'open', 7)];
  const { rooms, remaining } = formRooms(q, 10);
  assert.equal(rooms.length, 1);
  const ids = rooms[0].map((e) => e.id);
  assert.ok(ids.includes('a') && ids.includes('k'));
  assert.equal(ids.length, 6);
  assert.equal(remaining.length, 1);
});

test('blocked numbers never share a room', () => {
  const q = [Q('a', 'open', 1, { phoneHash: 'ha', blocked: new Set(['hb']) }), Q('b', 'open', 2, { phoneHash: 'hb' }), Q('c', 'open', 3), Q('d', 'open', 4), Q('e', 'open', 5), Q('f', 'open', 6), Q('g', 'open', 7)];
  const { rooms } = formRooms(q, 10);
  for (const room of rooms) {
    const ids = room.map((e) => e.id);
    assert.ok(!(ids.includes('a') && ids.includes('b')));
  }
});

test('a short room starts only after the wait time', () => {
  const q = [Q('a', 'open', 0), Q('b', 'open', 0), Q('c', 'open', 0), Q('d', 'open', 0)];
  assert.equal(formRooms(q, 10_000).rooms.length, 0);
  assert.equal(formRooms(q, 61_000).rooms.length, 1);
});

// ---------- games ----------

test('road trip answers must be three different allowed players; rain checks stay hidden', () => {
  const allowed = new Set(['b', 'c', 'd']);
  assert.equal(cleanTrip({ road: 'b', brunch: 'b', rain: 'c' }, allowed), null);
  assert.equal(cleanTrip({ road: 'b', brunch: 'c', rain: 'z' }, allowed), null);
  const ok = cleanTrip({ road: 'b', brunch: 'c', rain: 'd' }, allowed)!;
  const totals = tallyTrip(new Map([['a', ok]]));
  assert.deepEqual(totals, { b: { road: 1, brunch: 0 }, c: { road: 0, brunch: 1 } });
  assert.ok(!('d' in totals));
});

// ---------- full room session ----------

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

test('a whole session runs from room start to reveal', () => {
  const clock = fakeClock();
  const inbox = new Map<string, ServerMsg[]>();
  const mk = (id: string, status: Status, partyCode = id, wingFor?: string): RoomPlayer => ({ id, name: id, status, partyCode, cosmetics: {}, wingFor, profile: { age: 25, prompts: [] } });
  const players = [mk('a', 'open', 'p'), mk('k', 'wing', 'p', 'a'), mk('b', 'open'), mk('c', 'friends'), mk('d', 'taken'), mk('e', 'open')];
  const timings: RoomTimings = { hotTake: 1000, whoSaid: 1000, guess: 1000, roadTrip: 1000, results: 100, picks: 1000 };
  let done = false;
  const room = new Room('r1', players, {
    send: (id, msg) => { const l = inbox.get(id) ?? []; l.push(msg); inbox.set(id, l); },
    schedule: clock.schedule, now: clock.now, rng: () => 0.42, onDone: () => { done = true; },
  }, timings);
  const last = (id: string, t: ServerMsg['t']) => [...(inbox.get(id) ?? [])].reverse().find((m) => m.t === t) as any;

  room.start();
  assert.equal(last('a', 'roundStart').game, 'hotTake');
  for (const p of players) room.handle(p.id, { t: 'answer', round: 0, value: 50 });
  assert.equal(last('a', 'roundResult').game, 'hotTake');

  clock.advance(100);
  assert.equal(last('a', 'roundStart').game, 'whoSaid');
  for (const p of players) room.handle(p.id, { t: 'answer', round: 1, value: `answer from ${p.id}` });
  const gs = last('a', 'guessStart');
  assert.equal(gs.answers.length, 6);

  clock.advance(1000); // guess timer runs out
  assert.equal(last('a', 'roundResult').game, 'whoSaid');
  clock.advance(100);
  assert.ok(last('b', 'unlock'), 'photos unlock after round 2');

  const trip = last('a', 'roundStart');
  assert.equal(trip.game, 'roadTrip');
  assert.ok(!trip.data.candidates.includes('k'), 'your own wingman is not placeable');

  room.handle('k', { t: 'hype', text: 'Emma laughed at that' });
  assert.equal(last('a', 'hype').text, 'Emma laughed at that');

  clock.advance(1000);
  clock.advance(100);
  assert.ok(last('a', 'picksStart'));
  const aCands = last('a', 'picksStart').candidates;
  assert.equal(aCands.find((c: any) => c.id === 'd').canHeart, false, 'Taken cannot receive hearts');

  room.handle('a', { t: 'picks', picks: [{ id: 'b', heart: true }], group: false });
  room.handle('b', { t: 'picks', picks: [{ id: 'a', heart: true }], group: false });
  for (const id of ['k', 'c', 'd', 'e']) room.handle(id, { t: 'picks', picks: [], group: false });
  assert.ok(done);
  assert.deepEqual(last('a', 'reveal').matches, ['b']);
});
