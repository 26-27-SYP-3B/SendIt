import { verifyToken } from '@clerk/backend';

export function createAuthenticator(options) {
  return async (authorization) => {
    // Native Clients senden das Clerk-Session-JWT als Bearer-Token.
    const match = /^Bearer (\S+)$/.exec(authorization ?? '');
    if (!match) return null;
    try {
      const data = await verifyToken(match[1], options);
      if (typeof data.sub !== 'string' || !/^user_[A-Za-z0-9]+$/.test(data.sub) ||
          typeof data.sid !== 'string' || !data.sid.startsWith('sess_') ||
          data.sts === 'pending' || !Number.isFinite(data.exp)) {
        return null;
      }
      return data.sub;
    } catch {
      return null;
    }
  };
}
