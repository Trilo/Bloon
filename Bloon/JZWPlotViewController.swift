//
//  JZWGrapherView.swift
//  Bloon
//
//  Created by Jacob Weiss on 12/7/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Foundation

extension String {
    
    subscript (i: Int) -> Character {
        return self[self.index(self.startIndex, offsetBy: i)]
    }
    
    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }    
}

class JZWPlotModel: JZWSettingsModel
{
    @objc var xVar: String = ""
    @objc var yVar: String = ""
    @objc var cond: String = ""
    @objc var color: NSColor = NSColor.red
    @objc var pointSize: Int = 3
    @objc var lineWidth: Int = 0
    @objc var avgNum: Int = 0
    @objc var gradient: [[Double]]? = nil
    @objc var colorBar: String = ""
}

extension String
{
    func stringByTrimmingCharactersFromStartInSet(_ set : CharacterSet) -> String
    {
        var copy = self
        while copy != "" && set.contains(UnicodeScalar(UInt32(copy[copy.startIndex].unicodeScalarCodePoint()))!)
        {
            copy.remove(at: copy.startIndex)
        }
        return copy
    }
    func stringByTrimmingCharactersFromEndInSet(_ set : CharacterSet) -> String
    {
        var copy = self
        while copy != "" && set.contains(UnicodeScalar(UInt32(copy[copy.index(before: copy.endIndex)].unicodeScalarCodePoint()))!)
        {
            copy.remove(at: copy.index(before: copy.endIndex))
        }
        return copy
    }
}

class JZWPlotViewController: JZWMiniSettingsViewController, JZWTextFieldDelegate
{
    var model = JZWPlotModel()
        
    var tokenLabels : [String]
    {
        didSet
        {
            DispatchQueue.main.async { 
                self.forceRecolor()
            }
        }
    }
    
    @IBOutlet var xVariableField: NSTextField?
    @IBOutlet var yVariableField: NSTextField?
    @IBOutlet var pointSizeField: NSTextField!
    @IBOutlet var color: NSColorWell!
    @IBOutlet var averageField: NSTextField!
    @IBOutlet var conditional: NSTextField!
    @IBOutlet var conditionHeight: NSLayoutConstraint!
    @IBOutlet var height: NSLayoutConstraint!
    @IBOutlet var lineWidthField: NSTextField!
    @IBOutlet weak var colorBarField: NSTextField!
    
    weak var graphController : JZWGraphViewController! = nil
    
