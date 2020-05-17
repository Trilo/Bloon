//
//  JZWConstString.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/10/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWConstStringToken: JZWToken
{
    let str : String
    
    init(label: String, string: String)
    {
        self.str = string
        
        super.init(label: label, numBytes: self.str.count, format: ByteFormat.signedBigEndian)
    }

    override func copy() -> JZWToken
    {
        return JZWConstStringToken(label: self.label, string: self.str)
    }
    
    override func dataIsValid(_ data: JZWData, start: Int, index: Int, end: Int) -> (valid: Bool, bytesRead: Int, validBlocks: [() -> Void]?)
    {
        let tailRange = NSMakeRange(index, self.numBytes)
        
        do
        {
            let tailData = try data.subdataWithRange(tailRange)
            
            let str = NSString(data: tailData, encoding: String.Encoding.ascii.rawValue)!

            if self.str == str as String
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
        catch
        {
            return (false, 0, nil)
        }
    }
    
    override func toAscii(_ data: JZWData, index: Int, end: Int) -> (ascii: String, numBytes: Int)
    {
        let tailRange = NSMakeRange(index, self.numBytes)
        
        do
        {
            let tailData = try data.subdataWithRange(tailRange)
            let str = NSString(data: tailData, encoding: String.Encoding.ascii.rawValue)
            
            return (str! as String, self.numBytes)
        }
        catch
        {
            return ("", self.numBytes)
        }
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        return (other is JZWConstStringToken) && ((other as! JZWConstStringToken).str == self.str)
    }
    
    override func parse(_ data: JZWData, index: Int, end: Int, parsedValue: JZWParsedSentencePointer, sentence : JZWSentence, basePath: NSString) -> Int
    {
        return self.numBytes
    }
}
