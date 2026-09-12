# MyMPSU Development Progress

Last updated: 2026-07-05

This is the public development progress log for MyMPSU. It tracks the main product direction, recent completed work, known gaps, and the weekly testing flow.

Do not store secrets, credentials, private server notes, signing details, local machine paths, private keys, tokens, or internal deployment instructions in this file.

## Current Product Direction

MyMPSU is moving toward feature parity across iOS, Android, backend, and web. The current focus is Android parity with the richer iOS behavior around runtime configuration, AI chat, role requests, accessibility, app security, premium features, admin tools, themes, and active notifications.

## Current Android Status

Android already covers the core app surface:

- bottom navigation;
- schedule and session screens;
- group selection;
- homework in schedule cards;
- account flow with email, Google, and Apple sign-in;
- account sessions;
- group members;
- themes;
- onboarding;
- basic admin panel;
- foreground notification for the current lesson state.

The largest remaining gaps are not in basic schedule browsing, but in product polish and platform parity:

- full Pelikasha / AI chat history UI;
- App Lock and local biometric protection;
- Plus / Premium subscription flow;
- advanced accessibility behavior, including text-to-speech scenarios;
- complete admin parity for runtime settings, system notices, and moderation;
- theme ID migration and visual parity;
- safer Android token storage.

## Recently Completed

### 2026-07-12 - Student Maintainer Handover Foundation

Goal:

- Make a new, empty MyMPSU backend installation reproducible without
  transferring existing user accounts.

Completed:

- Replaced the broken root Docker entrypoint with a working API image.
- Added a single documented Compose stack with PostgreSQL and health checks.
- Added explicit empty-database initialization.
- Added safe example configuration with optional AI and SMTP integration.
- Expanded the root environment template to cover every backend integration and
  documented API deployment, HTTPS, firewall ports, Ollama, and Swagger access.
- Added database backup and restore commands.
- Added setup, operations, and maintainer handover documentation.
- Added backend test and container-build CI.
- Made browser CORS origins configurable for student-operated deployments.

Verification:

- Backend suite: 43 tests passed.
- Empty SQLite database initialization created 20 expected tables.
- Docker Compose configuration parsed successfully.
- Full container build was not run because Docker Desktop was not active.

Remaining:

- Replace the legacy schema bootstrap with versioned Alembic migrations.
- Move mobile API addresses and signing identifiers into build configuration.
- Test the documented flow from a clean clone on a second machine.
- Add production reverse-proxy and release procedures.

### 2026-06-25 - Android Parity Foundation

Completed:

- Added Android runtime config and public system notice support.
- Added maintenance banner behavior.
- Connected AI availability and daily limits to runtime settings.
- Improved schedule cache behavior and pull-to-refresh.
- Split offline schedule cache and active notification settings.
- Added Android tester role request UI.
- Improved Android schedule, homework, and assistant logic toward iOS parity.
- Added AI orchestration pieces: intent detection, local answers, context selection, context budgeting, dialog summary compression, response validation, emergency retry, and request cancellation.

Verification at the time:

- Android debug build passed.
- Android release build passed.
- Backend tests passed.

### 2026-06-25 - Requests And Moderation

Completed:

- Added backend endpoint to cancel a pending role request.
- Added backend endpoint to cancel a pending group-change request.
- Added Android API and repository support for cancelling both request types.
- Added Android "My requests" block in the account screen.
- Displayed user role requests and group-change requests with statuses and moderator comments.
- Added cancel action for pending requests.
- Added admin reject dialogs with moderator comments.
- Added backend tests for cancelling role and group-change requests.

Verification at the time:

- Backend tests passed.
- Android debug build passed.
- Android release build passed.

## Partially Complete

### Pelikasha / AI Chat

Implemented:

- AI intent orchestration;
- local answer engine;
- relevant schedule context;
- context budgeting and compression;
- response validation;
- emergency retry;
- request cancellation.

Remaining:

- full dialog history screen;
- create, delete, rename, and switch dialogs;
- clearer retry UI for failed bubbles;
- richer UX parity with iOS.

### Active Notifications

Implemented:

- current lesson state notification;
- schedule data from cache/API;
- Android notification permission flow;
- deep link into the schedule area.

Remaining:

- notification actions;
- exact alarm UX or fallback strategy;
- possible home screen widget if considered part of iOS WidgetKit parity.

### Accessibility

Implemented:

- stored settings for reduced motion, high contrast, larger text, haptics, auto speech, and detailed speech.

Remaining:

- complete UI wiring;
- text-to-speech for schedule;
- automatic speech scenarios;
- broader high contrast and large text verification across key screens.

### Requests

Implemented:

- tester role request;
- user request history;
- cancellation of pending requests;
- moderator comments for rejections.

Remaining:

- optional richer filtering and history views;
- extended moderation screens if needed.

## Roadmap

### P0

- Finish Pelikasha dialog management UI.
- Keep runtime config and system notices aligned across iOS and Android.

### P1

- Add App Lock with passcode and biometrics on Android.
- Add Plus / Premium subscription flow through Google Play Billing.
- Finish accessibility behavior, especially schedule speech.
- Add "My group" homework parity on Android.
- Improve admin parity for notice editing, runtime settings, and moderation comments.

### P2

- Migrate theme IDs and polish theme parity.
- Improve active notification actions and exact alarm handling.
- Move Android auth token storage to a stronger encrypted storage path.

## Weekly Testing Flow

The project should use a predictable weekly testing rhythm:

1. Pick a weekly build label, for example `2026-W28` or `v0.8.0-beta.3`.
2. Build and distribute Android APK and iOS TestFlight builds from the same feature set.
3. Publish a short tester changelog with:
   - what changed;
   - what testers should focus on;
   - known issues;
   - how to report feedback.
4. Collect tester feedback in one structured place.
5. Convert feedback into GitHub issues or a single triage note.
6. Update this progress file after fixes are implemented and verified.

## Tester Feedback Template

Use this structure for tester notes so they are easy to triage and hand to an AI assistant or developer:

```md
## Build

- Platform: Android / iOS
- Version or build label:
- Device:
- OS version:
- Tester:

## Summary

One sentence describing the issue or suggestion.

## Steps To Reproduce

1.
2.
3.

## Expected Result

What should have happened?

## Actual Result

What happened instead?

## Evidence

- Screenshot/video:
- Logs, if available:

## Severity

- Blocker / High / Medium / Low

## Notes

Any extra context, frequency, workaround, or related feedback.
```

## How To Update This File

For each new feature or weekly iteration, add a dated entry with:

- goal;
- implementation stages;
- completed work;
- changed user behavior;
- verification commands or manual checks;
- remaining gaps;
- next concrete step.

Use this mini-template:

```md
### YYYY-MM-DD - Feature Or Release Name

Goal:

-

Stages:

- [ ] Discovery
- [ ] Design
- [ ] Implementation
- [ ] Verification
- [ ] Handoff

Completed:

-

Verification:

-

Remaining:

-
```
