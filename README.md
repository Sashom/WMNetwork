# WMNetwork
Lighweight, UltraSimple JSON REST Networking Framework for iOS in Swift 3

If you have been using a lot of JSON REST webservices where you need to login to get a token and follow if it has expired, this makes things a bit easier for you.

Automatically logs you in (reads HTTP status code 401 only to perform login so far).
You just configure the login credentials and how the returned tokens match the headers to be included in for authentication (example further down).

**WARNING:** This is still experimental alpha version.

## Motivation:

	#import WMNetwork
**GET**

	WMNet.get("http://wmnet.vikors.com/stuff.php") { (data, error) in
        guard error == nil else {
            DispatchQueue.main.async {
                 > update ui with error
            }

            return
        }

        // data is Dictionary[String: Any], aka ResponseDictionary
        if let id = (data["Result"] as? ResponseDictionary)?["id"] as? Int {
            // we have some id
            DispatchQueue.main.async {
                > update ui with success
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
        if let id = (data["Result"] as? ResponseDictionary)?["id"] as? Int {
            // we have some id
            DispatchQueue.main.async {
                // update ui with success
            }
        }
  	}
    

***Configuration***
Just set the loginCredentials variable
			WMNet.shared.loginCredentials = {
			let lc = WMNet.LoginCredentials(
				loginURLString: "http://wmnet.vikors.com/stuff.php?what=login"
				, keyValues: ResponseDictionary(dictionaryLiteral:
					("myLoginUser", "dedo")	// or NSNull() to avoid login
					, ("myLoginPass", "pene"))
				, loginHeadersMatch: ResponseDictionary(dictionaryLiteral:
					// (key for value from server, key for value for header)
						("token1", "primary_token")
					// (key for value from server, key for value for header)
					  , ("token2", "secondary_token")
				)
			)

			return lc
		}

		WMNet.shared.autoLogin = true

		_ = WMNet.get("http://wmnet.vikors.com/stuff.php?what=securedcontent") { (response, error) in
			NSLog("GET Response: \(response)")
		}


This is the end, my only friend.
