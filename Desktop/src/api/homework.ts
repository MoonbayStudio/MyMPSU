import type { Homework, HomeworkDraft } from "../models/domain";
import { apiRequest } from "./client";

export const homeworkApi = {
  list(groupId: number): Promise<Homework[]> {
    return apiRequest(`/groups/${groupId}/homeworks`);
  },
  create(groupId: number, draft: HomeworkDraft): Promise<Homework> {
    return apiRequest(`/groups/${groupId}/homeworks`, {
      method: "POST",
      body: JSON.stringify(draft),
    });
  },
  update(groupId: number, id: number, draft: Partial<HomeworkDraft>): Promise<Homework> {
    return apiRequest(`/groups/${groupId}/homeworks/${id}`, {
      method: "PATCH",
      body: JSON.stringify(draft),
    });
  },
  remove(groupId: number, id: number): Promise<void> {
    return apiRequest(`/groups/${groupId}/homeworks/${id}`, { method: "DELETE" });
  },
};
