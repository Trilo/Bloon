//
//  JZWAsciiNumToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/9/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWAsciiNumToken: JZWToken
{
    let maxNumberLength = 40
    
    var lengthFunction : ((UnsafeMutablePointer<Int8>) -> Int)
    
    init(label: String, lengthFunction: @escaping ((UnsafeMutablePointer<Int8>) -> Int), numBytes: Int = 1)
    {
        self.lengthFunction = lengthFunction
        super.init(label: label, numBytes: numBytes, format: ByteFormat.signedBigEndian)
    }
    
    override func copy() -> JZWToken
    {
        return JZWAsciiNumToken(label: self.label, lengthFunction: self.lengthFunction, numBytes: self.numBytes)
    }
    
    override func dataIsValid(_ data: JZWData, start: Int, index: Int, end: Int) -> (valid: Bool, bytesRead: Int, validBlocks: [() -> Void]?)
    {
        let lenTail = Int(data.length()) - index
        
        if lenTail == 0
        {
            return (false, 0, nil)
        }
        
        var range = NSMakeRange(index, self.maxNumberLength)
        
        do
        {
            let tail = try data.getBytes(&range)
            let ptr = UnsafeMutablePointer<Int8>(tail)
            let lenLongestStr = self.lengthFunction(ptr)
            tail.deallocate()
            
            if lenLongestStr == lenTail
            {
                return (false, 0, nil)
            }
            else if lenLongestStr <= 0
            {
                self.isValid = false
                return (false, 1, nil)
            }
            
            self.isValid = true
            return (true, lenLongestStr, nil)
        }
        catch
        {
            return (false, 0, nil)
        }
    }
    
    override func toAscii(_ data: JZWData, index: Int, end: Int) -> (ascii: String, numBytes: Int)
    {
        var range = NSMakeRange(index, self.maxNumberLength)
        
        do
        {
            let tail = try data.getBytes(&range)
                        
            let ptr = UnsafeMutablePointer<Int8>(tail)
            let lenLongestStr = self.lengthFunction(ptr)
            if lenLongestStr < 0
            {
                print ("toAscii Failed")
                return ("", 0)
            }
            
            let str = NSString(bytesNoCopy: ptr, length: lenLongestStr, encoding: String.Encoding.utf8.rawValue, freeWhenDone: true)
            
            if let unwrappedStr = str
            {
                return (unwrappedStr as String, lenLongestStr)
            }
            else
            {
                print("toAscii Failed")
                return ("", 0)
            }
        }
        catch
        {
            return ("", 0)
        }
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        return (other is JZWAsciiIntToken)
    }
    
    override func parse(_ data: JZWData, index: Int, end: Int, parsedValue: JZWParsedSentencePointer, sentence : JZWSentence, basePath: NSString) -> Int
    {
        let (string, numChars) = self.toAscii(data, index: index, end: end)
                
        let path = self.getReusablePath(basePath)

        JZWParsedSentence.setValue(NSString(string: string).doubleValue, forKey: path, jps: parsedValue, sentence: sentence)
        
        return numChars
    }
}
