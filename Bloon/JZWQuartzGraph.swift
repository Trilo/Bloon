//
//  JZWQuartzGraph.swift
//  Bloon
//
//  Created by Jacob Weiss on 2/5/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

/*
- (JZWQuartzGraph*)createStaticGraph
{
JZWQuartzGraph* graph = [[JZWQuartzGraph alloc] initWithTitle:self->title plots:self->plots transform:self->currentTransform xMin:self->xMin xMax:self->xMax yMin:self->yMin yMax:self->yMax xScale:self->xScale yScale:self->yScale xTranslate:self->xTranslate yTranslate:self->yTranslate backgroundColor:self->backgroundColor axisColor:self->axisColor axesOn:self->axesOn xNumTicks:self->xNumTicks yNumTicks:self->yNumTicks tickLength:self->tickLength axisWidth:self->axisWidth tickWidth:self->tickWidth gridOn:self->gridOn gridColor:self->gridColor gridWidth:self->gridWidth labelsOn:self->labelsOn labelColor:self->labelColor autoTickMarks:self->autoTickMarks];

return graph;
}
*/
import Cocoa

class JZWQuartzGraph: NSView
{
    let AUTOSCROLL_BUFFER : CGFloat = 0.025
    let LINE_STIPPLE_NUM = 4
    let NORMAL_STIPPLE_PATTERN = 0xFFFF
    let GRID_STIPPLE_PATTERN = 0xAAAA
    
    let TICK_LABEL_ADJUST_TOP : CGFloat = 5.0
    let TICK_LABEL_ADJUST_BOTTOM : CGFloat = 15.0
    let TICK_LABEL_ADJUST_LEFT : CGFloat = 5.0
    let TICK_LABEL_ADJUST_RIGHT : CGFloat = 5.0
    
    let X_TICK_LABEL_TOP_ADJUST : CGFloat = 5.0
    let X_TICK_LABEL_BOTTOM_ADJUST : CGFloat = -15.0
    let X_LABEL_SHIFT : CGFloat = 5.0
    let MAX_TICK_LABEL_LENGTH : CGFloat = 40.0
    let AUTO_TICK_WIDTH : CGFloat = 72.0
    let Y_AXIS_LABEL_LEFT_AD : CGFloat = 5.0

    
    let title : String
    let plots : [JZWPlot]
    let transform : NSAffineTransform
    
    let xMin : CGFloat
    let xMax : CGFloat
    let yMin : CGFloat
    let yMax : CGFloat
    
    let xScale : CGFloat
    let yScale : CGFloat
    let xTranslate : CGFloat
    let yTranslate : CGFloat
    
    let backgroundColor : NSColor
    let axisColor : NSColor
    let axesOn : Bool
    
    let xNumTicks : Int
    let yNumTicks : Int
    
    let tickLength : CGFloat
    let axisWidth : CGFloat
    let tickWidth : CGFloat
    
    let gridOn : Bool
    let gridColor : NSColor
    let gridWidth : CGFloat
    
    let labelsOn : Bool
    let labelColor : NSColor
    
    let autoTickMarks : Bool
    
