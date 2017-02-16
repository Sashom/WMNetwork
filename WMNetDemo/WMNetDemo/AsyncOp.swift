//
//  AsyncOp.swift
//  WMNetwork
//
//  Created by Sasho on 11.02.17 г..
//  Copyright © 2017 г. All rights reserved.
//

import Foundation

public class AsyncOperation : Operation {
	override public var isAsynchronous: Bool { return true }
	private let stateLock = NSLock()
	private var _executing: Bool = false

	override private(set) public var isExecuting: Bool {
		get {
			return stateLock.withCriticalScope { _executing }
		}
		set {
			willChangeValue(forKey: "isExecuting")
			stateLock.withCriticalScope { _executing = newValue }
			didChangeValue(forKey: "isExecuting")
		}
	}

	private var _finished: Bool = false

	override private(set) public var isFinished: Bool {
		get {
			return stateLock.withCriticalScope { _finished }
		}
		set {
			willChangeValue(forKey: "isFinished")
			stateLock.withCriticalScope { _finished = newValue }
			didChangeValue(forKey: "isFinished")
		}
	}

	public func completeOperation() {
		if isExecuting {
			isExecuting = false
		}

		if !isFinished {
			isFinished = true
		}
	}

	override public func start() {
		if isCancelled {
			isFinished = true
			return
		}

		isExecuting = true

		main()
	}

	override public func main() {
		fatalError("subclasses must override `main`")
	}
}

extension NSLock {
	func withCriticalScope<T>( block: (Void) -> T) -> T {
		lock()
		let value = block()
		unlock()
		return value
	}
}

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
