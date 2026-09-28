# on_go_console_backend

The admin console's backend seam, as a package. It used to be
`on_go_console/lib/src/backend/`.

```
lib/
  console_backend.dart   ConsoleBackend: every contract the console calls
  api/                   ConsoleApi: installs the On Go API client (package:on_go_api)
  local/                 In-browser implementations, one per contract
```

The console imports it as `package:on_go_console_backend/console_backend.dart`
(and `.../api/console_api.dart`, `.../local/...`). Nothing in here imports a
console screen, session or theme, which is what let it move out of the app.

There is still one On Go API for every role: the TypeScript repository
`On-Go backend api` beside the two front ends (`sktle-niel/On-Go-WA`, deployed
on staging). The contract and client both apps use are in
`../../../On-Go/packages/`. This package is the console's side of that seam:
local stand-ins until the API serves a contract, then the API itself.

## Checking it

```bash
flutter pub get
flutter analyze
```

Its behaviour is tested from the console (`on_go_console/test`), whose pages
and services exercise it.
