//
//  JZWMainGui.swift
//  Bloon
//
//  Created by Jacob Weiss on 12/8/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Foundation

let ANIMATION_SPEED: Float = 0.7

let HISTORYVIEW_PUSH_NOTIFICATION = "HISTORYVIEWPUSH"
let HISTORYVIEW_POP_NOTIFICATION = "HISTORYVIEWPOP"
let HISTORYVIEW_TITLE_NOTIFICATION = "HISTORYVIEWTITLE"

class JZWHistoryViewController: NSViewController, NSPathControlDelegate, CAAnimationDelegate
{
    @IBOutlet var history: NSPathControl!
    @IBOutlet var contentView: NSView!
    @IBOutlet var historyBG: JZWGradient!
    
    var viewStack = [NSView]()
    var animationStack = [(NSArray, CABasicAnimation)]()
    
    var currentIndex: Int = -1
    var targetIndex: Int = 0
    var animationInProgress: Bool = false
    
    var viewsToPush: [(NSView, NSString)] = [(NSView, NSString)]()
    
    let easeInOut: (CAMediaTimingFunction, Float) = (CAMediaTimingFunction(controlPoints: 0.5, 0, 0.5, 1.0), ANIMATION_SPEED)
    let easeIn: (CAMediaTimingFunction, Float) = (CAMediaTimingFunction(controlPoints: 0.8, 0, 0.8, 0.5), ANIMATION_SPEED)
    let easeOut: (CAMediaTimingFunction, Float) = (CAMediaTimingFunction(controlPoints: 0.2, 0.5, 0.2, 1.0), ANIMATION_SPEED)
    let linear: (CAMediaTimingFunction, Float) = (CAMediaTimingFunction(controlPoints: 0.5, 0.5, 0.5, 0.5), ANIMATION_SPEED * 2.5)
    
