//
//  JZWSettingsViewController.swift
//  Bloon
//
//  Created by Jacob Weiss on 2/3/15.
//  Copyright (c) 2015 Jacob Weiss. All rights reserved.
//

import Foundation

protocol Reflectable
{
    func properties()->[String]
}

extension Reflectable
{
    func properties() -> [String]
    {
        var s = [String]()
        var mirror : Mirror? = Mirror(reflecting: self)
        while let m = mirror
        {
            let c = m.children
            let generator = c.makeIterator()
            for _ in 0 ..< c.count
            {
                let x = generator.next()
                if let name = x?.label
                {
                    s.append(name)
                }
            }
            mirror = m.superclassMirror
        }
        return s
    }
}

protocol Savable
{
    func saveWithCoder(_ coder: NSCoder)
    func loadFromCoder(_ coder: NSCoder)
}

extension Savable where Self : NSObject, Self : Reflectable
{
    func saveWithCoder(_ coder: NSCoder)
    {
        for p in self.properties()
        {
            switch getTypeOfProperty(p, self)
            {
                case "Int":
                    coder.encode(self.value(forKey: p) as! Int, forKey: p)
                case "Double":
                    coder.encode(self.value(forKey: p) as! Double, forKey: p)
                case "Bool":
                    coder.encode(self.value(forKey: p) as! Bool, forKey: p)
                case "Object":
                    coder.encode(self.value(forKey: p), forKey: p)
                default:
                    print("Type Error While Saving")
            }
        }
    }
    
    func loadFromCoder(_ coder: NSCoder)
    {
        for p in self.properties()
        {
            switch getTypeOfProperty(p, self)
            {
                case "Int":
                    self.setValue(coder.decodeInteger(forKey: p), forKey: p)
                case "Double":
                    self.setValue(coder.decodeDouble(forKey: p), forKey: p)
                case "Bool":
                    self.setValue(coder.decodeBool(forKey: p), forKey: p)
                case "Object":
                    self.setValue(coder.decodeObject(forKey: p), forKey: p)
                default:
                    print("Type Error While Loading")
            }
        }
    }
}

class JZWSettingsModel: NSObject, Reflectable, Savable
{
    @objc var tableElements = [JZWSettingsViewController]()
    @objc var title: String = ""
}

class JZWSettingsViewController: NSViewController
{
    var model: JZWSettingsModel!
    
    private var mvc: JZWMiniSettingsViewController?
    var miniViewController: JZWMiniSettingsViewController?
    {
        set
        {
            self.mvc = newValue
            if self.mvc != nil
            {
                self.mvc!.mainViewController = self
            }
        }
        get
        {
            return self.mvc
        }
    }
    
