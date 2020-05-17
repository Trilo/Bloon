//
//  JZWMrSwArray.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/14/15.
//  Copyright © 2015 Jacob Weiss. All rights reserved.
//

import Cocoa

enum JZWMrSwArrayError: Error
{
    case invalidRange
}

@inline(__always) func atomicSet<E>(_ target : UnsafeMutablePointer<UnsafeMutablePointer<E>?>!, _ new_value : UnsafeMutablePointer<E>!)
{
    _ = target.withMemoryRebound(to: Optional<UnsafeMutableRawPointer>.self, capacity: 1) { (ptr : UnsafeMutablePointer<UnsafeMutableRawPointer?>) in
        OSAtomicCompareAndSwapPtr(UnsafeMutableRawPointer(target.pointee), UnsafeMutableRawPointer(new_value), ptr)
    }
}

infix operator ⚛=
func ⚛=<E> ( lhs : inout UnsafeMutablePointer<E>?, rhs : UnsafeMutablePointer<E>!)
{
    atomicSet(&lhs, rhs)
}

class JZWMrSwArray<T>
{
    var blockSize : Int64 = 0
    var numBlocks : Int64 = 0
    
    var blocks : UnsafeMutablePointer<UnsafeMutablePointer<T>>? = nil
    var _length : Int64 = 0
    
    private var oldBlockLists : [UnsafeMutablePointer<UnsafeMutablePointer<T>>] = []
    
    var space : Int
    {
        get
        {
            return Int(self.numBlocks * self.blockSize)
        }
    }
    
    var count : Int
    {
        get
        {
            return Int(self._length)
        }
    }
    
    func length() -> Int
    {
        return Int(self._length)
    }
    
    subscript(index: Int) -> T
    {
        get
        {
            let blockIndex = index / Int(self.blockSize)
            let innerIndex = index % Int(self.blockSize)
            
            let safeBlocks = self.blocks
            
            let ret = safeBlocks?[blockIndex][innerIndex]
            return ret!
        }
    }

    init(blockSize : Int, numBlocks : Int)
    {
        self.blockSize = Int64(blockSize)
        self.numBlocks = Int64(numBlocks)
        
        self.blocks = UnsafeMutablePointer<UnsafeMutablePointer<T>>.allocate(capacity: Int(self.numBlocks))
        
        for i in 0 ..< Int(self.numBlocks)
        {
            self.blocks?.advanced(by: i).initialize(to: UnsafeMutablePointer<T>.allocate(capacity: Int(self.blockSize)))
        }
        
        self._length = 0
    }
    
    deinit
    {
        // Destroy all initialized locations
        let blockIndex = Int(self._length / self.blockSize)
        let innerIndex = Int(self._length % self.blockSize)
        
        self.blocks?[blockIndex].deinitialize(count: innerIndex)
        for i in 0 ..< blockIndex
        {
            self.blocks?[i].deinitialize(count: Int(self.blockSize))
        }
        
        // Dealloc all blocks
        for i in 0 ..< Int(self.numBlocks)
        {
            self.blocks?[i].deallocate()
        }
        
        // Dealloc current block list
        self.blocks?.deinitialize(count: Int(self.numBlocks))
        self.blocks?.deallocate()
        self.blocks = nil
        
        // Dealloc all old block lists
        var nb = self.numBlocks / 2
        while self.oldBlockLists.count > 0
        {
            let old = self.oldBlockLists.removeLast()
            old.deallocate()
            nb /= 2
        }
    }
    
    // ********************************** Writer Functions (One Thread Only) **********************************
    
    func resizeByAddingBlocks(_ nb : Int)
    {
        let newBlocks = UnsafeMutablePointer<UnsafeMutablePointer<T>>.allocate(capacity: Int(self.numBlocks) + nb)
        
        newBlocks.moveInitialize(from: self.blocks!, count: Int(self.numBlocks))
        
        for i in self.numBlocks ..< self.numBlocks + Int64(nb)
        {
            newBlocks.advanced(by: Int(i)).initialize(to: UnsafeMutablePointer<T>.allocate(capacity: Int(self.blockSize)))
        }
        
        self.oldBlockLists.append(self.blocks!)
        
        self.blocks ⚛= newBlocks
        OSAtomicAdd64(Int64(nb), &self.numBlocks)
    }

