-- MacTree SQLite Schema
-- Version 1

PRAGMA foreign_keys = ON;

-- Schema version tracking
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO schema_version (version) VALUES (1);

-- Scan sessions
CREATE TABLE IF NOT EXISTS scan_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    root_path TEXT NOT NULL,
    volume_id TEXT,
    started_at TEXT NOT NULL,
    finished_at TEXT,
    status TEXT NOT NULL CHECK(status IN ('running', 'completed', 'cancelled', 'error')),
    total_items INTEGER DEFAULT 0,
    total_size INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0
);

CREATE INDEX idx_sessions_root ON scan_sessions(root_path);
CREATE INDEX idx_sessions_started ON scan_sessions(started_at DESC);

-- File entries (both files and directories)
CREATE TABLE IF NOT EXISTS file_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    path TEXT NOT NULL,
    name TEXT NOT NULL,
    parent_path TEXT,
    type TEXT NOT NULL CHECK(type IN ('file', 'directory', 'symlink')),
    size INTEGER NOT NULL DEFAULT 0,
    mtime TEXT,
    extension TEXT,
    FOREIGN KEY (session_id) REFERENCES scan_sessions(id) ON DELETE CASCADE
);

CREATE INDEX idx_entries_session ON file_entries(session_id);
CREATE INDEX idx_entries_path ON file_entries(path);
CREATE INDEX idx_entries_parent ON file_entries(parent_path);
CREATE INDEX idx_entries_type ON file_entries(type);
CREATE INDEX idx_entries_size ON file_entries(size DESC);

-- Directory aggregates (computed totals)
CREATE TABLE IF NOT EXISTS dir_aggregates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    path TEXT NOT NULL,
    total_size INTEGER NOT NULL DEFAULT 0,
    file_count INTEGER NOT NULL DEFAULT 0,
    dir_count INTEGER NOT NULL DEFAULT 0,
    depth INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (session_id) REFERENCES scan_sessions(id) ON DELETE CASCADE,
    UNIQUE(session_id, path)
);

CREATE INDEX idx_aggregates_session ON dir_aggregates(session_id);
CREATE INDEX idx_aggregates_path ON dir_aggregates(path);
CREATE INDEX idx_aggregates_size ON dir_aggregates(total_size DESC);

-- Scan errors
CREATE TABLE IF NOT EXISTS scan_errors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    path TEXT NOT NULL,
    error_code INTEGER,
    error_message TEXT NOT NULL,
    occurred_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id) REFERENCES scan_sessions(id) ON DELETE CASCADE
);

CREATE INDEX idx_errors_session ON scan_errors(session_id);

-- Last scan pointer (for quick "load last scan" on app launch)
CREATE TABLE IF NOT EXISTS app_state (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO app_state (key, value) VALUES ('last_session_id', '0');
