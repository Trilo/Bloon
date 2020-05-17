//
//  JZWGradient.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/27/15.
//  Copyright © 2015 Jacob Weiss. All rights reserved.
//

import Cocoa

//@IBDesignable
class JZWGradient: JZWView, CALayerDelegate
{
    var mutateContext : ((CGContext) -> Void)? = nil
    var drawOnContext : ((CGContext) -> Void)? = nil
    
    var gradient : [CGFloat] = [0, 0, 0, 0, 0, 0, 0, 0]
    
    override var wantsUpdateLayer : Bool
    {
        get
        {
            return true
        }
    }
    
    @IBInspectable
    var gradientIndex : Int
    {
        set
        {
            switch newValue
            {
            case 0:
                self.setRed()
            case 1:
                self.setOrange()
            case 2:
                self.setYellow()
            case 3:
                self.setGreen()
            case 4:
                self.setBlue()
            case 5:
                self.setDarkBlue()
            case 6:
                self.setDarkDarkBlue()
            case 7:
                self.setPurple()
            case 8:
                self.setWhite()
            case 9:
                self.setGrey()
            case 10:
                self.setClear()
            default:
                break
            }
        }
        get
        {
            return 0
        }
    }
    
    @IBInspectable
    var nsTopColor : NSColor
    {
        set
        {
            self.topColor = CIColor(cgColor: newValue.cgColor)
        }
        get
        {
            return NSColor(ciColor: self.topColor!)
        }
    }
    
    @IBInspectable
    var nsBottomColor : NSColor
        {
        set
        {
            self.bottomColor = CIColor(cgColor: newValue.cgColor)
        }
        get
        {
            return NSColor(ciColor: self.bottomColor!)
        }
    }

    
    // The top color of the gradient.
    var tc : CIColor? = nil
    var topColor : CIColor?
    {
        set(newValue)
        {
            tc = newValue
            if let t = newValue
            {
                self.gradient[0] = t.red
                self.gradient[1] = t.green
                self.gradient[2] = t.blue
                self.gradient[3] = t.alpha
            }
        }
        get
        {
            return tc
        }
    }
    
    // The bottom color of the gradient.
    var bc : CIColor? = nil
    var bottomColor : CIColor?
    {
        set(newValue)
        {
            bc = newValue
            if let t = newValue
            {
                let end = self.gradient.count
                self.gradient[end - 4] = t.red
                self.gradient[end - 3] = t.green
                self.gradient[end - 2] = t.blue
                self.gradient[end - 1] = t.alpha
            }
        }
        get
        {
            return bc
        }
    }

    // In order to simulate a button press, the gradient can be reversed.
    var opacity : CGFloat = 1.0;
    @IBInspectable
    var reversed : Bool = false
    @IBInspectable
    var angle : Double = 90

    @IBInspectable
    var cornerRadius : Int
    {
        set
        {
            self.layer!.cornerRadius = CGFloat(newValue)
            self.layer!.masksToBounds = true;
        }
        get
        {
            return Int(self.layer!.cornerRadius)
        }
    }
    
    @IBInspectable
    var borderWidth : Int
    {
        set
        {
            self.layer!.borderWidth = CGFloat(newValue)
        }
        get
        {
            return Int(self.layer!.borderWidth)
        }
    }
    
    @IBInspectable
    var borderColor : NSColor
        {
        set
        {
            self.layer!.borderColor = newValue.cgColor
        }
        get
        {
            return NSColor(cgColor: self.layer!.borderColor!)!
        }
    }
    
    static func whiteBackground() -> JZWGradient
    {
        let g = JZWGradient()
        g.initialize()
        g.setWhite()
        return g
    }
    
    static func blueBackground() -> JZWGradient
    {
        let g = JZWGradient()
        g.initialize()
        g.setBlue()
        return g
    }

    static func darkBlueBackground() -> JZWGradient
    {
        let g = JZWGradient()
        g.initialize()
        g.setDarkBlue()
        return g
    }
    
    static func darkDarkBlueBackground() -> JZWGradient
    {
        let g = JZWGradient()
        g.initialize()
        g.setDarkDarkBlue()
        return g
    }
    
    static func purpleBackground() -> JZWGradient
    {
        let g = JZWGradient()
        g.initialize()
        g.setPurple()
        return g
    }

    static func redBackground() -> JZWGradient
    {
        let g = JZWGradient()
        g.initialize()
        g.setRed()
        return g
    }
    static func greyBackground() -> JZWGradient
    {
        let g = JZWGradient()
        g.initialize()
        g.setGrey()
        return g
    }

    static func yellowBackground() -> JZWGradient
    {
        let g = JZWGradient()
        g.initialize()
        g.setYellow()
        return g
    }
    
    static func blackBackground() -> JZWGradient
    {
        let g = JZWGradient()
        g.initialize()
        g.setBlack()
        return g
    }

    func darkerColorForBorder(_ factor : CGFloat) -> CIColor
    {
        return CIColor(red: self.bottomColor!.red * factor, green: self.bottomColor!.green * factor, blue: self.bottomColor!.blue * factor, alpha: 1)
    }
    
