//
//  JZWConstLengthAsciiHex.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/8/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWConstLengthAsciiHexToken: JZWConstLengthAsciiNumToken
{
    init(label: String, numBytes: Int)
    {
        super.init(label: label, lengthFunction: { (input : UnsafeMutablePointer<Int8>) -> Int in
            return lengthOfHexInt(input)
            }, numBytes: numBytes)
    }
    
    override func copy() -> JZWToken {
        return JZWConstLengthAsciiHexToken(label: self.label, numBytes: self.numBytes)
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        return (other is JZWConstLengthAsciiHexToken)
    }
    
    override func parse(_ data: JZWData, index: Int, end: Int, parsedValue: JZWParsedSentencePointer, sentence : JZWSentence, basePath: NSString) -> Int
    {
        let (string, numChars) = self.toAscii(data, index: index, end: end)
        
        let scanner = Scanner(string: string)
        
        var value : UInt32 = 0;
        scanner.scanHexInt32(&value)
        
        let path = self.getReusablePath(basePath)
        
        JZWParsedSentence.setValue(Double(value), forKey: path, jps: parsedValue, sentence: sentence)

        return numChars
    }
}
