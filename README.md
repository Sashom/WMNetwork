# WMNetwork
Lighweight, ultrasimple Networking Framework for iOS in Swift 3

Assumes JSON REST Server

Motivation:
_ = WMNet.get("http://wmnet.vikors.com/getmestuff.php") {
(data, error) in
guard error == nil else {
DispatchQueue.main.async {
	// update ui with error
}
return
}

// data is Dictionary<String, Any]>, aka ResponseDictionary
if let id = data["Result"]?["id"] as? Int {
	// we have some id
	DispatchQueue.main.async {
		// update ui with success
		//
	}

}
