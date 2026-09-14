# QueueUp Simple-Path Implementation Plan

> **For implementing agents:** Execute this plan task-by-task with test-first checkpoints. Do not add architecture or product scope beyond the MUST requirements in `spec(1).md`.

**Goal:** Build a compact Android Flutter hiring artifact backed by a deterministic in-memory Fastify API that demonstrates the complete event, squad, check-in, readiness, stale-data, release, and presentation flow.

**Architecture:** A Flutter application uses one injected `TournamentController extends ChangeNotifier` and explicit per-resource caches over a small `QueueUpApi` HTTP boundary. A Fastify process owns fresh in-memory seed state per `buildServer()` call and enforces check-in, station assignment, and readiness invariants. The simple path uses no preparatory refactor and no persistence, authentication, generic repository, or state-management package.

**Tech stack:** Stable Flutter/Dart, Material 3, `http`, `intl`, Android; Node LTS, TypeScript, Fastify, `tsx`, and `node:test`.

**Source of truth:** `spec(1).md`

---

## Mandatory commit boundary

- Do **not** commit anything Superpowers-related.
- Do not create or stage `.agents/`, `.opencode/`, `docs/superpowers/`, skill output, agent transcripts, or other Superpowers configuration/artifacts.
- Keep implementation commits limited to product source, product tests, generated Flutter Android project files, `README.md`, and required product evidence under `docs/screenshots/`.
- This planning document is stored in the neutral `docs/plans/` path because the workspace has no existing plan convention. Before any implementation commit, inspect `git status --short` and stage explicit product paths only.
- Never commit the release APK or demonstration video.

## Selected path and scope

The selected path is the **simple path**: build the smallest cohesive implementation directly from the specification, in its stated sequence, without prefactoring. Implement all MUST requirements. Do not begin SHOULD or OPTIONAL work as part of this plan. If all MUST work passes under the time cap, optional follow-up should be separately selected and planned.

### Explicit exclusions

No authentication, persistence/database, Firebase, payments, notifications, WebSockets, polling, background refresh, chat, scanning, brackets, admin UI, AI, iOS release, cloud infrastructure, containers, analytics, theme switching, custom animation, code generation, Dio, go_router, Provider/Riverpod, generic repositories/caches/results, networking middleware, or CI/CD. Do not add a venue-code step. Do not claim affiliation with real venues or Gala.

### Blast radius

This is a greenfield workspace containing only the specification. The intended blast radius is therefore limited to new `api/`, `mobile/`, `README.md`, and product-evidence files. The only cross-boundary contracts are JSON shapes, IDs, status strings, mutation responses, and localhost Android networking. Keeping those explicit and testing them at the API and controller boundaries avoids broader architecture.

## File map

### Repository root and evidence

- `README.md` — case study, architecture, setup/run/test/build commands, trade-offs, screenshots, recording link.
- `.gitignore` — excludes dependency/build/editor artifacts, APKs, videos, and Superpowers artifacts.
- `docs/screenshots/events.png` — required Events screenshot.
- `docs/screenshots/checked-in.png` — required checked-in Event screenshot.
- `docs/screenshots/squad-ready.png` — required ready Squad screenshot.
- `docs/screenshots/match-ready.png` — required ready Match screenshot.

### API

- `api/package.json` — development, typecheck, and test scripts plus Fastify/TypeScript dependencies.
- `api/tsconfig.json` — strict Node TypeScript configuration.
- `api/src/app.ts` — domain types, deterministic seed builder, `buildServer()`, routes, mutations, and safe error responses.
- `api/src/server.ts` — listen on `0.0.0.0:3000` and log startup/fatal details.
- `api/test/workflow.test.ts` — public HTTP-boundary invariant, transition, idempotency, isolation, and safe-error tests using `app.inject()`.

### Flutter

