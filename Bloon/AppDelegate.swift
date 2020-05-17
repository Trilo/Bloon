//
//  AppDelegate.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/3/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

extension String
{
    func indentByTabs(_ tabs : Int) -> String
    {
        return self.components(separatedBy: "\r\n").reduce("", {"\($0)\r\n\t\($1)"})
    }
    func removeEmptyLines() -> String
    {
        return self.components(separatedBy: "\r\n")
            .filter({$0.components(separatedBy: CharacterSet.whitespaces).filter({$0 != ""}).count != 0})
            .reduce("", {"\($0)\r\n\($1)"})
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    func ranges(of : String) -> [NSRange]
    {
        let nsself = self as NSString
        var searchRange : NSRange = NSMakeRange(0, nsself.length)
        var foundRanges = [NSRange]()
        
        while true
        {
            let r = nsself.range(of: of, options: CompareOptions.literal, range: searchRange, locale: nil)
                
            if r.location != NSNotFound
            {
                foundRanges.append(r)
                searchRange = NSMakeRange(r.location + r.length, nsself.length - (r.location + r.length))
            }
            else
            {
                return foundRanges
            }
        }
    }
}

@objc class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate
{
    @IBOutlet weak var menu: NSMenu!
    @IBOutlet var saveConfig: NSMenuItem!
    @IBOutlet weak var saveConfigAs: NSMenuItem!
    @IBOutlet var loadConfig: NSMenuItem!
    @IBOutlet var runConfig: NSMenuItem!
    @IBOutlet var stopConfig: NSMenuItem!
    @IBOutlet weak var newConfig: NSMenuItem!
    @IBOutlet weak var runConfigNoSave: NSMenuItem!
    @IBOutlet weak var aboutMenu: NSMenuItem!
    @IBOutlet weak var prefMenu: NSMenuItem!
    
    var handle : FileHandle? = nil
    let aboutWindow = JZWAboutWindow(windowNibName: "JZWAboutWindow")
    let preferencesWindow = JZWPreferencesWindow(windowNibName: "JZWPreferencesWindow")
    
    class AppInstance
    {
        var parser : JZWParser? = nil
        var historyController = JZWHistoryViewController()
        var mainViewController : JZWMainViewController! = nil
        var savePath = ""
        var errorsWindow = JZWErrorWindow(windowNibName: "JZWErrorWindow")
    }
    
    var instances = [NSWindow : AppInstance]()
    
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        self.saveConfig.action = #selector(AppDelegate.save(_:))
        self.saveConfig.target = self
        self.saveConfigAs.action = #selector(AppDelegate.saveAs)
        self.saveConfigAs.target = self
        self.runConfig.action = #selector(AppDelegate.run)
        self.runConfig.target = self
        self.runConfigNoSave.action = #selector(AppDelegate.runNoSave)
        self.runConfigNoSave.target = self
        self.stopConfig.action = #selector(AppDelegate.stop)
        self.stopConfig.target = self
        self.loadConfig.action = #selector(NSObject.load)
        self.loadConfig.target = self
        self.newConfig.action = #selector(AppDelegate.new)
        self.newConfig.target = self
        self.aboutMenu.action = #selector(AppDelegate.showAboutWindow(_:))
        self.aboutMenu.target = self
        self.prefMenu.action = #selector(AppDelegate.showPrefsWindow(_:))
        self.prefMenu.target = self
    }

    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any?
    {
        if client is JZWTextField
        {
            return (client as! JZWTextField).getFieldEditor()
        }
        
        return nil
    }
    
    @nonobjc internal func windowShouldClose(_ sender: Any) -> Bool
    {
        let _ = self.areYouSure(sender as? NSWindow)
        return false
    }
    func windowWillClose(_ notification: Notification)
    {
        let window = notification.object! as! NSWindow
        if let ai = self.instances[window]
        {
            
            ai.mainViewController.stop { () -> () in
                ai.parser = nil
                ai.mainViewController.currentParser = nil
                ai.mainViewController.currentWindows = nil
                self.instances.removeValue(forKey: window)
            }
        }
    }
    
