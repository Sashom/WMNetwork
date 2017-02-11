//
//  WMNetwork.swift
//  WMNetwork
//
//  Created by Sasho on 11.02.17 г..
//  Copyright © 2017 г. WebMaster Ltd. All rights reserved.
//

import Foundation

class WMRequest: AsyncOperation, URLSessionDelegate {
	/*weak*/ var request:	URLRequest? = nil
	var URLString:        	String   // possible to contain variables like %s %u
	var REQMethod:          WMRequestMethod 	= .get
	var MethodParams:       MethodParamType?
	var JSONWrapperObj:		String?					= nil

	// below optional (occasional)
	var URLParams:          URLParamType // to be used for GET params when method is POST
	var responseData:       ResponseDictionary?
	var error:              NSError?
	var tryCount:			Int						= 0

	var networkOperationCompletionHandler: NetCompHandler?
	//let sessionManager: SessionManager
	var skipTokens:			Bool					= false

	init(URLString: String, REQMethod: WMRequestMethod = .get, netOpCompletionHandler: NetCompHandler? = nil) {
		//self.sessionManager = sesManager
		self.networkOperationCompletionHandler = netOpCompletionHandler
		self.URLString = URLString
		self.REQMethod = REQMethod
	}

	convenience init(oldR: WMRequest) {
		self.init(URLString: oldR.URLString, REQMethod: oldR.REQMethod, netOpCompletionHandler: oldR.networkOperationCompletionHandler)
		self.MethodParams = oldR.MethodParams
		self.skipTokens = oldR.skipTokens
		self.URLParams = oldR.URLParams
		//self.paramsEncoding = oldR.paramsEncoding
		self.JSONWrapperObj = oldR.JSONWrapperObj
	}

	override func main() {
		tryCount += 1

		guard tryCount < 3 else {
			NSLog("Too many tries in main() = %d.\nCall Sasho!", tryCount)

			return
		}

		//let vTokens = validTokens()
		guard skipTokens || vTokens != nil else {
			// tokens have expired or else invalid_session
			DispatchQueue.main.async {
				logOut()
				_ = logIn(withSuccessCHandler: {
					let vsgR = WMRequest(oldR: self) // here `self` isFinished!, so recreate it below to execute it again , now with the correct tokens.
					_ = WMRequest.addRequest(vsgReq: vsgR)
				})
			}

			return
		}

		//let headers: TokensData = defaultHeaders + ( skipTokens ? nil : vTokens )
		var queryString: String = "" // ? + stuff
		if let urlParams = self.URLParams as URLParamType, urlParams.count > 0 {
			queryString = "?"
			for param in urlParams.keys {
				queryString += param + "=" + (urlParams[param]!.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed))! + "&"
			}
		}

		DispatchQueue.main.async {
			UIApplication.shared.isNetworkActivityIndicatorVisible = true
		}

		if let wo = JSONWrapperObj {
			var newParams: MethodParamType = [:]
			newParams[wo] = MethodParams
			MethodParams = newParams
		}

