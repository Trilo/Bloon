//
//  JZWMiniGraphViewController.swift
//  Bloon
//
//  Created by Jacob Weiss on 2/1/15.
//  Copyright (c) 2015 Jacob Weiss. All rights reserved.
//

import Foundation

class WeakWatcher
{
    weak var watcher : JZWMiniGraphWatcher?
    
    init(w: JZWMiniGraphWatcher) { watcher = w }
    
    var object : JZWMiniGraphWatcher? { return watcher }
}

@objc protocol JZWMiniGraphWatcher
{
    func boundsChanged(_ bound: String, value: Int)
}

class JZWMiniGraphViewController: JZWMiniSettingsViewController
{
    @IBOutlet var xField: NSTextField!
    @IBOutlet var xStepper: NSStepper!
    @IBOutlet var yField: NSTextField!
    @IBOutlet var yStepper: NSStepper!
    @IBOutlet var wField: NSTextField!
    @IBOutlet var wStepper: NSStepper!
    @IBOutlet var hField: NSTextField!
    @IBOutlet var hStepper: NSStepper!
    @IBOutlet var button: NSButton!
    
    var watchers: [WeakWatcher] = [WeakWatcher]()
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: "JZWMiniGraphView", bundle: nil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let m = self.mainViewController!.model as! JZWGraphModel
                
        self.titleField?.stringValue = m.title
        self.xStepper.integerValue = m.x
        self.yStepper.integerValue = m.y
        self.wStepper.integerValue = m.w
        self.hStepper.integerValue = m.h        
    }
    
    required init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }

    override func select()
    {
        (self.view as! JZWGradient).borderWidth = 4
        (self.view as! JZWGradient).borderColor = NSColor.black
        (self.view as! JZWGradient).redrawGradient()
    }
    
    override func validate() -> [String]
    {
        return []
    }
    
    override func deselect()
    {
        (self.view as! JZWGradient).borderWidth = 2
        (self.view as! JZWGradient).borderColor = NSColor.white
        (self.view as! JZWGradient).redrawGradient()
    }
    
    func addWatcher(_ watcher: JZWMiniGraphWatcher)
    {
        let w = WeakWatcher(w: watcher)
        self.watchers.append(w)
    }
    
    @IBAction func hChanged(_ sender: NSStepper)
    {
        for w in self.watchers
        {
            if w.object != nil
            {
                w.object!.boundsChanged("h", value: sender.integerValue)
            }
        }
    }
    @IBAction func wChanged(_ sender: NSStepper)
    {
        for w in self.watchers
        {
            if w.object != nil
            {
                w.object!.boundsChanged("w", value: sender.integerValue)
            }
        }
    }
    @IBAction func yChanged(_ sender: NSStepper)
    {
        for w in self.watchers
        {
            if w.object != nil
            {
                w.object!.boundsChanged("y", value: sender.integerValue)
            }
        }
    }
    @IBAction func xChanged(_ sender: NSStepper)
    {
        for w in self.watchers
        {
            if w.object != nil
            {
                w.object!.boundsChanged("x", value: sender.integerValue)
            }
        }
    }
}
