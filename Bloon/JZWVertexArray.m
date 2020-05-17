//
//  JZWVertexArray.m
//  Bloon
//
//  Created by Jacob Weiss on 8/16/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

/*
 In order to draw efficiently with OpenGL, we need to store all of our vertices in a nice packed data structure.
 This vertex array also has 3 distinct features:
 1) It stores a "new vertices" array that can be used to draw more efficiently.
 2) It can maintain a parallel data structure of gaussian-averaged data.
 3) It can create a histogram of its data.
 */

#import "JZWVertexArray.h"
#import "Bloon-Swift.h"

#define HISTOGRAM_SIZE      (3000)
#define HISTOGRAM_ZERO      (HISTOGRAM_SIZE / 2)
#define GROUP_SIZE          (10000)
#define NSPOINT_DIST(a,b)   (fabs(a.x - b.x) + fabs(a.y - b.y))

#define MATH_E (2.71828182845904523536)
#define GAUSSIAN_WIDTH (16)

JZWRect INITIAL_RECT = {{FLT_MAX, FLT_MAX}, {-FLT_MAX, -FLT_MAX}, false, GL_INVALID_VALUE, GL_INVALID_VALUE};

void* crealloc(void* source, int oldLength, int newLength)
{
    void* newArray = (void*)calloc(newLength, 1);
    memcpy(newArray, source, oldLength);
    free(source);
    return newArray;
}

// memsize in bytes
void initMem(void* mem, int memSize, const void* initValue, int elementSize)
{
    char* memCh = (char*)mem;
    for (int i = 0; i < memSize; i += elementSize)
    {
        memcpy(memCh + i, initValue, elementSize);
    }
}
// oldLength and newLength in bytes
void reallocInit(void** source, int oldLength, int newLength, void* initValue, int elementSize)
{
    void* s = *source;
    *source = (void*)realloc(s, newLength);
    char* sourceCh = (char*)(*source) + oldLength;
    initMem(sourceCh, newLength - oldLength, initValue, elementSize);
}

@implementation JZWVertexArray
{
    GLdouble* data; // The raw data, stored as {x0,y0,z0,x1,y1,z1,...,xn,yn,zn}
    GLdouble* conv; // The convoluted data (averaged)
    
    JZWVertexArray* color; // The color for each point
    
    int numDims; // The number of dimensions
    
    double* convAdj;    // The amount of each average taken, size equals conv / numDims
    int convArraySpace; // The size (in elements) of the conv array
    int windowSize;     // The size (in elements) of the convolution window
    int maxConvIndex;   // The current highest value the convolution has seen (in number of vertices)
    double* window;     // The actual convolution to perform
    
    int* xHistogram;
    int* yHistogram;
    
    int size;  // The size, in elements, of the data array
    int space; // The space, in elements, of the data array
    JZWRect bounds;
    
    JZWRect* chunkBounds;
    int chunkBoundsSpace;
    
    BOOL* averages;
    
    JZWVertexArray* newVertices;
}

- (JZWRect*)getChunkAtIndex:(int)index
{
    int oldSpace = self->chunkBoundsSpace;
    BOOL needsRealloc = false;
    while (self->chunkBoundsSpace <= index)
    {
        self->chunkBoundsSpace = (self->chunkBoundsSpace + 1) * 2;
        needsRealloc = true;
    }
    if (needsRealloc)
    {
        reallocInit((void**)&(self->chunkBounds), oldSpace * sizeof(JZWRect), self->chunkBoundsSpace * sizeof(JZWRect), &INITIAL_RECT, sizeof(JZWRect));
    }

    return self->chunkBounds + index;
}

