//
//  JZWView.h
//  PhotoEditor
//
//  Created by Jacob Weiss on 4/9/13.
//  Copyright (c) 2013 Jacob Weiss. All rights reserved.
//

#import <Cocoa/Cocoa.h>

IB_DESIGNABLE
@interface JZWView : NSView

@property (atomic) BOOL userInteractionEnabled;
@property (atomic) BOOL flipView;
@property (weak) NSView* contentSizeDelegate;

- (NSImage *)imageWithSubviews:(NSView*)v;

@end
