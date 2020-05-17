//
//  JZWAsciiHexChecksum.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/8/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWAsciiHexChecksumToken: JZWConstLengthAsciiHexToken
{
    var range : NSRange
    
    init(label: String, range: NSRange = NSMakeRange(0, 0))
    {
        self.range = range
        super.init(label: label, numBytes: 2)
    }
    
    override func dataIsValid(_ data: JZWData, start: Int, index: Int, end: Int) -> (valid: Bool, bytesRead: Int, validBlocks: [() -> Void]?)
    {
        if index + self.numBytes > Int(data.length())
        {
            return (false, 0, nil)
        }
        
        var begin = start + self.range.location
        var endcs = index
        
        if self.range.length <= 0
        {
            endcs += self.range.length
        }
        else
        {
            endcs = begin + self.range.length
        }
        if self.range.location < 0
        {
            begin = index + self.range.location
        }
                
        let checksum : UInt8 = JZWChecksumToken.checksum(data, start: begin, index: endcs)
        
        let (string, _) = self.toAscii(data, index: index, end: end)
        
        let scanner = Scanner(string: string)
        
        var value : UInt32 = 0;
        scanner.scanHexInt32(&value)
        
        let valid = UInt8(value) == checksum
        self.isValid = valid
        return (valid, self.numBytes, nil)
    }
}
