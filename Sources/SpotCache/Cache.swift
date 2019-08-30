//
//  Cache.swift
//  Spot
//
//  Created by Shawn Clovie on 6/9/16.
//  Copyright © 2016 Shawn Clovie. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import Spot

// Cache exists for 1 week
private let cacheMaxPeriodInSecond: TimeInterval = 86400 * 7

private let cacheDecodeQueue = DispatchQueue(label: "cache.decode", attributes: .concurrent)

private var sharedCaches = SynchronizableValue([String: AnyObject]())

public final class Cache<T: DataConvertable> {
	
	public static var shared: Cache<T> {
		let name = String(describing: T.self)
		let inst: Cache<T>
		if let exist = sharedCaches.get()[name] as? Cache<T> {
			inst = exist
		} else {
			inst = Cache<T>(name: "__shared")
			inst.maxMemoryCost = 1024000
			sharedCaches.waitAndSet {
				$0[name] = inst
			}
		}
		return inst
	}
	
	/// - parameters: URL, downloaded object
	public let fileDidDownloadEvent = EventObservable<(URL, AttributedResult<T>)>()
	/// - parameters: cleared file URLs
	public let diskCacheDidCleanEvent = EventObservable<[URL]>()
	/// - parameters: URL, percentage
	public let downloadingProgressEvent = EventObservable<(URL, Double)>()

	public let cacheDirectory: URL
	public let cacheFileExtension: String
	
	public var maxMemoryCost: UInt = 0 {
		didSet {
			memoryCache.totalCostLimit = Int(maxMemoryCost)
		}
	}
	public var maxDiskCacheSize: UInt = 0
	public var maxCachePeriodInSecond = cacheMaxPeriodInSecond
	
	private let memoryCache = NSCache<NSString, AnyObject>()
	
	private let ioQueue: DispatchQueue
	private var fileManager: FileManager!
	
	private var fetchingInfos = SynchronizableValue([URL: CacheFetchingInfo<T>]())
	
	private let notificationObserver = NotificationObserver()
	
	private let logger: Logger
	
	public init(name: String, path: URL? = nil, cacheFileExtension: String = "") {
		logger = .init(tag: "\(type(of: self)).\(name)", for: .spotcache)
		
		let cacheName = "SpotCache.\(T.self).\(name)"
		memoryCache.name = cacheName
		
		let dstPath = path ?? .spot_cachesPath
		cacheDirectory = dstPath.appendingPathComponent(cacheName)
		self.cacheFileExtension = cacheFileExtension
		
		ioQueue = DispatchQueue(label: cacheName + ".io", attributes: [])
		ioQueue.sync { 
			fileManager = FileManager()
		}
		
		#if os(iOS)
		notificationObserver.observe(UIApplication.didReceiveMemoryWarningNotification) { [weak self] _ in
			self?.memoryCache.removeAllObjects()
		}
		notificationObserver.observe(UIApplication.willTerminateNotification) { [weak self] _ in
			self?.cleanExpiredDiskCache(nil)
		}
		notificationObserver.observe(UIApplication.didEnterBackgroundNotification) { [weak self] _ in
			guard let self = self else {return}
			UIApplication.shared.spot.beginBackgroundTask {
				self.cleanExpiredDiskCache($0)
			}
		}
		#elseif os(macOS)
		
		#endif
	}
	
	// MARK: - Clear & Clean
	
	public func clearDiskCache(_ completion: ((Error?)->Void)? = nil) {
		ioQueue.async {
			var err: Error?
			do {
				let dir = self.cacheDirectory
				try self.fileManager.removeItem(at: dir)
				try self.fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
			} catch {
				err = error
			}
			if let fn = completion {
				DispatchQueue.main.spot.async(err, fn)
			}
		}
	}
	
