# Graduation

@Metadata {
    @TitleHeading("Article")
}

Concurrency101 has succeeded when you no longer need it.

## Ritual

1. Pick one example under `Examples/GCD/` or `Examples/Modern/`.
2. Delete `import Concurrency101`.
3. Rewrite every helper as the Apple call in its documentation comment.
4. If you started on GCD, rewrite once more with `Task`, `await`, `@MainActor`, and `actor`.

If you cannot, reread <doc:MentalModel> or <doc:ModernModel> and the symbol docs.

## Side by side

Concurrency101.GCD:

```swift
Concurrency101.GCD.runUserRequestedWork {
    let value = load()
    Concurrency101.GCD.updateUI { label.text = value }
}
```

GCD:

```swift
DispatchQueue.global(qos: .userInitiated).async {
    let value = load()
    DispatchQueue.main.async {
        label.text = value
    }
}
```

Concurrency101.Modern:

```swift
Concurrency101.Modern.runDetachedFromCaller {
    let value = load()
    await Concurrency101.Modern.waitForUI { label.text = value }
}
```

Swift Concurrency:

```swift
Task.detached(priority: .userInitiated) {
    let value = load()
    await MainActor.run {
        label.text = value
    }
}
```

The package has failed if you keep `import Concurrency101` in an app because “the names are nicer.”
