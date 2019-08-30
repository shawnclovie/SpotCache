//
//  ViewController.swift
//  SpotCacheTestApp
//
//  Created by Shawn Clovie on 30/8/2019.
//  Copyright © 2019 Spotlit.club. All rights reserved.
//

import UIKit
import Spot
import SpotCache

let lastCacheURLStringItem = UserDefaultsItem("lastCacheURLString", defaultValue: "")

class ViewController: UIViewController {
	
	let messageView = UITextView()
	let urlInputField = UITextField()
	
	let logger = Logger(tag: "\(ViewController.self)", for: .trace)
	
	var inputURL: URL? {URL(string: urlInputField.text ?? "")}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		logger.setTime(enabled: true)
		
		navigationItem.leftBarButtonItems = [
			.init(title: "X message", style: .plain, target: self, action: #selector(touchUp(clearMessage:))),
			.init(title: "X cache", style: .plain, target: self, action: #selector(touchUp(clearCache:))),
			]
		navigationItem.rightBarButtonItem = .init(title: "hide keyboard", style: .plain, target: self, action: #selector(touchUp(hideKeyboard:)))
		view.backgroundColor = .white
		messageView.backgroundColor = .clear
		messageView.font = UIFont(name: "Menlo", size: 12)
		urlInputField.placeholder = "Input URL here then Press Go"
		urlInputField.autocapitalizationType = .none
		urlInputField.autocorrectionType = .no
		urlInputField.keyboardType = .URL
		urlInputField.returnKeyType = .go
		urlInputField.delegate = self
		urlInputField.layer.borderColor = UIColor.darkGray.cgColor
		urlInputField.layer.borderWidth = 0.5
		let showContentButton = UIButton(type: .system)
		showContentButton.setTitle("Content", for: .normal)
		showContentButton.addTarget(self, action: #selector(touchUp(showContent:)), for: .touchUpInside)
		showContentButton.setContentCompressionResistancePriority(.required, for: .horizontal)
		showContentButton.setContentHuggingPriority(.required, for: .horizontal)
		[messageView, urlInputField, showContentButton].forEach{
			$0.translatesAutoresizingMaskIntoConstraints = false
			view.addSubview($0)
		}
		let spacing: CGFloat = 4
		[
			urlInputField.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
			urlInputField.heightAnchor.constraint(equalToConstant: 40),
			urlInputField.leftAnchor.constraint(equalTo: view.leftAnchor, constant: spacing),
			showContentButton.leftAnchor.constraint(equalTo: urlInputField.rightAnchor),
			showContentButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -spacing),
			showContentButton.centerYAnchor.constraint(equalTo: urlInputField.centerYAnchor),
			showContentButton.heightAnchor.constraint(equalTo: urlInputField.heightAnchor),
			messageView.topAnchor.constraint(equalTo: urlInputField.bottomAnchor),
			messageView.leftAnchor.constraint(equalTo: view.leftAnchor),
			messageView.rightAnchor.constraint(equalTo: view.rightAnchor),
			messageView.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor, constant: -spacing),
			].forEach{$0.isActive = true}
		
		urlInputField.text = lastCacheURLStringItem.value
		urlInputField.becomeFirstResponder()
	}
	
	@objc private func touchUp(hideKeyboard: Any) {
		urlInputField.resignFirstResponder()
		messageView.resignFirstResponder()
	}
	
	@objc private func touchUp(clearCache: Any) {
		Cache<URL>.shared.clearDiskCache()
	}
	
	@objc private func touchUp(clearMessage: Any) {
		messageView.text = ""
	}
	
	@objc private func touchUp(showContent: Any) {
		guard let url = inputURL else {
			showAlert(message: "🙀Inputing URL invalid")
			return
		}
		do {
			let path = try Cache<URL>.shared.retrieveItem(for: url)
			let content = try String(contentsOf: path)
			showAlert(message: content)
		} catch {
			showAlert(message: "🙀Failed to retrive \(url)\n\(error)")
		}
	}
	
	func showAlert(message: String) {
		let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
		alert.addAction(.init(title: "OK", style: .default, handler: nil))
		present(alert, animated: true, completion: nil)
	}
	
	func log(_ msgs: [Any]) {
		logger.log(.trace, messages: msgs)
		messageView.text += "\(msgs)\n"
	}
}

extension ViewController: UITextFieldDelegate {
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		let text = textField.text ?? ""
		if let url = URL(string: text) {
			lastCacheURLStringItem.set(text)
			Cache<URL>.shared.fetch(url, options: [.cacheTargets([.disk]), .requestModifier(self), .callbackQueue(.main)], progress: {
				self.log(["\(url) progress \($0.totalBytesWritten)/\($0.totalBytesExpected)"])
			}, completion: {
				self.log(["\(url) complete", $0])
			})
		} else {
			log(["invalid url:", text])
		}
		return true
	}
}

extension ViewController: CacheURLRequestModifier {
	func modified(request: URLRequest) -> URLRequest {
		var new = request
		new.allHTTPHeaderFields = [
			"User-Agent": "Mozilla/5.0 AppleWebKit/537.36; iOS 10.2)",
			"Accept": "text/html,image/webp,image/apng,*/*;q=0.8",
			"Accept-Encoding": "identity",
			"Accept-Language": "zh-CN,zh,en",
			"Connection": "keep-alive",
			"Upgrade-Insecure-Requests": "1",
		]
		return new
	}
}
