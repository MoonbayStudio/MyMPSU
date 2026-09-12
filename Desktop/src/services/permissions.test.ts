import { describe, expect, it } from "vitest";
import type { UserProfile } from "../models/domain";
import { canEditHomework } from "./permissions";

const profile = (type: string, groupId?: number): UserProfile => ({ id: "1", roles: [{ type, title: type, groupId }], tier: "free", linkedProviders: [] });

describe("canEditHomework", () => {
  it("allows leaders only in their group", () => {
    expect(canEditHomework(profile("group_leader", 7), 7)).toBe(true);
    expect(canEditHomework(profile("group_leader", 7), 8)).toBe(false);
  });
  it("does not allow a regular student", () => expect(canEditHomework(profile("student"), 7)).toBe(false));
});