    @IBAction func viewErrorReport(_ sender: AnyObject) {
        guard let window = NSApplication.shared.keyWindow else
        {
            return
        }
        
        var ai : AppInstance? = nil

        if window.windowController is JZWErrorWindow
        {
            ai = (window.windowController as! JZWErrorWindow).relatedApp!
        }
        else
        {
            if self.instances[window] != nil
            {
                ai = self.instances[window]!
            }
            else
            {
                for instance in self.instances
                {
                    if let currentWindows = instance.1.mainViewController.currentWindows
                    {
                        if currentWindows.contains(window)
                        {
                            ai = instance.1
                            break
                        }
                    }
                }
            }
        }
        
        if ai == nil
        {
            return
        }
        
        ai?.errorsWindow.relatedApp = ai
        
        var errorReport = ""
        if let parser = ai!.mainViewController.currentParser?.parser
        {
            errorReport = "\(errorReport)\r\n\(parser.name)"
            errorReport = "\(errorReport)\r\n\(parser.errorReport().indentByTabs(1))"
        }
        errorReport = errorReport.removeEmptyLines()
        
        ai!.errorsWindow.showWindow(self)
        ai!.errorsWindow.errorsField.string = errorReport
        
        ai!.errorsWindow.errorsField.textStorage!.removeAttribute(NSAttributedString.Key.foregroundColor, range: NSMakeRange(0, (ai!.errorsWindow.errorsField.string as NSString).length))
        for warningRange in errorReport.components(separatedBy: "\r\n")
                                       .filter({$0.range(of: "nan") != nil})
                                       .map({errorReport.ranges(of: $0)})
                                       .reduce([], {$0 + $1})
        {
            ai!.errorsWindow.errorsField.textStorage!.addAttribute(NSAttributedString.Key.foregroundColor, value: NSColor(calibratedRed: 0.6, green: 0, blue: 0, alpha: 1), range: warningRange)
        }
    }
    