    init(title : String, plots : [JZWPlot], transform : NSAffineTransform,
        xMin : CGFloat, xMax : CGFloat, yMin : CGFloat, yMax : CGFloat,
        xScale : CGFloat, yScale : CGFloat, xTranslate : CGFloat, yTranslate : CGFloat,
        backgroundColor : NSColor, axisColor : NSColor, axesOn : Bool,
        xNumTicks : Int, yNumTicks : Int, tickLength : CGFloat, axisWidth : CGFloat, tickWidth : CGFloat,
        gridOn : Bool, gridColor : NSColor, gridWidth : CGFloat,
        labelsOn : Bool, labelColor : NSColor, autoTickMarks : Bool)
    {
        self.title = title
        self.plots = plots
        self.transform = transform
        self.xMin = xMin
        self.xMax = xMax
        self.yMin = yMin
        self.yMax = yMax
        self.xScale = xScale
        self.yScale = yScale
        self.xTranslate = xTranslate
        self.yTranslate = yTranslate
        self.backgroundColor = backgroundColor
        self.axisColor = axisColor
        self.axesOn = axesOn
        self.xNumTicks = xNumTicks
        self.yNumTicks = yNumTicks
        self.tickLength = tickLength
        self.axisWidth = axisWidth
        self.tickWidth = tickWidth
        self.gridOn = gridOn
        self.gridColor = gridColor
        self.gridWidth = gridWidth
        self.labelsOn = labelsOn
        self.labelColor = labelColor
        self.autoTickMarks = autoTickMarks
        super.init(frame: NSMakeRect(0, 0, 0, 0))
        
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawRect(dirtyRect: NSRect)
    {
        super.drawRect(dirtyRect)

        self.backgroundColor.setFill()
        NSRectFill(self.bounds)
        
    
        // ******************************** Calculate Useful Values ***********************************
        
        let width = self.frame.size.width;
        let height = self.frame.size.height;
        
        let widthValue = self.xMax - self.xMin;
        let heightValue = self.yMax - self.yMin;
        
        
        var xAxis = (-self.yMin) / (heightValue) * height;
        var xAxisReal = xAxis;
        var xAxisLabelTop : Bool
        var yAxis = (-self.xMin) / (widthValue) * width;
        var yAxisReal = yAxis;
        var yAxisLabelRight : Bool
        
        var xOriginValue : CGFloat = 0;
        var yOriginValue : CGFloat = 0;
        
        if (xAxis < 0)
        {
            yOriginValue = self.yMin;
            xAxis = 0;
            xAxisLabelTop = true;
        }
        else if (xAxis > height)
        {
            yOriginValue = self.yMax;
            xAxis = height;
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
        else if (yAxis > width)
        {
            xOriginValue = self.xMax;
            yAxis = width;
            yAxisLabelRight = false;
        }
        else
        {
            yAxisLabelRight = self.xMax > -self.xMin;
        }
        
        var xNumTicksAdjusted = self.xNumTicks;
        
        if (self.autoTickMarks)
        {
            xNumTicksAdjusted = Int(width / AUTO_TICK_WIDTH - CGFloat(1.0))
        }
        
        let xTickValue = (self.xMax - self.xMin) / CGFloat(xNumTicksAdjusted)
        let yTickValue = (self.yMax - self.yMin) / CGFloat(self.yNumTicks)
        
        let xTickPixels = CGFloat(width) / CGFloat(xNumTicksAdjusted)
        let yTickPixels = CGFloat(height) / CGFloat(self.yNumTicks)
        
        let ticksValid = xTickPixels > 0 && yTickPixels > 0;
        
        let halfTick = self.tickLength / 2;
        
        let xTickStartValue = xOriginValue + xTickValue - fmod(xOriginValue, xTickValue);
        let xTickStartPixels = (xTickStartValue - xOriginValue) * self.xScale;
        
        let yTickStartValue = yOriginValue + yTickValue - fmod(yOriginValue, yTickValue);
        let yTickStartPixels = (yTickStartValue - yOriginValue) * self.yScale;
        
        // ******************************** Start Drawing ***********************************

        // ******************************** Draw The Grid ***********************************
        if (self.gridOn)
        {
            let gridPath = NSBezierPath()
            gridPath.lineWidth = self.gridWidth
            gridPath.setLineDash([5.0, 5.0], count: 2, phase: 0.0)
            self.gridColor.setStroke()
            
            for (var x = yAxis + xTickStartPixels; x < width; x += xTickPixels)
            {
                gridPath.moveToPoint(NSMakePoint(x, xAxisReal))
                gridPath.lineToPoint(NSMakePoint(x, 0))
                gridPath.moveToPoint(NSMakePoint(x, xAxisReal))
                gridPath.lineToPoint(NSMakePoint(x, height))
            }
            for (var x = yAxis + xTickStartPixels; x > 0; x -= xTickPixels)
            {
                gridPath.moveToPoint(NSMakePoint(x, xAxisReal))
                gridPath.lineToPoint(NSMakePoint(x, 0))
                gridPath.moveToPoint(NSMakePoint(x, xAxisReal))
                gridPath.lineToPoint(NSMakePoint(x, height))
            }
            for (var y = xAxis + yTickStartPixels; y < height; y += yTickPixels)
            {
                gridPath.moveToPoint(NSMakePoint(yAxisReal, y))
                gridPath.lineToPoint(NSMakePoint(0, y))
                gridPath.moveToPoint(NSMakePoint(yAxisReal, y))
                gridPath.lineToPoint(NSMakePoint(width, y))
            }
            for (var y = xAxis + yTickStartPixels; y > 0; y -= yTickPixels)
            {
                gridPath.moveToPoint(NSMakePoint(yAxisReal, y))
                gridPath.lineToPoint(NSMakePoint(0, y))
                gridPath.moveToPoint(NSMakePoint(yAxisReal, y))
                gridPath.lineToPoint(NSMakePoint(width, y))
            }
            
            gridPath.stroke()
        }
        
        // ******************************** Draw The Axes ***********************************
        if (self.axesOn)
        {
            let axisPath = NSBezierPath()
            axisPath.lineWidth = self.axisWidth
            self.axisColor.setStroke()

            axisPath.moveToPoint(NSMakePoint(0, xAxis))
            axisPath.lineToPoint(NSMakePoint(width, xAxis))
            axisPath.moveToPoint(NSMakePoint(yAxis, 0))
            axisPath.lineToPoint(NSMakePoint(yAxis, height))

            axisPath.stroke()
            
            // ******************************** Draw The Tick Marks ***********************************
            
            let tickPath = NSBezierPath()
            tickPath.lineWidth = self.tickWidth
            
            for (var x = yAxis + xTickStartPixels; x < width; x += xTickPixels)
            {
                tickPath.moveToPoint(NSMakePoint(x, xAxis + halfTick))
                tickPath.lineToPoint(NSMakePoint(x, xAxis - halfTick))
            }
            for (var x = yAxis + xTickStartPixels; x > 0; x -= xTickPixels)
            {
                tickPath.moveToPoint(NSMakePoint(x, xAxis + halfTick))
                tickPath.lineToPoint(NSMakePoint(x, xAxis - halfTick))
            }
            for (var y = xAxis + yTickStartPixels; y < height; y += yTickPixels)
            {
                tickPath.moveToPoint(NSMakePoint(yAxis + halfTick, y))
                tickPath.lineToPoint(NSMakePoint(yAxis - halfTick, y))
            }
            for (var y = xAxis + yTickStartPixels; y > 0; y -= yTickPixels)
            {
                tickPath.moveToPoint(NSMakePoint(yAxis + halfTick, y))
                tickPath.lineToPoint(NSMakePoint(yAxis - halfTick, y))
            }
            
            tickPath.stroke()
        }
        

        // ******************************** Draw The Data Points ***********************************
        
        
        for plot in self.plots
        {
            Swift.print("hello")
            if (plot.hidden)
            {
                continue;
            }
            
            let path = plot.constructBezierPathWithTransform(self.transform)
            plot.color.setStroke()
            path.stroke()
        }
        
        /*

        // ******************************** Draw Axis Scale Labels ***********************************
        
        if (ticksValid && self.labelsOn)
        {
            CGFloat topBottom = xAxisLabelTop   ? (halfTick + TICK_LABEL_ADJUST_TOP)  : -(halfTick + TICK_LABEL_ADJUST_BOTTOM);
            CGFloat leftRight = yAxisLabelRight ? (halfTick + TICK_LABEL_ADJUST_LEFT) : -(halfTick - TICK_LABEL_ADJUST_RIGHT);
            CGFloat yTopBottom = xAxisLabelTop ? X_TICK_LABEL_TOP_ADJUST : X_TICK_LABEL_BOTTOM_ADJUST;
            CGFloat xLabelShift = X_LABEL_SHIFT;
            
            char valueString[MAX_TICK_LABEL_LENGTH];
            
            for (CGFloat x = yAxis + xTickStartPixels; x < width; x += xTickPixels)
            {
                CGFloat value = (x - yAxis) / self.xScale + xOriginValue;
                
                if (fabs(value) < xTickValue / 2)
                {
                    continue;
                }
                
                sprintf(valueString, "%.2E", value);
                
                drawText(valueString, x + xLabelShift, xAxis + topBottom, self.axisLabelFont, self.labelColor);
            }
            for (CGFloat x = yAxis + xTickStartPixels; x > 0; x -= xTickPixels)
            {
                CGFloat value = (x - yAxis) / self.xScale + xOriginValue;
                
                if (fabs(value) < xTickValue / 2)
                {
                    continue;
                }
                
                sprintf(valueString, "%.2E", value);
                
                drawText(valueString, x + xLabelShift, xAxis + topBottom, self.axisLabelFont, self.labelColor);
            }
            for (CGFloat y = xAxis + yTickStartPixels; y < height; y += yTickPixels)
            {
                CGFloat value = (y - xAxis) / self.yScale + yOriginValue;
                
                if (fabs(value) < yTickValue / 2)
                {
                    continue;
                }
                
                sprintf(valueString, "%.2E", value);
                
                CGFloat adj = 0;
                
                if (!yAxisLabelRight)
                {
                    adj = STR_SMALL_FONT_WIDTH_PIXELS(valueString) + Y_AXIS_LABEL_LEFT_ADJ;
                }
                
                drawText(valueString, yAxis + leftRight - adj, y + yTopBottom, self.axisLabelFont, self.labelColor);
            }
            for (CGFloat y = xAxis + yTickStartPixels; y > 0; y -= yTickPixels)
            {
                CGFloat value = (y - xAxis) / self.yScale + yOriginValue;
                
                if (fabs(value) < yTickValue / 2)
                {
                    continue;
                }
                
                sprintf(valueString, "%.2E", value);
                
                CGFloat adj = 0;
                
                if (!yAxisLabelRight)
                {
                    adj = STR_SMALL_FONT_WIDTH_PIXELS(valueString) + Y_AXIS_LABEL_LEFT_ADJ;
                }
                
                drawText(valueString, yAxis + leftRight - adj, y + yTopBottom, self.axisLabelFont, self.labelColor);
            }
        }
        
        // ******************************** Draw Title ***********************************
        
        const char* ctitle = [self.title cStringUsingEncoding:NSASCIIStringEncoding];
        unsigned long titleLength = STR_LARGE_FONT_WIDTH_PIXELS(ctitle);
        
        glColor3f(self.backgroundColor.redComponent, self.backgroundColor.greenComponent, self.backgroundColor.blueComponent);
        glRectf(self.bounds.size.width / 2 - titleLength / 2 - 2, height - 3,
        self.bounds.size.width / 2 + titleLength / 2 + 2, height - LARGE_FONT_LINE_HEIGHT - 5);
        
        drawText((char*)ctitle, self.bounds.size.width / 2 - titleLength / 2, self.bounds.size.height - LARGE_FONT_LINE_HEIGHT, self.titleFont, self.labelColor);
        
    }
    */
    }
}

