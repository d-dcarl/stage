# Stage

Play short party games with 4–8 people, then privately pick who you'd play with again. Mutual picks become matches, friends or groups. Everyone shares the same rooms: you set a status (Open to dating, Here to play, Taken, or Wingman) and the rules follow from it.

> Chemistry isn't found in profiles. It shows up when people play together.

## What's in this repo

| Folder | What it is |
| --- | --- |
| `client/` | Flutter app (Riverpod state, WebSocket client) |
| `server/` | Node.js + TypeScript game server: matchmaking, rooms, rounds, picks |
| `shared/` | The wire protocol both sides follow (`protocol.ts`, mirrored in `client/lib/net/protocol.dart`) |
| `prototype/` | Single-file web demo with simulated players, for testing whether the games are fun |
| `docs/` | Links to the roadmap, wireframes and demo |

## Run it locally (Mac)

You need **Node 22.18+** and **Flutter 3.24+** (`brew install node` and the [Flutter install guide](https://docs.flutter.dev/get-started/install/macos)).

**1. Start the server with bots** (so you can play alone):

```bash
cd server
npm install
npm test          # engine tests, should all pass
npm run dev       # ws://localhost:8787, bots fill your room after 3 s
```

**2. Generate the platform folders once**, then run the app:

```bash
cd client
flutter create . --platforms=ios,android,web --project-name stage   # adds ios/, android/, web/ without touching lib/
flutter pub get
flutter run -d chrome                     # fastest way to try it
flutter run -d ios                        # iOS simulator
```

Server address defaults to `ws://localhost:8787`. Override it per build:

```bash
flutter run --dart-define=STAGE_SERVER=ws://192.168.1.20:8787   # a phone on your Wi-Fi
flutter run --dart-define=STAGE_SERVER=ws://10.0.2.2:8787       # Android emulator
```

**To test a party or wingman:** open two clients. In the first, press Play and note the party code on the queue screen. In the second, pick **Wingman**, enter that code, and press Play.

## How a session works

1. **Lobby:** set a status, optionally join a friend's party by code, press Play.
2. **Queue:** the matchmaker seats the oldest players first, keeps parties together, aims for at least 4 Open players per room, and never seats blocked numbers together.
3. **Round 1, Hot Take:** slide from Never to Obviously; everyone sees where the room landed.
4. **Round 2, Who Said It:** answer anonymously, then guess authors. Photos and profiles unlock after this round.
5. **Round 3, Road Trip, Brunch, Rain Check:** place three people. Only road-trip and brunch totals are shown. Rain checks are never revealed.
6. **Picks:** up to 3 private picks, plus a heart for dating interest. Hearts only count between two Open players. Party members can't pick each other.
7. **Reveal:** mutual hearts become matches, other mutual picks become friends, and 3+ "whole group" ticks form a group.

Rules live in `server/src/engine/` and are covered by `server/test/`.

## Principles

- **Behavior over profiles.** Game results feed matching privately and are never shown as a score.
- **Low friction to join, high friction to cause harm.** The server validates every message; the client is never trusted.
- **Privacy by default.** First names only until round 2. Blocked numbers are stored as keyed hashes. Raw mic or camera data stays on the phone.
- **Cosmetics are self-expression.** Frames, entrances, emotes, duo and couples sets (split the cost or gift it).

## Status and next steps

This is a prototype: no accounts, no database, rooms live in memory, and bots are dev-only.

- [ ] Sign-in (phone + Apple/Google), 21+ age gate, profiles and photos
- [ ] Postgres for accounts, blocks and history; Redis for queue and room state
- [ ] Block contacts (hash numbers server-side with a secret key)
- [ ] Report and block from any screen; moderation tools
- [ ] Cosmetics store with in-app purchases; split-cost bundles
- [ ] Hosted rooms for creators (pods that rotate, host on stage)
- [ ] Reconnect mid-round; server deploy (Fly.io or Railway)

Bots must never run in production. Real users only ever meet real users.
