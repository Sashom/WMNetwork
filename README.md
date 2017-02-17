# WMNetwork
Lighweight, UltraSimple JSON REST Networking Framework for iOS in Swift 3

**WARNING:** This is still experimental alpha version. Lacks functionality/flexibility and has potential (design) flaws.

If you have been using a lot of JSON REST webservices where you need to login to get a token and follow if it has expired, this makes things a bit easier for you.

Automatically logs you in (so far reads only HTTP status code 401 to perform login).
You just configure the login credentials and how the returned tokens match the headers to be included in for authentication (example further down).

## Motivation:

**GET**

	#import WMNetwork
	WMNet.get("http://wmnet.vikors.com/stuff.php") { (data, error) in
        guard error == nil
        	, let data = data as? ResponseDictionary else {
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
        guard error == nil
        	, let data = data as? ResponseDictionary else {
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
Just set the loginCredentials variable when app starts or from the global space

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
		// now you go for your requests, e.g. in `viewDidLoad()`
		_ = WMNet.get("http://wmnet.vikors.com/stuff.php?what=securedcontent") { (data, error) in
			NSLog("GET Response: \(data)")
		}

A bit more explanation about loginHeadersMatch part of the loginCredentials above:
In the example above after successful login server returns 2 variables `token1`, and `token2`.
In turn to authenticate with the server you need to include these tokens somehow as headers, which names are different from `token1` and `token2`, but essentially contain the same data.
So the headers matching `token1` and `token2` are named respectively `primary_token` and `secondary_token`.

This project uses a modified version of:
https://github.com/jrendel/SwiftKeychainWrapper
which files are directly included in WMNetwork.

This is the end, my only friend.
