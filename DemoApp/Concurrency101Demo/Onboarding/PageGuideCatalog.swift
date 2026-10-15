import Foundation

enum PageGuidePage: String, CaseIterable, Identifiable {
    case home, hub, playground, sandbox, notes
    case drillSetup, drillQuestion, drillResults, drillExplanation
    case errorLog, cheatSheet, sandboxPicker, sandboxLessons, sandboxHelp

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .home: "Home"
        case .hub: "Your learning path"
        case .playground: "Playground"
        case .sandbox: "Sandbox"
        case .notes: "Notes"
        case .drillSetup: "Drill setup"
        case .drillQuestion: "Drill questions"
        case .drillResults: "Drill results"
        case .drillExplanation: "Explanation"
        case .errorLog: "Error log"
        case .cheatSheet: "Cheat sheet"
        case .sandboxPicker: "Choose your code"
        case .sandboxLessons: "Choose a lesson"
        case .sandboxHelp: "Sandbox help"
        }
    }
}

struct PageGuideStep: Identifiable {
    let id: String
    let title: LocalizedStringResource
    let location: LocalizedStringResource
    let message: LocalizedStringResource
    let symbol: String

    init(_ id: String, _ title: LocalizedStringResource, _ location: LocalizedStringResource,
         _ message: LocalizedStringResource, _ symbol: String) {
        self.id = id
        self.title = title
        self.location = location
        self.message = message
        self.symbol = symbol
    }
}

