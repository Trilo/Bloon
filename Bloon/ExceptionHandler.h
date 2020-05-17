//
//  ExceptionHandler.h
//  Bloon
//
//  Created by Jacob Weiss on 5/22/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

// From http://stackoverflow.com/questions/34956002/how-to-properly-handle-nsfilehandle-exceptions-in-swift-2-0

#ifndef ExceptionHandler_h
#define ExceptionHandler_h

//
//  ExceptionCatcher.h
//

#import <Foundation/Foundation.h>

NS_INLINE NSException * _Nullable tryBlock(void(^_Nonnull tryBlock)(void)) {
    @try {
        tryBlock();
    }
    @catch (NSException *exception) {
        return exception;
    }
    return nil;
}

#endif /* ExceptionHandler_h */
