//
//  JZWHeap.swift
//  Bloon
//
//  Created by Jacob Weiss on 6/11/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWMinHeap<T>
{
    let compareFunc : (_ element : T, _ isLessThan : T) -> (Bool)
    private var elements = [T]()
    
    init(compareFunc : @escaping (_ element : T, _ isLessThan : T) -> (Bool))
    {
        self.compareFunc = compareFunc
    }
    
    var count : Int
    {
        get
        {
            return elements.count
        }
    }
    
    func push(_ e : T)
    {
        self.elements.append(e)
        
        var insertIndex = self.elements.count - 1
        var parentIndex = (insertIndex - 1) / 2
        
        while insertIndex > 0 && self.compareFunc(e, self.elements[parentIndex])
        {
            self.elements[insertIndex] = self.elements[parentIndex]
            insertIndex = parentIndex
            parentIndex = (insertIndex - 1) / 2
        }
        self.elements[insertIndex] = e
    }
    
    func popMin() -> T?
    {
        if self.elements.count == 0
        {
            return nil
        }
        if self.elements.count == 1
        {
            return self.elements.removeLast()
        }
        
        let element = self.elements[0]
        self.elements[0] = self.elements.removeLast()
        
        var removeIndex = 0
        
        while true
        {
            let left = removeIndex * 2 + 1
            let right = left + 1
            var smallest = removeIndex
            
            if left < self.elements.count && self.compareFunc(self.elements[left], self.elements[smallest])
            {
                smallest = left
            }
            if right < self.elements.count && self.compareFunc(self.elements[right], self.elements[smallest])
            {
                smallest = right
            }
            
            if smallest != removeIndex
            {
                (self.elements[smallest], self.elements[removeIndex]) = (self.elements[removeIndex], self.elements[smallest])
                removeIndex = smallest
            }
            else
            {
                break
            }
        }
        
        return element
    }
    
    func peekMin() -> T?
    {
        return self.elements.first
    }
}
