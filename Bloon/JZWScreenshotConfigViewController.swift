//
//  JZWScreenshotConfigViewController.swift
//  Bloon
//
//  Created by Jacob Weiss on 6/11/17.
//  Copyright © 2017 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWScreenshotConfigViewController: NSViewController {
    @IBOutlet weak var maintainsGridLines: NSButton!
    @IBOutlet weak var scaleUI: NSButton!
    @IBOutlet weak var resolutionTicker: NSStepper!
    @IBOutlet weak var resolutionLabel: NSTextField!
    
    var baseResolution : CGSize = CGSize()
    
    init(baseResolution : CGSize)
    {
        super.init(nibName: "JZWScreenshotConfigViewController", bundle: nil)
        self.baseResolution = baseResolution
    }
    
    @IBAction func resolutionChanged(_ sender: Any) {
        self.setResolutionLabel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setResolutionLabel()
    {
        self.resolutionLabel.stringValue = "Resolution: \(Int32(self.baseResolution.width) * self.resolutionTicker.intValue) x \(Int32(self.baseResolution.height) * self.resolutionTicker.intValue)"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setResolutionLabel()
    }
    
}
