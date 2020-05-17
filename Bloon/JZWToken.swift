//
//  JZWToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/3/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

enum TokenType: String
{
    case Repeat = "Repeat"
    case Group = "Group"
    case ConstLengthGroup = "ConstLengthGroup"
    case FixedLengthGroup = "FixedLengthGroup"
    case TerminatedString = "TerminatedString"
    case NullTerminatedString = "NullTerminatedString"
    case ConstString = "ConstString"
    case BinInt = "BinInt"
    case ConstBinInt = "ConstBinInt"
    case Char = "Char"
    case ConstChar = "ConstChar"
    case Checksum = "Checksum"
    case AsciiInt = "AsciiInt"
    case AsciiDouble = "AsciiDouble"
    case AsciiHex = "AsciiHex"
    case ConstLengthAsciiInt = "ConstLengthAsciiInt"
    case ConstLengthAsciiDouble = "ConstLengthAsciiDouble"
    case ConstLengthAsciiHex = "ConstLengthAsciiHex"
    case AsciiHexChecksum = "AsciiHexChecksum"
    case ParsableData = "ParsableData"
}

class JZWToken
{
    weak var builtToken : JZWToken? = nil
    //let pathDictionary = NSMutableDictionary()
    var cachedPath : NSString? = nil
    var label : String
    let numBytes : Int
    let format : ByteFormat
    let isLittleEndian : Bool
    let isSigned : Bool
    
    var invalidCount : Int = 0
    var totalCount : Int = 0
    var isValid : Bool
    {
        set
        {
            self.totalCount += 1
            self.invalidCount += newValue ? 0 : 1
        }
        get
        {
            return false
        }
    }
    
    init(label: String, numBytes: Int, format: ByteFormat)
    {
        self.label = label
        self.format = format
        self.numBytes = numBytes
        
        switch self.format
        {
            case .signedBigEndian, .unsignedBigEndian:
                self.isLittleEndian = false
            case .signedLittleEndian, .unsignedLittleEndian:
                self.isLittleEndian = true
        }
        switch self.format
        {
            case .signedBigEndian, .signedLittleEndian:
                self.isSigned = true
            case .unsignedBigEndian, .unsignedLittleEndian:
                self.isSigned = false
        }

    }
    
    func errorReport() -> String
    {
        if let t = self.builtToken
        {
            return t.errorReport()
        }
        else
        {
            let percentage = String(format: "%.2f", Double(self.invalidCount) / Double(self.totalCount) * 100)
            return "\(self.label) \(self.invalidCount)/\(self.totalCount) = \(percentage)%"
        }
    }
    
    func copy() -> JZWToken
    {
        return JZWToken(label: self.label, numBytes: self.numBytes, format: self.format)
    }
    
    func dataIsValid(_ data: JZWData, start: Int, index: Int, end: Int) -> (valid: Bool, bytesRead: Int, validBlocks: [() -> Void]?)
    {
        NSLog("This method must be overridden")
        return (false, self.numBytes, nil)
    } 

    func toAscii(_ data: JZWData, index: Int, end: Int) -> (ascii: String, numBytes: Int)
    {
        NSLog("This method must be overridden")
        return (String(), self.numBytes)
    }
    
    func equals(_ other : JZWToken) -> Bool
    {
        NSLog("This method must be overridden")
        return false
    }

    func parse(_ data: JZWData, index: Int, end: Int, parsedValue: JZWParsedSentencePointer, sentence : JZWSentence, basePath: NSString) -> Int
    {
        return 0
    }

    func getTokenLabels() -> [String]
    {
        return [self.label]
    }
    
    func getUnsignedIntValue(_ data: JZWData, index: Int) -> UInt
    {
        var range = NSMakeRange(index, self.numBytes)
        
        do
        {
            let bytes = try data.getBytes(&range)
            if range.length == 0
            {
                return 0
            }
            let val = _getUnsignedIntValue(bytes, Int32(self.numBytes), self.isLittleEndian)
            bytes.deallocate()
            return UInt(val)
        }
        catch
        {
            return 0
        }
    }
    func getIntValue(_ data: JZWData, index: Int) -> Int
    {
        var range = NSMakeRange(index, self.numBytes)
        
        do
        {
            let bytes = try data.getBytes(&range)
            let intValue = Int(getSignedIntValue(bytes, Int32(self.numBytes), self.isLittleEndian))
            bytes.deallocate()
            return intValue
        }
        catch
        {
            return 0
        }
    }
    
    func getByteValue(_ data: JZWData, index: Int) -> Int8
    {
        var range = NSMakeRange(index, self.numBytes)
        
        do
        {
            let bytes = try data.getBytes(&range)
            let byte = UnsafeMutablePointer<Int8>(bytes)[0]
            bytes.deallocate()
            return byte
        }
        catch
        {
            return 0
        }
    }
    
    
    func getReusablePath(_ basePath: NSString) -> NSString
    {
        objc_sync_enter(self)
        if let path = self.cachedPath
        {
            objc_sync_exit(self)
            return path
        }
        else
        {
            self.cachedPath = basePath.appending(self.label) as NSString?
            objc_sync_exit(self)
            return self.cachedPath!
        }
    }
    
    func getAllSentences(_ allSentences: inout [String: JZWSentence])
    {
    }
    
    var description: String
    {
        return self.label
    }

}