- `mobile/pubspec.yaml` — Flutter project metadata and only `http`/`intl` runtime dependencies.
- `mobile/lib/main.dart` — fixed dark theme (`themeMode: ThemeMode.dark`), API/controller composition root, controller injection, and owned `http.Client` disposal.
- `mobile/lib/models/event.dart` — immutable Event and strict `fromJson`.
- `mobile/lib/models/player.dart` — immutable Player and strict `fromJson`.
- `mobile/lib/models/squad.dart` — immutable Squad and strict `fromJson`.
- `mobile/lib/models/match.dart` — immutable Match, `MatchStatus`, and strict `fromJson`.
- `mobile/lib/models/api_responses.dart` — strict CheckInResponse, ReadyResponse, and safe API error representation.
- `mobile/lib/services/queue_up_api.dart` — `QueueUpApi` interface.
- `mobile/lib/services/api_client.dart` — injected `http.Client`, per-operation five-second await timeout, layered JSON validation, safe error handling, and explicit endpoint methods.
- `mobile/lib/state/request_state.dart` — minimal request status and safe message/stale state.
- `mobile/lib/state/tournament_controller.dart` — resource caches, independent request states, confirmed mutations, and notifications.
- `mobile/lib/screens/events_screen.dart` — three-event list, initial/fatal/refresh states, featured derivation.
- `mobile/lib/screens/event_detail_screen.dart` — detail, check-in, stations, and featured-only navigation.
- `mobile/lib/screens/squad_screen.dart` — five players, chips, and readiness.
- `mobile/lib/screens/match_screen.dart` — match details, check-in gate, readiness mutation, and confirmed state.
- `mobile/lib/widgets/resource_state_view.dart` — shared fatal error and state-driven persistent `MaterialBanner` below the AppBar without a generic cache abstraction.
- `mobile/lib/formatters.dart` — fixed English date/time and contiguous station-range formatting.
- `mobile/test/models/event_test.dart` — strict summary/detail parsing regressions.
- `mobile/test/state/tournament_controller_test.dart` — stale retention and cross-cache mutation regressions with a fake API.
- `mobile/android/app/src/main/AndroidManifest.xml` — internet permission and deliberate cleartext local HTTP allowance.
- `mobile/android/app/src/main/res/xml/network_security_config.xml` — create only if the generated target SDK is API 38 or newer, where `usesCleartextTraffic` alone is ignored; permits development HTTP for the demo build.
- Other files under `mobile/android/` — generated by stable `flutter create --platforms=android` and changed only where required.

## Implementation contract

| Acceptance criterion / invariant | Intended files | RED evidence and expected failure | GREEN evidence | Documentation / operational evidence |
|---|---|---|---|---|
| Fresh server exposes health and exactly three deterministic events; featured capability derives from `squadId`/`matchId` | `api/src/app.ts`, `api/test/workflow.test.ts`, Event model, Events screen | `npm test -- --test-name-pattern="fresh event summaries"` fails because routes/seed do not exist | Test passes and asserts exact count, order, fixed fields, featured relationships, and reduced secondary details | README API/run section; Events screenshot |
| Required malformed JSON and unknown match status fail closed as request failures | Dart model files and model tests | `flutter test test/models` fails on absent parsers, and later would fail if malformed values are accepted | Tests assert public `fromJson` throws `FormatException` for malformed JSON, wrong root type, missing/wrong required fields, invalid nullable fields, and unknown status; unspecified extra keys may be ignored | README notes strict typed parsing |
| Ready before check-in is rejected with safe `409 CHECK_IN_REQUIRED`; errors expose no internals | API app/workflow test; API client/controller/match screen | Workflow test fails because endpoint is absent | Exact status/code/message asserted through Fastify `inject()`; client displays safe message | Recorded pre-check-in disabled UI; README server-invariant decision |
| Check-in is atomic at the in-memory domain transition, idempotent, and returns updated Event plus Match with identical stations/original timestamp | API app/workflow test; client response/controller/detail and match screens | Check-in test fails before route; regression tests fail if one entity changes, station arrays differ, or repeated timestamp changes | One request mutates both resources before response; repeated POST returns equal stations/timestamp; controller replaces both caches from response | Checked-in screenshot and demo recording |
| Ready after check-in is idempotent and atomically returns authoritative Match plus Squad (`5/5`, `ready`, Cong ready) | API app/workflow test; controller and Squad/Match screens | End-to-end transition test fails before route; controller test fails before cache replacement | Fastify sequence asserts external response and subsequent GETs; controller test asserts both caches update without GET calls | Squad and Match screenshots; recording |
| Mutation failures preserve confirmed caches, do not mark GET state stale, and restore retryable CTA | Controller tests and screens | Controller tests fail before mutation logic | Fake API failure leaves object identity/data unchanged, mutation state exits loading, GET resource state unchanged, method returns false | Recording or manual checklist records failed CTA retry behavior |
| Every GET resource independently supports initial loading/fatal retry/refresh/stale retention/recovery | Request state/controller/widget/all screens and controller tests | Stale regression test fails because no controller exists | Test proves success → cached value → failed refresh retains exact value and sets only that resource error → successful retry clears notice | Recording proves API suspend, visible stale data, persistent Retry, resume, warning cleared |
| Match is viewable pre-check-in, readiness CTA disabled with explanation; post-ready CTA becomes non-interactive `Ready ✓` | Match screen plus controller/model | Widget behavior is manually RED until screen exists; no mandatory widget test under MUST | Manual emulator script verifies both states; controller/API tests establish data inputs | Recording and Match screenshot |
| Android emulator reaches host API over explicit development cleartext HTTP | `main.dart`, API client, Android manifest | Initial release smoke fails to load Events without manifest/base URL | Installed release APK launches and loads Events from `10.0.2.2:3000`; compile-time URL parses with `http`/`https` scheme and non-empty host | README explains `API_BASE_URL`, application-wide cleartext trade-off, and physical-device override |
| Product presentation satisfies four-screen flow, text labels, touch/contrast, non-color status, portrait target | Four screens, shared state widget, theme | Initial manual checklist fails while screens are absent | Guided acceptance run passes every numbered step on Pixel-sized portrait emulator | Four screenshots and 45–70 second recording |
| Project is statically valid, tested, release-buildable, and reproducible from README | All product files and README | Commands initially fail because projects do not exist | `flutter analyze`, `flutter test`, `npm run typecheck`, `npm test`, `flutter build apk --release`, install, launch, and Events request all pass | Execute every README command exactly; record command/results and release smoke date |

