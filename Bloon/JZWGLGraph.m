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
#import <simd/simd.h>

@import Accelerate;

#define FRAMERATE (30)
#define MAX_POINTS (-1)

#define NO_SELECTION -2
#define FLIP_AS -1
#define FLIP_LEGEND -3

#define SHOW_FPS (0)

#define AUTOSCROLL_BUFFER (0.025)
#define LINE_STIPPLE_NUM (4)
#define NORMAL_STIPPLE_PATTERN (0xFFFF)
#define GRID_STIPPLE_PATTERN (0xAAAA)

#define X_TICK_TOP_TO_LABEL_BOTTOM (5)
#define TICK_LABEL_ADJUST_BOTTOM (15)
#define TICK_LABEL_ADJUST_LEFT (5)
#define TICK_LABEL_ADJUST_RIGHT (5)

#define Y_TICK_TO_LABEL_BOTTOM (5)
#define X_TICK_LABEL_BOTTOM_ADJUST (-15)
#define X_LABEL_SHIFT (5)
#define MAX_TICK_LABEL_LENGTH (40)
#define AUTO_TICK_WIDTH (80)
#define AUTO_TICK_WIDTH_DATE (105)
#define Y_AXIS_LABEL_LEFT_ADJ (5)
#define DIGITS_IN_AXIS_LABELS (7)

#define LARGE_FONT_CHAR_WIDTH (9)
#define SMALL_FONT_CHAR_WIDTH (8)
#define SMALL_FONT_CHAR_HEIGHT (9)
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

#define TRANSFORM_X(x) ((x) * self->xScale + self->xTranslate)
#define TRANSFORM_Y(y) ((y) * self->yScale + self->yTranslate)

@interface JZWGLGraph ()

- (void)setTransform;

@end

@implementation JZWGLGraph
{
    NSString* title;
    
    NSMutableArray* plots;
    NSAffineTransform* currentTransform;

    NSDate* lastFrameTime;
    unsigned long frameCounter;

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
    
    double tickLength;
    double axisWidth;
    double tickWidth;
    
    BOOL gridOn;
    NSColor* gridColor;
    double gridWidth;
    
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
    
    NSImage *cachedScreenshot;
    
    GLuint program;
    GLuint constantLocX;
    GLuint multiplierLocX;
    GLuint constantLocY;
    GLuint multiplierLocY;
    GLuint positionLoc;
    
    GLdouble* transformedVertexBuffer;
    dispatch_queue_t vertexTransformQueue;
    
    int currentlyScrolling;
    
    long maxPointsPerFrame;
    
    BOOL isDrawing;
    
    BOOL isSnapshotting;
    CGRect snapshotFrame;
    double UIScaleFactor;
    double gridLineScaleFactor;
    
    NSDateFormatter* dateFormatter;
    BOOL xAxisShowsDate;
}

// *********************************************** Class Methods ************************************************

+ (dispatch_queue_t)plotUpdateQueue
{
    static dispatch_queue_t queue = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        dispatch_queue_attr_t qosAttribute = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INITIATED, 0);
        queue = dispatch_queue_create("Plot Update Queue", qosAttribute);
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
        //NSOpenGLPFAMultisample,
        //NSOpenGLPFASampleBuffers, (NSOpenGLPixelFormatAttribute)1,
        NSOpenGLPFAColorSize, (NSOpenGLPixelFormatAttribute) 32,
        NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute) 23,
        //NSOpenGLPFASamples, (NSOpenGLPixelFormatAttribute)16,
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
    
    dispatch_queue_attr_t qosAttribute = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
    self->queue =  dispatch_queue_create([graphTitle cStringUsingEncoding:NSASCIIStringEncoding], qosAttribute);
    self->isUpdating = false;
    
    self->axisLabelFont = GLUT_BITMAP_8_BY_13;
    self->titleFont = GLUT_BITMAP_9_BY_15;
    
    self->autoTickMarks = true;

    [[JZWGLGraph getAllGraphs] addObject:self];
    
    self->currentTouches = [[NSMutableSet alloc] init];
    self->mouseIsDown = false;

    self.allowedTouchTypes = NSTouchTypeMaskDirect | NSTouchTypeMaskIndirect;
    self.layer.drawsAsynchronously = true;
    
    self->redrawEverything = 4;
    
    self->selectedPlot = NO_SELECTION;
    self->selectedColor = [[NSColor grayColor] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    self->unselectedColor = [[NSColor whiteColor] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    self->maxPlotNameLength = 0;
    
    self->forceRedraw = false;
    
    self->shouldStopGraphing = false;
    
    self->boundsPrecision = 0.99;
    
    self->cachedScreenshot = nil;
    
    [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawNever];
    [self setLayerContentsPlacement:NSViewLayerContentsPlacementScaleAxesIndependently];
    
    [[self openGLContext] makeCurrentContext];
    
    self->currentlyScrolling = 2;
    /*
    const char *str = [[[NSString alloc] initWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"]] encoding:NSUTF8StringEncoding] cStringUsingEncoding:NSASCIIStringEncoding];
    GLint length = (GLint)strlen(str);
    GLuint shader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(shader, 1, &str, NULL);
    glCompileShader(shader);
    self->program = glCreateProgram();
    glAttachShader(self->program, shader);
    glBindAttribLocation(self->program, 0, "position");
    glLinkProgram(self->program);
    
    char buff[8000];
    GLsizei infoLength;
    glGetShaderInfoLog(shader, 8000, &infoLength, buff);
    printf("Log: %s", buff);

    self->multiplierLocY = glGetUniformLocation(self->program, "mx");
    self->constantLocX = glGetUniformLocation(self->program, "cx");
    self->multiplierLocX = glGetUniformLocation(self->program, "my");
    self->constantLocX = glGetUniformLocation(self->program, "cy");
    self->positionLoc = glGetAttribLocation(self->program, "position");
    */
    
    self->lastFrameTime = [NSDate date];
    self->frameCounter = 0;
    
    self->transformedVertexBuffer = (GLdouble*)malloc(VERTEX_ARRAY_CHUNK_SIZE * 2 * sizeof(GLdouble));

    const char* queueName = [[NSString stringWithFormat:@"%@ Vertex Transform Queue", graphTitle] UTF8String];
    qosAttribute = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0);
    self->vertexTransformQueue = dispatch_queue_create(queueName, qosAttribute);
    
    self->maxPointsPerFrame = [JZWPreferencesWindow sharedPreferences].maxPointsPerFrame;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferencesChangedWithNotification:) name:@"PreferencesChanged" object:nil];
    
    self->isDrawing = false;
    self->isSnapshotting = false;
    self->UIScaleFactor = 1.0;
    self->gridLineScaleFactor = 1.0;
    
    self->dateFormatter = [[NSDateFormatter alloc] init];
    [self->dateFormatter setLocale:[NSLocale currentLocale]];
    [self->dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    self->xAxisShowsDate = NO;
    
    return self;
}

