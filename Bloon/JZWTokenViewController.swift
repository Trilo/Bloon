//
//  TokenView.swift
//  Bloon
//
//  Created by Jacob Weiss on 12/7/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Foundation

// Label + numBytes + value + button

let TOKEN_LABELS_CHANGED_NOTIFICATION = "TOKENLABELSCHANGEDNOTIFICATION"

let TokenInterfaceTypes : [TokenType : (hasNumBytesField: Bool, hasFormatField: Bool, hasValueField: Bool, hasDescendent: Bool)] =
[
    TokenType.Group :                   (false, false, false, true),
    TokenType.ConstLengthGroup :        (true,  true,  false, true),
    TokenType.FixedLengthGroup :        (true,  false, false, true),
    TokenType.TerminatedString :        (false, false, true,  false),
    TokenType.NullTerminatedString :    (false, false, false, false),
    TokenType.ConstString :             (false, false, true,  false),
    TokenType.BinInt :                  (true,  true,  false, false),
    TokenType.ConstBinInt :             (true,  true,  true,  false),
    TokenType.Char :                    (false, false, false, false),
    TokenType.ConstChar :               (false, false, true,  false),
    TokenType.AsciiInt :                (false, false, false, false),
    TokenType.AsciiDouble :             (false, false, false, false),
    TokenType.AsciiHex :                (false, false, false, false),
    TokenType.ConstLengthAsciiInt :     (true,  false, false, false),
    TokenType.ConstLengthAsciiDouble :  (true,  false, false, false),
    TokenType.ConstLengthAsciiHex :     (true,  false, false, false),
    TokenType.ParsableData :            (false, false, false, true),
    TokenType.Repeat :                  (true,  false, false, true)
]

let ShortTokenNames : [TokenType : String] =
[
    TokenType.ConstLengthGroup :       "ConLenGroup",
    TokenType.FixedLengthGroup :       "FixLenGroup",
    TokenType.NullTerminatedString :   "NullTermStr",
    TokenType.ConstLengthAsciiInt :    "ConLenAscInt",
    TokenType.ConstLengthAsciiDouble : "ConLenAscDoub",
    TokenType.ConstLengthAsciiHex :    "ConLenAscHex"
]

enum ByteFormat : Int
{
    case unsignedLittleEndian = 0
    case unsignedBigEndian = 1
    case signedLittleEndian = 2
    case signedBigEndian = 3
}

class JZWTokenModel
{
    var type: TokenType = TokenType.Char
    var label: String = ""
    var numBytes: Int = 1
    var format: Int = 2
    var value: String = ""
}

class JZWTokenViewController: JZWMiniSettingsViewController, NSControlTextEditingDelegate, NSTextFieldDelegate
{
    var model = JZWTokenModel()
    
    @IBOutlet var typeLabel: NSTextField!
    @IBOutlet var label: NSTextField!
    @IBOutlet var numBytesField: NSTextField!
    @IBOutlet var byteFormat: NSPopUpButton!
    @IBOutlet var valueField: NSTextField!
    @IBOutlet var descendentButton: NSButton!
    
    var descendent: NSViewController?
    var type: TokenType?

    // ****************************************** Initialization ******************************************

    init(type: TokenType)
    {
        super.init(nibName: "JZWTokenView", bundle: nil)
           
        if type == TokenType.Group || type == TokenType.ConstLengthGroup || type == TokenType.FixedLengthGroup || type == TokenType.Repeat
        {
            self.descendent = JZWTokenTableController()
            if (type == TokenType.ConstLengthGroup || type == TokenType.FixedLengthGroup)
            {
                (self.descendent! as! JZWTokenTableController).isGroupController = true
            }
        }
        else if type == TokenType.ParsableData
        {
            self.descendent = JZWParserViewController()
        }
        
        self.type = type
        self.model.type = type
    }

    required convenience init?(coder: NSCoder)
    {
        self.init(type:TokenType(rawValue: coder.decodeObject(forKey: "type") as! String)!)
        
        self.model.label = coder.decodeObject(forKey: "label") as! String
        self.model.numBytes = Int(coder.decodeInt32(forKey: "numBytes"))
        self.model.value = coder.decodeObject(forKey: "value") as! String
        self.model.format = Int(coder.decodeInt32(forKey: "format"))
        
        if self.type == TokenType.Group || self.type == TokenType.ConstLengthGroup || self.type == TokenType.FixedLengthGroup || type == TokenType.Repeat
        {
            self.descendent = coder.decodeObject(forKey: "descendent") as! JZWTokenTableController
            if (type == TokenType.ConstLengthGroup || type == TokenType.FixedLengthGroup)
            {
                (self.descendent! as! JZWTokenTableController).isGroupController = true
            }
        }
        else if type == TokenType.ParsableData
        {
            self.descendent = coder.decodeObject(forKey: "descendent") as! JZWParserViewController
        }
    }

