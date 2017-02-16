# WMNetwork
Lighweight, UltraSimple JSON REST Networking Framework for iOS in Swift 3

**WARNING:** This is still experimental alpha version.

## Motivation:

**GET**
WMNet.get("http://wmnet.vikors.com/stuff.php") { (data, error) in
	guard error == nil else {
		DispatchQueue.main.async {
			// update ui with error
		}
        
		return
	}

	// data is Dictionary<String, Any>, aka ResponseDictionary
	if let id = data["Result"]?["id"] as? Int {
		// we have some id
		DispatchQueue.main.async {
			// update ui with success
		}
	}
}


**POST**
let postVars: ResponseDictionary = [
	"album_id": 1999,
    "text": "And when the rain begins to flow",
    "chorus": "I'll be the sunshine in your eyes",
    "epilog": "80's classics",
]
WMNet.post("http://wmnet.vikors.com/stuff.php", params: postVars) { (data, error) in
    guard error == nil else {
        DispatchQueue.main.async {
            // update ui with error
        }
        
        return
    }

    // data is Dictionary<String, Any>, aka ResponseDictionary
    if let id = data["Result"]?["id"] as? Int {
        // we have some id
        DispatchQueue.main.async {
            // update ui with success
        }
    }
}
