---

description: "Task list for implementing WizTree for Mac (MacTree)"
---

# Tasks: WizTree for Mac (MacTree)

**Input**: Design documents from `specs/001-disk-usage-viz/`  
**Prerequisites**: `specs/001-disk-usage-viz/plan.md` (required), `specs/001-disk-usage-viz/spec.md` (required)

**Tests**: Not requested as TDD-only; add tests where they de-risk correctness/perf.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[TaskID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[US#]**: Which user story this task belongs to (US1..US5)
- Each task includes exact file path(s)

---

## Phase 1: Setup (Shared Infrastructure) — Milestone 1

**Purpose**: Create the macOS app skeleton (native container + vanilla web UI shell) and a runnable dev loop.

- [X] T001 Create feature source skeleton directories: app/, tests/, docs/ in app/, tests/, docs/
- [X] T002 Initialize SwiftPM package for app in app/Package.swift
- [X] T003 [P] Add macOS app entrypoint and window bootstrap in app/Sources/MacTreeApp/main.swift
- [X] T004 [P] Add AppDelegate + window controller scaffolding in app/Sources/MacTreeApp/AppDelegate.swift and app/Sources/MacTreeApp/MainWindowController.swift
- [X] T005 [P] Add WKWebView hosting + navigation policy (disallow remote loads) in app/Sources/MacTreeApp/WebViewBridge.swift
- [X] T006 [P] Create vanilla UI shell files (tree pane + treemap pane + top bar placeholders) in app/Resources/Web/index.html, app/Resources/Web/styles.css, app/Resources/Web/app.js
- [X] T007 Add dev-run script to launch app locally in app/Scripts/dev-run.sh
- [X] T008 Add basic logging helper (stdout only, no telemetry) in app/Sources/MacTreeApp/System/Logging.swift

**Checkpoint**: App launches; WKWebView renders the UI shell.

---

## Phase 2: Foundational (Blocking Prerequisites) — Milestones 1–2

**Purpose**: Scanner + incremental aggregation + SQLite persistence + load-last-scan plumbing.

### Persistence foundations

- [X] T009 Define SQLite schema (sessions, file_entries, dir_aggregates) in app/Resources/Database/migrations.sql
- [X] T010 Implement SQLite connection wrapper (open/create, pragmas, statements) in app/Sources/MacTreeApp/Persistence/SQLiteDatabase.swift
- [X] T011 Implement migration runner + schema version tracking in app/Sources/MacTreeApp/Persistence/Migrations.swift
- [X] T012 [P] Implement repositories for sessions and entries in app/Sources/MacTreeApp/Persistence/Repositories.swift
- [X] T013 Add Application Support path resolution for DB location in app/Sources/MacTreeApp/Persistence/AppSupportPaths.swift

### Core domain model

- [X] T014 [P] Define ScanSession model in app/Sources/MacTreeApp/Model/ScanSession.swift
- [X] T015 [P] Define FileEntry model (file/dir/symlink) in app/Sources/MacTreeApp/Model/FileEntry.swift
- [X] T016 [P] Define DirAggregate model in app/Sources/MacTreeApp/Model/DirAggregate.swift
- [X] T017 [P] Define ScanProgress and error record types in app/Sources/MacTreeApp/Scanning/ScanProgress.swift

### Scanner prototype (CLI-like in logs)

- [X] T018 Implement cancellation token and cooperative checks in app/Sources/MacTreeApp/Scanning/ScanCancellationToken.swift
- [X] T019 Implement iterative filesystem traversal that emits FileEntry batches in app/Sources/MacTreeApp/Scanning/Scanner.swift
- [X] T020 Implement symlink policy (do not follow; avoid loops) in app/Sources/MacTreeApp/Scanning/Scanner.swift
- [X] T021 Implement permission-error handling (continue, record errors) in app/Sources/MacTreeApp/Scanning/Scanner.swift
- [X] T022 Implement throttled progress/batch emission (N files or X ms) in app/Sources/MacTreeApp/Scanning/Scanner.swift
- [X] T023 Wire scanner prototype to print stats to logs (no UI yet) in app/Sources/MacTreeApp/AppDelegate.swift

### Incremental aggregation

- [ ] T024 Implement incremental aggregator that updates DirAggregate on each FileEntry batch in app/Sources/MacTreeApp/Aggregation/Aggregator.swift
- [ ] T025 Ensure aggregator is stable/deterministic across batch sizes in app/Sources/MacTreeApp/Aggregation/Aggregator.swift

### Persistence of scan results

- [ ] T026 Persist ScanSession lifecycle (start/finish/cancel) in app/Sources/MacTreeApp/Persistence/Repositories.swift
- [ ] T027 Persist FileEntry batches efficiently (prepared statements, transaction per batch) in app/Sources/MacTreeApp/Persistence/Repositories.swift
- [ ] T028 Persist DirAggregate updates efficiently (upsert) in app/Sources/MacTreeApp/Persistence/Repositories.swift

### Load last scan into memory

- [ ] T029 Implement “load last scan” query and in-memory reconstruction in app/Sources/MacTreeApp/Persistence/Repositories.swift
- [ ] T030 Define in-memory view model for current dataset (tree + aggregates) in app/Sources/MacTreeApp/Model/ScanDataset.swift
- [ ] T031 Populate ScanDataset from SQLite on app launch in app/Sources/MacTreeApp/AppDelegate.swift

**Checkpoint**: Scanner runs with cancellation; SQLite contains sessions/entries/aggregates; app can load last scan at startup.

---

## Phase 3: User Story 1 — Select & Scan with Live Results (Priority: P1) 🎯 MVP

**Goal**: Select folder/volume, start scan immediately, show progress + partial results without freezing.

**Independent Test**: Select a folder with thousands of items; see progress update continuously; partial tree rows and treemap tiles appear during scan; cancel stops quickly.

- [ ] T032 [US1] Add folder/volume selection UI (macOS open panel) handler in app/Sources/MacTreeApp/WebViewBridge.swift
- [ ] T033 [US1] Define JS↔native message protocol for scan commands/events in app/Sources/MacTreeApp/WebViewBridge.swift and app/Resources/Web/app.js
- [ ] T034 [US1] Implement scan start/cancel wiring from UI to Scanner in app/Sources/MacTreeApp/WebViewBridge.swift
- [ ] T035 [US1] Stream incremental progress events to UI (throttled) in app/Sources/MacTreeApp/WebViewBridge.swift
- [ ] T036 [US1] Stream incremental result deltas (tree + treemap data chunks) to UI in app/Sources/MacTreeApp/WebViewBridge.swift
- [ ] T037 [US1] Render progressive tree rows (basic, non-virtualized placeholder) in app/Resources/Web/app.js
- [ ] T038 [US1] Render progressive treemap tiles (basic placeholder rectangles) in app/Resources/Web/app.js
- [ ] T039 [US1] Ensure UI never blocks: batch DOM updates via requestAnimationFrame in app/Resources/Web/app.js
- [ ] T040 [US1] Implement cancel button + state handling in app/Resources/Web/index.html and app/Resources/Web/app.js

**Checkpoint**: MVP scan with live progress and partial results is usable.

---

## Phase 4: User Story 2 — Drill Down with Synced Table + Treemap (Priority: P2)

**Goal**: Click in table/treemap to focus; both views remain synchronized.

**Independent Test**: After/during scan, click a folder in table → treemap focuses; click a treemap tile → table selects/reveals.

- [ ] T041 [US2] Add selection/focus state management in app/Resources/Web/app.js
- [ ] T042 [US2] Implement breadcrumb/back UI for focused path in app/Resources/Web/index.html and app/Resources/Web/app.js
- [ ] T043 [US2] Implement table row click → focus path event in app/Resources/Web/app.js
- [ ] T044 [US2] Implement treemap tile click → select/focus event in app/Resources/Web/app.js
- [ ] T045 [US2] Implement native-side “focus path” query to return children + aggregates in app/Sources/MacTreeApp/WebViewBridge.swift
- [ ] T046 [US2] Ensure focus changes do not require full re-render (diff updates) in app/Resources/Web/app.js

---

## Phase 5: User Story 3 — Search/Filter Large Results Fast (Priority: P3)

**Goal**: Fast filter by name/path/extension and optional minimum size threshold; affects both table and treemap.

**Independent Test**: With a large dataset, type in search and adjust “min size” and verify updates within ~100ms/interaction.

- [ ] T047 [US3] Add search input + min-size control to UI in app/Resources/Web/index.html and app/Resources/Web/app.js
- [ ] T048 [US3] Implement client-side filter pipeline (text + extension + min-size) in app/Resources/Web/app.js
- [ ] T049 [US3] Add debounced filtering and incremental rendering for filtered results in app/Resources/Web/app.js
- [ ] T050 [US3] Add native-side optional filtered query for very large datasets (fallback) in app/Sources/MacTreeApp/WebViewBridge.swift
- [ ] T051 [US3] Ensure filter applies consistently to treemap layout input data in app/Resources/Web/app.js

---

## Phase 6: User Story 4 — Sort the Table by Size/Count/Name (Priority: P4)

**Goal**: Sort table by size/count/name; correct numeric vs lexical ordering; stable sorts.

**Independent Test**: Click headers and verify ordering and toggling direction.

- [ ] T052 [US4] Add sortable column headers UI in app/Resources/Web/index.html
- [ ] T053 [US4] Implement stable sort functions (name/size/count) in app/Resources/Web/app.js
- [ ] T054 [US4] Ensure sort works with focus/drill-down scope and filters combined in app/Resources/Web/app.js

---

## Phase 7: User Story 5 — Reveal in Finder & Rescan (Priority: P5)

**Goal**: Reveal selected item in Finder; rescan current root; preserve view state.

**Independent Test**: Reveal works for file/folder; rescan updates totals without losing sort/filter/focus.

- [ ] T055 [P] [US5] Implement Finder reveal helper in app/Sources/MacTreeApp/System/FinderReveal.swift
- [ ] T056 [US5] Add context menu / button for “Reveal in Finder” in app/Resources/Web/index.html and app/Resources/Web/app.js
- [ ] T057 [US5] Wire reveal action to native bridge with path validation in app/Sources/MacTreeApp/WebViewBridge.swift
- [ ] T058 [US5] Implement rescan action (restart scan for same root) in app/Sources/MacTreeApp/WebViewBridge.swift
- [ ] T059 [US5] Preserve UI state across rescan (focus/sort/filter) in app/Resources/Web/app.js
- [ ] T060 [US5] Update SQLite session history and “last scan” pointer on rescan in app/Sources/MacTreeApp/Persistence/Repositories.swift

---

## Phase 8: Polish & Cross-Cutting Concerns — Milestone 4

**Purpose**: Robust errors, performance hardening, packaging, docs.

### Error handling (permissions, broken symlinks, unreadable volumes)

- [ ] T061 Add user-visible error summary panel in app/Resources/Web/index.html and app/Resources/Web/app.js
- [ ] T062 Ensure scanner records structured errors (path, errno, message) in app/Sources/MacTreeApp/Scanning/ScanProgress.swift
- [ ] T063 Show non-fatal permission errors without interrupting scan in app/Sources/MacTreeApp/WebViewBridge.swift

### Treemap correctness & UX

- [ ] T064 Implement squarified treemap layout algorithm in app/Resources/Web/treemap.js
- [ ] T065 Integrate treemap layout with incremental updates and filtering in app/Resources/Web/app.js
- [ ] T066 Add hover tooltip (path + size + %) in app/Resources/Web/app.js and app/Resources/Web/styles.css

### Tree table performance

- [ ] T067 Implement virtualized table rendering for huge lists in app/Resources/Web/virtual-list.js
- [ ] T068 Integrate virtualization with sorting/filtering/focus in app/Resources/Web/app.js

### Performance + stress checks

- [ ] T069 Add a manual perf checklist and stress scenarios in specs/001-disk-usage-viz/quickstart.md
- [ ] T070 Add lightweight benchmark harness for scanner throughput logging in app/Sources/MacTreeApp/Scanning/ScannerBenchmark.swift

### Packaging + README

- [ ] T071 Add packaging script to produce a .app bundle (local signing optional) in app/Scripts/package-app.sh
- [ ] T072 Create basic README with build/run instructions and privacy statement in README.md

### Optional v1.1 note (do not implement in v1)

- [ ] T073 Document optional “compare timestamps for incremental update” approach for v1.1 in specs/001-disk-usage-viz/research.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)** → blocks all other work until app/UI shell runs
- **Phase 2 (Foundational)** → blocks all user stories
- **Phase 3 (US1 / MVP)** → must complete before US2–US5 are meaningfully testable
- **US2–US5** can proceed in parallel after US1, sharing the same data model and bridge
- **Polish** depends on the user stories you choose to ship

### User Story Dependencies (Graph)

- Foundations → US1
- US1 → US2
- US1 → US3
- US1 → US4
- US1 → US5

---

## Parallel Execution Examples

### After Phase 2 completes

- US2 (T041–T046) and US4 (T052–T054) can run in parallel (mostly UI-only files)
- US3 (T047–T051) can run in parallel with US2 (different UI modules)
- US5 T055 can run in parallel with UI tasks (native-only)

### US1 (P1)

- In parallel: T032 (folder picker wiring) + T033 (bridge protocol) + T037/T038 (initial renderers)
- Then: T034–T036 (wiring + streaming) while iterating on T039/T040 (UI smoothness + cancel)

### US2 (P2)

- In parallel: T041 (state) + T042 (breadcrumbs) + T045 (native focus query)
- Then: T043/T044 (click handlers) + T046 (diff updates)

### US3 (P3)

- In parallel: T047 (UI controls) + T048 (filter pipeline)
- Then: T049 (debounce/render strategy) + T051 (treemap consistency) while implementing T050 (native fallback)

### US4 (P4)

- In parallel: T052 (headers UI) + T053 (sort functions)
- Then: T054 (compose with focus + filters)

### US5 (P5)

- In parallel: T055 (native Finder reveal helper) + T056 (UI affordance)
- Then: T057 (bridge wiring) while implementing T058–T060 (rescan + persistence)

---

## Implementation Strategy

### MVP (Recommended scope)

- Phase 1 + Phase 2 + US1 only (T001–T040)

### Incremental delivery

- Ship US1 first, then add US2/US3/US4/US5 in priority order (or parallel), then polish.

---

## Task Count Summary (for quick tracking)

- Setup + Foundational: T001–T031 (31 tasks)
- US1: T032–T040 (9 tasks)
- US2: T041–T046 (6 tasks)
- US3: T047–T051 (5 tasks)
- US4: T052–T054 (3 tasks)
- US5: T055–T060 (6 tasks)
- Polish: T061–T073 (13 tasks)

Total: 73 tasks