    override func encode(with aCoder: NSCoder)
    {
        let m = self.model as JZWTokenModel
        
        aCoder.encode(m.type.rawValue, forKey: "type")
        aCoder.encode(Int32(m.numBytes), forKey: "numBytes")
        aCoder.encode(m.label, forKey: "label")
        aCoder.encode(m.value, forKey: "value")
        aCoder.encode(Int32(m.format), forKey: "format")
        
        if self.descendent != nil
        {
            aCoder.encode(self.descendent!, forKey: "descendent")
        }
    }

    override func viewDidLoad()
    {
        (self.view as! JZWGradient).initialize()
        (self.view as! JZWGradient).borderWidth = 2
        (self.view as! JZWGradient).borderColor = NSColor.white
        (self.view as! JZWGradient).cornerRadius = 19
        (self.view as! JZWGradient).setDarkDarkBlue()
        
        self.setupInterface()
        
        self.label.stringValue = self.model.label
        self.numBytesField.stringValue = "\(self.model.numBytes)"
        self.valueField.stringValue = self.model.value
        self.byteFormat.selectItem(at: self.model.format)
        self.label.delegate = self
    }
    
    // ****************************************** My Overrides ******************************************
    
    override func build(_ fullPath: NSString, userData: inout [String: AnyObject]?) -> AnyObject?
    {
        let label = self.model.label
        let nb = self.model.numBytes
        let format = ByteFormat(rawValue: self.model.format)!
        let value = self.model.value
        
        let p = NSString(format: "%@.%@", fullPath, label)
        
        var t : JZWToken? = nil
        switch self.model.type
        {
        case TokenType.AsciiDouble:             t = JZWAsciiDoubleToken(label: label)
        case TokenType.AsciiHex:                t = JZWAsciiHexToken(label: label)
        case TokenType.AsciiHexChecksum:        t = nil
        case TokenType.AsciiInt:                t = JZWAsciiIntToken(label: label)
        case TokenType.BinInt:                  t = JZWBinIntToken(label: label, numBytes: nb, format: format)
        case TokenType.Char:                    t = JZWCharToken(label: label)
        case TokenType.Checksum:                t = nil
        case TokenType.ConstBinInt:
            var v : Int = 0
            if let intValue = Int(value)
            {
                v = intValue
            }
            else if value.hasPrefix("0x")
            {
                v = Int(strtoul(value.replacingCharacters(in: value.range(of: "0x")!, with: ""), nil, 16))
            }
            else if value.hasPrefix("0b")
            {
                v = Int(strtoul(value.replacingCharacters(in: value.range(of: "0b")!, with: ""), nil, 2))
            }
            t = JZWConstBinIntToken(label: label, numBytes: nb, constValue: v, format: format)
        case TokenType.ConstChar:
            if value.count > 0 {
                t = JZWConstCharToken(label: label, char: value[0])
            }
        case TokenType.ConstLengthAsciiDouble:  t = JZWConstLengthAsciiDoubleToken(label: label, numBytes: nb)
        case TokenType.ConstLengthAsciiHex:     t = JZWConstLengthAsciiHexToken(label: label, numBytes: nb)
        case TokenType.ConstLengthAsciiInt:     t = JZWConstLengthAsciiIntToken(label: label, numBytes: nb)
        case TokenType.ConstLengthGroup:        t = JZWConstLengthGroupToken(label: label, tokens: (self.descendent! as! JZWTokenTableController).build(p, userData: &userData)! as! [JZWToken], numBytes: nb)
        case TokenType.FixedLengthGroup:        t = JZWFixedLengthGroupToken(label: label, tokens: (self.descendent! as! JZWTokenTableController).build(p, userData: &userData)! as! [JZWToken], numBytes: nb)
        case TokenType.ConstString:             t = JZWConstStringToken(label: label, string: value)
        case TokenType.Group:                   t = JZWGroupToken(label: label, tokens: (self.descendent! as! JZWTokenTableController).build(p, userData: &userData)! as! [JZWToken])
        case TokenType.NullTerminatedString:    t = JZWNullTerminatedStringToken(label: label)
        case TokenType.ParsableData:            t = JZWParsableDataToken(label: label, parser: ((self.descendent! as! JZWParserViewController).build(p, userData: &userData)! as! JZWParserStarter).parser!)
        case TokenType.Repeat:
            var tokenList = [JZWToken]()
            for i in 0 ..< nb
            {
                let repeatedTokens = (self.descendent! as! JZWTokenTableController).build("\(p).\(i)" as NSString, userData: &userData)! as! [JZWToken]
                
                for repToken in repeatedTokens
                {
                    repToken.label = "\(i).\(repToken.label)"
                }
                tokenList += repeatedTokens
            }
            t = JZWRepeatToken(label: label, tokens: tokenList)
        case TokenType.TerminatedString:        t = JZWTerminatedStringToken(label: label, ch: value[0])
        }
        
        if t != nil
        {
            if userData![ALL_TOKEN_LABELS] == nil
            {
                userData![ALL_TOKEN_LABELS] = NSMutableDictionary()
            }
            if (label != "" && p.range(of: "..").location == NSNotFound)
            {
                (userData![ALL_TOKEN_LABELS] as! NSMutableDictionary).setValue(t!, forKey: p.trimmingCharacters(in: CharacterSet(charactersIn: ".")) as String)
            }
        }
        
        return t
    }

