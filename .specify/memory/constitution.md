<!--
SYNC IMPACT REPORT
==================
Version Change: N/A → 1.0.0
Reason: Initial constitution ratification for MacTree project

Modified Principles: None (initial creation)
Added Sections:
  - Core Principles (5 principles defined)
  - Technical Standards
  - Development Workflow
  - Governance

Removed Sections: None

Templates Status:
  ✅ plan-template.md - Constitution Check section references this file
  ✅ spec-template.md - Requirements align with constitution principles
  ✅ tasks-template.md - Task organization respects constitution constraints
  ✅ Command prompts - Generic guidance maintained

Follow-up TODOs: None
-->

# MacTree Constitution

## Core Principles

### I. Performance First

Scanning MUST be fast, incremental, and never block the UI.

**Rationale**: MacTree is a disk usage visualization tool where users expect immediate responsiveness. Blocking the UI during scans creates a poor user experience and violates macOS platform conventions for smooth, interruptible operations. Incremental scanning ensures users can see results as they arrive, maintaining engagement and providing early value.

### II. Local-Only & Private

All data MUST stay on the user's machine. No uploads, no telemetry, no external network requests.

**Rationale**: Users scan personal and sensitive directories. Privacy is non-negotiable. This principle ensures complete user trust and eliminates entire categories of security, compliance, and data handling concerns. It also simplifies the application architecture by removing network dependencies.

### III. Simple, Predictable UX

Behavior MUST be obvious and consistent with macOS conventions.

**Rationale**: Users should never need documentation for basic operations. Following macOS Human Interface Guidelines ensures the application feels native, reduces cognitive load, and leverages existing user knowledge. Predictability means users can confidently explore features without fear of unexpected behavior.

### IV. Minimal Dependencies

Use vanilla HTML, CSS, and JavaScript whenever possible. Avoid frameworks and heavy libraries unless clearly justified.

**Rationale**: Dependencies introduce maintenance burden, security vulnerabilities, bundle size bloat, and upgrade friction. Vanilla web technologies are stable, well-documented, and sufficient for MacTree's needs. This principle keeps the codebase maintainable long-term and reduces the attack surface.

### V. Correctness Over Features

Accurate sizes and stable results matter more than extra functionality.

**Rationale**: A disk usage tool that reports incorrect sizes is worse than useless—it's misleading. Users rely on MacTree for truth. Stability means users can trust results across multiple scans. Features that compromise correctness or stability MUST be rejected, no matter how appealing.

## Technical Standards

### Technology Stack

- **Frontend**: Vanilla HTML5, CSS3, JavaScript (ES2020+)
- **Backend/Native**: Platform-specific native code when necessary for file system access
- **Build Tools**: Minimal tooling—prefer standard browser APIs
- **Testing**: Standard testing frameworks appropriate to the language (e.g., Jest for JavaScript, XCTest for Swift)

### Performance Requirements

- **UI Responsiveness**: UI MUST remain interactive during all operations
- **Incremental Display**: Results MUST be displayed progressively, not all-at-once
- **Scan Performance**: Large directory scans (>100k files) MUST show first results within 1 second
- **Memory Efficiency**: Memory usage MUST scale sub-linearly with directory size

### Data Integrity

- **Size Accuracy**: File and directory sizes MUST match system utilities (e.g., `du`, Finder)
- **Consistency**: Repeated scans of unchanged directories MUST produce identical results
- **Error Handling**: File system errors MUST be surfaced clearly without corrupting results

## Development Workflow

### Implementation Process

1. **Specification First**: Every feature starts with a clear specification documenting user scenarios, requirements, and acceptance criteria
2. **Constitution Check**: Verify new features align with all five core principles before implementation
3. **Incremental Development**: Break features into independently testable units
4. **Testing Strategy**: Test correctness with real file systems, not just mocked data

### Code Review Standards

- **Principle Alignment**: Reviewers MUST verify compliance with all core principles
- **Performance Verification**: Changes affecting scan performance MUST include before/after measurements
- **Simplicity Review**: Complexity MUST be justified—prefer simpler solutions
- **Dependency Justification**: New dependencies require explicit approval and documented rationale

### Quality Gates

- **No UI Blocking**: Any change that blocks the UI during operations MUST be rejected
- **No External Requests**: Any code that makes network requests MUST be rejected
- **Accuracy Tests**: Size calculation changes MUST pass validation against system utilities
- **Platform Consistency**: UI changes MUST follow macOS Human Interface Guidelines

## Governance

### Amendment Process

1. **Proposal**: Document proposed change with rationale and impact analysis
2. **Review**: Assess impact on existing features and specifications
3. **Migration Plan**: If accepted, create plan to update affected artifacts
4. **Version Increment**: Update constitution version following semantic versioning

### Versioning Policy

- **MAJOR** (x.0.0): Backward-incompatible changes—removing or redefining principles
- **MINOR** (0.x.0): New principles or materially expanded sections
- **PATCH** (0.0.x): Clarifications, wording improvements, non-semantic changes

### Compliance

- This constitution supersedes all other development practices
- All feature specifications, plans, and tasks MUST reference this constitution
- Violations MUST be documented and explicitly justified with compelling rationale
- Constitution review MUST occur during specification and planning phases

**Version**: 1.0.0 | **Ratified**: 2025-12-18 | **Last Amended**: 2025-12-18
