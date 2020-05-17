//
//  JZWGroupToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/8/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWGroupToken: JZWToken
{
    var tokens : [JZWToken]
    
    init(label: String, tokens: [JZWToken], numBytes: Int = 1)
    {
        self.tokens = tokens
        super.init(label: label, numBytes: numBytes, format: ByteFormat.signedBigEndian)
    }
    
    override func copy() -> JZWToken
    {
        return JZWGroupToken(label: self.label, tokens: self.tokens.map({$0.copy()}), numBytes: self.numBytes)
    }
    
    override func errorReport() -> String {
        var error = super.errorReport()
        for t in self.tokens
        {
            error = "\(error)\r\n\(t.errorReport().indentByTabs(1))"
        }
        return error
    }
    
    override func dataIsValid(_ data: JZWData, start: Int, index: Int, end: Int) -> (valid: Bool, bytesRead: Int, validBlocks: [() -> Void]?)
    {
        var i = 0
        var allBlocks : [() -> Void] = []
        
        for t in self.tokens
        {
            let (valid, bytesRead, blocks) = t.dataIsValid(data, start: index, index: index + i, end: end)
            
            if !valid
            {
                self.isValid = false
                return (false, bytesRead, nil)
            }
                        
            if let b = blocks
            {
                allBlocks += b
            }
            
            i += bytesRead
        }
        
        self.isValid = true
        return (true, i, allBlocks)
    }
    
    override func toAscii(_ data: JZWData, index: Int, end: Int) -> (ascii: String, numBytes: Int)
    {
        let str = NSMutableString(string: "[")
        var i = 0
        
        let numTokens = self.tokens.count;
        
        for j in 0 ..< numTokens
        {
            let t = self.tokens[j]
            let (s, j) = t.toAscii(data, index: index + i, end: end)
            
            if t.label != ""
            {
                str.append(s)
                str.append(" ")
            }
            
            i += j
        }
        
        str.append("]")
        
        return (str as String, i)
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        if other is JZWGroupToken
        {
            let gt = other as! JZWGroupToken
            
            if self.tokens.count != gt.tokens.count
            {
                return false
            }
            
            for i in 0 ..< self.tokens.count
            {
                if !self.tokens[i].equals(gt.tokens[i])
                {
                    return false
                }
            }
            return true
        }
        return false
    }
    
    override func getTokenLabels() -> [String]
    {
        var tl = [String]()
        
        for token in self.tokens
        {
            for label in token.getTokenLabels()
            {
                if !label.hasSuffix(".") && label != ""
                {
                    tl.append(self.label + ".\(label)")
                }
            }
        }
        
        return tl
    }

    override func parse(_ data: JZWData, index: Int, end: Int, parsedValue: JZWParsedSentencePointer, sentence : JZWSentence, basePath: NSString) -> Int
    {
        var bytesRead = 0
        
        let path = NSMutableString(string: basePath)
        path.append(self.label)
        path.append(".")
        
        for t in self.tokens
        {
            bytesRead += t.parse(data, index: index + bytesRead, end: end, parsedValue: parsedValue, sentence: sentence, basePath: path)
        }
        
        return bytesRead
    }
    
    override func getAllSentences(_ allSentences: inout [String: JZWSentence])
    {
        for t in self.tokens
        {
            t.getAllSentences(&allSentences)
        }
    }
}










