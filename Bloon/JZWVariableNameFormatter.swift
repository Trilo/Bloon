//
//  JZWVariableNameFormatter.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/22/15.
//  Copyright © 2015 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWVariableNameFormatter: Formatter
{
    private static var illegalSet : CharacterSet? = nil

    static var illegalCharacterSet : CharacterSet
    {
        get
        {
            if let s = illegalSet
            {
                return s
            }
            
            let set = NSMutableCharacterSet()
            set.formUnion(with: CharacterSet.lowercaseLetters)
            set.formUnion(with: CharacterSet.uppercaseLetters)
            set.formUnion(with: CharacterSet.decimalDigits)
            
            set.invert()
            illegalSet = set as CharacterSet
            
            return illegalSet!
        }
    }
    
    override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if let _ = partialString.rangeOfCharacter(from: JZWVariableNameFormatter.illegalCharacterSet)
        {
            return false
        }
        
        return true
    }
    
    override func string(for obj: Any?) -> String? {
        return obj as? String

    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
                                 for string: String,
                                 errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool
    {
        obj?.pointee = string as AnyObject?
        return true        
    }
}
