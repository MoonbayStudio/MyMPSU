import { useEffect, useState } from "react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { Bot, CalendarDays, ClipboardList, GraduationCap, House, PanelLeftClose, PanelLeftOpen, Settings, UserRound } from "lucide-react";
import { useQueryClient } from "@tanstack/react-query";
import { useAppContext } from "./AppContext";

const navigation = [
  { to: "/", label: "Сегодня", icon: House, end: true },
  { to: "/schedule", label: "Расписание", icon: CalendarDays },
  { to: "/homework", label: "Домашние задания", icon: ClipboardList },
  { to: "/assistant", label: "AI-помощник", icon: Bot },
  { to: "/profile", label: "Профиль", icon: UserRound },
];

export function AppShell() {
  const [collapsed, setCollapsed] = useState(false);
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { preferences } = useAppContext();

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      if (!(event.metaKey || event.ctrlKey)) return;
      const routes: Record<string, string> = { "1": "/", "2": "/schedule", "3": "/homework", "4": "/assistant", ",": "/settings" };
      if (routes[event.key]) {
        event.preventDefault();
        navigate(routes[event.key]);
      } else if (event.key.toLowerCase() === "r") {
        event.preventDefault();
        void queryClient.invalidateQueries();
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [navigate, queryClient]);

  return (
    <div className={`app-shell ${collapsed ? "sidebar-collapsed" : ""}`}>
      <aside className="sidebar">
        <div className="brand-row">
          <div className="brand-mark" aria-hidden="true"><GraduationCap /></div>
          <div className="brand-copy"><strong>Мой МПГУ</strong><span>{preferences.groupName}</span></div>
          <button className="icon-button collapse-button" aria-label={collapsed ? "Развернуть боковую панель" : "Свернуть боковую панель"} onClick={() => setCollapsed((value) => !value)}>
            {collapsed ? <PanelLeftOpen /> : <PanelLeftClose />}
          </button>
        </div>
        <nav aria-label="Основная навигация">
          {navigation.map(({ to, label, icon: Icon, end }) => (
            <NavLink key={to} to={to} end={end} aria-label={label} title={collapsed ? label : undefined}>
              <Icon aria-hidden="true" /><span>{label}</span>
            </NavLink>
          ))}
        </nav>
        <NavLink className="settings-link" to="/settings" aria-label="Настройки" title={collapsed ? "Настройки" : undefined}>
          <Settings aria-hidden="true" /><span>Настройки</span>
        </NavLink>
      </aside>
      <main className="main-content"><Outlet /></main>
    </div>
  );
}
