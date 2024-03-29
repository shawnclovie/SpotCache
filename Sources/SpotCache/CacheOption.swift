//
//  CacheOption.swift
//  Spot
//
//  Created by Shawn Clovie on 6/11/16.
//  Copyright © 2016 Shawn Clovie. All rights reserved.
//

import Foundation
import CoreGraphics
import Spot

public protocol CacheURLRequestModifier {
	func modified(request: URLRequest) -> URLRequest
}

public enum CacheOption {
	case cacheTargets([CacheTarget])
	case connection(URLConnection)
	case downloadPriority(Float)
	case forceRefresh
	case backgroundDecode
	case callbackQueue(DispatchQueue)
	case requestModifier(CacheURLRequestModifier)
}

struct CacheOptionInfo {
	var cacheTargets: [CacheTarget] = []
	var downloadPriority: Float = URLSessionTask.defaultPriority
	var connection: URLConnection = .default
	var forceRefresh = false
	var backgroundDecode = false
	var callbackQueue: DispatchQueue?
	var requestModifier: CacheURLRequestModifier?
	
	init(_ opts: [CacheOption]) {
		for opt in opts {
			switch opt {
			case .cacheTargets(let it):		cacheTargets = it
			case .downloadPriority(let it):	downloadPriority = it
			case .forceRefresh:				forceRefresh = true
			case .backgroundDecode:			backgroundDecode = true
			case .connection(let it):		connection = it
			case .callbackQueue(let it):	callbackQueue = it
			case .requestModifier(let it):	requestModifier = it
			}
		}
	}
}
