# Implementation Plan: WizTree for Mac (MacTree)

**Branch**: `001-disk-usage-viz` | **Date**: 2025-12-18 | **Spec**: `specs/001-disk-usage-viz/spec.md`
**Input**: Feature specification from `specs/001-disk-usage-viz/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Build a macOS desktop app that scans a selected folder/volume and visualizes storage usage (tree table + treemap) with live, incremental results. The UI is a vanilla HTML/CSS/JS app hosted in a WKWebView, backed by a small native scanning/aggregation/persistence layer using SQLite for caching and instant reload.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Swift 5.9+  
**Primary Dependencies**: None (Apple frameworks only: AppKit/SwiftUI, WebKit, SQLite3)  
**Storage**: SQLite (local-only) in Application Support  
**Testing**: XCTest (logic-level tests for scanner/aggregator/treemap layout)  
**Target Platform**: macOS 13+ (WKWebView + modern concurrency)
**Project Type**: Desktop app (native container + embedded web UI)  
**Performance Goals**: First partial results <1s; scan throughput ≥10k entries/sec on local SSD; UI remains interactive (inputs <100ms)  
**Constraints**: No network calls; incremental scanning/aggregation; cancellation; stable size totals; minimal dependencies; handle permission errors  
**Scale/Scope**: 100k–1M filesystem entries in a single scan; progressive rendering and virtualization required

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Gates derived from `.specify/memory/constitution.md`:

1. **Performance first**: scanning/aggregation is incremental and runs off the main thread; UI is never blocked; updates are throttled and batched.
2. **Local-only & private**: no network access; all cache stored locally in Application Support; no telemetry.
3. **Simple, predictable UX**: macOS-standard folder picker; obvious scan/progress/cancel; selection sync between table and treemap.
4. **Minimal dependencies**: vanilla HTML/CSS/JS in WKWebView; SQLite3 via system library; avoid third-party frameworks.
5. **Correctness over features**: size calculations are consistent and stable; permission errors handled without corrupting aggregates; deterministic aggregation.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
app/
├── Package.swift
├── Sources/
│   └── MacTreeApp/
│       ├── AppDelegate.swift
│       ├── MainWindowController.swift
│       ├── WebViewBridge.swift
│       ├── Scanning/
│       │   ├── Scanner.swift
│       │   ├── ScanProgress.swift
│       │   └── ScanCancellationToken.swift
│       ├── Model/
│       │   ├── FileEntry.swift
│       │   ├── DirAggregate.swift
│       │   └── ScanSession.swift
│       ├── Aggregation/
│       │   └── Aggregator.swift
│       ├── Persistence/
│       │   ├── SQLiteDatabase.swift
│       │   ├── Migrations.swift
│       │   └── Repositories.swift
│       └── System/
│           └── FinderReveal.swift
├── Resources/
│   ├── Web/
│   │   ├── index.html
│   │   ├── styles.css
│   │   └── app.js
│   └── Database/
│       └── migrations.sql
└── Scripts/
  ├── dev-run.sh
  └── package-app.sh

tests/
└── MacTreeTests/
  ├── ScannerTests.swift
  ├── AggregatorTests.swift
  ├── TreemapLayoutTests.swift
  └── PersistenceTests.swift
```

**Structure Decision**: Use a single macOS app package with embedded web UI (WKWebView) to satisfy minimal-dependency UI requirements while keeping filesystem access, SQLite persistence, and Finder integration native.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