    init()
    {
        self.tokenLabels = [String]()
        
        super.init(nibName: "JZWPlotView", bundle: nil)
        // check state here and provide app-specific diagnostic if it's wrong
        NotificationCenter.default.post(name: Notification.Name(rawValue: TOKEN_LABELS_CHANGED_NOTIFICATION), object: self, userInfo: nil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.xVariableField?.stringValue = self.model.xVar
        self.yVariableField?.stringValue = self.model.yVar
        self.conditional?.stringValue = self.model.cond
        self.colorBarField?.stringValue = self.model.colorBar

        self.pointSizeField.stringValue = "\(self.model.pointSize)"
        self.lineWidthField.stringValue = "\(self.model.lineWidth)"
        self.color.color = self.model.color
        self.titleField?.stringValue = self.mainViewController!.model.title
        self.averageField.stringValue = "\(self.model.avgNum)"
        
        (self.xVariableField! as! JZWTextField).getFieldEditor().string = self.model.xVar
        (self.yVariableField! as! JZWTextField).getFieldEditor().string = self.model.yVar
        (self.conditional! as! JZWTextField).getFieldEditor().string = self.model.cond
        (self.colorBarField! as! JZWTextField).getFieldEditor().string = self.model.colorBar

        NotificationCenter.default.post(name: Notification.Name(rawValue: TOKEN_LABELS_CHANGED_NOTIFICATION), object: self, userInfo: nil)
        
        self.graphController.changePlotMode(self)
        
        for subView in self.view.subviews where subView.tag == 1
        {
            let label = subView as! NSTextField
            
            let attributedLabelText = NSMutableAttributedString(string: label.attributedStringValue.string)
            let fullRange = NSRange(location: 0, length: attributedLabelText.length)
            attributedLabelText.addAttribute(NSAttributedString.Key.strokeWidth, value: -2, range: fullRange)
            attributedLabelText.addAttribute(NSAttributedString.Key.strokeColor, value: NSColor.black, range: fullRange)
            attributedLabelText.addAttribute(NSAttributedString.Key.foregroundColor, value: NSColor.white, range: fullRange)
            attributedLabelText.addAttribute(NSAttributedString.Key.font, value: NSFont.systemFont(ofSize: 13, weight: NSFont.Weight(rawValue: 1)), range: fullRange)
            
            label.attributedStringValue = attributedLabelText
        }
        
        self.setGradient()
    }
    
    required convenience init?(coder: NSCoder)
    {
        self.init()
        self.model.loadFromCoder(coder)
    }
    
    override func encode(with aCoder: NSCoder)
    {
        self.model.saveWithCoder(aCoder)
    }
    
    func expressionIsValid(_ exp: String) -> Bool
    {
        let validationString = NSMutableString(string: exp)
        let sortedLabels = self.tokenLabels.sorted() { (s1 : String, s2 : String) -> Bool in
            s1.count > s2.count
        }
        for token in sortedLabels
        {
            validationString.replaceOccurrences(of: token, with: " (0) ", options: NSString.CompareOptions.literal, range: NSMakeRange(0, validationString.length))
        }
        let parser = GCMathParser()
        var failed : ObjCBool = false
        parser.evaluate(validationString as String, failed: &failed)
        return !failed.boolValue
    }
    
    func conditionalIsValid(_ exp : String) -> Bool
    {
        let lset = NSMutableCharacterSet()
        let rset = NSMutableCharacterSet()
        lset.formUnion(with: CharacterSet.whitespacesAndNewlines)
        rset.formUnion(with: CharacterSet.whitespacesAndNewlines)
        lset.formUnion(with: CharacterSet(charactersIn: "["))
        rset.formUnion(with: CharacterSet(charactersIn: "]"))

        var parens = 0
        for c in exp
        {
            if c == "[" { parens += 1 }
            if c == "]" { parens -= 1 }
        }
        if parens != 0
        {
            return false
        }
        
        return exp.components(separatedBy: CharacterSet(charactersIn: "&|"))
          .map({ (comp : String) -> String in
            return comp.stringByTrimmingCharactersFromStartInSet(lset as CharacterSet).stringByTrimmingCharactersFromEndInSet(rset as CharacterSet).replacingOccurrences(of: "\n", with: " ")
        }).map({ (expr : String) -> Bool in
            for c in ["<=", ">=", "<", ">", "==", "!="]
            {
                let exprs = expr.components(separatedBy: c)
                if exprs.count == 2
                {
                    return expressionIsValid(exprs[0]) && expressionIsValid(exprs[1])
                }
            }
            return false
        }).reduce(true, {$0 && $1})
    }
    
    func forceRecolor()
    {
        if let xvf = self.xVariableField, let yvf = self.yVariableField, let cond = self.conditional, let cb = self.colorBarField
        {
            self.formatStorage((self.xVariableField! as! JZWTextField).getFieldEditor().textStorage!, field : xvf as? JZWTextField)
            self.formatStorage((self.yVariableField! as! JZWTextField).getFieldEditor().textStorage!, field : yvf as? JZWTextField)
            self.formatStorage((self.conditional! as! JZWTextField).getFieldEditor().textStorage!, field : cond as? JZWTextField)
            self.formatStorage((self.colorBarField! as! JZWTextField).getFieldEditor().textStorage!, field : cb as? JZWTextField)
        }
    }
    
    func formatStorage(_ storage: NSTextStorage, field: JZWTextField? = nil)
    {
        let digits = CharacterSet.decimalDigits
        
        let fullRange = NSMakeRange(0, storage.length)
        storage.removeAttribute(NSAttributedString.Key.strokeWidth, range: fullRange)
        storage.removeAttribute(NSAttributedString.Key.foregroundColor, range: fullRange)
        storage.removeAttribute(NSAttributedString.Key.backgroundColor, range: fullRange)
        
        let str = storage.string
        
        if field == self.conditional ? !self.conditionalIsValid(str) : !self.expressionIsValid(str)
        {
            storage.addAttribute(NSAttributedString.Key.backgroundColor, value: NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0.25), range: fullRange)
        }
        
        var digitRange = NSMakeRange(0, 1)
        for c in str.unicodeScalars
        {
            if digits.contains(UnicodeScalar(c.value)!) || UnicodeScalar(".").value == c.value
            {
                storage.addAttribute(NSAttributedString.Key.foregroundColor, value: NSColor(calibratedRed: 0, green: 0.4, blue: 0, alpha: 1), range: digitRange)
                storage.addAttribute(NSAttributedString.Key.strokeWidth, value: -5, range: digitRange)
            }
            digitRange.location += 1
        }
        
        for token in self.tokenLabels
        {
            var range = (str as NSString).range(of: token)
            
            while (range.location != NSNotFound)
            {
                storage.addAttribute(NSAttributedString.Key.foregroundColor, value: NSColor(calibratedRed: 0, green: 0, blue: 0.6, alpha: 1), range: range)
                storage.addAttribute(NSAttributedString.Key.strokeWidth, value: -5, range: range)
                range = (str as NSString).range(of: token, options: NSString.CompareOptions.literal, range: NSMakeRange(range.location + range.length, str.count - (range.location + range.length)))
            }
        }
        
        for function in (GCMathParser.functionList() as! [String])
        {
            var range = (str as NSString).range(of: function)

            while (range.location != NSNotFound)
            {
                storage.addAttribute(NSAttributedString.Key.strokeWidth, value: -5, range: range)
                range = (str as NSString).range(of: function, options: NSString.CompareOptions.literal, range: NSMakeRange(range.location + range.length, str.count - (range.location + range.length)))
            }
        }
        
        storage.addAttribute(NSAttributedString.Key.font, value: NSFont.systemFont(ofSize: 13), range: fullRange)
        
        if let f = field
        {
            f.attributedStringValue = storage.attributedSubstring(from: fullRange)
        }
    }
    
