# Concurrency101

Learning package only. Not for production or App Store targets.

## What this is

A Swift package that wraps Grand Central Dispatch and Swift Concurrency behind names that describe intent. Every helper is a 1:1 mapping onto a real Apple API.

- `Concurrency101.GCD` — queues, QoS, barriers, groups, `sync`
- `Concurrency101.Modern` — tasks, actors, `await`, isolation
- `Concurrency101Sim` — the simulated runtime behind the demo app's Sandbox room (interpreter for a Swift subset + virtual threads, queues, actors, clock)
- Demo app: `DemoApp/Concurrency101Demo.xcodeproj`
- CLI examples live under `Examples/`

The goal is that a learner can drop `import Concurrency101` and write `DispatchQueue`, `Task`, `@MainActor`, and `actor` themselves. Do not add helpers that hide Apple APIs without a matching real call.

## Rules

- Keep the teaching warning. Do not turn this into a production utility library.
- GCD track: do not add Swift 6 `Sendable` on GCD closures. Modern track: keep `@Sendable`.
- Prefer names that say intent (`runUserRequestedWork`) over raw QoS words (`userInitiated`).
- UI work goes through `updateUI` / `waitForUI`. User-waiting work is `runUserRequestedWork`, not `runWhenUserIsNotWaiting`.
- Freeze / deadlock lessons are intentional. Do not "fix" them by removing the hang unless the lesson itself is being rewritten.
- Match existing style in `Sources/`. Small, explicit mappings. No extra abstraction layers.
- Simulator prelude (`Sources/Concurrency101Sim/Runtime/Prelude.swift`) mirrors `Sources/Concurrency101` 1:1. When a teaching helper changes, change the prelude to match.
- A new Playground lesson needs an expectation in `Tests/Concurrency101SimTests/Lessons/LessonConformanceTests.swift`; the tests read the snippets straight from the scenario libraries.

## Commands

```bash
swift test
swift build
open DemoApp/Concurrency101Demo.xcodeproj
```

Requires Swift 5.9+, macOS 13 / iOS 16 / tvOS 16 / watchOS 9.

## File structure

### Package

- `Package.swift` — `Concurrency101` and `Concurrency101Sim` libraries, their test targets, and the example executables. Example target paths are declared here.
- `Sources/Concurrency101/` — teaching package, already split into `GCD/` and `Modern/`. `Concurrency101.swift` and `ModuleWarning.swift` sit beside those folders. DocC articles are `Sources/Concurrency101/Concurrency101.docc/` (`Concurrency101.md`, `MentalModel.md`, `ModernModel.md`, `QoSIntent.md`, `Blocking.md`, `Graduation.md`).
- `Sources/Concurrency101Sim/` — `Syntax/` (lexer, AST, parser), `Compile/` (compiler, bytecode, globals), `Runtime/` (values, objects, machine, scheduler, built-ins, prelude), and `Simulator.swift` (public API and result types).
- `Examples/` — CLI lessons. Shared helper is `Examples/ExampleSupport/`. Each lesson is one folder with `main.swift` under `Examples/GCD/` or `Examples/Modern/` (UI, QoS intent, lanes, groups, barriers, cancellation, deadlock, actors, task groups, continuations).
- `DemoApp/Concurrency101Demo/Curriculum/` — lesson markdown. GCD notes are `Curriculum/GCD/`. The Modern path is `Curriculum/Modern/` (`Notes/`, `Drills/`, `Lab/`, plus roadmap, glossary, progress, and resources files).
- `DemoApp/Concurrency101Demo/Assets.xcassets/` — accent color and app icon.
- `README.md` — learner-facing guide.

### Demo rooms

Project: `DemoApp/Concurrency101Demo.xcodeproj`. Target sources: `DemoApp/Concurrency101Demo/`.

- `App/` — `@main` (`Concurrency101DemoApp.swift`) and the root stack (`RootView.swift`)
- `Model/` — `LearningTrack` (track copy and accent) and `PathRoom` (Playground, Sandbox, Notes, Drill)
- `Theme/` — colors (`DemoTheme`), layout (`DemoLayout`), source metrics (`DemoSourceType`), glyphs (`DemoGlyphs`), shared nav chrome (`DemoRoomChrome`)
- `Shared/` — canvas (`DemoCanvas`), choice card (`ChoiceCard`), phone/pad stack (`AdaptiveCardStack`)
- `Landing/` — track doors (`LandingView`) and the hub (`TrackHubView`)
- `Playground/` — workbench, cheat sheet, console, log, and scenarios. `DemoScenario` is `Playground/DemoScenario.swift`. Per-track lists are `Playground/Scenarios/`.
- `Notes/` — studio, article, and session. The loader for curriculum markdown is `Notes/Curriculum/` (`CurriculumCatalog`, `CurriculumBundle`, `NoteMarkdown`).
- `Drill/` — lobby, question, explain, results, session, and GCD/Swift question banks. `DrillView.swift` is the room.
- `Sandbox/` — the simulated-runtime room: `SandboxView` (room), `SandboxSession` (draft, diagnostics, run, playback), editor, output (trace + outcome), timeline, help sheet. Linked to the `Concurrency101Sim` package product.
- `Learning/` — error log of missed predictions.
- `Onboarding/` — automatic first-visit page guides, component descriptions, visit state, view targets, and the spotlight tooltip overlay. Update targets and guide copy when a page's controls change. Each guide is offered once, with no manual trigger.

Landing picks a track, then the hub opens a `PathRoom` (Playground, Sandbox, Notes, Drill). Lesson copy stays in `Curriculum/`; `Notes/Curriculum/` is only the reader.

### Tests

`Tests/Concurrency101Tests/GCD/`, `Tests/Concurrency101Tests/Modern/`, and `Tests/Concurrency101Tests/Support/TestSupport.swift`.

`Tests/Concurrency101SimTests/` — `Language/` (parser, diagnostics), `Runtime/` (GCD and Swift Concurrency model), `Lessons/` (every Playground snippet, plus `LessonDumpTests`, which prints traces when `SIM_DUMP=1`), `Support/`.
