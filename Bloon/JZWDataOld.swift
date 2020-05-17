//
//  JZWData.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/13/15.
//  Copyright © 2015 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWData
{
    var blockSize : Int = 0
    var numBlocks : Int = 0
    
    var blocks : UnsafeMutablePointer<UnsafeMutablePointer<Int8>> = nil
    var _length : Int = 0
    
    var oldBlockLists : [UnsafeMutablePointer<UnsafeMutablePointer<Int8>>] = []
    
    private var space : Int
    {
        get
        {
            return self.numBlocks * self.blockSize
        }
    }

    init(blockSize : Int, numBlocks : Int)
    {
        self.blockSize = blockSize
        self.numBlocks = numBlocks
        
        self.blocks = UnsafeMutablePointer<UnsafeMutablePointer<Int8>>.alloc(self.numBlocks)
        
        for i in 0 ..< self.numBlocks
        {
            self.blocks.advancedBy(i).initialize(UnsafeMutablePointer<Int8>.alloc(self.blockSize))
        }
        
        self._length = 0
    }
    
    func length() -> Int
    {
        return self._length
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
 
    func appendData(data : JZWData)
    {
        while self._length + data._length > self.space
        {
            self.resizeByAddingBlocks(self.numBlocks)
        }

        let inputDataSize = data._length
        
        var dataIndex = self._length
        
        let safeBlocks = self.blocks
        
        for i in 0 ..< inputDataSize
        {
            let inputBlockIndex = i / data.blockSize
            let inputInnerIndex = i % data.blockSize
            
            let blockIndex = dataIndex / self.blockSize
            let innerIndex = dataIndex % self.blockSize
            
            safeBlocks[blockIndex][innerIndex] = data.blocks[inputBlockIndex][inputInnerIndex]
            
            dataIndex++
        }

        self._length += inputDataSize
    }

    func resizeByAddingBlocks(nb : Int)
    {
        let newBlocks = UnsafeMutablePointer<UnsafeMutablePointer<Int8>>.alloc(self.numBlocks + nb)

        newBlocks.moveInitializeFrom(self.blocks, count: self.numBlocks)
                
        for i in self.numBlocks ..< self.numBlocks + nb
        {
            newBlocks.advancedBy(i).initialize(UnsafeMutablePointer<Int8>.alloc(self.blockSize))
        }
        
        self.oldBlockLists.append(self.blocks)
        self.blocks = newBlocks
        self.numBlocks += nb
    }
    
    func getBytes(inout range : NSRange) -> UnsafeMutablePointer<Int8>
    {
        if range.length <= 0 || range.location > self._length
        {
            return nil;
        }
    
        if range.location + range.length > self._length
        {
            range.length = self._length - range.location;
        }
        
        let bytes = UnsafeMutablePointer<Int8>.alloc(range.length)
        
        var byteIndex = 0
        
        let startBlockIndex = range.location / self.blockSize;
        let startInnerIndex = range.location % self.blockSize;
    
        let endIndex = range.location + range.length - 1
        let endBlockIndex = endIndex / self.blockSize;
        let endInnerIndex = endIndex % self.blockSize;
    
        let safeBlocks = self.blocks
    
        if startBlockIndex < endBlockIndex
        {
            byteIndex = self.blockSize - startInnerIndex;
            memcpy(bytes, safeBlocks[startBlockIndex] + startInnerIndex, byteIndex);
        }
        else
        {
            memcpy(bytes, safeBlocks[startBlockIndex] + startInnerIndex, endInnerIndex - startInnerIndex + 1);
            return bytes;
        }
        
        for i in startBlockIndex + 1 ..< endBlockIndex
        {
            memcpy(bytes + byteIndex, safeBlocks + i, self.blockSize);
            byteIndex += self.blockSize;
        }
        
        memcpy(bytes + byteIndex, safeBlocks[endBlockIndex], endInnerIndex + 1);
        
        return bytes;
    }

    func iterateWithBlock(block : ((Int8) -> Bool), inRange range : NSRange)
    {
        let safeBlocks = self.blocks
        
        for i in range.location ..< range.location + range.length
        {
            let blockIndex = i / self.blockSize;
            let innerIndex = i % self.blockSize;
        
            if (block(safeBlocks[blockIndex][innerIndex]))
            {
                return;
            }
        }
        
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

    deinit
    {
        for i in 0 ..< self.numBlocks
        {
            self.blocks[i].dealloc(self.blockSize)
        }
        
        self.blocks.destroy(self.numBlocks)
        self.blocks.dealloc(self.numBlocks)
        
        var nb = self.numBlocks / 2
        while self.oldBlockLists.count > 0
        {
            let old = self.oldBlockLists.removeLast()
            old.dealloc(nb)
            nb /= 2
        }
    }
}