    @IBOutlet var table: NSTableView?
    @IBOutlet var titleField: NSTextField?
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?)
    {
        if (nibNameOrNil == nil)
        {
            super.init(nibName: "JZWSettingsView", bundle: nil)
        }
        else
        {
            super.init(nibName: nibNameOrNil, bundle: nil)
        }
        // check state here and provide app-specific diagnostic if it's wrong
        
        self.model = self.loadModel()
        self.miniViewController = self.loadMiniViewController()
    }
    
    convenience init()
    {
        self.init(nibName: nil, bundle: nil)
    }

    required convenience init?(coder: NSCoder)
    {
        self.init()
        
        self.model.loadFromCoder(coder)
        
        if let m = coder.decodeObject(forKey: "mini") as! JZWMiniSettingsViewController?
        {
            self.miniViewController = m
        }
    }
    
    override func encode(with aCoder: NSCoder)
    {
        self.model.saveWithCoder(aCoder)
        
        if self.miniViewController != nil
        {
            aCoder.encode(self.miniViewController!, forKey: "mini")
        }
    }
    
    func loadModel() -> JZWSettingsModel
    {
        return JZWSettingsModel()
    }
    
    func loadMiniViewController() -> JZWMiniSettingsViewController?
    {
        return nil
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if let t = self.titleField
        {
            t.delegate = self
        }
        
        if let t = self.table
        {
            t.delegate = self
            t.dataSource = self
            t.selectionHighlightStyle = NSTableView.SelectionHighlightStyle.none
            t.allowsMultipleSelection = true
            t.draggingDestinationFeedbackStyle = NSTableView.DraggingDestinationFeedbackStyle.gap

        }
        
        if let t = self.titleField
        {
            t.delegate = self
        }
    }

    override func viewWillAppear()
    {
        if self.allowsDragging()
        {
            self.table!.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: DragType)])
        }
    }
    
    //****************************************** OVERRIDE IN SUBCLASSES **************************************
    
    func getDefaultTitle() -> String
    {
        return "Title"
    }
    
    func getTitle() -> String
    {
        if self.titleField != nil && self.titleField!.stringValue != ""
        {
            return self.titleField!.stringValue
        }
        else if let m = self.model, m.title != ""
        {
            return m.title
        }
        
        return self.getDefaultTitle()
    }

    func getStaticErrorsAndWarnings() -> (warnings : [String], errors : [String])
    {
        var warnings = [String]()
        var errors = [String]()
        
        for subController in self.model.tableElements
        {
            let (subWarnings, subErrors) = subController.getStaticErrorsAndWarnings()
            warnings += subWarnings
            errors += subErrors
        }
        
        return (warnings, errors)
    }
    
    func newTableElement() -> JZWSettingsViewController?
    {
        return nil
    }
    
    func build(_ fullPath: NSString, userData: inout [String: AnyObject]?) -> AnyObject?
    {
        return self.mvc!.build(NSString(format: "%@.%@", fullPath, self.model.title), userData: &userData)
    }
    
    //****************************************** Other Methods **************************************
    
    func getAllSentenceControllers() -> [String : JZWSentenceViewController]
    {
        var sents = [String : JZWSentenceViewController]()
        
        for child in self.model.tableElements
        {
            sents = child.getAllSentenceControllers().reduce(sents, { (dict, tup) -> [String : JZWSentenceViewController] in
                var d = dict
                d["\(self.model.title).\(tup.0)"] = tup.1
                return d
            })
        }
    
        return sents
    }
    
    func getAllTokenLabels() -> [String]
    {
        var tokenLabels = [String]()
        
        for child in self.model.tableElements
        {
            tokenLabels += child.getAllTokenLabels().map({"\(self.model.title).\($0)"})
        }
        
        return tokenLabels
    }
    
    func updateTokenLabels(_ labels: [String])
    {
        for child in self.model.tableElements
        {
            child.updateTokenLabels(labels)
        }
        
        if let mini = self.miniViewController
        {
            mini.updateTokenLabels(labels)
        }
    }
    
    func getUniqueClassIdentifier() -> String?
    {
        if self.model.tableElements.count > 0
        {
            return self.model.tableElements[0].className
        }
        return self.newTableElement()?.className
    }

    func updateSelection()
    {
        for vc in self.model.tableElements
        {
            vc.miniViewController!.deselect()
        }
        
        (self.table!.selectedRowIndexes as NSIndexSet).enumerate({ (index : Int, stop : UnsafeMutablePointer<ObjCBool>) -> Void in
            self.model.tableElements[index].miniViewController!.select()
        })
    }
    
    //****************************************** IBAction Callbacks **************************************
    
    func didAddNewElement() {}
    
    @IBAction func newElement(_ sender: AnyObject)
    {
        if let newElement = self.newTableElement()
        {
            self.model.tableElements.append(newElement)
            self.table!.reloadData()
            self.didAddNewElement()
        }
    }
    
    @IBAction func deleteElement(_ sender: AnyObject)
    {
        if (self.table!.selectedRow >= 0)
        {
            let toRemoves = self.table!.selectedRowIndexes.map({ (row : Int) -> JZWSettingsViewController in
                self.model.tableElements[row]
            })
            
            for toRemove in toRemoves
            {
                var viewToRemove : NSView? = toRemove.view
                
                if let miniController = toRemove.mvc , miniController is JZWTokenViewController
                {
                    if let descendent = (miniController as! JZWTokenViewController).descendent
                    {
                        viewToRemove = descendent.view
                        NotificationCenter.default.post(name: Notification.Name(rawValue: HISTORYVIEW_POP_NOTIFICATION),
                            object: self.view.window, userInfo: ["view" : viewToRemove!])
                    }
                }
            }
            
            self.model.tableElements = self.model.tableElements.filter({ (controller : JZWSettingsViewController) -> Bool in
                return !toRemoves.contains(controller)
            })
            self.table!.removeRows(at: self.table!.selectedRowIndexes, withAnimation: NSTableView.AnimationOptions.slideDown)
        }
    }
}

