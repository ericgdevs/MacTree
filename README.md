# MacTree

A native macOS desktop application that visualizes disk usage with blazing-fast scanning and an intuitive interface inspired by WizTree. MacTree combines a hierarchical folder table with an interactive treemap to help you quickly identify what's consuming your storage.

## Features

- **Fast Scanning**: Rapidly scan any volume or folder with live progress updates
- **Dual Visualization**: 
  - Hierarchical tree table showing folders and files with size/percentage
  - Interactive treemap for visual representation of space usage
- **Live Results**: See partial results as scanning progresses without UI freezing
- **Synchronized Views**: Click items in the table or treemap to drill down, with both views staying in sync
- **Powerful Search & Filter**: 
  - Fast search by filename, path, or extension
  - Filter by minimum file size to find space hogs
  - Real-time filtering across large datasets
- **Local Caching**: Scan results are cached for quick revisits
- **Permission Handling**: Gracefully handles unreadable paths and permission errors

## Requirements

- macOS 13.0 or later
- Xcode 14.0+ (for building from source)

## Installation

### Running the Pre-built App

```bash
./launch-mactree.command
```

### Building from Source

```bash
cd app
swift build
swift run
```

## Development

### Project Structure

- `Sources/MacTreeApp/` - Swift source code
  - `AppDelegate.swift` - Application lifecycle management
  - `Scanning/` - File system scanning engine
  - `Aggregation/` - Data aggregation and processing
  - `Model/` - Data models (FileEntry, DirAggregate, etc.)
  - `Persistence/` - SQLite database management
  - `Resources/Web/` - Embedded web interface (HTML/CSS/JS)
- `specs/` - Feature specifications and planning documents
- `docs/` - Additional documentation

### Development Scripts

```bash
# Run in development mode
./app/Scripts/dev-run.sh
```

## Technology Stack

- **Swift** - Native macOS application
- **WebKit** - Embedded web view for UI
- **SQLite** - Local storage and caching
- **JavaScript** - Interactive treemap and table views

## Contributing

This project was built with assistance from:
- **GitHub Copilot** - AI-powered code completion and development assistance
- **Speckit** - Specification-driven development workflow

## License

Copyright © 2025. All rights reserved.

## Roadmap

See [specs/001-disk-usage-viz/](specs/001-disk-usage-viz/) for detailed feature specifications and tasks.
