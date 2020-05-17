//
//  JZWDataToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/12/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWParsableDataToken: JZWToken
{
    var parser : JZWParser
    
    init(label: String, parser: JZWParser)
    {
        self.parser = parser
                
        super.init(label: label, numBytes: 1, format: ByteFormat.signedBigEndian)
    }
    
    override func copy() -> JZWToken
    {
        return JZWParsableDataToken(label: self.label, parser: self.parser)
    }
    
    override func errorReport() -> String {
        let myErrors = super.errorReport()
        let subErrors = self.parser.errorReport().indentByTabs(1)
        
        return "\(myErrors)\r\n\(subErrors)"
    }
    
    override func dataIsValid(_ data: JZWData, start: Int, index: Int, end: Int) -> (valid: Bool, bytesRead: Int, validBlocks: [() -> Void]?)
    {
        self.isValid = true
        return (true, end - index,
            [
                {
                    do
                    {
                        try self.parser.readData(data.subdataWithRange(NSMakeRange(index, end - index)))
                    }
                    catch {}
                }
            ]
        )
    }
    
    override func toAscii(_ data: JZWData, index: Int, end: Int) -> (ascii: String, numBytes: Int)
    {
        //let subdata = data.subdataWithRange(NSMakeRange(index, data.length - index))
        let str = "Parsed Data" //NSString(data: subdata, encoding: NSASCIIStringEncoding)
        
        return (str, end - index)
    }
    
    override func parse(_ data: JZWData, index: Int, end: Int, parsedValue: JZWParsedSentencePointer, sentence : JZWSentence, basePath: NSString) -> Int
    {
        return end - index
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        return other is JZWParsableDataToken
    }
    
    override func getAllSentences(_ allSentences: inout [String : JZWSentence])
    {
        self.parser.getAllSentences(&allSentences)
    }
    
    deinit
    {
        // Swift.print("Deinit Parsable Data Token: " + self.parser.name)
    }
}
