//
//  JZWFieldEditor.swift
//  Bloon
//
//  Created by Jacob Weiss on 1/26/15.
//  Copyright (c) 2015 Jacob Weiss. All rights reserved.
//

import Foundation


class JZWFieldEditor: NSTextView
{
    var completionRange: NSRange = NSMakeRange(0, 0)
    var completions: [String] = [String]()
    var completionEnabled = true
    
    weak var associatedTextField: JZWTextField?
    
    override var rangeForUserCompletion: NSRange
    {
        return self.completionRange
    }
    
    override func completions(forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]?
    {
        if !self.completionEnabled
        {
            return nil
        }
        
        index.pointee = -1;
        return self.completions
    }
    
    override func insertCompletion(_ word: String, forPartialWordRange charRange: NSRange, movement: Int, isFinal flag: Bool)
    {
        // suppress completion if user types a space
        if (movement != NSOtherTextMovement && movement != NSUpTextMovement && movement != NSDownTextMovement && movement != NSReturnTextMovement)
        {
            return
        }
        
        super.insertCompletion(word, forPartialWordRange: charRange, movement: movement, isFinal: flag)
    }

    func getHeight() -> CGFloat
    {
        let manager = self.layoutManager!
        let numberOfGlyphs = manager.numberOfGlyphs
        
        var numberOfLines : CGFloat = 0
        var index = 0
        
        while index < numberOfGlyphs
        {
            var lineRange = NSRange()
            manager.lineFragmentRect(forGlyphAt: index, effectiveRange: &lineRange)
            index = NSMaxRange(lineRange);
            numberOfLines += 1
        }
        
        if self.string.last == "\n"
        {
            numberOfLines += 1
        }
        
        let lineHeight = CGFloat(manager.defaultLineHeight(for: self.font!))
        return numberOfLines == 0 ? lineHeight + 5 : numberOfLines * lineHeight + 5
    }
}