	public func cleanExpiredDiskCache(_ completion: (()->Void)?) {
		// Do things in cocurrent io queue
		ioQueue.async {
			var (deletingURLs, diskCacheSize, cachedFiles) = self.travelCachedFiles(onlyForCacheSize: false)
			for fileURL in deletingURLs {
				do {
					try self.fileManager.removeItem(at: fileURL)
				} catch {
					self.logger.log(.error, messages: ["cleanExpiredDiskCache", error])
				}
			}
			if self.maxDiskCacheSize > 0 && diskCacheSize > self.maxDiskCacheSize {
				let targetSize = self.maxDiskCacheSize / 2
				// Sort files by last modify date. We want to clean from the oldest files.
				let sortedFiles = cachedFiles.spot_sortedKeysByValue { (res1, res2) in
					guard let date1 = res1.contentModificationDate,
						let date2 = res2.contentModificationDate else {
							// Not valid date information. This should not happen. Just in case.
							return true
					}
					return date1.compare(date2) == .orderedAscending
				}
				for fileURL in sortedFiles {
					do {
						try self.fileManager.removeItem(at: fileURL)
					} catch {
						self.logger.log(.error, messages: ["cleanExpiredDiskCache", error])
					}
					deletingURLs.append(fileURL)
					if let fileSize = cachedFiles[fileURL]?.totalFileAllocatedSize {
						diskCacheSize -= UInt(fileSize)
					}
					if diskCacheSize < targetSize {
						break
					}
				}
			}
			DispatchQueue.main.async {
				if !deletingURLs.isEmpty {
					self.diskCacheDidCleanEvent.dispatch(deletingURLs)
				}
				completion?()
			}
		}
	}
	
	private func travelCachedFiles(onlyForCacheSize: Bool) -> (deletingURLs: [URL], diskCacheSize: UInt, cachedFiles: [URL: URLResourceValues]) {
		let resourceKeys: Set<URLResourceKey> =
			[.isDirectoryKey, .contentModificationDateKey, .totalFileAllocatedSizeKey]
		let expiredDate = Date(timeIntervalSinceNow: -self.maxCachePeriodInSecond)
		
		var cachedFiles = [URL: URLResourceValues]()
		var deletingURLs = [URL]()
		var diskCacheSize: UInt = 0
		
		if let fileEnumerator = fileManager
			.enumerator(at: cacheDirectory,
			            includingPropertiesForKeys: resourceKeys.map {$0},
			            options: .skipsHiddenFiles,
			            errorHandler: nil),
			let urls = fileEnumerator.allObjects as? [URL] {
			for fileURL in urls {
				do {
					let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
					// If it is a Directory. Continue to next file URL.
					if resourceValues.isDirectory ?? false {
						continue
					}
					// If this file is expired, add it to deletingURLs
					if !onlyForCacheSize &&
						(resourceValues.contentModificationDate as NSDate?)?.laterDate(expiredDate) == expiredDate {
						deletingURLs.append(fileURL)
						continue
					}
					if let fileSize = resourceValues.totalFileAllocatedSize {
						diskCacheSize += UInt(fileSize)
						if !onlyForCacheSize {
							cachedFiles[fileURL] = resourceValues
						}
					}
				} catch {}
			}
		}
		return (deletingURLs, diskCacheSize, cachedFiles)
	}
}

// MARK: - Store & Remove

extension Cache {
	
	public func saveToMemoryCache(_ item: T, for url: URL) {
		memoryCache.setObject(item as AnyObject, forKey: url.spot_cacheKey as NSString)
	}
	
	public func saveToDisk(_ data: Data, downloadFrom url: URL, completion: ((Bool)->Void)?) {
		ioQueue.async {
			let cachePath = self.cachePath(for: url)
			var success = false
			do {
				let dir = self.cacheDirectory
				if !self.fileManager.fileExists(atPath: dir.path) {
					try self.fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
				}
				success = self.fileManager.createFile(atPath: cachePath.path, contents: data, attributes: nil)
			} catch {
			}
			if let fn = completion {
				DispatchQueue.main.spot.async(success, fn)
			}
		}
	}
	
	public func removeItem(downloadFrom url: URL,
	                       fromDisk: Bool = true,
	                       completion: ((Error?)->Void)? = nil) {
		let key = url.spot_cacheKey
		memoryCache.removeObject(forKey: key as NSString)
		if fromDisk {
			ioQueue.async {
				var err: Error?
				do {
					try self.fileManager.removeItem(at: self.cachePath(for: url))
				} catch {
					err = error
				}
				if let fn = completion {
					DispatchQueue.main.spot.async(err, fn)
				}
			}
		} else if let fn = completion {
			DispatchQueue.main.spot.async(.none, fn)
		}
	}
}

