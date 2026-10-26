// Login state for the dashboard, plus the 15-minute inactivity rule (same as the mobile app):
// any mouse, keyboard or touch activity counts; while the admin is active the session is
// refreshed every 2 minutes so the server-side idle timer does not run out either.

import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import * as client from './api';

const IDLE_LIMIT_MS = 15 * 60 * 1000;
const KEEP_ALIVE_MS = 2 * 60 * 1000;
const ACTIVITY_EVENTS = ['mousedown', 'keydown', 'touchstart', 'scroll'];

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => client.currentSession()?.user ?? null);
  const [notice, setNotice] = useState(null); // why the admin was logged out
  const lastActivity = useRef(0);

  const endSession = useCallback(message => {
    setUser(null);
    setNotice(message);
  }, []);

  useEffect(() => client.setSessionEndHandler(endSession), [endSession]);

  const login = async (email, password) => {
    const admin = await client.login(email, password);
    lastActivity.current = Date.now();
    setNotice(null);
    setUser(admin);
  };

  const logout = async () => {
    await client.logout();
    setUser(null);
    setNotice(null);
  };

  useEffect(() => {
    if (!user) return undefined;
    const touch = () => {
      lastActivity.current = Date.now();
    };
    touch();
    ACTIVITY_EVENTS.forEach(e => window.addEventListener(e, touch, { passive: true }));
    const timer = setInterval(async () => {
      const idle = Date.now() - lastActivity.current;
      if (idle >= IDLE_LIMIT_MS) {
        await client.logout();
        endSession('You were logged out after 15 minutes without activity.');
        return;
      }
      const sinceRefresh = Date.now() - (client.currentSession()?.refreshedAt ?? 0);
      if (idle < KEEP_ALIVE_MS && sinceRefresh >= KEEP_ALIVE_MS) client.refreshSession().catch(() => {});
    }, 15 * 1000);
    return () => {
      ACTIVITY_EVENTS.forEach(e => window.removeEventListener(e, touch));
      clearInterval(timer);
    };
  }, [user, endSession]);

  return <AuthContext.Provider value={{ user, notice, login, logout }}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);
