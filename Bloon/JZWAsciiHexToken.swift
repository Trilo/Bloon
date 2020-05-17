//
//  JZWAsciiHexToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/8/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWAsciiHexToken: JZWAsciiNumToken
{
    init(label: String)
    {
        super.init(label: label, lengthFunction: { (input : UnsafeMutablePointer<Int8>) -> Int in
            return lengthOfHexInt(input)
        })
    }
    
    override func copy() -> JZWToken
    {
        return JZWAsciiHexToken(label: self.label)
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        return (other is JZWAsciiHexToken)
    }
    
    override func parse(_ data: JZWData, index: Int, end: Int, parsedValue: JZWParsedSentencePointer, sentence : JZWSentence, basePath: NSString) -> Int
    {
        let (string, numChars) = self.toAscii(data, index: index, end: end)
        
        let scanner = Scanner(string: string)
        
        var value : UInt64 = 0;
        scanner.scanHexInt64(&value)
        let path = self.getReusablePath(basePath)

        JZWParsedSentence.setValue(Double(value), forKey: path, jps: parsedValue, sentence: sentence)

        return numChars
    }
}
