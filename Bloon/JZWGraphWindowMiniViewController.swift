//
//  JZWGraphWindowMiniViewController.swift
//  Bloon
//
//  Created by Jacob Weiss on 2/2/15.
//  Copyright (c) 2015 Jacob Weiss. All rights reserved.
//

import Foundation

class JZWGraphWindowMiniViewController: JZWMiniSettingsViewController
{
    @IBOutlet var button: NSButton!
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: "JZWGraphWindowMiniView", bundle: nil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let m = self.mainViewController! as! JZWGraphWindowViewController
        
        self.titleField!.stringValue = (m.model as! JZWGraphWindowModel).title
    }
    
    required init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func validate() -> [String]
    {
        return []
    }
}
