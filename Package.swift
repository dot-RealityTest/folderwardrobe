// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "folderwardrobe",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "folderwardrobe", targets: ["FolderColorApp"])
    ],
    targets: [
        .executableTarget(
            name: "FolderColorApp",
            path: "Sources/FolderColorApp"
        )
    ]
)
