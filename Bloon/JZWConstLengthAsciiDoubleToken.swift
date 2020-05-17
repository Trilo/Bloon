//
//  JZWConstLengthAsciiDoubleToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/9/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWConstLengthAsciiDoubleToken: JZWConstLengthAsciiNumToken
{
    init(label: String, numBytes: Int)
    {
        super.init(label: label, lengthFunction: { (input : UnsafeMutablePointer<Int8>) -> Int in
            lengthOfDouble(input)
            }, numBytes: numBytes)
    }
    
    override func copy() -> JZWToken
    {
        return JZWConstLengthAsciiDoubleToken(label: self.label, numBytes: self.numBytes)
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        return (other is JZWConstLengthAsciiDoubleToken)
    }
}
