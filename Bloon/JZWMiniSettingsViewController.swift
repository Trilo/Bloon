//
//  JZWMiniSettingsViewController.swift
//  Bloon
//
//  Created by Jacob Weiss on 2/3/15.
//  Copyright (c) 2015 Jacob Weiss. All rights reserved.
//

import Foundation

class JZWMiniSettingsViewController: NSViewController, NSCopying
{
    @IBOutlet var titleField: NSTextField?
    
    weak var mainViewController: JZWSettingsViewController?
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        // check state here and provide app-specific diagnostic if it's wrong
    }
    
    convenience init()
    {
        self.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad()
    {
        self.titleField?.delegate = self.mainViewController
        
        super.viewDidLoad()
    }
    
    @IBAction func buttonPressed(_ sender: AnyObject)
    {
        NotificationCenter.default.post(name: Notification.Name(rawValue: HISTORYVIEW_PUSH_NOTIFICATION),
            object: self.view.window, userInfo: ["view" : self.mainViewController!.view, "title" : self.mainViewController!.getTitle()])
    }
    
    func validate() -> [String]
    {
        return []
    }
    
    func build(_ fullPath: NSString, userData: inout [String: AnyObject]?) -> AnyObject?
    {
        return nil
    }
    
    func updateTokenLabels(_ lables: [String]) {}
    
    func select()
    {
        if (self.view is JZWGradient)
        {
            (self.view as! JZWGradient).setBlue()
            (self.view as! JZWGradient).redrawGradient()
        }
    }
    
    func deselect()
    {
        if (self.view is JZWGradient)
        {
            (self.view as! JZWGradient).setDarkDarkBlue()
            (self.view as! JZWGradient).redrawGradient()
        }
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        return NSNull()
    }
    
    func copy(with zone: NSZone?) -> AnyObject
    {
        return NSNull()
    }
    
    func copy(_ sender: AnyObject)
    {
        print("Copy Me")
    }
}
