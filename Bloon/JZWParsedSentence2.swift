//
//  JZWParsedSentence.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/5/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
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
}

class JZWParsedSentence2
{
    unowned var data: JZWData
    unowned var sentence: JZWSentence
    var index: Int
    var end: Int
    var timeStamp : NSTimeInterval
    var parsedNumericValuesArray : JZWIndexedDictionary<NSString, Double>!
    var doneParsing : Bool = false
    var isParsing : Bool = false
    
    init(data: JZWData, sentence: JZWSentence, index: Int, end: Int)
    {
        self.data = data
        self.sentence = sentence
        self.index = index
        self.end = end
        self.timeStamp = NSDate().timeIntervalSince1970
        self.parsedNumericValuesArray = nil

       // self.sentence.appendParsedValue(self)
    }
    
    func saveData() -> (rawData : NSMutableData, parsedData : NSMutableData)
    {
        let str = NSMutableString(string: NSNumber(double: self.timeStamp).stringValue)
        str.appendString(" ")
        
        return self.sentence.saveData(self.data, index: self.index, str : str)
    }
    
    func length() -> Int
    {
        return self.end - self.index
    }
    
    func parse()
    {
        /*
        let pv =  self.sentence.parse(self.data, index: self.index)
        let time = self.timeStamp
        pv.setValue(time, forKey: "TimeStamp") //["TimeStamp"] = time
        
        self.parsedNumericValuesArray = pv
        
        self.doneParsing = true
 */
    }
    
    
    func numericData() -> JZWIndexedDictionary<NSString, Double>
    {
        if self.parsedNumericValuesArray == nil
        {
            //objc_sync_enter(self)
            if self.parsedNumericValuesArray == nil
            {
                self.parse()
            }
            //objc_sync_exit(self)
        }
        
        return self.parsedNumericValuesArray
    }
    
    
    func getNumericValue(label: String) -> Double
    {
        return self.numericData().getValueForKey(label)
    }
    
    func getNumericValueNoBlock(label: String) -> Double?
    {
        if self.doneParsing
        {
            return self.parsedNumericValuesArray.getValueForKey(label)
        }
        
        objc_sync_enter(self)
        if self.isParsing
        {
            objc_sync_exit(self)
            return nil
        }
        else
        {
            self.isParsing = true
            objc_sync_exit(self)
            self.parse()
            return self.parsedNumericValuesArray.getValueForKey(label)
        }
    }

}








