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
    
    func appendData(_ data : Data)
    {
        let len = data.count
        
        while Int(self._length) + len > self.space
        {
            self.resizeByAddingBlocks(Int(self.numBlocks))
        }
        
        let bytes = UnsafeMutablePointer<Int8>(mutating: (data as NSData).bytes.bindMemory(to: Int8.self, capacity: data.count))
        
        var index = self._length
        
        let safeBlocks = self.blocks
        
        for i in 0 ..< len
        {
            let blockIndex = Int(index / self.blockSize)
            let innerIndex = Int(index % self.blockSize)
            safeBlocks![blockIndex][innerIndex] = bytes[i]
            index += 1
        }
        
        OSAtomicAdd64(Int64(len), &self._length)
    }
    
    func subdataWithRange(_ range : NSRange) throws -> Data
    {
        var r = range
        let bytes = try self.getBytes(&r)
        return Data(bytesNoCopy: bytes, count: r.length, deallocator: .free)
    }

    func getBytes(_ range : inout NSRange) throws -> UnsafeMutablePointer<Int8>
    {
        let data : UnsafeMutablePointer<Int8> = try self.getRaw(&range)
        data[range.length] = 0
        return data
    }
        
    func findCharacter(_ c : Int8, inRange range : NSRange) -> Int
    {
        var index = range.location;
        
        self.iterateWithBlock({ (testChar : Int8) -> Bool in
            index += 1
            return testChar == c
        }, inRange: range)
        
        if index >= range.location + range.length
        {
            return -1;
        }
        
        return index - 1;
    }
    
}