### Verification path and budget

The principal claim is that server-confirmed state remains coherent across API resources and four Flutter screens, including temporary transport failure. The preferred evidence path is: deterministic fresh server → Fastify public-boundary workflow test → strict model/controller tests → static checks → release APK → emulator acceptance run with process suspension/recovery → screenshots/recording. This path is repeatable because each `buildServer()` and API restart restores seed state.

The weaker fallback is debug-mode emulator testing; it cannot close the release-build claim. A stronger optional path is a physical Android smoke test, but it is a SHOULD item and does not replace emulator acceptance. No extra diagnostic product surface is needed: Fastify logs technical errors, the server restart is the reset affordance, and the persistent resource notice makes stale state directly observable.

Verification ownership during execution:

- API implementer owns API typecheck and Fastify tests.
- Flutter data/state implementer owns model/controller tests and `flutter analyze`.
- UI implementer owns the numbered emulator acceptance checklist and accessibility/presentation inspection.
- Release/evidence owner executes README commands verbatim, builds/installs the release APK, verifies a real Events request, and captures artifacts.

## Shared analysis

### Strategy and ordering

Establish the generated projects and shared contracts first. Then run three non-overlapping implementation lanes in parallel: Fastify backend, Flutter data/state, and Flutter UI. Reconcile those lanes before completing cross-cutting stale-data behavior. Finish with one integrated verification/release gate and then hiring evidence. This preserves the spec’s dependencies while avoiding parallel writers touching the same files.

### Architectural reasoning and trade-offs

- One explicit controller is sufficient for four screens and makes cross-screen cache replacement visible without introducing Provider/Riverpod. Pass the same instance through screen constructors and observe it with `ListenableBuilder`; do not instantiate controllers per screen or use animation-oriented `AnimatedBuilder` for ordinary state observation.
- Summary and detail Event caches remain separate because payload completeness differs; merging them risks erasing detail fields.
- Mutation responses include every changed entity so the client neither guesses server state nor refetches.
- In-memory server state makes reset and demo determinism cheap but deliberately provides no durability or multi-process consistency.
- Cleartext local HTTP is accepted only for this demo and must be documented as unsuitable for production. `android:usesCleartextTraffic="true"` permits cleartext application-wide, not only to `10.0.2.2`; a production/demo multi-variant app would require a scoped or demo-specific network policy.
- Handwritten strict parsers add small code volume but directly demonstrate Dart type-boundary discipline.

### Applicable preflight safeguards