- (void)preferencesChangedWithNotification:(NSNotification*)not
{
    self->maxPointsPerFrame = [JZWPreferencesWindow sharedPreferences].maxPointsPerFrame;
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
     labelColor:(NSColor*)_labelColor gridColor:(NSColor*)_gridColor bgColor:(NSColor*)_bgColor axisColor:(NSColor*)_axisColor xAxisDates:(BOOL)_xAxisDates
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
    self->xAxisShowsDate = _xAxisDates;
}

- (void)dealloc
{
    free(self->transformedVertexBuffer);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// *********************************************** Drawing Methods ************************************************

void drawText(char* string, double x, double y, void* font, double scale, NSColor* color)
{
    NSColor* c = color;
    glColor3f(c.redComponent, c.greenComponent, c.blueComponent);
    
    if (scale == 1)
    {
        // A trick to fix the clipping problem found here: https://www.opengl.org/archives/resources/faq/technical/clipping.htm
        glRasterPos2i(0, 0);
        glBitmap (0, 0, 0, 0, x, y, NULL);
        while (*string)
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            glutBitmapCharacter(font, *string++);
#pragma clang diagnostic pop
        }
    }
    else
    {
        double fontSize = (font == GLUT_BITMAP_8_BY_13) ? 1 : 1.14;
        glPushMatrix();
        glTranslatef(x, y, 0);
        glScalef(0.075 * scale * fontSize, 0.075 * scale * fontSize, 0);
        glLineWidth(1.0 * scale);
        glEnable(GL_LINE_SMOOTH);
        while (*string)
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            glutStrokeCharacter(GLUT_STROKE_MONO_ROMAN, *string++);
#pragma clang diagnostic pop
        }
        glPopMatrix();
        glDisable(GL_LINE_SMOOTH);
    }
}


/*
 if value < 1 and it has too many float digits
    scientific notation
 if increment is >= 1
    if value is less than n digits
        format as integer
    if value is more than n digits
        scientific notation
 if increment is < 1
    if value is less than n digits
        format as float
    if value is more than n digits
        if int value is more than n digits
            scientific notation
        if int value is less than n digits
            display float with n digits total
 */
void formatLabel(char* buffer, double value, double increment, int maxDigits)
{
    int digitsInIntPortion = floor(fabs(value)) == 0 ? 1 : (int)log10(floor(fabs(value))) + 1;
    int digitsInFloatPortion = (int)fabs(log2(increment));
    
    if (fabs(value) < 1 && digitsInFloatPortion > maxDigits)
    {
        sprintf(buffer, "%.2E", value);
    }
    else if (increment >= 1.0)
    {
        if (digitsInIntPortion <= maxDigits)
        {
            sprintf(buffer, "%d", (int)value);
        }
        else
        {
            sprintf(buffer, "%.2E", value);
        }
    }
    else
    {
        if (digitsInIntPortion + digitsInFloatPortion <= maxDigits)
        {
            sprintf(buffer, "%.*f", digitsInFloatPortion, value);
        }
        else
        {
            if (digitsInIntPortion > maxDigits)
            {
                sprintf(buffer, "%.2E", value);
            }
            else
            {
                sprintf(buffer, "%.*f", maxDigits - digitsInIntPortion, value);
            }
        }
    }
}

int lengthOfNumber(double value, double increment)
{
    int digitsInIntPortion = floor(fabs(value)) == 0 ? 1 : (int)log10(floor(fabs(value))) + 1;
    int digitsInFloatPortion = increment >= 1 ? 0 : (int)fabs(log2(increment));
    return digitsInIntPortion + digitsInFloatPortion;
}

- (void)glDraw
{
    if (!self)
    {
        NSLog(@"Graph is Null?");
        return;
    }
    
    objc_sync_enter([self openGLContext]);
    if (self->isDrawing)
    {
        objc_sync_exit([self openGLContext]);
        return;
    }
    self->isDrawing = true;
    objc_sync_exit([self openGLContext]);

    [[self openGLContext] lock];
    [[self openGLContext] makeCurrentContext];
    [self setupGL];
  
    self->frameCounter++;
    
#pragma mark ******************************** Determine If Full Redraw Required ***********************************
    
    BOOL shouldRedrawEverything = self->redrawEverything > 0 || self.inLiveResize || self->menuOn || self->forceRedraw || self->currentlyScrolling;
    
    if (self->redrawEverything > 0)
    {
        self->redrawEverything--;
        NSDate* now = [NSDate date];
#if SHOW_FPS
        NSTimeInterval frameDuration = [now timeIntervalSinceDate:self->lastFrameTime];
#endif
        self->lastFrameTime = now;
#if SHOW_FPS
        printf("%.3lf fps\n", 1.0/frameDuration);
#endif
    }
    
#pragma mark ******************************** Determine Scroll Mode ***********************************
    
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
                double rightMost = bounds.origin.x + bounds.size.width;
                double shift = (self->xMax - self->xMin) * AUTOSCROLL_BUFFER;
                if (rightMost > self->xMax - shift)
                {
                    self->xMin += rightMost - self->xMax + shift;
                    self->xMax = rightMost + shift;
                    shouldRedrawEverything = true;
                }
            }
            break;
    }
    
