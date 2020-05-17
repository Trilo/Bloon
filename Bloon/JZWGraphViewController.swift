//
//  JZWGraphViewController.swift
//  Bloon
//
//  Created by Jacob Weiss on 2/1/15.
//  Copyright (c) 2015 Jacob Weiss. All rights reserved.
//

import Foundation

enum GraphMode : Int
{
    case time = 0
    case index = 1
    case variable = 2
    case date = 3
}

class JZWGraphModel: JZWSettingsModel
{
    @objc var xMin: Double = -10
    @objc var xMax: Double = 10
    @objc var xTicks: Int = 10
    @objc var yMin: Double = -10
    @objc var yMax: Double = 10
    @objc var yTicks: Int = 10
    @objc var showsLabels: Int = NSControl.StateValue.on.rawValue
    @objc var showsGrid: Int = NSControl.StateValue.on.rawValue
    @objc var autoTickMarks: Int = NSControl.StateValue.on.rawValue
    @objc var showsAxis: Int = NSControl.StateValue.on.rawValue
    
    @objc var labelColor: NSColor = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 1)
    @objc var gridColor: NSColor = NSColor(calibratedRed: 0.25, green: 0.25, blue: 0.25, alpha: 1)
    @objc var bgColor: NSColor = NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 1)
    @objc var axisColor: NSColor = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 1)
    
    @objc var x: Int = 0
    @objc var y: Int = 0
    @objc var w: Int = 1
    @objc var h: Int = 1
    
    @objc var graphMode : Int = GraphMode.variable.rawValue
    @objc var doesAutoScroll: Int = NSControl.StateValue.off.rawValue
}

class JZWGraphViewController: JZWSettingsViewController, JZWMiniGraphWatcher
{
    @IBOutlet var xMinField: NSTextField!
    @IBOutlet var xMaxField: NSTextField!
    @IBOutlet var xTicksField: NSTextField!
    @IBOutlet var yMinField: NSTextField!
    @IBOutlet var yMaxField: NSTextField!
    @IBOutlet var yTicksField: NSTextField!
    @IBOutlet var showsLabels: NSButton!
    @IBOutlet var showsGrid: NSButton!
    @IBOutlet var autoTickMarks: NSButton!
    @IBOutlet var labelColor: NSColorWell!
    @IBOutlet var gridColor: NSColorWell!
    @IBOutlet var bgColor: NSColorWell!
    @IBOutlet var axisColor: NSColorWell!
    @IBOutlet var showsAxis: NSButton!
    
    @IBOutlet var plotsAgainstTime: NSButton!
    @IBOutlet var plotsAgainstIndex: NSButton!
    @IBOutlet var plotsAgainstVariable: NSButton!
    @IBOutlet var plotsAgainstDate: NSButton!
    @IBOutlet var autoScrolls: NSButton!
    