- **Trust boundaries:** Validate route IDs through resource lookup, JSON response shapes in Dart, match status enum values, and environment-derived base URL URI construction. Current POSTs have no request bodies, so there is no body schema.
- **Server workflow invariants:** Fail closed for unknown resources and invalid transitions; never simulate success client-side.
- **Atomic changed entities:** In-memory check-in and ready handlers compute/commit all affected state synchronously before returning complete response objects. Tests assert both entities after each transition.
- **Safe errors:** API responses use only stable codes and safe messages; internal exceptions are logged and mapped to generic `500` responses. Flutter SnackBars never display raw exception/database details.
- **Meaningful tests:** Each test asserts observable parser, controller, or HTTP behavior and is RED before implementation. Fakes arrange failures but cached-state outcomes—not fake calls alone—are the behavior under test.
- Authentication, tenant/RLS, encryption/backfill, schema/deploy skew, clinical audit, providers, webhooks, queues, and uploads are not applicable because the spec explicitly excludes those systems.

### Risks and controls

- **15-hour cap:** Complete MUST slices only; do not spend time on SHOULD/OPTIONAL polish until a separately approved follow-up.
- **Flutter/Node setup drift:** Commit generated dependency lockfiles and record exact Flutter version/channel, Dart version, and SDK constraints before coding; do not let Android CLI become a runtime dependency.
- **Android tooling availability:** Treat Google Android CLI as optional tooling, not a runtime or MUST-path dependency. On Apple Silicon use the official `darwin_arm64` distribution. `android update` updates the CLI; `android init` installs its agent skill rather than initializing Flutter or the repository. Legacy `sdkmanager`, `avdmanager`, and `emulator` commands are deprecated operational fallbacks and are not feature-equivalent to Android CLI; `adb` remains a valid deployment fallback.
- **HTTP timeout semantics:** Apply `.timeout(const Duration(seconds: 5))` to every HTTP operation. This bounds how long QueueUp awaits a response but does not cancel the underlying request. Do not add automatic retry; user-triggered Retry remains authoritative.
- **Android target-SDK cleartext behavior:** Place `android.permission.INTERNET` as a `<uses-permission>` child of `<manifest>` and `android:usesCleartextTraffic="true"` on `<application>`. Inspect the generated target SDK: for API 38 or newer, use a development-only Network Security Configuration because the application attribute alone is ignored. Do not carry this demo policy into a production variant.
- **Cache inconsistency:** Centralize response replacement in controller methods and verify no refetch occurs after mutations.
- **Stale versus mutation errors:** Give each resource GET state and each mutation state distinct keys/fields; test that mutation failures do not set stale state.
- **UI overwork:** Use standard Material 3 components/transitions and the fixed theme; no custom animation/design system.
- **Demo reset:** Restart the API only for deterministic reset; suspend/resume the same process for stale-data demonstration.
- **Venue realism:** Before final copy, perform a quick web search of venue names; replace any real operator with an invented name without changing workflow.

### Open assumptions

- Stable Flutter, Android SDK/emulator, Node LTS, and npm are available or can be installed within normal setup time.
- The plan uses npm rather than another Node package manager because the required verification commands use npm.
- The current-player identity is fixed in seed state, as authentication is explicitly excluded.
- No README recording URL can be finalized until the video is hosted; use a real URL only when publishing evidence, never a placeholder in the completed artifact.

## Path comparison

### Simple path — selected

Create the API and Flutter app directly with the files and vertical slices below. Use only the API seam and small shared resource-state widget justified by tests/repeated screen behavior. This satisfies the task with the least setup and within the cap.

### Prefactor path — delta only

No prefactor is justified in a greenfield workspace. There is no existing structure to improve, and adding preparatory modules would consume the cap without reducing implementation risk. The prefactor path is therefore identical to the simple path and is not selected as a separate effort.

## Parallel execution graph

```text
Wave 1: Foundation and contract freeze (single owner)
    │
    ├──────────────┬──────────────────────┐
    ▼              ▼                      ▼
Wave 2A         Wave 2B                Wave 2C
Backend         Flutter core           Flutter UI
api/**          models/services/       screens/widgets/
                state/tests            visual main.dart
    │              │                      │
    └──────────────┴──────────────────────┘
                         ▼
Wave 3: Reconciliation and stale-data integration (single owner)
                         │
                         ▼
Wave 4: Automated, release, and emulator verification (single owner)
                         │
                         ▼
Wave 5: README, screenshots, and recording (single owner)
```

### Parallel ownership contract

