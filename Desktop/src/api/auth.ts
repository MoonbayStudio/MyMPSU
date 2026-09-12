import type { UserProfile } from "../models/domain";
import { platformService } from "../platform/platformService";
import { storageService } from "../platform/storageService";
import { apiRequest } from "./client";

interface LoginResponse {
  token: string;
  user: UserProfile;
}

export async function login(email: string, password: string): Promise<UserProfile> {
  const platform = await platformService.getPlatform();
  const response = await apiRequest<LoginResponse>("/auth/login", {
    method: "POST",
    body: JSON.stringify({
      email,
      password,
      deviceId: crypto.randomUUID(),
      deviceName: "MyMPSU Desktop",
      platform,
      appVersion: "0.1.0",
    }),
  });
  await storageService.setAuthToken(response.token);
  return response.user;
}

export function getProfile(): Promise<UserProfile> {
  return apiRequest("/me");
}

export async function logout(): Promise<void> {
  await storageService.clearAuthToken();
}
