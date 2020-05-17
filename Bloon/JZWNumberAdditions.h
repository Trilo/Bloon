//
//  JZWStringToNumber.h
//  Bloon
//
//  Created by Jacob Weiss on 8/8/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

float intToFloat(int i);
double longToDouble(long l);
int unsignedToSigned(unsigned int num, int numBytes);
unsigned int signedToUnsigned(int num, int numBytes);
NSMutableString* intToString(int i);
char intToChar(int i);
int getSignedIntValue(char* bytes, int numBytes, BOOL lsbyteFirst);
unsigned int _getUnsignedIntValue(char* bytes, int numBytes, BOOL lsbyteFirst);
long lengthOfDouble(char* s);
long lengthOfInt(char* s);
BOOL isHexCharacter(char ch);
long lengthOfHexInt(char* s);
NSString* getTypeOfProperty(NSString* property, NSObject* object);

inline void* get_GLUT_BITMAP_8_BY_13(void);
inline void* get_GLUT_BITMAP_9_BY_15(void);
void c_drawText(char* string, CGFloat x, CGFloat y, void* font, NSColor* color);

inline void atomicSet(void** target, void* new_value);
