// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PierreDiffsSwift",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "PierreDiffsSwift",
      targets: ["PierreDiffsSwift"]
    ),
  ],
  targets: [
    .target(
      name: "PierreDiffsSwift",
      resources: [
        .copy("Resources/pierre-diffs-bundle.js")
      ]
    ),
    .testTarget(
      name: "PierreDiffsSwiftTests",
      dependencies: ["PierreDiffsSwift"]
    ),
  ]
)
