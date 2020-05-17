//
//  JZWBinIntToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/5/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWBinIntToken: JZWToken
{
    override init(label: String, numBytes: Int, format: ByteFormat)
    {
        super.init(label: label, numBytes: numBytes, format: format)
    }
    
    override func copy() -> JZWToken
    {
        return JZWBinIntToken(label: self.label, numBytes: self.numBytes, format: self.format)
    }
    
    override func dataIsValid(_ data: JZWData, start: Int, index: Int, end: Int) -> (valid: Bool, bytesRead: Int, validBlocks: [() -> Void]?)
    {
        if index + self.numBytes > Int(data.length())
        {
            return (false, 0, nil)
        }
        
        self.isValid = true
        return (true, self.numBytes, nil)
    }
    
    override func toAscii(_ data: JZWData, index: Int, end: Int) -> (ascii: String, numBytes: Int)
    {
        return (intToString(Int32(self.getIntValue(data, index: index))) as String, self.numBytes)
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        return (other is JZWBinIntToken) && (other.numBytes == self.numBytes)
    }

    override func parse(_ data: JZWData, index: Int, end: Int, parsedValue: JZWParsedSentencePointer, sentence : JZWSentence, basePath: NSString) -> Int
    {
        var value : Double = 0.0
        
        if (self.isSigned)
        {
            value = Double(self.getIntValue(data, index: index))
        }
        else
        {
            value = Double(self.getUnsignedIntValue(data, index: index))
        }
        
        let path = self.getReusablePath(basePath)
        JZWParsedSentence.setValue(Double(value), forKey: path, jps: parsedValue, sentence: sentence)
        
        return self.numBytes
    }
}