extension JZWSettingsViewController : NSControlTextEditingDelegate, NSTextFieldDelegate
{
    func controlTextDidChange(_ obj: Notification)
    {
        let tf = obj.object! as! NSTextField
        
        if (tf == self.titleField)
        {
            if self.miniViewController != nil && self.miniViewController!.titleField != nil
            {
                self.miniViewController!.titleField!.stringValue = tf.stringValue
            }
        }
        else
        {
            if self.titleField != nil
            {
                self.titleField!.stringValue = tf.stringValue
            }
        }
        
        let title = (tf.stringValue == "") ? self.getDefaultTitle() : tf.stringValue
        
        self.model.title = title
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: HISTORYVIEW_TITLE_NOTIFICATION),
            object: self.view.window, userInfo: ["view" : self.view, "title" : title])
    }

    @objc func copy(_ sender: AnyObject)
    {
        if let t = self.table, let type = self.getUniqueClassIdentifier() , t.selectedRow >= 0
        {
            var data = [JZWSettingsViewController]()
            (t.selectedRowIndexes as NSIndexSet).enumerate({ (row : Int, stop : UnsafeMutablePointer<ObjCBool>) -> Void in
                data.append(self.model.tableElements[row])
            })
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setData(NSKeyedArchiver.archivedData(withRootObject: data), forType: NSPasteboard.PasteboardType(rawValue: type))
        }
    }
    
    @objc func willPasteElement(_ elements : [JZWSettingsViewController])
    {
        return
    }
    
    @objc func paste(_ sender: AnyObject)
    {
        if let type = self.getUniqueClassIdentifier()
        {
            if let data = NSPasteboard.general.data(forType: NSPasteboard.PasteboardType(rawValue: type))
            {
                let newElements = NSKeyedUnarchiver.unarchiveObject(with: data) as! [JZWSettingsViewController]
                self.willPasteElement(newElements)
                self.model.tableElements.append(contentsOf: newElements)
                self.table!.reloadData()
            }
        }
    }
}

extension JZWSettingsViewController : NSTableViewDataSource, NSTableViewDelegate
{
    var DragType: String
        {
        get
        {
            // Give each token a unique dragging id so that you cannot drag from one window to another
            return "\(self.className)" + "\(self.view.window!)"
        }
    }

    @objc func allowsDragging() -> Bool
    {
        return false
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int
    {
        return self.model.tableElements.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        return self.model.tableElements[row].miniViewController!.view
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat
    {
        return self.model.tableElements[row].miniViewController!.view.bounds.height
    }
    
    func tableViewSelectionDidChange(_ notification: Notification)
    {
        self.updateSelection()
    }
    
    func tableViewSelectionIsChanging(_ notification: Notification)
    {
        self.tableViewSelectionDidChange(notification)
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool
    {
        return true
    }
    
    
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool
    {
        if !self.allowsDragging()
        {
            return false
        }
        // Copy the row numbers to the pasteboard.
        let data = NSKeyedArchiver.archivedData(withRootObject: rowIndexes)
        pboard.declareTypes([NSPasteboard.PasteboardType(rawValue: DragType)], owner: self)
        pboard.setData(data, forType: NSPasteboard.PasteboardType(rawValue: DragType))
        return true;
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation
    {
        if !self.allowsDragging()
        {
            return NSDragOperation()
        }
        self.table!.setDropRow(row, dropOperation: NSTableView.DropOperation.above)
        return NSDragOperation.every
    }
    
    internal func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool
    {
        if !self.allowsDragging()
        {
            return false
        }

        let pboard = info.draggingPasteboard
        let rowData = pboard.data(forType: NSPasteboard.PasteboardType(rawValue: DragType))
        let rowIndexes: IndexSet? = NSKeyedUnarchiver.unarchiveObject(with: rowData!) as? IndexSet
        
        let toMove = rowIndexes!.map {self.model.tableElements[$0]}
        let before = self.model.tableElements[0 ..< row].filter {!toMove.contains($0)}
        let after = self.model.tableElements[row ..< self.model.tableElements.count].filter {!toMove.contains($0)}
        
        self.model.tableElements = before + toMove + after
        self.table!.reloadData()
        self.updateSelection()
        
        return true
    }
}
