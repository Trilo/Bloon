//
//  NSGLGraph.m
//  Bloon
//
//  Created by Jacob Weiss on 8/15/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

#import "JZWGLGraph.h"
#include <OpenGL/gl.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import <GLUT/GLUT.h>
#import "Bloon-Swift.h"
#import "JZWVertexArray.h"

#define FRAMERATE (30)
#define MAX_POINTS (-1)

#define NO_SELECTION -2
#define FLIP_AS -1
#define FLIP_LEGEND -3

@interface JZWGLGraph ()

- (void)setTransform;

@end

@implementation JZWGLGraph
{
    NSString* title;
    
    NSMutableArray* plots;
    NSAffineTransform* currentTransform;
    
    double xMin;
    double xMax;
    double yMin;
    double yMax;
    
    double xScale;
    double yScale;
    double xTranslate;
    double yTranslate;
    
    AutoScrollMode scrollMode;
    
    NSColor* backgroundColor;
    NSColor* axisColor;
    BOOL axesOn;
    
    int xNumTicks;
    int yNumTicks;
    
    CGFloat tickLength;
    CGFloat axisWidth;
    CGFloat tickWidth;
    
    BOOL gridOn;
    NSColor* gridColor;
    CGFloat gridWidth;
    
    BOOL labelsOn;
    NSColor* labelColor;
    
    NSColor* unselectedColor;
    NSColor* selectedColor;
    
    dispatch_queue_t queue;
    BOOL isUpdating;
    
    void* axisLabelFont;
    void* titleFont;
    
    BOOL autoTickMarks;
    
    NSSet* currentTouches;
    BOOL mouseIsDown;
    
    int redrawEverything;
    
    BOOL menuOn;
    BOOL legendOn;
    int maxPlotNameLength;
    int selectedPlot;
    
    BOOL isFullScreen;
    
    BOOL forceRedraw;
    
    BOOL shouldStopGraphing;
    
    double boundsPrecision;
}

// *********************************************** Class Methods ************************************************

+ (dispatch_queue_t)plotUpdateQueue
{
    static dispatch_queue_t queue = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("Plot Update Queue", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return queue;

}

+ (NSTimer*)getUpdateTimer
{
    static NSTimer* timer = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        timer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / FRAMERATE) target:[JZWGLGraph class] selector:@selector(updateAllGraphs) userInfo:nil repeats:true];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSEventTrackingRunLoopMode];
    });
    
    return timer;
}

+ (NSMutableArray*)getAllGraphs
{
    static dispatch_once_t once;
    static NSMutableArray* allGraphs = nil;
    
    dispatch_once(&once, ^{
        allGraphs = [[NSMutableArray alloc] init];
        [JZWGLGraph getUpdateTimer];
    });
    
    return allGraphs;
}

+ (void)updateAllGraphs
{
    objc_sync_enter([JZWGLGraph class]);
    NSMutableArray* allGraphs = [JZWGLGraph getAllGraphs];
    
    for (JZWGLGraph* g in allGraphs)
    {
        [g updateAsync];
    }
    
    objc_sync_exit([JZWGLGraph class]);
}

+ (void)removeGraph:(JZWGLGraph*)graph
{
    objc_sync_enter(graph);
    objc_sync_enter([JZWGLGraph class]);
    
    [graph stop];
    
    dispatch_barrier_sync(graph->queue, ^{
        NSMutableArray* allGraphs = [JZWGLGraph getAllGraphs];
        [allGraphs removeObject:graph];
        [graph->plots removeAllObjects];
    });
    
    objc_sync_exit([JZWGLGraph class]);
    objc_sync_exit(graph);
}

// *********************************************** Initializer Methods ************************************************

