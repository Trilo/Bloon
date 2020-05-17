//
//  JZWVertexArray.h
//  Bloon
//
//  Created by Jacob Weiss on 8/16/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <OpenGL/gl.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>

#define VERTEX_ARRAY_CHUNK_SIZE (8192)

typedef struct
{
    GLdouble x;
    GLdouble y;
} JZWPoint;

typedef struct
{
    GLdouble width;
    GLdouble height;
} JZWSize;

typedef struct
{
    JZWPoint origin;
    JZWSize size;
    BOOL modified;
    GLuint vertexBuffer;
    GLuint vertexArray;
} JZWRect;

typedef void (^VertexProcessingBlock)(GLdouble* vertices, GLdouble* colors, int numVertices, GLuint* vertexBuffer, GLuint* vertexArray, BOOL wasModified);

@interface JZWVertexArray : NSObject

- (id)initWithSize:(int)s avgNum:(int)an numDims:(int)nd;
- (void)appendVertex:(GLdouble*)vertex atIndex:(int)index;
- (void)appendVertex:(GLdouble*)vertex atIndex:(int)index withColor:(GLdouble*)colorVec;

- (GLdouble*)getVertices;
- (void)getVertices:(VertexProcessingBlock)processVertices;
- (void)getVertices:(VertexProcessingBlock)processVertices inBounds:(JZWRect)rect;
- (int)length;
- (NSPoint)vertexAtIndex:(int)index;
- (NSRect)getBounds;
- (NSRect)getBoundsWithPrecision:(double)precision;

- (void)recordNewVertices;
- (void)recordColor;

- (void)getNewVertices:(VertexProcessingBlock)processVertices;
- (void)getNewVertices:(VertexProcessingBlock)processVertices inBounds:(JZWRect)rect;

- (void)setAverages:(BOOL*)avgs;

- (JZWPoint)closestVertexToPoint:(JZWPoint)point xs:(GLdouble)xs ys:(GLdouble)ys xt:(GLdouble)xt yt:(GLdouble)yt color:(GLdouble**)colorOfClosestPoint;

- (void)resetNewVertices;

@end
