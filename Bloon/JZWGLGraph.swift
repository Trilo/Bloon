//
//  JZWGLGraph.swift
//  Bloon
//
//  Created by Jacob Weiss on 11/3/15.
//  Copyright © 2015 Jacob Weiss. All rights reserved.
//

import Cocoa

class JZWGLGraph : NSOpenGLView
{
    static let FRAMERATE = 60.0
    let MAX_POINTS = -1
    
    let NO_SELECTION = -2
    let FLIP_AS = -1
    let FLIP_LEGEND = -3
    
    enum AutoScrollMode
    {
        case AutoScrollOff
        case AutoScrollTime
        case AutoScrollNew
    }
    
    var title : NSString
    
    var plots : [JZWPlot]
    var currentTransform : NSAffineTransform
    
    var xMin : Double 
    var xMax : Double 
    var yMin : Double 
    var yMax : Double
    
    var xScale : Double
    var yScale : Double
    var xTranslate : Double
    var yTranslate : Double
    
    var scrollMode : AutoScrollMode
    
    var backgroundColor : NSColor
    var axisColor : NSColor
    var axesOn : Bool
    
    var xNumTicks : Int
    var yNumTicks : Int
    
    var tickLength : CGFloat
    var axisWidth : CGFloat
    var tickWidth : CGFloat
    
    var gridOn : Bool
    var gridColor : NSColor
    var gridWidth : CGFloat
    
    var labelsOn : Bool
    var labelColor : NSColor
    
    var unselectedColor : NSColor
    var selectedColor : NSColor
    
    var queue : dispatch_queue_t
    var isUpdating : Bool
    
    var axisLabelFont : UnsafeMutablePointer<Void>
    var titleFont : UnsafeMutablePointer<Void>
    
    var autoTickMarks : Bool
    
    var currentTouches : NSSet
    var mouseIsDown : Bool
    
    var redrawEverything : Int
    
    var menuOn : Bool
    var legendOn : Bool
    var maxPlotNameLength : Int
    var selectedPlot : Int

    // *********************************************** Static Stuff ************************************************

    static let plotUpdateQueue : dispatch_queue_t = dispatch_queue_create("PlotUpdateQueue", DISPATCH_QUEUE_CONCURRENT)
    
    static var updateTimer : NSTimer = {
        return JZWGLGraph.createTimer()
    }()
    
    class func createTimer() -> NSTimer
    {
        let timer = NSTimer.scheduledTimerWithTimeInterval(1.0 / FRAMERATE, target: self, selector: "updateAllGraphs", userInfo: nil, repeats: true)
        NSRunLoop.currentRunLoop().addTimer(timer, forMode: NSEventTrackingRunLoopMode)
        return timer
    }
    
    static var allGraphs : NSMutableArray = {
        let allGraphs = NSMutableArray()
        let _ = JZWGLGraph.updateTimer
        return allGraphs
    }()
    
    static func updateAllGraphs()
    {
        let allGraphs = self.allGraphs
        for g in allGraphs
        {
            g.updateAsync()
        }
    }
    
    static func removeGraph(graph : JZWGLGraph)
    {
        self.allGraphs.removeObject(graph)
    }
    
    // *********************************************** Initializer Methods ************************************************

