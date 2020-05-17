//
//  JZWConstLengthNumToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/10/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWConstLengthAsciiNumToken: JZWAsciiNumToken
{
    override init(label: String, lengthFunction: @escaping ((UnsafeMutablePointer<Int8>) -> Int), numBytes: Int)
    {
        super.init(label: label, lengthFunction: lengthFunction, numBytes: numBytes)
    }

    override func copy() -> JZWToken
    {
        return JZWConstLengthAsciiNumToken(label: self.label, lengthFunction: self.lengthFunction, numBytes: self.numBytes)
    }
    
    override func dataIsValid(_ data: JZWData, start: Int, index: Int, end: Int) -> (valid: Bool, bytesRead: Int, validBlocks: [() -> Void]?)
    {
        do
        {
            let subdat = try data.subdataWithRange(NSMakeRange(index, self.numBytes))
            let ptr = UnsafeMutablePointer<Int8>(mutating: (subdat as NSData).bytes.bindMemory(to: Int8.self, capacity: self.numBytes))
            
            let lenLongestStr = self.lengthFunction(ptr)
            
            if lenLongestStr == subdat.count
            {
                self.isValid = true
                return (true, lenLongestStr, nil)
            }
            
            self.isValid = false
            return (false, 1, nil)
        }
        catch
        {
            return (false, 0, nil)
        }
    }
    
    override func toAscii(_ data: JZWData, index: Int, end: Int) -> (ascii: String, numBytes: Int)
    {
        do
        {
            let subdat = try data.subdataWithRange(NSMakeRange(index, self.numBytes))
            let str = NSString(data: subdat, encoding: String.Encoding.ascii.rawValue)
            return (str! as String, self.numBytes)
        }
        catch
        {
            return (String(), 0)
        }
    }

    override func equals(_ other : JZWToken) -> Bool
    {
        return (other is JZWConstLengthAsciiNumToken)
    }
}
