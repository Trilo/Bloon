//
//  JZWGraphWindowViewController.swift
//  Bloon
//
//  Created by Jacob Weiss on 2/1/15.
//  Copyright (c) 2015 Jacob Weiss. All rights reserved.
//

import Foundation

class JZWGraphWindowModel: JZWSettingsModel
{
    @objc var rows: Int = 1
    @objc var cols: Int = 1
}

class JZWGraphWindowViewController: JZWSettingsViewController, JZWMiniGraphWatcher
{
    var graphColors: [(JZWGradient) -> ()] =
    [
        {(grad: JZWGradient) -> () in grad.setRed()},
        {(grad: JZWGradient) -> () in grad.setOrange()},
        {(grad: JZWGradient) -> () in grad.setYellow()},
        {(grad: JZWGradient) -> () in grad.setGreen()},
        {(grad: JZWGradient) -> () in grad.setBlue()},
        {(grad: JZWGradient) -> () in grad.setDarkDarkBlue()},
        {(grad: JZWGradient) -> () in grad.setPurple()},
        {(grad: JZWGradient) -> () in grad.setGrey()},
        {(grad: JZWGradient) -> () in grad.setBlack()}
    ]
    
    var visualizers = [JZWGradient]()
    
    @IBOutlet var numRowsField: NSTextField!
    @IBOutlet var numRowsStepper: NSStepper!
    @IBOutlet var numColsField: NSTextField!
    @IBOutlet var numColsStepper: NSStepper!
    @IBOutlet var windowVisualizerContainer: NSView!
    
    var windowVisualizer: JZWGridBoxView = JZWGridBoxView(rows: 1, cols: 1)
    