    init(withTitle graphTitle : NSString, frame frameRect : NSRect = NSMakeRect(0, 0, 0, 0))
    {
        let attribs : [NSOpenGLPixelFormatAttribute] = [
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAccelerated),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAColorSize), NSOpenGLPixelFormatAttribute(32),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADepthSize), NSOpenGLPixelFormatAttribute(23),
            NSOpenGLPixelFormatAttribute(0)
        ]
        
        let pixelFormat = NSOpenGLPixelFormat(attributes: attribs)
        
        self.title = graphTitle;
        
        self.plots = [JZWPlot]()
        self.currentTransform = NSAffineTransform()
        
        self.xMin = -100;
        self.xMax = 100;
        self.yMin = -100;
        self.yMax = 100;
        
        self.xScale = 1;
        self.yScale = 1;
        self.xTranslate = 0;
        self.yTranslate = 0;
        
        self.scrollMode = .AutoScrollOff;
        
        self.backgroundColor = NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 1)
        
        self.axesOn = true;
        self.axisColor = NSColor(calibratedRed:1, green:1, blue:1, alpha:1)
        
        self.xNumTicks = 10;
        self.yNumTicks = 10;
        
        self.tickLength = 20;
        self.tickWidth = 3;
        self.axisWidth = 5;
        
        self.gridColor = NSColor(calibratedRed:0.3, green:0.3, blue:0.3, alpha:1)
        self.gridOn = true;
        self.gridWidth = 1;
        
        self.labelsOn = true;
        self.labelColor = NSColor(calibratedRed:1, green:1, blue:1, alpha:1)
        
        self.queue = dispatch_queue_create(graphTitle.cStringUsingEncoding(NSASCIIStringEncoding), DISPATCH_QUEUE_SERIAL)
        self.isUpdating = false;
        
        GLUT_3_2_CORE_PROFILE
        
        self.axisLabelFont = get_GLUT_BITMAP_8_BY_13()
        self.titleFont = get_GLUT_BITMAP_9_BY_15()
        
        self.autoTickMarks = true
        
        self.currentTouches = NSMutableSet()
        self.mouseIsDown = false;
        
        self.redrawEverything = 4;
        
        self.selectedPlot = NO_SELECTION;
        self.selectedColor = NSColor.grayColor().colorUsingColorSpace(NSColorSpace.sRGBColorSpace())!
        self.unselectedColor = NSColor.whiteColor().colorUsingColorSpace(NSColorSpace.sRGBColorSpace())!
        self.maxPlotNameLength = 0;
        
        self.menuOn = false
        self.legendOn = false
        
        super.init(frame: frameRect, pixelFormat: pixelFormat)!
        
        self.translatesAutoresizingMaskIntoConstraints = false;
        JZWGLGraph.allGraphs.addObject(self)
        self.acceptsTouchEvents = true;
        self.layer!.drawsAsynchronously = true;
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setXMin(_xMin : Double, xMax _xMax : Double, xTicks _xTicks : Int,
            yMin _yMin : Double, yMax _yMax : Double, yTicks _yTicks : Int,
            showsLabels _labels : Bool, showsGrid _grid : Bool, autoTickMarks _autoTicks : Bool, showsAxis _showsAxis : Bool, scrollMode _scrollMode : AutoScrollMode,
            labelColor _labelColor : NSColor, gridColor _gridColor : NSColor, bgColor _bgColor : NSColor, axisColor _axisColor : NSColor)
    {
        self.xMin = _xMin;
        self.xMax = _xMax;
        self.xNumTicks = _xTicks;
        self.yMin = _yMin;
        self.yMax = _yMax;
        self.yNumTicks = _yTicks;
        self.labelsOn = _labels;
        self.gridOn = _grid;
        self.autoTickMarks = _autoTicks;
        self.labelColor = _labelColor;
        self.gridColor = _gridColor;
        self.backgroundColor = _bgColor;
        self.axesOn = _showsAxis;
        self.axisColor = _axisColor;
        self.scrollMode = _scrollMode;
    }
    
    // *********************************************** Drawing Methods ************************************************
    
    let AUTOSCROLL_BUFFER = 0.025
    let LINE_STIPPLE_NUM = 4
    let NORMAL_STIPPLE_PATTERN = 0xFFFF
    let GRID_STIPPLE_PATTERN = 0xAAAA
    
    let TICK_LABEL_ADJUST_TOP = 5
    let TICK_LABEL_ADJUST_BOTTOM = 15
    let TICK_LABEL_ADJUST_LEFT = 5
    let TICK_LABEL_ADJUST_RIGHT = 5
    
    let X_TICK_LABEL_TOP_ADJUST = 5
    let X_TICK_LABEL_BOTTOM_ADJUST = -15
    let X_LABEL_SHIFT = 5
    let MAX_TICK_LABEL_LENGTH = 40
    let AUTO_TICK_WIDTH = 72
    let Y_AXIS_LABEL_LEFT_ADJ = 5
    
    let LARGE_FONT_CHAR_WIDTH = 9
    let SMALL_FONT_CHAR_WIDTH = 8
    
    func STR_LARGE_FONT_WIDTH_PIXELS(len : Int) -> Int
    {
        return len * LARGE_FONT_CHAR_WIDTH
    }
    func STR_SMALL_FONT_WIDTH_PIXELS(len : Int) -> Int
    {
        return len * SMALL_FONT_CHAR_WIDTH
    }
    
    let LARGE_FONT_LINE_HEIGHT = 16
    let MENU_LEGEND_BORDER = 5
    let MENU_WIDTH = 100
    
    let LEGEND_COLOR_X1_ADJ = 2
    let LEGEND_COLOR_Y1_ADJ = -2
    let LEGEND_COLOR_X2_ADJ = 31
    let LEGEND_COLOR_Y2_ADJ = 11
    let MENU_COLOR_X2_ADJ = -2
    let MENU_MOUSE_ADJ = -5
    
    let LEGEND_COLOR_BOX_WIDTH = 40
    
    func glDraw()
    {
        self.openGLContext!.lock()
        self.openGLContext!.makeCurrentContext()
        self.setupGL();
    
        // ******************************** Determine If Full Redraw Required ***********************************
    
        var shouldRedrawEverything = self.redrawEverything > 0 || self.inLiveResize || self.menuOn;

        if (self.redrawEverything > 0)
        {
            self.redrawEverything--;
        }
    
        // ******************************** Determine Scroll Mode ***********************************
    
        switch self.scrollMode
        {
            case .AutoScrollOff:
                break;
            case .AutoScrollNew, .AutoScrollTime:
                if (self.plots.count > 0)
                {
                    var bounds = self.plots[0].plot.getBounds()
                    for p in self.plots
                    {
                        bounds = NSUnionRect(bounds, p.plot.getBounds());
                    }
                    let rightMost = bounds.origin.x + bounds.size.width;
                    let shift = (self.xMax - self.xMin) * AUTOSCROLL_BUFFER;
                    if (Double(rightMost) > self.xMax - shift)
                    {
                        self.xMin += Double(rightMost) - self.xMax + shift;
                        self.xMax = Double(rightMost) + shift;
                        shouldRedrawEverything = true
                    }
                }
                break;
        }
    
    // ******************************** Calculate Useful Values ***********************************
    
        self.setTransform();
    
        var c : NSColor? = nil
    
        if shouldRedrawEverything
        {
            c = self.backgroundColor;
        
            glClearColor(Float(c!.redComponent), Float(c!.greenComponent), Float(c!.blueComponent), 1);
            glClear(UInt32(GL_COLOR_BUFFER_BIT));
        }
    
        let width = self.frame.size.width;
        let height = self.frame.size.height;
        
        let widthValue = self.xMax - self.xMin;
        let heightValue = self.yMax - self.yMin;
    
    
        var xAxis = (-self.yMin) / (heightValue) * Double(height)
        let xAxisReal = xAxis;
        var xAxisLabelTop = true;
        var yAxis = (-self.xMin) / (widthValue) * Double(width)
        let yAxisReal = yAxis;
        var yAxisLabelRight = true
    
        var xOriginValue = 0.0;
        var yOriginValue = 0.0;
    
        if xAxis < 0
        {
            yOriginValue = self.yMin;
            xAxis = 0;
            xAxisLabelTop = true;
        }
        else if xAxis > Double(height)
        {
            yOriginValue = self.yMax;
            xAxis = Double(height)
            xAxisLabelTop = false;
        }
        else
        {
            xAxisLabelTop = self.yMax > -self.yMin;
        }
    
        if (yAxis < 0)
        {
            xOriginValue = self.xMin;
            yAxis = 0;
            yAxisLabelRight = true;
        }
        else if yAxis > Double(width)
        {
            xOriginValue = self.xMax;
            yAxis = Double(width)
            yAxisLabelRight = false;
        }
        else
        {
            yAxisLabelRight = self.xMax > -self.xMin;
        }
    
        var xNumTicksAdjusted : CGFloat = CGFloat(self.xNumTicks)
        
        if (self.autoTickMarks)
        {
            xNumTicksAdjusted = width / CGFloat(AUTO_TICK_WIDTH) - CGFloat(1.0);
        }
    
        let xTickValue = CGFloat(self.xMax - self.xMin) / CGFloat(xNumTicksAdjusted)
        let yTickValue = CGFloat(self.yMax - self.yMin) / CGFloat(self.yNumTicks)
    
        let xTickPixels = CGFloat(width) / xNumTicksAdjusted;
        let yTickPixels = CGFloat(height) / CGFloat(self.yNumTicks)
    
        let ticksValid = xTickPixels > 0 && yTickPixels > 0;
    
        let halfTick = self.tickLength / 2.0;
    
        let xTickStartValue = CGFloat(xOriginValue) + xTickValue - fmod(CGFloat(xOriginValue), xTickValue);
        let xTickStartPixels = (xTickStartValue - CGFloat(xOriginValue)) * CGFloat(self.xScale)
        
        let yTickStartValue = CGFloat(yOriginValue) + yTickValue - fmod(CGFloat(yOriginValue), yTickValue);
        let yTickStartPixels = (yTickStartValue - CGFloat(yOriginValue)) * CGFloat(self.yScale)
    
        // ******************************** Start Drawing ***********************************
        
        if (ticksValid && shouldRedrawEverything)
        {
            // ******************************** Draw The Grid ***********************************
            if (self.gridOn)
            {
                let gc = self.gridColor;
                glLineWidth(GLfloat(self.gridWidth))
                glColor3f(GLfloat(gc.redComponent), GLfloat(gc.greenComponent), GLfloat(gc.blueComponent));
                glLineStipple(GLint(LINE_STIPPLE_NUM), GLushort(GRID_STIPPLE_PATTERN))
                
                glBegin(GLenum(GL_LINES))
                for (var x : GLdouble = yAxis + GLdouble(xTickStartPixels); x < GLdouble(width); x += GLdouble(xTickPixels))
                {
                    glVertex2d(x, xAxisReal);
                    glVertex2d(x, 0);
                    glVertex2d(x, xAxisReal);
                    glVertex2d(x, GLdouble(height))
                }
                for (var x : GLdouble = yAxis + GLdouble(xTickStartPixels); x > 0.0; x -= GLdouble(xTickPixels))
                    {
                    glVertex2d(x, xAxisReal);
                    glVertex2d(x, 0);
                    glVertex2d(x, xAxisReal);
                    glVertex2d(x, GLdouble(height))
                }
                for (var y : GLdouble = xAxis + GLdouble(yTickStartPixels); y < GLdouble(height); y += GLdouble(yTickPixels))
                {
                    glVertex2d(yAxisReal, y);
                    glVertex2d(0, y);
                    glVertex2d(yAxisReal, y);
                    glVertex2d(GLdouble(width), y);
                }
                for (var y : GLdouble = xAxis + GLdouble(yTickStartPixels); y > 0.0; y -= GLdouble(yTickPixels))
                {
                    glVertex2d(yAxisReal, y);
                    glVertex2d(0, y);
                    glVertex2d(yAxisReal, y);
                    glVertex2d(GLdouble(width), y);
                }
                glEnd();
                
                glLineStipple(GLint(LINE_STIPPLE_NUM), GLushort(NORMAL_STIPPLE_PATTERN))
            }
        
            // ******************************** Draw The Axes ***********************************
            if (self.axesOn)
            {
                glLineWidth(GLfloat(self.axisWidth))
                c = self.axisColor;
                glColor3f(GLfloat(c!.redComponent), GLfloat(c!.greenComponent), GLfloat(c!.blueComponent))
                
                glBegin(GLenum(GL_LINES))
                glVertex2d(0, xAxis);
                glVertex2d(GLdouble(width), xAxis);
                glVertex2d(yAxis, 0);
                glVertex2d(yAxis, GLdouble(height))
                glEnd();
            
                // ******************************** Draw The Tick Marks ***********************************
                glLineWidth(GLfloat(self.tickWidth))
                glBegin(GLenum(GL_LINES))
                for (var x : GLdouble = yAxis + GLdouble(xTickStartPixels); x < GLdouble(width); x += GLdouble(xTickPixels))
                {
                    glVertex2d(x, xAxis + GLdouble(halfTick))
                    glVertex2d(x, xAxis - GLdouble(halfTick))
                }
                for (var x : GLdouble = yAxis + GLdouble(xTickStartPixels); x > 0.0; x -= GLdouble(xTickPixels))
                {
                    glVertex2d(x, xAxis + GLdouble(halfTick))
                    glVertex2d(x, xAxis - GLdouble(halfTick))
                }
                for (var y : GLdouble = xAxis + GLdouble(yTickStartPixels); y < GLdouble(height); y += GLdouble(yTickPixels))
                {
                    glVertex2d(yAxis + GLdouble(halfTick), y);
                    glVertex2d(yAxis - GLdouble(halfTick), y);
                }
                for (var y : GLdouble = xAxis + GLdouble(yTickStartPixels); y > 0.0; y -= GLdouble(yTickPixels))
                {
                    glVertex2d(yAxis + GLdouble(halfTick), y);
                    glVertex2d(yAxis - GLdouble(halfTick), y);
                }
                glEnd();
            }
        }
            
        // ******************************** Draw The Data Points ***********************************
        
        let transform = self.currentTransform.transformStruct
        
        let mtrx : [GLfloat] = [
        GLfloat(transform.m11), GLfloat(transform.m12), 0.0, 0.0,
        GLfloat(transform.m21), GLfloat(transform.m22), 0.0, 0.0,
        0.0,             0.0, 1.0, 0.0,
        GLfloat(transform.tX),  GLfloat(transform.tY), 0.0, 1.0
        ]
        
        glLoadMatrixf(mtrx);
        glEnableClientState(GLenum(GL_VERTEX_ARRAY))
        
        for plot in self.plots
        {
            if (plot.hidden)
            {
                continue;
            }
            
            let va = plot.plot;
            
            if (shouldRedrawEverything)
            {
                va.getVertices({ (verts : UnsafeMutablePointer<GLfloat>, nv : Int32) -> Void in
                    glPointSize(GLfloat(plot.pointDim))
                    glColor3f(GLfloat(plot.color.redComponent), GLfloat(plot.color.greenComponent), GLfloat(plot.color.blueComponent))
                    
                    glVertexPointer(2, GLenum(GL_FLOAT), 0, verts);
                    glDrawArrays(GLenum(GL_POINTS), 0, nv);

                })
            }
            else
            {
                va.getNewVertices({ (verts : UnsafeMutablePointer<GLfloat>, nv : Int32) -> Void in
                    glPointSize(GLfloat(plot.pointDim))
                    glColor3f(GLfloat(plot.color.redComponent), GLfloat(plot.color.greenComponent), GLfloat(plot.color.blueComponent))
                    
                    glVertexPointer(2, GLenum(GL_FLOAT), 0, verts);
                    glDrawArrays(GLenum(GL_POINTS), 0, nv);
                })
            }
        }
        
        glDisableClientState(GLenum(GL_VERTEX_ARRAY))
        glLoadIdentity();
        
        // ******************************** Draw Axis Scale Labels ***********************************
        
        if (ticksValid && self.labelsOn)
        {
            let topBottom = xAxisLabelTop   ? (halfTick + CGFloat(TICK_LABEL_ADJUST_TOP))  : -(halfTick + CGFloat(TICK_LABEL_ADJUST_BOTTOM))
            let leftRight = yAxisLabelRight ? (halfTick + CGFloat(TICK_LABEL_ADJUST_LEFT)) : -(halfTick - CGFloat(TICK_LABEL_ADJUST_RIGHT))
            let yTopBottom = xAxisLabelTop ? X_TICK_LABEL_TOP_ADJUST : X_TICK_LABEL_BOTTOM_ADJUST;
            let xLabelShift = X_LABEL_SHIFT;
            
            for (var x : CGFloat = CGFloat(yAxis) + xTickStartPixels; x < CGFloat(width); x += CGFloat(xTickPixels))
            {
                let value = (x - CGFloat(yAxis)) / CGFloat(self.xScale) + CGFloat(xOriginValue)
                
                if (fabs(value) < xTickValue / 2)
                {
                    continue;
                }
                
                let valueString = UnsafeMutablePointer<Int8>(NSString(format: "%.2E", value).cStringUsingEncoding(NSASCIIStringEncoding))
                
                c_drawText(valueString, x + CGFloat(xLabelShift), CGFloat(xAxis) + topBottom, self.axisLabelFont, self.labelColor);
            }
            for (var x : CGFloat = CGFloat(yAxis) + xTickStartPixels; x > 0.0; x -= CGFloat(xTickPixels))
            {
                let value = (x - CGFloat(yAxis)) / CGFloat(self.xScale) + CGFloat(xOriginValue)
                
                if (fabs(value) < xTickValue / 2)
                {
                    continue;
                }
                
                let valueString = UnsafeMutablePointer<Int8>(NSString(format: "%.2E", value).cStringUsingEncoding(NSASCIIStringEncoding))
                
                c_drawText(valueString, x + CGFloat(xLabelShift), CGFloat(xAxis) + topBottom, self.axisLabelFont, self.labelColor);
            }
            for (var y : CGFloat = CGFloat(xAxis) + yTickStartPixels; y < CGFloat(height); y += CGFloat(yTickPixels))
            {
                let value = (y - CGFloat(xAxis)) / CGFloat(self.yScale) + CGFloat(yOriginValue)
                
                if (fabs(value) < yTickValue / 2)
                {
                    continue;
                }
                
                let nsvaluestring = NSString(format: "%.2E", value)
                let valueString = UnsafeMutablePointer<Int8>(nsvaluestring.cStringUsingEncoding(NSASCIIStringEncoding))
                
                var adj = 0.0;
                
                if (!yAxisLabelRight)
                {
                    adj = Double(STR_SMALL_FONT_WIDTH_PIXELS(nsvaluestring.length) + Y_AXIS_LABEL_LEFT_ADJ)
                }
                
                c_drawText(valueString, CGFloat(yAxis) + leftRight - CGFloat(adj), y + CGFloat(yTopBottom), self.axisLabelFont, self.labelColor);
            }
            for (var y : CGFloat = CGFloat(xAxis) + yTickStartPixels; y > 0.0; y -= yTickPixels)
            {
                let value = (y - CGFloat(xAxis)) / CGFloat(self.yScale) + CGFloat(yOriginValue)
                
                if (fabs(value) < yTickValue / 2)
                {
                    continue;
                }
                
                let nsvaluestring = NSString(format: "%.2E", value)
                let valueString = UnsafeMutablePointer<Int8>(nsvaluestring.cStringUsingEncoding(NSASCIIStringEncoding))
                
                var adj = 0.0;
                
                if (!yAxisLabelRight)
                {
                    adj = Double(STR_SMALL_FONT_WIDTH_PIXELS(nsvaluestring.length) + Y_AXIS_LABEL_LEFT_ADJ)
                }
                
                c_drawText(valueString, CGFloat(yAxis) + leftRight - CGFloat(adj), y + CGFloat(yTopBottom), self.axisLabelFont, self.labelColor);
            }
        }
        
        // ******************************** Draw Title ***********************************
        
        let ctitle = UnsafeMutablePointer<Int8>(self.title.cStringUsingEncoding(NSASCIIStringEncoding))
        c_drawText(ctitle, self.bounds.size.width / 2 - CGFloat(STR_LARGE_FONT_WIDTH_PIXELS(self.title.length)) / 2, self.bounds.size.height - CGFloat(LARGE_FONT_LINE_HEIGHT), self.titleFont, self.labelColor);
        
        // ******************************** Draw Legend ***********************************
        
        if (self.legendOn)
        {
            let height = Int(LARGE_FONT_LINE_HEIGHT * self.plots.count + 6);
            let top = self.bounds.size.height;
            let width = self.maxPlotNameLength * LARGE_FONT_CHAR_WIDTH + LEGEND_COLOR_BOX_WIDTH;
            
            glColor3f(1, 1, 1);
            glRectf(0, GLfloat(top), GLfloat(width + MENU_LEGEND_BORDER), GLfloat(top) - GLfloat(height + MENU_LEGEND_BORDER))
            glColor3f(0, 0, 0);
            glRectf(GLfloat(MENU_LEGEND_BORDER), GLfloat(top) - GLfloat(MENU_LEGEND_BORDER), GLfloat(width), GLfloat(top) - GLfloat(height))
            
            let x : Int = MENU_LEGEND_BORDER + 2;
            var y : Int = Int(top - CGFloat(LARGE_FONT_LINE_HEIGHT + 2))
            
            for plot in self.plots
            {
                let name = UnsafeMutablePointer<Int8>(plot.name.cStringUsingEncoding(NSUTF8StringEncoding)!)
                c_drawText(name, CGFloat(x), CGFloat(y), self.titleFont, self.unselectedColor);
                glColor3f(GLfloat(plot.color.redComponent), GLfloat(plot.color.greenComponent), GLfloat(plot.color.blueComponent))
                
                glRectf(GLfloat(x + plot.name.characters.count * LARGE_FONT_CHAR_WIDTH + LEGEND_COLOR_X1_ADJ), GLfloat(y + LEGEND_COLOR_Y1_ADJ),
                GLfloat(x + plot.name.characters.count * LARGE_FONT_CHAR_WIDTH + LEGEND_COLOR_X2_ADJ), GLfloat(y + LEGEND_COLOR_Y2_ADJ))
                y -= LARGE_FONT_LINE_HEIGHT;
            }
        }
        
        // ******************************** Draw Menu ***********************************
        
        if (self.menuOn)
        {
            let height = LARGE_FONT_LINE_HEIGHT * (2 + self.plots.count) + 6;
            glColor3f(1, 1, 1);
            glRectf(0, 0, GLfloat(MENU_WIDTH + MENU_LEGEND_BORDER), GLfloat(height + MENU_LEGEND_BORDER))
            glColor3f(0, 0, 0);
            glRectf(GLfloat(MENU_LEGEND_BORDER), GLfloat(MENU_LEGEND_BORDER), GLfloat(MENU_WIDTH), GLfloat(height))
            
            let x : CGFloat = CGFloat(MENU_LEGEND_BORDER + 2)
            var y : CGFloat = CGFloat(MENU_LEGEND_BORDER + 4)
            
            let mouseGlobal = NSEvent.mouseLocation()
            let windowLocation = self.window?.convertRectFromScreen(NSMakeRect(mouseGlobal.x, mouseGlobal.y, 0, 0))
            let mouse = self.convertPoint(windowLocation!.origin, fromView: nil)
            
            if (NSPointInRect(mouse, self.bounds))
            {
                self.selectedPlot = NO_SELECTION;
                
                var c = self.unselectedColor;
                if (NSPointInRect(mouse, NSMakeRect(CGFloat(x), y + CGFloat(MENU_MOUSE_ADJ), CGFloat(MENU_WIDTH - MENU_LEGEND_BORDER), CGFloat(LARGE_FONT_LINE_HEIGHT))))
                {
                    c = self.selectedColor;
                    self.selectedPlot = FLIP_AS;
                }
                
                if (self.scrollMode == .AutoScrollOff)
                {
                    var enableas = "Enable AS".cStringUsingEncoding(NSASCIIStringEncoding)!
                    c_drawText(&enableas, x, y, self.titleFont, c);
                }
                else
                {
                    var disableas = "Disable AS".cStringUsingEncoding(NSASCIIStringEncoding)!
                    c_drawText(&disableas, x, y, self.titleFont, c);
                }
                
                y += CGFloat(LARGE_FONT_LINE_HEIGHT)
                
                c = self.unselectedColor;
                if (NSPointInRect(mouse, NSMakeRect(x, y + CGFloat(MENU_MOUSE_ADJ), CGFloat(MENU_WIDTH - MENU_LEGEND_BORDER), CGFloat(LARGE_FONT_LINE_HEIGHT))))
                {
                    c = self.selectedColor;
                    self.selectedPlot = FLIP_LEGEND;
                }
                if (self.legendOn)
                {
                    var legendoff = "Legend Off".cStringUsingEncoding(NSASCIIStringEncoding)!
                    c_drawText(&legendoff, x, y, self.titleFont, c);
                }
                else
                {
                    var legendon = "Legend On".cStringUsingEncoding(NSASCIIStringEncoding)!
                    c_drawText(&legendon, x, y, self.titleFont, c);
                }
                
                var i = 0;
                for plot in self.plots
                {
                    y += CGFloat(LARGE_FONT_LINE_HEIGHT)
                    
                    var c = self.unselectedColor;
                    if (NSPointInRect(mouse, NSMakeRect(x, y + CGFloat(MENU_MOUSE_ADJ), CGFloat(MENU_WIDTH - MENU_LEGEND_BORDER), CGFloat(LARGE_FONT_LINE_HEIGHT))))
                    {
                        c = self.selectedColor;
                        self.selectedPlot = i;
                    }
                    
                    if (plot.hidden)
                    {
                        var show = "Show".cStringUsingEncoding(NSASCIIStringEncoding)!
                        c_drawText(&show, x, y, self.titleFont, c);
                    }
                    else
                    {
                        var hide = "Hide".cStringUsingEncoding(NSASCIIStringEncoding)!
                        c_drawText(&hide, x, y, self.titleFont, c);
                    }
                    
                    glColor3f(GLfloat(plot.color.redComponent), GLfloat(plot.color.greenComponent), GLfloat(plot.color.blueComponent))
                    glRectf(GLfloat(x) + GLfloat(LEGEND_COLOR_BOX_WIDTH),      GLfloat(y) + GLfloat(LEGEND_COLOR_Y1_ADJ),
                    GLfloat(MENU_WIDTH + MENU_COLOR_X2_ADJ),  GLfloat(y) + GLfloat(LEGEND_COLOR_Y2_ADJ))
                    i++;
                }
            }
            else
            {
                self.menuOn = false;
                self.setRedrawEverything()
            }
        }
        
        glFlush();
        self.openGLContext!.unlock()
    }
    
    override func drawRect(dirtyRect: NSRect)
    {
        super.drawRect(dirtyRect)
        self.glDraw()
    }
    
    func setupGL()
    {
        glViewport(0, 0, GLsizei(self.bounds.size.width), GLsizei(self.bounds.size.height))
        
        glMatrixMode(GLenum(GL_PROJECTION))
        glLoadIdentity()
        glOrtho(0, GLdouble(self.bounds.size.width), 0, GLdouble(self.bounds.size.height), 0, 1);
        glMatrixMode(GLenum(GL_MODELVIEW))
        glDisable(GLenum(GL_DEPTH_TEST))
        
        glEnable(GLenum(GL_LINE_STIPPLE))
        glEnable(GLenum(GL_POINT_SMOOTH))
    }
    
    override func prepareOpenGL()
    {
        super.prepareOpenGL()
        self.setupGL()
    }
    
    func setTransform()
    {
        if (NSIsEmptyRect(self.frame))
        {
            return;
        }
        
        let xs = Double(self.frame.size.width) / (self.xMax - self.xMin);
        let ys = Double(self.frame.size.height) / (self.yMax - self.yMin);
        let xt = -self.xMin;
        let yt = -self.yMin;
        
        if (xs == self.xScale && ys == self.yScale && xt == self.xTranslate && yt == self.yTranslate)
        {
            return;
        }
        else
        {
            self.xScale = xs;
            self.yScale = ys;
            self.xTranslate = xt;
            self.yTranslate = yt;
            
            self.currentTransform = NSAffineTransform()
            self.currentTransform.scaleXBy(CGFloat(xs), yBy: CGFloat(ys))
            self.currentTransform.translateXBy(CGFloat(xt), yBy: CGFloat(yt))
        }
    }

    // *********************************************** Updating Methods ************************************************
    
    func updateVertices() -> Bool // Should return true if the plot was updated, false otherwise
    {
        if (self.isUpdating)
        {
            return true;
        }
        
        objc_sync_enter(self);
        
        self.isUpdating = true;
        
        if (self.plots.count == 0)
        {
            self.isUpdating = false;
            objc_sync_exit(self);
            return false;
        }
        
        var updated = false;
        dispatch_apply(self.plots.count, JZWGLGraph.plotUpdateQueue) { (i : Int) -> Void in
            updated = updated || self.plots[i].update(self.MAX_POINTS)
        }
        
        self.isUpdating = false;
        objc_sync_exit(self);
        
        return updated;
    }
    
    func updateAsync()
    {
        if (!self.isUpdating)
        {
            dispatch_async(self.queue, {
                if (self.updateVertices())
                {
                    self.glDraw();
                }
            });
            
            if (self.redrawEverything > 0 || self.menuOn)
            {
                self.glDraw();
            }
        }
        else
        {
            self.glDraw();
        }
    }
    
    // *********************************************** Misc. Methods ************************************************
    
    func setRedrawEverything()
    {
        self.redrawEverything = 2;
    }
    
    func setBounds()
    {
        if (self.plots.count == 0)
        {
            return;
        }
        
        var b = self.plots[0].plot.getBoundsWithPrecision(1.0)
        
        for (var i = 1; i < self.plots.count; i++)
        {
            b = NSUnionRect(b, self.plots[i].plot.getBoundsWithPrecision(1.0))
        }
        
        let total = fabs(b.origin.x) + fabs(b.origin.y) + fabs(b.size.width) + fabs(b.size.height);
        
        if (isnan(total) || total == CGFloat.infinity || total == -CGFloat.infinity || total == 0)
        {
            return;
        }
        
        self.xMin = Double(b.origin.x)
        self.xMax = Double(b.origin.x + b.size.width)
        self.yMin = Double(b.origin.y)
        self.yMax = Double(b.origin.y + b.size.height)
    }
    
    override func viewWillStartLiveResize()
    {
        self.setRedrawEverything()
    }
    
    override func viewDidEndLiveResize() {
        self.setRedrawEverything()
    }

    func addPlot(plot : JZWPlot)
    {
        self.plots.append(plot)
        self.maxPlotNameLength = Int(plot.name.characters.count > self.maxPlotNameLength ? plot.name.characters.count : self.maxPlotNameLength);
    }
    
    override var acceptsFirstResponder : Bool {
        return true
    }
    
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
        JZWGLGraph.removeGraph(self)
    }
    
    override var opaque : Bool {
        return true
    }

    func enableAutoScroll(sender : NSObject)
    {
        self.scrollMode = .AutoScrollNew
    }
    func disableAutoScroll(sender : NSObject)
    {
        self.scrollMode = .AutoScrollOff
    }

    func hidePlot(sender : NSMenuItem)
    {
        self.plots[sender.tag].hidden = true;
        self.setRedrawEverything()
    }
    
    func showPlot(sender : NSMenuItem)
    {
        self.plots[sender.tag].hidden = false;
        self.setRedrawEverything()
    }
    
    // *********************************************** Mouse Events ************************************************
    
    func handleTouches(event : NSEvent)
    {
        self.currentTouches =  event.touchesMatchingPhase(NSTouchPhase.Touching, inView:nil)
    }
    override func touchesBeganWithEvent(event : NSEvent)
    {
        self.handleTouches(event)
    }
    override func touchesEndedWithEvent(event: NSEvent)
    {
        self.handleTouches(event)
    }
    override func touchesCancelledWithEvent(event: NSEvent)
    {
        self.handleTouches(event)
    }
    
    override func mouseUp(theEvent: NSEvent)
    {
        let clickCount = theEvent.clickCount
        if (2 == clickCount && self.selectedPlot == NO_SELECTION)
        {
            self.setBounds()
        }
        
        self.mouseIsDown = false;
        
        if (self.selectedPlot == FLIP_AS)
        {
            if (self.scrollMode == .AutoScrollOff)
            {
            self.scrollMode = .AutoScrollNew;
            }
            else
            {
            self.scrollMode = .AutoScrollOff;
            }
        }
        else if (self.selectedPlot == FLIP_LEGEND)
        {
            self.legendOn = !self.legendOn;
        }
        else if (self.selectedPlot >= 0)
        {
            self.plots[self.selectedPlot].hidden = !self.plots[self.selectedPlot].hidden;
        }
        else
        {
            self.menuOn = false;
        }
        
        self.setRedrawEverything()
    }
    
    override func mouseDragged(theEvent: NSEvent)
    {
        let dx = Double(-theEvent.deltaX) / self.xScale;
        let dy = Double(theEvent.deltaY) / self.yScale;
        
        self.xMin += dx;
        self.xMax += dx;
        self.yMin += dy;
        self.yMax += dy;
        
        self.setRedrawEverything()
    }
    
    override func mouseDown(theEvent: NSEvent)
    {
        self.mouseIsDown = true
    }

    override func scrollWheel(theEvent: NSEvent)
    {
        let dx = Double(-theEvent.deltaX) / self.xScale * 2;
        let dy = Double(theEvent.deltaY) / self.yScale * 2;
        
        self.xMin += dx;
        self.xMax += dx;
        self.yMin += dy;
        self.yMax += dy;
        
        self.setRedrawEverything()
    }

    override func magnifyWithEvent(event: NSEvent)
    {
        let mag = event.magnification;
        
        let w = (self.xMax - self.xMin);
        let h = (self.yMax - self.yMin);
        
        let mouse = self.convertPoint(event.locationInWindow, fromView: nil)
        
        let touches = self.currentTouches.allObjects
        
        if (touches.count != 2)
        {
            return;
        }
        
        let t0 = touches[0]
        let t1 = touches[1]
        
        let pos0 = t0.normalizedPosition;
        let pos1 = t1.normalizedPosition;
        let dx = fabs(pos0.x - pos1.x);
        let dy = fabs(pos0.y - pos1.y);
        
        let hypotenuse = sqrt(dx * dx + dy * dy);
        
        let xmag = Double(mag * dx / hypotenuse)
        let ymag = Double(mag * dy / hypotenuse)
        
        let mxFrac = Double(mouse.x / self.frame.size.width)
        let myFrac = Double(mouse.y / self.frame.size.height)
        
        self.xMin += w * xmag * mxFrac / 2;
        self.xMax -= w * xmag * (1 - mxFrac) / 2;
        self.yMin += h * ymag * myFrac / 2;
        self.yMax -= h * ymag * (1 - myFrac) / 2;
        
        self.setRedrawEverything()
    }
    
    override func rightMouseDown(theEvent: NSEvent)
    {
    }
    override func rightMouseUp(theEvent: NSEvent) {
        self.menuOn = true;
    }
}