| Lane | Allowed write scope | Validation owner | Dependencies / handoff |
|---|---|---|---|
| Wave 1 — Foundation | `.gitignore`, project manifests/configuration, generated `mobile/android/**`, initial `main.dart`, health-only API skeleton | Foundation owner runs health and emulator connectivity checks | Must finish before writer lanes begin; publishes exact Dart interfaces and JSON contracts from the spec |
| Wave 2A — Backend | `api/**` only | Backend owner runs API typecheck and all Fastify tests | May use only frozen JSON contracts; must not edit Flutter or docs |
| Wave 2B — Flutter core | `mobile/lib/models/**`, `mobile/lib/services/**`, `mobile/lib/state/**`, `mobile/lib/formatters.dart`, `mobile/test/**` | Flutter-core owner runs Flutter tests and analysis for owned files | Uses fake API for controller tests; must not edit screens/widgets/Android files |
| Wave 2C — Flutter UI | `mobile/lib/screens/**`, `mobile/lib/widgets/**`, and visual composition in `mobile/lib/main.dart` | UI owner runs Flutter analysis and manual widget/screen smoke checks | Starts after Wave 2B publishes compiling model/controller signatures; may continue while backend work runs; must not edit core files |
| Wave 3 — Integration | Flutter files only where needed to connect completed lanes and finish stale behavior | Integration owner runs all Flutter tests, analysis, and debug acceptance flow | Starts only after all Wave 2 writers stop and their results are reconciled |
| Wave 4 — Verification | Defect fixes are assigned back to the owning lane; otherwise no feature writes | Release owner runs complete automated/release/emulator evidence path | Requires integrated API and Flutter state |
| Wave 5 — Evidence | `README.md`, `docs/screenshots/**`; video hosted externally | Evidence owner executes README commands and validates artifacts | Screenshots/recording require Wave 4 green; README drafting may start after Wave 2 reconciliation |

Rules:

- Use isolated Git worktrees for Wave 2 writers if Git has been initialized; otherwise initialize Git after Wave 1 and create worktrees before dispatch.
- Never run two writers against the same working directory without the non-overlapping ownership above being enforced.
- Freeze these public contracts after Wave 1: Event/Player/Squad/Match fields, `MatchStatus`, `QueueUpApi` signatures, controller method signatures, mutation response shapes, and request-state semantics.
- Contract changes proposed by one lane pause only affected dependants; the integration owner approves and communicates the change before edits continue.
- Each lane returns changed-file inventory, commands run, results, and unresolved integration assumptions.
- Reconcile all Wave 2 changes before Wave 3. Run a conflict scan and compile/test the combined state rather than trusting lane-local results.
- Do not parallelize Wave 3, Wave 4, or final screenshot/recording capture because they operate on shared state or require one coherent build.

## Execution tasks

The tasks below remain acceptance-oriented checklists. During Wave 2, split each checklist by the ownership table rather than assigning a mixed task wholesale to one writer.

### Task 1 — Wave 1: Establish runnable Android/API skeleton and freeze contracts

**Files:** Create `.gitignore`, `api/package.json`, `api/tsconfig.json`, `api/src/app.ts`, `api/src/server.ts`; generate `mobile/`, then modify `mobile/pubspec.yaml`, `mobile/lib/main.dart`, and `mobile/android/app/src/main/AndroidManifest.xml`.

- [ ] Record `flutter --version` including channel, `dart --version`, `node --version`, `npm --version`, `java -version`, and `adb --version`; confirm stable Flutter and Node LTS, set matching Dart/Flutter SDK constraints, and retain generated lockfiles.
- [ ] If using Google Android CLI, install the official macOS Apple Silicon `darwin_arm64` distribution, run `android update`, then `android init`; record that the latter installs the Android CLI agent skill and does not initialize this Flutter project. Do not block the MUST path if the CLI is unavailable.
- [ ] Run `flutter create --platforms=android --org dev.queueup mobile`; expected: generated project exits 0 and `flutter run` can launch the template on an Android emulator.
- [ ] Configure API scripts exactly as `dev: tsx watch src/server.ts`, `typecheck: tsc --noEmit`, and `test: node --import tsx --test test/**/*.test.ts` with Fastify as runtime dependency and TypeScript/tsx/Node types as development dependencies.
- [ ] Write the first Fastify test asserting `GET /health` returns status 200 and `{ok: true}`; run `cd api && npm test`; expected RED: missing `buildServer()` or route.
- [ ] Implement `buildServer()` with the health route and `server.ts` listening on `0.0.0.0:3000`; rerun test; expected GREEN.
- [ ] Replace template Flutter UI with `ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.dark)`, `ThemeData(colorScheme: scheme, useMaterial3: true)`, `themeMode: ThemeMode.dark`, and composition-root placeholders sufficient to launch.
- [ ] Add `<uses-permission android:name="android.permission.INTERNET"/>` directly under `<manifest>` and `android:usesCleartextTraffic="true"` on `<application>`. Inspect `targetSdk`: if API 38 or newer, add and reference a development-only Network Security Configuration instead of relying on the ignored attribute. Define exactly `const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000')` using multiline Dart formatting. Treat it as compile-time configuration supplied by `--dart-define`, validate the resulting URI has `http` or `https` scheme and a non-empty host, and document that `10.0.2.2` is emulator-only.
- [ ] Start API, launch emulator app, and verify a direct health probe plus emulator-to-host connectivity before proceeding.
- [ ] Record the frozen JSON field tables, `QueueUpApi` methods, controller method signatures, `MatchStatus` values, and request-state rules in the Wave 2 handoff; all are copied directly from `spec(1).md` without invention.
- [ ] Initialize Git only if the implementation owner intends to version the artifact; inspect status and ensure the commit boundary above is respected.

