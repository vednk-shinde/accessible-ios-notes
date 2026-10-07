// swift-tools-version:5.9
import PackageDescription

// NotesCore holds all UI-independent logic (encryption, search, accessibility
// phrasing) so it can be unit-tested with `swift test` on any Apple platform.
let package = Package(
    name: "NotesCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "NotesCore", targets: ["NotesCore"])],
    targets: [
        .target(name: "NotesCore"),
        .testTarget(name: "NotesCoreTests", dependencies: ["NotesCore"]),
    ]
)