    func append(_ element : T)
    {
        while Int(self._length + 1) > self.space
        {
            self.resizeByAddingBlocks(Int(self.numBlocks))
        }

        let index = self._length
        let blockIndex = Int(index / self.blockSize)
        let innerIndex = Int(index % self.blockSize)
        
        let safeBlocks = self.blocks
        
        safeBlocks?[blockIndex].advanced(by: innerIndex).initialize(to: element)
        OSAtomicIncrement64(&self._length)
    }
    
    func appendData(_ data : JZWMrSwArray<T>)
    {
        while Int(self._length + data._length) > self.space
        {
            self.resizeByAddingBlocks(Int(self.numBlocks))
        }
        
        let inputDataSize = Int(data._length)
        
        var dataIndex = Int(self._length)
        
        let safeBlocks = self.blocks
        
        for i in 0 ..< inputDataSize
        {
            let inputBlockIndex = i / Int(data.blockSize)
            let inputInnerIndex = i % Int(data.blockSize)
            
            let blockIndex = dataIndex / Int(self.blockSize)
            let innerIndex = dataIndex % Int(self.blockSize)
            
            safeBlocks?[blockIndex][innerIndex] = (data.blocks?[inputBlockIndex][inputInnerIndex])!
            
            dataIndex += 1
        }

        OSAtomicAdd64(Int64(inputDataSize), &self._length)
    }
    
    // ********************************** Reader Functions (Many Threads) **********************************

    func iterateWithBlock(_ block : ((T) -> Bool), inRange range : NSRange)
    {
        self.iterateRange(range) { (data : UnsafeMutablePointer<T>, length : Int) -> Bool in
            for i in 0..<length {
                if block(data[i]) {
                    return true
                }
            }
            return false
        }
    }

    func iterateRange(_ range : NSRange, withBlock block : ((UnsafeMutablePointer<T>, Int) -> Bool)) {
        var byteIndex = 0
        
        let startBlockIndex = range.location / Int(self.blockSize)
        let startInnerIndex = range.location % Int(self.blockSize)
        
        let endIndex = range.location + range.length - 1
        let endBlockIndex = endIndex / Int(self.blockSize)
        let endInnerIndex = endIndex % Int(self.blockSize)
        
        let safeBlocks = self.blocks
                
        if startBlockIndex < endBlockIndex
        {
            byteIndex = Int(self.blockSize) - startInnerIndex;
            if block(safeBlocks![startBlockIndex] + startInnerIndex, byteIndex) {
                return
            }
        }
        else
        {
            _ = block(safeBlocks![startBlockIndex] + startInnerIndex, (endInnerIndex - startInnerIndex + 1))
            return
        }
        
        for i in startBlockIndex + 1 ..< endBlockIndex
        {
            if block(safeBlocks![i], Int(self.blockSize)) {
                return
            }
        }
        
        if block(safeBlocks![endBlockIndex], Int(endInnerIndex + 1)) {
            return
        }
    }
    
    func last() -> T
    {
        return self[Int(self._length) - 1]
    }
        
    func getRaw(_ range : inout NSRange) throws -> UnsafeMutablePointer<T>
    {
        if range.length <= 0 || range.location >= Int(self._length)
        {
            throw JZWMrSwArrayError.invalidRange
        }
        
        if range.location + range.length > Int(self._length)
        {
            range.length = Int(self._length) - range.location;
        }
        
        let raw = UnsafeMutablePointer<T>.allocate(capacity: range.length + 1)
        var byteIndex = 0

        self.iterateRange(range) { (data : UnsafeMutablePointer<T>, length : Int) -> Bool in
            memcpy(raw + byteIndex, data, length * MemoryLayout<T>.stride);
            byteIndex += length
            return false
        }
        
        return raw;
    }
}
