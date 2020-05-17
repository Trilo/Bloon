//
//  JZWTextField.swift
//  Bloon
//
//  Created by Jacob Weiss on 1/27/15.
//  Copyright (c) 2015 Jacob Weiss. All rights reserved.
//

import Foundation

protocol JZWTextFieldDelegate : NSTextFieldDelegate
{
    func userTypedCharacterInTextField(_ sender: AnyObject?)
    func escapeKeyPressed(_ sender: AnyObject?)
}

class JZWTextField: NSTextField
{
    var fieldEditor : JZWFieldEditor? = nil
    
    func getFieldEditor() -> JZWFieldEditor
    {
        if self.fieldEditor == nil
        {
            self.fieldEditor = JZWFieldEditor()
            self.fieldEditor?.associatedTextField = self
        }
        
        return self.fieldEditor!
    }
    
    func getAssociatedFieldEditor() -> JZWFieldEditor
    {
        return self.window?.fieldEditor(true, for: self)! as! JZWFieldEditor
    }
    
    override func keyDown(with event: NSEvent)
    {
        if (event.keyCode == 53) // Escape key
        {
            return
        }
        super.keyDown(with: event)
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool
    {
        return event.keyCode == 53
    }
    
    override func keyUp(with theEvent: NSEvent)
    {
        super.keyUp(with: theEvent)

        let characters = CharacterSet.alphanumerics
        let punctuation = CharacterSet.punctuationCharacters

        if (theEvent.keyCode == 53) // Escape key
        {
            (self.delegate! as! JZWTextFieldDelegate).escapeKeyPressed(self)
            return
        }
        
        for ch in theEvent.charactersIgnoringModifiers!.unicodeScalars
        {
            if !characters.contains(UnicodeScalar(ch.value)!) && !punctuation.contains(UnicodeScalar(ch.value)!)
            {
                return
            }
        }
                
        if self.delegate != nil
        {
            if (self.delegate!.responds(to: #selector(JZWPlotViewController.userTypedCharacterInTextField(_:))))
            {
                (self.delegate! as! JZWTextFieldDelegate).userTypedCharacterInTextField(self)
            }
        }
    }
}

