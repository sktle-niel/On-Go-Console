# On Go Console

The **Admin** and **Moderator** web application.

This is one of On Go's two front ends. The other is the mobile app (Client +
Mechanic), which lives in its own repository,
[On-Go](https://github.com/sktle-niel/On-Go). They are separate applications:
neither imports the other, and everything they exchange goes through
`package:on_go_shared`. See `ARCHITECTURE.md` in that repository.

## Checking out

All three shared packages — `on_go_design`, `on_go_shared` and `on_go_api` —
live in the mobile app's repository and are resolved here by **relative path**,
so the two checkouts have to sit side by side:

```
Documents/
  On-Go/          the mobile app, and packages/on_go_design,
                  packages/on_go_shared and packages/on_go_api
  On-Go-Console/  this repository, and packages/on_go_console_backend
```

```bash
git clone https://github.com/sktle-niel/On-Go.git On-Go
git clone https://github.com/sktle-niel/On-Go-Console.git On-Go-Console
```

If `flutter pub get` reports that it cannot find `../On-Go/packages/...`, that
sibling checkout is what is missing.

## Running

```bash
flutter run -d chrome
```

Sign in as `admin` to open the administration side and create the first
moderator account. Moderators then sign in with the email and password their
admin set for them.

Clients and mechanics cannot sign in here — `AuthApi` refuses a mobile role on
the console surface, and the reverse.

## Layout

```
lib/src/app/        MaterialApp, named routes, the rail + top bar shell
packages/on_go_console_backend/
                    ← the seam: every call that leaves the console
                      (package:on_go_console_backend — ConsoleBackend, api/, local/)
lib/src/features/
    admin/            Overview, Moderators, Add Moderator, Escalations,
                      Audit Log, Income, Points, Ranks, Leaderboard,
                      Performance, Settings
    moderator/        Queue, History, Accounts, Profile, Settings
    shared/           Appearance, App Background, the review dialog
    auth/             Sign In
lib/src/session/    Who is signed in and what they may do
lib/src/theme/      The console's own design system
lib/src/widgets/    Cards, tables, badges, charts, empty states
```

## Theming

The console and the mobile app are **one theme system**, not two that look
alike. `package:on_go_design` holds the palettes, the theme registry, the
design tokens and the `ThemeController`; both front ends drive the same
controller.

That means the console offers the same eight themes, in four light/dark
families — Default and Dark Default, Calm Blue and Cold Blue, Ember Light and
Ember, Forest and Forest Night — under the same names, with the same **Dark
Mode**, **Dynamic Themes** (follow the clock) and **Warm Filter** controls,
behaving identically. Add a theme to `AppThemes.all` and it appears in both
pickers with nothing else to change.

What the console builds for itself is its `ThemeData`
(`lib/src/theme/console_theme.dart`): the same colours and the same pill
buttons and corner scale, at a density that suits a mouse and a wide window.
`ConsoleColors` keeps the desktop vocabulary — `sidebar`, `canvas`, `border` —
but every name resolves to a palette role, so there are no colour values here
that could drift from the app's.

Each person's theme is their own, saved in their own browser. The console does
not push a theme to anyone's phone; the only appearance it sets for the app is
the Sign In background, which is branding and lives behind its own permission.

`test/console_theme_test.dart` pins this.

## Responsive layout

The console adapts to the window it is in, with no setting to change. One
object — `ConsoleLayout` in `lib/src/theme/console_layout.dart` — turns the
width into every layout decision, and pages read it through `context.layout`
rather than testing widths themselves.

| | Phone (< 640) | Tablet (640–1079) | Desktop (≥ 1080) |
| --- | --- | --- | --- |
| Chrome | The **app's** app bar + bottom bar + drawer | Icon rail with tooltips (drawer under 860) | Pinned 248pt rail |
| Sections | Flat: heading, then content | Bordered panels | Bordered panels |
| Stat grid | 2 columns | 2 columns | 4 columns |
| Tables | One card per record | Table, scrolls in its card | Full table |
| Dialogs | Near full-width | Sized to fit | Their preferred width |
| Gutters | 14 | 20 | 24 |
| Content width | Full | Full | Capped at 1180 |

On a phone the console wears the **Client and Mechanic app's own chrome** —
`OnGoAppBar`, `NotificationBell` and `OnGoBottomNav` from
`package:on_go_design`, the same widget instances the app builds with, not
copies. So the floating pill bar, its selected-pill animation, its spacing and
its icons are the app's by construction and cannot drift.

The bar carries what the original panels carried:

| Role | Bottom bar | Drawer | Bell |
| --- | --- | --- | --- |
| Admin | Overview · Mods · Add · Audit · Income | Settings, Log Out | Notifications |
| Moderator | Queue · History · Accounts · Profile | Settings, Log Out | Jumps to Queue |

Admin and Moderator run through the same shell with their own destination
list, so neither can drift from the other, and **every destination stays
reachable at every size** — a test asserts it. A tablet and a desktop keep the
rail, which lists all of them.

`test/console_layout_test.dart` pins all of this — it is the kind of behaviour
that otherwise regresses silently on a developer's wide screen.

## Notes

- **It has URLs.** `/admin/moderators`, `/moderator/history`, and so on.
  Bookmarkable and linkable, and routing refuses a route belonging to the other
  role.
- **The design system is the app's.** Same eight themes, same colours, same
  Dark Mode / Dynamic Themes / Warm Filter — see below.
- **It talks to the On Go API**, on staging unless `ONGO_API_BASE_URL` says
  otherwise. Sign-in, the points policy, revenue and the Sign In background are
  served; the verification queue and the moderator directory are served behind
  `ONGO_API_VERIFICATION` and `ONGO_API_MODERATORS`. Build with
  `ONGO_BACKEND=local` and every contract keeps its in-browser implementation
  instead. The seam is `ConsoleBackend`; see `ConsoleApi`.
- **The queue and the ledger fill up from the mobile app**, so a staging
  database with no traffic shows them empty — every empty state here says so
  rather than looking broken.
