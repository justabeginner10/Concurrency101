# Priority and Quality of Service are user intent

@Metadata {
    @TitleHeading("Article")
}

GCD Quality of Service and Swift `TaskPriority` are **not** a thread, a deadline, or a start-time guarantee. They tell the system how important the work is relative to energy and responsiveness.

Concurrency101 names the same four classes by what the **user** is doing:

| User situation | Concurrency101 | GCD | Swift Concurrency |
|---|---|---|---|
| Next frame / finger tracking (tiny, rare) | `runForImmediateUI` | `.userInteractive` | `TaskPriority.high` |
| User tapped and is waiting | `runUserRequestedWork` | `.userInitiated` | `TaskPriority.userInitiated` |
| Progress they may watch | `runMaintenanceWork` | `.utility` | `TaskPriority.utility` |
| User is not waiting | `runWhenUserIsNotWaiting` | `.background` | `TaskPriority.background` |

## The “background” trap

In everyday English, “do it in the background” means “not the main thread / main actor.”

In both GCD and Swift, `.background` means **lowest urgency**. A Refresh button should use `runUserRequestedWork`, not `runWhenUserIsNotWaiting`.

## Inheritance trap (Swift only)

`Task(priority:)` created on `@MainActor` **inherits** the main actor. The priority helper does not kick you off-main by itself. Use ``Concurrency101/Modern/runDetachedFromCaller(_:)`` when the work must not run on the caller’s actor — and know why you are escaping.

GCD `DispatchQueue.global().async` always leaves the main queue. That difference is the whole lesson of the Swift track.
