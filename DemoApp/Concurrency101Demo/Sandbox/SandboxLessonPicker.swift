import SwiftUI

/// A native sheet keeps the lesson list at a stable size while navigating
/// between teaching names and Apple APIs, instead of resizing nested menus.
struct SandboxLessonPicker: View {
    let scenarios: [DemoScenario]
    let accent: Color
    let onPick: (DemoScenario?, Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SandboxLessonList(scenarios: scenarios, apple: false, accent: accent, onPick: onPick, onCancel: { dismiss() })
                    } label: {
                        Text("Concurrency101 names")
                            .pageGuideTarget(.sandboxPicker, "names")
                    }
                    NavigationLink {
                        SandboxLessonList(scenarios: scenarios, apple: true, accent: accent, onPick: onPick, onCancel: { dismiss() })
                    } label: {
                        Text("Apple API names")
                    }
                } header: {
                    Text("Start from a lesson")
                        .textCase(nil)
                }
                Section {
                    Button("Blank editor", role: .destructive) {
                        onPick(nil, false)
                    }
                    .pageGuideTarget(.sandboxPicker, "blank")
                }
            }
            .modifier(SandboxPickerListBackground())
            .navigationTitle("")
            .demoRoomChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .pageGuideTarget(.sandboxPicker, "cancel")
                }
            }
            .pageGuide(.sandboxPicker, accent: accent)
        }
        .pageGuideHost()
        .tint(accent)
        .preferredColorScheme(.dark)
        .presentationBackground(DemoTheme.void)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #elseif os(macOS)
        .frame(width: 480, height: 520)
        #endif
    }
}

private struct SandboxLessonList: View {
    let scenarios: [DemoScenario]
    let apple: Bool
    let accent: Color
    let onPick: (DemoScenario?, Bool) -> Void
    let onCancel: () -> Void

    var body: some View {
        List {
            Section {
                ForEach(scenarios) { scenario in
                    Button {
                        onPick(scenario, apple)
                    } label: {
                        Text(verbatim: scenario.title)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .pageGuideTarget(.sandboxLessons, "lesson", enabled: scenario.id == scenarios.first?.id)
                }
            } header: {
                Text(apple ? "Apple API names" : "Concurrency101 names")
                    .textCase(nil)
            }
        }
        .modifier(SandboxPickerListBackground())
        .navigationTitle("")
        .demoRoomChrome()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
                    .pageGuideTarget(.sandboxLessons, "navigate")
            }
        }
        .pageGuide(.sandboxLessons, accent: accent)
    }
}

private struct SandboxPickerListBackground: ViewModifier {
    func body(content: Content) -> some View {
        let list = content
            .scrollContentBackground(.hidden)
            .background { DemoTheme.void.ignoresSafeArea() }
        if #available(iOS 26, macOS 26, *) {
            // A short sheet leaves little room for the system's soft edge
            // fade. Keep the rows readable at both presentation heights.
            list.scrollEdgeEffectHidden(true, for: [.top, .bottom])
        } else {
            list
        }
    }
}