#pragma mark ******************************** Calculate Useful Values ***********************************

    [self setTransform];
    
    NSColor* c = nil;
    
    if (shouldRedrawEverything)
    {
        c = self->backgroundColor;
        
        glClearColor(c.redComponent, c.greenComponent, c.blueComponent, 1);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    
    // The width and height of the window in pixels
    double width = self.frame.size.width;
    double height = self.frame.size.height;
    
    // The width and height of the window in units
    double widthValue = self->xMax - self->xMin;
    double heightValue = self->yMax - self->yMin;
    
    // Determine the location of the axes
    double xAxis = (-self->yMin) / (heightValue) * height;
    double xAxisReal = xAxis;
    BOOL xAxisLabelTop;
    double yAxis = (-self->xMin) / (widthValue) * width;
    double yAxisReal = yAxis;
    BOOL yAxisLabelRight;
    
    double xOriginValue = 0;
    double yOriginValue = 0;
    
    JZWRect boundsValue = {{self->xMin, self->yMin}, {widthValue, heightValue}};
    
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
    
    double halfTick = self->tickLength / 2;

    // Determine the locations of the tick marks
    double minPixelsPerTick = (self->xAxisShowsDate ? AUTO_TICK_WIDTH_DATE : AUTO_TICK_WIDTH) * self->gridLineScaleFactor;
    
    double xminUnitsPerTick = minPixelsPerTick * widthValue / width;
    double yminUnitsPerTick = minPixelsPerTick * heightValue / height;

    double xn = floor(ceil(log2(widthValue))  - log2(xminUnitsPerTick));
    double yn = floor(ceil(log2(heightValue)) - log2(yminUnitsPerTick));

    double xunitsPerTick = pow(0.5, floor(log(widthValue)/log(0.5)) + xn);
    double yunitsPerTick = pow(0.5, floor(log(heightValue)/log(0.5)) + yn);

//    double longestNum = MAX(fabs(self->xMin), fabs(self->xMax));
//    if ((lengthOfNumber(longestNum, xunitsPerTick) + 1.5) * SMALL_FONT_CHAR_WIDTH > minPixelsPerTick)
//    {
//        minPixelsPerTick = (lengthOfNumber(longestNum, xunitsPerTick) + 1.5) * SMALL_FONT_CHAR_WIDTH;
//        
//        xminUnitsPerTick = minPixelsPerTick * widthValue / width;
//        yminUnitsPerTick = minPixelsPerTick * heightValue / height;
//        
//        xn = floor(ceil(log2(widthValue))  - log2(xminUnitsPerTick));
//        yn = floor(ceil(log2(heightValue)) - log2(yminUnitsPerTick));
//        
//        xunitsPerTick = pow(0.5, floor(log(widthValue)/log(0.5)) + xn);
//        yunitsPerTick = pow(0.5, floor(log(heightValue)/log(0.5)) + yn);
//    }
   
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
    
#pragma mark ******************************** Start Drawing ***********************************
    
    if (ticksValid && shouldRedrawEverything)
    {
#pragma mark ******************************** Draw The Grid ***********************************
        if (self->gridOn)
        {
            NSColor* gc = self->gridColor;
            glLineWidth(self->gridWidth * self->UIScaleFactor);
            glColor3f(gc.redComponent, gc.greenComponent, gc.blueComponent);
            glLineStipple(LINE_STIPPLE_NUM, GRID_STIPPLE_PATTERN);
            
            double xOffset = fmod(xAxis - xAxisReal, 8.0);
            double yOffset = fmod(yAxis - yAxisReal, 8.0);

            glBegin(GL_LINES);
            for (double x = yAxis + xTickStartPixels; x < width; x += xTickPixels)
            {
                glVertex2d(x, xAxis - xOffset);
                glVertex2d(x, 0);
                glVertex2d(x, xAxis - xOffset);
                glVertex2d(x, height);
            }
            for (double x = yAxis + xTickStartPixels; x > 0; x -= xTickPixels)
            {
                glVertex2d(x, xAxis - xOffset);
                glVertex2d(x, 0);
                glVertex2d(x, xAxis - xOffset);
                glVertex2d(x, height);
            }
            for (double y = xAxis + yTickStartPixels; y < height; y += yTickPixels)
            {
                glVertex2d(yAxis - yOffset, y);
                glVertex2d(0, y);
                glVertex2d(yAxis - yOffset, y);
                glVertex2d(width, y);
            }
            for (double y = xAxis + yTickStartPixels; y > 0; y -= yTickPixels)
            {
                glVertex2d(yAxis - yOffset, y);
                glVertex2d(0, y);
                glVertex2d(yAxis - yOffset, y);
                glVertex2d(width, y);
            }
            glEnd();
            
            glLineStipple(LINE_STIPPLE_NUM, NORMAL_STIPPLE_PATTERN);
        }
        
#pragma mark ******************************** Draw The Axes ***********************************
        if (self->axesOn)
        {
            glLineWidth(self->axisWidth * self->UIScaleFactor);
            c = self->axisColor;
            glColor3f(c.redComponent, c.greenComponent, c.blueComponent);
            
            glBegin(GL_LINES);
            glVertex2d(0, xAxis);
            glVertex2d(width, xAxis);
            glVertex2d(yAxis, 0);
            glVertex2d(yAxis, height);
            glEnd();
            
#pragma mark ******************************** Draw The Tick Marks ***********************************
            glLineWidth(self->tickWidth * self->UIScaleFactor);
            glBegin(GL_LINES);
            for (double x = yAxis + xTickStartPixels; x < width; x += xTickPixels)
            {
                glVertex2d(x, xAxis + halfTick);
                glVertex2d(x, xAxis - halfTick);
            }
            for (double x = yAxis + xTickStartPixels; x > 0; x -= xTickPixels)
            {
                glVertex2d(x, xAxis + halfTick);
                glVertex2d(x, xAxis - halfTick);
            }
            for (double y = xAxis + yTickStartPixels; y < height; y += yTickPixels)
            {
                glVertex2d(yAxis + halfTick, y);
                glVertex2d(yAxis - halfTick, y);
            }
            for (double y = xAxis + yTickStartPixels; y > 0; y -= yTickPixels)
            {
                glVertex2d(yAxis + halfTick, y);
                glVertex2d(yAxis - halfTick, y);
            }
            glEnd();
        }
    }
    
#pragma mark ******************************** Draw The Data Points ***********************************
    
    double xSca = self->xScale;
    double ySca = self->yScale;
    double xTra = self->xTranslate;
    double yTra = self->yTranslate;
    
    __block unsigned long totalNumPoints = 0;
    for (JZWPlot* plot in self->plots)
    {
        if (plot.hidden)
        {
            continue;
        }
        [plot.plot getVertices:^(GLdouble *vertices, GLdouble *colors, int numVertices, GLuint *vertexBuffer, GLuint *vertexArray, BOOL wasModified) {
            totalNumPoints += numVertices;
        } inBounds:boundsValue];
    }
    
    int drawEveryNthPoint = ceil((double)(totalNumPoints + 1) / maxPointsPerFrame);
    
    if (self->currentlyScrolling)
    {
        self->currentlyScrolling--;
    }
    
    glEnableClientState(GL_VERTEX_ARRAY);
    for (JZWPlot* plot in self->plots)
    {
        if (plot.hidden)
        {
            continue;
        }
        
        JZWVertexArray* va = plot.plot;
        
        GLdouble* bufferp = transformedVertexBuffer;

        glPointSize(plot.pointDim * self->UIScaleFactor);
        glLineWidth(plot.lineWidth * self->UIScaleFactor);
    
        simd_double2 B = simd_make_double2(xSca, ySca);
        simd_double2 C = simd_make_double2(xTra * xSca, yTra * ySca);
//        double xB = xSca;
//        double xC = xTra * xSca;
//        double yB = ySca;
//        double yC = yTra * ySca;
        
        BOOL usesColorBar = plot.color == nil;
    
        if (usesColorBar)
        {
            glEnableClientState(GL_COLOR_ARRAY);
        }
        else
        {
            glColor3f(plot.color.redComponent, plot.color.greenComponent, plot.color.blueComponent);
        }
        
        int localDrawEveryNthPoint = drawEveryNthPoint;
        
        BOOL onlyDrawNewVertices = shouldRedrawEverything || self->currentlyScrolling;
        
        if (!onlyDrawNewVertices || !self->currentlyScrolling || self->menuOn)
        {
            localDrawEveryNthPoint = 1;
        }
        
        simd_double2 *simd_bufferp = (simd_double2 *)bufferp;

        VertexProcessingBlock drawVerts = ^void(GLdouble* verts, GLdouble* colors, int nv, GLuint* vertexBuffer, GLuint* vertexArray, BOOL modified)
        {
            simd_double2 *simd_verts = (simd_double2 *)verts;
            
            for (int i = 0; i < nv / localDrawEveryNthPoint; i++) {
                simd_bufferp[i] = simd_muladd(simd_verts[i * localDrawEveryNthPoint], B, C);
            }
//            dispatch_group_t vertexTransformGroup = dispatch_group_create();
//
//            dispatch_group_async(vertexTransformGroup, self->vertexTransformQueue, ^{
//                vDSP_vsmsaD(verts,     2 * localDrawEveryNthPoint, &xB, &xC, bufferp,     2, nv / localDrawEveryNthPoint);
//            });
//            dispatch_group_async(vertexTransformGroup, self->vertexTransformQueue, ^{
//                vDSP_vsmsaD(verts + 1, 2 * localDrawEveryNthPoint, &yB, &yC, bufferp + 1, 2, nv / localDrawEveryNthPoint);
//            });
//
//            dispatch_group_wait(vertexTransformGroup, DISPATCH_TIME_FOREVER);
            
            glVertexPointer(2, GL_DOUBLE, 0, bufferp);
            if (usesColorBar)
            {
                glColorPointer(3, GL_DOUBLE, 3 * localDrawEveryNthPoint * sizeof(GLdouble), colors);
            }
            if (plot.scatter)
            {
                glDrawArrays(GL_POINTS, 0, nv / localDrawEveryNthPoint);
            }
            if (plot.line)
            {
                glDrawArrays(GL_LINE_STRIP, 0, nv / localDrawEveryNthPoint);
            }
        };

        if (onlyDrawNewVertices)
        {
            [va getVertices:drawVerts inBounds:boundsValue];
            [va resetNewVertices];
        }
        else
        {
            [va getNewVertices:drawVerts inBounds:boundsValue];
        }
        
        if (usesColorBar)
        {
            glDisableClientState(GL_COLOR_ARRAY);
        }
    }
    glDisableClientState(GL_VERTEX_ARRAY);
    glLoadIdentity();
#pragma mark ******************************** Draw Axis Scale Labels ***********************************
    
    if (ticksValid && self->labelsOn && shouldRedrawEverything)
    {
        double topBottom = xAxisLabelTop   ? (halfTick + X_TICK_TOP_TO_LABEL_BOTTOM)  : -(halfTick + X_TICK_TOP_TO_LABEL_BOTTOM + SMALL_FONT_CHAR_HEIGHT * self->gridLineScaleFactor);
        double leftRight = yAxisLabelRight ? (halfTick + TICK_LABEL_ADJUST_LEFT) : -(halfTick - TICK_LABEL_ADJUST_RIGHT);
        double yTopBottom = xAxisLabelTop ? Y_TICK_TO_LABEL_BOTTOM : -(Y_TICK_TO_LABEL_BOTTOM + SMALL_FONT_CHAR_HEIGHT * self->gridLineScaleFactor);
        double xLabelShift = X_LABEL_SHIFT;
        
        char valueString[MAX_TICK_LABEL_LENGTH];
        
        for (double x = yAxis + xTickStartPixels - xTickPixels; x < width; x += xTickPixels)
        {
            double value = (x - yAxis) / self->xScale + xOriginValue; // Calculate the value of the tick
            value = floor((value / xunitsPerTick) + 0.5) * xunitsPerTick; // Round it to the nearest real tick value
            
            if (fabs(value) < xTickValue / 2)
            {
                continue;
            }
            
            if (!self->xAxisShowsDate) {
                formatLabel(valueString, value, xunitsPerTick, DIGITS_IN_AXIS_LABELS);
                drawText(valueString, x + xLabelShift, xAxis + topBottom, self->axisLabelFont, self->gridLineScaleFactor, self->labelColor);
            } else {
                NSString *dateString = [self->dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:value]];
                char *cDateString = strdup([dateString cStringUsingEncoding:NSUTF8StringEncoding]);
                cDateString[10] = 0;
                double dateOffset = xAxisLabelTop ? LARGE_FONT_LINE_HEIGHT : 0;
                double timeOffset = xAxisLabelTop ? 0 : -LARGE_FONT_LINE_HEIGHT;
                drawText(cDateString, x + xLabelShift, xAxis + dateOffset + topBottom, self->axisLabelFont, self->gridLineScaleFactor, self->labelColor);
                drawText(cDateString + 11, x + xLabelShift, xAxis + timeOffset + topBottom, self->axisLabelFont, self->gridLineScaleFactor, self->labelColor);
                free(cDateString);
            }
            

        }
        for (double x = yAxis + xTickStartPixels; x > -xTickPixels; x -= xTickPixels)
        {
            double value = (x - yAxis) / self->xScale + xOriginValue;
            value = floor((value / xunitsPerTick) + 0.5) * xunitsPerTick;

            if (fabs(value) < xTickValue / 2)
            {
                continue;
            }
            
            if (!self->xAxisShowsDate) {
                formatLabel(valueString, value, xunitsPerTick, DIGITS_IN_AXIS_LABELS);
                drawText(valueString, x + xLabelShift, xAxis + topBottom, self->axisLabelFont, self->gridLineScaleFactor, self->labelColor);
            } else {
                NSString *dateString = [self->dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:value]];
                char *cDateString = strdup([dateString cStringUsingEncoding:NSUTF8StringEncoding]);
                cDateString[10] = 0;
                double dateOffset = xAxisLabelTop ? LARGE_FONT_LINE_HEIGHT : 0;
                double timeOffset = xAxisLabelTop ? 0 : -LARGE_FONT_LINE_HEIGHT;
                drawText(cDateString, x + xLabelShift, xAxis + dateOffset + topBottom, self->axisLabelFont, self->gridLineScaleFactor, self->labelColor);
                drawText(cDateString + 11, x + xLabelShift, xAxis + timeOffset + topBottom, self->axisLabelFont, self->gridLineScaleFactor, self->labelColor);
                free(cDateString);
            }
        }
        for (double y = xAxis + yTickStartPixels - yTickPixels; y < height; y += yTickPixels)
        {
            double value = (y - xAxis) / self->yScale + yOriginValue;
            value = floor((value / yunitsPerTick) + 0.5) * yunitsPerTick;

            if (fabs(value) < yTickValue / 2)
            {
                continue;
            }
            
            formatLabel(valueString, value, yunitsPerTick, DIGITS_IN_AXIS_LABELS);

            double adj = 0;
            
            if (!yAxisLabelRight)
            {
                adj = STR_SMALL_FONT_WIDTH_PIXELS(valueString) + Y_AXIS_LABEL_LEFT_ADJ;
            }
            
            drawText(valueString, yAxis + leftRight - adj, y + yTopBottom, self->axisLabelFont, self->gridLineScaleFactor, self->labelColor);
        }
        for (double y = xAxis + yTickStartPixels; y > -yTickPixels; y -= yTickPixels)
        {
            double value = (y - xAxis) / self->yScale + yOriginValue;
            value = floor((value / yunitsPerTick) + 0.5) * yunitsPerTick;

            if (fabs(value) < yTickValue / 2)
            {
                continue;
            }
            
            formatLabel(valueString, value, yunitsPerTick, DIGITS_IN_AXIS_LABELS);

            double adj = 0;
            
            if (!yAxisLabelRight)
            {
                adj = STR_SMALL_FONT_WIDTH_PIXELS(valueString) + Y_AXIS_LABEL_LEFT_ADJ;
            }
            
            drawText(valueString, yAxis + leftRight - adj, y + yTopBottom, self->axisLabelFont, self->gridLineScaleFactor, self->labelColor);
        }
    }
    
