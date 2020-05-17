//
//  JZWFixedLengthGroupToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 12/29/15.
//  Copyright © 2015 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWFixedLengthGroupToken: JZWGroupToken
{
    override func copy() -> JZWToken
    {
        return JZWFixedLengthGroupToken(label: self.label, tokens: self.tokens.map({$0.copy()}))
    }
    
    override func dataIsValid(_ data: JZWData, start: Int, index: Int, end: Int) -> (valid: Bool, bytesRead: Int, validBlocks: [() -> Void]?)
    {
        let length: Int = self.numBytes
                
        if index + length > Int(data.length())
        {
            return (false, 0, nil)
        }
        
        let (valid, _, blocks) = super.dataIsValid(data, start: start, index: index, end: index + length)
        
        self.isValid = valid
        return (valid, length, blocks)
    }
    
    override func toAscii(_ data: JZWData, index: Int, end: Int) -> (ascii: String, numBytes: Int)
    {
        let length: Int = self.numBytes
        
        let (str, _) = super.toAscii(data, index: index, end: index + length)
        
        return (str, length)
    }
    
    override func parse(_ data: JZWData, index: Int, end: Int, parsedValue: JZWParsedSentencePointer, sentence : JZWSentence, basePath: NSString) -> Int
    {
        let length: Int = self.numBytes
        
        return super.parse(data, index: index, end: index + length, parsedValue: parsedValue, sentence : sentence, basePath: basePath)
    }
}