// Init the array with an initial size and a number of points to average. If an <= 1, then there will be no averaging.
- (id)initWithSize:(int)s avgNum:(int)an numDims:(int)nd
{
    self = [super init];
    
    if (self)
    {
        self->color = nil;
        
        self->averages = (BOOL*)calloc(nd, sizeof(BOOL));
        for (int i = 0; i < nd; i++)
        {
            self->averages[i] = true;
        }
        
        self->numDims = nd;
        self->data = (GLdouble*)malloc(nd * s * sizeof(GLdouble));
        
        self->chunkBoundsSpace = (int)ceil(s / VERTEX_ARRAY_CHUNK_SIZE);
        self->chunkBounds = (JZWRect*)malloc(self->chunkBoundsSpace * sizeof(JZWRect));
        initMem(self->chunkBounds, self->chunkBoundsSpace * sizeof(JZWRect), &INITIAL_RECT, sizeof(JZWRect));
        
        if (an > 1)
        {
            self->windowSize = an;
            
            self->conv = (GLdouble*)calloc(nd * (s + an), sizeof(GLdouble));
            self->convAdj = (double*)calloc((s + an), sizeof(double));
            self->convArraySpace = nd * (s + an);
            
            // Calculate the curve used to average, in this case, a gaussian.
            self->window = (double*)calloc(an, sizeof(double));
            double step = 1.0 / an;
            double total = 0;
            for (int i = 0; i < an; i++)
            {
                double x = step * i;
                double g = pow(MATH_E, -pow(GAUSSIAN_WIDTH * (x - 0.5), 2));
                total += g;
                self->window[i] = g;
            }
            for (int i = 0; i < an; i++)
            {
                self->window[i] /= total;
            }
        }
        else
        {
            self->windowSize = -1;
        }
        
        self->xHistogram = (int*)calloc(HISTOGRAM_SIZE, sizeof(int));
        self->yHistogram = (int*)calloc(HISTOGRAM_SIZE, sizeof(int));
        
        self->size = 0;
        self->space = nd * s;
        
        self->bounds = INITIAL_RECT;
        
        self->newVertices = nil;
        
        self->maxConvIndex = 0;
        
        return self;
    }
    
    return nil;
}

- (void)dealloc
{
    free(self->data);
    free(self->xHistogram);
    free(self->yHistogram);
    free(self->chunkBounds);
    if (self->windowSize > 1)
    {
        free(self->conv);
        free(self->window);
        free(self->convAdj);
    }
}

- (void)setAverages:(BOOL*)avgs
{
    memcpy(self->averages, avgs, self->numDims * sizeof(BOOL));
}

- (void)recordNewVertices
{
    self->newVertices = [[JZWVertexArray alloc] initWithSize:1000 avgNum:0 numDims:self->numDims];
    if (self->color)
    {
        NSLog(@"%@", [self->color description]);
        [self->newVertices recordColor];
    }
}
- (void)recordColor
{
    self->color = [[JZWVertexArray alloc] initWithSize:1000 avgNum:self->windowSize numDims:3];
    for (int i = 0; i < 3; i++)
    {
        self->color->averages[i] = true;
    }
    if (self->color && self->newVertices != nil && self->newVertices->color == nil)
    {
        [self->newVertices recordColor];
    }
}

- (void)reset
{
    objc_sync_enter(self);
    self->size = 0;
    self->bounds = INITIAL_RECT;
    initMem(self->chunkBounds, self->chunkBoundsSpace * sizeof(JZWRect), &INITIAL_RECT, sizeof(JZWRect));
    [self->color reset];
    objc_sync_exit(self);
}

void expandRectDim(JZWRect *r, int dim, GLdouble value)
{
    if (dim >= 2) return;
    
    void (*expand[2]) (JZWRect*, GLdouble) = {&expandRectX, &expandRectY};
    expand[dim](r, value);
}

void expandRectX(JZWRect* r, GLdouble x)
{
    double x1 = r->origin.x;
    double x2 = x1 + r->size.width;
    
    if (x < x1)
    {
        x1 = x;
    }
    if (x > x2)
    {
        x2 = x;
    }
    
    r->origin.x = x1;
    r->size.width = x2 - x1;
    r->modified = true;
}
void expandRectY(JZWRect* r, GLdouble y)
{
    double y1 = r->origin.y;
    double y2 = y1 + r->size.height;
    
    if (y < y1)
    {
        y1 = y;
    }
    if (y > y2)
    {
        y2 = y;
    }
    
    r->origin.y = y1;
    r->size.height = y2 - y1;
    r->modified = true;
}

JZWRect expandRectToIncludePoint(JZWRect r, GLdouble x, GLdouble y)
{    
    expandRectX(&r, x);
    expandRectY(&r, y);
    return r;
}

- (void)appendVertex:(GLdouble*)vertex atIndex:(int)index
{
    [self appendVertex:vertex atIndex:index withColor:nil];
}

