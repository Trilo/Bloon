//
//  JZWErrorWindow.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/3/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWErrorWindow: NSWindowController {

    @IBOutlet var errorsField: NSTextView!
    weak var relatedApp : AppDelegate.AppInstance? = nil
    
    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
}
