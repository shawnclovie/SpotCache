//
//  CacheFetchingInfo.swift
//  Spot
//
//  Created by Shawn Clovie on 5/3/2018.
//  Copyright © 2018 Shawn Clovie. All rights reserved.
//

import Foundation
import Spot

struct CacheFetchingInfo<T: DataConvertable> {
	var task: URLTask?
	var options: [CacheOption] = []
	var progresses: [(URLTask.Progress)->Void] = []
	var completions: [(AttributedResult<T>)->Void] = []
	
	mutating func add(_ options: [CacheOption], progress: ((URLTask.Progress)->Void)?, completion: ((AttributedResult<T>)->Void)?) {
		self.options.append(contentsOf: options)
		if let fn = progress {
			progresses.append(fn)
		}
		if let fn = completion {
			completions.append(fn)
		}
	}
	
	func progressing(_ progress: URLTask.Progress) {
		guard !progresses.isEmpty else {
			return
		}
		for fn in progresses {
			fn(progress)
		}
	}
	
	func completed(_ result: AttributedResult<T>) {
		guard !completions.isEmpty else {
			return
		}
		let fns = completions
		options.callbackQueue.async {
			for fn in fns {
				fn(result)
			}
		}
	}
}