- (void)appendVertex:(GLdouble*)vertex atIndex:(int)index withColor:(GLdouble*)colorVec
{
    objc_sync_enter(self);
    [self->color appendVertex:colorVec atIndex:index];
    
    if (self->size + self->numDims + self->windowSize >= self->space)
    {
        // Double the sizes of the data and bounds arrays
        self->data = realloc(self->data, 2 * self->space * sizeof(GLdouble));
        self->space *= 2;
    }
    
    GLdouble x = vertex[0];
    GLdouble y = vertex[1];
    
    // Expand the bounds to include the new point
    self->bounds = expandRectToIncludePoint(self->bounds, x, y);
    if (self->windowSize <= 1)
    {
        JZWRect* currentChunk = [self getChunkAtIndex:self->size / self->numDims / VERTEX_ARRAY_CHUNK_SIZE];
        *currentChunk = expandRectToIncludePoint(*currentChunk, x, y);
    }

    for (int i = 0; i < self->numDims; i++)
    {
        self->data[self->size++] = vertex[i];
    }
    
    GLdouble newVert[self->numDims];
    memcpy(newVert, vertex, self->numDims * sizeof(GLdouble));
    
    // Handle all the averaging
    if (self->windowSize > 1)
    {
        if (index > self->maxConvIndex)
        {
            self->maxConvIndex = index;
        }
        
        int sizeNeeded = (index + self->windowSize) * self->numDims;
        if (sizeNeeded >= self->convArraySpace / self->numDims)
        {
            int newSize = sizeNeeded * 10;
            self->conv = (GLdouble*)crealloc(self->conv, self->convArraySpace * sizeof(GLdouble), newSize * sizeof(GLdouble));
            self->convAdj = (double*)crealloc(self->convAdj, self->convArraySpace / self->numDims * sizeof(double), newSize / self->numDims * sizeof(double));
            self->convArraySpace = newSize;
        }
        
        int realMin = floor(index - self->windowSize / 2.0); // Half the window is to the left of index
        int max = floor(index + self->windowSize / 2.0); // Half the window is to the right of index
        int min = (realMin < 0) ? 0 : realMin;
        
        for (int i = min; i < max; i++)
        {
            double gauss = self->window[i - min];
            double currentAvgNum = self->convAdj[i];
            self->convAdj[i] += gauss;
            JZWRect* chnkBnd = [self getChunkAtIndex:i / VERTEX_ARRAY_CHUNK_SIZE];
            
            for (int d = 0; d < self->numDims; d++)
            {
                if (self->averages[d])
                {
                    GLdouble current = self->conv[self->numDims * i + d];
                    double tmp = (current * currentAvgNum + vertex[d] * gauss) / self->convAdj[i];
                    self->conv[self->numDims * i + d] = tmp;
                    expandRectDim(chnkBnd, d, tmp);
                }
            }
        }
        
        JZWRect* chnkBnd = [self getChunkAtIndex:index / VERTEX_ARRAY_CHUNK_SIZE];
        for (int d = 0; d < self->numDims; d++)
        {
            if (!self->averages[d])
            {
                self->conv[self->numDims * index + d] = vertex[d];
                expandRectDim(chnkBnd, d, vertex[d]);
            }
        }
        
        for (int d = 0; d < self->numDims; d++)
        {
            newVert[d] = self->conv[self->numDims * index + d];
        }
    }
    
    if (self->newVertices)
    {
        if (self->newVertices->color)
        {
            [self->newVertices appendVertex:newVert atIndex:-1 withColor:colorVec];
        }
        else
        {
            [self->newVertices appendVertex:newVert atIndex:-1];
        }
    }
    
    objc_sync_exit(self);
}

- (GLdouble*)getVertices
{
    return self->data;
}

- (NSRect)getBounds
{
    return NSMakeRect(self->bounds.origin.x, self->bounds.origin.y, self->bounds.size.width, self->bounds.size.height);
}

- (NSRange)getOneDimensionalBoundsWithPrecision:(double)precision histogram:(int*)histogram
{
    assert(self->numDims == 2);
    
    int minStart = 0;
    int minEnd = HISTOGRAM_SIZE;
    
    int start = 0;
    int end = 0;
    
    int points = 0;
    bool isMovingEnd = true;
    
    while (1)
    {
        if (isMovingEnd)
        {
            if (end >= HISTOGRAM_SIZE)
            {
                isMovingEnd = !isMovingEnd;
                continue;
            }
            // Move the end forward until the range contains enough points
            if (2 * (double)points / self->size > precision)
            {
                if (end - start < minEnd - minStart)
                {
                    minStart = start;
                    minEnd = end;
                }
                isMovingEnd = !isMovingEnd;
            }
            points += histogram[end++];
        }
        else
        {
            // Move the start forward until the range is too small
            if (2 * (double)points / self->size > precision)
            {
                if (end - start < minEnd - minStart)
                {
                    minStart = start;
                    minEnd = end;
                }
            }
            else
            {
                if (end >= HISTOGRAM_SIZE)
                {
                    break;
                }
                isMovingEnd = !isMovingEnd;
            }
            points -= histogram[start++];
        }
    }
    
    return NSMakeRange(minStart, minEnd - minStart);
}

