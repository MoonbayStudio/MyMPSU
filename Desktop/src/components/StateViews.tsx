import { AlertCircle, BookOpen, LoaderCircle, RefreshCw } from "lucide-react";

export function LoadingState({ label = "Загружаем данные…" }: { label?: string }) {
  return (
    <div className="state-view" role="status">
      <LoaderCircle className="spin" aria-hidden="true" />
      <span>{label}</span>
    </div>
  );
}

export function ErrorState({ message, retry }: { message: string; retry?: () => void }) {
  return (
    <div className="state-view state-error" role="alert">
      <AlertCircle aria-hidden="true" />
      <div><strong>Не удалось загрузить данные</strong><p>{message}</p></div>
      {retry && <button className="button secondary" onClick={retry}><RefreshCw size={16} /> Повторить</button>}
    </div>
  );
}

export function EmptyState({ title, text }: { title: string; text: string }) {
  return (
    <div className="state-view">
      <BookOpen aria-hidden="true" />
      <div><strong>{title}</strong><p>{text}</p></div>
    </div>
  );
}
