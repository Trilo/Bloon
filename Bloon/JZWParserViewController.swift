//
//  ParserView.swift
//  Bloon
//
//  Created by Jacob Weiss on 12/7/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Foundation


class JZWParserModel: JZWSettingsModel
{
    @objc var savesAscii: Int = NSControl.StateValue.off.rawValue
    @objc var savesBinary: Int = NSControl.StateValue.off.rawValue
    @objc var savePath: String = "./"
    @objc var parsePath: String = ""
    @objc var portOrFile: Int = 1
    @objc var selectedPort: String = "/dev/tty.usbmodem1421"
    @objc var baud: String = "115200"
    @objc var parseBookmark: String = ""
    @objc var saveBookmark: String = ""
}

class JZWParserStarter
{
    var parser: JZWParser? = nil
    var startParser: () -> (Bool) = {return true}
    var stopParser: (@escaping () -> ()) -> () = {_ in }
}

class JZWParserViewController: JZWSettingsViewController
{
    @IBOutlet var asciiCheckbox: NSButton?
    @IBOutlet var binaryCheckbox: NSButton?
    @IBOutlet var savePathLabel: NSTextField!
    @IBOutlet var savePathButton: NSButton!
    @IBOutlet var savePath: NSTextField!
    @IBOutlet var parsePath: NSTextField!
    @IBOutlet var parsePathButton: NSButton!
    @IBOutlet var portOrFile: NSMatrix!
    @IBOutlet var baudList: NSPopUpButton!
    @IBOutlet var portList: NSPopUpButton!
    @IBOutlet var newSentence: NSButton!
    @IBOutlet var removeSentence: NSButton!
    @IBOutlet var chooseParsePathButton: NSButton!
    @IBOutlet var savesAsciiTopConstraint: NSLayoutConstraint!
    
    typealias KVOContext = UInt8
    var MyObservationContext = KVOContext()
    
    let ROOT_PARSER_SAVE_PATH = "ROOT_PARSER_SAVE_PATH"
    
    // Initializers
    
    var fd: CInt
    var queue: DispatchQueue
    var source: DispatchSourceWrite
    
    var isRootParser : Bool = false
    
    // ****************************************** Initialization ******************************************
    
    init()
    {
        // http://www.cocoanetics.com/2013/08/monitoring-a-folder-with-gcd/
        let f = open("/dev/", O_EVTONLY)
        self.fd = f
        self.queue = DispatchQueue(label: "device_monitor")

        self.source = DispatchSource.makeWriteSource(fileDescriptor: fd, queue: queue)
        
        super.init(nibName: "JZWParserView", bundle: nil)
        
        source.setEventHandler { [weak self] in
            self?.updatePortList()
        }
        source.setCancelHandler(handler: {() -> () in close(f); return})
        source.resume()
    }
    
    required convenience init?(coder: NSCoder)
    {
        self.init()
        self.model.loadFromCoder(coder)
    }
    
    override func loadModel() -> JZWSettingsModel
    {
        return JZWParserModel()
    }
    
