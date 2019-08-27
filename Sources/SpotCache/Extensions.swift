//
//  Foundation+Cache.swift
//  Spot
//
//  Created by Shawn Clovie on 20/02/2017.
//  Copyright © 2017 Shawn Clovie. All rights reserved.
//

import Foundation
import Spot
#if canImport(UIKit)
import UIKit
#endif

extension Suffix where Base == URL {
	var cacheKey: String {
		base.absoluteString.spot.md5
	}
}

extension Dictionary {
	func sortedKeysByValue(by order: (Value, Value) -> Bool) -> [Key] {
		Array(self).sorted {order($0.1, $1.1)}.map {$0.0}
	}
}

extension Data: DataConvertable {
	public typealias ItemType = Data
	
	public static func convert(from source: Data.Source) -> Data? {
		source.data
	}
	
	public func convertToData() -> Data? {
		self
	}
}

extension URL: DataConvertable {
	public static func convert(from source: Data.Source) -> URL? {
		source.path
	}
	
	public func convertToData() -> Data? {
		try? Data(contentsOf: self)
	}
}

#if canImport(UIKit)
extension UIImage: DataConvertable {
	
	public static func convert(from source: Data.Source) -> UIImage? {
		guard let data = source.data else {
			return nil
		}
		return UIImage(data: data, scale: UIScreen.main.scale)
	}
	
	public func convertToData() -> Data? {
		spot.encode(as: spot.hasAlpha ? .png : .jpeg(quality: 0.8))
	}
}
#endif
