import {
  isPermissionGranted,
  requestPermission,
  sendNotification,
} from "@tauri-apps/plugin-notification";
import { isTauri } from "./platformService";

export interface NotificationService {
  notify(title: string, body: string): Promise<boolean>;
}

export const notificationService: NotificationService = {
  async notify(title, body) {
    if (!isTauri()) return false;
    let granted = await isPermissionGranted();
    if (!granted) granted = (await requestPermission()) === "granted";
    if (!granted) return false;
    sendNotification({ title, body });
    return true;
  },
};
