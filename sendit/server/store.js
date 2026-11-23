import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const inviteHash = (code) => createHash('sha256').update(code).digest('hex');
const pair = (first, second) => [first, second].sort();

const rideQuery = `
  SELECT ride.*, groups.name AS group_name,
    EXISTS (SELECT 1 FROM participants
      WHERE ride_id = ride.id AND user_id = $viewer) AS joined,
    (SELECT count(*) FROM participants WHERE ride_id = ride.id) AS participant_count
  FROM rides AS ride LEFT JOIN groups ON ride.group_id = groups.id
  WHERE (
    ride.owner_id = $viewer OR ride.visibility = 'public' OR
    (ride.visibility = 'friends' AND EXISTS (
      SELECT 1 FROM friendships
      WHERE first_id = min(ride.owner_id, $viewer)
        AND second_id = max(ride.owner_id, $viewer)
    )) OR
    (ride.visibility = 'group' AND EXISTS (
      SELECT 1 FROM group_members
      WHERE group_id = ride.group_id AND user_id = $viewer
    ))
  )
`;

function rideJson(row, viewer) {
  return {
    id: row.id,
    title: row.title,
    departure: row.departure,
    meetingPoint: { lat: row.latitude, lng: row.longitude },
    route: JSON.parse(row.route),
    visibility: row.visibility,
    groupName: row.group_name,
    isOwner: row.owner_id === viewer,
    joined: Boolean(row.joined),
    participantCount: row.participant_count,
  };
}

