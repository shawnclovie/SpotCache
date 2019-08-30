//
//  SpotCacheTests.swift
//  SpotCacheTests
//
//  Created by Shawn Clovie on 18/8/2019.
//  Copyright © 2019 Spotlit.club. All rights reserved.
//

import XCTest
import Spot
@testable import SpotCache

struct RequestModifier: CacheURLRequestModifier {
	func modified(request: URLRequest) -> URLRequest {
		var new = request
		new.allHTTPHeaderFields = ["User-Agent": "Mozilla/5.0 (\(Version.deviceModelName); iOS \(Version.systemString))"]
		return new
	}
}

class SpotCacheTests: XCTestCase {

    override func setUp() {
    }

    override func tearDown() {
    }

    func testCache() {
		var expections: [XCTestExpectation] = []
		let cacheURLs = [
			"http://image.biaobaiju.com/uploads/20180802/03/1533150157-csMjhVNgZS.png",
			"http://img0.imgtn.bdimg.com/it/u=3616026612,3005758900&fm=26&gp=0.jpg",
			"https://media.riffsy.com/images/5ce76a640011902a79b484da92b0d7db/raw",
			].map{URL(string: $0)!}
		for url in cacheURLs {
			let exp = XCTestExpectation()
			let path = Cache<UIImage>.shared.cachePath(for: url)
			try? FileManager.default.removeItem(at: path)
			Cache<UIImage>.shared.fetch(url, options: [.cacheTargets([.disk]), .requestModifier(RequestModifier())], progress: { (progress) in
				print(url, "progress \(Int(progress.percentage*100))%")
			}, completion: { (result) in
				print(url, "complete", result)
				print(url, (try? Cache<UIImage>.shared.retrieveItem(for: url)) as Any)
				exp.fulfill()
			})
			expections.append(exp)
		}
		let exp = XCTestExpectation()
		Cache<URL>.shared.fetch(URL(string: "http://www.baidu.com")!) { result in
			print(result)
			exp.fulfill()
		}
		wait(for: expections, timeout: 10)
    }
}
