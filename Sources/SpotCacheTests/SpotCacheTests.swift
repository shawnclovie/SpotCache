//
//  SpotCacheTests.swift
//  SpotCacheTests
//
//  Created by Shawn Clovie on 18/8/2019.
//  Copyright © 2019 Spotlit.club. All rights reserved.
//

import XCTest
@testable import SpotCache

class SpotCacheTests: XCTestCase {

    override func setUp() {
    }

    override func tearDown() {
    }

    func testCache() {
		var expections: [XCTestExpectation] = []
		let cacheURLs = [
			URL(string: "https://media.riffsy.com/images/5ce76a640011902a79b484da92b0d7db/raw")!,
			URL(string: "https://media.riffsy.com/images/cec933defd3ff8c1590c5a0bc380540c/raw")!,
			]
		for url in cacheURLs {
			let exp = XCTestExpectation()
			Cache<UIImage>.shared.fetch(url, options: [.backgroundDecode], progress: { (progress) in
				print("\(url) progress \(Int(progress.percentage*100))%")
			}, completion: { (result) in
				print("\(url) complete \(result)")
				print((try? Cache<UIImage>.shared.retrieveItem(for: url)) as Any)
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
