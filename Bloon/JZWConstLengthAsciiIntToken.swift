//
//  JZWConstLengthAsciiInt.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/8/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWConstLengthAsciiIntToken: JZWConstLengthAsciiNumToken
{
    init(label: String, numBytes: Int)
    {
        super.init(label: label, lengthFunction: { (input : UnsafeMutablePointer<Int8>) -> Int in
            return lengthOfInt(input)
            }, numBytes: numBytes)
    }
    
    override func copy() -> JZWToken
    {
        return JZWConstLengthAsciiIntToken(label: self.label, numBytes: self.numBytes)
    }

    override func equals(_ other : JZWToken) -> Bool
    {
        return (other is JZWConstLengthAsciiIntToken)
    }
}