### Task 2 — Wave 2A/2B: Implement deterministic Event API and strict Flutter models in parallel

**Files:** Modify `api/src/app.ts`; create `api/test/workflow.test.ts`, Event/Player/Squad/Match/API-response model files, `mobile/lib/formatters.dart`, and corresponding model tests.

- [ ] Write API RED tests for exactly three fixed summaries in order, featured relationships, secondary event absence of workflow IDs, featured detail, reduced secondary details, and `404` safe error shape.
- [ ] Run `cd api && npm test`; expected RED: event routes absent.
- [ ] Implement exact seed values and `GET /events`, `GET /events/:eventId`; derive featured capability only from non-null `squadId` and `matchId`.
- [ ] Rerun API tests; expected GREEN with exact fixed ISO timestamps and invented venue values.
- [ ] Write Dart RED tests for summary/detail Event parsing, nullable workflow fields, stations, missing/wrong required values, and unknown Match status.
- [ ] Run `cd mobile && flutter test test/models`; expected RED: model classes/parsers absent.
- [ ] Implement immutable models with explicit required-field type checks and `FormatException`; implement exhaustive `MatchStatus` parsing; add no `toJson`.
- [ ] Implement fixed English timestamp formatting with `intl` and station collapse (`[]`, one station, contiguous `B11–B15`, and non-contiguous fallback).
- [ ] Rerun model tests and `flutter analyze`; expected GREEN.

### Task 3 — Wave 2B/2C: Implement Event state and read-only UI with a signature handoff

**Files:** Create API interface/client, request state/controller, resource-state widget, Events screen, and Event Detail screen; modify `main.dart`.

- [ ] Write controller RED tests for initial Events success, initial failure returning false with no cache, and independent Event-detail cache entries.
- [ ] Run controller test file; expected RED: interface/controller absent.
- [ ] Implement `QueueUpApi` and `ApiClient` explicit GET methods with one injected `http.Client`, `.timeout(const Duration(seconds: 5))` on every operation, URI-safe IDs, expected-status/content-type checks, `jsonDecode`, root-shape validation, strict model parsing, and safe server-message parsing. Under `kDebugMode`, log only diagnostic failure type/context with `debugPrint`; never expose raw exceptions, bodies, stack traces, or server internals in UI.
- [ ] Make the composition root own and close the injected `http.Client` from its `dispose`; add no per-request clients and no automatic retry.
- [ ] Implement explicit controller caches/request states and `loadEvents`/`loadEvent`, distinguishing initial loading from refreshing and retaining cached values on failure.
- [ ] Rerun controller tests; expected GREEN.
- [ ] Implement Events initial load, pull-to-refresh, fatal Retry, exact three-card content, featured first/chips, and navigation. Observe the passed controller with `ListenableBuilder` and give the refreshable list `AlwaysScrollableScrollPhysics` so refresh remains available with short content.
- [ ] Implement detail first-load/refresh/error states; secondary details must omit check-in, Squad, and Match controls entirely.
- [ ] Manually verify reopening cached details renders immediately with no hidden request and each screen’s failure affects only its own state.

### Task 4 — Wave 2A/2B/2C: Add Squad API, state, and screen in owned files

