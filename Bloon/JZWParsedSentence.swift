//
//  JZWParsedSentence.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/5/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

typealias JZWParsedSentencePointer = UnsafeMutablePointer<JZWParsedSentenceData>

/*
JZWParsedSentence

Mediates between the low level C representation of a parsed sentence and the higher level swift code.
*/
class JZWParsedSentence
{
    // Create and return a new parsed sentence structure from the given sentence at the given index.
    // The underlying object is not reference counted and needs to be manually destroyed with the destroy function.
    final class func new(_ sentence: JZWSentence, index: Int) -> JZWParsedSentencePointer
    {
        let newData = JZWParsedSentenceData_new(UInt32(index), Date().timeIntervalSince1970, UInt32(sentence.tokenMap.count))
        sentence.appendParsedValue(newData!)
        
        return newData!
    }
    
    // Destroys the given parsed sentence structure
    final class func destroy(_ jps : JZWParsedSentencePointer)
    {
        JZWParsedSentenceData_destroy(jps);
    }

    final class func saveData(_ jps : JZWParsedSentencePointer, sentence : JZWSentence, forceSaveAscii: Bool) -> (rawData : NSMutableData, parsedData : NSMutableData)
    {
        let str = NSMutableString(string: NSNumber(value: JZWParsedSentenceData_getTimeStamp(jps)).stringValue)
        str.append(" ")
        
        let data = sentence.data!
        let index = JZWParsedSentenceData_getIndex(jps)
        
        return sentence.saveData(data, index: Int(index), forceSaveAscii: forceSaveAscii, str : str)
    }
    
    final class func parse(_ jps : JZWParsedSentencePointer, sentence : JZWSentence)
    {
        let index = JZWParsedSentenceData_getIndex(jps)
        sentence.parse(Int(index), parsedSentence : jps)
        JZWParsedSentenceData_setState(jps, ParsingState_Parsed)
    }
    
    final class func getNumericValueNoBlock(_ jps : JZWParsedSentencePointer, sentence : JZWSentence, label: String) -> Double?
    {
        let state = JZWParsedSentenceData_getState(jps)
        switch state
        {
        case ParsingState_Unparsed: // If unparsed, then parse and return the requested value
            JZWParsedSentenceData_setState(jps, ParsingState_Parsing)
            JZWParsedSentence.parse(jps, sentence: sentence)
            return JZWParsedSentence.getValueForKey(label as NSString, jps: jps, sentence: sentence)
            
        case ParsingState_Parsing: // If another thread requests data while this is being parsed, return nil
            return nil
            
        case ParsingState_Parsed: // Return the requested value
            return JZWParsedSentence.getValueForKey(label as NSString, jps: jps, sentence: sentence)
            
        default:
            assert(false)
        }
        return nil
    }
    
    final class func setValue(_ value : Double, forKey : NSString, jps : JZWParsedSentencePointer, sentence : JZWSentence)
    {
        let array = JZWParsedSentenceData_getParsedValuesArray(jps)
        if let indexBox = sentence.tokenMap.object(forKey: forKey), let index = (indexBox as? NSNumber)?.int32Value
        {
            array![Int(index)] = value
        }
    }
    
    private class func getValueForKey(_ key : NSString, jps : JZWParsedSentencePointer, sentence : JZWSentence) -> Double
    {
        let array = JZWParsedSentenceData_getParsedValuesArray(jps)
        if let indexBox = sentence.tokenMap.object(forKey: key), let index = (indexBox as? NSNumber)?.int32Value
        {
            return array![Int(index)]
        }
        assert(false)
        return array![0]
    }
}