/// UI instructions live together so a renamed control has one guide to update.
enum PageGuideCatalog {
    static func steps(for page: PageGuidePage) -> [PageGuideStep] {
        switch page {
        case .home:
            [
                .init("purpose", "Learn, then graduate", "The Concurrency101 heading",
                      "This is a learning app. The 101 names explain intent; the Apple names show the APIs you will eventually use yourself. This teaching package is not for production or App Store targets.", "graduationcap"),
                .init("gcd", "Grand Central Dispatch", "The GCD track card",
                      "Open this card to learn queues, QoS, groups, barriers, cancellation, and blocking. Amber marks the main thread.", "rectangle.stack"),
                .init("modern", "Swift Concurrency", "The Swift Concurrency track card",
                      "Open this card to learn tasks, actors, await, isolation, and cooperative cancellation. Each track has its own lessons, notes, quiz, and saved place.", "arrow.triangle.branch"),
            ]
        case .hub:
            [
                .init("continue", "Continue where you left off", "Continue, below the track heading",
                      "After you start learning, Continue reopens your last note, lesson, or unfinished quiz. It appears when there is a saved place to return to.", "arrow.forward.circle"),
                .init("playground", "Playground", "The Playground room card",
                      "Run prepared lessons on the real runtime. Predict an outcome, compare 101 and Apple code, then read the console. Some lessons intentionally freeze the app.", "play.rectangle"),
                .init("sandbox", "Sandbox", "The Sandbox room card",
                      "Edit a lesson or write code and run it on a simulated runtime. Explore deadlocks safely and inspect a trace or thread timeline.", "hammer"),
                .init("notes", "Notes", "The Notes room card",
                      "Read and search the curriculum. Links connect related notes, and your last reading position is remembered.", "book"),
                .init("drill", "Drill", "The Drill room card",
                      "Choose a difficulty and answer eight questions. You get feedback after each answer, explanations, and a chance to review misses.", "checkmark.circle"),
                .init("path", "Follow the Path", "The Path section below the room cards",
                      "Open a topic's note, its lesson chips, and any practice note. Checkmarks mean you opened the note or ran the lesson; they do not claim mastery. Closed-book quiz opens Drill.", "list.bullet"),
                .init("errors", "Learn from misses", "Error log at the bottom of the hub",
                      "Open Error log to compare what you predicted with what happened and read the rule behind the answer. The count reflects saved entries from missed predictions and quiz answers.", "text.badge.xmark"),
            ]
        case .playground:
            [
                .init("lesson", "Choose a lesson", "The lesson selector beside Run",
                      "Tap the lesson name to choose another scenario. The Apple API label and description explain what the selected lesson is demonstrating.", "list.bullet"),
                .init("prediction", "Predict first", "The prediction choices above the code, when present",
                      "Pick an outcome before running. Run becomes available after your prediction. Afterward, read the answer and explanation; a miss is recorded in Error log.", "questionmark.circle"),
                .init("run", "Run the real lesson", "Run beside the lesson selector",
                      "Run executes the prepared lesson on real queues and tasks. Freeze lessons ask for confirmation and intentionally hang the app. Use Sandbox to explore those lessons safely; stop in Xcode or force-quit to recover from a real freeze.", "play.fill"),
                .init("versions", "Compare API names", "101 / GCD or Swift in the code header",
                      "The switch changes the displayed snippet between teaching names and the equivalent Apple APIs. It helps you connect an intent to the real call.", "arrow.left.arrow.right"),
                .init("source", "Read and copy code", "The source panel and Copy button",
                      "Colors distinguish keywords, types, calls, strings, and numbers. The gutter numbers logical source lines. Copy copies the displayed version. Playground code is read-only; open it in Sandbox to edit.", "doc.on.doc"),
                .init("console", "Read the trace", "The glass console below or beside the code",
                      "Each line includes its runtime information. Amber means main thread and cyan means off-main. The same lines print in Xcode. Scroll to inspect earlier output.", "text.alignleft"),
                .init("panels", "Make room to inspect", "Expand / Fold, Clear, and the panel-size icons",
                      "Expand and Fold resize the docked phone console. Clear removes its output. Panel-size icons maximize code or console; the restore icon returns to the workbench.", "arrow.up.left.and.arrow.down.right"),
                .init("options", "Playground options", "The ellipsis-circle button in the toolbar",
                      "Open in Sandbox carries the selected lesson and displayed API version into an editable editor. Cheat sheet compares intent names with Apple APIs. Font size changes source and console text.", "ellipsis.circle"),
            ]
        case .sandbox:
            [
                .init("lesson", "Start from a lesson", "From: … or Your code beside Run",
                      "Open the chooser for Concurrency101 names, Apple API names, or a Blank editor. Pick a lesson to load it. Replacing edited code asks for confirmation.", "list.bullet"),
                .init("run", "Run your current code", "Run beside the source chooser",
                      "Run executes the editor's current text on the simulated runtime. It returns an outcome instead of freezing the app. With a hardware keyboard, Command-R also runs the code.", "play.fill"),
                .init("editor", "Edit and copy", "The Code panel",
                      "Type or paste Swift into the highlighted editor. Line numbers match source lines; wrapped continuations keep their original number. Copy copies the current text. Your draft is saved for this track.", "square.and.pencil"),
                .init("versions", "Switch between 101 and Apple", "101 / GCD or Swift in the Code header",
                      "For a loaded lesson, the switch shows its other API version. Edits to each version are kept separately, even after reopening Sandbox. The switch is unavailable for a blank or unrelated custom draft, or during a run.", "arrow.left.arrow.right"),
                .init("diagnostics", "Fix source errors", "Status in the Code header; messages below the editor",
                      "Code is checked as you type. Messages identify the source line and problem, such as a missing await or try. Fix errors before running. These checks cover the Sandbox's supported Swift subset.", "exclamationmark.bubble"),
                .init("trace", "Trace", "Trace in the output selector",
                      "Trace lists virtual time, thread, text, and queue, actor, or task context. Amber is main. A source-line reference tells you which part of your code produced the event.", "text.alignleft"),
                .init("threads", "Threads", "Threads in the output selector",
                      "The timeline draws one row per virtual thread. Solid bars are running work; outlined bars hold a thread while waiting. A bar running off the end never returned. Tap a bar to inspect its operation, times, and source line; scroll to inspect more threads.", "chart.bar.xaxis"),
                .init("outcome", "Read the outcome", "The card at the end of the output",
                      "When playback ends, the card reports completion, deadlock, crash, or a run limit. Read its details and warnings to see which waits or operations caused the result.", "checkmark.rectangle"),
                .init("shuffle", "Shuffle the interleaving", "Shuffle · seed below the source chooser",
                      "Shuffle runs the same current code with another seed. The same code, cores, and seed repeat the same run, so you can compare different valid outcomes without changing the program.", "shuffle"),
                .init("cores", "Choose the task-pool size", "Cores beside Shuffle",
                      "Choose 1, 2, 4, or 8 cores before the next run. Try one core to see how blocking can starve the simulated Swift task pool. These are model settings, not your device's actual thread counts.", "cpu"),
                .init("playback", "Control playback", "The speed selector and Skip to end",
                      "1× follows virtual time, ¼× plays slowly, and Instant shows the complete run. A speed choice applies to the next playback. Skip to end appears during playback and immediately reveals the remaining output. The t label shows virtual time.", "speedometer"),
                .init("help", "Check what is supported", "The question-circle button in the toolbar",
                      "How the Sandbox works explains the thread pools, supported APIs, model limits, and output legend. The simulator models a Swift subset; its times and thread counts are illustrative.", "questionmark.circle"),
            ]
        case .notes:
            [
                .init("index", "Browse the index", "The Notes sidebar",
                      "Choose a note from its section. The highlighted row marks the current note. On portrait iPhone, the sidebar button in the toolbar opens or closes the drawer; tapping outside it also closes it.", "sidebar.left"),
                .init("search", "Search note titles", "Find / Search notes at the top of the sidebar",
                      "Type a title, identifier, or note number to filter the index. Clear the search to bring back all notes. This searches the index, not the full article text.", "magnifyingglass"),
                .init("article", "Read the article", "The numbered heading and article pane",
                      "Scroll through the curriculum, select text, and scroll wide code blocks horizontally. Your last selected note is remembered. Diagram sections show their source text.", "book"),
                .init("links", "Follow related topics", "Links inside the article",
                      "Curriculum links open related notes in this reader. Other links open their external destination. Following a curriculum link clears the index search so the destination can be found.", "link"),
                .init("pager", "Previous and Next", "The buttons at the bottom of the article",
                      "Move through notes in curriculum order. A disabled button means there is no earlier or later note. Use the sidebar when you want to jump to a specific topic.", "arrow.left.arrow.right"),
            ]
        case .drillSetup:
            [
                .init("difficulty", "Choose a difficulty", "The difficulty cards below Drill",
                      "Tap a difficulty to choose the question bank. The selected card is filled with the track color. Its description tells you what the questions focus on.", "slider.horizontal.3"),
                .init("history", "See what comes next", "Last run and missed-question text, when present",
                      "Last run shows your previous score at the selected difficulty. Saved misses from that bank are brought back first in a new quiz.", "clock"),
                .init("resume", "Resume an unfinished quiz", "Resume, when a saved run exists",
                      "Resume restores the saved question, answers, and progress. It appears only when you have an unfinished run for this track.", "arrow.forward.circle"),
                .init("start", "Start or New run", "The button below the difficulty cards",
                      "Start deals eight questions at the chosen difficulty. When a saved quiz exists, New run starts over instead of resuming it. Question and answer orders are shuffled.", "play.fill"),
            ]
        case .drillQuestion:
            [
                .init("progress", "Track your place", "The question count and progress strip at the top",
                      "The count shows your position in the deck. The strip fills as you move through questions. Your picks and current place are saved as you go.", "chart.bar"),
                .init("question", "Read the question and code", "The question body",
                      "Read the whole prompt and any highlighted, numbered snippet before choosing. Copy copies that snippet. The code shown here is for reasoning; it is not executed by the quiz.", "curlybraces"),
                .init("answers", "Choose A, B, C, or D", "The four answer rows",
                      "Tap one answer. Your choice locks, and the correct answer is revealed immediately. Misses are saved for review and added to Error log; a correct answer resolves that saved miss.", "checkmark.circle"),
                .init("explain", "Understand the rule", "Explain in the bottom bar",
                      "Explain becomes available after you answer. It opens the rule and the source note, with Open note when the curriculum source is available.", "text.book.closed"),
                .init("navigation", "Previous and Next", "The bottom-right buttons",
                      "Previous revisits an earlier question. Next becomes available after an answer and moves forward; on the final question it opens Results. Revisiting a question preserves its locked choice.", "arrow.left.arrow.right"),
                .init("leave", "Leave and resume later", "The back button at the top",
                      "Going back during a quiz asks for confirmation. Your unfinished run remains saved, so Resume in Drill can bring you back later.", "arrow.uturn.backward"),
            ]
        case .drillResults:
            [
                .init("score", "Read your score", "Hits and Longest streak below Results or Review",
                      "Hits counts correct answers out of the deck. Longest streak counts consecutive correct answers. A Review result uses the smaller deck of questions you were revisiting.", "chart.bar"),
                .init("retry", "Retry", "The filled Retry button",
                      "Retry deals a new full quiz at the same difficulty. Your saved misses are used to choose what to practice first.", "arrow.clockwise"),
                .init("review", "Review misses", "Review misses, when there were wrong answers",
                      "This builds a review deck from the questions you just missed. It is a chance to apply the explanations with a fresh choice.", "text.badge.xmark"),
                .init("difficulty", "Change difficulty", "The outlined Change difficulty button",
                      "Return to the lobby, pick another bank, and start a new run. You can also use back to return to your track hub.", "slider.horizontal.3"),
            ]
        case .drillExplanation:
            [
                .init("rule", "The rule", "The explanation under The rule",
                      "Read why the keyed answer is correct and which concurrency principle the question tests. This explains the current question after your answer has been locked.", "text.alignleft"),
                .init("source", "Read the source note", "Source and Open note",
                      "Source names the curriculum article behind the question. When Open note is available, it closes this explanation and opens that article. Returning brings you back to the quiz.", "book"),
                .init("done", "Return to the question", "Done in the explanation header",
                      "Done closes the explanation. It does not change your answer or advance the quiz. Previous and Next remain in the question's bottom bar.", "checkmark"),
            ]
        case .errorLog:
            [
                .init("entries", "Your saved misses", "The cards below Error log",
                      "A wrong Playground prediction or Drill answer adds an entry. Each card names its topic and the date. If there are no entries, Nothing here yet is expected.", "list.bullet"),
                .init("comparison", "Predicted and Actually", "The two labeled values on each card",
                      "Compare the answer you chose with the result or correct answer. This makes the misconception visible rather than keeping only a score.", "arrow.left.arrow.right"),
                .init("why", "Read why", "The explanation at the bottom of each card",
                      "Use the rule to decide what to read or practice next. Return to the hub for Path, Notes, Playground, or Drill; saved misses are also brought back in new quizzes.", "book"),
            ]
        case .cheatSheet:
            [
                .init("mapping", "Intent, 101, and Apple", "The mapping rows",
                      "Read the intent first, then compare the teaching helper with its real Apple API. This is a reference for graduating from the learning package to Dispatch or Swift Concurrency.", "arrow.left.arrow.right"),
                .init("traps", "Everyday language traps", "The traps below the mapping list",
                      "Compare what a beginner says, what they often type, and what they usually meant. These distinctions help you avoid choosing an API just because its name sounds familiar.", "exclamationmark.triangle"),
                .init("close", "Return to Playground", "Close in the toolbar",
                      "Close dismisses the cheat sheet and returns to your selected lesson. The lesson and console are kept.", "xmark"),
            ]
        case .sandboxPicker:
            [
                .init("names", "Choose the API form", "Concurrency101 names and Apple API names",
                      "Choose a group to see the track's lesson list. Concurrency101 loads teaching helpers; Apple API names loads the equivalent Dispatch or Swift Concurrency snippet.", "arrow.left.arrow.right"),
                .init("blank", "Start fresh", "Blank editor below the API groups",
                      "Blank editor clears the code and its lesson association. If either API version has edits, Sandbox asks before replacing your work.", "doc"),
                .init("cancel", "Keep your current code", "Cancel in the toolbar",
                      "Cancel or dismiss the chooser to return without changing the editor. The sheet can be expanded when you want more room.", "xmark"),
            ]
        case .sandboxLessons:
            [
                .init("lesson", "Load a snippet", "The lesson-name rows",
                      "Tap a lesson to load the API form named by the section heading. The chooser closes first, then Sandbox asks to replace edited code if needed.", "doc.text"),
                .init("navigate", "Choose another group or cancel", "Back and Cancel in the toolbar",
                      "Back returns to the API groups. Cancel closes the whole chooser without changing the editor. Scroll the list to see more lessons.", "arrow.uturn.backward"),
            ]
        case .sandboxHelp:
            [
                .init("model", "Understand the model", "What runs and What it models",
                      "Read how snippets start and which queues, task pools, actors, waits, and APIs are supported. These sections explain how to interpret a run.", "cpu"),
                .init("limits", "Check the limits", "What it doesn't",
                      "Check language and isolation limitations before writing a snippet. The virtual clock and thread counts illustrate behavior; they do not measure your device's real runtime.", "exclamationmark.triangle"),
                .init("legend", "Read the output legend", "Reading the output",
                      "This section explains Trace, thread bars, Shuffle, and Cores. Done closes help and returns to the same editor and output.", "chart.bar.xaxis"),
            ]
        }
    }
}
