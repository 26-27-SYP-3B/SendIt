import { ApiError } from './store.js';

const maxBodyBytes = 2 * 1024 * 1024;
const rideId = /^[0-9a-f]{32}$/;
const groupId = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/;
const inviteCode = /^[A-Za-z0-9_-]{32}$/;

function send(response, status, body) {
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  response.end(JSON.stringify(body));
}

async function readBody(request) {
  if (request.headers['content-type']?.split(';', 1)[0] !== 'application/json') {
    throw new ApiError(415, 'JSON-Anfrage erwartet.');
  }
  let bytes = 0;
  const chunks = [];
  for await (const chunk of request.iterator({ destroyOnReturn: false })) {
    bytes += chunk.length;
    if (bytes > maxBodyBytes) {
      request.resume();
      throw new ApiError(413, 'Die Anfrage ist zu groß.');
    }
    chunks.push(chunk);
  }
  try {
    const data = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (data && typeof data === 'object' && !Array.isArray(data)) return data;
  } catch {
    // Ungültiges JSON und andere Datentypen erhalten dieselbe Rückmeldung.
  }
  throw new ApiError(400, 'Ungültige Anfrage.');
}

function textField(value, maxLength, message) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > maxLength) {
    throw new ApiError(400, message);
  }
  return value.trim();
}

function coordinate(value, message) {
  if (!Number.isFinite(value?.lat) || Math.abs(value.lat) > 90 ||
      !Number.isFinite(value?.lng) || Math.abs(value.lng) > 180) {
    throw new ApiError(400, message);
  }
  return { lat: value.lat, lng: value.lng };
}

function routeField(value) {
  if (value == null) return null;
  const message = 'Die Route ist ungültig oder zu groß.';
  const { points, distanceMeters, durationSeconds } = value;
  if (!Array.isArray(points) || points.length < 2 || points.length > 25000 ||
      !Number.isFinite(distanceMeters) || distanceMeters < 0 ||
      !Number.isFinite(durationSeconds) || durationSeconds < 0) {
    throw new ApiError(400, message);
  }
  return {
    name: textField(value.name, 80, message),
    points: points.map((point) => coordinate(point, message)),
    distanceMeters,
    durationSeconds,
  };
}

function parseRide(data) {
  if (typeof data.id !== 'string' || !rideId.test(data.id)) {
    throw new ApiError(400, 'Ungültige Ausfahrts-ID.');
  }
  const title = textField(data.title, 100, 'Gib einen Titel mit bis zu 100 Zeichen ein.');
  if (!Number.isSafeInteger(data.departure) || data.departure < 0 ||
      data.departure > 253402300799999) {
    throw new ApiError(400, 'Gib ein gültiges Datum und eine Abfahrtszeit an.');
  }
  const meetingPoint = coordinate(data.meetingPoint, 'Wähle einen Treffpunkt auf der Karte.');
  const visibility = data.visibility;
  if (!['public', 'friends', 'group'].includes(visibility)) {
    throw new ApiError(400, 'Wähle eine gültige Sichtbarkeit.');
  }
  const target = visibility === 'group' ? data.groupId : null;
  if (visibility === 'group' && (typeof target !== 'string' || !groupId.test(target))) {
    throw new ApiError(400, 'Wähle eine Gruppe.');
  }
  return {
    id: data.id, title, departure: data.departure, meetingPoint, visibility,
    groupId: target, route: routeField(data.route),
  };
}

export function createHandler({ store, authenticate, getProfileName }) {
  return async (request, response) => {
    try {
      const user = await authenticate(request.headers.authorization);
      if (!user) throw new ApiError(401, 'Bitte melde dich erneut an.');

      const path = new URL(request.url, 'http://localhost').pathname;
      const method = request.method;
      const join = /^\/rides\/([0-9a-f]{32})\/join$/.exec(path);
      const group = /^\/groups\/([0-9a-f-]{36})$/.exec(path);
      const friend = /^\/friends\/(user_[A-Za-z0-9]+)$/.exec(path);

      if (method === 'GET' && path === '/rides') {
        return send(response, 200, store.rides(user));
      }
      if (method === 'POST' && path === '/rides') {
        return send(response, 201, store.createRide(user, parseRide(await readBody(request))));
      }
      if (method === 'POST' && join) {
        return send(response, 200, store.joinRide(user, join[1]));
      }
      if (method === 'GET' && path === '/groups') {
        return send(response, 200, store.groups(user));
      }
      if (method === 'POST' && path === '/groups') {
        const { name } = await readBody(request);
        return send(response, 201, store.createGroup(user, textField(
          name, 60, 'Gib einen Gruppennamen mit bis zu 60 Zeichen ein.',
        )));
      }
      if (method === 'DELETE' && group) {
        store.leaveGroup(user, group[1]);
        return send(response, 200, {});
      }
      if (method === 'GET' && path === '/friends') {
        return send(response, 200, store.friends(user));
      }
      if (method === 'DELETE' && friend) {
        store.removeFriend(user, friend[1]);
        return send(response, 200, {});
      }
      if (method === 'POST' && path === '/invites') {
        const { groupId: target = null } = await readBody(request);
        if (target !== null && (typeof target !== 'string' || !groupId.test(target))) {
          throw new ApiError(400, 'Ungültige Gruppe.');
        }
        const name = target ? null : await getProfileName(user);
        return send(response, 201, store.createInvite(user, target, name));
      }
      if (method === 'POST' && path === '/invites/redeem') {
        const { code } = await readBody(request);
        if (typeof code !== 'string' || !inviteCode.test(code)) {
          throw new ApiError(400, 'Gib einen gültigen Einladungscode ein.');
        }
        const name = store.inviteNeedsProfile(code) ? await getProfileName(user) : null;
        store.redeemInvite(user, code, name);
        return send(response, 200, {});
      }
      throw new ApiError(404, 'Die angeforderte Seite wurde nicht gefunden.');
    } catch (error) {
      if (response.destroyed) return;
      if (error instanceof ApiError) return send(response, error.status, { error: error.message });
      console.error('Ausfahrten-API:', error.name);
      return send(response, 500, { error: 'Der Ausfahrten-Dienst ist gerade nicht verfügbar.' });
    }
  };
}
