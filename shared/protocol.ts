// Stage wire protocol: JSON messages over one WebSocket.
// Every message is { "t": <type>, ...fields }.
// The Dart client mirrors these shapes in client/lib/net/protocol.dart.
// Keep the two in sync when you change anything here.

export type Status = 'open' | 'friends' | 'taken' | 'wing';
export type GameId = 'hotTake' | 'whoSaid' | 'roadTrip';
export type TripSlot = 'road' | 'brunch' | 'rain';

/** What other players are allowed to see about you. No phone, no exact location. */
export interface PublicPlayer {
  id: string;
  name: string;
  status: Status;
  /** Equipped cosmetic ids, e.g. { frame: 'neon', entrance: 'pop' }. */
  cosmetics: Record<string, string>;
  /** Id of the friend this player is winging for, when status is 'wing'. */
  wingFor?: string;
  /** Present only after the photo unlock. */
  profile?: { age: number; prompts: string[]; photoUrl?: string };
}

// ---------- client -> server ----------
export type ClientMsg =
  | {
      t: 'hello';
      name: string;
      status: Status;
      cosmetics?: Record<string, string>;
      /** Join a friend's party by their code. Omit to start your own. */
      partyCode?: string;
      /** Prototype only. Real profiles come from the account once sign-in exists. */
      profile?: { age: number; prompts: string[] };
    }
  | { t: 'queue' }
  | { t: 'leave' }
  | { t: 'react'; emote: string }
  /** Wingmen only: a private note to the friend they're winging for. */
  | { t: 'hype'; text: string }
  /** hotTake: number 0-100 · whoSaid: string answer · roadTrip: Record<TripSlot, playerId> */
  | { t: 'answer'; round: number; value: unknown }
  | { t: 'guess'; round: number; answerId: string; playerId: string }
  | { t: 'picks'; picks: { id: string; heart: boolean }[]; group: boolean };

// ---------- server -> client ----------
export type ServerMsg =
  | { t: 'welcome'; playerId: string; partyCode: string }
  | { t: 'queueUpdate'; waiting: number; needed: number }
  | { t: 'roomStart'; roomId: string; players: PublicPlayer[] }
  | { t: 'roundStart'; round: number; game: GameId; prompt: string; endsAt: number; data?: unknown }
  | { t: 'guessStart'; round: number; answers: { answerId: string; text: string }[]; endsAt: number }
  | { t: 'roundResult'; round: number; game: GameId; result: unknown }
  | { t: 'unlock'; players: PublicPlayer[] }
  | { t: 'picksStart'; endsAt: number; candidates: { id: string; canHeart: boolean }[] }
  | { t: 'reveal'; matches: string[]; friends: string[]; group: string[] }
  | { t: 'react'; playerId: string; emote: string }
  | { t: 'hype'; from: string; text: string }
  | { t: 'error'; message: string };