#pragma mark ******************************** Draw Title ***********************************
    
    if (!self->isSnapshotting)
    {
        const char* ctitle = [self->title cStringUsingEncoding:NSUTF8StringEncoding];
        unsigned long titleLength = STR_LARGE_FONT_WIDTH_PIXELS(ctitle);
        
        glColor3f(self->backgroundColor.redComponent, self->backgroundColor.greenComponent, self->backgroundColor.blueComponent);
        glRectf(self.bounds.size.width / 2 - titleLength / 2 - 2, height - 3,
                self.bounds.size.width / 2 + titleLength / 2 + 2, height - LARGE_FONT_LINE_HEIGHT - 5);
        
        drawText((char*)ctitle, self.bounds.size.width / 2 - titleLength / 2, self.bounds.size.height - LARGE_FONT_LINE_HEIGHT, self->titleFont, 1.0, self->labelColor);
    }
    
#pragma mark ******************************** Draw Legend ***********************************
    
    if (self->legendOn)
    {
        int legendHeight = (int)(LARGE_FONT_LINE_HEIGHT * [self->plots count] + 6);
        int top = self.bounds.size.height;
        int legendWidth = self->maxPlotNameLength * LARGE_FONT_CHAR_WIDTH + LEGEND_COLOR_BOX_WIDTH;
        
        glColor3f(1, 1, 1);
        glRectf(0, top, legendWidth + MENU_LEGEND_BORDER, top - (legendHeight + MENU_LEGEND_BORDER));
        glColor3f(0, 0, 0);
        glRectf(MENU_LEGEND_BORDER, top - MENU_LEGEND_BORDER, legendWidth, top - legendHeight);

        int x = MENU_LEGEND_BORDER + 2;
        int y = top - (LARGE_FONT_LINE_HEIGHT + 2);
        
        for (JZWPlot* plot in self->plots)
        {
            char* name = (char*)[plot.name cStringUsingEncoding:NSUTF8StringEncoding];
            drawText(name, x + LEGEND_COLOR_X2_ADJ + 1, y, self->titleFont, self->gridLineScaleFactor, self->unselectedColor);
            glColor3f(plot.color.redComponent, plot.color.greenComponent, plot.color.blueComponent);
            
            glRectf(x,                       y + LEGEND_COLOR_Y1_ADJ,
                    x + LEGEND_COLOR_X2_ADJ, y + LEGEND_COLOR_Y2_ADJ);
            y -= LARGE_FONT_LINE_HEIGHT;
        }
    }
    
