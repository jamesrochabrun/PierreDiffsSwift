# PierreDiffsSwift

A Swift package for rendering beautiful, syntax-highlighted code diffs in macOS applications using the [@pierre/diffs](https://www.npmjs.com/package/@pierre/diffs) JavaScript library.

## Dark Mode
<img width="859" height="990" alt="Image" src="https://github.com/user-attachments/assets/4eb8df72-308b-4f99-9bc9-acdb347a11e6" />
<img width="840" height="632" alt="Image" src="https://github.com/user-attachments/assets/5701be1a-55ee-4c53-9d81-1cfdb38c22fa" />

## Light Mode
<img width="852" height="984" alt="Image" src="https://github.com/user-attachments/assets/9c6a62c5-8ff5-465d-84b1-a025a9272bc1" />
<img width="832" height="612" alt="Image" src="https://github.com/user-attachments/assets/0ae99c27-8aba-4523-a7e9-031a8cf9b940" />

## Features

- Rich syntax highlighting via Shiki (supports 40+ languages)
- Split and unified diff view modes
- Inline word-level change highlighting
- Dark/light theme support (auto-detects system preference)
- Scroll or wrap overflow modes
- Line click callbacks for custom interactions
- SwiftUI-native views wrapping WKWebView

## Requirements

- macOS 14.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add PierreDiffsSwift to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/jamesrochabrun/PierreDiffsSwift.git", from: "1.0.0")
]
```

Or in Xcode: File > Add Package Dependencies... and enter the repository URL.

## Quick Start

### Basic Diff Rendering

```swift
import SwiftUI
import PierreDiffsSwift

struct ContentView: View {
    @State private var diffStyle: DiffStyle = .split
    @State private var overflowMode: OverflowMode = .scroll

    var body: some View {
        PierreDiffView(
            oldContent: "let x = 1\nlet y = 2",
            newContent: "let x = 1\nlet y = 3\nlet z = 4",
            fileName: "example.swift",
            diffStyle: $diffStyle,
            overflowMode: $overflowMode
        )
        .frame(height: 400)
    }
}
```

## API Reference

### Views

#### `PierreDiffView`

Low-level SwiftUI view that renders diffs using WKWebView and the @pierre/diffs library.

```swift
PierreDiffView(
    oldContent: String,           // Original file content
    newContent: String,           // Updated file content
    fileName: String,             // Filename for syntax detection
    diffStyle: Binding<DiffStyle>,
    overflowMode: Binding<OverflowMode>,
    onLineClick: ((Int, String) -> Void)? = nil,
    onExpandRequest: (() -> Void)? = nil
)
```

#### `DiffEditsView`

High-level view that processes edit tool responses (Edit, MultiEdit, Write) and renders the resulting diff.

```swift
DiffEditsView(
    messageID: UUID,
    editTool: EditTool,
    toolParameters: [String: String],
    projectPath: String? = nil,
    onExpandRequest: (() -> Void)? = nil,
    diffStore: DiffStateManager? = nil,
    diffLifecycleState: DiffLifecycleState? = nil
)
```

#### `DiffModalView`

Full-screen modal wrapper for displaying diffs with a close button.

```swift
DiffModalView(
    messageID: UUID,
    editTool: EditTool,
    toolParameters: [String: String],
    projectPath: String? = nil,
    diffStore: DiffStateManager? = nil,
    diffLifecycleState: DiffLifecycleState? = nil,
    onDismiss: @escaping () -> Void
)
```

#### `CompactDiffStatusView`

Compact view showing that changes have been reviewed, with tap-to-expand.

```swift
CompactDiffStatusView(
    fileName: String,
    timestamp: Date?,
    onTapToExpand: @escaping () -> Void
)
```

### Types

#### `DiffStyle`

```swift
enum DiffStyle: String, CaseIterable {
    case split    // Side-by-side view
    case unified  // Single column view
}
```

#### `OverflowMode`

```swift
enum OverflowMode: String, CaseIterable {
    case scroll  // Horizontal scrolling for long lines
    case wrap    // Word wrap long lines
}
```

#### `EditTool`

```swift
enum EditTool: String {
    case edit      // Single edit operation
    case multiEdit // Multiple edits in one file
    case write     // Write entire file content
}
```

#### `DiffResult`

```swift
struct DiffResult: Equatable, Codable {
    var filePath: String
    var fileName: String
    var original: String
    var updated: String
    var isInitial: Bool
}
```

### State Management

#### `DiffStateManager`

Observable class for managing diff state across your application.

```swift
@Observable
class DiffStateManager {
    func getState(for messageID: UUID) -> DiffState
    func process(diffs: [DiffResult], for messageID: UUID) async
    func removeState(for messageID: UUID)
    func clearAllStates()
}
```

### Processing

#### `DiffResultProcessor`

Processes edit tool responses to generate diff results.

```swift
struct DiffResultProcessor {
    init(fileDataReader: FileDataReader)

    func processEditTool(
        response: String,
        tool: EditTool
    ) async -> [DiffResult]?
}
```

### Protocols

#### `FileDataReader`

Protocol for reading file contents. Default implementation provided.

```swift
protocol FileDataReader {
    var projectPath: String? { get }
    func readFileContent(in paths: [String], maxTasks: Int) async throws -> [String: String]
    func cancelCurrentTask()
}

// Default implementation
class DefaultFileDataReader: FileDataReader
```

## Examples

### Processing Edit Tool Response

```swift
import PierreDiffsSwift

// Create processor with file reader
let processor = DiffResultProcessor(
    fileDataReader: DefaultFileDataReader(projectPath: "/path/to/project")
)

// Process an edit response
let toolResponse = """
{
    "file_path": "/path/to/file.swift",
    "old_string": "let x = 1",
    "new_string": "let x = 2"
}
"""

if let results = await processor.processEditTool(response: toolResponse, tool: .edit) {
    // Use results with DiffStateManager or display directly
}
```

### Using DiffEditsView with Parameters

```swift
DiffEditsView(
    messageID: UUID(),
    editTool: .edit,
    toolParameters: [
        "file_path": "/path/to/file.swift",
        "old_string": "let x = 1",
        "new_string": "let x = 2"
    ],
    projectPath: "/path/to/project"
)
```

### Managing Multiple Diffs

```swift
struct MyView: View {
    @State private var diffStore = DiffStateManager()

    var body: some View {
        ForEach(messages) { message in
            DiffEditsView(
                messageID: message.id,
                editTool: message.editTool,
                toolParameters: message.parameters,
                diffStore: diffStore
            )
        }
    }
}
```

## Rebuilding the JavaScript Bundle

The package includes a pre-built JavaScript bundle. To rebuild it:

```bash
cd scripts
npm install
npm run build
```

This generates `pierre-diffs-bundle.js` which should be copied to `Sources/PierreDiffsSwift/Resources/`.

## Supported Languages

The package supports syntax highlighting for 40+ languages including:
Swift, JavaScript, TypeScript, Python, Go, Rust, Java, Kotlin, C, C++, Ruby, PHP, SQL, HTML, CSS, JSON, YAML, Markdown, and more.

Language is auto-detected from the filename extension.

## License

MIT
