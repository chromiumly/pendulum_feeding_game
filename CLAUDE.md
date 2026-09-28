# Pendulum Feeding Game

## Project Overview

This is a wedding reception mini-game.

The existing TypeScript implementation is located at:

`../pendulum-feeding-game`

This Flutter project is a new implementation of the same game.

The TypeScript project is the reference implementation for the existing game behavior, but its software architecture and state management are NOT considered ideal and should not be copied blindly.

## Main Goal

Build the production version of the game using:

* Flutter
* Flame
* Dart
* Flutter Web

The game will eventually be deployed as a static web application, primarily accessed from smartphones.

## Important Development Principle

Separate:

1. Game behavior/specification
2. Game architecture/implementation
3. Visual design/assets

The existing TypeScript implementation is the reference for (1), but not necessarily for (2) or (3).

### Preserve

Unless there is a clear reason to change them, preserve the behavioral meaning of:

* Double-pendulum physics
* Runge-Kutta integration
* Initial conditions
* Pendulum geometry
* Food launching behavior
* Food trajectory
* Collision/eating rules
* Score calculation
* Game rules
* Input semantics
* Game state transitions

When changing an implementation detail, verify that the resulting behavior remains equivalent to the TypeScript version.

### Improve

The Flutter implementation may redesign:

* State management
* Class responsibilities
* File/module structure
* Game loop architecture
* Separation between physics, game state, rendering, and UI
* Collision implementation
* Input handling
* Naming
* Reusable components
* Flutter/Flame integration

Do not copy poor architectural patterns from the TypeScript prototype merely for compatibility.

## Initial Development Phase

The first implementation should NOT reproduce the final visual design.

Use simple placeholder rendering:

* Circles for characters/objects
* Lines for pendulum rods
* Simple arrows for food direction
* Simple colors/background
* Basic Flutter UI controls

The purpose of this phase is to verify:

1. Physics
2. State transitions
3. Input
4. Food launching
5. Collision detection
6. Scoring
7. Overall gameplay

Real visual assets and polished Figma-based UI should be introduced after the core game behavior is working.

## Physics

The double-pendulum physics is important.

Do not replace the existing mathematical model with a different physics engine merely because Flame is being used.

Use the existing TypeScript implementation as the numerical reference.

The physics implementation should be isolated from rendering.

Prefer a structure where physical state is explicit and centralized, for example:

* angles
* angular velocities
* other required physical state

Physics calculations should not directly depend on Flutter widgets or rendering components.

## Flame

Use Flame for the game-side responsibilities where appropriate:

* Game loop
* Game components
* Game objects
* Rendering
* Input
* Collision detection
* Game effects/animations

Use ordinary Flutter widgets for application/UI screens where appropriate:

* Title
* Instructions/setup
* Result
* Ranking
* Other non-game UI

Do not introduce additional game engines unless there is a concrete technical reason.

## Architecture

Prefer clear separation such as:

* Physics
* Game state
* Game components
* Collision/game rules
* Flutter UI

Avoid unnecessary abstraction and over-engineering.

Keep the architecture simple enough for a small wedding game.

## Testing

When porting numerical or game logic from TypeScript:

* Use deterministic test cases where possible.
* Compare important numerical states between TypeScript and Dart.
* Pay particular attention to RK4 integration and coordinate calculations.
* Do not assume that visually similar behavior means numerical equivalence.

Run Flutter tests and static analysis after meaningful changes.

## Existing Project

The existing TypeScript project must be treated as read-only during the migration unless explicitly requested otherwise.

Do not modify files under `../pendulum-feeding-game`.

The Flutter project is the only project that should normally be modified.

## Assets

Existing TypeScript assets may eventually be reused.

Do not spend time reproducing final visual assets during the initial physics/gameplay implementation.

Final visual design will be developed separately using Figma.

## Code Style

Prefer:

* Small, focused classes
* Explicit state
* Clear naming
* Minimal coupling
* Simple data flow
* Testable logic

Avoid:

* Unnecessary global state
* Duplicated state
* Rendering logic mixed into physics calculations
* Premature abstractions
* Large "god" classes
* Unnecessary dependencies

## Workflow

For substantial changes:

1. Inspect the relevant existing code.
2. Explain the proposed design briefly.
3. Implement the smallest coherent change.
4. Run relevant tests/analyzer/build.
5. Report what changed and any remaining issues.

Do not make broad unrelated refactors while implementing a feature.