export function createStore(path) {
  const db = new DatabaseSync(path, { timeout: 5000 });
  db.exec(`
    PRAGMA foreign_keys = ON;
    PRAGMA journal_mode = WAL;
    CREATE TABLE IF NOT EXISTS profiles (
      id TEXT PRIMARY KEY, name TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS friendships (
      first_id TEXT NOT NULL REFERENCES profiles(id),
      second_id TEXT NOT NULL REFERENCES profiles(id),
      PRIMARY KEY (first_id, second_id),
      CHECK (first_id < second_id)
    );
    CREATE INDEX IF NOT EXISTS friendships_second ON friendships(second_id);
    CREATE TABLE IF NOT EXISTS groups (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, owner_id TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS group_members (
      group_id TEXT NOT NULL REFERENCES groups(id),
      user_id TEXT NOT NULL,
      PRIMARY KEY (group_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS groups_by_member ON group_members(user_id);
    CREATE TABLE IF NOT EXISTS invites (
      hash TEXT PRIMARY KEY, issuer_id TEXT NOT NULL,
      group_id TEXT REFERENCES groups(id), expires_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS rides (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      title TEXT NOT NULL,
      departure INTEGER NOT NULL,
      latitude REAL NOT NULL, longitude REAL NOT NULL,
      route TEXT NOT NULL,
      visibility TEXT NOT NULL CHECK (visibility IN ('public', 'friends', 'group')),
      group_id TEXT REFERENCES groups(id),
      CHECK ((visibility = 'group') = (group_id IS NOT NULL))
    );
    CREATE INDEX IF NOT EXISTS rides_by_departure ON rides(departure);
    CREATE TABLE IF NOT EXISTS participants (
      ride_id TEXT NOT NULL REFERENCES rides(id), user_id TEXT NOT NULL,
      PRIMARY KEY (ride_id, user_id)
    );
  `);

  function transaction(work) {
    db.exec('BEGIN IMMEDIATE');
    try {
      const result = work();
      db.exec('COMMIT');
      return result;
    } catch (error) {
      db.exec('ROLLBACK');
      throw error;
    }
  }

  function upsertProfile(id, name) {
    db.prepare(`
      INSERT INTO profiles VALUES (?, ?)
      ON CONFLICT(id) DO UPDATE SET name = excluded.name
    `).run(id, name);
  }

  function visibleRide(viewer, id) {
    return db.prepare(rideQuery + ' AND ride.id = $id').get({
      $viewer: viewer,
      $id: id,
    });
  }

  function findInvite(hash) {
    return db.prepare('SELECT * FROM invites WHERE hash = ? AND expires_at > ?')
      .get(hash, Date.now());
  }

  return {
    close: () => db.close(),

    rides(viewer) {
      return db.prepare(rideQuery + ' AND ride.departure > $now ORDER BY ride.departure, ride.id')
        .all({ $viewer: viewer, $now: Date.now() })
        .map((row) => rideJson(row, viewer));
    },

    createRide(viewer, ride) {
      return transaction(() => {
        const existing = db.prepare('SELECT owner_id FROM rides WHERE id = ?').get(ride.id);
        if (existing) {
          if (existing.owner_id !== viewer) throw new ApiError(409, 'Diese Ausfahrt existiert bereits.');
          // Derselbe Speicherversuch kann nach einem Verbindungsabbruch wiederholt werden.
          return rideJson(visibleRide(viewer, ride.id), viewer);
        }
        if (ride.departure <= Date.now()) {
          throw new ApiError(400, 'Die Abfahrt muss in der Zukunft liegen.');
        }
        if (ride.groupId && !db.prepare(
          'SELECT 1 FROM group_members WHERE group_id = ? AND user_id = ?',
        ).get(ride.groupId, viewer)) {
          throw new ApiError(403, 'Du bist kein Mitglied dieser Gruppe.');
        }
        db.prepare('INSERT INTO rides VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)').run(
          ride.id, viewer, ride.title, ride.departure, ride.meetingPoint.lat,
          ride.meetingPoint.lng, JSON.stringify(ride.route), ride.visibility, ride.groupId,
        );
        return rideJson(visibleRide(viewer, ride.id), viewer);
      });
    },

    joinRide(viewer, id) {
      return transaction(() => {
        const row = visibleRide(viewer, id);
        if (!row) throw new ApiError(404, 'Diese Ausfahrt ist nicht verfügbar.');
        if (row.owner_id === viewer || row.departure <= Date.now()) {
          throw new ApiError(409, 'Für diese Ausfahrt ist keine Anmeldung möglich.');
        }
        db.prepare('INSERT OR IGNORE INTO participants VALUES (?, ?)').run(id, viewer);
        return rideJson(visibleRide(viewer, id), viewer);
      });
    },

    groups(viewer) {
      return db.prepare(`
        SELECT groups.id, groups.name, owner_id = ? AS isOwner
        FROM groups JOIN group_members ON groups.id = group_members.group_id
        WHERE user_id = ? ORDER BY groups.name COLLATE NOCASE, groups.id
      `).all(viewer, viewer).map((group) => ({ ...group, isOwner: Boolean(group.isOwner) }));
    },

    createGroup(viewer, name) {
      const id = randomUUID();
      transaction(() => {
        db.prepare('INSERT INTO groups VALUES (?, ?, ?)').run(id, name, viewer);
        db.prepare('INSERT INTO group_members VALUES (?, ?)').run(id, viewer);
      });
      return { id, name, isOwner: true };
    },

    leaveGroup(viewer, groupId) {
      db.prepare(`
        DELETE FROM group_members WHERE group_id = ? AND user_id = ?
          AND user_id != (SELECT owner_id FROM groups WHERE id = ?)
      `).run(groupId, viewer, groupId);
    },

    friends(viewer) {
      return db.prepare(`
        SELECT profiles.id, profiles.name FROM friendships JOIN profiles
        ON profiles.id = CASE WHEN first_id = ? THEN second_id ELSE first_id END
        WHERE first_id = ? OR second_id = ? ORDER BY name COLLATE NOCASE, profiles.id
      `).all(viewer, viewer, viewer);
    },

    removeFriend(viewer, friendId) {
      db.prepare('DELETE FROM friendships WHERE first_id = ? AND second_id = ?')
        .run(...pair(viewer, friendId));
    },

    createInvite(viewer, groupId, name) {
      return transaction(() => {
        if (groupId && !db.prepare('SELECT 1 FROM groups WHERE id = ? AND owner_id = ?')
          .get(groupId, viewer)) {
          throw new ApiError(403, 'Nur der Gruppenersteller kann Personen einladen.');
        }
        if (!groupId) upsertProfile(viewer, name);
        const code = randomBytes(24).toString('base64url');
        db.prepare('DELETE FROM invites WHERE expires_at <= ? OR (issuer_id = ? AND group_id IS ?)')
          .run(Date.now(), viewer, groupId);
        db.prepare('INSERT INTO invites VALUES (?, ?, ?, ?)')
          .run(inviteHash(code), viewer, groupId, Date.now() + 24 * 60 * 60 * 1000);
        return { code };
      });
    },

    inviteNeedsProfile(code) {
      const invite = findInvite(inviteHash(code));
      if (!invite) throw new ApiError(404, 'Der Einladungscode ist ungültig oder abgelaufen.');
      return invite.group_id === null;
    },

    redeemInvite(viewer, code, name) {
      transaction(() => {
        const hash = inviteHash(code);
        const invite = findInvite(hash);
        if (!invite) throw new ApiError(404, 'Der Einladungscode ist ungültig oder abgelaufen.');
        if (invite.issuer_id === viewer) {
          throw new ApiError(400, 'Du kannst deinen eigenen Code nicht einlösen.');
        }
        if (invite.group_id) {
          db.prepare('INSERT OR IGNORE INTO group_members VALUES (?, ?)').run(invite.group_id, viewer);
        } else {
          upsertProfile(viewer, name);
          db.prepare('INSERT OR IGNORE INTO friendships VALUES (?, ?)')
            .run(...pair(invite.issuer_id, viewer));
        }
        db.prepare('DELETE FROM invites WHERE hash = ?').run(hash);
      });
    },
  };
}
