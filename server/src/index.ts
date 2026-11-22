import { WebSocketServer, type WebSocket } from 'ws';
import { Hub } from './hub.ts';

const PORT = Number(process.env.PORT ?? 8787);
// Dev only: fill your room with bots after this many ms. Leave unset in production.
const BOTS_AFTER_MS = Number(process.env.STAGE_BOTS_AFTER_MS ?? 0);
const MAX_MESSAGE_BYTES = 4 * 1024;

const hub = new Hub({ botFillAfterMs: BOTS_AFTER_MS });
const wss = new WebSocketServer({ port: PORT, maxPayload: MAX_MESSAGE_BYTES });

wss.on('connection', (ws: WebSocket) => {
  const id = hub.connect({
    send: (msg) => { if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(msg)); },
  });

  // Simple flood protection: at most 20 messages per second per socket.
  let windowStart = Date.now();
  let count = 0;
  ws.on('message', (data) => {
    const now = Date.now();
    if (now - windowStart > 1000) { windowStart = now; count = 0; }
    if (++count > 20) return;
    hub.receive(id, data.toString());
  });
  ws.on('close', () => hub.disconnect(id));
  ws.on('error', () => hub.disconnect(id));
});

setInterval(() => hub.tick(), 1000);

console.log(`Stage server listening on ws://localhost:${PORT}${BOTS_AFTER_MS ? ` (bots fill rooms after ${BOTS_AFTER_MS} ms)` : ''}`);
