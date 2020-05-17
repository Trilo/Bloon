//
//  JZWMrSwData.swift
//  Bloon
//
//  Created by Jacob Weiss on 2/18/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWData: JZWMrSwArray<Int8>
{
    override init(blockSize : Int, numBlocks : Int)
    {
        super.init(blockSize: blockSize, numBlocks: numBlocks)
    }
    
    func appendData(data : NSData)
    {
        let len = data.length
        
        while self._length + len > self.space
        {
            self.resizeByAddingBlocks(self.numBlocks)
        }
        
        let bytes = UnsafePointer<Int8>(data.bytes)
        
        var index = self._length
        
        let safeBlocks = self.blocks
        
        for i in 0 ..< len
        {
            let blockIndex = index / self.blockSize
            let innerIndex = index % self.blockSize
            safeBlocks[blockIndex][innerIndex] = bytes[i]
            index++
        }
        
        self._length += len;
    }
    
    func getBytes(inout range : NSRange) -> UnsafeMutablePointer<Int8>
    {
        return self.getRaw(&range)
    }
    
    func findCharacter(c : Int8, inRange range : NSRange) -> Int
    {
        var index = range.location;
        
        self.iterateWithBlock({ (testChar : Int8) -> Bool in
            index++
            return testChar == c
            }, inRange: range)
        
        if index >= range.location + range.length
        {
            return -1;
        }
        
        return index - 1;
    }
    
    func subdataWithRange(range : NSRange) -> NSData
    {
        var r = range
        let bytes = self.getBytes(&r)
        return NSData(bytesNoCopy: bytes, length: r.length, freeWhenDone: true)
    }
}
