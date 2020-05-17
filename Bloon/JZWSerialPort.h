//
//  JZWSerialPort.h
//  Bloon
//
//  Created by Jacob Weiss on 8/3/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JZWSerialPort : NSObject

- (id)init;
- (void)close;
- (int)openPort:(NSString*)port baud:(int)baud readBlock:(void (^)(NSFileHandle* handle))readBlock;

@end