#pragma mark ******************************** Draw Menu ***********************************
    
    if (self->menuOn)
    {
        NSPoint mouseGlobal = [NSEvent mouseLocation];
        NSRect windowLocation = [[self window] convertRectFromScreen:NSMakeRect(mouseGlobal.x, mouseGlobal.y, 0, 0)];
        NSPoint mouse = [self convertPoint: windowLocation.origin fromView: nil];
        JZWPoint mouseDbl = {mouse.x, mouse.y};

#pragma mark *************************** Highlight Closest Point
        
        JZWPoint* points = calloc([self->plots count], sizeof(JZWPoint));
        GLdouble* pointColors = calloc([self->plots count] * 3, sizeof(GLdouble));
        int pointIndex = 0;
        
        for (JZWPlot* plot in self->plots)
        {
            if (!plot.hidden)
            {
                GLdouble *highlightColor;
                JZWPoint rawPoint = [[plot plot] closestVertexToPoint:mouseDbl xs:self->xScale ys:self->yScale xt:self->xTranslate yt:self->yTranslate color:&highlightColor];
                points[pointIndex] = rawPoint;
                GLdouble tpx = (rawPoint.x + xTra) * xSca;
                GLdouble tpy = (rawPoint.y + yTra) * ySca;
                
                glPointSize(plot.pointDim + SELECTED_POINT_INCREASE * 2);
                glColor3f(self->backgroundColor.redComponent, self->backgroundColor.greenComponent, self->backgroundColor.blueComponent);
                glBegin( GL_POINTS );
                glVertex2d(tpx, tpy);
                glEnd();
                
                glPointSize(plot.pointDim + SELECTED_POINT_INCREASE);
                if (highlightColor)
                {
                    pointColors[pointIndex * 3 + 0] = highlightColor[0];
                    pointColors[pointIndex * 3 + 1] = highlightColor[1];
                    pointColors[pointIndex * 3 + 2] = highlightColor[2];
                }
                else
                {
                    pointColors[pointIndex * 3 + 0] = plot.color.redComponent;
                    pointColors[pointIndex * 3 + 1] = plot.color.greenComponent;
                    pointColors[pointIndex * 3 + 2] = plot.color.blueComponent;
                }
                glColor3f(pointColors[pointIndex * 3 + 0], pointColors[pointIndex * 3 + 1], pointColors[pointIndex * 3 + 2]);

                glBegin( GL_POINTS );
                glVertex2d(tpx, tpy);
                glEnd();
                
                glPointSize(MAX(plot.pointDim, 1));
                glColor3f(self->backgroundColor.redComponent, self->backgroundColor.greenComponent, self->backgroundColor.blueComponent);
                glBegin( GL_POINTS );
                glVertex2d(tpx, tpy);
                glEnd();
            }
            pointIndex++;
        }
        
#pragma mark *************************** Draw Menu
        
        unsigned long menuHeight = LARGE_FONT_LINE_HEIGHT * (2 + [self->plots count]) + 6;
        glColor3f(1, 1, 1);
        glRectf(0, 0, MENU_WIDTH + MENU_LEGEND_BORDER, menuHeight + MENU_LEGEND_BORDER);
        glColor3f(0, 0, 0);
        glRectf(MENU_LEGEND_BORDER, MENU_LEGEND_BORDER, MENU_WIDTH, menuHeight);
        
        int x = MENU_LEGEND_BORDER + 2;
        int y = MENU_LEGEND_BORDER + 4;
        
        if (NSPointInRect(mouse, self.bounds))
        {
            self->selectedPlot = NO_SELECTION;

            NSColor* c1 = self->unselectedColor;
            if (NSPointInRect(mouse, NSMakeRect(x, y + MENU_MOUSE_ADJ, MENU_WIDTH - MENU_LEGEND_BORDER, LARGE_FONT_LINE_HEIGHT)))
            {
                c1 = self->selectedColor;
                self->selectedPlot = FLIP_AS;
            }

            if (self->scrollMode == AutoScrollOff)
            {
                drawText("Enable AS", x, y, self->titleFont, self->gridLineScaleFactor, c1);
            }
            else
            {
                drawText("Disable AS", x, y, self->titleFont, self->gridLineScaleFactor, c1);
            }
            
            y += LARGE_FONT_LINE_HEIGHT;
            
            c1 = self->unselectedColor;
            if (NSPointInRect(mouse, NSMakeRect(x, y + MENU_MOUSE_ADJ, MENU_WIDTH - MENU_LEGEND_BORDER, LARGE_FONT_LINE_HEIGHT)))
            {
                c1 = self->selectedColor;
                self->selectedPlot = FLIP_LEGEND;
            }
            if (self->legendOn)
            {
                drawText("Legend Off", x, y, self->titleFont, self->gridLineScaleFactor, c1);
            }
            else
            {
                drawText("Legend On", x, y, self->titleFont, self->gridLineScaleFactor, c1);
            }
            
            int i = 0;
            for (JZWPlot* plot in self->plots)
            {
                y += LARGE_FONT_LINE_HEIGHT;
                
                NSColor* c2 = self->unselectedColor;
                if (NSPointInRect(mouse, NSMakeRect(x, y + MENU_MOUSE_ADJ, MENU_WIDTH - MENU_LEGEND_BORDER, LARGE_FONT_LINE_HEIGHT)))
                {
                    c2 = self->selectedColor;
                    self->selectedPlot = i;
                }
                
                if (plot.hidden)
                {
                    drawText("Show", x, y, self->titleFont, self->gridLineScaleFactor, c2);
                }
                else
                {
                    drawText("Hide", x, y, self->titleFont, self->gridLineScaleFactor, c2);
                }
                
                glColor3f(pointColors[i * 3 + 0], pointColors[i * 3 + 1], pointColors[i * 3 + 2]);
                glRectf(x + LEGEND_COLOR_BOX_WIDTH,      y + LEGEND_COLOR_Y1_ADJ,
                        MENU_COLOR_WIDTH + MENU_COLOR_X2_ADJ,  y + LEGEND_COLOR_Y2_ADJ);
                
                if (!plot.hidden)
                {
                    char valueString[MAX_TICK_LABEL_LENGTH];
                    sprintf(valueString, "(%.5E, %.5E)", points[i].x, points[i].y);
                    drawText(valueString, 100, y + 1, self->axisLabelFont, self->gridLineScaleFactor, c2);
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
        free(pointColors);
    }

#pragma mark ***************************** Draw white border
    
    glLineWidth(1);
    glColor3f(1.0, 1.0, 1.0);
    
    glBegin(GL_LINES);
    glVertex2d(1, 1);
    glVertex2d(width - 1, 1);
    
    glVertex2d(width - 1, 1);
    glVertex2d(width - 1, height - 1);
    
    glVertex2d(width - 1, height - 1);
    glVertex2d(1, height - 1);
    
    glVertex2d(1, height - 1);
    glVertex2d(1, 1);
    glEnd();
    
    
    //*****************************
    
    glFlush();
    [[self openGLContext] unlock];
    
    objc_sync_enter([self openGLContext]);
    self->isDrawing = false;
    objc_sync_exit([self openGLContext]);
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (self->shouldStopGraphing)
    {
        return;
    }
    
    [super drawRect:dirtyRect];
    [self glDraw];
}

- (void)reshape
{
    [self setNeedsDisplay:true];
    [self setNeedsUpdateConstraints:true];
    //[self setRedrawEverything];
}

- (void)update
{
    [[self openGLContext] lock];
    [super update];
    [[self openGLContext] unlock];
}


- (void)setupGL
{
    if (!isSnapshotting) {
        CGRect f = self.frame;
        f.origin.x = 0;
        f.origin.y = 0;
        
        if (self.frame.origin.y < 0)
        {
            f.origin.y = self.frame.origin.y;
        }
        if (self.frame.origin.x < 0)
        {
            f.origin.x = self.frame.origin.x;
        }
        
        [self setupGLWithFrame:f];
    }
    else
    {
        [self setupGLWithFrame:self->snapshotFrame];
    }
}
- (void)setupGLWithFrame:(CGRect)frame
{
    double x = frame.origin.x;
    double y = frame.origin.y;
    
    glViewport(x, y, (GLsizei)frame.size.width, (GLsizei)frame.size.height);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, frame.size.width, 0, frame.size.height, 0, 1);
    glMatrixMode(GL_MODELVIEW);
    glDisable(GL_DEPTH_TEST);
    
    glEnable(GL_LINE_STIPPLE);
    glEnable(GL_POINT_SMOOTH);
    glHint(GL_POINT_SMOOTH_HINT, GL_NICEST);
    glEnable (GL_BLEND);
    glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);
    
    /*
    glUseProgram(self->program);
    glUniform1f(self->constantLocX, 0.0);
    glUniform1f(self->multiplierLocX, 1.0);
    glUniform1f(self->constantLocY, 0.0);
    glUniform1f(self->multiplierLocY, 1.0);
     */
    
    //glEnable(GL_MULTISAMPLE);
    //glHint (GL_MULTISAMPLE_FILTER_HINT_NV, GL_NICEST);
}

