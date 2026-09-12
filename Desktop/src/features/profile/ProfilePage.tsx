import { useState, type FormEvent } from "react";
import { CheckCircle2, LogIn, LogOut, Mail, ShieldCheck, UsersRound } from "lucide-react";
import { useAppContext } from "../../app/AppContext";

export function ProfilePage() {
  const { profile, preferences, login, logout, authLoading } = useAppContext();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    try { await login(email, password); } catch (reason) { setError(reason instanceof Error ? reason.message : "Не удалось войти"); }
  };

  if (!profile) return <section className="page profile-narrow"><header className="page-header"><div><span className="eyebrow">Аккаунт</span><h1>Вход в Мой МПГУ</h1><p>Токен сессии хранится в защищённом системном хранилище, а не в localStorage.</p></div></header><form className="login-card" onSubmit={submit}><div className="login-symbol"><LogIn /></div><label>Электронная почта<input type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} /></label><label>Пароль<input type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} /></label>{error && <p className="form-error" role="alert">{error}</p>}<button className="button primary" disabled={authLoading}>{authLoading ? "Входим…" : "Войти"}</button></form></section>;

  return <section className="page"><header className="page-header"><div><span className="eyebrow">Аккаунт</span><h1>{profile.displayName || "Пользователь МПГУ"}</h1><p>Данные вашего аккаунта и права доступа.</p></div><button className="button secondary danger-text" onClick={() => void logout()}><LogOut size={16} /> Выйти</button></header><div className="profile-grid"><article className="profile-card identity-card"><div className="avatar">{(profile.displayName || "М").slice(0, 1).toUpperCase()}</div><h2>{profile.displayName || "Имя не указано"}</h2><p>{profile.email || profile.contactEmail || "Почта не указана"}</p><span className="plan-badge">{profile.tier === "free" ? "Базовый план" : profile.tier}</span></article><div className="profile-details"><article><Mail /><div><span>Электронная почта</span><strong>{profile.email || profile.contactEmail || "Не указана"}</strong></div></article><article><UsersRound /><div><span>Учебная группа</span><strong>{preferences.groupName}</strong></div></article><article><ShieldCheck /><div><span>Роли</span><strong>{profile.roles.length ? profile.roles.map((role) => role.title).join(", ") : "Студент"}</strong></div></article><article><CheckCircle2 /><div><span>Способы входа</span><strong>{profile.linkedProviders.length ? profile.linkedProviders.join(", ") : "Пароль"}</strong></div></article></div></div></section>;
}
