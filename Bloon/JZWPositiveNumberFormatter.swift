//
//  JZWPositiveNumberFormatter.swift
//  Bloon
//
//  Created by Jacob Weiss on 1/26/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWPositiveNumberFormatter: Formatter
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
            set.formUnion(with: CharacterSet.decimalDigits)
            
            set.invert()
            illegalSet = set as CharacterSet
            
            return illegalSet!
        }
    }
    
    override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool
    {
        if let _ = partialString.rangeOfCharacter(from: JZWPositiveNumberFormatter.illegalCharacterSet)
        {
            return false
        }
        
        return true
    }
    
    
    override func editingString(for obj: Any) -> String? {
        return obj as? String

    }
    override func string(for obj: Any?) -> String? {
        return obj as? String

    }

    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool
    {
        obj?.pointee = string as AnyObject?
        return true
    }

}
