// swift-tools-version:5.0

import PackageDescription

let package = Package(
	name: "SpotCache",
	products: [
		.library(name: "SpotCache", targets: ["SpotCache"]),
	],
	dependencies: [
		.package(url: "https://github.com/shawnclovie/Spot",
				 .upToNextMajor(from: "1.0.0")),
	],
	targets: [
		.target(name: "SpotCache", dependencies: ["Spot"]),
		.testTarget(name: "SpotCacheTests", dependencies: ["Spot", "SpotCache"])
	]
)
