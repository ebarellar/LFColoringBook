//
//  Stack.swift
//  LFColoringBook
//
//  Created by Trabajo on 19/09/20.
//https://github.com/raywenderlich/swift-algorithm-club/tree/master/Stack

import Foundation

public struct Stack<T> {
  fileprivate var array = [T]()

  public var isEmpty: Bool {
    return array.isEmpty
  }

  public var count: Int {
    return array.count
  }

  public mutating func push(_ element: T) {
    array.append(element)
  }

  public mutating func pop() -> T? {
    return array.popLast()
  }

  public var top: T? {
    return array.last
  }
}
