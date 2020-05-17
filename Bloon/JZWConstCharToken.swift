//
//  JZWConstCharToken.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/11/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

extension Character
{
    func unicodeScalarCodePoint() -> Int
    {
        let characterString = String(self)
        let scalars = characterString.unicodeScalars
        
        return Int(scalars[scalars.startIndex].value)
    }
}

class JZWConstCharToken: JZWConstBinIntToken
{
    let char : Character
    init(label: String, char: Character)
    {
        self.char = char
        super.init(label: label, numBytes: 1, constValue: char.unicodeScalarCodePoint(), format: ByteFormat.signedBigEndian)
    }
    
    override func copy() -> JZWToken
    {
        return JZWConstCharToken(label: self.label, char: self.char)
    }
    
    override func toAscii(_ data: JZWData, index: Int, end: Int) -> (ascii: String, numBytes: Int)
    {
        return (String(describing: UnicodeScalar(self.constValue)), self.numBytes)
    }
    
    override func equals(_ other : JZWToken) -> Bool
    {
        return (other is JZWConstCharToken) && ((other as! JZWConstCharToken).constValue == self.constValue)
    }
}




