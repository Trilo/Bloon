//
//  JZWTerminatedStringToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/6/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWTerminatedStringToken: JZWToken
{
    let terminationCharacter : Int8
    
    init(label: String, ch: Int8)
    {
        self.terminationCharacter = Int8(ch)
        
        super.init(label: label, numBytes: 1, format: ByteFormat.signedBigEndian)
    }
    
    convenience init(label: String, ch: Character)
    {
        self.init(label: label, ch: Int8(ch.unicodeScalarCodePoint()))
    }

    override func copy() -> JZWToken
    {
        return JZWTerminatedStringToken(label: self.label, ch: self.terminationCharacter)
    }
    
    override func dataIsValid(_ data: JZWData, start: Int, index: Int, end: Int) -> (valid: Bool, bytesRead: Int, validBlocks: [() -> Void]?)
    {
        if index + self.numBytes > Int(data.length())
        {
            return (false, 0, nil)
        }

        let end = Int(data.findCharacter(self.terminationCharacter, inRange: NSMakeRange(index, Int(data.length()) - index)))
        
        if end == -1
        {
            self.isValid = false
            return (false, 0, nil)
        }

        self.isValid = true
        return (true, end - index + 1, nil)
    }
    
    override func toAscii(_ data: JZWData, index: Int, end: Int) -> (ascii: String, numBytes: Int)
    {
        
        let end = Int(data.findCharacter(self.terminationCharacter, inRange: NSMakeRange(index, Int(data.length()) - index)))
        
        if end != -1
        {
            let stringRange = NSMakeRange(index, end - index + 1)
            do
            {
                return try (NSString(data: data.subdataWithRange(stringRange), encoding: String.Encoding.ascii.rawValue)! as String, stringRange.length)
            }
            catch
            {
                return (String(), self.numBytes)
            }
        }
        
        return (String(), self.numBytes)
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        return (other is JZWTerminatedStringToken) && ((other as! JZWTerminatedStringToken).terminationCharacter == self.terminationCharacter)
    }

    override func parse(_ data: JZWData, index: Int, end: Int, parsedValue: JZWParsedSentencePointer, sentence : JZWSentence, basePath: NSString) -> Int
    {
        let (_, numBytes) = self.toAscii(data, index: index, end: end)
        
        return numBytes;
    }
}






