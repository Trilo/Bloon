//
//  JZWIndexedDictionary.swift
//  Bloon
//
//  Created by Jacob Weiss on 2/10/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWIndexedDictionary<K : AnyObject, V>
{
    var keysToIndexes : NSDictionary
    var values : UnsafeMutablePointer<V>
    
    init(withIndexMap map: NSDictionary)
    {
        self.keysToIndexes = map
        self.values = UnsafeMutablePointer<V>.alloc(map.count)
    }
    
    func setValue(value : V, forKey : K)
    {
        if let indexBox = self.keysToIndexes.objectForKey(forKey), let index = indexBox.intValue
        {
            self.values[Int(index)] = value
        }
    }
    
    func getValueForKey(key : K) -> V
    {
        if let indexBox = self.keysToIndexes.objectForKey(key), let index = indexBox.intValue
        {
            return self.values[Int(index)]
        }
        assert(false)
        return self.values[0]
    }
    
    deinit
    {
        self.values.destroy()
    }
}