    func readFromModel()
    {
        let m = self.model as! JZWParserModel
        
        self.asciiCheckbox?.state = NSControl.StateValue(rawValue: m.savesAscii)
        self.binaryCheckbox?.state = NSControl.StateValue(rawValue: m.savesBinary)
        self.savePath?.stringValue = m.savePath
        self.parsePath?.stringValue = m.parsePath
        self.portOrFile.setSelectionFrom(m.portOrFile, to: m.portOrFile, anchor: 0, highlight: false)
        self.titleField?.stringValue = m.title
        self.baudList?.selectItem(withTitle: m.baud)
        self.updatePortList()
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.view.translatesAutoresizingMaskIntoConstraints = false
        self.updatePortList()
        
        let txtColor : NSColor = NSColor.white
        let txtFont : NSFont = NSFont.boldSystemFont(ofSize: 13)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.right
        let txtDict : [NSAttributedString.Key : Any] = [NSAttributedString.Key.font : txtFont, NSAttributedString.Key.foregroundColor : txtColor, NSAttributedString.Key.paragraphStyle : paragraphStyle]
                
        let parseFileText : NSAttributedString = NSAttributedString(string: "Parse File", attributes: txtDict)
        let parsePortText : NSAttributedString = NSAttributedString(string: "Parse Port", attributes: txtDict)
        let parsePipeText : NSAttributedString = NSAttributedString(string: "Parse Pipe", attributes: txtDict)
        let savesBinaryText : NSAttributedString = NSAttributedString(string: "Saves Binary", attributes: txtDict)
        let savesAsciiText : NSAttributedString = NSAttributedString(string: "Saves Ascii", attributes: txtDict)
        self.asciiCheckbox?.attributedTitle = savesAsciiText
        self.binaryCheckbox!.attributedTitle = savesBinaryText
        
        (self.portOrFile?.cell(atRow: 0, column: 0) as! NSButtonCell).attributedTitle = parseFileText
        (self.portOrFile?.cell(atRow: 0, column: 1) as! NSButtonCell).attributedTitle = parsePortText
        (self.portOrFile?.cell(atRow: 0, column: 2) as! NSButtonCell).attributedTitle = parsePipeText

        self.asciiCheckbox!.action = #selector(JZWParserViewController.savesAsciiChanged(_:))
        self.asciiCheckbox!.target = self
        self.binaryCheckbox!.action = #selector(JZWParserViewController.savesBinaryChanged(_:))
        self.binaryCheckbox!.target = self
        
        self.readFromModel()
        self.setAsRootParser(self.isRootParser)
        
        self.parsePathButton.isEnabled = ((self.model as! JZWParserModel).portOrFile == 0)
    }
    
    // ****************************************** Other Methods ******************************************
    
    override func getStaticErrorsAndWarnings() -> (warnings: [String], errors: [String]) {
        let subErrors = super.getStaticErrorsAndWarnings()
        var warnings = [String]()
        var errors = [String]()
        
        let m = self.model as! JZWParserModel
        
        if m.title == ""
        {
            warnings += ["Parser has no name."]
        }
        errors += ["Test"]
        return (warnings + subErrors.warnings, errors + subErrors.errors)
    }
    
    func setAsRootParser(_ isRoot : Bool)
    {
        self.parsePath.isHidden = !isRoot
        self.portOrFile.isHidden = !isRoot
        self.baudList.isHidden = !isRoot
        self.portList.isHidden = !isRoot
        self.savePath.isHidden = !isRoot
        self.savePathLabel.isHidden = !isRoot
        self.savePathButton.isHidden = !isRoot
        self.chooseParsePathButton.isHidden = !isRoot
        if (isRoot)
        {
            self.savesAsciiTopConstraint.constant = 144
        }
        else
        {
            self.savesAsciiTopConstraint.constant = 62
            self.parsePath.stringValue = "./"
            (self.model as! JZWParserModel).parsePath = "./"
        }
    }
    
    func updatePortList()
    {
        if self.portList != nil
        {
            DispatchQueue.main.async(execute: {() -> () in
                self.portList.removeAllItems()
                self.portList.addItems(withTitles: JZWParser.getPorts())
                let title = (self.model as! JZWParserModel).selectedPort
                if self.portList.item(withTitle: title) != nil
                {
                    self.portList.selectItem(withTitle: title)
                }
                else
                {
                    self.portList.selectItem(at: 0)
                }
                return
            })
        }
    }
    
    @IBAction func portSelectionChanged(_ sender: AnyObject?)
    {
        (self.model as! JZWParserModel).selectedPort = (sender as! NSPopUpButton).selectedItem!.title
    }
    
    @IBAction func baudChanged(_ sender: AnyObject)
    {
        (self.model as! JZWParserModel).baud = (sender as! NSPopUpButton).selectedItem!.title
    }

    override func getDefaultTitle() -> String
    {
        return "Parser"
    }
    