- (void)prepareOpenGL
{
    [super prepareOpenGL];
    [self setupGL];
}

- (void)setTransform
{
    CGRect frame = self.frame;
    if (NSIsEmptyRect(frame))
    {
        return;
    }
    
    double xs = (frame.size.width) / (self->xMax - self->xMin);
    double ys = (frame.size.height) / (self->yMax - self->yMin);
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
        return false;
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
        JZWPlot* plot = (JZWPlot*)[self->plots objectAtIndex:i];
        updated |= [plot update:4096] && (plot.avgNum > 1);
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
            }
        });
    }
    
    [self glDraw];
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
    
    unsigned long i;
    NSRect b = NSMakeRect(-10, -10, 20, 20);
    
    for (i = 0; i < self->plots.count; i++)
    {
        JZWPlot* plot = ((JZWPlot*)[self->plots objectAtIndex:i]);
        if (!plot.hidden)
        {
            b = [plot.plot getBoundsWithPrecision:self->boundsPrecision];
            break;
        }
    }
    if (i == self->plots.count)
    {
        return;
    }
    
    for (; i < self->plots.count; i++)
    {
        JZWPlot* plot = ((JZWPlot*)[self->plots objectAtIndex:i]);
        if (!plot.hidden)
        {
            NSRect bounds = [plot.plot getBoundsWithPrecision:self->boundsPrecision];
            b = NSUnionRect(b, bounds);
        }
    }
    b = NSInsetRect(b, b.size.width * -0.1, b.size.height * -0.1);

    double total = fabs(b.origin.x) + fabs(b.origin.y) + fabs(b.size.width) + fabs(b.size.height);
        
    if (isnan(total) || total == INFINITY || total == -INFINITY || total == 0 || b.size.width == 0 || b.size.height == 0)
    {
        return;
    }
    
    self->xMin = b.origin.x;
    self->xMax = b.origin.x + b.size.width;
    self->yMin = b.origin.y;
    self->yMax = b.origin.y + b.size.height;
    
    [self setRedrawEverything];
}

