//
//  JZACharToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/10/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWCharToken: JZWBinIntToken
{
    init(label: String)
    {
        super.init(label: label, numBytes: 1, format: ByteFormat.signedBigEndian)
    }
    
    override func copy() -> JZWToken
    {
        return JZWCharToken(label: self.label)
    }
    
    override func toAscii(_ data: JZWData, index: Int, end: Int) -> (ascii: String, numBytes: Int)
    {
        let byte = UInt8(self.getIntValue(data, index: index))
        
        let s = String(UnicodeScalar(byte))
        
        return (s, self.numBytes)
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        return (other is JZWBinIntToken) && (other.numBytes == self.numBytes)
    }    
}
