//
//  WMNetwork.swift
//  WMNetwork
//
//  Created by Sasho on 11.02.17 г..
//  Copyright © 2017 г. . All rights reserved.
//

import Foundation
import UIKit

// to add headers and tokens together
func + <K,V> (left: Dictionary<K,V>, right: Dictionary<K,V>?) -> Dictionary<K,V> {
	guard let right = right else { return left }
	return left.reduce(right) {
		var new = $0 as [K:V]
		new.updateValue($1.1, forKey: $1.0)
		return new
	}
}

// to build post body
extension NSMutableData {
	func appendString(string: String) {
		let data = string.data(using: .utf8, allowLossyConversion: true)
		append(data!)
	}
}

// to check for networkactivityindicator
extension OperationQueue {
	var allDone: Bool {
		for op in self.operations {
			if op.isFinished == false {
				return false
			}
		}

		return true
	}

	var allSleeping: Bool {
		for op in self.operations {
			if op.isExecuting {
				return false
			}
		}

		return true
	}
}


// public interface - working with WMRequest class
class WMNet {
	static let shared = WMNet()

	static func defaultCachePolicy(wmReq: WMRequest) -> URLRequest.CachePolicy {
		switch wmReq.REQMethod {
		case .get:
			return URLRequest.CachePolicy.reloadIgnoringLocalCacheData

		default:
			return URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
		}

	}

	var cachePolicy: ((_ wmReq: WMRequest) -> URLRequest.CachePolicy) = WMNet.defaultCachePolicy

	var defaultHeaders: [String: String] = {
		var x: [String: String] = [
			"Accept": "application/json",
			"User-Agent": "WMNetwork Framework v. 0.5",
			]

		return x
	}()

	lazy var HTTP: URLSession = { () -> URLSession in
		let config = URLSessionConfiguration.default
		config.httpAdditionalHeaders 			= self.defaultHeaders
		config.timeoutIntervalForRequest 		= 40

		return URLSession(configuration: config)
	}()

	class public func post(_ urlString: String, params: ResponseDictionary? = nil, closure: NetCompHandler? = nil) -> WMRequest? {
		return req(urlString: urlString, method: .post, params: params, closure: closure)
	}

	class public func get(_ urlString: String, closure: NetCompHandler? = nil) -> WMRequest? {
		return req(urlString: urlString, method: .get, params: nil, closure: closure)
	}

	class public func req(urlString: String, method: WMRequestMethod, params: ResponseDictionary? = nil, closure: NetCompHandler? = nil) -> WMRequest? {
		let wmReq = WMRequest(URLString: urlString, methodParams: params, REQMethod: method, additionalHeaders: nil, netOpCompletionHandler: closure)
		wmReq.skipTokens = true /**** !!! for test only : tokens handling to come !!! ***/

		if WMRequest.addRequest(vsgReq: wmReq) {
			return wmReq
		}
		else {
			return nil
		}
	}

	private init() {}

	var networkOpQueue: OperationQueue = {
		var opQ = OperationQueue()
		opQ.maxConcurrentOperationCount = 2

		return opQ
	}()
}

class WMRequest: AsyncOperation { //, URLSessionTaskDelegate, URLSessionDelegate - TODO, challenges?
	var request:			URLRequest? = nil
	var URLString:        	String   // possible to contain variables like %s %u
	var REQMethod:          WMRequestMethod 		= .get
	var MethodParams:       MethodParamType?
	var URLParams:          URLParamType
	var responseData:       ResponseDictionary?
	var error:              NSError?
	var retryCount:			Int						= 0
	weak var delegate: 		WMNet?					= WMNet.shared

	var networkOperationCompletionHandler: NetCompHandler?
	var skipTokens:			Bool					= false

	init(URLString: String, methodParams: MethodParamType? = nil, REQMethod: WMRequestMethod = .get, additionalHeaders headers: ResponseDictionary? = nil, netOpCompletionHandler: NetCompHandler? = nil) {
		self.networkOperationCompletionHandler = netOpCompletionHandler
		self.URLString = URLString
		self.REQMethod = REQMethod
		self.MethodParams = methodParams
	}

	convenience init(oldR: WMRequest) {
		self.init(URLString: oldR.URLString, REQMethod: oldR.REQMethod, netOpCompletionHandler: oldR.networkOperationCompletionHandler)
		self.MethodParams = oldR.MethodParams
		self.skipTokens = oldR.skipTokens
		self.URLParams = oldR.URLParams
	}

	override func main() {
		retryCount += 1

		guard retryCount < 3 else {
			//NSLog("Too many tries in main() = %d.\nCall Sasho!", retryCount)

			return
		}

		let vTokens: TokensData? = nil
		guard skipTokens || vTokens != nil else {
			// here use dependencies? // .addDependency // login to get tokens?
			/*logOut()
			_ = logIn(withSuccessCHandler: {
			let vsgR = WMRequest(oldR: self) // here `self` isFinished!, so recreate it below to execute it again , now with the correct tokens.
			_ = WMRequest.addRequest(vsgReq: vsgR)
			})*/

			return
		}

		let del = delegate ?? WMNet.shared
		let headers: TokensData = del.defaultHeaders + ( skipTokens ? nil : vTokens )
		var queryString: String = "" // ? + stuff
		// this below might get deprecated as in often URL params are String(format:)'ed into the url
		if let urlParams = self.URLParams as URLParamType, urlParams.count > 0 {
			queryString = "?"
			for param in urlParams.keys {
				queryString += param + "=" + (urlParams[param]!.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed))! + "&"
			}
		}