- (void)createHistogramsWithBounds:(JZWRect)b
{
    assert(self->numDims == 2);
    
    double xCenter = (2 * b.origin.x + b.size.width) / 2;
    double yCenter = (2 * b.origin.y + b.size.height) / 2;
    
    double xScale = b.size.width / HISTOGRAM_SIZE;
    double yScale = b.size.height / HISTOGRAM_SIZE;
    
    for (int i = 0; i < HISTOGRAM_SIZE; i++)
    {
        self->xHistogram[i] = 0;
        self->yHistogram[i] = 0;
    }
    
    objc_sync_enter(self);
    for (int i = 0; i < self->size / 2; i++)
    {
        int x = (int)((self->data[2 * i] - xCenter) / xScale) + HISTOGRAM_ZERO;
        int y = (int)((self->data[2 * i + 1] - yCenter) / yScale) + HISTOGRAM_ZERO;
        
        if (x >= HISTOGRAM_SIZE)
        {
            x = HISTOGRAM_SIZE - 1;
        }
        else if (x < 0)
        {
            x = 0;
        }
        if (y >= HISTOGRAM_SIZE)
        {
            y = HISTOGRAM_SIZE - 1;
        }
        else if (y < 0)
        {
            y = 0;
        }
        
        self->xHistogram[x]++;
        self->yHistogram[y]++;
    }
    objc_sync_exit(self);
}

- (NSRect)getBoundsWithPrecision:(double)precision
{
    assert(self->numDims == 2);

    JZWRect b = self->bounds;
    
    double xCenter = (2 * b.origin.x + b.size.width) / 2;
    double yCenter = (2 * b.origin.y + b.size.height) / 2;
    
    double xScale = b.size.width / HISTOGRAM_SIZE;
    double yScale = b.size.height / HISTOGRAM_SIZE;
    
    [self createHistogramsWithBounds:b];
    
    NSRange xRange = [self getOneDimensionalBoundsWithPrecision:precision histogram:self->xHistogram];
    NSRange yRange = [self getOneDimensionalBoundsWithPrecision:precision histogram:self->yHistogram];
    
    long xStart = xRange.location;// - 1;
    long xEnd   = xRange.location + xRange.length;// + 2;
    
    long yStart = yRange.location;// - 1;
    long yEnd   = yRange.location + yRange.length;// + 2;
    
    double x = (xStart - HISTOGRAM_ZERO) * xScale + xCenter;
    double y = (yStart - HISTOGRAM_ZERO) * yScale + yCenter;
    double width = (xEnd - HISTOGRAM_ZERO) * xScale + xCenter - x;
    double height = (yEnd - HISTOGRAM_ZERO) * yScale + yCenter - y;
    
    if (width == 0)
    {
        x -= 0.5;
        width = 1;
    }
    if (height == 0)
    {
        y -= 0.5;
        height = 1;
    }
    
    return NSMakeRect(x, y, width, height);
}

