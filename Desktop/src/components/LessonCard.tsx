import { Clock3, MapPin, UserRound } from "lucide-react";
import type { Lesson } from "../models/domain";

export function LessonCard({ lesson, state }: { lesson: Lesson; state?: string }) {
  const stateLabel = state === "current" ? "Сейчас" : state === "next" ? "Следующая" : null;
  return (
    <article className={`lesson-card ${state ? `is-${state}` : ""}`}>
      <div className="lesson-time"><span>{lesson.startTime}</span><small>{lesson.endTime}</small></div>
      <div className="lesson-main">
        <div className="lesson-title-row">
          <h3>{lesson.subject}</h3>
          {stateLabel && <span className="status-badge">{stateLabel}</span>}
        </div>
        <span className="lesson-type">{lesson.type}</span>
        <div className="lesson-meta">
          <span><UserRound size={15} />{lesson.teacher}</span>
          <span><MapPin size={15} />{lesson.room}</span>
          <span className="sr-only"><Clock3 size={15} />с {lesson.startTime} до {lesson.endTime}</span>
        </div>
      </div>
    </article>
  );
}