- (void)viewWillStartLiveResize
{
    //self->cachedScreenshot = [self image];
    //[self setRedrawEverything];
}

- (void)viewDidEndLiveResize
{
    //self->cachedScreenshot = nil;
    //[self setRedrawEverything];
}

- (void)addPlot:(JZWPlot *)plot
{
    [self->plots addObject:plot];
    self->maxPlotNameLength = (int)([plot.name length] > (unsigned long)self->maxPlotNameLength ? [plot.name length] : self->maxPlotNameLength);
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
- (void)touchesMovedWithEvent:(NSEvent *)event
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
    double dx = -event.deltaX / self->xScale;
    double dy = event.deltaY / self->yScale;
    
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
    double dx = -event.deltaX / self->xScale * 2;
    double dy = event.deltaY / self->yScale * 2;
    
    self->xMin += dx;
    self->xMax += dx;
    self->yMin += dy;
    self->yMax += dy;
    
    self->currentlyScrolling = 3;
    [self setRedrawEverything];
}

- (void)zoomX:(double)xmag zoomY:(double)ymag
{
    double w = (self->xMax - self->xMin);
    double h = (self->yMax - self->yMin);
    
    NSPoint mouse = [self convertPoint:[self.window mouseLocationOutsideOfEventStream] fromView:nil];
    
    double mxFrac = mouse.x / self.frame.size.width;
    double myFrac = mouse.y / self.frame.size.height;
    
    self->xMin += w * xmag * mxFrac / 2;
    self->xMax -= w * xmag * (1 - mxFrac) / 2;
    self->yMin += h * ymag * myFrac / 2;
    self->yMax -= h * ymag * (1 - myFrac) / 2;
    
    self->currentlyScrolling = 3;
    [self setRedrawEverything];
}

