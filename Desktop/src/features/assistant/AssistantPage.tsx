import { type FormEvent, useMemo, useRef, useState } from "react";
import { Bot, CalendarDays, LoaderCircle, Send, Sparkles, Trash2 } from "lucide-react";
import { useAppContext } from "../../app/AppContext";
import { sendAssistantMessage } from "../../api/assistant";
import { useSchedule } from "../../hooks/useSchedule";
import type { AssistantMessage } from "../../models/domain";
import { toIsoDate } from "../../services/dateService";

const welcomeMessage: AssistantMessage = {
  id: "welcome",
  role: "assistant",
  content: "Привет! Я помогу разобраться с парами, аудиториями и учебными делами. Например, спроси: «Какие пары завтра?»",
};

const quickPrompts = ["Какие пары сегодня?", "Что у меня завтра?", "Во сколько первая пара?"];

export function AssistantPage() {
  const { preferences } = useAppContext();
  const today = useMemo(() => new Date(), []);
  const schedule = useSchedule(today);
  const conversationId = useRef(`desktop-${Date.now()}-${Math.random().toString(36).slice(2)}`);
  const [messages, setMessages] = useState<AssistantMessage[]>([welcomeMessage]);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [remaining, setRemaining] = useState<number | null>(null);

  async function submitMessage(text: string) {
    const normalized = text.trim();
    if (!normalized || sending) return;

    const userMessage: AssistantMessage = {
      id: `user-${Date.now()}`,
      role: "user",
      content: normalized,
    };
    setMessages((current) => [...current, userMessage]);
    setDraft("");
    setError(null);
    setSending(true);

    try {
      const response = await sendAssistantMessage({
        message: normalized,
        conversationId: conversationId.current,
        groupId: preferences.groupId,
        groupName: preferences.groupName,
        targetDate: toIsoDate(today),
        schedule: schedule.data,
      });
      setMessages((current) => [
        ...current,
        { id: `assistant-${Date.now()}`, role: "assistant", content: response.reply },
      ]);
      setRemaining(response.remaining);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Не удалось получить ответ");
    } finally {
      setSending(false);
    }
  }

  function handleSubmit(event: FormEvent) {
    event.preventDefault();
    void submitMessage(draft);
  }

  function clearConversation() {
    conversationId.current = `desktop-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    setMessages([welcomeMessage]);
    setError(null);
    setRemaining(null);
  }

  return (
    <section className="page assistant-page">
      <header className="page-header assistant-header">
        <div>
          <span className="eyebrow">AI-ассистент</span>
          <h1>Помощник МПГУ</h1>
          <p><CalendarDays aria-hidden="true" /> Контекст: {preferences.groupName}</p>
        </div>
        <button className="button secondary" onClick={clearConversation} disabled={sending}>
          <Trash2 size={16} /> Новый диалог
        </button>
      </header>

      <div className="assistant-panel">
        <div className="assistant-messages" aria-live="polite" aria-label="Сообщения ассистента">
          {messages.map((message) => (
            <article className={`assistant-message ${message.role}`} key={message.id}>
              <div className="assistant-avatar" aria-hidden="true">{message.role === "assistant" ? <Bot /> : "Я"}</div>
              <div><span>{message.role === "assistant" ? "Помощник МПГУ" : "Вы"}</span><p>{message.content}</p></div>
            </article>
          ))}
          {sending && (
            <article className="assistant-message assistant pending">
              <div className="assistant-avatar" aria-hidden="true"><Bot /></div>
              <div><span>Помощник МПГУ</span><p><LoaderCircle className="spin" /> Думаю над ответом…</p></div>
            </article>
          )}
        </div>

        {messages.length === 1 && (
          <div className="assistant-suggestions" aria-label="Быстрые вопросы">
            {quickPrompts.map((prompt) => <button key={prompt} onClick={() => void submitMessage(prompt)}><Sparkles />{prompt}</button>)}
          </div>
        )}

        {error && <div className="assistant-error" role="alert">{error}. Проверьте, что AI включён, а OpenRouter-ключ задан на сервере.</div>}

        <form className="assistant-composer" onSubmit={handleSubmit}>
          <label className="sr-only" htmlFor="assistant-input">Сообщение помощнику</label>
          <textarea
            id="assistant-input"
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter" && !event.shiftKey) {
                event.preventDefault();
                event.currentTarget.form?.requestSubmit();
              }
            }}
            placeholder="Спросить о расписании или учёбе…"
            rows={2}
            maxLength={2000}
            disabled={sending}
          />
          <button className="assistant-send" type="submit" disabled={sending || !draft.trim()} aria-label="Отправить сообщение"><Send /></button>
        </form>
        <footer className="assistant-footer">
          <span>AI может ошибаться. Данные о парах берутся из расписания выбранной группы.</span>
          {remaining !== null && remaining >= 0 && <span>Осталось сегодня: {remaining}</span>}
        </footer>
      </div>
    </section>
  );
}
