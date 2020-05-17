//
//  JZWView.m
//  PhotoEditor
//
//  Created by Jacob Weiss on 4/9/13.
//  Copyright (c) 2013 Jacob Weiss. All rights reserved.
//

#import "JZWView.h"

@implementation JZWView

- (id)init
{
    self = [super init];
    
    if (self)
    {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.userInteractionEnabled = YES;
        self.flipView = NO;
    }
    
    return self;
}

- (BOOL)isFlipped
{
    return self.flipView;
}

/*
- (NSView *)hitTest:(NSPoint)aPoint
{
    if (!self.userInteractionEnabled)
    {
        return nil;
    }
    return [super hitTest:aPoint];
}
*/

- (NSSize)intrinsicContentSize
{
    __strong NSView *csd = self.contentSizeDelegate;
    if (csd)
    {
        return csd.intrinsicContentSize;
    }
    else
    {
        return [super intrinsicContentSize];
    }
}

- (NSImage *)imageWithSubviews:(NSView*)v
{
    NSBitmapImageRep *bir = [v bitmapImageRepForCachingDisplayInRect:v.bounds];
    //[bir setSize:v.bounds.size];
    NSImage* image = [[NSImage alloc] initWithSize:v.bounds.size];
    [image addRepresentation:bir];
    
    //[v cacheDisplayInRect:[v bounds] toBitmapImageRep:bir];
    
    [self cacheAllSubviewsOfView:v subview:v toImage:image];
    
    return image;
}

- (void)cacheAllSubviewsOfView:(NSView*)view subview:(NSView*)subview toImage:(NSImage*)image
{
    if (!subview.isHidden)
    {
        NSBitmapImageRep* bir = [subview bitmapImageRepForCachingDisplayInRect:subview.bounds];
        [subview cacheDisplayInRect:subview.bounds toBitmapImageRep:bir];
        NSImage* subImage = [[NSImage alloc] initWithSize:subview.bounds.size];
        [subImage addRepresentation:bir];
        
        [image lockFocus];
        [subImage drawInRect:[view convertRect:subview.bounds fromView:subview] fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
        [image unlockFocus];
    }
    
    for (NSView* v in subview.subviews)
    {
        if (!v.isHidden)
        {
            [self cacheAllSubviewsOfView:view subview:v toImage:image];
        }
    }
}

@end
