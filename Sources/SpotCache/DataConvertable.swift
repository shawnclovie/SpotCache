//
//  Data.swift
//  Spot
//
//  Created by Shawn Clovie on 6/11/16.
//  Copyright © 2016 Shawn Clovie. All rights reserved.
//

import Foundation

public protocol DataConvertable {
	/// Type that could convert data to.
	associatedtype ItemType
	
	static func convert(from source: Data.Source) -> ItemType?
	
	func convertToData() -> Data?
}
