import { mkdirSync } from 'node:fs';
import { createServer } from 'node:http';
import { dirname } from 'node:path';
import { createClerkClient } from '@clerk/backend';
import { createAuthenticator } from './auth.js';
import { createHandler } from './api.js';
import { createStore } from './store.js';

const {
  CLERK_SECRET_KEY: secretKey,
  CLERK_ISSUER: issuer,
  DATABASE_PATH: databasePath = 'data/sendit.sqlite',
  HOST: host = '127.0.0.1',
  PORT: port = '8080',
} = process.env;

if (!/^sk_(test|live)_/.test(secretKey ?? '') || !issuer || new URL(issuer).origin !== issuer ||
    !issuer.startsWith('https://')) {
  throw new Error('CLERK_SECRET_KEY und CLERK_ISSUER müssen zur Clerk-Instanz der App gehören.');
}

const clerk = createClerkClient({ secretKey });
mkdirSync(dirname(databasePath), { recursive: true });
const store = createStore(databasePath);

const handler = createHandler({
  store,
  authenticate: createAuthenticator({ secretKey, issuer }),
  async getProfileName(id) {
    const user = await clerk.users.getUser(id);
    return [user.firstName, user.lastName].filter(Boolean).join(' ') ||
      user.username || `Fahrer …${id.slice(-6)}`;
  },
});

createServer(handler).listen(Number(port), host, () => {
  console.log(`Ausfahrten-API läuft auf ${host}:${port}.`);
});
