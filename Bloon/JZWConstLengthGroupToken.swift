//
//  JZWConstLengthGroupToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/12/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWConstLengthGroupToken: JZWGroupToken
{
    override func copy() -> JZWToken
    {
        return JZWConstLengthGroupToken(label: self.label, tokens: self.tokens.map({$0.copy()}))
    }
    
    override func dataIsValid(_ data: JZWData, start: Int, index: Int, end: Int) -> (valid: Bool, bytesRead: Int, validBlocks: [() -> Void]?)
    {
        let length: Int = Int(self.getUnsignedIntValue(data, index: index))
                
        if index + length > Int(data.length())
        {
            return (false, 0, nil)
        }
        
        let (valid, _, blocks) = super.dataIsValid(data, start: start, index: index + self.numBytes, end: index + self.numBytes + length)
        
        self.isValid = valid
        return (valid, length + self.numBytes, blocks)
    }
    
    override func toAscii(_ data: JZWData, index: Int, end: Int) -> (ascii: String, numBytes: Int)
    {
        let length: Int = Int(self.getUnsignedIntValue(data, index: index))

        let (str, _) = super.toAscii(data, index: index + self.numBytes, end: index + self.numBytes + length)
                
        return (str, length + self.numBytes)
    }
    
    override func parse(_ data: JZWData, index: Int, end: Int, parsedValue: JZWParsedSentencePointer, sentence : JZWSentence, basePath: NSString) -> Int
    {
        let length: Int = Int(self.getUnsignedIntValue(data, index: index))

        return super.parse(data, index: index + self.numBytes, end: index + self.numBytes + length, parsedValue: parsedValue, sentence: sentence, basePath: basePath)
    }
}