    func newAppInstance(_ withMainViewController : JZWMainViewController? = nil, fileName : String = "") -> (NSWindow, AppInstance)
    {
        let window = NSWindow()
        window.delegate = self
        window.styleMask.formUnion(NSWindow.StyleMask.resizable)
        window.styleMask.formUnion(NSWindow.StyleMask.closable)
        
        if fileName != ""
        {
            window.title = fileName.components(separatedBy: "/").last!
        }
        
        let appInstance = AppInstance()
        
        window.contentView!.addSubview(appInstance.historyController.view)

        let dict = ["gui" : appInstance.historyController.view]
        window.contentView!.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[gui]|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: dict))
        window.contentView!.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[gui]|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: dict))
        
        var windowFrame = window.frame
        windowFrame.origin = CGPoint(x: 0, y: window.screen!.frame.height)
        window.setFrame(windowFrame, display: true, animate: false)
        window.isReleasedWhenClosed = false

        if let mvc = withMainViewController
        {
            appInstance.mainViewController = mvc
        }
        else
        {
            appInstance.mainViewController = JZWMainViewController()
        }
        
        appInstance.historyController.initNotifications()
        appInstance.historyController.pushView(appInstance.mainViewController.view, title: "Bloon")
        appInstance.savePath = fileName
        
        return (window, appInstance)
    }
        
    func application(_ sender: NSApplication, openFile filename: String) -> Bool
    {
        if let opened = NSKeyedUnarchiver.unarchiveObject(withFile: filename) as? JZWMainViewController
        {
            let ai = self.newAppInstance(opened, fileName: filename)
            self.instances[ai.0] = ai.1
            
            ai.0.makeKeyAndOrderFront(self)
            ai.0.isReleasedWhenClosed = false
            
            NSDocumentController.shared.noteNewRecentDocumentURL(URL(fileURLWithPath: filename))
            return true
        }
        return false
    }
    
    @objc func showPrefsWindow(_ sender : AnyObject)
    {
        self.preferencesWindow.showWindow(self)
    }
    
    @objc func showAboutWindow(_ sender : AnyObject)
    {
        self.aboutWindow.showWindow(self)
    }
    
    func areYouSure(_ w : NSWindow? = nil) -> Bool
    {
        var window : NSWindow;
        
        if w != nil
        {
            window = w!
        }
        else if NSApplication.shared.keyWindow != nil
        {
            window = NSApplication.shared.keyWindow!
        }
        else
        {
            return false
        }
        
        if self.instances[window] == nil
        {
            return false
        }
        
        let alert = NSAlert()
        alert.messageText = "Do you want to save the changes you made?"
        alert.informativeText = "Your changes will be lost if you don’t save them."

        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don't Save")
        
        var shouldClose = false
        alert.beginSheetModal(for: window) { (response : NSApplication.ModalResponse) -> Void in
            switch response
            {
            case NSApplication.ModalResponse.alertSecondButtonReturn:
                break
            case NSApplication.ModalResponse.alertFirstButtonReturn:
                self.save()
                fallthrough
            case NSApplication.ModalResponse.alertThirdButtonReturn:
                window.close()
                shouldClose = true
            default:
                break;
            }
        }
        
        return shouldClose
    }

    @objc func new()
    {
        let ai = self.newAppInstance()
        self.instances[ai.0] = ai.1
        
        ai.0.makeKeyAndOrderFront(self)
        ai.0.isReleasedWhenClosed = false
    }
    
    func updateMenu(_ sender : AnyObject)
    {
        if NSEvent.modifierFlags == NSEvent.ModifierFlags.shift
        {
            self.runConfig.isHidden = true
            self.runConfigNoSave.isHidden = false
        }
        else
        {
            self.runConfig.isHidden = false
            self.runConfigNoSave.isHidden = true
        }
        self.menu.update()
    }
    
    @objc func save(_ sender : AnyObject? = nil)
    {
        var window : NSWindow? = nil
        
        if sender is NSWindow?
        {
            window = sender as! NSWindow?
        }
        
        if window == nil
        {
            guard let w = NSApplication.shared.keyWindow else
            {
                return
            }
            window = w
        }
        
        guard let ai = self.instances[window!] else
        {
            return
        }

        if ai.savePath == ""
        {
            self.saveAs()
        }
        
        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        archiver.outputFormat = PropertyListSerialization.PropertyListFormat.binary
        archiver.encode(ai.mainViewController, forKey: "root")
        archiver.finishEncoding()
        data.write(toFile: ai.savePath, atomically: true)
    }
    
    @objc func saveAs()
    {
        guard let window = NSApplication.shared.keyWindow, let ai = self.instances[window] else
        {
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Save Config As..."
        savePanel.canCreateDirectories = true
        savePanel.allowedFileTypes = ["bln"]
        savePanel.beginSheetModal(for: window, completionHandler: { (response : NSApplication.ModalResponse) -> Void in
            if let path = savePanel.url?.path , response == NSApplication.ModalResponse.OK
            {
                ai.savePath = path
                window.title = path.components(separatedBy: "/").last!
                self.save(window)
            }
        })
    }
    
    @objc func load()
    {
        let openPanel = NSOpenPanel()
        openPanel.title = "Load Config"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedFileTypes = ["bln"]
        openPanel.begin { (response : NSApplication.ModalResponse) -> Void in
            if let path = openPanel.url?.path , response == NSApplication.ModalResponse.OK
            {
                if !self.application(NSApplication.shared, openFile: path)
                {
                    print("Open file failed!!")
                }
            }
        }
    }
    
    @objc func runNoSave()
    {
        guard let window = NSApplication.shared.keyWindow, let ai = self.instances[window] else
        {
            return
        }
        
        if ai.mainViewController.start(false) == false
        {
            self.stop()
        }
    }
    
    @objc func run()
    {

        guard let window = NSApplication.shared.keyWindow, let ai = self.instances[window] else
        {
            return
        }
        
        if ai.mainViewController.start() == false
        {
            self.stop()
        }
    }
    
    @objc func stop()
    {
        guard let window = NSApplication.shared.keyWindow else
        {
            return
        }
        
        var ai : AppInstance? = nil
        if self.instances[window] != nil
        {
            ai = self.instances[window]!
        }
        else
        {
            for instance in self.instances
            {
                if let currentWindows = instance.1.mainViewController.currentWindows
                {
                    if currentWindows.contains(window)
                    {
                        ai = instance.1
                        break
                    }
                }
            }
        }
        
        if ai == nil
        {
            return
        }
        
        ai!.mainViewController.stop { () -> () in
            ai!.parser = nil
            
            ai!.mainViewController.currentParser = nil
            ai!.mainViewController.currentWindows = nil
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification)
    {
        // Insert code here to tear down your application   
        //parser!.close()
    }
}
/*
@available(OSX 10.12.2, *)
extension AppDelegate NSTouchBarProvider, NSTouchBarDelegate
{
    var touchBar: NSTouchBar?
    {
        let mainBar = NSTouchBar()
        mainBar.delegate = self
        mainBar.defaultItemIdentifiers = [NSTouchBarItemIdentifier(rawValue: "run"),
                                          NSTouchBarItemIdentifier(rawValue: "terminate")]
        return mainBar
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItemIdentifier) -> NSTouchBarItem?
    {
        switch identifier.rawValue
        {
        case "run":
            let item = NSTouchBarItem(identifier: identifier)
            item.view?.addSubview(NSTextField(labelWithString: "Run"))
            return item
        case "terminate":
            let item = NSTouchBarItem(identifier: identifier)
            item.view?.addSubview(NSTextField(labelWithString: "Terminate"))
            return item
        default:
            return nil
        }
    }
}
*/