    init()
    {
        super.init(nibName: "JZWGraphView", bundle: nil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.readFromModel()
        
        let txtColor : NSColor = NSColor.white
        let txtFont : NSFont = NSFont.boldSystemFont(ofSize: 13)
        let txtDict = [NSAttributedString.Key.font : txtFont, NSAttributedString.Key.foregroundColor : txtColor]
        
        self.plotsAgainstTime.attributedTitle =     NSAttributedString(string: "Time",        attributes: txtDict)
        self.plotsAgainstIndex.attributedTitle =    NSAttributedString(string: "Index",       attributes: txtDict)
        self.plotsAgainstVariable.attributedTitle = NSAttributedString(string: "Variable",    attributes: txtDict)
        self.plotsAgainstDate.attributedTitle =     NSAttributedString(string: "Date",        attributes: txtDict)
        self.autoScrolls.attributedTitle =          NSAttributedString(string: "Auto Scroll", attributes: txtDict)
        //self.autoTickMarks.attributedTitle =        NSAttributedString(string: "Auto Ticks",  attributes: txtDict)

        self.changePlotMode(self.plotsAgainstIndex)
        //self.checkboxChanged(self.autoTickMarks)
        
        self.table!.draggingDestinationFeedbackStyle = NSTableView.DraggingDestinationFeedbackStyle.gap
    }
    
    required convenience init?(coder: NSCoder)
    {
        self.init()
        
        self.model.loadFromCoder(coder)
        
        for e in self.model.tableElements
        {
            (e.miniViewController! as! JZWPlotViewController).graphController = self
        }
    }
    
    override func viewWillAppear()
    {
        super.viewWillAppear()
        self.changePlotMode(self)
    }
    override func viewDidAppear()
    {
        self.changePlotMode(self)
    }
    
    func readFromModel()
    {
        let m = self.model as! JZWGraphModel
        
        self.titleField?.stringValue = m.title
        self.xMinField.doubleValue = m.xMin
        self.xMaxField.doubleValue = m.xMax
        //self.xTicksField.integerValue = m.xTicks
        self.yMinField.doubleValue = m.yMin
        self.yMaxField.doubleValue = m.yMax
        //self.yTicksField.integerValue = m.yTicks
        self.showsLabels.state = NSControl.StateValue(rawValue: m.showsLabels)
        self.showsGrid.state = NSControl.StateValue(rawValue: m.showsGrid)
        //self.autoTickMarks.state = m.autoTickMarks
        self.labelColor.color = m.labelColor
        self.gridColor.color = m.gridColor
        self.bgColor.color = m.bgColor
        self.axisColor.color = m.axisColor
        self.showsAxis.state = NSControl.StateValue(rawValue: m.showsAxis)
        
        self.autoScrolls.state = NSControl.StateValue(rawValue: m.doesAutoScroll)
        
        switch GraphMode(rawValue: m.graphMode)!
        {
            case GraphMode.time:
                self.plotsAgainstTime.state = NSControl.StateValue(rawValue: 1)
            case GraphMode.index:
                self.plotsAgainstIndex.state = NSControl.StateValue(rawValue: 1)
            case GraphMode.variable:
                self.plotsAgainstVariable.state = NSControl.StateValue(rawValue: 1)
            case GraphMode.date:
                self.plotsAgainstDate.state = NSControl.StateValue(rawValue: 1)
        }
    }

    override func loadModel() -> JZWSettingsModel
    {
        return JZWGraphModel()
    }
    
    override func loadMiniViewController() -> JZWMiniSettingsViewController?
    {
        let mini = JZWMiniGraphViewController()
        mini.addWatcher(self)
        return mini
    }
    
    override func getDefaultTitle() -> String
    {
        return "Graph"
    }
    
    override func newTableElement() -> JZWSettingsViewController?
    {
        let newPlot = JZWPlotViewController()
        newPlot.graphController = self;
        let newSettings = JZWSettingsViewController()
        newSettings.miniViewController = newPlot
        return newSettings
    }
    
    override func willPasteElement(_ elements: [JZWSettingsViewController])
    {
        for e in elements
        {
            (e.miniViewController as! JZWPlotViewController).graphController = self
        }
    }
    
    @objc override func allowsDragging() -> Bool
    {
        return true
    }
    
    override func controlTextDidChange(_ obj: Notification)
    {
        let field = obj.object! as! NSTextField
        let m = self.model as! JZWGraphModel
        _ = self.miniViewController! as! JZWMiniGraphViewController
        
        let _ = self.view
        switch (field)
        {
            case self.xMinField:
                m.xMin = self.xMinField.doubleValue
            case self.xMaxField:
                m.xMax = self.xMaxField.doubleValue
            //case self.xTicksField:
            //    m.xTicks = self.xTicksField.integerValue
            case self.yMinField:
                m.yMin = self.yMinField.doubleValue
            case self.yMaxField:
                m.yMax = self.yMaxField.doubleValue
            //case self.yTicksField:
            //    m.yTicks = self.yTicksField.integerValue
            default:
                super.controlTextDidChange(obj)
        }
    }
    
    @IBAction func colorChanged(_ sender: AnyObject)
    {
        let m = self.model as! JZWGraphModel
        let cw = sender as! NSColorWell
        
        switch (cw)
        {
            case self.labelColor:
                m.labelColor = self.labelColor.color
            case self.gridColor:
                m.gridColor = self.gridColor.color
            case self.bgColor:
                m.bgColor = self.bgColor.color
            case self.axisColor:
                m.axisColor = self.axisColor.color
            default:
                return
        }
    }
    
    @IBAction func checkboxChanged(_ sender: AnyObject)
    {
        let m = self.model as! JZWGraphModel
        let cb = sender as! NSButton
        
        switch (cb)
        {
            case self.showsLabels:
                m.showsLabels = self.showsLabels.state.rawValue
            case self.showsGrid:
                m.showsGrid = self.showsGrid.state.rawValue
            case self.showsAxis:
                m.showsAxis = self.showsAxis.state.rawValue
            case self.autoScrolls:
                m.doesAutoScroll = self.autoScrolls.state.rawValue
            default:
                return
        }
    }
    
    func boundsChanged(_ bound: String, value: Int)
    {
        let m = self.model as! JZWGraphModel
        let mini = self.miniViewController! as! JZWMiniGraphViewController
        
        switch (bound)
        {
            case "x":
                m.x = mini.xStepper.integerValue
            case "y":
                m.y = mini.yStepper.integerValue
            case "w":
                m.w = mini.wStepper.integerValue
            case "h":
                m.h = mini.hStepper.integerValue
            default:
                return
        }
    }
    
    override func didAddNewElement()
    {
        self.changePlotMode(self)
    }
    
    @IBAction func changePlotMode(_ sender: AnyObject)
    {
        let m = self.model as! JZWGraphModel
        
        if self.plotsAgainstTime.state.rawValue == 1
        {
            m.graphMode = GraphMode.time.rawValue
            self.fillPlotXVarsWithString("Real Time")
        }
        else if self.plotsAgainstIndex.state.rawValue == 1
        {
            m.graphMode = GraphMode.index.rawValue
            self.fillPlotXVarsWithString("Index")
        }
        else if self.plotsAgainstVariable.state.rawValue == 1
        {
            m.graphMode = GraphMode.variable.rawValue
            self.fillPlotXVarsWithString(nil)
        }
        else if self.plotsAgainstDate.state.rawValue == 1
        {
            m.graphMode = GraphMode.date.rawValue
            self.fillPlotXVarsWithString(nil)
        }
    }
    
    private func fillPlotXVarsWithString(_ string: String?)
    {
        let m = self.model as! JZWGraphModel

        for p in m.tableElements
        {
            let plotController = p.miniViewController! as! JZWPlotViewController
            
            if let s = string
            {
                plotController.xVariableField!.isEnabled = false
                plotController.xVariableField!.stringValue = s
                (plotController.xVariableField! as! JZWTextField).getFieldEditor().string = s
            }
            else
            {
                plotController.xVariableField!.isEnabled = true
                plotController.xVariableField!.stringValue = (plotController.model as JZWPlotModel).xVar
                (plotController.xVariableField! as! JZWTextField).getFieldEditor().string = (plotController.model as JZWPlotModel).xVar
                plotController.forceRecolor()
            }
        }
    }
        
    override func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat
    {
        let _ = (self.model.tableElements[row].miniViewController! as! JZWPlotViewController).view
        let h = (self.model.tableElements[row].miniViewController! as! JZWPlotViewController).height.constant
        if h > 0
        {
            return h
        }
        return super.tableView(tableView, heightOfRow: row)
    }

    override func build(_ fullPath: NSString, userData: inout [String: AnyObject]?) -> AnyObject?
    {
        let m = self.model as! JZWGraphModel
        let graph = JZWGLGraph(title: m.title)
        
        let mode = m.graphMode == GraphMode.date.rawValue ? GraphMode.variable.rawValue : m.graphMode
        
        userData!["GraphMode"] = mode as AnyObject?
        
        for p in m.tableElements.reversed()
        {
            if let plot = p.build("", userData: &userData) as! JZWPlot?
            {
                graph!.add(plot)
            }
        }
        
        let scrollMode : AutoScrollMode = m.doesAutoScroll == NSControl.StateValue.on.rawValue ? AutoScrollNew : AutoScrollOff
        
        graph?.setXMin(m.xMin, xMax: m.xMax, xTicks: Int32(m.xTicks),
            yMin: m.yMin, yMax: m.yMax, yTicks: Int32(m.yTicks),
            showsLabels: m.showsLabels == NSControl.StateValue.on.rawValue, showsGrid: m.showsGrid == NSControl.StateValue.on.rawValue,
            autoTickMarks: m.autoTickMarks == NSControl.StateValue.on.rawValue, showsAxis: m.showsAxis == NSControl.StateValue.on.rawValue, scrollMode: scrollMode,
            label: m.labelColor.usingColorSpace(NSColorSpace.sRGB)!,
            gridColor: m.gridColor.usingColorSpace(NSColorSpace.sRGB)!,
            bgColor: m.bgColor.usingColorSpace(NSColorSpace.sRGB)!,
            axisColor: m.axisColor.usingColorSpace(NSColorSpace.sRGB)!,
            xAxisDates: m.graphMode == GraphMode.date.rawValue)
                
        return graph
    }
}




