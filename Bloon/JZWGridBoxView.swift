//
//  JZWGridBoxView.swift
//  Bloon
//
//  Created by Jacob Weiss on 9/1/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWGridBoxView: NSView
{
    var numRows : Int = 1
    var numColumns : Int = 1
    
    var border : CGFloat = 3
    
    var containedViews : [(view : NSView, bounds : NSRect, constraints : [NSLayoutConstraint]?)] = []
    
    var backgroundColor : NSColor = NSColor.black
    
    var shouldAnimateLayout : Date? = nil
    
    @objc var fullScreenView : NSView? = nil
    
    struct GridBoxLayout {
        let xm : CGFloat
        let xc : CGFloat
        let ym : CGFloat
        let yc : CGFloat
        let wm : CGFloat
        let wc : CGFloat
        let hm : CGFloat
        let hc : CGFloat
    }
    
    convenience init(rows: Int, cols: Int)
    {
        self.init()
        
        self.translatesAutoresizingMaskIntoConstraints = false
                
        self.numRows = rows
        self.numColumns = cols
    }
    
    override init(frame frameRect: NSRect)
    {
        super.init(frame: frameRect)
        self.translatesAutoresizingMaskIntoConstraints = false
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    func addSubview(_ aView: NSView, inRect: NSRect)
    {
        super.addSubview(aView)
        self.containedViews.append((aView, inRect, nil))
        self.needsLayout = true
    }
    
    override var wantsDefaultClipping:Bool{return false}//avoids clipping the view
    
    func clear()
    {
        for view in self.subviews
        {
            view.removeFromSuperview()
        }
        self.containedViews.removeAll(keepingCapacity: true)
        self.removeConstraints(self.constraints)
    }

    func transformRect(_ rect: NSRect, transform: NSAffineTransform) -> NSRect
    {
        let p0 = rect.origin
        let p1 = CGPoint(x: rect.origin.x + rect.size.width, y: rect.origin.y + rect.size.height)
        
        let p0t = transform.transform(p0)
        let p1t = transform.transform(p1)
        
        return NSMakeRect(p0t.x, p0t.y, p1t.x - p0t.x, p1t.y - p0t.y)
    }
    
    func animateNextChanges() {
        self.shouldAnimateLayout = Date()
    }
    
    @objc func fullScreenView(_ ofView : NSView?)
    {
        self.animateNextChanges()
        self.fullScreenView = ofView
        self.layout()
    }
    
    override func layout() {
        super.layout()
        
        var willAnimate = !self.inLiveResize
        if let animateDate = self.shouldAnimateLayout {
            willAnimate = willAnimate && abs(animateDate.timeIntervalSinceNow) < 10
        } else {
            willAnimate = false
        }
        
        let layoutBlock = {
            self.generateLayoutWithApplier { (layout : GridBoxLayout, view : NSView) in
                self.setLayout(layout, forView: view)
            }
        }
        
        if !willAnimate {
            layoutBlock()
        } else {
            for (view, _, _) in self.containedViews where view is JZWGLGraph
            {
                (view as! JZWGLGraph).setForceRedraw(true)
            }

            NSAnimationContext.runAnimationGroup({ (ctx : NSAnimationContext) -> Void in
                ctx.duration = 0.2
                ctx.allowsImplicitAnimation = true
                layoutBlock()
            }, completionHandler: {
                for (view, _, _) in self.containedViews where view is JZWGLGraph
                {
                    (view as! JZWGLGraph).setForceRedraw(false)
                    (view as! JZWGLGraph).setRedrawEverything()
                }
            })
        }
    }
    
//    override func updateConstraints()
//    {
//        self.removeConstraints(self.constraints)
//
//         self.generateLayoutWithApplier { (layout : GridBoxLayout, view : NSView) in
//            let cons = self.constraintsForLayout(layout, forView: view)
//            self.addConstraints(cons)
//         }
//
//        super.updateConstraints()
//    }
    
    
    func layoutForRect(rect : NSRect) -> GridBoxLayout
    {
        var widthAdj = -2 * self.border
        var heightAdj = -2 * self.border
        
        var xAdj : CGFloat = 0
        var yAdj : CGFloat = 0
        
        if rect.origin.x == 0
        {
            widthAdj += self.border
            xAdj -= self.border / 2.0
        }
        if rect.origin.x + rect.size.width == CGFloat(self.numColumns)
        {
            widthAdj += self.border
            xAdj += self.border / 2.0
        }
        
        if rect.origin.y == 0
        {
            heightAdj += self.border
            yAdj -= self.border / 2.0
        }
        if rect.origin.y + rect.size.height == CGFloat(self.numRows)
        {
            heightAdj += self.border
            yAdj += self.border / 2.0
        }
        
        let xm = (2 * rect.origin.x + rect.size.width) / CGFloat(self.numColumns)
        let xc = xAdj
        
        let ym = (2 * rect.origin.y + rect.size.height) / CGFloat(self.numRows)
        let yc = yAdj
        
        let wm = rect.size.width / CGFloat(self.numColumns)
        let wc = widthAdj
        
        let hm = rect.size.height / CGFloat(self.numRows)
        let hc = heightAdj
        
        return GridBoxLayout(xm: xm, xc: xc, ym: ym, yc: yc, wm: wm, wc: wc, hm: hm, hc: hc)
    }
    
    func generateLayoutWithApplier(_ applier : (GridBoxLayout, NSView) -> ()) {
        var fullScreen : (view : NSView, bounds : NSRect, constraints : [NSLayoutConstraint]?)? = nil
        if let fsView = self.fullScreenView
        {
            let v = self.containedViews.filter({$0.view === fsView})
            if v.count == 1
            {
                fullScreen = v[0]
            }
        }
        
        let transform = NSAffineTransform()
        if let fs = fullScreen
        {
            transform.scaleX(by: CGFloat(self.numColumns) / fs.bounds.size.width, yBy: CGFloat(self.numRows) / fs.bounds.size.height)
            transform.translateX(by: -fs.bounds.origin.x, yBy: -fs.bounds.origin.y)
        }
        
        for (view, rect, _) in self.containedViews
        {
            let trect = self.transformRect(rect, transform: transform)
            view.translatesAutoresizingMaskIntoConstraints = false
            let layout = self.layoutForRect(rect: trect)
            applier(layout, view)
        }
    }

    func constraintsForLayout(_ layout : GridBoxLayout, forView view : NSView) -> [NSLayoutConstraint]
    {
        let newConstraints : [NSLayoutConstraint] =
        [
            NSLayoutConstraint(
                item: view, attribute: NSLayoutConstraint.Attribute.centerX,
                relatedBy: NSLayoutConstraint.Relation.equal,
                toItem: self, attribute: NSLayoutConstraint.Attribute.centerX,
                multiplier: layout.xm, constant: layout.xc),
            NSLayoutConstraint(
                item: view, attribute: NSLayoutConstraint.Attribute.centerY,
                relatedBy: NSLayoutConstraint.Relation.equal,
                toItem: self, attribute: NSLayoutConstraint.Attribute.centerY,
                multiplier: layout.ym, constant: layout.yc),
            NSLayoutConstraint(
                item: view, attribute: NSLayoutConstraint.Attribute.width,
                relatedBy: NSLayoutConstraint.Relation.equal,
                toItem: self, attribute: NSLayoutConstraint.Attribute.width,
                multiplier: layout.wm, constant: layout.wc),
            NSLayoutConstraint(
                item: view, attribute: NSLayoutConstraint.Attribute.height,
                relatedBy: NSLayoutConstraint.Relation.equal,
                toItem: self, attribute: NSLayoutConstraint.Attribute.height,
                multiplier: layout.hm, constant: layout.hc)
        ]

        return newConstraints
    }
    
    func rectWithCenter(_ center : CGPoint, size : CGSize) -> NSRect {
        return NSRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }
    
    func centerOfRect(_ rect : NSRect) -> CGPoint {
        return CGPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
    }

    func setLayout(_ layout : GridBoxLayout, forView view : NSView) {
        var center = self.centerOfRect(self.bounds)
        center.x = center.x * layout.xm + layout.xc
        center.y = self.frame.size.height - (center.y * layout.ym + layout.yc)
        
        var size = self.frame.size
        size.width = size.width * layout.wm + layout.wc
        size.height = size.height * layout.hm + layout.hc
        
        view.frame = self.rectWithCenter(center, size: size)
    }

    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(self.bounds)
        self.backgroundColor.setFill()
        self.bounds.fill()
    }
    
    override func removeFromSuperview()
    {
        super.removeFromSuperview()
        self.clear()
    }
    
    enum Direction
    {
        case up
        case down
        case left
        case right
    }
    
    func view(_ view : NSView?, inDirection : Direction) -> NSView?
    {
        guard let v = view else
        {
            return nil
        }
        
        let views = self.containedViews.filter({$0.view === v})
        
        guard views.count == 1 else
        {
            return nil
        }
        
        let bounds = views[0].bounds
        
        let adjacent = self.containedViews.filter({ (v : (view: NSView, bounds: NSRect, constraints: [NSLayoutConstraint]?)) -> Bool in
            let onTheRight = NSMinX(v.bounds) == NSMaxX(bounds)
            let onTheLeft  = NSMaxX(v.bounds) == NSMinX(bounds)
            let above      = NSMinY(v.bounds) == NSMaxY(bounds)
            let below      = NSMaxY(v.bounds) == NSMinY(bounds)
            let hOverlap   = !(NSMaxX(v.bounds) <= NSMinX(bounds) || NSMinX(v.bounds) >= NSMaxX(bounds))
            let vOverlap   = !(NSMaxY(v.bounds) <= NSMinY(bounds) || NSMinY(v.bounds) >= NSMaxY(bounds))

            switch inDirection
            {
            case .up:
                return (below && hOverlap)
            case .down:
                return (above && hOverlap)
            case .left:
                return (onTheLeft && vOverlap)
            case .right:
                return (onTheRight && vOverlap)
            }
        }).sorted { (v0 : (view: NSView, bounds: NSRect, constraints: [NSLayoutConstraint]?), v1 : (view: NSView, bounds: NSRect, constraints: [NSLayoutConstraint]?)) -> Bool in
            switch inDirection
            {
            case .up, .down:
                return v0.bounds.origin.x < v1.bounds.origin.x
            case .left, .right:
                return v0.bounds.origin.y < v1.bounds.origin.y
            }
        }
    
        if adjacent.count > 0
        {
            return adjacent[0].view
        }
        
        return view
    }
    
    
    
    override func keyDown(with theEvent: NSEvent) {
        if (theEvent.modifierFlags.rawValue & NSEvent.ModifierFlags.numericPad.rawValue) != 0
        {
            if let theArrow = theEvent.charactersIgnoringModifiers
            {
                if theArrow.count == 0
                {
                    return
                }
                if theArrow.count == 1
                {
                    switch theArrow.first!.unicodeScalarCodePoint()
                    {
                    case NSLeftArrowFunctionKey:
                        self.fullScreenView(self.view(self.fullScreenView, inDirection: Direction.left))
                    case NSRightArrowFunctionKey:
                        self.fullScreenView(self.view(self.fullScreenView, inDirection: Direction.right))
                    case NSUpArrowFunctionKey:
                        self.fullScreenView(self.view(self.fullScreenView, inDirection: Direction.up))
                    case NSDownArrowFunctionKey:
                        self.fullScreenView(self.view(self.fullScreenView, inDirection: Direction.down))
                    default:
                        return
                    }
                }
            }
        }
        else
        {
            let zoomFactor = 0.5
            let keyMap : [String : (_ graph : JZWGLGraph) -> ()] = [
                " " : {(graph : JZWGLGraph) in graph.setBounds()},
                "x" : {(graph : JZWGLGraph) in graph.zoomX(zoomFactor, zoomY: 0)},
                "X" : {(graph : JZWGLGraph) in graph.zoomX(-zoomFactor, zoomY: 0)},
                "y" : {(graph : JZWGLGraph) in graph.zoomX(0, zoomY: zoomFactor)},
                "Y" : {(graph : JZWGLGraph) in graph.zoomX(0, zoomY: -zoomFactor)},
                "s" : {(graph : JZWGLGraph) in
                    let savePanel = NSSavePanel()
                    savePanel.title = "Save screenshot as..."
                    savePanel.canCreateDirectories = true
                    savePanel.allowedFileTypes = ["png"]
                    savePanel.nameFieldStringValue = graph.graphTitle()
                    let options = JZWScreenshotConfigViewController(baseResolution: graph.frame.size)
                    savePanel.accessoryView = options.view
                    savePanel.beginSheetModal(for: self.window!, completionHandler: { (response : NSApplication.ModalResponse) -> Void in
                        if let path = savePanel.url, response == NSApplication.ModalResponse.OK
                        {
                            let graphImage = graph.image(withResolutionMultiplier: options.resolutionTicker.intValue,
                                                         gridScale: options.maintainsGridLines.state == NSControl.StateValue.on,
                                                         uiScale: options.scaleUI.state == NSControl.StateValue.on)!
                            graphImage.lockFocus()
                            let bitmap = NSBitmapImageRep(focusedViewRect: NSRect(x: 0, y: 0, width: graphImage.size.width, height: graphImage.size.height))!
                            graphImage.unlockFocus()
                            let data = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:])!
                            try! data.write(to: path, options : Data.WritingOptions.atomic)
                        }
                    })
                }
            ]
            
            if let theKey = theEvent.charactersIgnoringModifiers
            {
                if theKey.count == 0
                {
                    return
                }
                if let action = keyMap[theKey]
                {
                    for v in self.containedViews
                    {
                        let loc = NSEvent.mouseLocation
                        let mouse = v.view.convert(loc, from: nil)
                        if (v.view.isMousePoint(mouse, in: v.view.bounds)) && (v.view is JZWGLGraph)
                        {
                            action(v.view as! JZWGLGraph)
                            return
                        }
                    }
                }
            }
        }
    }
    
    func generatePreviews() -> [(NSImage, NSView)]
    {
        var previews = [(NSImage, NSView)]()
        for view in self.containedViews
        {
            if view.view is JZWGLGraph
            {
                previews.append(((view.view as! JZWGLGraph).image(), view.view))
            }
        }
        return previews
    }
    
    deinit
    {
        // Swift.print("Deinit GridBoxView")
        self.containedViews = []
        self.fullScreenView = nil
    }
}