    override func newTableElement() -> JZWSettingsViewController?
    {
        return JZWSentenceViewController()
    }
        
    override func build(_ fullPath: NSString, userData: inout [String: AnyObject]?) -> AnyObject?
    {
        let m = self.model as! JZWParserModel
        
        var savePath = m.savePath
        if self.isRootParser
        {
            userData![ROOT_PARSER_SAVE_PATH] = m.savePath as AnyObject?
        }
        else
        {
            savePath = userData![ROOT_PARSER_SAVE_PATH] as! String
        }
        
        var sentences = [JZWSentence]()
        
        for s in self.model.tableElements
        {
            if let sentence = s.build(NSString(format: "%@.%@", fullPath, m.title), userData: &userData) as! JZWSentence?
            {
                sentences.append(sentence)
            }
        }
        
        let start = JZWParserStarter()
        
        let parser = JZWParser(portName: m.title, dataPath: savePath, portPath: m.selectedPort, baud: Int32(Int(m.baud)!), sentences: sentences)
        
        parser.savesAscii = m.savesAscii == NSControl.StateValue.on.rawValue
        parser.savesBinary = m.savesBinary == NSControl.StateValue.on.rawValue
        
        // Set up the file to parse
        // Set up the output directory
        
        var parseURL : URL? = nil
        var saveURL : URL? = nil

        if self.isRootParser
        {
            var isStale : ObjCBool = false
            do
            {
                let data = Data(base64Encoded: m.parseBookmark.data(using: String.Encoding.utf8)!, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters)
                parseURL = try (NSURL(resolvingBookmarkData: data!, options: NSURL.BookmarkResolutionOptions.withoutUI.union(NSURL.BookmarkResolutionOptions.withoutMounting).union(NSURL.BookmarkResolutionOptions.withSecurityScope), relativeTo: nil, bookmarkDataIsStale: &isStale) as URL)
                if isStale.boolValue
                {
                    parseURL = nil;
                }
                
            } catch {}
            
            do
            {
                let data = Data(base64Encoded: m.saveBookmark.data(using: String.Encoding.utf8)!, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters)
                var isStale : ObjCBool = false
                saveURL = try (NSURL(resolvingBookmarkData: data!, options: NSURL.BookmarkResolutionOptions.withoutUI.union(NSURL.BookmarkResolutionOptions.withoutMounting).union(NSURL.BookmarkResolutionOptions.withSecurityScope), relativeTo: nil, bookmarkDataIsStale: &isStale) as URL)
                if isStale.boolValue
                {
                    saveURL = nil
                }
            } catch {}
        }
                
        if let url = saveURL
        {
            _ = url.startAccessingSecurityScopedResource()
        }

        if m.portOrFile == 0 // parse file
        {
            start.startParser = {
                if let url = parseURL
                {
                    _ = url.startAccessingSecurityScopedResource()
                    let returnVal = parser.readData(m.parsePath)
                    url.stopAccessingSecurityScopedResource()
                    return returnVal
                }
                else
                {
                    parser.presentErrorAlert(withMessage: "Error: Failed to open file at path: \(m.parsePath). Try re-opening it.")
                    return false
                }
            }
        }
        else if m.portOrFile == 1// Parse Port
        {
            start.startParser = {
                return parser.openSerialPort()
            }
        }
        else if m.portOrFile == 2 // parse pipe
        {
            start.startParser = {
                return parser.readData(m.parsePath)
            }
        }
        
        func stopParser(callback : @escaping () -> ())
        {
            parser.closeParser(callback)
            if let url = saveURL
            {
                url.stopAccessingSecurityScopedResource()
            }

        }
        
        start.stopParser = stopParser
        start.parser = parser

        if userData != nil
        {
            (userData![ALL_PARSERS] as! NSMutableArray).add(parser)
        }
        
        return start
    }
    
