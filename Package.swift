// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "EasyEnglish",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "EasyEnglish.app", targets: ["EasyEnglish"]),
        .executable(name: "import_database", targets: ["import_database"]),
        .executable(name: "update_roots", targets: ["update_roots"])
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.13.2")
    ],
    targets: [
        .executableTarget(
            name: "EasyEnglish",
            dependencies: [.product(name: "SQLite", package: "SQLite.swift")],
            path: "Sources/EasyEnglishApp",
            resources: [.copy("Resources")]
        ),
        .executableTarget(
            name: "import_database",
            dependencies: [.product(name: "SQLite", package: "SQLite.swift")],
            path: "scripts",
            exclude: ["update_roots.swift"],
            sources: ["import_database.swift"]
        ),
        .executableTarget(
            name: "update_roots",
            dependencies: [.product(name: "SQLite", package: "SQLite.swift")],
            path: "scripts",
            exclude: ["import_database.swift"],
            sources: ["update_roots.swift"]
        ),
        .testTarget(
            name: "EasyEnglishTests",
            dependencies: ["EasyEnglish"],
            path: "Tests/EasyEnglishTests"
        )
    ]
)