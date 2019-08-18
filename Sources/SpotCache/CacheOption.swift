//
//  CacheOption.swift
//  Spot
//
//  Created by Shawn Clovie on 6/11/16.
//  Copyright © 2016 Shawn Clovie. All rights reserved.
//

import Foundation
import CoreGraphics

public enum CacheOption {
	case cacheTargets([CacheTarget])
	case downloadPriority(Float)
	case forceRefresh
	case backgroundDecode
	case scaleFactor(CGFloat)
	case callbackQueue(DispatchQueue?)
}

public func ==(lhs: CacheOption, rhs: CacheOption) -> Bool {
	switch (lhs, rhs) {
	case (.cacheTargets(_), .cacheTargets(_)):			fallthrough
	case (.downloadPriority(_), .downloadPriority(_)):	fallthrough
	case (.forceRefresh, .forceRefresh):				fallthrough
	case (.backgroundDecode, .backgroundDecode):		fallthrough
	case (.scaleFactor(_), .scaleFactor(_)):			fallthrough
	case (.callbackQueue(_), .callbackQueue(_)):		return true
	default:return false
	}
}

extension Collection where Iterator.Element == CacheOption {
	func findOption(_ target: Iterator.Element) -> Iterator.Element? {
		firstIndex {$0 == target}.flatMap {self[$0]}
	}
	
	public var cacheTargets: [CacheTarget] {
		if let item = findOption(.cacheTargets([])),
			case .cacheTargets(let tar) = item {
			return tar
		}
		return [.disk, .memory]
	}
	
	public var downloadPriority: Float {
		if let item = findOption(.downloadPriority(0)),
			case .downloadPriority(let priority) = item {
			return priority
		}
		return URLSessionTask.defaultPriority
	}
	
	public var forceRefresh: Bool {
		contains {$0 == .forceRefresh}
	}
	
	public var backgroundDecode: Bool {
		contains {$0 == .backgroundDecode}
	}
	
	public var scaleFactor: CGFloat {
		if let item = findOption(.scaleFactor(0)),
			case .scaleFactor(let scale) = item {
			return scale
		}
		return 1
	}
	
	var callbackQueue: DispatchQueue {
		if let item = findOption(.callbackQueue(nil)),
			case .callbackQueue(let queue) = item {
			return queue ?? DispatchQueue.main
		}
		return DispatchQueue.main
	}
}
