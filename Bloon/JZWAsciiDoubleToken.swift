//
//  JZWAsciiDoubleToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/8/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWAsciiDoubleToken: JZWAsciiNumToken
{
    init(label: String)
    {
        super.init(label: label, lengthFunction: { (input : UnsafeMutablePointer<Int8>) -> Int in
            return lengthOfDouble(input)
            })
    }
    
    override func copy() -> JZWToken
    {
        return JZWAsciiDoubleToken(label: self.label)
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        return (other is JZWAsciiDoubleToken)
    }
}
