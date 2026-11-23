import assert from 'node:assert/strict';
import { generateKeyPairSync, randomBytes, sign } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { once } from 'node:events';
import { test } from 'node:test';
import { createHandler } from './api.js';
import { createAuthenticator } from './auth.js';
import { createStore } from './store.js';

const issuer = 'https://sendit-test.clerk.accounts.dev';
const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const authenticate = createAuthenticator({
  issuer,
  jwtKey: publicKey.export({ type: 'spki', format: 'pem' }),
});
const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');

function token(user, claims = {}) {
  const now = Math.floor(Date.now() / 1000);
  const header = encode({
    alg: 'RS256', typ: 'JWT', kid: 'test-key', cat: 'cl_B7d4PD111AAA',
  });
  const payload = encode({
    sub: user, sid: 'sess_test', iss: issuer, iat: now, nbf: now, exp: now + 60,
    ...claims,
  });
  const unsigned = `${header}.${payload}`;
  return `${unsigned}.${sign('RSA-SHA256', Buffer.from(unsigned), privateKey).toString('base64url')}`;
}

async function startApi(t, database = ':memory:') {
  const store = createStore(database);
  const server = createServer(createHandler({
    store, authenticate, getProfileName: async (user) => user.slice(5),
  }));
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    store.close();
  });

  return async (user, path, method = 'GET', body) => {
    const headers = {};
    if (user) headers.Authorization = `Bearer ${token(user)}`;
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    const response = await fetch(`http://127.0.0.1:${server.address().port}${path}`, {
      method, headers, body: JSON.stringify(body),
    });
    assert.equal(response.headers.get('cache-control'), 'no-store');
    return { status: response.status, body: await response.json() };
  };
}

const owner = 'user_Organisator';
const friend = 'user_Freund';
const member = 'user_Mitglied';
const stranger = 'user_Gast';

const draft = (fields = {}) => ({
  id: randomBytes(16).toString('hex'),
  title: '  Mühlviertelrunde  ',
  departure: Date.now() + 60 * 60 * 1000,
  meetingPoint: { lat: 48.305, lng: 14.286 },
  visibility: 'public',
  ...fields,
});

test('Clerk-Authentifizierung verlangt ein signiertes, aktives Session-Token dieser Instanz', async () => {
  assert.equal(await authenticate(`Bearer ${token(owner)}`), owner);
  const valid = token(owner).split('.');
  valid[1] = encode({ sub: stranger });
  for (const value of [
    undefined,
    'Bearer abc',
    `Bearer ${valid.join('.')}`,
    `Bearer ${token(owner, { sid: null })}`,
    `Bearer ${token(owner, { sts: 'pending' })}`,
    `Bearer ${token(owner, { exp: 1 })}`,
    `Bearer ${token(owner, { iss: 'https://other.clerk.accounts.dev' })}`,
  ]) {
    assert.equal(await authenticate(value), null);
  }
});

test('Pflichtfelder, Koordinaten, Sichtbarkeit und Gruppenzugehörigkeit werden geprüft', async (t) => {
  const request = await startApi(t);
  assert.equal((await request(null, '/rides')).status, 401);
  assert.equal((await request(null, '/rides', 'POST', draft())).status, 401);

  for (const fields of [
    { title: '   ' }, { departure: undefined }, { departure: 0 },
    { meetingPoint: undefined }, { meetingPoint: { lat: 100, lng: 14 } },
    { visibility: 'unknown' }, { visibility: 'group' },
    { route: { points: [] } },
  ]) {
    assert.equal((await request(owner, '/rides', 'POST', draft(fields))).status, 400);
  }

  const group = await request(member, '/groups', 'POST', { name: 'Mittwochsrunde' });
  assert.equal(group.status, 201);
  assert.equal((await request(owner, '/rides', 'POST', draft({
    visibility: 'group', groupId: group.body.id,
  }))).status, 403);
  assert.deepEqual((await request(owner, '/rides')).body, []);
});