    func updatedAvgAndPoint(_ field : NSTextField) -> Bool
    {
        if field === self.averageField
        {
            self.model.avgNum = Int(field.intValue)
            if field.intValue == 0
            {
                self.averageField.stringValue = "0"
            }
            return true
        }
        else if field === self.pointSizeField
        {
            self.model.pointSize = Int(field.intValue)
            if field.intValue == 0
            {
                self.pointSizeField.stringValue = "0"
                self.model.pointSize = 0
            }
            return true
        }
        else if field === self.lineWidthField
        {
            self.model.lineWidth = Int(field.intValue)
            if field.intValue == 0
            {
                self.lineWidthField.stringValue = "0"
                self.model.lineWidth = 0;
            }
            return true
        }

        return false
    }
    
    override func select()
    {
        (self.view as! JZWGradient).borderWidth = 4
        (self.view as! JZWGradient).borderColor = NSColor.black
        (self.view as! JZWGradient).redrawGradient()
    }
        
    override func deselect()
    {
        (self.view as! JZWGradient).borderWidth = 2
        (self.view as! JZWGradient).borderColor = NSColor.white
        (self.view as! JZWGradient).redrawGradient()
    }

    func setGradient()
    {
        if let g = self.model.gradient
        {
            (self.view as! JZWGradient).gradient = g.reduce([CGFloat](), {$0 + $1.map({CGFloat($0)})})
        }
        else
        {
            (self.view as! JZWGradient).gradient = [self.model.color.redComponent * 0.8,
                                                    self.model.color.greenComponent * 0.8,
                                                    self.model.color.blueComponent * 0.8,
                                                    self.model.color.alphaComponent,
                                                    self.model.color.redComponent,
                                                    self.model.color.greenComponent,
                                                    self.model.color.blueComponent,
                                                    self.model.color.alphaComponent]
        }
        (self.view as! JZWGradient).redrawGradient()
    }
    
