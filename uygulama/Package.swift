// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Fotora",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Metni modelin parçalarına bölmek için (Gemma sözlüğü). Apache 2.0.
        .package(url: "https://github.com/huggingface/swift-transformers", exact: "1.3.4"),
    ],
    targets: [
        .target(name: "FotoraCore", dependencies: [.product(name: "Tokenizers", package: "swift-transformers")], linkerSettings: [.linkedLibrary("sqlite3")]),
        .executableTarget(name: "fotora-tara", dependencies: ["FotoraCore"]),
        .executableTarget(name: "Fotora", dependencies: ["FotoraCore"]),
        .executableTarget(name: "fotora-ara", dependencies: ["FotoraCore"]),
        .executableTarget(name: "fotora-test", dependencies: ["FotoraCore"]),
    ]
)
