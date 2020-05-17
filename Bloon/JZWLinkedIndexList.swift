//
//  LinkedIndexList.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/16/15.
//  Copyright © 2015 Jacob Weiss. All rights reserved.
//

import Cocoa

/**
JZWLinkedIndexIterator

This class provides an efficient mechanism for looping through a range of integers while simultaneously removing them from the range. The integers in the range are not guaranteed to be provided in any particular order.
*/
class JZWLinkedIndexIterator
{
    private var curr : JZWLinkedIndexList!
    private var prev : JZWLinkedIndexList!
    
    init(range : Range<Int>)
    {
        self.prev = JZWLinkedIndexList(range: range)
        self.curr = prev.next
    }
    
    /**
    When at the end of the range, next() will circle around to the beginning of the list. If the list is empy, it returns nil
    */
    func next() -> Int?
    {
        if self.curr == nil
        {
            return nil
        }
        
        self.prev = self.curr
        self.curr = self.curr.next
        
        return self.curr.index
    }
    
    /**
    If called following next(), the index that was returned is removed from the set. Otherwise, behavior is undefined.
    */
    func remove()
    {
        if self.curr === self.prev
        {
            self.curr = nil
            self.prev = nil
        }
        else
        {
            self.prev.next = self.curr.next
            self.curr = self.curr.next
        }
    }
    
    private class JZWLinkedIndexList
    {
        var index : Int
        var next : JZWLinkedIndexList
        
        private init(index : Int, node : JZWLinkedIndexList)
        {
            self.index = index
            self.next = node
        }
        
        convenience init(range : Range<Int>)
        {
            self.init(index: range.first!, node: self)

            var node = self
            for i in range.dropFirst().reverse()
            {
                node = JZWLinkedIndexList(index: i, node: node)
            }
            
            self.next = node
        }
        
    }
}