- (id)initWithTitle:(NSString*)graphTitle frame:(NSRect)frameRect
{
    NSOpenGLPixelFormatAttribute attribs[] =
    {
        NSOpenGLPFAAccelerated,
        NSOpenGLPFAColorSize, (NSOpenGLPixelFormatAttribute) 32,
        NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute) 23,
        (NSOpenGLPixelFormatAttribute) 0
    };
    
    NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
    
    self = [super initWithFrame:frameRect pixelFormat:pixelFormat];
    
    if (self == NULL)
    {
        NSLog(@"Could not initialise self");
        return NULL;
    }
    
    self->title = graphTitle;
    
    self.translatesAutoresizingMaskIntoConstraints = false;
    self->plots = [[NSMutableArray alloc] init];
    self->currentTransform = [[NSAffineTransform alloc] init];
    
    self->xMin = -100;
    self->xMax = 100;
    self->yMin = -100;
    self->yMax = 100;
    
    self->xScale = 1;
    self->yScale = 1;
    self->xTranslate = 0;
    self->yTranslate = 0;
    
    self->scrollMode = AutoScrollOff;
    
    self->backgroundColor = [NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:1];
    
    self->axesOn = true;
    self->axisColor = [NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:1];
    
    self->xNumTicks = 10;
    self->yNumTicks = 10;
    
    self->tickLength = 20;
    self->tickWidth = 3;
    self->axisWidth = 5;
    
    self->gridColor = [NSColor colorWithCalibratedRed:0.3 green:0.3 blue:0.3 alpha:1];
    self->gridOn = true;
    self->gridWidth = 1;
    
    self->labelsOn = true;
    self->labelColor = [NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:1];
    
    self->queue = dispatch_queue_create([graphTitle cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    self->isUpdating = false;
    
    self->axisLabelFont = GLUT_BITMAP_8_BY_13;
    self->titleFont = GLUT_BITMAP_9_BY_15;
    
    self->autoTickMarks = true;

    [[JZWGLGraph getAllGraphs] addObject:self];
    
    self->currentTouches = [[NSMutableSet alloc] init];
    self->mouseIsDown = false;

    self.acceptsTouchEvents = YES;
    
    self.layer.drawsAsynchronously = true;
    
    self->redrawEverything = 4;
    
    self->selectedPlot = NO_SELECTION;
    self->selectedColor = [[NSColor grayColor] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    self->unselectedColor = [[NSColor whiteColor] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    self->maxPlotNameLength = 0;
    
    self->forceRedraw = false;
    
    self->shouldStopGraphing = false;
    
    self->boundsPrecision = 0.99;
    
    return self;
}

- (id)initWithTitle:(NSString*)graphTitle
{
    self = [self initWithTitle:graphTitle frame:NSMakeRect(0, 0, 0, 0)];
    
    return self;
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [self initWithTitle:@"Graph" frame:frameRect];
    
    return self;
}

- (void)setXMin:(double)_xMin xMax:(double)_xMax xTicks:(int)_xTicks
           yMin:(double)_yMin yMax:(double)_yMax yTicks:(int)_yTicks
    showsLabels:(BOOL)_labels showsGrid:(BOOL)_grid autoTickMarks:(BOOL)_autoTicks showsAxis:(BOOL)_showsAxis scrollMode:(AutoScrollMode)_scrollMode
     labelColor:(NSColor*)_labelColor gridColor:(NSColor*)_gridColor bgColor:(NSColor*)_bgColor axisColor:(NSColor*)_axisColor;
{
    self->xMin = _xMin;
    self->xMax = _xMax;
    self->xNumTicks = _xTicks;
    self->yMin = _yMin;
    self->yMax = _yMax;
    self->yNumTicks = _yTicks;
    self->labelsOn = _labels;
    self->gridOn = _grid;
    self->autoTickMarks = _autoTicks;
    self->labelColor = _labelColor;
    self->gridColor = _gridColor;
    self->backgroundColor = _bgColor;
    self->axesOn = _showsAxis;
    self->axisColor = _axisColor;
    self->scrollMode = _scrollMode;
}

// *********************************************** Drawing Methods ************************************************

void drawText(char* string, CGFloat x, CGFloat y, void* font, NSColor* color)
{
    NSColor* c = color;
    glColor3f(c.redComponent, c.greenComponent, c.blueComponent);
    
    glRasterPos2i(x, y);
    
    while (*string)
    {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            glutBitmapCharacter(font, *string++);
        #pragma clang diagnostic pop
    }
}

#define AUTOSCROLL_BUFFER (0.025)
#define LINE_STIPPLE_NUM (4)
#define NORMAL_STIPPLE_PATTERN (0xFFFF)
#define GRID_STIPPLE_PATTERN (0xAAAA)

#define TICK_LABEL_ADJUST_TOP (5)
#define TICK_LABEL_ADJUST_BOTTOM (15)
#define TICK_LABEL_ADJUST_LEFT (5)
#define TICK_LABEL_ADJUST_RIGHT (5)

#define X_TICK_LABEL_TOP_ADJUST (5)
#define X_TICK_LABEL_BOTTOM_ADJUST (-15)
#define X_LABEL_SHIFT (5)
#define MAX_TICK_LABEL_LENGTH (40)
#define AUTO_TICK_WIDTH (72)
#define Y_AXIS_LABEL_LEFT_ADJ (5)

#define LARGE_FONT_CHAR_WIDTH (9)
#define SMALL_FONT_CHAR_WIDTH (8)
#define STR_LARGE_FONT_WIDTH_PIXELS(str) (strlen(str) * LARGE_FONT_CHAR_WIDTH)
#define STR_SMALL_FONT_WIDTH_PIXELS(str) (strlen(str) * SMALL_FONT_CHAR_WIDTH)

#define LARGE_FONT_LINE_HEIGHT (16)
#define MENU_LEGEND_BORDER (5)
#define MENU_WIDTH (330)
#define MENU_COLOR_WIDTH (100)
#define MENU_NO_NUMBER_WIDTH (100)

#define LEGEND_COLOR_X1_ADJ (2)
#define LEGEND_COLOR_Y1_ADJ (-2)
#define LEGEND_COLOR_X2_ADJ (31)
#define LEGEND_COLOR_Y2_ADJ (11)
#define MENU_COLOR_X2_ADJ (-2)
#define MENU_MOUSE_ADJ (-5)

#define LEGEND_COLOR_BOX_WIDTH (40)

#define SELECTED_POINT_INCREASE (10)

void glDraw(JZWGLGraph* self)
{
    if (!self)
    {
        NSLog(@"Graph is Null?");
        return;
    }
    objc_sync_enter([self openGLContext]);
    [[self openGLContext] lock];
    [[self openGLContext] makeCurrentContext];
    [self setupGL];
    
    // ******************************** Determine If Full Redraw Required ***********************************
    
    BOOL shouldRedrawEverything = self->redrawEverything > 0 || self.inLiveResize || self->menuOn || self->forceRedraw;
    
    if (self->redrawEverything > 0)
    {
        self->redrawEverything--;
    }
    
    // ******************************** Determine Scroll Mode ***********************************
    
    switch (self->scrollMode)
    {
        case AutoScrollOff:
            break;
        case AutoScrollNew:
        case AutoScrollTime:
            if ([self->plots count] > 0)
            {
                NSRect bounds = [((JZWPlot*)[self->plots objectAtIndex:0]).plot getBounds];
                for (JZWPlot* p in self->plots)
                {
                    bounds = NSUnionRect(bounds, [p.plot getBounds]);
                }
                CGFloat rightMost = bounds.origin.x + bounds.size.width;
                CGFloat shift = (self->xMax - self->xMin) * AUTOSCROLL_BUFFER;
                if (rightMost > self->xMax - shift)
                {
                    self->xMin += rightMost - self->xMax + shift;
                    self->xMax = rightMost + shift;
                    shouldRedrawEverything = true;
                }
            }
            break;
    }
    
    // ******************************** Calculate Useful Values ***********************************

    [self setTransform];
    
    NSColor* c = nil;
    
    if (shouldRedrawEverything)
    {
        c = self->backgroundColor;
        
        glClearColor(c.redComponent, c.greenComponent, c.blueComponent, 1);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    
    // The width and height of the window in pixels
    CGFloat width = self.frame.size.width;
    CGFloat height = self.frame.size.height;
    
    // The width and height of the window in units
    CGFloat widthValue = self->xMax - self->xMin;
    CGFloat heightValue = self->yMax - self->yMin;
    
    // Determine the location of the axes
    CGFloat xAxis = (-self->yMin) / (heightValue) * height;
    CGFloat xAxisReal = xAxis;
    BOOL xAxisLabelTop;
    CGFloat yAxis = (-self->xMin) / (widthValue) * width;
    CGFloat yAxisReal = yAxis;
    BOOL yAxisLabelRight;
    
    CGFloat xOriginValue = 0;
    CGFloat yOriginValue = 0;
    
    if (xAxis < 0)
    {
        yOriginValue = self->yMin;
        xAxis = 0;
        xAxisLabelTop = true;
    }
    else if (xAxis > height)
    {
        yOriginValue = self->yMax;
        xAxis = height;
        xAxisLabelTop = false;
    }
    else
    {
        xAxisLabelTop = self->yMax > -self->yMin;
    }
    
    if (yAxis < 0)
    {
        xOriginValue = self->xMin;
        yAxis = 0;
        yAxisLabelRight = true;
    }
    else if (yAxis > width)
    {
        xOriginValue = self->xMax;
        yAxis = width;
        yAxisLabelRight = false;
    }
    else
    {
        yAxisLabelRight = self->xMax > -self->xMin;
    }
    
    CGFloat halfTick = self->tickLength / 2;

    // Determine the locations of the tick marks
    double minPixelsPerTick = AUTO_TICK_WIDTH;
    
    double xminUnitsPerTick = minPixelsPerTick * widthValue / width;
    double yminUnitsPerTick = minPixelsPerTick * heightValue / height;

    double xn = floor(ceil(log2(widthValue))  - log2(xminUnitsPerTick));
    double yn = floor(ceil(log2(heightValue)) - log2(yminUnitsPerTick));

    double xunitsPerTick = pow(0.5, floor(log(widthValue)/log(0.5)) + xn);
    double yunitsPerTick = pow(0.5, floor(log(heightValue)/log(0.5)) + yn);

    if (log2(widthValue) == (int)(log2(widthValue)))
    {
        xunitsPerTick *= 2;
    }
    if (log2(heightValue) == (int)(log2(heightValue)))
    {
        yunitsPerTick *= 2;
    }

    double xpixelsPerTick = xunitsPerTick * width / widthValue;
    double ypixelsPerTick = yunitsPerTick * height / heightValue;

    double xTickPixels = xpixelsPerTick;
    double xTickValue = xunitsPerTick;
    double xTickStartValue = xOriginValue + xTickValue - fmod(xOriginValue, xTickValue);
    double xTickStartPixels = (xTickStartValue - xOriginValue) * self->xScale;

    double yTickPixels = ypixelsPerTick;
    double yTickValue = yunitsPerTick;
    double yTickStartValue = yOriginValue + yTickValue - fmod(yOriginValue, yTickValue);
    double yTickStartPixels = (yTickStartValue - yOriginValue) * self->yScale;
    
    BOOL ticksValid = xTickPixels > 0 && yTickPixels > 0;
    
    // ******************************** Start Drawing ***********************************
    
    if (ticksValid && shouldRedrawEverything)
    {
        // ******************************** Draw The Grid ***********************************
        if (self->gridOn)
        {
            NSColor* gc = self->gridColor;
            glLineWidth(self->gridWidth);
            glColor3f(gc.redComponent, gc.greenComponent, gc.blueComponent);
            glLineStipple(LINE_STIPPLE_NUM, GRID_STIPPLE_PATTERN);
            
            glBegin(GL_LINES);
            for (CGFloat x = yAxis + xTickStartPixels; x < width; x += xTickPixels)
            {
                glVertex2d(x, xAxisReal);
                glVertex2d(x, 0);
                glVertex2d(x, xAxisReal);
                glVertex2d(x, height);
            }
            for (CGFloat x = yAxis + xTickStartPixels; x > 0; x -= xTickPixels)
            {
                glVertex2d(x, xAxisReal);
                glVertex2d(x, 0);
                glVertex2d(x, xAxisReal);
                glVertex2d(x, height);
            }
            for (CGFloat y = xAxis + yTickStartPixels; y < height; y += yTickPixels)
            {
                glVertex2d(yAxisReal, y);
                glVertex2d(0, y);
                glVertex2d(yAxisReal, y);
                glVertex2d(width, y);
            }
            for (CGFloat y = xAxis + yTickStartPixels; y > 0; y -= yTickPixels)
            {
                glVertex2d(yAxisReal, y);
                glVertex2d(0, y);
                glVertex2d(yAxisReal, y);
                glVertex2d(width, y);
            }
            glEnd();
            
            glLineStipple(LINE_STIPPLE_NUM, NORMAL_STIPPLE_PATTERN);
        }
        
        // ******************************** Draw The Axes ***********************************
        if (self->axesOn)
        {
            glLineWidth(self->axisWidth);
            c = self->axisColor;
            glColor3f(c.redComponent, c.greenComponent, c.blueComponent);
            
            glBegin(GL_LINES);
            glVertex2d(0, xAxis);
            glVertex2d(width, xAxis);
            glVertex2d(yAxis, 0);
            glVertex2d(yAxis, height);
            glEnd();
            
            // ******************************** Draw The Tick Marks ***********************************
            glLineWidth(self->tickWidth);
            glBegin(GL_LINES);
            for (CGFloat x = yAxis + xTickStartPixels; x < width; x += xTickPixels)
            {
                glVertex2d(x, xAxis + halfTick);
                glVertex2d(x, xAxis - halfTick);
            }
            for (CGFloat x = yAxis + xTickStartPixels; x > 0; x -= xTickPixels)
            {
                glVertex2d(x, xAxis + halfTick);
                glVertex2d(x, xAxis - halfTick);
            }
            for (CGFloat y = xAxis + yTickStartPixels; y < height; y += yTickPixels)
            {
                glVertex2d(yAxis + halfTick, y);
                glVertex2d(yAxis - halfTick, y);
            }
            for (CGFloat y = xAxis + yTickStartPixels; y > 0; y -= yTickPixels)
            {
                glVertex2d(yAxis + halfTick, y);
                glVertex2d(yAxis - halfTick, y);
            }
            glEnd();
        }
    }
    
    // ******************************** Draw The Data Points ***********************************
    
    NSAffineTransformStruct transform = [self->currentTransform transformStruct];
    
    GLfloat mtrx[] = {
        transform.m11, transform.m12, 0, 0,
        transform.m21, transform.m22, 0, 0,
        0,             0, 1, 0,
        transform.tX,  transform.tY, 0, 1
    };
    
    glLoadMatrixf(mtrx);
    glEnableClientState(GL_VERTEX_ARRAY);
    
    for (JZWPlot* plot in self->plots)
    {
        if (plot.hidden)
        {
            continue;
        }
        
        JZWVertexArray* va = plot.plot;
        
        
        if (shouldRedrawEverything)
        {
            [va getVertices:^(GLfloat *verts, int nv) {
                glPointSize(plot.pointDim);
                glColor3f(plot.color.redComponent, plot.color.greenComponent, plot.color.blueComponent);
                
                glVertexPointer(2, GL_FLOAT, 0, verts);
                glDrawArrays(GL_POINTS, 0, nv);
            }];
        }
        else
        {
            [va getNewVertices:^(GLfloat *verts, int nv) {
                glPointSize(plot.pointDim);
                glColor3f(plot.color.redComponent, plot.color.greenComponent, plot.color.blueComponent);
                
                glVertexPointer(2, GL_FLOAT, 0, verts);
                glDrawArrays(GL_POINTS, 0, nv);
            }];
        }
    }
    
    glDisableClientState(GL_VERTEX_ARRAY);
    glLoadIdentity();
    
    // ******************************** Draw Axis Scale Labels ***********************************
    
    if (ticksValid && self->labelsOn)
    {
        CGFloat topBottom = xAxisLabelTop   ? (halfTick + TICK_LABEL_ADJUST_TOP)  : -(halfTick + TICK_LABEL_ADJUST_BOTTOM);
        CGFloat leftRight = yAxisLabelRight ? (halfTick + TICK_LABEL_ADJUST_LEFT) : -(halfTick - TICK_LABEL_ADJUST_RIGHT);
        CGFloat yTopBottom = xAxisLabelTop ? X_TICK_LABEL_TOP_ADJUST : X_TICK_LABEL_BOTTOM_ADJUST;
        CGFloat xLabelShift = X_LABEL_SHIFT;
        
        char valueString[MAX_TICK_LABEL_LENGTH];
        
        for (CGFloat x = yAxis + xTickStartPixels; x < width; x += xTickPixels)
        {
            CGFloat value = (x - yAxis) / self->xScale + xOriginValue; // Calculate the value of the tick
            value = floor((value / xunitsPerTick) + 0.5) * xunitsPerTick; // Round it to the nearest real tick value
            
            if (fabs(value) < xTickValue / 2)
            {
                continue;
            }
            
            sprintf(valueString, "%.2E", value);
            
            drawText(valueString, x + xLabelShift, xAxis + topBottom, self->axisLabelFont, self->labelColor);
        }
        for (CGFloat x = yAxis + xTickStartPixels; x > 0; x -= xTickPixels)
        {
            CGFloat value = (x - yAxis) / self->xScale + xOriginValue;
            value = floor((value / xunitsPerTick) + 0.5) * xunitsPerTick;

            if (fabs(value) < xTickValue / 2)
            {
                continue;
            }
            
            sprintf(valueString, "%.2E", value);
            
            drawText(valueString, x + xLabelShift, xAxis + topBottom, self->axisLabelFont, self->labelColor);
        }
        for (CGFloat y = xAxis + yTickStartPixels; y < height; y += yTickPixels)
        {
            CGFloat value = (y - xAxis) / self->yScale + yOriginValue;
            value = floor((value / yunitsPerTick) + 0.5) * yunitsPerTick;

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
            
            drawText(valueString, yAxis + leftRight - adj, y + yTopBottom, self->axisLabelFont, self->labelColor);
        }
        for (CGFloat y = xAxis + yTickStartPixels; y > 0; y -= yTickPixels)
        {
            CGFloat value = (y - xAxis) / self->yScale + yOriginValue;
            value = floor((value / yunitsPerTick) + 0.5) * yunitsPerTick;

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
            
            drawText(valueString, yAxis + leftRight - adj, y + yTopBottom, self->axisLabelFont, self->labelColor);
        }
    }
    
    // ******************************** Draw Title ***********************************
    
    const char* ctitle = [self->title cStringUsingEncoding:NSASCIIStringEncoding];
    unsigned long titleLength = STR_LARGE_FONT_WIDTH_PIXELS(ctitle);
    
    glColor3f(self->backgroundColor.redComponent, self->backgroundColor.greenComponent, self->backgroundColor.blueComponent);
    glRectf(self.bounds.size.width / 2 - titleLength / 2 - 2, height - 3,
            self.bounds.size.width / 2 + titleLength / 2 + 2, height - LARGE_FONT_LINE_HEIGHT - 5);
    
    drawText((char*)ctitle, self.bounds.size.width / 2 - titleLength / 2, self.bounds.size.height - LARGE_FONT_LINE_HEIGHT, self->titleFont, self->labelColor);
    
    // ******************************** Draw Legend ***********************************
    
    if (self->legendOn)
    {
        int height = (int)(LARGE_FONT_LINE_HEIGHT * [self->plots count] + 6);
        int top = self.bounds.size.height;
        int width = self->maxPlotNameLength * LARGE_FONT_CHAR_WIDTH + LEGEND_COLOR_BOX_WIDTH;
        
        glColor3f(1, 1, 1);
        glRectf(0, top, width + MENU_LEGEND_BORDER, top - (height + MENU_LEGEND_BORDER));
        glColor3f(0, 0, 0);
        glRectf(MENU_LEGEND_BORDER, top - MENU_LEGEND_BORDER, width, top - height);
        
        int x = MENU_LEGEND_BORDER + 2;
        int y = top - (LARGE_FONT_LINE_HEIGHT + 2);
        
        for (JZWPlot* plot in self->plots)
        {
            char* name = (char*)[plot.name cStringUsingEncoding:NSUTF8StringEncoding];
            drawText(name, x + LEGEND_COLOR_X2_ADJ + 1, y, self->titleFont, self->unselectedColor);
            glColor3f(plot.color.redComponent, plot.color.greenComponent, plot.color.blueComponent);
            
            glRectf(x,                       y + LEGEND_COLOR_Y1_ADJ,
                    x + LEGEND_COLOR_X2_ADJ, y + LEGEND_COLOR_Y2_ADJ);
            y -= LARGE_FONT_LINE_HEIGHT;
        }
    }
    
    // ******************************** Draw Menu ***********************************
    
    if (self->menuOn)
    {
        NSPoint mouseGlobal = [NSEvent mouseLocation];
        NSRect windowLocation = [[self window] convertRectFromScreen:NSMakeRect(mouseGlobal.x, mouseGlobal.y, 0, 0)];
        NSPoint mouse = [self convertPoint: windowLocation.origin fromView: nil];

        //*************************** Highlight Closest Point
        
        NSPoint* points = calloc([self->plots count], sizeof(NSPoint));
        int pointIndex = 0;
        
        for (JZWPlot* plot in self->plots)
        {
            if (!plot.hidden)
            {
                NSPoint rawPoint = [[plot plot] closestVertexToPoint:mouse inTransform:self->currentTransform];
                points[pointIndex] = rawPoint;
                NSPoint p = [self->currentTransform transformPoint:rawPoint];
                
                glPointSize(plot.pointDim + SELECTED_POINT_INCREASE * 2);
                glColor3f(self->backgroundColor.redComponent, self->backgroundColor.greenComponent, self->backgroundColor.blueComponent);
                glBegin( GL_POINTS );
                glVertex2f(p.x, p.y);
                glEnd();
                
                glPointSize(plot.pointDim + SELECTED_POINT_INCREASE);
                glColor3f(plot.color.redComponent, plot.color.greenComponent, plot.color.blueComponent);
                glBegin( GL_POINTS );
                glVertex2f(p.x, p.y);
                glEnd();
                
                glPointSize(plot.pointDim);
                glColor3f(self->backgroundColor.redComponent, self->backgroundColor.greenComponent, self->backgroundColor.blueComponent);
                glBegin( GL_POINTS );
                glVertex2f(p.x, p.y);
                glEnd();
            }
            pointIndex++;
        }
        
        //*************************** Draw Menu
        
        unsigned long height = LARGE_FONT_LINE_HEIGHT * (2 + [self->plots count]) + 6;
        glColor3f(1, 1, 1);
        glRectf(0, 0, MENU_WIDTH + MENU_LEGEND_BORDER, height + MENU_LEGEND_BORDER);
        glColor3f(0, 0, 0);
        glRectf(MENU_LEGEND_BORDER, MENU_LEGEND_BORDER, MENU_WIDTH, height);
        
        int x = MENU_LEGEND_BORDER + 2;
        int y = MENU_LEGEND_BORDER + 4;
        
        if (NSPointInRect(mouse, self.bounds))
        {
            self->selectedPlot = NO_SELECTION;

            NSColor* c = self->unselectedColor;
            if (NSPointInRect(mouse, NSMakeRect(x, y + MENU_MOUSE_ADJ, MENU_WIDTH - MENU_LEGEND_BORDER, LARGE_FONT_LINE_HEIGHT)))
            {
                c = self->selectedColor;
                self->selectedPlot = FLIP_AS;
            }

            if (self->scrollMode == AutoScrollOff)
            {
                drawText("Enable AS", x, y, self->titleFont, c);
            }
            else
            {
                drawText("Disable AS", x, y, self->titleFont, c);
            }
            
            y += LARGE_FONT_LINE_HEIGHT;
            
            c = self->unselectedColor;
            if (NSPointInRect(mouse, NSMakeRect(x, y + MENU_MOUSE_ADJ, MENU_WIDTH - MENU_LEGEND_BORDER, LARGE_FONT_LINE_HEIGHT)))
            {
                c = self->selectedColor;
                self->selectedPlot = FLIP_LEGEND;
            }
            if (self->legendOn)
            {
                drawText("Legend Off", x, y, self->titleFont, c);
            }
            else
            {
                drawText("Legend On", x, y, self->titleFont, c);
            }
            
            int i = 0;
            for (JZWPlot* plot in self->plots)
            {
                y += LARGE_FONT_LINE_HEIGHT;
                
                NSColor* c = self->unselectedColor;
                if (NSPointInRect(mouse, NSMakeRect(x, y + MENU_MOUSE_ADJ, MENU_WIDTH - MENU_LEGEND_BORDER, LARGE_FONT_LINE_HEIGHT)))
                {
                    c = self->selectedColor;
                    self->selectedPlot = i;
                }
                
                if (plot.hidden)
                {
                    drawText("Show", x, y, self->titleFont, c);
                }
                else
                {
                    drawText("Hide", x, y, self->titleFont, c);
                }
                
                glColor3f(plot.color.redComponent, plot.color.greenComponent, plot.color.blueComponent);
                glRectf(x + LEGEND_COLOR_BOX_WIDTH,      y + LEGEND_COLOR_Y1_ADJ,
                        MENU_COLOR_WIDTH + MENU_COLOR_X2_ADJ,  y + LEGEND_COLOR_Y2_ADJ);
                
                if (!plot.hidden)
                {
                    char valueString[MAX_TICK_LABEL_LENGTH];
                    sprintf(valueString, "(%.5E, %.5E)", points[i].x, points[i].y);
                    drawText(valueString, 100, y + 1, self->axisLabelFont, c);
                }
                
                i++;
            }
        }
        else
        {
            self->menuOn = false;
            [self setRedrawEverything];
        }
        
        free(points);
    }

    //***************************** Draw white border
    
    glLineWidth(1);
    glColor3f(1.0, 1.0, 1.0);
    
    glBegin(GL_LINES);
    glVertex2d(1, 1);
    glVertex2d(width, 1);
    
    glVertex2d(width, 1);
    glVertex2d(width, height);
    
    glVertex2d(width, height);
    glVertex2d(1, height);
    
    glVertex2d(1, height);
    glVertex2d(1, 1);
    glEnd();
    
    
    //*****************************
    
    glFlush();
    [[self openGLContext] unlock];
    objc_sync_exit([self openGLContext]);
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (self->shouldStopGraphing)
    {
        return;
    }
    
    [super drawRect:dirtyRect];
    glDraw(self);
}

- (void)reshape
{
    [self setupGL];
}

- (void)update
{
    [[self openGLContext] lock];
    [super update];
    [[self openGLContext] unlock];
}

- (void)setupGL
{
    CGFloat x = 0;
    CGFloat y = 0;
    
    if (self.frame.origin.y < 0)
    {
        y = self.frame.origin.y;
    }
    if (self.frame.origin.x < 0)
    {
        x = self.frame.origin.x;
    }
    
    glViewport(x, y, (GLsizei)[self bounds].size.width, (GLsizei)[self bounds].size.height);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, self.bounds.size.width, 0, self.bounds.size.height, 0, 1);
    glMatrixMode(GL_MODELVIEW);
    glDisable(GL_DEPTH_TEST);
    
    glEnable(GL_LINE_STIPPLE);
    glEnable(GL_POINT_SMOOTH);
}

- (void)prepareOpenGL
{
    [super prepareOpenGL];
    [self setupGL];
}

- (void)setTransform
{
    if (NSIsEmptyRect(self.frame))
    {
        return;
    }
    
    double xs = (self.frame.size.width) / (self->xMax - self->xMin);
    double ys = (self.frame.size.height) / (self->yMax - self->yMin);
    double xt = -self->xMin;
    double yt = -self->yMin;
    
    if (xs == self->xScale && ys == self->yScale && xt == self->xTranslate && yt == self->yTranslate)
    {
        return;
    }
    else
    {
        self->xScale = xs;
        self->yScale = ys;
        self->xTranslate = xt;
        self->yTranslate = yt;
        
        self->currentTransform = [[NSAffineTransform alloc] init];
        [self->currentTransform scaleXBy:xs yBy:ys];
        [self->currentTransform translateXBy:xt yBy:yt];
    }
}

// *********************************************** Updating Methods ************************************************

- (BOOL)isUpdating
{
    return self->isUpdating;
}

- (BOOL)updateVertices // Should return true if the plot was updated, false otherwise
{
    if (self->isUpdating)
    {
        return YES;
    }
    
    objc_sync_enter(self);
    
    self->isUpdating = true;
    
    if ([self->plots count] == 0)
    {
        self->isUpdating = false;
        objc_sync_exit(self);
        return false;
    }
    
    __block BOOL updated = false;
    dispatch_apply(self->plots.count, [JZWGLGraph plotUpdateQueue], ^(size_t i) {
        updated |= [(JZWPlot*)[self->plots objectAtIndex:i] update:-1];
    });
    
    self->isUpdating = false;
    objc_sync_exit(self);
    
    return updated;
}

- (void)updateAsync
{
    if (self->shouldStopGraphing)
    {
        return;
    }
    
    if (!self->isUpdating)
    {
       dispatch_async(self->queue, ^{
            if ([self updateVertices])
            {
                [self setRedrawEverything];
                glDraw(self);
            }
        });
        
        if (self->redrawEverything > 0 || self->menuOn)
        {
            glDraw(self);
        }
    }
    else
    {
        glDraw(self);
    }   
}

// *********************************************** Misc. Methods ************************************************

- (void)setRedrawEverything
{
    self->redrawEverything = 2;
}

- (void)setBounds
{
    if (self->plots.count == 0)
    {
        return;
    }
    
    NSRect b = [((JZWPlot*)[self->plots objectAtIndex:0]).plot getBoundsWithPrecision:self->boundsPrecision];
    
    for (int i = 1; i < self->plots.count; i++)
    {
        NSRect bounds = [((JZWPlot*)[self->plots objectAtIndex:i]).plot getBoundsWithPrecision:self->boundsPrecision];
        b = NSUnionRect(b, bounds);
    }
    b = NSInsetRect(b, b.size.width * -0.1, b.size.height * -0.1);

    CGFloat total = fabs(b.origin.x) + fabs(b.origin.y) + fabs(b.size.width) + fabs(b.size.height);
    
    if (isnan(total) || total == INFINITY || total == -INFINITY || total == 0)
    {
        return;
    }
    
    self->xMin = b.origin.x;
    self->xMax = b.origin.x + b.size.width;
    self->yMin = b.origin.y;
    self->yMax = b.origin.y + b.size.height;
}

- (void)viewWillStartLiveResize
{
    [self setRedrawEverything];
}

- (void)viewDidEndLiveResize
{
    [self setRedrawEverything];
}

- (void)addPlot:(JZWPlot *)plot
{
    [self->plots addObject:plot];
    self->maxPlotNameLength = (int)([plot.name length] > self->maxPlotNameLength ? [plot.name length] : self->maxPlotNameLength);
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)removeFromSuperview
{
    [super removeFromSuperview];
}

- (BOOL)isOpaque
{
    return true;
}

- (void)enableAutoScroll:(NSObject*)sender
{
    self->scrollMode = AutoScrollNew;
}

- (void)disableAutoScroll:(NSObject*)sender
{
    self->scrollMode = AutoScrollOff;
}

- (void)hidePlot:(NSObject*)sender
{
    ((JZWPlot*)self->plots[((NSMenuItem*)sender).tag]).hidden = true;
    [self setRedrawEverything];
}

- (void)showPlot:(NSObject*)sender
{
    ((JZWPlot*)self->plots[((NSMenuItem*)sender).tag]).hidden = false;
    [self setRedrawEverything];
}

- (void)setForceRedraw:(BOOL)fr
{
    self->forceRedraw = fr;
}

- (NSString*)graphTitle
{
    return self->title;
}

- (void)stop
{
    self->shouldStopGraphing = true;
    for (JZWPlot* plot in self->plots)
    {
        [plot setStop:true];
    }
    
}
// *********************************************** Mouse Events ************************************************

- (void)handleTouches:(NSEvent*)event
{
    self->currentTouches = [event touchesMatchingPhase:NSTouchPhaseTouching inView:nil];
}
- (void)touchesBeganWithEvent:(NSEvent *)event
{
    [self handleTouches:event];
}
- (void)touchesEndedWithEvent:(NSEvent *)event
{
    [self handleTouches:event];
}
- (void)touchesCancelledWithEvent:(NSEvent *)event
{
    [self handleTouches:event];
}

- (void)mouseUp:(NSEvent *)event
{
    NSInteger clickCount = [event clickCount];
    NSUInteger numTouches = [self->currentTouches count];
    
    if (2 == clickCount && self->selectedPlot == NO_SELECTION)
    {
        switch (numTouches) {
            case 1:
                if ([self.superview isKindOfClass:[JZWGridBoxView class]])
                {
                    NSView* fsView = [(JZWGridBoxView*)self.superview fullScreenView];
                    
                    if (fsView == self)
                    {
                        [(JZWGridBoxView*)self.superview fullScreenView:nil];
                    }
                    else
                    {
                        [(JZWGridBoxView*)self.superview fullScreenView:self];
                    }
                }
                break;
            case 3:
                [self setBounds];
            default:
                break;
        }
    }
    
    self->mouseIsDown = false;
    
    if (self->selectedPlot == FLIP_AS)
    {
        if (self->scrollMode == AutoScrollOff)
        {
            self->scrollMode = AutoScrollNew;
        }
        else
        {
            self->scrollMode = AutoScrollOff;
        }
    }
    else if (self->selectedPlot == FLIP_LEGEND)
    {
        self->legendOn = !self->legendOn;
    }
    else if (self->selectedPlot >= 0)
    {
        ((JZWPlot*)self->plots[self->selectedPlot]).hidden = !((JZWPlot*)self->plots[self->selectedPlot]).hidden;
    }
    else
    {
        self->menuOn = false;        
    }
    
    [self setRedrawEverything];
}

- (void)mouseDragged: (NSEvent*) event
{
    CGFloat dx = -event.deltaX / self->xScale;
    CGFloat dy = event.deltaY / self->yScale;
    
    self->xMin += dx;
    self->xMax += dx;
    self->yMin += dy;
    self->yMax += dy;
    
    [self setRedrawEverything];
}

- (void)mouseDown:(NSEvent *)theEvent
{
    self->mouseIsDown = true;
}

- (void)scrollWheel: (NSEvent*) event
{
    CGFloat dx = -event.deltaX / self->xScale * 2;
    CGFloat dy = event.deltaY / self->yScale * 2;
    
    self->xMin += dx;
    self->xMax += dx;
    self->yMin += dy;
    self->yMax += dy;
    
    [self setRedrawEverything];
}

- (void) magnifyWithEvent: (NSEvent*) event
{
    CGFloat mag = event.magnification * 1.5;
    
    CGFloat w = (self->xMax - self->xMin);
    CGFloat h = (self->yMax - self->yMin);
    
    NSPoint mouse = [self convertPoint:[event locationInWindow] fromView:nil];
    
    NSArray* touches = [self->currentTouches allObjects];
    
    if ([touches count] != 2)
    {
        return;
    }
    
    NSTouch* t0 = [touches objectAtIndex:0];
    NSTouch* t1 = [touches objectAtIndex:1];
    
    NSPoint pos0 = t0.normalizedPosition;
    NSPoint pos1 = t1.normalizedPosition;
    CGFloat dx = fabs(pos0.x - pos1.x);
    CGFloat dy = fabs(pos0.y - pos1.y);
    
    CGFloat hypotenuse = sqrt(dx * dx + dy * dy);
    
    CGFloat xmag = mag * dx / hypotenuse;
    CGFloat ymag = mag * dy / hypotenuse;
    
    CGFloat mxFrac = mouse.x / self.frame.size.width;
    CGFloat myFrac = mouse.y / self.frame.size.height;
    
    self->xMin += w * xmag * mxFrac / 2;
    self->xMax -= w * xmag * (1 - mxFrac) / 2;
    self->yMin += h * ymag * myFrac / 2;
    self->yMax -= h * ymag * (1 - myFrac) / 2;
    
    [self setRedrawEverything];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
    self->menuOn = true;
}

/*
- (NSImage*) image
{
    NSRect bounds = [self bounds];
    int height = bounds.size.height;
    int width = bounds.size.width;
    
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc]
                                  initWithBitmapDataPlanes:NULL
                                  pixelsWide:width
                                  pixelsHigh:height
                                  bitsPerSample:8
                                  samplesPerPixel:4
                                  hasAlpha:YES
                                  isPlanar:NO
                                  colorSpaceName:NSCalibratedRGBColorSpace
                                  bytesPerRow:4 * width
                                  bitsPerPixel:0
                                  ];
    
    // This call is crucial, to ensure we are working with the correct context
    [[self openGLContext] makeCurrentContext];    
    [self drawRect:[self bounds]];
    //Your code to use the contents
    glReadPixels(0, 0, width, height,
                 GL_RGBA, GL_UNSIGNED_BYTE, [imageRep bitmapData]);
    
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(width,height)];
    [image addRepresentation:imageRep];
    [image setFlipped:YES];
    [image lockFocusOnRepresentation:imageRep]; // This will flip the rep.
    [image unlockFocus];
    
    return image;
}
*/

@end
