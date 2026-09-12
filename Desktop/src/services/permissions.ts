import type { UserProfile } from "../models/domain";

const EDIT_HOMEWORK_ROLES = new Set(["admin", "moderator", "group_leader"]);

export function canEditHomework(profile: UserProfile | null, groupId: number): boolean {
  if (!profile) return false;
  return profile.roles.some(
    (role) => EDIT_HOMEWORK_ROLES.has(role.type) && (!role.groupId || role.groupId === groupId),
  );
}