test('Öffentliche Ausfahrt mit Route ist geräteübergreifend abrufbar und Beitritt ist idempotent', async (t) => {
  const request = await startApi(t);
  const route = {
    name: 'Donaurunde',
    points: [{ lat: 48.305, lng: 14.286 }, { lat: 48.32, lng: 14.29 }],
    distanceMeters: 1700,
    durationSeconds: 680,
  };
  const ride = draft({ route, ownerId: stranger });
  const saves = await Promise.all([
    request(owner, '/rides', 'POST', ride), request(owner, '/rides', 'POST', ride),
  ]);
  assert.ok(saves.every(({ status, body }) => status === 201 && body.isOwner));
  const feed = (await request(stranger, '/rides')).body;
  assert.equal(feed.length, 1);
  assert.equal(feed[0].title, 'Mühlviertelrunde');
  assert.equal(feed[0].departure, ride.departure);
  assert.deepEqual(feed[0].meetingPoint, ride.meetingPoint);
  assert.deepEqual(feed[0].route, route);
  assert.equal(feed[0].isOwner, false);

  const path = `/rides/${ride.id}/join`;
  assert.equal((await request(owner, path, 'POST')).status, 409);
  for (let i = 0; i < 2; i++) {
    const joined = await request(stranger, path, 'POST');
    assert.equal(joined.status, 200);
    assert.equal(joined.body.joined, true);
    assert.equal(joined.body.participantCount, 1);
  }
  assert.equal((await request(owner, '/rides')).body[0].participantCount, 1);
});

test('Freundes- und Gruppenausfahrten sind ausschließlich für den aktuellen Empfängerkreis sichtbar', async (t) => {
  const request = await startApi(t);
  const group = (await request(owner, '/groups', 'POST', { name: 'Runde 1' })).body;
  const secondGroup = (await request(owner, '/groups', 'POST', { name: 'Runde 2' })).body;
  const friendCode = (await request(owner, '/invites', 'POST', {})).body.code;
  assert.equal((await request(friend, '/invites/redeem', 'POST', { code: friendCode })).status, 200);
  assert.equal((await request(stranger, '/invites/redeem', 'POST', { code: friendCode })).status, 404);

  const groupCode = (await request(owner, '/invites', 'POST', { groupId: group.id })).body.code;
  assert.equal((await request(member, '/invites/redeem', 'POST', { code: groupCode })).status, 200);
  assert.equal((await request(member, '/invites', 'POST', { groupId: group.id })).status, 403);
  assert.deepEqual((await request(member, '/groups')).body, [{ ...group, isOwner: false }]);

  const friendsRide = draft({ title: 'Nur Freunde', visibility: 'friends' });
  const groupRide = draft({ title: 'Nur erste Gruppe', visibility: 'group', groupId: group.id });
  const secondGroupRide = draft({ title: 'Nur zweite Gruppe', visibility: 'group', groupId: secondGroup.id });
  for (const ride of [friendsRide, groupRide, secondGroupRide]) {
    assert.equal((await request(owner, '/rides', 'POST', ride)).status, 201);
  }
  assert.equal((await request(owner, '/rides')).body.length, 3);
  for (const [viewer, visible] of [[friend, [friendsRide]], [member, [groupRide]], [stranger, []]]) {
    const rides = (await request(viewer, '/rides')).body;
    assert.deepEqual(rides.map(({ id }) => id), visible.map(({ id }) => id));
    for (const ride of [friendsRide, groupRide, secondGroupRide]) {
      const { status } = await request(viewer, `/rides/${ride.id}/join`, 'POST');
      assert.equal(status, visible.includes(ride) ? 200 : 404);
    }
  }

  await request(owner, `/friends/${friend}`, 'DELETE');
  await request(member, `/groups/${group.id}`, 'DELETE');
  assert.deepEqual((await request(friend, '/rides')).body, []);
  assert.deepEqual((await request(member, '/rides')).body, []);
});

test('Ausfahrten bleiben nach erneutem Öffnen der Datenbank erhalten', () => {
  const directory = mkdtempSync(join(tmpdir(), 'sendit-rides-'));
  try {
    const database = join(directory, 'data.sqlite');
    const ride = draft({ route: null, groupId: null });
    let store = createStore(database);
    try {
      store.createRide(owner, ride);
    } finally {
      store.close();
    }
    store = createStore(database);
    try {
      assert.equal(store.rides(stranger)[0].id, ride.id);
    } finally {
      store.close();
    }
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