- (void)getVertices:(VertexProcessingBlock)processVertices
{
    if (processVertices == NULL)
    {
        return;
    }
    
    GLuint vb = GL_INVALID_VALUE;
    GLuint va = GL_INVALID_VALUE;

    objc_sync_enter(self);
    if (self->windowSize > 1)
    {
        processVertices(self->conv, self->color == nil ? nil : self->color->conv, self->maxConvIndex, &vb, &va, YES);
    }
    else
    {
        processVertices(self->data, self->color == nil ? nil : self->color->data, self->size / self->numDims, &vb, &va, YES);
    }
    objc_sync_exit(self);
}
- (void)getVertices:(VertexProcessingBlock)processVertices inBounds:(JZWRect)rect
{
    if (processVertices == NULL)
    {
        return;
    }
    
    [self getVertices:^(GLdouble *verts, GLdouble *colors, int nv, GLuint *vertexBuffer, GLuint* vertexArray, BOOL wasModified) {
        int numChunks = nv / VERTEX_ARRAY_CHUNK_SIZE;
        int leftovers = nv % VERTEX_ARRAY_CHUNK_SIZE;

        for (int i = 0; i < numChunks; i++)
        {
            JZWRect* chunkRect = [self getChunkAtIndex:i];
            if (rectIntersectsRect(rect, *chunkRect))
            {
                processVertices(verts + self->numDims * i * VERTEX_ARRAY_CHUNK_SIZE,
                                colors == nil ? nil : colors + 3 * i * VERTEX_ARRAY_CHUNK_SIZE,
                                VERTEX_ARRAY_CHUNK_SIZE,
                                &(chunkRect->vertexBuffer),
                                &(chunkRect->vertexArray),
                                chunkRect->modified);
                chunkRect->modified = false;
            }
        }
        JZWRect* chunkRect = [self getChunkAtIndex:numChunks];
        if (rectIntersectsRect(rect, *chunkRect))
        {
            processVertices(verts + self->numDims * numChunks * VERTEX_ARRAY_CHUNK_SIZE,
                            colors == nil ? nil : colors + 3 * numChunks * VERTEX_ARRAY_CHUNK_SIZE,
                            leftovers,
                            &(chunkRect->vertexBuffer),
                            &(chunkRect->vertexArray),
                            chunkRect->modified);
            chunkRect->modified = false;
        }
    }];
}
- (void)getNewVertices:(VertexProcessingBlock)processVertices
{
    objc_sync_enter(self);
    [self->newVertices getVertices:processVertices];
    [self->newVertices reset];
    objc_sync_exit(self);
}
- (void)resetNewVertices
{
    objc_sync_enter(self);
    [self->newVertices reset];
    objc_sync_exit(self);

}
- (void)getNewVertices:(VertexProcessingBlock)processVertices inBounds:(JZWRect)rect
{
    [self->newVertices getVertices:processVertices inBounds:rect];
    [self->newVertices reset];
}

- (NSPoint)vertexAtIndex:(int)index
{
    assert(self->numDims == 2);

    objc_sync_enter(self);
    int i = index * 2;
    NSPoint p = NSMakePoint(self->data[i], self->data[i + 1]);
    objc_sync_exit(self);
    return p;
}

JZWRect transformRect(JZWRect rect, GLdouble xs, GLdouble ys, GLdouble xt, GLdouble yt)
{
    GLdouble x0 = rect.origin.x;
    GLdouble y0 = rect.origin.y;
    GLdouble x1 = x0 + rect.size.width;
    GLdouble y1 = y0 + rect.size.height;
    
    x0 = (x0 + xt) * xs;
    y0 = (y0 + yt) * ys;
    x1 = (x1 + xt) * xs;
    y1 = (y1 + yt) * ys;
    
    rect.origin.x = x0;
    rect.origin.y = y0;
    rect.size.width = x1 - x0;
    rect.size.height = y1 - y0;
    
    return rect;
}
JZWPoint transformPoint(JZWPoint point, GLdouble xs, GLdouble ys, GLdouble xt, GLdouble yt)
{
    point.x = (point.x + xt) * xs;
    point.y = (point.y + yt) * ys;
    return point;
}
GLdouble distanceFromPointToPoint(JZWPoint p0, JZWPoint p1)
{
    double dx = p0.x - p1.x;
    double dy = p0.y - p1.y;
    return sqrt(dx * dx + dy * dy);
}
bool circleIntersectsRect(JZWPoint circleCenter, double radius, JZWRect rect)
{
    double rectCenterX = rect.origin.x + rect.size.width / 2;
    double rectCenterY = rect.origin.y + rect.size.height / 2;

    double circleDistancex = fabs(circleCenter.x - rectCenterX);
    double circleDistancey = fabs(circleCenter.y - rectCenterY);
    
    if (circleDistancex > (rect.size.width/2 + radius)) { return false; }
    if (circleDistancey > (rect.size.height/2 + radius)) { return false; }
    
    if (circleDistancex <= (rect.size.width/2)) { return true; }
    if (circleDistancey <= (rect.size.height/2)) { return true; }
    
    GLdouble cornerDistance_sq = powf(circleDistancex - rect.size.width / 2, 2) + powf(circleDistancey - rect.size.height / 2, 2);
    
    return (cornerDistance_sq <= (radius * radius));
}
bool rectIntersectsRect(JZWRect ra, JZWRect rb)
{
    double xa0 = ra.origin.x;
    double ya0 = ra.origin.y;
    double xa1 = xa0 + ra.size.width;
    double ya1 = ya0 + ra.size.height;
    double xb0 = rb.origin.x;
    double yb0 = rb.origin.y;
    double xb1 = xb0 + rb.size.width;
    double yb1 = yb0 + rb.size.height;

    return (xa0 < xb1 && xa1 > xb0 && ya0 < yb1 && ya1 > yb0);
}

