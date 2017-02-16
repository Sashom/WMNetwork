//
//  WMNetwork.swift
//  WMNetwork
//
//  Created by Sasho on 11.02.17 г..
//  Copyright © 2017 г. . All rights reserved.
//

import Foundation
import UIKit

func + <K,V> (left: Dictionary<K,V>, right: Dictionary<K,V>?) -> Dictionary<K,V> {
	guard let right = right else { return left }
	return left.reduce(right) {
		var new = $0 as [K:V]
		new.updateValue($1.1, forKey: $1.0)
		return new
	}
}

extension NSMutableData {

	func appendString(string: String) {
		let data = string.data(using: .utf8, allowLossyConversion: true)
		append(data!)
	}
}


// public interface - working with WMRequest
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
			"User-Agent": "WMNetwork Framework v. 1",
			]

		return x
	}()

	lazy var HTTP: URLSession = { () -> URLSession in
		NSLog("Requesting HTTP URLSession")
		let config = URLSessionConfiguration.default
		config.httpAdditionalHeaders 			= self.defaultHeaders
		config.timeoutIntervalForRequest 		= 40
		return URLSession(configuration: config)
	}()

	class public func post(_ urlString: String, closure: NetCompHandler? = nil) -> WMRequest? {
		return req(urlString: urlString, method: .post, params: nil, closure: closure)
	}

	class public func get(_ urlString: String, closure: NetCompHandler? = nil) -> WMRequest? {
		return req(urlString: urlString, method: .get, params: nil, closure: closure)
	}

	class public func req(urlString: String, method: WMRequestMethod, params: ResponseDictionary? = nil, closure: NetCompHandler? = nil) -> WMRequest? {
		let wmReq = WMRequest(URLString: urlString, methodParams: params, REQMethod: method, additionalHeaders: nil, netOpCompletionHandler: closure)
		wmReq.skipTokens = true /**** !!! for test only !!! ***/

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

class WMRequest: AsyncOperation, URLSessionDelegate {
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
			NSLog("Too many tries in main() = %d.\nCall Sasho!", retryCount)

			return
		}

		let vTokens: TokensData? = nil
		guard skipTokens || vTokens != nil else {
			DispatchQueue.main.async {
				// here use dependencies? // .addDependency // login to get tokens?
				/*logOut()
				_ = logIn(withSuccessCHandler: {
					let vsgR = WMRequest(oldR: self) // here `self` isFinished!, so recreate it below to execute it again , now with the correct tokens.
					_ = WMRequest.addRequest(vsgReq: vsgR)
				})*/
			}

			return
		}

		let del = delegate ?? WMNet.shared
		let headers: TokensData = del.defaultHeaders + ( skipTokens ? nil : vTokens )
		var queryString: String = "" // ? + stuff
		// this below might get deprecated and in most cases URL params are String(format:)'ed into the url
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

		request.httpBody = createBodyWithParameters(boundary: boundary, parameters: MethodParams) as Data


		let task = del.HTTP.dataTask(with: request as URLRequest) { (data, response, error) in
			var responseResult: ResponseDictionary? = nil
			var err: Error? = nil

			defer {
				if let netOpCH = self.networkOperationCompletionHandler {
					netOpCH(responseResult, err as NSError?, self)
				}

				self.completeOperation()
			}

			guard let theData = data as Data?
				, let _:URLResponse = response, error == nil else {
					// cannot parse the result data
					err = NSError(domain: "API Call DAtaTask response DATA", code: 949497, userInfo: ["description": "Cannot get data from response."])
					NSLog("Cannot get data from API Call response.")

					return
			}

			var rr: ResponseDictionary? = try? JSONSerialization.jsonObject(with: theData) as! ResponseDictionary
			if rr == nil {
				if let str = String(data: theData, encoding: .utf8)
				 , let tt = Int(str) {
					rr = ["Result": ["id": tt]]
				}
			}

			if rr == nil {
				// cannot parse the result
				err = NSError(domain: "API Call DAtaTask response JSON", code: 949498, userInfo: ["description": "Cannot parse the API Call DAtaTask result to JSON."])
				NSLog("cannot parse the API Call DAtaTask result to JSON")

				return
			}

			responseResult = rr!
			err = error

			// defer is going to finish the job
		}

		task.resume()
		return request as URLRequest

		/*return sessionManager.request(URLString + qs, method: REQMethod, parameters: MethodParams, encoding: paramsEncoding, headers: headers)
		.validate()
		.responseJSON { response in
		if let jswok = self.JSONWrapperObj
		,  let wo = self.MethodParams?[jswok] as? MethodParamType {
		self.MethodParams = wo
		}

		// should check INVALID_SESSION and try to reload...
		if let rr = response.result.value as? ResponseDictionary
		, let e = rr["Exception"] as? ResponseDictionary
		, let eCode = e["Code"] as? String {
		switch eCode {
		case ExceptionCodes.SessionExpiredCodeKey:
		DispatchQueue.main.async {
		logOut()
		_ = logIn(withSuccessCHandler: {
		let vsgR = WMRequest(oldR: self) // here `self` isFinished!, so recreate it below to execute it again , now with the correct tokens.
		_ = WMRequest.addRequest(vsgReq: vsgR)
		})
		return
		}

		default:
		break

		} // end switch
		/*
		self.completeOperation()
		return
		*/
		}
		else {
		// if network error
		}

		if let netOpCH = self.networkOperationCompletionHandler {
		netOpCH(response.result.value, response.result.error as NSError?, nil)
		}

		self.completeOperation()
		}*/
	}

	deinit {
		//DLog("how: " + URLString + "finished = \(isFinished); cancelled = \(isCancelled)")
	}

	override func cancel() {
		guard isFinished == false
			, isCancelled == false else {
				return
		}

		//request?.cancel()
		super.cancel()
		super.completeOperation() // set isfinished and isexecuting
	}

	class func addRequest(vsgReq: WMRequest, netOp: OperationQueue) -> Bool {
		return addReq(vsgReq: vsgReq, enforce: false, netOp: netOp)
	}

	class func addRequest(vsgReq: WMRequest, enforce: Bool = false) -> Bool {
		return addReq(vsgReq: vsgReq, enforce: enforce, netOp: WMNet.shared.networkOpQueue)
	}

	class func addReq(vsgReq: WMRequest, enforce: Bool = false, netOp: OperationQueue) -> Bool {
		guard vsgReq.isFinished == false else {
			NSLog("MOTHER OF GOD!! IS HAS FINISHED ... Maybe trying to add same thing twice?! \(vsgReq.URLString)")

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

}

func createBodyWithParameters(boundary: String, parameters: MethodParamType? = nil, filePathKey: String? = nil, imageDataKey: NSData? = nil) -> Data {
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
typealias NetCompHandler = (_ responseObject: Any?, _ error: NSError?, _ wmR: WMRequest?) -> ()
typealias TokensData = Dictionary<String, String>