    init()
    {
        super.init(nibName: "JZWGraphWindowView", bundle: nil)
        // check state here and provide app-specific diagnostic if it's wrong
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.windowVisualizer.backgroundColor = NSColor.black
        self.windowVisualizerContainer.addSubview(self.windowVisualizer)
        let dict : [String : AnyObject] = ["wv" : self.windowVisualizer]
        self.windowVisualizerContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[wv]|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: dict))
        self.windowVisualizerContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[wv]|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: dict))
        
        self.readFromModel()
        
        self.redrawGraphVisualizations()        
    }
        
    required convenience init?(coder: NSCoder)
    {
        self.init()
        
        self.model.loadFromCoder(coder)
        
        for i in 0 ..< self.model.tableElements.count
        {
            let g = self.newVisualizerGradient()
            self.visualizers.append(g)
            (self.model.tableElements[i].miniViewController as! JZWMiniGraphViewController).addWatcher(self)
        }
    }
    
    func readFromModel()
    {
        let m = self.model as! JZWGraphWindowModel
        
        self.titleField?.stringValue = m.title
        self.miniViewController!.title = m.title
        self.numRowsField!.integerValue = m.rows
        self.numRowsStepper!.integerValue = m.rows
        self.windowVisualizer.numRows = m.rows
        self.numColsField!.integerValue = m.cols
        self.numColsStepper!.integerValue = m.cols
        self.windowVisualizer.numColumns = m.cols
    }
    
    override func loadModel() -> JZWSettingsModel
    {
        return JZWGraphWindowModel()
    }
    
    override func loadMiniViewController() -> JZWMiniSettingsViewController?
    {
        return JZWGraphWindowMiniViewController()
    }
    
    override func getDefaultTitle() -> String
    {
        return "Window"
    }
    
    @IBAction func columnsChanged(_ sender: AnyObject)
    {
        let c = self.numColsStepper.integerValue
        let m = self.model as! JZWGraphWindowModel
        
        m.cols = c
        self.numColsField.integerValue = c
        self.windowVisualizer.numColumns = c
        self.redrawGraphVisualizations()
    }
    @IBAction func rowsChanged(_ sender: AnyObject)
    {
        let r = self.numRowsStepper.integerValue
        let m = self.model as! JZWGraphWindowModel
        
        m.rows = r
        self.numRowsField.integerValue = r
        self.windowVisualizer.numRows = r
        self.redrawGraphVisualizations()
    }
    
    func newVisualizerGradient() -> JZWGradient
    {
        let g = JZWGradient()
        g.opacity = 0.75
        g.initialize()
        g.borderColor = NSColor.white
        g.borderWidth = 2
        return g;
    }
    
    func redrawGraphVisualizations()
    {
        self.windowVisualizer.clear()
        
        self.windowVisualizer.numRows = self.numRowsStepper.integerValue
        self.windowVisualizer.numColumns = self.numColsStepper.integerValue
                
        for i in 0 ..< self.model.tableElements.count
        {
            let graphController = self.model.tableElements[i] as! JZWGraphViewController
            let mc = graphController.miniViewController! as! JZWMiniGraphViewController
            let graphVisual = self.visualizers[i]
                        
            self.graphColors[i % self.graphColors.count](mc.view as! JZWGradient)
            self.graphColors[i % self.graphColors.count](graphVisual as JZWGradient)
            
            if mc.xStepper.integerValue >= self.numColsStepper.integerValue
            {
                mc.xStepper.integerValue = self.numColsStepper.integerValue - 1
            }
            if mc.yStepper.integerValue >= self.numRowsStepper.integerValue
            {
                mc.yStepper.integerValue = self.numRowsStepper.integerValue - 1
            }

            mc.xStepper.maxValue = Double(self.numColsStepper!.integerValue - 1)
            mc.yStepper.maxValue = Double(self.numRowsStepper!.integerValue - 1)
            mc.wStepper.maxValue = Double(self.numColsStepper!.integerValue - mc.xStepper!.integerValue)
            mc.hStepper.maxValue = Double(self.numRowsStepper!.integerValue - mc.yStepper!.integerValue)
                        
            mc.xField.integerValue = mc.xStepper.integerValue
            mc.yField.integerValue = mc.yStepper.integerValue
            mc.wField.integerValue = mc.wStepper.integerValue
            mc.hField.integerValue = mc.hStepper.integerValue
            
            graphController.boundsChanged("x", value: mc.xStepper.integerValue)
            graphController.boundsChanged("y", value: mc.yStepper.integerValue)
            graphController.boundsChanged("w", value: mc.wStepper.integerValue)
            graphController.boundsChanged("h", value: mc.hStepper.integerValue)
            
            self.windowVisualizer.animateNextChanges()
            self.windowVisualizer.addSubview(graphVisual,
                inRect: NSMakeRect(
                    CGFloat(mc.xStepper.integerValue),
                    CGFloat(mc.yStepper.integerValue),
                    CGFloat(mc.wStepper.integerValue),
                    CGFloat(mc.hStepper.integerValue)))
        }
    }
    
    func boundsChanged(_ bound: String, value: Int)
    {
        self.redrawGraphVisualizations()
    }
    
    @objc override func paste(_ sender: AnyObject)
    {
        let type = JZWGraphViewController().className
        if let data = NSPasteboard.general.data(forType: NSPasteboard.PasteboardType(rawValue: type))
        {
            let newElements = NSKeyedUnarchiver.unarchiveObject(with: data) as! [JZWSettingsViewController]
            for newElement in newElements
            {
                let miniController = newElement.miniViewController! as! JZWMiniGraphViewController
                miniController.addWatcher(self)
                let g = self.newVisualizerGradient()
                self.visualizers.append(g)
                self.model.tableElements.append(newElement)
                self.table!.reloadData()
                self.redrawGraphVisualizations()
            }
        }
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: TOKEN_LABELS_CHANGED_NOTIFICATION), object: self, userInfo: nil)
    }
    
    override func build(_ fullPath: NSString, userData: inout [String: AnyObject]?) -> AnyObject?
    {
        let m = self.model as! JZWGraphWindowModel
        let graphs = JZWGridBoxView(rows: m.rows, cols: m.cols)
        
        for graphController in m.tableElements.reversed()
        {
            let gm = graphController.model as! JZWGraphModel
            let graph = graphController.build("", userData: &userData)! as! JZWGLGraph
            graphs.addSubview(graph, inRect: NSMakeRect(CGFloat(gm.x), CGFloat(gm.y), CGFloat(gm.w), CGFloat(gm.h)))
        }
        
        return graphs
    }
    
    override func newTableElement() -> JZWSettingsViewController?
    {
        let newGraph = JZWGraphViewController()
        let mc = newGraph.miniViewController! as! JZWMiniGraphViewController
        mc.addWatcher(self)
        let g = self.newVisualizerGradient()
        self.visualizers.append(g)
        self.model.tableElements.append(newGraph)
        self.table!.reloadData()
        self.redrawGraphVisualizations()
        return nil
    }
    
    override func deleteElement(_ sender: AnyObject)
    {
        if self.table!.selectedRow >= 0
        {
            super.deleteElement(sender)
            
            self.visualizers.removeLast()
            self.redrawGraphVisualizations()
        }
    }
}