    override func controlTextDidChange(_ obj: Notification)
    {
        let field = obj.object! as! NSTextField
        
        let m = self.model as! JZWParserModel
        
        if field == self.savePath
        {
            m.savePath = field.stringValue
        }
        else if field == self.parsePath
        {
            m.parsePath = field.stringValue
        }
        else if field == self.titleField
        {
            m.title = (self.titleField!.stringValue)
            NotificationCenter.default.post(name: Notification.Name(rawValue: TOKEN_LABELS_CHANGED_NOTIFICATION), object: self, userInfo: nil)
            super.controlTextDidChange(obj)
            self.filePortChanged(self)
        }
    }
    
    @IBAction func savePathSelect(_ sender: AnyObject)
    {
        let savePath = NSOpenPanel()
        savePath.title = "Choose Save Directory"
        savePath.allowsMultipleSelection = false
        savePath.canChooseDirectories = true
        savePath.canCreateDirectories = true
        savePath.canChooseFiles = false
        if let w = self.view.window
        {
            savePath.beginSheetModal(for: w) { (status : NSApplication.ModalResponse) -> Void in
                if let path = savePath.url?.path
                {
                    do
                    {
                        let bookmark = try (savePath.url! as NSURL).bookmarkData(options: NSURL.BookmarkCreationOptions.withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        (self.model as! JZWParserModel).saveBookmark = bookmark.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
                    }
                    catch
                    {
                    }
                    self.savePath.stringValue = path
                    let m = self.model as! JZWParserModel
                    m.savePath = path
                }
            }
        }
    }
    
    @IBAction func parseFileSelect(_ sender: AnyObject)
    {
        let parsePath = NSOpenPanel()
        parsePath.title = "Choose File To Parse"
        parsePath.allowsMultipleSelection = false
        parsePath.canChooseDirectories = false
        parsePath.canCreateDirectories = false
        parsePath.canChooseFiles = true
        if let w = self.view.window
        {
            parsePath.beginSheetModal(for: w) { (status : NSApplication.ModalResponse) -> Void in
                if let path = parsePath.url?.path
                {
                    do
                    {
                        let bookmark = try (parsePath.url! as NSURL).bookmarkData(options: NSURL.BookmarkCreationOptions.withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        (self.model as! JZWParserModel).parseBookmark = bookmark.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
                    }
                    catch
                    {
                    }
                    self.parsePath.stringValue = path
                    let m = self.model as! JZWParserModel
                    m.parsePath = path
                }
            }
        }
    }
    
    @objc func savesAsciiChanged(_ sender: AnyObject)
    {
        let m = self.model as! JZWParserModel
        m.savesAscii = self.asciiCheckbox!.state.rawValue
    }
    @objc func savesBinaryChanged(_ sender: AnyObject)
    {
        let m = self.model as! JZWParserModel
        m.savesBinary = self.binaryCheckbox!.state.rawValue
    }
    @IBAction func filePortChanged(_ sender: AnyObject)
    {
        let m = self.model as! JZWParserModel
        let prev = m.portOrFile
        m.portOrFile = self.portOrFile!.selectedRow
        if (m.portOrFile == 2) // Pipe
        {
            m.parsePath = NSHomeDirectory() + "/bloonpipe_" + m.title
            self.parsePath.stringValue = m.parsePath
        }
        else if !(prev == 0 && m.portOrFile == 0)
        {
            m.parsePath = ""
            self.parsePath.stringValue = ""
        }
        
        self.parsePathButton.isEnabled = (m.portOrFile == 0)
    }

    override func deleteElement(_ sender: AnyObject)
    {
        super.deleteElement(sender)
        NotificationCenter.default.post(name: Notification.Name(rawValue: TOKEN_LABELS_CHANGED_NOTIFICATION), object: self, userInfo: nil)
    }
}

class JZWDraggableTextField : NSTextField
{
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }
    
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool
    {
        let pboard = sender.draggingPasteboard
        
        if let types = pboard.types , types.contains(NSPasteboard.PasteboardType.filePromise)
        {
            let _ = NSURL(from: pboard)
        }
        return true;

    }
}
