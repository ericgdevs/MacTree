# Feature Specification: WizTree for Mac (MacTree)

**Feature Branch**: `001-disk-usage-viz`  
**Created**: 2025-12-18  
**Status**: Draft  
**Input**: User description: "A macOS desktop application that scans a selected disk/folder and visualizes storage usage like WizTree: tree table + treemap, with fast search/filter, sorting, and local-only caching."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Select & Scan with Live Results (Priority: P1)

As a user, I select a volume/folder and scanning begins immediately, showing progress and partial results live in both the folder table and treemap without freezing.

**Why this priority**: This is the core workflow; everything else builds on having a fast, trustworthy scan with immediate feedback.

**Independent Test**: Choose a folder with thousands of files, start scan, and verify progress updates, live partial results, and continued UI responsiveness (scroll, click, search focus) while scanning.

**Acceptance Scenarios**:

1. **Given** the app is open, **When** I select a folder/volume, **Then** scanning starts immediately and a progress indicator appears
2. **Given** a scan is running, **When** items are discovered, **Then** the table and treemap update incrementally without blocking the UI
3. **Given** the scan encounters unreadable paths, **When** permission errors occur, **Then** the scan continues and an error summary is available
4. **Given** I press cancel during a scan, **When** cancellation is requested, **Then** scanning stops quickly and partial results remain available

---

### User Story 2 - Drill Down with Synced Table + Treemap (Priority: P2)

As a user, I click folders to drill down, and the table and treemap stay in sync so I can understand where space is going.

**Why this priority**: Exploration is the primary way users use storage visualizers; synchronization makes navigation obvious and fast.

**Independent Test**: After a scan, click items in the table and treemap and verify the other view highlights/focuses the corresponding item and the visible scope updates.

**Acceptance Scenarios**:

1. **Given** scan results are visible, **When** I click a folder in the table, **Then** the treemap focuses on that folder’s contents
2. **Given** scan results are visible, **When** I click a tile in the treemap, **Then** the table selects and reveals that item
3. **Given** I am drilled into a subfolder, **When** I navigate to a parent (breadcrumb/back), **Then** both views update consistently

---

### User Story 3 - Search/Filter Large Results Fast (Priority: P3)

As a user, I search/filter by path/name/extension and optionally filter by a minimum size threshold (e.g., “show only > X MB”) to quickly find large files/folders.

**Why this priority**: Users often know what they’re looking for (e.g., “.mp4”, “node_modules”). Fast filtering is a key WizTree-like behavior.

**Independent Test**: With a scan result containing tens of thousands of items, type into search and verify filtering updates quickly and does not lag.

**Acceptance Scenarios**:

1. **Given** results are shown, **When** I type into search, **Then** visible results filter within 100ms per keystroke
2. **Given** a filter is active, **When** I clear search, **Then** the full result set view returns immediately
3. **Given** results are shown, **When** I set a minimum size threshold, **Then** the table and treemap show only items whose size is ≥ the threshold

---

### User Story 4 - Sort the Table by Size/Count/Name (Priority: P4)

As a user, I sort by size, count, or name so I can quickly identify top offenders.

**Why this priority**: Sorting is essential for “find the biggest folders/files” workflows.

**Independent Test**: Click Size / Count / Name headers and verify correct ordering (numerical vs lexical) and direction toggling.

**Acceptance Scenarios**:

1. **Given** the table is visible, **When** I click the Size column, **Then** rows sort by size descending; clicking again sorts ascending
2. **Given** the table is visible, **When** I click Item Count, **Then** rows sort numerically by count

---

### User Story 5 - Reveal in Finder & Rescan (Priority: P5)

As a user, I can reveal an item in Finder and rescan to refresh results.

**Why this priority**: V1 explicitly avoids deletion workflows; Reveal-in-Finder is the safe action bridge. Rescan keeps results accurate.

**Independent Test**: Right-click an item and reveal it in Finder; create/delete a large file and rescan to verify updated totals.

**Acceptance Scenarios**:

1. **Given** an item is selected, **When** I choose “Reveal in Finder”, **Then** Finder opens with that item selected
2. **Given** I click “Rescan”, **When** the scan reruns, **Then** totals update and UI remains responsive

---

### Edge Cases

- Permission denied / Full Disk Access not granted: scan continues where possible; show summary of inaccessible paths
- Symlinks: avoid infinite loops; treat symlink as leaf by default (do not follow targets)
- Very deep folder trees: avoid recursion depth crashes; iterative traversal
- Huge directories (100k+ entries): incremental batching; UI virtualizes long lists
- Files changing during scan: results represent point-in-time reads; allow rescan to reconcile

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow selecting a volume or folder to scan
- **FR-002**: System MUST start scanning immediately after selection
- **FR-003**: System MUST stream results incrementally and never block the UI
- **FR-004**: System MUST support canceling an in-progress scan
- **FR-005**: System MUST build and display a folder tree table: name, size, % of parent/total, item count
- **FR-006**: System MUST render a treemap sized by bytes and keep it in sync with the table selection
- **FR-007**: System MUST support sorting by size, count, and name
- **FR-008**: System MUST support fast search/filter by path/name/extension
- **FR-008a**: System MUST support an optional “minimum size” filter (e.g., show only items ≥ X MB)
- **FR-009**: System MUST handle permission errors gracefully and surface them to the user
- **FR-010**: System MUST provide “Reveal in Finder” and “Rescan” actions
- **FR-011**: System MUST keep all data local (no uploads, no telemetry, no network calls)
- **FR-012**: System MUST cache scan results locally so reopening the app is instant

### Key Entities *(include if feature involves data)*

- **ScanSession**: Root path/volume, timestamps, completion state, error summary
- **FileEntry**: Path, type (file/dir/symlink), size, mtime (optional), extension
- **DirAggregate**: Path, total_size, file_count, dir_count
- **UIState**: Current focus path, selection, sort, filter, view mode

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: First visible results appear within 1 second for folders with ≥1,000 entries
- **SC-002**: UI remains responsive during scanning (interactions respond within 100ms)
- **SC-003**: Search/filter updates within 100ms per keystroke for 100k items
- **SC-004**: Size results are stable and consistent across rescans (no unexplained oscillation)
- **SC-005**: No network requests are made during normal operation