    func getAllTokenLabels() -> [String]
    {
        if type == TokenType.Group || type == TokenType.ConstLengthGroup || type == TokenType.ParsableData || type == TokenType.FixedLengthGroup
        {
            var allLabels = [String]()

            let labels = (self.descendent! as! JZWSettingsViewController).getAllTokenLabels()
            
            for label in labels
            {
                allLabels.append("\(self.model.label).\(label)")
            }
            return allLabels
        }
        else if type == TokenType.Repeat
        {
            var allLabels = [String]()
            
            let labels = (self.descendent! as! JZWSettingsViewController).getAllTokenLabels()
            for i in 0 ..< self.model.numBytes
            {
                allLabels.append(contentsOf: labels.map({"\(self.model.label).\(i).\($0)"}))
            }
            return allLabels
        }
        else if self.model.label != ""
        {
            return [self.model.label]
        }
        else
        {
            return []
        }
    }
    
    // ****************************************** Actions ******************************************

    @IBAction override func buttonPressed(_ sender: AnyObject)
    {
        var title = ""
        if self.type! == TokenType.Group || self.type! == TokenType.ConstLengthGroup || self.type! == TokenType.FixedLengthGroup || type == TokenType.Repeat
        {
            title = self.label.stringValue == "" ? "Group" : self.label.stringValue
        }
        else
        {
            let parserTitle = (self.descendent! as! JZWParserViewController).getTitle()
            title = (parserTitle == "") ? "Parser" : parserTitle
        }
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: HISTORYVIEW_PUSH_NOTIFICATION),
            object: self.view.window, userInfo: ["view" : self.descendent!.view, "title" : title])
    }

    @IBAction func formatChanged(_ sender: AnyObject)
    {
        self.model.format = (sender as! NSPopUpButton).indexOfSelectedItem
    }
    // ****************************************** Other Methods ******************************************
    
    func setupInterface()
    {
        let whichFields = TokenInterfaceTypes[self.type!]!

        self.numBytesField?.isHidden = !whichFields.hasNumBytesField
        self.byteFormat?.isHidden = !whichFields.hasFormatField
        self.valueField?.isHidden = !whichFields.hasValueField
        self.descendentButton?.isHidden = !whichFields.hasDescendent
        
        if let short = ShortTokenNames[self.type!]
        {
            self.typeLabel.stringValue = short
        }
        else
        {
            self.typeLabel.stringValue = self.type!.rawValue
        }
    }
    
    func controlTextDidChange(_ obj: Notification)
    {
        let field = obj.object! as! NSTextField
        
        if field == self.label
        {
            if (self.type! == TokenType.Group || self.type! == TokenType.ConstLengthGroup || self.type! == TokenType.FixedLengthGroup || self.type! == TokenType.Repeat)
            {
                let title = field.stringValue == "" ? "Group" : field.stringValue
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: HISTORYVIEW_TITLE_NOTIFICATION),
                    object: self.view.window, userInfo: ["view" : self.descendent!.view, "title" : title])
            }
            self.model.label = field.stringValue
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: TOKEN_LABELS_CHANGED_NOTIFICATION), object: self, userInfo: nil)
        }
        else if field == self.numBytesField
        {
            self.model.numBytes = field.integerValue
        }
        else if field == self.valueField
        {
            self.model.value = field.stringValue
        }
    }
    
    
}