- (void) magnifyWithEvent: (NSEvent*) event
{
    double mag = event.magnification * 1.5;
    
    double w = (self->xMax - self->xMin);
    double h = (self->yMax - self->yMin);
    
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
    double dx = fabs(pos0.x - pos1.x);
    double dy = fabs(pos0.y - pos1.y);
    
    double hypotenuse = sqrt(dx * dx + dy * dy);
    
    double xmag = mag * dx / hypotenuse;
    double ymag = mag * dy / hypotenuse;
    
    double mxFrac = mouse.x / self.frame.size.width;
    double myFrac = mouse.y / self.frame.size.height;
    
    self->xMin += w * xmag * mxFrac / 2;
    self->xMax -= w * xmag * (1 - mxFrac) / 2;
    self->yMin += h * ymag * myFrac / 2;
    self->yMax -= h * ymag * (1 - myFrac) / 2;
    
    self->currentlyScrolling = 3;
    [self setRedrawEverything];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
    self->menuOn = true;
}

- (NSImage*)image
{
    return [self imageWithResolutionMultiplier:1 gridScale:NO uiScale:NO];
}

- (NSImage*)imageWithResolutionMultiplier:(int)numTiles gridScale:(BOOL)scaleGrid uiScale:(BOOL)scaleUI
{
    self->isSnapshotting = YES;
    if (scaleUI)
    {
        self->UIScaleFactor = numTiles;
    }
    if (scaleGrid)
    {
        self->gridLineScaleFactor = numTiles;
    }
    self->menuOn = NO;
    
    NSRect savedFrame = self.frame;
    NSRect pictureFrame = savedFrame;
    pictureFrame.size.height *= numTiles;
    pictureFrame.size.width *= numTiles;
    self.frame = pictureFrame;

    NSImage* img = [[NSImage alloc] initWithSize:NSMakeSize(pictureFrame.size.width, pictureFrame.size.height)];
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc]
                                  initWithBitmapDataPlanes:NULL
                                  pixelsWide:savedFrame.size.width
                                  pixelsHigh:savedFrame.size.height
                                  bitsPerSample:8
                                  samplesPerPixel:4
                                  hasAlpha:YES
                                  isPlanar:NO
                                  colorSpaceName:NSCalibratedRGBColorSpace
                                  bytesPerRow:4 * savedFrame.size.width
                                  bitsPerPixel:32
                                  ];
    
    for (int x = 0; x < numTiles; x++)
    {
        for (int y = 0; y < numTiles; y++)
        {
            CGRect drawFrame = CGRectMake(-x * savedFrame.size.width, -y * savedFrame.size.height, savedFrame.size.width, savedFrame.size.height);
            self->snapshotFrame = drawFrame;
            self->snapshotFrame.size.width *= numTiles;
            self->snapshotFrame.size.height *= numTiles;
            [self setRedrawEverything];
            [self glDraw];
            
            // This call is crucial, to ensure we are working with the correct context
            [[self openGLContext] makeCurrentContext];
            
            //Your code to use the contents
            glReadPixels(0, 0, savedFrame.size.width, savedFrame.size.height,
                         GL_RGBA, GL_UNSIGNED_BYTE, [imageRep bitmapData]);
            
            [img lockFocus];
            NSAffineTransform* t = [NSAffineTransform transform];
            [t translateXBy:0 yBy:imageRep.pixelsHigh];
            [t scaleXBy:1 yBy:-1];
            [t concat];
            drawFrame.origin.x *= -1;
            [imageRep drawInRect:NSRectFromCGRect(drawFrame)];
            [img unlockFocus];
        }
    }
    
    self.frame = savedFrame;
    self->isSnapshotting = NO;
    self->UIScaleFactor = 1.0;
    self->gridLineScaleFactor = 1.0;
    
    return img;
}

@end