// Mean run time 0.014585333333333 seconds
/*
- (NSPoint)closestVertexToPoint:(NSPoint)point xs:(GLfloat)xs ys:(GLfloat)ys xt:(GLfloat)xt yt:(GLfloat)yt
{
    __block NSPoint closestRaw;
    
    [self getVertices:^(GLdouble * verts, int numVerts)
     {
         closestRaw = NSMakePoint(verts[0], verts[1]);
         NSPoint closest = transformPoint(point, xs, ys, xt, yt);
         double closestDist = distanceFromPointToPoint(point, closest);
         
         for (int i = 0; i < numVerts; i++)
         {
             NSPoint testRaw = NSMakePoint(verts[i * 2], verts[i * 2 + 1]);
             NSPoint test = transformPoint(testRaw, xs, ys, xt, yt);
             double dist = distanceFromPointToPoint(point, test);
             if (dist < closestDist)
             {
                 closest = test;
                 closestDist = dist;
                 closestRaw = testRaw;
             }
         }
     }];
    
    return closestRaw;
}
*/
// Mean run time 0.00090345555555556 seconds
- (JZWPoint)closestVertexToPoint:(JZWPoint)point xs:(GLdouble)xs ys:(GLdouble)ys xt:(GLdouble)xt yt:(GLdouble)yt color:(GLdouble**)colorOfClosestPoint
{
    assert(self->numDims == 2);

    __block JZWPoint closestDoub;
    __block GLdouble* closestColor;
    
    [self getVertices:^(GLdouble* verts, GLdouble* colors, int nv, GLuint* vb, GLuint* va, BOOL modified) {
        int numChunks = nv / VERTEX_ARRAY_CHUNK_SIZE;
        int leftovers = nv % VERTEX_ARRAY_CHUNK_SIZE;

        double closestDist = DBL_MAX;
        // First run through each chunk and compare the first node of each to the search point
        for (int i = 0; i < numChunks; i++)
        {
            JZWPoint raw = {verts[i * 2 * VERTEX_ARRAY_CHUNK_SIZE], verts[i * 2 * VERTEX_ARRAY_CHUNK_SIZE + 1]};
            JZWPoint test = transformPoint(raw, xs, ys, xt, yt);
            double dist = distanceFromPointToPoint(point, test);
            if (dist < closestDist)
            {
                closestDoub = raw;
                closestDist = dist;
                closestColor = colors + (i * 3 * VERTEX_ARRAY_CHUNK_SIZE);
            }
        }
        
        for (int i = 0; i < numChunks; i++)
        {
            JZWRect b = *[self getChunkAtIndex:i];
            b = transformRect(b, xs, ys, xt, yt);
            if (circleIntersectsRect(point, closestDist, b))
            {
                GLdouble* chunk = verts + VERTEX_ARRAY_CHUNK_SIZE * i * 2;
                for (int j = 0; j < VERTEX_ARRAY_CHUNK_SIZE; j++)
                {
                    JZWPoint testRaw = {chunk[2 * j], chunk[2 * j + 1]};
                    JZWPoint test = transformPoint(testRaw, xs, ys, xt, yt);
                    double dist = distanceFromPointToPoint(point, test);
                    if (dist < closestDist)
                    {
                        closestDoub = testRaw;
                        closestDist = dist;
                        closestColor = colors + (i * 3 * VERTEX_ARRAY_CHUNK_SIZE) + (j * 3);
                    }
                }
            }
        }
        JZWRect b = *[self getChunkAtIndex:numChunks];
        b = transformRect(b, xs, ys, xt, yt);
        if (circleIntersectsRect(point, closestDist, b))
        {
            GLdouble* chunk = verts + VERTEX_ARRAY_CHUNK_SIZE * numChunks * 2;
            for (int j = 0; j < leftovers; j++)
            {
                JZWPoint testRaw = {chunk[2 * j], chunk[2 * j + 1]};
                JZWPoint test = transformPoint(testRaw, xs, ys, xt, yt);
                double dist = distanceFromPointToPoint(point, test);
                if (dist < closestDist)
                {
                    closestDoub = testRaw;
                    closestDist = dist;
                    closestColor = colors + (numChunks * 3 * VERTEX_ARRAY_CHUNK_SIZE) + (j * 3);
                }
            }
        }
        
        *colorOfClosestPoint = colors ? closestColor : nil;
    }];
    
    return closestDoub;
}

- (int)length
{
    return self->size / self->numDims;
}

@end















