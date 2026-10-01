# ``Concurrency101``

@Metadata {
    @TechnologyRoot
}

A **learning-only** Swift package that wraps Grand Central Dispatch and Swift Concurrency behind names that describe intent.

This is a bilingual dictionary, not a production concurrency library. Every helper maps 1:1 onto a real Apple API. After you can explain the helper in Apple words, delete `import Concurrency101` and write Dispatch or Swift Concurrency yourself.

@Warning("Do not add Concurrency101 to an App Store target or client project.")

## Two tracks

Pick **GCD** if you need queues, QoS, barriers, and `sync`. Pick **Modern** if you need tasks, actors, `await`, and isolation. The questions are the same: who is waiting, does this touch UI, can this overlap, is this a footgun.

## Topics

### Getting started

- <doc:MentalModel>
- <doc:ModernModel>
- <doc:QoSIntent>
- <doc:Blocking>
- <doc:Graduation>

### Tracks

- ``Concurrency101/GCD``
- ``Concurrency101/Modern``