		self.request = makeRequest(queryString: queryString, headers: headers)
	}

	func makeRequest(queryString qs: String, headers: TokensData) -> URLRequest {
		let url = URL(string: URLString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)! + qs)!
		let request = NSMutableURLRequest(url: url)
		request.httpMethod = REQMethod.rawValue
		switch REQMethod {
		case .get:
			request.cachePolicy = URLRequest.CachePolicy.reloadRevalidatingCacheData

		default:
			request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
		}

		for (hf, hv) in headers {
			request.setValue(hv, forHTTPHeaderField: hf)
		}

		let boundary = "Boundary-\(UUID.init())"

		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

		request.httpBody = createBodyWithParameters(boundary: boundary, parameters: MethodParams) as Data

		let task = HTTPSession.dataTask(with: request as URLRequest) { (data, response, error) in
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
					DLog("Cannot get data from API Call response.")

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
				DLog("cannot parse the API Call DAtaTask result to JSON")

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

	required init?(coder aDecoder: NSCoder) {
		let URLString       = aDecoder.decodeObject(forKey: "URLString")       as! String
		let REQMethod       = WMRequestMethod(rawValue: aDecoder.decodeObject(forKey: "REQMethod") as! String)!
		let MethodParams    = aDecoder.decodeObject(forKey: "MethodParams")    as? MethodParamType
		let URLParams       = aDecoder.decodeObject(forKey: "URLParams")       as!  URLParamType
		//let sessManager		= aDecoder.decodeObject(forKey: "sessManager")     as! String
		let skipTokens		= aDecoder.decodeBool(forKey: "skipTokens")

		//super.init()
		self.URLString 		= URLString
		self.REQMethod 		= REQMethod
		self.MethodParams 	= MethodParams
		self.URLParams 		= URLParams
		/*
		switch sessManager {
		case "Background":
		self.sessionManager = BackgroundHTTP
		default:	// HTTP
		self.sessionManager = HTTP
		}
		*/
		self.skipTokens		= skipTokens

		self.networkOperationCompletionHandler = nil
	}

	func encode(with coder: NSCoder) {
		coder.encode(self.URLString, forKey: "URLString")
		coder.encode(self.REQMethod.rawValue, forKey: "REQMethod")
		coder.encode(self.MethodParams, forKey: "MethodParams")
		coder.encode(self.URLParams, forKey: "URLParams")
		/*if self.sessionManager === HTTP {
		coder.encode("HTTP", forKey: "sessManager")
		}
		else {
		coder.encode("Background", forKey: "sessManager")
		}*/

		coder.encode(self.skipTokens, forKey: "skipTokens")
	}

	class func addRequest(vsgReq: WMRequest, enforce: Bool = false) -> Bool {
		return addReq(vsgReq: vsgReq, enforce: enforce, netOp: networkOpQueue)
	}

	class func addReq(vsgReq: WMRequest, enforce: Bool = false, netOp: OperationQueue) -> Bool {

		if vsgReq.MethodParams == nil || vsgReq.MethodParams!.isEmpty {
			//NSLog("WHYYY!!!??? 3")
		}

		guard vsgReq.isFinished == false else {
			NSLog("MOTHER OF GOD!! IS HAS FINISHED ... WHYYY?! \(vsgReq.URLString)")

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

let loginDefaultSuccessfulHandler = {
	/*rootVCAD?.clearNavStack()
	rootVCAD?.navigateToAuthenticatedViewController()
	rootVCAD?.messageBar.updateWith(messageItem: MessageBarItem(title: String(format: "WELCOME_DISPLAYNAME_MESSAGE_KEY".localized, userKeys.stringForKey(keyName: Settings.displayNameKey) ?? "")))
	*/
}

func logIn(withSuccessCHandler successHandler: (() -> Void)? = loginDefaultSuccessfulHandler ) -> Bool {
	guard let did = userKeys.stringForKey(keyName: Settings.deviceIdKey) ?? UIDevice.current.identifierForVendor?.uuidString
		, let login = userKeys.stringForKey(keyName: Settings.loginKey) else {
			return false
	}

	guard validTokens() == nil else { // no need to relogin if tokens already good
		//AppDelegate.appStatus = AppDelegate.workAppStatus()
		if let sh = successHandler {
			sh()
		}

		return true
	}

	func authFailedToast(_ message: String = "AUTHENTICATION_FAILED_MESSAGE_KEY".localized) {
		//rootVCAD?.messageBar.updateWith(messageItem: MessageBarItem(title: message))
	}

	let loginReq: WMRequest = WMRequest(URLString: URLs.WM_LOGIN_URL, REQMethod: .post) {
		responseObject, error, _ in
		guard let respData = responseObject as? ResponseDictionary else {
			DLog("Failed " + (error?.description)! )
			logOut()
			authFailedToast("LOGIN_OPERATION_FAILED_KEY".localized)

			return
		}

		guard respData["Success"] as? Bool == true else {
			// check for Exception -> Code == Settings.APINotSuppCodeKey
			if let exc = respData["Exception"] as? ResponseDictionary, let exceptionCode = exc["Code"] as? String {
				switch exceptionCode {
				case ExceptionCodes.APINotSuppCodeKey:	// API Not Supported
					//	AppDelegate.alertToUpdate()
					break
				default:
					authFailedToast()
					break
				}
			}
			else {
				authFailedToast()
			}

			logOut()

			return
		}

		guard let result = respData["Result"] as? [String: AnyObject], let success = result["Success"] as? Bool else {
			logOut()
			authFailedToast()

			return
		}

		guard success else {	// no exception but success still suz
			logOut()
			authFailedToast()

			return
		}

		guard let API = result[Settings.APIKey] as? String
			, let APIStr = API.replacingOccurrences(of: ".", with: "_") as String?
			, supportedAPIs.contains(APIStr) else {
				// this should not happen.
				// Problem with the server?
				authFailedToast("SERVER_COMM_FAILED_MESSAGE_KEY".localized) // probably better off with another message here ... network connection prob

				return
		}

		_ = userKeys.setString(value: APIStr, forKey: Settings.APIKey)

		guard let idUser = result["IdUser"] as? Int
			, let sessionToken = result["SessionGuid"] as? String
			, let companyToken = result["CompanyGuid"] as? String
			, let instance = userKeys.stringForKey(keyName: Settings.instanceKey)
			, let expireInMinutes = result["UserSessionExpireMinutes"] as? Int else {
				logOut()
				authFailedToast()

				return
		}

		// ok finally write down this shit
		DispatchQueue.main.async {
			let tokenDict: TokensData = [Settings.idUserHeaderKey: String(idUser), Settings.companyHeaderKey: companyToken, Settings.sessionTknKey: sessionToken, Settings.instanceKey: instance]
			_ = saveTokens(tokenDict)

			let expiresOn = Date(timeIntervalSinceNow: TimeInterval(expireInMinutes * 60 ))
			_ = userKeys.setObject(value: expiresOn as NSCoding, forKey: Settings.tokenExpiresOnKey)

			// ok refresh app status & let the user in
			//AppDelegate.appStatus = AppDelegate.workAppStatus()
			/*	if AppDelegate.appStatus == .allAuthsPassed {
			_ = userKeys.setBool(value: false, forKey: Settings.neverLoggedKey)
			}
			*/
			if let sh = successHandler {
				sh()
			}
		}
	}

	loginReq.skipTokens = false
	let params: MethodParamType = [Settings.loginKey: login, Settings.deviceIdKey: did, "APIVersions": supportedAPIs.map({ $0.replacingOccurrences(of: "_", with: ".") })]
	loginReq.MethodParams = params
	_ = WMRequest.addRequest(vsgReq: loginReq)

	return true
}

func logOut() {
	// log out logic here
	_ = userKeys.removeObjectForKey(keyName: Settings.tokenStorage)
	_ = userKeys.removeObjectForKey(keyName: Settings.tokenExpiresOnKey)
	theTokens = nil

	//AppDelegate.appStatus = .hasToLogin

	if let neverLogged = userKeys.boolForKey(keyName: Settings.neverLoggedKey)
	 , neverLogged == true {
		//rootVCAD?.clearNavStack()
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
typealias NetCompHandler = (_ responseObject: Any?, _ error: NSError?, _ vsgR: Any?) -> ()

