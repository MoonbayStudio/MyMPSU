import { useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Pencil, Plus, Trash2, X } from "lucide-react";
import { homeworkApi } from "../../api/homework";
import type { Homework, HomeworkDraft } from "../../models/domain";
import { useAppContext } from "../../app/AppContext";
import { canEditHomework } from "../../services/permissions";
import { EmptyState, ErrorState, LoadingState } from "../../components/StateViews";

const emptyDraft: HomeworkDraft = { lesson_date: new Date().toISOString().slice(0, 10), lesson_time: "09:00", subject: "", teacher: "", room: "", text: "" };

export function HomeworkPage() {
  const { preferences, profile } = useAppContext();
  const [editing, setEditing] = useState<Homework | "new" | null>(null);
  const [draft, setDraft] = useState<HomeworkDraft>(emptyDraft);
  const queryClient = useQueryClient();
  const query = useQuery({ queryKey: ["homework", preferences.groupId], queryFn: () => homeworkApi.list(preferences.groupId), enabled: Boolean(profile) });
  const save = useMutation({
    mutationFn: () => editing === "new" ? homeworkApi.create(preferences.groupId, draft) : homeworkApi.update(preferences.groupId, editing!.id, draft),
    onSuccess: async () => { setEditing(null); await queryClient.invalidateQueries({ queryKey: ["homework", preferences.groupId] }); },
  });
  const remove = useMutation({ mutationFn: (id: number) => homeworkApi.remove(preferences.groupId, id), onSuccess: () => queryClient.invalidateQueries({ queryKey: ["homework", preferences.groupId] }) });
  const canEdit = canEditHomework(profile, preferences.groupId);

  const beginEdit = (item: Homework) => {
    setDraft({ lesson_date: item.lesson_date, lesson_time: item.lesson_time, subject: item.subject, teacher: item.teacher, room: item.room, text: item.text });
    setEditing(item);
  };
  const submit = (event: FormEvent) => { event.preventDefault(); save.mutate(); };

  return <section className="page">
    <header className="page-header"><div><span className="eyebrow">Учёба</span><h1>Домашние задания</h1><p>Задания вашей группы, отсортированные по дате занятия.</p></div>{canEdit && <button className="button primary" onClick={() => { setDraft(emptyDraft); setEditing("new"); }}><Plus size={17} /> Добавить</button>}</header>
    {!profile && <EmptyState title="Нужна авторизация" text="Войдите в профиле, чтобы видеть домашние задания своей группы." />}
    {query.isLoading && <LoadingState />}
    {query.isError && <ErrorState message={query.error.message} retry={() => void query.refetch()} />}
    {query.data?.length === 0 && <EmptyState title="Заданий пока нет" text="Когда староста или модератор добавит домашку, она появится здесь." />}
    <div className="homework-grid">{query.data?.map((item) => <article className="homework-card" key={item.id}><div className="homework-date"><strong>{new Date(`${item.lesson_date}T12:00:00`).toLocaleDateString("ru-RU", { day: "numeric", month: "short" })}</strong><span>{item.lesson_time}</span></div><div><span className="lesson-type">{item.subject}</span><h2>{item.text}</h2><p>{[item.teacher, item.room].filter(Boolean).join(" · ")}</p></div>{canEdit && <div className="card-actions"><button className="icon-button" aria-label={`Изменить: ${item.subject}`} onClick={() => beginEdit(item)}><Pencil /></button><button className="icon-button danger" aria-label={`Удалить: ${item.subject}`} onClick={() => remove.mutate(item.id)}><Trash2 /></button></div>}</article>)}</div>
    {editing && <div className="modal-backdrop" role="presentation"><form className="modal" onSubmit={submit} aria-label={editing === "new" ? "Новое домашнее задание" : "Редактирование домашнего задания"}><header><h2>{editing === "new" ? "Новое задание" : "Изменить задание"}</h2><button type="button" className="icon-button" aria-label="Закрыть" onClick={() => setEditing(null)}><X /></button></header><div className="form-grid"><label>Дата<input type="date" required value={draft.lesson_date} onChange={(e) => setDraft({ ...draft, lesson_date: e.target.value })} /></label><label>Время<input type="time" value={draft.lesson_time ?? ""} onChange={(e) => setDraft({ ...draft, lesson_time: e.target.value })} /></label><label className="wide">Предмет<input required value={draft.subject} onChange={(e) => setDraft({ ...draft, subject: e.target.value })} /></label><label>Преподаватель<input value={draft.teacher ?? ""} onChange={(e) => setDraft({ ...draft, teacher: e.target.value })} /></label><label>Аудитория<input value={draft.room ?? ""} onChange={(e) => setDraft({ ...draft, room: e.target.value })} /></label><label className="wide">Задание<textarea required rows={4} value={draft.text} onChange={(e) => setDraft({ ...draft, text: e.target.value })} /></label></div>{save.isError && <p className="form-error">{save.error.message}</p>}<footer><button type="button" className="button secondary" onClick={() => setEditing(null)}>Отмена</button><button className="button primary" disabled={save.isPending}>{save.isPending ? "Сохраняем…" : "Сохранить"}</button></footer></form></div>}
  </section>;
}