    @IBAction func openGradient(_ sender: Any)
    {
        let openPanel = NSOpenPanel()
        openPanel.title = "Open Gradient Image"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedFileTypes = ["jpg", "png", "bmp", "gif", "tiff"];
        openPanel.begin { (response : NSApplication.ModalResponse) -> Void in
            if let path = openPanel.url?.path , response == NSApplication.ModalResponse.OK
            {
                let image = NSImage(contentsOfFile: path)
                let bitmap = NSBitmapImageRep(data: (image?.tiffRepresentation)!)
                var gradient : [[Double]] = []
                for y in 0 ..< bitmap!.pixelsHigh
                {
                    let c = bitmap!.colorAt(x: 0, y: y)!
                    let sample : [Double] = [Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent), Double(c.alphaComponent)]
                    gradient.append(sample)
                }
                self.model.gradient = gradient.reversed()
                self.setGradient()
            }
        }
    }
    
    func controlTextDidChange(_ obj: Notification)
    {
        let field = obj.object! as! NSTextField
        
        if self.updatedAvgAndPoint(field)
        {
            return
        }
        
        let fe = (field as! JZWTextField).getAssociatedFieldEditor()
        self.formatStorage(fe.textStorage!, field: field as? JZWTextField)
        
        if field == self.xVariableField
        {
            self.model.xVar = field.stringValue
        }
        else if field == self.yVariableField
        {
            self.model.yVar = field.stringValue
        }
        else if field == self.conditional
        {
            let desiredHeight = CGFloat(fe.getHeight())
            NSAnimationContext.beginGrouping()
            self.conditionHeight.constant = desiredHeight;
            self.height!.constant = 170 - 22 + desiredHeight;
            let tableview = self.graphController.table!
            tableview.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: Range.init(NSMakeRange(0, tableview.numberOfRows))!))
            NSAnimationContext.endGrouping()
            self.model.cond = field.stringValue
        }
        else if field == self.colorBarField
        {
            self.model.colorBar = field.stringValue
        }
    }
    
    func getMatchesForTextField(_ field: JZWTextField) -> ([String], NSRange)
    {
        let fe = field.getAssociatedFieldEditor()
        let insertionPoint = fe.selectedRange.location
        _ = fe.selectedRange.length
        
        let string = field.stringValue
        
        var preprefix = 0
        
        var prefix: String = (string as NSString).substring(with: NSMakeRange(0, insertionPoint)) as String
        
        let allAutocompletes: [String] = self.tokenLabels + (GCMathParser.functionList() as! [String])
        
        var matches : [String] = []
        
        while prefix.count > 0
        {
            matches = allAutocompletes.filter({$0.hasPrefix(prefix)})
            
            if matches.count > 0
            {
                break
            }
            
            preprefix += 1
            prefix.remove(at: prefix.startIndex)
        }
        
        return (matches, NSMakeRange(preprefix, prefix.count))
    }
    
    func updateMatchesForTextField(_ field: JZWTextField) -> Bool
    {
        let fe = field.getAssociatedFieldEditor()
        
        let (matches, matchRange) = self.getMatchesForTextField(field as JZWTextField)
        
        if matches.count > 0
        {
            fe.completionRange = matchRange
            fe.completions = matches
            return true
        }
        else
        {
            fe.completions = []
            return false
        }
    }
    
    func escapeKeyPressed(_ sender: AnyObject?) {
        let fe = (sender as! JZWTextField).getAssociatedFieldEditor()
        fe.completionEnabled = !fe.completionEnabled
        let _ = self.updateMatchesForTextField(sender as! JZWTextField)
        fe.complete(nil)
    }
    
    @objc func userTypedCharacterInTextField(_ sender: AnyObject?)
    {
        let field = sender! as! NSTextField
        
        if self.updatedAvgAndPoint(field)
        {
            return
        }
        
        let fe = (field as! JZWTextField).getAssociatedFieldEditor()

        if self.updateMatchesForTextField(field as! JZWTextField)
        {
            fe.complete(nil)
        }
        
        self.formatStorage(fe.textStorage!, field: field as? JZWTextField)
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool
    {
        if textView is JZWFieldEditor
        {
            if commandSelector == #selector(NSResponder.complete(_:))
            {
                _ = self.updateMatchesForTextField((textView as! JZWFieldEditor).associatedTextField!)
            }
        }
        return false
    }
    
    override func updateTokenLabels(_ labels: [String])
    {
        self.tokenLabels = labels
    }
    
    func controlTextDidBeginEditing(_ obj: Notification)
    {
        let field = obj.object! as! NSTextField

        if self.updatedAvgAndPoint(field)
        {
            return
        }

        let fe = (field as! JZWTextField).getAssociatedFieldEditor()
        self.formatStorage(fe.textStorage!, field: field as? JZWTextField)
    }
    
    override func validate() -> [String]
    {
        return []
    }
    
    override func build(_ fullPath: NSString, userData: inout [String: AnyObject]?) -> AnyObject?
    {
        let gm = GraphMode(rawValue: userData!["GraphMode"]! as! Int)!
                
        if !((self.expressionIsValid(self.model.xVar) || gm != GraphMode.variable) && self.expressionIsValid(self.model.yVar))
        {
            return nil
        }
        
        let plot = JZWPlot(x: self.model.xVar, y: self.model.yVar, con: self.model.cond, colorStr: self.model.colorBar, scatter: self.model.pointSize > 0, line: self.model.lineWidth > 0,
            tokenLabels: userData![ALL_TOKEN_LABELS]! as! [String : JZWToken],
            sentences:   userData![ALL_SENTENCES]!    as! [String : JZWSentence],
            plotMode: gm, avgNum: self.model.avgNum)
        
        if self.model.colorBar != "" && self.model.gradient != nil
        {
            plot.colorBar = self.model.gradient!
            plot.plot.recordColor()
        }
        else
        {
            plot.color = self.model.color
        }
        plot.lineWidth = CGFloat(self.model.lineWidth)
        plot.pointDim = CGFloat(self.model.pointSize)
        plot.name = self.mainViewController!.model.title;
        return plot
    }
    
    @IBAction func colorChanged(_ sender: AnyObject)
    {
        self.model.gradient = nil
        self.model.color = (sender as! NSColorWell).color
        self.setGradient()
    }
}