// MARK: - Get data from cache

extension Cache {
	
	public func retrieveItem(for url: URL, completion: @escaping (AttributedResult<T>)->Void) {
		retrieveItem(keyed: url.spot_cacheKey, completion: completion)
	}
	
	public func retrieveItem(for url: URL) throws -> T {
		let key = url.spot_cacheKey
		if let item = retrieveInMemoryCache(keyed: key) {
			return item
		}
		return try retrieveInDiskCache(keyed: key)
	}
	
	public func retrieveItemInMemoryCache(for url: URL) -> T? {
		retrieveInMemoryCache(keyed: url.spot_cacheKey)
	}
	
	@discardableResult
	private func retrieveItem(keyed key: String, completion: @escaping (AttributedResult<T>)->Void) -> (()->Void)? {
		if let item = retrieveInMemoryCache(keyed: key) {
			completion(.success(item))
			return nil
		}
		var sself = Optional(self)
		let block = {
			do {
				let item = try sself!.retrieveInDiskCache(keyed: key)
				DispatchQueue.main.async {
					completion(.success(item))
					sself = nil
				}
			} catch {
				completion(.failure(error as? AttributedError ?? .init(.io, original: error)))
				sself = nil
			}
		}
		ioQueue.async(execute: block)
		return block
	}
	
	private func retrieveInMemoryCache(keyed key: String) -> T? {
		memoryCache.object(forKey: key as NSString) as? T
	}
	
	private func retrieveInDiskCache(keyed key: String) throws -> T {
		let file = cacheFile(keyed: key)
		if !fileManager.fileExists(atPath: file.path) {
			throw AttributedError(.fileNotFound, object: key, userInfo: ["file": file])
		}
		if let value = T.convert(from: .path(file)) as? T {
			return value
		}
		throw AttributedError(.invalidFormat, object: key, userInfo: ["file": file])
	}
}

extension Cache {
	public func cachePath(for url: URL) -> URL {
		cacheFile(keyed: url.spot_cacheKey)
	}
	
	func cacheFile(keyed key: String) -> URL {
		let dir = cacheDirectory
		if !fileManager.fileExists(atPath: dir.path) {
			do {
				try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
			} catch {
				logger.log(.error, messages: ["makeCacheDirectory", error])
			}
		}
		return dir.appendingPathComponent(key)
			.appendingPathExtension(cacheFileExtension)
	}
}

extension Cache {
	/// Check url cache exist on disk or memory or neither..
	/// - parameter url: URL to check
	public func isCacheExists(for url: URL, in target: CacheTarget) -> Bool {
		let key = url.spot_cacheKey
		switch target {
		case .disk:
			let cachePath = self.cacheFile(keyed: key).path
			return fileManager.fileExists(atPath: cachePath)
		case .memory:
			return memoryCache.object(forKey: key as NSString) != nil
		}
	}
	
	public func isFetchingURL(_ url: URL) -> Bool {
		return fetchingInfos.waitAndGet()[url] != nil
	}
	
	/// Fetch (download) data from url.
	/// - parameter url:        URL
	/// - parameter options:    Cache options
	/// - parameter progress:   Download progress callback
	/// - parameter completion: Download completion callback
	public func fetch(_ url: URL,
	                  options: [CacheOption] = [],
	                  progress: ((URLTask.Progress)->Void)? = nil,
	                  completion: ((AttributedResult<T>)->Void)? = nil) {
		let optInfo = CacheOptionInfo(options)
		let fnRetrived = { (result: AttributedResult<T>) in
			if case .success(_) = result {
				completion?(result)
				return
			}
			let download = self.fetchingInfos.waitAndGet()[url] == nil
			if progress != nil || completion != nil {
				self.fetchingInfos.waitAndSet {
					if download {
						$0[url] = .init()
					}
					$0[url]?.dispatches.append(.init(options: optInfo, progression: progress, completion: completion))
				}
			}
			if download {
				self.request(url, option: optInfo)
			}
		}
		if optInfo.forceRefresh && !fetchingInfos.waitAndGet().keys.contains(url) {
			fnRetrived(.failure(AttributedError(.itemNotFound, object: url)))
		} else {
			retrieveItem(keyed: url.spot_cacheKey, completion: fnRetrived)
		}
	}
	
