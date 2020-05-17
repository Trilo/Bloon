//
//  JZWConstBinIntToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/5/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWConstBinIntToken: JZWBinIntToken
{
    var constValue : Int = 0
    
    init(label: String, numBytes: Int, constValue: Int, format: ByteFormat)
    {
        self.constValue = constValue
        
        super.init(label: label, numBytes: numBytes, format: format)
    }
    
    override func copy() -> JZWToken
    {
        return JZWConstBinIntToken(label: self.label, numBytes: self.numBytes, constValue: self.constValue, format: self.format)
    }
    
    override func dataIsValid(_ data: JZWData, start: Int, index: Int, end: Int) -> (valid: Bool, bytesRead: Int, validBlocks: [() -> Void]?)
    {
        if index + self.numBytes > Int(data.length())
        {
            return (false, 0, nil)
        }
        
        let num = Int(self.getUnsignedIntValue(data, index: index))
        
        if num == self.constValue
        {
            self.isValid = true
            return (true, self.numBytes, nil)
        }
        else
        {
            self.isValid = false
            return (false, 1, nil)
        }
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        return super.equals(other) && ((other as! JZWConstBinIntToken).constValue == self.constValue)
    }
}