    // Initializers
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        // check state here and provide app-specific diagnostic if it's wrong
    }
    convenience init()
    {
        self.init(nibName: "JZWHistoryView", bundle: nil)
        self.view.translatesAutoresizingMaskIntoConstraints = false
        self.history?.setPathComponentCells([NSPathComponentCell]())
        self.contentView?.wantsLayer = true
        self.contentView?.layerContentsRedrawPolicy = NSView.LayerContentsRedrawPolicy.onSetNeedsDisplay
        
        self.history.backgroundColor = NSColor.clear
        self.historyBG.initialize()
        self.historyBG.setWhite()
    }
    
    func initNotifications()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(JZWHistoryViewController.pushViewNotification(_:)), name: NSNotification.Name(rawValue: HISTORYVIEW_PUSH_NOTIFICATION), object: self.view.window)
        NotificationCenter.default.addObserver(self, selector: #selector(JZWHistoryViewController.popViewNotification(_:)), name: NSNotification.Name(rawValue: HISTORYVIEW_POP_NOTIFICATION), object: self.view.window)
        NotificationCenter.default.addObserver(self, selector: #selector(JZWHistoryViewController.titleViewNotification(_:)), name: NSNotification.Name(rawValue: HISTORYVIEW_TITLE_NOTIFICATION), object: self.view.window)
    }
    
    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
    }
    
    // IBActions or Callbacks
    
    @IBAction func pathControlSingleClick(_ sender : AnyObject)
    {
        if self.history?.clickedPathComponentCell() == nil
        {
            return
        }

        let clickedIndex = (self.history!.clickedPathComponentCell()!.url!.pathComponents.count) - 1
                
        self.switchToView(clickedIndex)
    }
    
    // Other Functions
    
    func reset()
    {
        self.currentIndex = -1
    }
    
    @objc func popViewNotification(_ not: Notification)
    {
        let view = (not as NSNotification).userInfo!["view"] as! NSView
        self.popViewsFromView(view)
    }

    @objc func pushViewNotification(_ not: Notification)
    {
        let view = (not as NSNotification).userInfo!["view"] as! NSView?
        let title = (not as NSNotification).userInfo!["title"] as! String?
        
        if view != nil && title != nil
        {
            self.pushView(view!, title: title! as NSString)
        }
    }
    
    @objc func titleViewNotification(_ not: Notification)
    {
        let view = (not as NSNotification).userInfo!["view"] as! NSView?
        let title = (not as NSNotification).userInfo!["title"] as! String?
        
        if view != nil && title != nil
        {
            self.changeTitleForView(view!, newTitle: title!)
        }
        
        self.history!.setNeedsDisplay()
    }
    
    func changeTitleForView(_ view: NSView, newTitle: String)
    {
        for i in 0...self.viewStack.count - 1
        {
            if self.viewStack[i] == view
            {
                (self.history!.pathComponentCells() as [NSPathComponentCell])[i].title = newTitle
            }
        }
    }
    
    func popViewsFromIndex(_ index: Int)
    {        
        var cells = (self.history?.pathComponentCells())!

        var i = self.viewStack.count - 1
        while i >= index
        {
            self.viewStack[i].removeFromSuperview()
            self.contentView!.removeConstraints(self.viewStack[i].constraints)
            
            self.viewStack.removeLast()
            self.animationStack.removeLast()
            cells.removeLast()
            i -= 1
        }
        
        self.history!.setPathComponentCells(cells)
    }
    
    func popViewsFromView(_ view: NSView)
    {
        var i = 0
        while (i < self.viewStack.count && self.viewStack[i] != view)
        {
            i += 1
        }
        
        if i < self.viewStack.count
        {
            self.popViewsFromIndex(i)
        }
    }
    
    func pushView(_ view: NSView, title: NSString)
    {
        if self.currentIndex + 1 < self.viewStack.count && self.viewStack[self.currentIndex + 1] == view
        {
            self.switchToView(self.currentIndex + 1)
            return
        }

        view.wantsLayer = true
        view.layerContentsRedrawPolicy = NSView.LayerContentsRedrawPolicy.onSetNeedsDisplay
        
        if self.animationInProgress
        {
            self.viewsToPush.append((view, title))
            return
        }
        
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
                
        self.contentView?.addSubview(view)
        
        let newCell = NSPathComponentCell(textCell: title as String)

        var cells: [NSPathComponentCell]? = self.history?.pathComponentCells() as [NSPathComponentCell]?
        
        if self.currentIndex == -1
        {
            newCell.url = URL(string: "a")
            cells?.append(newCell)
            self.viewStack.append(view)
            self.history?.setPathComponentCells(cells!)
            
            let constraints = self.layoutConstraintsForView(view, offsetBy: NSMakePoint(0, 0), delegate: self, timingFunc: self.easeInOut)
            
            self.animationStack.append(constraints)
            self.contentView.addConstraints(constraints.0 as! [NSLayoutConstraint])
            
            view.isHidden = false
            self.currentIndex = 0
            
            return
        }
        
        newCell.url = URL(string: cells![self.currentIndex].url!.absoluteString + "/a")
        
        let constraints = self.layoutConstraintsForView(view, offsetBy: NSMakePoint(0, 0), delegate: self, timingFunc: self.easeInOut)

        if self.currentIndex == self.viewStack.count - 1
        {
            cells?.append(newCell)
            self.viewStack.append(view)
            self.animationStack.append(constraints)
        }
        else
        {
            self.popViewsFromIndex(self.currentIndex + 1)
            self.viewStack.append(view)
            self.animationStack.append(constraints)
            cells = self.history?.pathComponentCells() as [NSPathComponentCell]?
            cells?.append(newCell)
        }
        
        self.contentView?.addConstraints(constraints.0 as! [NSLayoutConstraint])

        self.history?.setPathComponentCells(cells!)
        
        self.switchToView(self.currentIndex + 1)
    }
    
    func switchToView(_ index: Int)
    {
        if index == self.currentIndex
        {
            return
        }
        
        self.targetIndex = index

        if self.animationInProgress
        {
            return
        }
        
        let switchFrom = self.currentIndex
        
        self.viewStack[switchFrom].isHidden = false

        let timingFunc = abs(self.currentIndex - index) == 1 ? self.easeInOut : self.easeIn
        
        self.animationInProgress = true
        if index < self.currentIndex
        {
            self.currentIndex -= 1
            self.viewStack[self.currentIndex].isHidden = false

            self.slideToViewToTheLeft(self.currentIndex, slideFrom: switchFrom, timingFunc: timingFunc)
        }
        else if index > currentIndex
        {
            self.currentIndex += 1
            self.viewStack[self.currentIndex].isHidden = false

            self.slideToViewToTheRight(self.currentIndex, slideFrom: switchFrom, timingFunc: timingFunc)
        }
    }
    
    func animationDidStop(_ theAnimation: CAAnimation, finished: Bool)
    {
        if (finished)
        {
            if self.currentIndex > 0
            {
                self.viewStack[self.currentIndex - 1].isHidden = true
            }
            
            if self.currentIndex < self.viewStack.count - 1
            {
                self.viewStack[self.currentIndex + 1].isHidden = true
            }
            
            var increment: Int = 0
            var slideFunc: (_ slideTo: Int, _ slideFrom: Int, _ timingFunc: (CAMediaTimingFunction, Float)) -> ()
            
            if self.targetIndex < self.currentIndex
            {
                increment = -1
                slideFunc = slideToViewToTheLeft
            }
            else if self.targetIndex > self.currentIndex
            {
                increment = 1
                slideFunc = slideToViewToTheRight
            }
            else
            {
                if self.currentIndex > 0
                {
                    self.viewStack[self.currentIndex - 1].isHidden = true
                }
                
                if self.currentIndex < self.viewStack.count - 1
                {
                    self.viewStack[self.currentIndex + 1].isHidden = true
                }

                self.animationInProgress = false
                if self.viewsToPush.count != 0
                {
                    let (v, t) = self.viewsToPush.remove(at: 0)
                    self.pushView(v, title: t)
                }
                return
            }
            
            if (self.currentIndex - increment > 0) && (self.currentIndex - increment < self.viewStack.count)
            {
                self.viewStack[self.currentIndex - increment].isHidden = true
            }
            
            self.currentIndex += increment
            
            let timingFunc = (self.targetIndex == self.currentIndex) ? self.easeOut : self.linear
            
            slideFunc(self.currentIndex, self.currentIndex - increment, timingFunc)
            
            self.viewStack[self.currentIndex].isHidden = false
            self.viewStack[self.currentIndex - increment].isHidden = false
        }
    }
    
    func layoutConstraintsForView(_ view: NSView, offsetBy offset: NSPoint, delegate: CAAnimationDelegate?, timingFunc: (CAMediaTimingFunction, Float)) -> (NSArray, CABasicAnimation)
    {
        let result: NSMutableArray = NSMutableArray(capacity: 4)
        let placeholder = self.contentView!;
        
        result.add(NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.left, relatedBy: NSLayoutConstraint.Relation.equal, toItem: placeholder, attribute: NSLayoutConstraint.Attribute.left, multiplier: 1.0, constant: offset.x))
        
        result.add(NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: placeholder, attribute: NSLayoutConstraint.Attribute.width, multiplier: 1.0, constant: 0))
        
        result.add(NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: placeholder, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1.0, constant: offset.y))
        
        result.add(NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: placeholder, attribute: NSLayoutConstraint.Attribute.height, multiplier: 1.0, constant: 0))
        
        let animation = CABasicAnimation()
        animation.timingFunction = timingFunc.0
        animation.delegate = delegate
        animation.speed = timingFunc.1
        (result.object(at: 0) as! NSLayoutConstraint).animations = [NSAnimatablePropertyKey(stringLiteral: "constant") : animation]
        return (result, animation)
    }
    
    func modifyConstraintsForView(_ view: Int, offsetBy offset: NSPoint, delegate: CAAnimationDelegate?, timingFunc: (CAMediaTimingFunction, Float))
    {        
        let constraints = self.animationStack[view]

        (constraints.0.object(at: 0) as! NSLayoutConstraint).constant = offset.x
        (constraints.0.object(at: 2) as! NSLayoutConstraint).constant = offset.y

        constraints.1.timingFunction = timingFunc.0
        constraints.1.delegate = delegate
        constraints.1.speed = timingFunc.1
    }
    
    func slideToViewToTheRight(_ slideTo: Int, slideFrom: Int, timingFunc: (CAMediaTimingFunction, Float))
    {
        if (slideTo == slideFrom)
        {
            return
        }

        let width: CGFloat = self.contentView!.bounds.size.width;
        
        let constraints = self.animationStack[slideTo]
        self.modifyConstraintsForView(slideTo, offsetBy: NSMakePoint(width, 0.0), delegate: self, timingFunc: timingFunc)
        ((constraints.0.object(at: 0) as AnyObject).animator() as! NSLayoutConstraint).constant = 0.0
        
        let constraintsFrom = self.animationStack[slideFrom]
        self.modifyConstraintsForView(slideFrom, offsetBy: NSMakePoint(0.0, 0.0), delegate: nil, timingFunc: timingFunc)
        ((constraintsFrom.0.object(at: 0) as AnyObject).animator() as! NSLayoutConstraint).constant = -width
    }
    
    func slideToViewToTheLeft(_ slideTo: Int, slideFrom: Int, timingFunc: (CAMediaTimingFunction, Float))
    {
        if (slideTo == slideFrom)
        {
            return
        }
        
        let width: CGFloat = self.contentView!.bounds.size.width;
        
        let constraints = self.animationStack[slideTo]
        self.modifyConstraintsForView(slideTo, offsetBy: NSMakePoint(-width, 0.0), delegate: self, timingFunc: timingFunc)
        ((constraints.0.object(at: 0) as AnyObject).animator() as! NSLayoutConstraint).constant = 0.0
        
        let constraintsFrom = self.animationStack[slideFrom]
        self.modifyConstraintsForView(slideFrom, offsetBy: NSMakePoint(0.0, 0.0), delegate: nil, timingFunc: timingFunc)
        ((constraintsFrom.0.object(at: 0) as AnyObject).animator() as! NSLayoutConstraint).constant = width

    }
}















