import { useState } from "react";
import { ChevronLeft, ChevronRight, RefreshCw } from "lucide-react";
import { LessonCard } from "../../components/LessonCard";
import { ErrorState, LoadingState } from "../../components/StateViews";
import { useSchedule } from "../../hooks/useSchedule";
import { addDays, startOfWeek, toIsoDate } from "../../services/dateService";

export function SchedulePage() {
  const [week, setWeek] = useState(() => startOfWeek(new Date()));
  const schedule = useSchedule(week);
  const monday = startOfWeek(week);
  const days = Array.from({ length: 6 }, (_, index) => addDays(monday, index));
  const label = `${new Intl.DateTimeFormat("ru-RU", { day: "numeric", month: "short" }).format(monday)} — ${new Intl.DateTimeFormat("ru-RU", { day: "numeric", month: "short", year: "numeric" }).format(addDays(monday, 6))}`;

  return (
    <section className="page schedule-page">
      <header className="page-header">
        <div><span className="eyebrow">Неделя</span><h1>Расписание</h1><p>{label}</p></div>
        <div className="toolbar" aria-label="Переключение недели">
          <button className="icon-button" aria-label="Предыдущая неделя" onClick={() => setWeek(addDays(week, -7))}><ChevronLeft /></button>
          <button className="button secondary" onClick={() => setWeek(startOfWeek(new Date()))}>Эта неделя</button>
          <button className="icon-button" aria-label="Следующая неделя" onClick={() => setWeek(addDays(week, 7))}><ChevronRight /></button>
          <button className="icon-button" aria-label="Обновить" onClick={() => void schedule.refetch()}><RefreshCw /></button>
        </div>
      </header>
      {schedule.isLoading && <LoadingState />}
      {schedule.isError && <ErrorState message={schedule.error.message} retry={() => void schedule.refetch()} />}
      {schedule.data && <div className="week-grid">{days.map((day) => {
        const date = toIsoDate(day);
        const items = schedule.data.lessons.filter((lesson) => lesson.date === date);
        const isToday = date === toIsoDate(new Date());
        return <section className={`day-column ${isToday ? "today" : ""}`} key={date} aria-label={day.toLocaleDateString("ru-RU")}>
          <header><span>{new Intl.DateTimeFormat("ru-RU", { weekday: "short" }).format(day)}</span><strong>{day.getDate()}</strong></header>
          <div>{items.length ? items.map((lesson) => <LessonCard key={lesson.id} lesson={lesson} />) : <p className="empty-day">Пар нет</p>}</div>
        </section>;
      })}</div>}
    </section>
  );
}
