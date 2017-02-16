//
//  ViewController.swift
//  WMNetDemo
//
//  Created by Sasho on 16.02.17 г..
//
//

import UIKit
//import WMNetwork

struct URLs {
	static let getStuffURL = "http://wmnet.vikors.com/getmestuff.php"
	static let loginFailURL = "http://wmnet.vikors.com/getmestuff.php?what=loginfail"
}

class ViewController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.

		let params: ResponseDictionary = [
			"Dedo": "Pene",
			"Chicho": "Gosho",
			"Baba": "Tonka",
			"Chislo": 9494
		]
		let k = WMNet.get(URLs.loginFailURL) { //, params: params) {
			(data, error, wmReq) in
			guard let data = data as? ResponseDictionary else {
				NSLog("No data... \(error.debugDescription)")
				return
			}

			NSLog("Did it \(data)")
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


}

