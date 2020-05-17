//
//  JZWPreferencesWindow.swift
//  Bloon
//
//  Created by Jacob Weiss on 12/16/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWPreferences : NSObject, Reflectable, Savable, NSCoding
{
    @objc var maxPointsPerFrame : Int = 500000;
    
    func encode(with aCoder: NSCoder)
    {
        self.saveWithCoder(aCoder)
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init()
        self.loadFromCoder(aDecoder)
    }
    
    override init()
    {
        super.init()
    }
}

class JZWPreferencesWindow: NSWindowController, NSTextFieldDelegate
{
    @IBOutlet weak var pointsPerFrameField: NSTextField!
    override func windowDidLoad()
    {
        super.windowDidLoad()

        self.pointsPerFrameField.stringValue = "\(JZWPreferencesWindow.sharedPreferences().maxPointsPerFrame)"
    }
    
    private static let _prefsPath = NSHomeDirectory() + "/BloonPrefs.xml"
    private static var _sharedPreferences : JZWPreferences? = nil
    @objc class func sharedPreferences() -> JZWPreferences
    {
        if let prefs = _sharedPreferences
        {
            return prefs
        }
        else if let prefs = NSKeyedUnarchiver.unarchiveObject(withFile: _prefsPath) as? JZWPreferences
        {
            _sharedPreferences = prefs
        }
        else
        {
            _sharedPreferences = JZWPreferences()
        }
        return _sharedPreferences!
    }
    
    class func savePrefs()
    {
        if let prefs = _sharedPreferences
        {
            let data = NSMutableData()
            let archiver = NSKeyedArchiver(forWritingWith: data)
            archiver.outputFormat = PropertyListSerialization.PropertyListFormat.xml
            archiver.encode(prefs, forKey: "root")
            archiver.finishEncoding()
            data.write(toFile: _prefsPath, atomically: true)
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        if let pointsPerFrame = Int(pointsPerFrameField.stringValue)
        {
            JZWPreferencesWindow.sharedPreferences().maxPointsPerFrame = pointsPerFrame
            JZWPreferencesWindow.savePrefs()
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "PreferencesChanged"), object: nil)
        }
    }
}
