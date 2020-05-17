//
//  JZWSentence.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/3/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWSentence
{
    var name: String
    var path: String
    var tokens : [JZWToken]
    private var parsedValues: JZWMrSwArray<JZWParsedSentencePointer>
    var savesAscii = true
    var savesBinary = true
    var asciiFile : FileHandle? = nil
    var binFile : FileHandle? = nil
    var saveQueue : DispatchQueue;
    var tokenMap : NSDictionary //[String : Int] // Maps token paths to indexes
    var data : JZWData? = nil
    
    init(path: String, tokens: [JZWToken])
    {
        self.path = path
        self.name = path.components(separatedBy: ".").last!
        self.tokens = tokens
        self.parsedValues = JZWMrSwArray<JZWParsedSentencePointer>(blockSize: 1000, numBlocks: 10)
        
        self.saveQueue = DispatchQueue(label: self.name + "SaveQueue", qos: DispatchQoS.utility, attributes: DispatchQueue.Attributes(), autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        
        // Generate the token map
        let map = NSMutableDictionary() //[String : Int]()
        map.setObject(0, forKey: "TimeStamp" as NSCopying)
        var i = 1
        for token in tokens
        {
            for label in token.getTokenLabels().map({"\(path).\($0)"})
            {
                if !label.hasSuffix(".")
                {
                    map.setObject(i, forKey: label as NSCopying)
                    i += 1
                }
            }
        }
        self.tokenMap = map
    }
    
    func errorReport() -> String
    {
        var errors = self.name
        for t in self.tokens
        {
            errors = "\(errors)\r\n\(t.errorReport().indentByTabs(1))"
        }
        return errors
    }

    func getToken(_ index: Int) -> JZWToken?
    {
        if (index >= self.tokens.count)
        {
            return nil
        }
        
        return self.tokens[index]
    }
    
    func getTokenLabels() -> [String]
    {
        var tl = [String]()
        
        for token in self.tokens
        {
            for label in token.getTokenLabels()
            {
                if !label.hasSuffix(".") && label != ""
                {
                    tl.append("\(self.name).\(label)")
                }
            }
        }
        
        return tl
    }
        
    func appendParsedValue(_ value: JZWParsedSentencePointer)
    {
        self.parsedValues.append(value)
    }
    
    func getMostRecentParsedValue() -> JZWParsedSentencePointer
    {
        let s = self.parsedValues.last()
        return s
    }

    func getParsedValue(_ index: Int) -> JZWParsedSentencePointer
    {
        let s = self.parsedValues[index]
        return s
    }
    
    func numParsed() -> Int
    {
        let num = self.parsedValues.count
        return num
    }
    
    // Binary search to find first parsed data after the provided time
    func findNextParsedData(_ time: TimeInterval, mindex: Int = 0) -> (JZWParsedSentencePointer?, Int)
    {
        var minIndex = mindex
        
        var maxIndex = self.parsedValues.count - 1
        
        if maxIndex < 0
        {
            return (nil, -1)
        }
        
        while maxIndex - minIndex > 1
        {
            let searchIndex = (minIndex + maxIndex) / 2
            
            let searchTime = JZWParsedSentenceData_getTimeStamp(self.getParsedValue(searchIndex))
            
            if time > searchTime
            {
                minIndex = searchIndex
            }
            else if time < searchTime
            {
                maxIndex = searchIndex
            }
            else
            {
                return (self.getParsedValue(searchIndex + 1), searchIndex + 1)
            }
        }
        let returnValue = (Optional<JZWParsedSentencePointer>(self.parsedValues[minIndex]), minIndex)

        return returnValue
    }
    
    // Binary search to find first parsed data after the provided data index
    func findNextParsedDataByIndex(_ index: Int64, mindex: Int = 0) -> (JZWParsedSentencePointer?, Int)
    {
        var minIndex = mindex
        
        var maxIndex = self.parsedValues.count - 1
        
        if maxIndex < 0
        {
            return (nil, -1)
        }
        
        /*
        for i in mindex ..< self.parsedValues.count
        {
            let searchTime = JZWParsedSentenceData_getIndex(self.getParsedValue(i))
                        
            if Int64(searchTime) > index
            {
                return (self.getParsedValue(i), i)
            }
        }
        return (nil, -1)*/

        while maxIndex - minIndex > 1
        {
            let searchIndex = (minIndex + maxIndex) / 2
            
            let indexOfSentence = JZWParsedSentenceData_getIndex(self.getParsedValue(searchIndex))
            
            if index > Int64(indexOfSentence)
            {
                minIndex = searchIndex
            }
            else if index < Int64(indexOfSentence)
            {
                maxIndex = searchIndex
            }
            else
            {
                return (self.getParsedValue(searchIndex + 1), searchIndex + 1)
            }
        }
        let returnValue = (Optional<JZWParsedSentencePointer>(self.parsedValues[minIndex]), minIndex)
        
        return returnValue
    }

    func toRawString(_ data: JZWData, index: Int) -> String
    {
        let str = NSMutableString()
        
        var i = index
        
        let numTokens = self.tokens.count
        for t in 0 ..< numTokens
        {
            let token = self.tokens[t]
            let (ascii, bytesRead) = token.toAscii(data, index: i, end: Int(data.length()) - 1)
            str.append(ascii)
            i += bytesRead
            str.append(" ")
        }
        
        str.append("\n")
        
        return str as String
    }
    
    func toRawBinary(_ data: JZWData, index: Int) -> NSMutableData
    {
        var i = index
        let numTokens = self.tokens.count
        for t in 0 ..< numTokens
        {
            let token = self.tokens[t]
            let (_, bytesRead) = token.toAscii(data, index: i, end: Int(data.length()) - 1)
            i += bytesRead
        }

        do
        {
            return try (data.subdataWithRange(NSMakeRange(index, i - index)) as NSData).mutableCopy() as! NSMutableData
        }
        catch
        {
            return NSMutableData()
        }
    }
    
    func createSaveFiles(_ path: String)
    {
        if self.savesAscii
        {
            let asciiPath = path + "_" + self.path + ".txt"
            FileManager.default.createFile(atPath: asciiPath, contents: nil, attributes: nil)
            self.asciiFile = FileHandle(forWritingAtPath:asciiPath)
        }

        if self.savesBinary
        {
            let binPath = path + "_" + self.path + ".dat"
            FileManager.default.createFile(atPath: binPath, contents: nil, attributes: nil)
            self.binFile = FileHandle(forWritingAtPath:binPath)
        }
    }
    
    func closeSaveFiles()
    {
        if self.binFile != nil
        {
            self.binFile!.closeFile()
            self.binFile = nil
        }
        if self.asciiFile != nil
        {
            self.asciiFile!.closeFile()
            self.asciiFile = nil
        }
    }
        
    func toString(_ data: JZWData, index: Int) -> String
    {
        let str = NSMutableString()
        str.append(self.name)
        str.append("[")
        
        var i = index
        let numTokens = self.tokens.count
        for t in 0 ..< numTokens
        {
            let token = self.tokens[t]
            let name = token.label
            var (ascii, bytesRead): (String, Int) = ("", token.numBytes)
            if (name != "")
            {
                (ascii, bytesRead) = token.toAscii(data, index: i, end: Int(data.length()) - 1)
                str.append(name)
                str.append(":")
                str.append(ascii)
                str.append("\t")
            }
            i += bytesRead
        }
        str.append("]")
        
        return str as String
    }
    
    func saveData(_ data: JZWData, index: Int, forceSaveAscii: Bool, str : NSMutableString = "") -> (rawData : NSMutableData, parsedData : NSMutableData)
    {
        var i = index

        if forceSaveAscii || self.savesAscii
        {
            let numTokens = self.tokens.count

            for t in 0 ..< numTokens
            {
                let token = self.tokens[t]
                let (ascii, bytesRead) = token.toAscii(data, index: i, end: Int(data.length()) - 1)
                
                if token.label != ""
                {
                    str.append(ascii)
                    str.append(" ")
                }
                
                i += bytesRead
            }
            str.append("\n")
        }
        
        do
        {
            let rawBinary = try (NSMutableData(data: NSData(data: data.subdataWithRange(NSMakeRange(index, i - index))) as Data))
            let rawString = NSMutableData(data: str.data(using: String.Encoding.ascii.rawValue, allowLossyConversion: false)!)

            if self.savesBinary && self.binFile != nil
            {
                self.binFile!.write(rawBinary as Data)
            }
            if self.savesAscii && self.asciiFile != nil
            {
                self.asciiFile!.write(rawString as Data)
            }
            
            return (rawBinary, rawString)
        }
        catch
        {
            return (NSMutableData(), NSMutableData())
        }
    }
    
    // Returns ([String:Double])
    final func parse(_ index: Int, parsedSentence : JZWParsedSentencePointer)
    {
        let data = self.data!
        let i = index
        var bytesRead = 0
        
        let basePath = NSMutableString(string: self.path)//NSMutableString(string: self.name)
        basePath.append(".")
        
        for token in self.tokens
        {
            bytesRead += token.parse(data, index: i + bytesRead, end: Int(data.length()) - 1, parsedValue: parsedSentence, sentence : self, basePath: basePath)
        }
    }
        
    func getAllSentences(_ allSentences: inout [String: JZWSentence])
    {
        for t in self.tokens
        {
            t.getAllSentences(&allSentences)
        }
    }
    
    deinit
    {
        for i in 0 ..< self.parsedValues.count
        {
            JZWParsedSentence.destroy(self.parsedValues[i])
        }
    }
}










