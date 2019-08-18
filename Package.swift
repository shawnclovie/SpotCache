// swift-tools-version:5.0

import PackageDescription

let package = Package(
	name: "SpotCache",
	products: [
		.library(
			name: "SpotCache",
			targets: ["SpotCache"]),
	],
	dependencies: [
		.package(url: "https://github.com/shawnclovie/Spot", .branch("master")),
	],
	targets: [
		.target(
			name: "SpotCache",
			dependencies: []),
	]
)