**Files:** Modify API app/test, API client/controller; create `mobile/lib/screens/squad_screen.dart`.

- [ ] Add API RED tests asserting the featured Squad has exact name, five players, one current user, one captain, and initial `4/5` readiness.
- [ ] Run API tests; expected RED: Squad route absent.
- [ ] Implement `GET /squads/:squadId` and safe `404`; rerun tests; expected GREEN.
- [ ] Add controller RED tests for lazy Squad load, cache retention, and independent stale state; then implement `getSquad`/`loadSquad`; expected GREEN.
- [ ] Implement Squad screen with readiness count, five readable rows, text Captain/You chips, text readiness, pull-to-refresh, fatal Retry, and a state-driven persistent stale `MaterialBanner`. Use `AlwaysScrollableScrollPhysics` for short content.
- [ ] Verify Squad is accessible before check-in and shows `4 of 5 ready`.

### Task 5 — Wave 2A/2B/2C: Add idempotent check-in across owned files

**Files:** Modify API app/workflow test, API responses/client/controller, Event Detail and Match data presentation.

- [ ] Add RED API tests: first check-in returns Event+Match with `B11`–`B15` and non-null `checkedInAt`; second check-in returns unchanged stations and original timestamp; subsequent GETs agree.
- [ ] Run API tests; expected RED: check-in route absent.
- [ ] Implement synchronous in-memory transition in `POST /events/:eventId/check-in`; unknown Event/related Match fails closed without partial mutation.
- [ ] Rerun API tests; expected GREEN.
- [ ] Add controller RED tests asserting successful check-in replaces detail Event and Match caches from the response without GET calls; failure preserves both caches and GET request states.
- [ ] Implement strict `CheckInResponse`, client POST without body, separate mutation state, boolean result, and listener notifications; rerun tests; expected GREEN.
- [ ] Implement Event-detail pending disabled CTA/progress, safe SnackBar failure, and confirmed non-interactive `Checked in` / `Stations B11–B15` state.
- [ ] Verify repeat tapping after success is impossible in UI and repeat HTTP requests remain server-idempotent.

### Task 6 — Wave 2A/2B/2C: Add Match readiness across owned files

**Files:** Modify API app/workflow test, API client/controller; create/complete Match screen; update Squad screen observation.

- [ ] Extend the mandatory Fastify RED sequence: ready before check-in → exact safe 409; check-in → 200; ready → 200 with `5/5`, `ready`, Cong ready; repeat ready → unchanged 200; later GETs agree.
- [ ] Add RED cases for unknown Match and prohibited `in_progress`/`complete` transitions without state mutation.
- [ ] Run API tests; expected RED: Match/ready routes absent.
- [ ] Implement `GET /matches/:matchId` and ordered ready logic exactly as specified; recalculate readiness from authoritative players and update Match+Squad synchronously.
- [ ] Rerun API tests; expected GREEN.
- [ ] Add controller RED tests proving `markReady` replaces Match and Squad caches without refetch, failure preserves both, and unrelated GET state is unchanged.
- [ ] Implement strict `ReadyResponse`, client POST without body, controller mutation handling, and notifications; expected controller tests GREEN.
- [ ] Implement Match information, pre-check-in disabled CTA/explanation, pending progress, safe failure SnackBar, and post-ready non-interactive `Ready ✓`.
- [ ] Navigate back to Squad without refetch and verify Cong/`5 of 5 ready` update from the shared controller.

### Task 7 — Wave 3: Reconcile lanes and complete stale-data recovery

**Files:** Modify controller/request-state/widget and all four screens; expand controller tests.

- [ ] Stop all Wave 2 writers, inventory their changed files, merge/reconcile their work, and resolve contract mismatches before further edits.
- [ ] Run `cd api && npm run typecheck && npm test` and `cd ../mobile && flutter analyze && flutter test`; expected: combined baseline passes before stale integration proceeds.
- [ ] Write the mandatory controller RED regression: successful load caches value; refresh failure returns false, retains exact prior data, marks only that resource error/stale; successful retry clears only that warning.
- [ ] Add RED coverage for Events, Event detail, Squad, and Match resource-key independence and refresh-vs-initial loading.
- [ ] Run controller tests; expected RED for any incomplete transitions.
- [ ] Implement the minimum explicit transition logic needed to pass; do not introduce generic cache/Result abstractions.
- [ ] Rerun all Flutter tests; expected GREEN.
- [ ] Ensure each screen uses `RefreshIndicator` whose `onRefresh` awaits the resource load, `AlwaysScrollableScrollPhysics`, and controller-owned cache retention. Render a state-driven non-dismissible `MaterialBanner` directly below the AppBar with exact conservative copy and resource-specific Retry; never call `ScaffoldMessenger.showMaterialBanner` from `build` and never use a SnackBar for stale GET state.
- [ ] Ensure uncached failures retain AppBar/navigation chrome and show centered generic error plus Retry; mutation failures must never trigger stale banners.
- [ ] Suspend the same foreground API process, refresh each previously loaded screen, resume it, press Retry, and verify warning removal with confirmed mutation state intact.

