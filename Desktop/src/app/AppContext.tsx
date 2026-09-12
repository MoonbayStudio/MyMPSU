import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import type { AppPreferences, UserProfile } from "../models/domain";
import { getProfile, login as loginRequest, logout as logoutRequest } from "../api/auth";
import { defaultPreferences, storageService } from "../platform/storageService";

interface AppContextValue {
  preferences: AppPreferences;
  updatePreferences: (value: AppPreferences) => Promise<void>;
  profile: UserProfile | null;
  authLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AppContext = createContext<AppContextValue | null>(null);

export function AppProvider({ children }: { children: ReactNode }) {
  const [preferences, setPreferences] = useState(defaultPreferences);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [authLoading, setAuthLoading] = useState(true);

  useEffect(() => {
    void storageService.getPreferences().then(setPreferences);
    void storageService
      .getAuthToken()
      .then((token) => (token ? getProfile() : null))
      .then(setProfile)
      .catch(() => storageService.clearAuthToken())
      .finally(() => setAuthLoading(false));
  }, []);

  useEffect(() => {
    const root = document.documentElement;
    root.dataset.theme = preferences.theme;
    if (preferences.theme === "system") root.removeAttribute("data-resolved-theme");
  }, [preferences.theme]);

  const value = useMemo<AppContextValue>(
    () => ({
      preferences,
      profile,
      authLoading,
      async updatePreferences(next) {
        setPreferences(next);
        await storageService.setPreferences(next);
      },
      async login(email, password) {
        setAuthLoading(true);
        try {
          setProfile(await loginRequest(email, password));
        } finally {
          setAuthLoading(false);
        }
      },
      async logout() {
        await logoutRequest();
        setProfile(null);
      },
    }),
    [preferences, profile, authLoading],
  );

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAppContext(): AppContextValue {
  const value = useContext(AppContext);
  if (!value) throw new Error("useAppContext must be used inside AppProvider");
  return value;
}
