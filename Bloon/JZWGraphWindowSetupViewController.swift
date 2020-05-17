//
//  JZWGraphWindowSetupViewController.swift
//  Bloon
//
//  Created by Jacob Weiss on 2/2/15.
//  Copyright (c) 2015 Jacob Weiss. All rights reserved.
//

import Foundation

class JZWGraphWindowSetupViewController: JZWSettingsViewController
{
    @IBOutlet var addWindow: NSButton!
    @IBOutlet var removeWindow: NSButton!
    
    // ****************************************** Initialization ******************************************
    
    init()
    {
        super.init(nibName: "JZWGraphWindowSetupView", bundle: nil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.readFromModel()
    }
    
    required convenience init?(coder: NSCoder)
    {
        self.init()
        self.model.loadFromCoder(coder)
    }
        
    func readFromModel()
    {
        let m = self.model as JZWSettingsModel
        
        self.titleField?.stringValue = m.title
    }
    
    // ****************************************** My Overrides ******************************************
    
    override func newTableElement() -> JZWSettingsViewController?
    {
        return JZWGraphWindowViewController()
    }
    
    override func build(_ fullPath: NSString, userData: inout [String: AnyObject]?) -> AnyObject?
    {
        var windows = [NSWindow]()
        
        for w in (self.model.tableElements as! [JZWGraphWindowViewController])
        {
            let window = NSWindow()
            window.title = w.model.title
            window.styleMask.formUnion(NSWindow.StyleMask.resizable)
            let graphs = w.build("", userData: &userData)! as! JZWGridBoxView
            let contentView = window.contentView! as NSView
            contentView.addSubview(graphs)
            let dict = ["graphs" : graphs]
            contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[graphs]|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: dict))
            contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[graphs]|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: dict))
            windows.append(window)
        }
        
        return windows as AnyObject?
    }
}