### Task 8 — Wave 4: Run complete automated and release verification

**Files:** Modify only defects directly revealed by verification.

- [ ] Run `cd mobile && flutter analyze`; expected: no issues.
- [ ] Run `cd mobile && flutter test`; expected: all tests pass, including parsing and stale-data regression.
- [ ] Run `cd api && npm run typecheck`; expected: exit 0 with no TypeScript errors.
- [ ] Run `cd api && npm test`; expected: all public-boundary workflow/invariant tests pass.
- [ ] Run `cd mobile && flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:3000`; expected: unsplit release APK at `build/app/outputs/flutter-apk/app-release.apk`.
- [ ] Run `test -f build/app/outputs/flutter-apk/app-release.apk`, `adb devices -l`, and confirm one target emulator. Verify the generated `applicationId` in `android/app/build.gradle.kts` (or `.gradle`); with the planned `--org dev.queueup` generation it should be `dev.queueup.mobile`.
- [ ] Start fresh API and deploy the generated APK. Preferred optional Android CLI command from `mobile/`: `android run --apks=build/app/outputs/flutter-apk/app-release.apk`. Fallback: `adb -e install -r build/app/outputs/flutter-apk/app-release.apk`, then `adb -e shell am start -W -n dev.queueup.mobile/.MainActivity` after confirming that generated application ID. Verify both successful launch and a real `/events` request in API logs/UI. Android CLI deploys an existing APK and never replaces `flutter build apk`.
- [ ] Execute the complete 17-step acceptance demo from the spec, including process suspension/recovery; record pass/fail against every step.
- [ ] Inspect status labels for text/icon redundancy, touch targets, Material contrast, portrait overflow, and back navigation.

### Task 9 — Wave 5: Write reproducible case study and capture evidence

**Files:** Create/modify `README.md`, four `docs/screenshots/*.png`; host but do not commit video.

- [ ] Write concise problem/context, Flutter mobile rationale, exact setup/run/test/release commands, required ASCII architecture diagram, decisions, exclusions, production changes, cleartext trade-off, API override, and reset/suspend demo procedure.
- [ ] Do not publish an implementation-hour claim. Mention AI assistance only if policy requires it, and never call this commercial Flutter experience.
- [ ] Execute every README command exactly as written from a clean practical starting point; correct documentation rather than relying on undocumented steps.
- [ ] Reset API and capture Events screenshot; perform check-in and capture checked-in detail; mark ready and capture Squad and Match screenshots on a standard Pixel portrait emulator.
- [ ] Embed all four screenshots in README.
- [ ] Record 45–70 seconds covering happy path, API unreachability, preserved cached data, persistent Retry, process recovery, successful Retry, and warning removal.
- [ ] Host/link the recording without adding the video file to Git.
- [ ] Perform final `git status --short`; confirm no APK, video, `.agents/`, `.opencode/`, `docs/superpowers/`, agent transcript, or other Superpowers-related artifact is staged.

## Final completion gate

- [ ] Every MUST checkbox in Section 21 of `spec(1).md` has direct passing evidence.
- [ ] The parsing test is present unless it was explicitly cut only after the documented cap threshold; stale/controller and Fastify integration tests are never cut.
- [ ] Automated checks and release build pass on the final source state.
- [ ] Release APK installs, launches, and loads Events from the real API.
- [ ] README commands were executed verbatim and remain accurate.
- [ ] Four screenshots and the linked recording prove the required states.
- [ ] No SHOULD/OPTIONAL scope was added before MUST completion.
- [ ] No Superpowers-related files or artifacts are committed.

Stop after this gate. Any SHOULD or OPTIONAL work requires a separate explicit selection against remaining time.
