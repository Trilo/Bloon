//
//  JZWCheckSumToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/7/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWChecksumToken: JZWToken
{
    var range : NSRange
    
    init(label: String, range: NSRange = NSMakeRange(0, 0))
    {
        self.range = range
        super.init(label: label, numBytes: 1, format: ByteFormat.signedBigEndian)
    }
    
    class func checksum(_ data: JZWData, start: Int, index: Int) -> UInt8
    {
        let length = index - start
        var range = NSMakeRange(start, length)
        
        do
        {
            let bytes = try data.getBytes(&range)
            
            var checksum : Int8 = 0
            
            for i in 0 ..< length
            {
                checksum ^= bytes[i]
            }
            
            bytes.deallocate()
            
            return UInt8(checksum)
        }
        catch
        {
            return 0
        }
    }
    
    override func dataIsValid(_ data: JZWData, start: Int, index: Int, end: Int) -> (valid: Bool, bytesRead: Int, validBlocks: [() -> Void]?)
    {
        if index + self.numBytes > Int(data.length())
        {
            self.isValid = false
            return (false, 0, nil)
        }
        
        let begin = start + self.range.location
        var end = index
        
        if self.range.length <= 0
        {
            end += self.range.length
        }
        else
        {
            end = begin + self.range.length
        }
        
        if (end >= Int(data.length()))
        {
            self.isValid = false
            return (false, 1, nil)
        }

        let checksum : UInt8 = JZWChecksumToken.checksum(data, start: begin, index: end)
        
        let value = UInt8(self.getIntValue(data, index: index))
        let valid = value == checksum
        self.isValid = valid
        return (valid, self.numBytes, nil)
    }
    
    override func toAscii(_ data: JZWData, index: Int, end: Int) -> (ascii: String, numBytes: Int)
    {
        return (intToString(Int32(self.getIntValue(data, index: index))) as String, self.numBytes)
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        return ((other is JZWChecksumToken) && (other.numBytes == self.numBytes))
    }

    override func parse(_ data: JZWData, index: Int, end: Int, parsedValue: JZWParsedSentencePointer, sentence : JZWSentence, basePath: NSString) -> Int
    {
        let value = self.getIntValue(data, index: index)
        
        let path = self.getReusablePath(basePath)
        
        JZWParsedSentence.setValue(Double(value), forKey: path, jps: parsedValue, sentence: sentence)
        
        return self.numBytes
    }
}
