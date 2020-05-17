//
//  ParserView.swift
//  Bloon
//
//  Created by Jacob Weiss on 12/7/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Foundation

class JZWTokenTableController: JZWSettingsViewController
{    
    @IBOutlet var addTokenMenu: NSPopUpButton!
    @IBOutlet var removeToken: NSButton!
    
    typealias KVOContext = UInt8
    var MyObservationContext = KVOContext()
    
    var isGroupController : Bool = false
    
    // ****************************************** Initialization ******************************************
    
    init()
    {
        super.init(nibName: "JZWTokenTableView", bundle: nil)
    }
    
    required convenience init?(coder: NSCoder)
    {
        self.init()
        self.model.loadFromCoder(coder)
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.view.translatesAutoresizingMaskIntoConstraints = false
                
        self.addTokenMenu.synchronizeTitleAndSelectedItem()
        
        self.addTokenMenu.removeAllItems()
        self.addTokenMenu.setTitle("Add Token")
        self.addTokenMenu.menu?.autoenablesItems = true
        
        self.addTokenMenu.addItem(withTitle: "")
        for tokenType in TokenInterfaceTypes.keys.map({$0.rawValue}).sorted(by: <)
        {
            if !self.isGroupController && tokenType == TokenType.ParsableData.rawValue
            {
                continue
            }
            self.addTokenMenu.addItem(withTitle: tokenType)
        }
        
        self.addTokenMenu.setTitle("Add Token")
        self.addTokenMenu.isEnabled = true
    }    
    
    // ****************************************** My Overrides ******************************************
    
    @objc override func allowsDragging() -> Bool
    {
        return true
    }
    
    override func getAllTokenLabels() -> [String]
    {
        var tokenLabels = [String]()        
        
        for t in self.model.tableElements
        {
            let token = t.miniViewController as! JZWTokenViewController
            
            tokenLabels += token.getAllTokenLabels()
        }
        
        return tokenLabels
    }
    
    override func build(_ fullPath: NSString, userData: inout [String: AnyObject]?) -> AnyObject?
    {
        var tokens = [JZWToken]()
        
        for controller in (self.model.tableElements)
        {
            let token = controller.miniViewController! as! JZWTokenViewController
            
            tokens.append(token.build(fullPath, userData: &userData)! as! JZWToken)
        }
        
        return tokens as AnyObject?
    }
    
    override func getUniqueClassIdentifier() -> String
    {
        return self.className
    }
    
    @objc override func paste(_ sender: AnyObject)
    {
        super.paste(sender)
        
        self.model.tableElements = self.model.tableElements.filter({ (controller : JZWSettingsViewController) -> Bool in
            return self.isGroupController || (controller.miniViewController! as! JZWTokenViewController).type! != TokenType.ParsableData
        })
        self.table!.reloadData()
    }
    
    // ****************************************** Actions ******************************************

    @IBAction func newToken(_ sender: NSPopUpButton)
    {
        let tokenTitle = (sender.titleOfSelectedItem)!
        let newToken = JZWTokenViewController(type: TokenType(rawValue: tokenTitle)!)
        let newSettings = JZWSettingsViewController()
        newSettings.miniViewController = newToken
        self.model.tableElements.append(newSettings)
        self.table!.reloadData()
    }
    
    override func deleteElement(_ sender: AnyObject)
    {
        super.deleteElement(sender)
        NotificationCenter.default.post(name: Notification.Name(rawValue: TOKEN_LABELS_CHANGED_NOTIFICATION), object: self, userInfo: nil)
    }
}