	private func request(_ url: URL, option: CacheOptionInfo) {
		var req = URLRequest.spot(.get, url)
		if let actor = option.requestModifier {
			req = actor.modified(request: req)
		}
		let cacheFile = self.cacheFile(keyed: url.spot_cacheKey)
		let tempPath = cacheFile.appendingPathExtension(String(Date().timeIntervalSince1970))
		let shouldSaveFile = option.cacheTargets.contains(.disk)
		let task = URLTask(req, for: shouldSaveFile ? .download(saveAsFile: tempPath) : .data)
		_ = task.progressEvent.subscribe {
			self.downloadingProgressEvent.dispatch((url, $0.percentage))
			self.fetchingInfos.waitAndGet()[url]?.progressing($0)
		}
		_ = task.downloadedEvent.subscribe { (path, error) in
			if let err = error {
				self.logger.log(.error, messages: ["downloaded", err])
			}
		}
		_ = task.completeEvent.subscribe { (task, result) in
			switch result {
			case .success(let data):
				let status = task.respondStatusCode ?? 404
				let success = status < 400
				if shouldSaveFile {
					// Other process may downloading same file.
					if !success || self.fileManager.fileExists(atPath: cacheFile.path) {
						do {
							try self.fileManager.removeItem(at: tempPath)
						} catch {
							self.logger.log(.error, messages: ["remove temp file failed", tempPath])
						}
					} else {
						do {
							try self.fileManager.moveItem(at: tempPath, to: cacheFile)
						} catch {
							self.logger.log(.error, messages: ["moving failed", tempPath, "->", cacheFile])
						}
					}
				}
				guard success else {
					let source: AttributedError.Source
					switch status {
					case 404:			source = .itemNotFound
					case 403:			source = .privilegeLimited
					case 500..<(.max):	source = .server
					default:			source = .serviceMissing
					}
					self.requestDidFinish(url, result: .failure(.init(source, object: url, userInfo: ["status": status, "respondData": task.respondData])))
					return
				}
				let fn = {
					let result: AttributedResult<T>
					if shouldSaveFile {
						do {
							result = .success(try self.retrieveInDiskCache(keyed: url.spot_cacheKey))
						} catch {
							result = .failure(.init(with: error, .io))
						}
					} else if let item = T.convert(from: .data(data)) as? T {
						result = .success(item)
					} else {
						result = .failure(.init(.invalidFormat, object: data))
					}
					if option.cacheTargets.contains(.memory), let item = try? result.get() {
						self.saveToMemoryCache(item, for: url)
					}
					self.requestDidFinish(url, result: result)
				}
				if option.backgroundDecode {
					cacheDecodeQueue.async(execute: fn)
				} else {
					fn()
				}
			case .failure(let err):
				self.requestDidFinish(url, result: .failure(err))
			}
		}
		fetchingInfos.waitAndSet {
			$0[url]?.task = task
		}
		task.request(priority: option.downloadPriority)
	}
	
	private func requestDidFinish(_ url: URL, result: AttributedResult<T>) {
		fileDidDownloadEvent.dispatch((url, result))
		fetchingInfos.waitAndSet {
			$0.removeValue(forKey: url)?.completed(result)
		}
	}
	
	/// Cancel fetching task.
	/// - parameter url:            URL of task.
	/// - parameter stopConnection: Stop url connection too.
	public func cancelFetching(_ url: URL, stopConnection: Bool = false) {
		var info: CacheFetchingInfo<T>?
		fetchingInfos.waitAndSet {
			info = $0.removeValue(forKey: url)
		}
		if stopConnection {
			info?.task?.cancel()
		}
	}
}

extension URL {
	fileprivate var spot_cacheKey: String {
		absoluteString.spot.md5
	}
}

extension Dictionary {
	fileprivate func spot_sortedKeysByValue(by order: (Value, Value) -> Bool) -> [Key] {
		Array(self).sorted {order($0.1, $1.1)}.map {$0.0}
	}
}
