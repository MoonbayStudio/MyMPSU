import { useMemo } from "react";
import { CloudOff, RefreshCw, Sparkles } from "lucide-react";
import { useSchedule } from "../../hooks/useSchedule";
import { LessonCard } from "../../components/LessonCard";
import { EmptyState, ErrorState, LoadingState } from "../../components/StateViews";
import { markNextLesson, toIsoDate } from "../../services/dateService";

export function TodayPage() {
  const now = useMemo(() => new Date(), []);
  const schedule = useSchedule(now);
  const lessons = useMemo(
    () => schedule.data?.lessons.filter((lesson) => lesson.date === toIsoDate(now)) ?? [],
    [schedule.data, now],
  );
  const states = useMemo(() => markNextLesson(lessons, now), [lessons, now]);

  return (
    <section className="page">
      <header className="page-header">
        <div><span className="eyebrow">Сегодня</span><h1>{new Intl.DateTimeFormat("ru-RU", { weekday: "long", day: "numeric", month: "long" }).format(now)}</h1><p>Ваш учебный день в одном месте.</p></div>
        <button className="button secondary" onClick={() => void schedule.refetch()}><RefreshCw size={16} /> Обновить</button>
      </header>
      {schedule.data?.source === "mock" && <div className="notice info"><Sparkles />Тестовое расписание: пары сгенерированы для этой недели.</div>}
      {schedule.data?.source === "cache" && <div className="notice warning"><CloudOff />Сервер недоступен. Показана сохранённая копия от {new Date(schedule.data.fetchedAt).toLocaleString("ru-RU")}.</div>}
      {schedule.isLoading && <LoadingState label="Составляем ваш день…" />}
      {schedule.isError && <ErrorState message={schedule.error.message} retry={() => void schedule.refetch()} />}
      {schedule.isSuccess && lessons.length === 0 && <EmptyState title="Сегодня пар нет" text="Можно выдохнуть или заглянуть в расписание на неделю." />}
      <div className="today-layout">
        <div className="lesson-list">{lessons.map((lesson) => <LessonCard key={lesson.id} lesson={lesson} state={states.get(lesson.id)} />)}</div>
        {lessons.length > 0 && <aside className="day-summary"><span className="eyebrow">Кратко</span><strong>{lessons.length} {lessons.length === 1 ? "пара" : lessons.length < 5 ? "пары" : "пар"}</strong><p>Первая в {lessons[0].startTime}<br />Последняя до {lessons.at(-1)?.endTime}</p></aside>}
      </div>
    </section>
  );
}
