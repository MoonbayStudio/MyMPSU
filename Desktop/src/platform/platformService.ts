import { type as osType } from "@tauri-apps/plugin-os";

export type DesktopPlatform = "macos" | "windows" | "linux" | "browser";

export interface PlatformService {
  getPlatform(): Promise<DesktopPlatform>;
  shortcutLabel(key: string): Promise<string>;
}

function isTauri(): boolean {
  return "__TAURI_INTERNALS__" in window;
}

class DefaultPlatformService implements PlatformService {
  async getPlatform(): Promise<DesktopPlatform> {
    if (!isTauri()) return "browser";
    const value = osType();
    if (value === "macos") return "macos";
    if (value === "windows") return "windows";
    return "linux";
  }

  async shortcutLabel(key: string): Promise<string> {
    return `${(await this.getPlatform()) === "macos" ? "⌘" : "Ctrl+"}${key}`;
  }
}

export const platformService: PlatformService = new DefaultPlatformService();
export { isTauri };