		DispatchQueue.main.async {
			UIApplication.shared.isNetworkActivityIndicatorVisible = true
		}

		// makeRequest is to be overriden for different wmrequests (e.g. upload file, download...)
		self.request = makeRequest(queryString: queryString, headers: headers)
	}

	func makeRequest(queryString qs: String, headers: TokensData) -> URLRequest {
		let url = URL(string: URLString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)! + qs)!
		let request = NSMutableURLRequest(url: url)
		request.httpMethod = REQMethod.rawValue
		let del = delegate ?? WMNet.shared
		request.cachePolicy = del.cachePolicy(self)// HTTP.configuration.requestCachePolicy

		for (hf, hv) in headers {
			request.setValue(hv, forHTTPHeaderField: hf)
		}

		let boundary = "Boundary-\(UUID.init())"

		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

		request.httpBody = WMRequest.createBodyWithParameters(boundary: boundary, parameters: MethodParams) as Data

		let task = del.HTTP.dataTask(with: request as URLRequest) { (data, response, error) in
			var responseResult: ResponseDictionary? = nil
			var err: Error? = nil

			defer {
				if let netOpCH = self.networkOperationCompletionHandler {
					netOpCH(responseResult, err as NSError?)
				}

				self.completeOperation()
			}

			func setError(withText text: String, andCode code: Int) {
				if error == nil {
					err = NSError(domain: text, code: code, userInfo: ["description": text])
				}
				else {
					err = error
				}
			}

			guard let response = response as? HTTPURLResponse else {
				setError(withText: "No response.", andCode: 98765)

				return
			}

			guard response.statusCode < 400 else {
				switch response.statusCode {
				case 401: // 401 Unauthorized : possibly needs credentials. How about / refresh / reload / relogin / get tokens n stuff could be automatically handled from here
					break

				default:
					break
				}

				setError(withText: "API Call DAtaTask response Status Code not so good.", andCode: response.statusCode)

				return
			}

			guard let theData = data as Data?
				, error == nil else {
					// cannot parse the result data
					setError(withText: "API Call DAtaTask response DATA.", andCode: 949497)

					return
			}

			guard let rr = try? JSONSerialization.jsonObject(with: theData) as! ResponseDictionary else {
				setError(withText: "API Call DAtaTask response JSON.", andCode: 949498)

				return
			}

			responseResult = rr
			err = error

			// defer is going to finish the job
		}

		task.resume()

		return request as URLRequest
	}

	override func cancel() {
		guard isFinished == false
			, isCancelled == false else {
				return
		}

		super.cancel()
		super.completeOperation() // set isfinished and isexecuting
	}

	override func completeOperation() {
		super.completeOperation()

		let del = delegate ?? WMNet.shared
		if del.networkOpQueue.allDone {
			DispatchQueue.main.async {
				UIApplication.shared.isNetworkActivityIndicatorVisible = false
			}
		}
	}

	class func addRequest(vsgReq: WMRequest, netOp: OperationQueue) -> Bool {
		return addReq(vsgReq: vsgReq, enforce: false, netOp: netOp)
	}

	class func addRequest(vsgReq: WMRequest, enforce: Bool = false) -> Bool {
		return addReq(vsgReq: vsgReq, enforce: enforce, netOp: WMNet.shared.networkOpQueue)
	}

	class func addReq(vsgReq: WMRequest, enforce: Bool = false, netOp: OperationQueue) -> Bool {
		guard vsgReq.isFinished == false else {
			//NSLog("MOTHER OF GOD!! IS HAS FINISHED ... Maybe trying to add same thing twice?! \(vsgReq.URLString)")

			return false
		}

		for op in netOp.operations {
			if op == vsgReq {
				if enforce == false || op.isExecuting {
					return false
				}
				else {
					op.cancel()
					break
				}
			}
		}

		netOp.addOperation(vsgReq)

		return true
	}

	static func createBodyWithParameters(boundary: String, parameters: MethodParamType? = nil, filePathKey: String? = nil, imageDataKey: NSData? = nil) -> Data {
		let body = NSMutableData();

		if parameters != nil {
			for (key, value) in parameters! {
				body.appendString(string: "--\(boundary)\r\n")
				body.appendString(string: "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
				body.appendString(string: "\(value)\r\n")
			}
		}

		if let idk = imageDataKey as? Data {
			let filename = "product_photo.jpg"
			let mimetype = "image/jpg"

			body.appendString(string: "--\(boundary)\r\n")
			let fpk = filePathKey ?? "file"
			body.appendString(string: "Content-Disposition: form-data; name=\"\(fpk)\"; filename=\"\(filename)\"\r\n")
			body.appendString(string: "Content-Type: \(mimetype)\r\n\r\n")
			body.append(idk)
			body.appendString(string: "\r\n")
			body.appendString(string: "--\(boundary)--\r\n")
		}

		return body as Data
	}

}

public enum WMRequestMethod: String {
	case options = "OPTIONS"
	case get     = "GET"
	case head    = "HEAD"
	case post    = "POST"
	case put     = "PUT"
	case patch   = "PATCH"
	case delete  = "DELETE"
	case trace   = "TRACE"
	case connect = "CONNECT"
}

typealias ResponseDictionary = [String: Any]
typealias ResponseArray = [ResponseDictionary]
typealias MethodParamType = ResponseDictionary
typealias URLParamType = [String: String]?
typealias NetCompHandler = (_ responseObject: Any?, _ error: NSError?) -> ()
typealias TokensData = Dictionary<String, String>
