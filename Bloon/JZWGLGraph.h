//
//  NSGLGraph.h
//  Bloon
//
//  Created by Jacob Weiss on 8/15/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum
{
    AutoScrollOff,
    AutoScrollTime,
    AutoScrollNew
} AutoScrollMode;

@class JZWPlot;

@interface JZWGLGraph : NSOpenGLView

+ (void)removeGraph:(JZWGLGraph*)graph;

- (id)initWithFrame:(NSRect)frameRect;
- (id)initWithTitle:(NSString*)title;

- (NSString*)graphTitle;

- (void)addPlot:(JZWPlot*)plot;
- (void)updateAsync;
- (void)setBounds;
- (void)zoomX:(double)xmag zoomY:(double)ymag;

- (void)setXMin:(double)_xMin xMax:(double)_xMax xTicks:(int)_xTicks
           yMin:(double)_yMin yMax:(double)_yMax yTicks:(int)_yTicks
    showsLabels:(BOOL)_labels showsGrid:(BOOL)_grid autoTickMarks:(BOOL)_autoTicks showsAxis:(BOOL)_showsAxis scrollMode:(AutoScrollMode)_scrollMode
     labelColor:(NSColor*)_labelColor gridColor:(NSColor*)_gridColor bgColor:(NSColor*)_bgColor axisColor:(NSColor*)_axisColor xAxisDates:(BOOL)_xAxisDates;

- (void)setForceRedraw:(BOOL)forceRedraw;
- (void)setRedrawEverything;

- (BOOL)isUpdating;
- (void)stop;

- (NSImage*) image;
- (NSImage*)imageWithResolutionMultiplier:(int)numTiles gridScale:(BOOL)scaleGrid uiScale:(BOOL)scaleUI;

@end
