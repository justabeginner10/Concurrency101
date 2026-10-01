// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Concurrency101",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "Concurrency101", targets: ["Concurrency101"]),
        .executable(name: "GCDUpdateUIExample", targets: ["GCDUpdateUIExample"]),
        .executable(name: "GCDUserWaitingVersusNotWaitingExample", targets: ["GCDUserWaitingVersusNotWaitingExample"]),
        .executable(name: "GCDPrivateSerialLaneExample", targets: ["GCDPrivateSerialLaneExample"]),
        .executable(name: "GCDRunSeveralThenContinueExample", targets: ["GCDRunSeveralThenContinueExample"]),
        .executable(name: "GCDMissingEndOneExample", targets: ["GCDMissingEndOneExample"]),
        .executable(name: "GCDBarrierExample", targets: ["GCDBarrierExample"]),
        .executable(name: "GCDCancellableWorkExample", targets: ["GCDCancellableWorkExample"]),
        .executable(name: "GCDDeadlockOnPurposeExample", targets: ["GCDDeadlockOnPurposeExample"]),
        .executable(name: "ModernUpdateUIExample", targets: ["ModernUpdateUIExample"]),
        .executable(name: "ModernTaskVersusDetachedExample", targets: ["ModernTaskVersusDetachedExample"]),
        .executable(name: "ModernExclusiveStateExample", targets: ["ModernExclusiveStateExample"]),
        .executable(name: "ModernTaskGroupExample", targets: ["ModernTaskGroupExample"]),
        .executable(name: "ModernCancellationExample", targets: ["ModernCancellationExample"]),
        .executable(name: "ModernContinuationExample", targets: ["ModernContinuationExample"]),
        .executable(name: "ModernReentrancyExample", targets: ["ModernReentrancyExample"]),
        .executable(name: "ModernParkThreadOnPurposeExample", targets: ["ModernParkThreadOnPurposeExample"]),
    ],
    targets: [
        .target(name: "Concurrency101"),
        .target(
            name: "ExampleSupport",
            dependencies: [],
            path: "Examples/ExampleSupport"
        ),
        .testTarget(
            name: "Concurrency101Tests",
            dependencies: ["Concurrency101"]
        ),
        .executableTarget(
            name: "GCDUpdateUIExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/GCD/UpdateUI"
        ),
        .executableTarget(
            name: "GCDUserWaitingVersusNotWaitingExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/GCD/UserWaitingVersusNotWaiting"
        ),
        .executableTarget(
            name: "GCDPrivateSerialLaneExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/GCD/PrivateSerialLane"
        ),
        .executableTarget(
            name: "GCDRunSeveralThenContinueExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/GCD/RunSeveralThenContinue"
        ),
        .executableTarget(
            name: "GCDMissingEndOneExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/GCD/MissingEndOne"
        ),
        .executableTarget(
            name: "GCDBarrierExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/GCD/Barrier"
        ),
        .executableTarget(
            name: "GCDCancellableWorkExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/GCD/CancellableWork"
        ),
        .executableTarget(
            name: "GCDDeadlockOnPurposeExample",
            dependencies: ["Concurrency101"],
            path: "Examples/GCD/DeadlockOnPurpose"
        ),
        .executableTarget(
            name: "ModernUpdateUIExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/Modern/UpdateUI"
        ),
        .executableTarget(
            name: "ModernTaskVersusDetachedExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/Modern/TaskVersusDetached"
        ),
        .executableTarget(
            name: "ModernExclusiveStateExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/Modern/ExclusiveState"
        ),
        .executableTarget(
            name: "ModernTaskGroupExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/Modern/TaskGroup"
        ),
        .executableTarget(
            name: "ModernCancellationExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/Modern/Cancellation"
        ),
        .executableTarget(
            name: "ModernContinuationExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/Modern/Continuation"
        ),
        .executableTarget(
            name: "ModernReentrancyExample",
            dependencies: ["Concurrency101", "ExampleSupport"],
            path: "Examples/Modern/Reentrancy"
        ),
        .executableTarget(
            name: "ModernParkThreadOnPurposeExample",
            dependencies: ["Concurrency101"],
            path: "Examples/Modern/ParkThreadOnPurpose"
        ),
    ]
)
