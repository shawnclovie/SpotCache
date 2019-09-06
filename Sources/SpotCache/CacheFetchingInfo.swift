//
//  CacheFetchingInfo.swift
//  Spot
//
//  Created by Shawn Clovie on 5/3/2018.
//  Copyright © 2018 Shawn Clovie. All rights reserved.
//

import Foundation
import Spot

final class CacheFetchingInfo<T: DataConvertable> {
	
	struct DispatchInfo {
		var options: CacheOptionInfo
		var progression: ((URLTask.Progress)->Void)?
		var completion: ((AttributedResult<T>)->Void)?
	}
	
	var task: URLTask?
	var dispatches: [DispatchInfo] = []
	
	init() {}
	
	func progressing(_ progress: URLTask.Progress) {
		guard !dispatches.isEmpty else {
			return
		}
		for it in dispatches {
			guard let fn = it.progression else {continue}
			if let queue = it.options.callbackQueue {
				queue.spot.async(progress, fn)
			} else {
				fn(progress)
			}
		}
	}
	
	func completed(_ result: AttributedResult<T>) {
		guard !dispatches.isEmpty else {
			return
		}
		for it in dispatches {
			guard let fn = it.completion else {continue}
			if let queue = it.options.callbackQueue {
				queue.spot.async(result, fn)
			} else {
				fn(result)
			}
		}
	}
}
