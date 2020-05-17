//
//  SentenceView.swift
//  Bloon
//
//  Created by Jacob Weiss on 12/7/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Foundation

class JZWSentenceModel: JZWSettingsModel
{
    @objc var savesAscii: Int = NSControl.StateValue.off.rawValue
    @objc var savesBinary: Int = NSControl.StateValue.off.rawValue
}

class JZWSentenceViewController: JZWSettingsViewController
{
    @IBOutlet var savesAscii: NSButton!
    @IBOutlet var savesBinary: NSButton!
    @IBOutlet var tokenTableContainerView: NSView!
    
    var tokenTableController: JZWTokenTableController! = JZWTokenTableController()
    
    // ****************************************** Initialization ******************************************

    init()
    {
        super.init(nibName: "JZWSentenceView", bundle: nil)
    }
    
    required convenience init?(coder: NSCoder)
    {
        self.init()
        self.tokenTableController = (coder.decodeObject(forKey: "table") as! JZWTokenTableController)
        self.model.loadFromCoder(coder)
    }
    
    override func encode(with aCoder: NSCoder)
    {
        super.encode(with: aCoder)
        aCoder.encode(self.tokenTableController, forKey: "table")
    }
    
    func readFromModel()
    {
        let m = self.model as! JZWSentenceModel
        
        self.titleField!.stringValue = m.title
        self.savesAscii.state = NSControl.StateValue(rawValue: m.savesAscii)
        self.savesBinary.state = NSControl.StateValue(rawValue: m.savesBinary)
        self.miniViewController?.titleField!.stringValue = m.title
    }
    
    override func viewDidLoad()
    {
        let txtColor : NSColor = NSColor.white
        let txtFont : NSFont = NSFont.boldSystemFont(ofSize: 13)
        let txtDict = [NSAttributedString.Key.font : txtFont, NSAttributedString.Key.foregroundColor : txtColor]
        
        let savesBinaryText : NSAttributedString = NSAttributedString(string: "Saves Binary", attributes: txtDict)
        let savesAsciiText : NSAttributedString = NSAttributedString(string: "Saves Ascii", attributes: txtDict)
        self.savesAscii?.attributedTitle = savesAsciiText
        self.savesBinary?.attributedTitle = savesBinaryText
        
        self.savesAscii.target = self
        self.savesAscii.action = #selector(JZWParserViewController.savesAsciiChanged(_:))
        self.savesBinary.target = self
        self.savesBinary.action = #selector(JZWParserViewController.savesBinaryChanged(_:))

        let layer = CALayer()
        layer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        self.tokenTableContainerView.wantsLayer = true
        self.tokenTableContainerView.layer = layer
        
        (self.tokenTableController.view as! JZWGradient).setClear()
        
        self.tokenTableContainerView.addSubview(self.tokenTableController.view)
        
        let dict = ["ttc" : self.tokenTableController.view]
        
        self.tokenTableContainerView.translatesAutoresizingMaskIntoConstraints = false
        self.tokenTableController.view.translatesAutoresizingMaskIntoConstraints = false
        
        self.tokenTableContainerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[ttc]|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: dict))
        self.tokenTableContainerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[ttc]|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: dict))

        self.readFromModel()
        
        super.viewDidLoad()
    }
    
    // ****************************************** My Overrides ******************************************
    
    override func loadModel() -> JZWSettingsModel
    {
        return JZWSentenceModel()
    }
    
    override func loadMiniViewController() -> JZWMiniSettingsViewController?
    {
        return JZWMiniSentenceViewController()
    }

    override func getAllTokenLabels() -> [String]
    {
        return self.tokenTableController.getAllTokenLabels().map({"\(self.model.title).\($0)"})        
    }

    override func getAllSentenceControllers() -> [String : JZWSentenceViewController]
    {
        var sents = super.getAllSentenceControllers()
        
        for (path, sent) in self.tokenTableController.getAllSentenceControllers()
        {
            sents[path] = sent
        }
        
        sents[self.model.title] = self
        
        return sents
    }
    
    override func getDefaultTitle() -> String
    {
        return "Sentence"
    }
    
    override func build(_ fullPath: NSString, userData: inout [String: AnyObject]?) -> AnyObject?
    {
        let m = self.model as! JZWSentenceModel
        let fp = NSString(format: "%@.%@", fullPath, self.model.title).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let tokens = self.tokenTableController.build(fp as NSString, userData: &userData) as! [JZWToken]
        let sentence = JZWSentence(path: fp as String, tokens: tokens)
        
        sentence.savesAscii = m.savesAscii == NSControl.StateValue.on.rawValue
        sentence.savesBinary = m.savesBinary == NSControl.StateValue.on.rawValue
        
        if (userData![ALL_SENTENCES] == nil)
        {
            userData![ALL_SENTENCES] = NSMutableDictionary()
        }
        (userData![ALL_SENTENCES] as! NSMutableDictionary).setValue(sentence, forKey: fp.trimmingCharacters(in: CharacterSet(charactersIn: ".")) as String)
        
        return sentence
    }

    override func deleteElement(_ sender: AnyObject)
    {
        super.deleteElement(sender)
        NotificationCenter.default.post(name: Notification.Name(rawValue: TOKEN_LABELS_CHANGED_NOTIFICATION), object: self, userInfo: nil)
    }

    // ****************************************** Other Methods ******************************************
    
    override func controlTextDidChange(_ obj: Notification)
    {
        super.controlTextDidChange(obj)
        self.model.title = self.titleField!.stringValue
        NotificationCenter.default.post(name: Notification.Name(rawValue: TOKEN_LABELS_CHANGED_NOTIFICATION), object: self, userInfo: nil)
    }
    
    func savesAsciiChanged(_ sender: AnyObject)
    {
        let m = self.model as! JZWSentenceModel
        m.savesAscii = self.savesAscii!.state.rawValue
    }
    func savesBinaryChanged(_ sender: AnyObject)
    {
        let m = self.model as! JZWSentenceModel
        m.savesBinary = self.savesBinary!.state.rawValue
    }
}
