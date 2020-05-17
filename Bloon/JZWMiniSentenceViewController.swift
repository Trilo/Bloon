//
//  JZWMiniSentenceViewController.swift
//  Bloon
//
//  Created by Jacob Weiss on 1/29/15.
//  Copyright (c) 2015 Jacob Weiss. All rights reserved.
//

import Foundation

class JZWMiniSentenceViewController: JZWMiniSettingsViewController
{
    @IBOutlet var button: NSButton!
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: "JZWMiniSentenceView", bundle: nil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.titleField!.stringValue = (self.mainViewController!.model as! JZWSentenceModel).title
    }
    
    required init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func validate() -> [String]
    {
        return []
    }
    
    func controlTextDidChange(_ obj: Notification)
    {
        NotificationCenter.default.post(name: Notification.Name(rawValue: TOKEN_LABELS_CHANGED_NOTIFICATION), object: self, userInfo: nil)
    }
}