    func setRed()
    {
        self.topColor = CIColor(red:1, green:0, blue:0 ,alpha:1)
        self.bottomColor = CIColor(red:0.7, green:0, blue:0, alpha:1)
        self.redrawGradient()
    }
    
    func setOrange()
    {
        self.topColor = CIColor(red:1, green:0.75, blue:0.25, alpha:1)
        self.bottomColor = CIColor(red:0.85, green:0.3, blue:0.1, alpha:1)
        self.redrawGradient()
    }
    
    func setYellow()
    {
        let k : CGFloat = 0.75;
        self.topColor = CIColor(red:1 * k, green:0.97 * k, blue:0.73 * k, alpha:1)
        self.bottomColor = CIColor(red:1 * k, green:0.91 * k, blue:0.07 * k, alpha:1)
        self.redrawGradient()
    }
    
    func setGreen()
    {
        self.topColor = CIColor(red:0.29, green:0.78, blue:0.16, alpha:1)
        self.bottomColor = CIColor(red:0.27, green:0.63, blue:0.05, alpha:1)
        self.redrawGradient()
    }
    
    func setBlue()
    {
        self.topColor = CIColor(red:0.39, green:0.63, blue:0.78, alpha:1)
        self.bottomColor = CIColor(red:0.22, green:0.42, blue:0.62, alpha:1)
        self.redrawGradient()
    }
    
    func setDarkBlue()
    {
        self.topColor = CIColor(red:0.235, green:0.25, blue:0.439)
        self.bottomColor = CIColor(red:0.2, green:0.2, blue:0.4)
        self.redrawGradient()
    }
    
    func setDarkDarkBlue()
    {
        self.topColor = CIColor(red:0.235 * 0.6, green:0.25 * 0.6, blue:0.439 * 0.6)
        self.bottomColor = CIColor(red:0.4 * 0.6, green:0.4 * 0.6, blue:0.8 * 0.6)
        self.redrawGradient()
    }
    
    func setPurple()
    {
        self.topColor = CIColor(red:0.55, green:0.39, blue:0.78, alpha:1)
        self.bottomColor = CIColor(red:0.44, green:0.22, blue:0.62, alpha:1)
        self.redrawGradient()
    }
    
    func setWhite()
    {
        self.topColor = CIColor(red:1, green:1, blue:1, alpha:1)
        self.bottomColor = CIColor(red:0.9, green:0.9, blue:0.9, alpha:1)
        self.redrawGradient()
    }
    
    func setGrey()
    {
        self.topColor = CIColor(red:0.78, green:0.78, blue:0.78, alpha:1)
        self.bottomColor = CIColor(red:0.62, green:0.62, blue:0.62, alpha:1)
        self.redrawGradient()
    }
    
    func setBlack()
    {
        self.topColor = CIColor(red: 0.23, green: 0.23, blue: 0.23, alpha: 1)
        self.bottomColor = CIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
        self.redrawGradient()
    }

    func setClear()
    {
        self.topColor = CIColor(red:0.39, green:0.63, blue:0.78, alpha:0)
        self.bottomColor = CIColor(red:0.22, green:0.42, blue:0.62, alpha:0)
        self.redrawGradient()
    }
    
    func initialize()
    {
        self.mutateContext = nil
        self.drawOnContext = nil
        self.translatesAutoresizingMaskIntoConstraints = false
        self.layer = CALayer()
        self.wantsLayer = true
        self.layer?.delegate = self

        self.topColor = nil;
        self.bottomColor = nil;
        self.angle = 90;
        
        self.layer?.setNeedsDisplay()
    }
    
    init()
    {
        super.init(frame: NSMakeRect(0, 0, 0, 0))
        self.initialize()
    }
    
    override init(frame frameRect: NSRect)
    {
        super.init(frame: frameRect)
        self.initialize()
    }

    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
        self.initialize()
    }
    
    convenience init(topColor: CIColor, bottomColor: CIColor)
    {
        self.init()
        self.initialize()
        self.topColor = topColor
        self.bottomColor = bottomColor
        
        self.layer?.setNeedsDisplay()
    }
    
    func redrawGradient()
    {
        self.layer?.setNeedsDisplay()
    }
    
    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)
    }
    
    func draw(_ layer: CALayer, in ctx: CGContext)
    {
        if self.gradient.count < 8
        {
            return
        }
        
        let sp = CGColorSpaceCreateDeviceRGB()
        let g = CGGradient(colorSpace: sp, colorComponents: self.gradient, locations: nil, count: self.gradient.count / 4)
        
        if let m = self.mutateContext
        {
            m(ctx)
        }
        
        if self.reversed
        {
            ctx.drawLinearGradient(g!, start: CGPoint(x: 0, y: self.frame.size.height), end: CGPoint(x: 0, y: 0), options: CGGradientDrawingOptions(rawValue: 0))
        }
        else
        {
            ctx.drawLinearGradient(g!, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: self.frame.size.height), options: CGGradientDrawingOptions(rawValue: 0))
        }
        
        if let d = self.drawOnContext
        {
            d(ctx)
        }
    }
}
