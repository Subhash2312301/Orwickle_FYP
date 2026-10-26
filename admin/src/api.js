// HTTP client for the Orwickle backend. The dashboard holds no database keys: everything goes
// through /api/admin/*, which only accepts administrators.
//
// Tokens live in sessionStorage (cleared when the tab closes). On a 401 the session is refreshed
// once and the request retried. Only one refresh runs at a time, because refresh tokens rotate and
// using an old one twice ends every session (reuse detection).

const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:4000/api';
const STORAGE_KEY = 'orwickle-admin-session';

export class ApiError extends Error {
  constructor(status, code, message, details = {}) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

let session = readSession();
let refreshing = null;
let onSessionEnd = () => {};

function readSession() {
  try {
    return JSON.parse(sessionStorage.getItem(STORAGE_KEY));
  } catch {
    return null;
  }
}

function saveSession(next) {
  session = next;
  if (next) sessionStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  else sessionStorage.removeItem(STORAGE_KEY);
}

export const currentSession = () => session;

/** Called when the session can no longer be refreshed (expired, revoked or logged out). */
export function setSessionEndHandler(handler) {
  onSessionEnd = handler;
}

async function send(path, { method = 'GET', body, token } = {}) {
  let res;
  try {
    res = await fetch(`${BASE_URL}${path}`, {
      method,
      headers: {
        ...(body !== undefined && { 'Content-Type': 'application/json' }),
        ...(token && { Authorization: `Bearer ${token}` }),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError(0, 'NETWORK', 'Cannot reach the server. Is the backend running?');
  }
  if (res.status === 204) return null;
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const e = data.error || {};
    throw new ApiError(res.status, e.code || 'ERROR', e.message || 'Something went wrong', e.details || {});
  }
  return data;
}

export async function refreshSession() {
  if (!session) throw new ApiError(401, 'SESSION_EXPIRED', 'Please log in again');
  refreshing ??= send('/auth/refresh', { method: 'POST', body: { refreshToken: session.refreshToken } })
    .then(next => {
      saveSession({ ...session, accessToken: next.accessToken, refreshToken: next.refreshToken, refreshedAt: Date.now() });
    })
    .catch(err => {
      saveSession(null);
      onSessionEnd('Your session has expired. Please log in again.');
      throw err;
    })
    .finally(() => {
      refreshing = null;
    });
  return refreshing;
}

/** Authenticated request with one refresh-and-retry on 401. */
export async function api(path, options = {}) {
  if (refreshing) await refreshing;
  try {
    return await send(path, { ...options, token: session?.accessToken });
  } catch (err) {
    if (err.status !== 401 || !session) throw err;
    await refreshSession();
    return send(path, { ...options, token: session.accessToken });
  }
}

export async function login(email, password) {
  const data = await send('/auth/login', { method: 'POST', body: { email, password } });
  if (data.user.role !== 'admin') {
    // end the session the server just created; this dashboard is for administrators only
    await send('/auth/logout', { method: 'POST', body: { refreshToken: data.refreshToken } }).catch(() => {});
    throw new ApiError(403, 'FORBIDDEN', 'Only administrators can use this dashboard.');
  }
  saveSession({ accessToken: data.accessToken, refreshToken: data.refreshToken, user: data.user, refreshedAt: Date.now() });
  return data.user;
}

/** Changing the password ends every other session; the server returns a fresh one for this tab. */
export async function changePassword(currentPassword, newPassword) {
  const data = await api('/auth/change-password', { method: 'POST', body: { currentPassword, newPassword } });
  saveSession({ ...session, accessToken: data.accessToken, refreshToken: data.refreshToken, refreshedAt: Date.now() });
}

export async function logout() {
  const refreshToken = session?.refreshToken;
  saveSession(null);
  if (refreshToken) await send('/auth/logout', { method: 'POST', body: { refreshToken } }).catch(() => {});
}
