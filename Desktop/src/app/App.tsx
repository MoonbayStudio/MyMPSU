import { createBrowserRouter, RouterProvider } from "react-router-dom";
import { AppShell } from "./AppShell";
import { TodayPage } from "../features/schedule/TodayPage";
import { SchedulePage } from "../features/schedule/SchedulePage";
import { HomeworkPage } from "../features/homework/HomeworkPage";
import { ProfilePage } from "../features/profile/ProfilePage";
import { SettingsPage } from "../features/settings/SettingsPage";
import { AssistantPage } from "../features/assistant/AssistantPage";

const router = createBrowserRouter([
  {
    path: "/",
    element: <AppShell />,
    children: [
      { index: true, element: <TodayPage /> },
      { path: "schedule", element: <SchedulePage /> },
      { path: "homework", element: <HomeworkPage /> },
      { path: "assistant", element: <AssistantPage /> },
      { path: "profile", element: <ProfilePage /> },
      { path: "settings", element: <SettingsPage /> },
    ],
  },
]);

export function App() {
  return <RouterProvider router={router} />;
}
