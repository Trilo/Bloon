//
//  JZWStringToNumber.m
//  Bloon
//
//  Created by Jacob Weiss on 8/8/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

#include <stdio.h>
#import "JZWNumberAdditions.h"
#import <objc/runtime.h>
#include <OpenGL/gl.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import <GLUT/GLUT.h>

#define CASE_NUM	case '0': case '1': case '2': case '3': case '4': case '5': case '6': case '7': case '8': case '9':
#define CASE_E		case 'e': case 'E':
#define CASE_DOT	case '.':
#define CASE_SIGN	case '+': case '-':


const char digit_pairs[201] = {
    "00010203040506070809"
    "10111213141516171819"
    "20212223242526272829"
    "30313233343536373839"
    "40414243444546474849"
    "50515253545556575859"
    "60616263646566676869"
    "70717273747576777879"
    "80818283848586878889"
    "90919293949596979899"
};

typedef union
{
    double Double;
    long Long;
} DtoL;

typedef union
{
    float Float;
    int Int;
} FtoI;

char* itostr(int n, int* numChars)
{
    if(n==0)
    {
        char* s = (char*)calloc(2, sizeof(char));
        
        s[0] = '0';
        s[1] = 0;
        
        *numChars = 1;
        
        return s;
    }
    
    int sign = -(n<0);
    unsigned int val = (n^sign)-sign;
    
    int size;
    if(val>=10000)
    {
        if(val>=10000000)
        {
            if(val>=1000000000)
                size=10;
            else if(val>=100000000)
                size=9;
            else
                size=8;
        }
        else
        {
            if(val>=1000000)
                size=7;
            else if(val>=100000)
                size=6;
            else
                size=5;
        }
    }
    else
    {
        if(val>=100)
        {
            if(val>=1000)
                size=4;
            else
                size=3;
        }
        else
        {
            if(val>=10)
                size=2;
            else
                size=1;
        }
    }
    
    size -= sign;
    *numChars = size;
    char* s = (char*)malloc(size * sizeof(char));
    char* c = &s[0];
    if(sign)
        *c='-';
    
    c += size-1;
    while(val>=100)
    {
        int pos = val % 100;
        val /= 100;
        *(short*)(c-1)=*(short*)(digit_pairs+2*pos);
        c-=2;
    }
    while(val>0)
    {
        *c--='0' + (val % 10);
        val /= 10;
    }
    return s;
}

inline float intToFloat(int i)
{
    FtoI fi;
    fi.Int = i;
    return fi.Float;
}

inline double longToDouble(long l)
{
    DtoL dl;
    dl.Long = l;
    return dl.Double;
}

inline int unsignedToSigned(unsigned int num, int numBytes)
{
    int bits = 8 * numBytes;
    
    if (num & (1 << (bits - 1)))
    {
        return (int)(num - (1 << bits));
    }
    
    return num;
}

inline unsigned int signedToUnsigned(int num, int numBytes)
{
    int bits = 8 * numBytes;
    
    if (num & (1 << (bits - 1)))
    {
        return (int)(num + (1 << bits));
    }
    
    return num;
}

inline NSMutableString* intToString(int i)
{
    int numChars = 0;
    char* str = itostr(i, &numChars);
    
    return [[NSMutableString alloc] initWithBytesNoCopy:str length:numChars encoding:NSASCIIStringEncoding freeWhenDone:YES];
}

inline char intToChar(int i)
{
    return (char)i;
}

inline int getSignedIntValue(char* bytes, int numBytes, BOOL lsbyteFirst)
{
    return unsignedToSigned(_getUnsignedIntValue(bytes, numBytes, lsbyteFirst), numBytes);
}

inline unsigned int _getUnsignedIntValue(char* bytes, int numBytes, BOOL lsbyteFirst)
{
    unsigned long num = 0;
    
    if (lsbyteFirst)
    {
        for (int i = 0; i < numBytes; i++)
        {
            num |= (bytes[i] & 0xFF) << (8 * i);
        }
    }
    else
    {
        int be = numBytes - 1;
        for (int i = 0; i < numBytes; i++)
        {
            num |= (bytes[i] & 0xFF) << (8 * (be - i));
        }
    }
    
    return (int)num;
}

/*
 Horrible (but fast?) spagetti code that, given a string that begins with a valid floating point string, returns it's length.
 If the string does not contain a valid floating point number, then it returns <= 0.
*/
inline long lengthOfDouble(char* s)
{
    char* string = s;
    
    switch (*string)
    {
        CASE_SIGN // ±
        {
            switch (*(++string))
            {
                CASE_NUM // ±x
                {
                    switch (*(++string))
                    {
                        CASE_NUM { goto LABEL_0; } // ±xx
                        CASE_DOT { goto LABEL_DOT_0; } // ±x.
                        CASE_E   { goto LABEL_E_0; } // ±xE
                        default: { return (string - s); } // ±x Valid
                    }
                }
                CASE_DOT // ±.
                {
                    switch (*(++string))
                    {
                        CASE_NUM { goto LABEL_DOT_NUM; } // ±.x
                        default: { return (s - string); } // ±. Invalid
                    }
                }
                default: { return (s - string); } // ± Invalid
            }
        }
        CASE_DOT // .
        {
            switch (*(++string))
            {
                CASE_NUM { goto LABEL_DOT_NUM; } // ±.x
                default: { return (s - string); } // . Invalid
            }
        }
        CASE_NUM // x
        {
            LABEL_0:
            switch (*(++string))
            {
                CASE_NUM { goto LABEL_0; } // xx
                CASE_DOT // x.
                {
                    LABEL_DOT_0:
                    switch (*(++string))
                    {
                        CASE_NUM // x.x
                        {
                            switch (*(++string))
                            {
                                CASE_NUM // x.xx
                                {
                                    LABEL_DOT_NUM:
                                    switch (*(++string))
                                    {
                                        CASE_NUM { goto LABEL_DOT_NUM; } // x.xxx
                                        CASE_E   { goto LABEL_E_0; } // x.xxE
                                        default: { return (string - s); } // x.xx Valid
                                    }
                                }	
                                CASE_E   { goto LABEL_E_0; } // x.xxE
                                default: { return (string - s); } // Valid
                            }
                        }		
                        default: { return (string - s); } // x. Valid
                    }
                }
                CASE_E // xE
                {
                    LABEL_E_0:
                    switch (*(++string))
                    {
                        CASE_SIGN // xE±
                        {										
                            switch (*(++string))
                            {
                                CASE_NUM // xE±x
                                {		
                                    LABEL_E_SIGN_NUM:
                                    switch (*(++string))
                                    {
                                        CASE_NUM { goto LABEL_E_SIGN_NUM; } // xE±xx
                                        default: { return (string - s); } // xE±x Valid
                                    }
                                }
                                default: { return (s - string); } // xEx± Invalid
                            }
                        }
                        CASE_NUM // xEx
                        {
                            LABEL_E_1:
                            switch (*(++string))
                            {
                                CASE_NUM { goto LABEL_E_1; } // xExx
                                default: { return (string - s); } // xEx Valid
                            }
                        }
                        default: { return (s - string); } // xE Invalid
                    }
                }
                default: { return (string - s); }  // x Valid
            }
        }
        default: { return (s - string); } // Invalid
    }
}

inline long lengthOfInt(char* s)
{
    char* string = s;
    
    switch (*string)
    {
        CASE_SIGN // ±
        {
            switch (*(++string))
            {
                CASE_NUM { goto LABEL_0; } // ±x
                default: { return (s - string); } // Invalid
            }
        }
        CASE_NUM // x
        {
            LABEL_0:
            switch (*(++string))
            {
                CASE_NUM { goto LABEL_0; } // xx
                default: { return (string - s); }  // x Valid
            }
        }
        default: { return (s - string); } // Invalid
    }
}

inline BOOL isHexCharacter(char ch)
{
    return (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F') || (ch >= '0' && ch <= '9');
}

inline long lengthOfHexInt(char* s)
{
    char* string = s;
    
    while (isHexCharacter(*(string++)));
    
    return (string - s - 1);
}

NSString* getTypeOfProperty(NSString* property, NSObject* object)
{
    objc_property_t p = class_getProperty([object class], [property cStringUsingEncoding:NSUTF8StringEncoding]);
    if (p == NULL)
    {
        return nil;
    }
    const char * type = property_getAttributes(p);
    NSString * typeString = [NSString stringWithUTF8String:type];
    NSArray * attributes = [typeString componentsSeparatedByString:@","];
    NSString * typeAttribute = [attributes objectAtIndex:0];
    NSString * propertyType = [typeAttribute substringFromIndex:1];
    const char * rawPropertyType = [propertyType UTF8String];
        
    if (strcmp(rawPropertyType, @encode(int)) == 0 || (strcmp(rawPropertyType, @encode(long)) == 0))
    {
        return @"Int";
    }
    else if (strcmp(rawPropertyType, @encode(double)) == 0)
    {
        return @"Double";
    }
    else if (strcmp(rawPropertyType, @encode(BOOL)) == 0)
    {
        return @"Bool";
    }
    else
    {
        return @"Object";
    }
}

inline void* get_GLUT_BITMAP_8_BY_13()
{
    return GLUT_BITMAP_8_BY_13;
}

inline void* get_GLUT_BITMAP_9_BY_15()
{
    return GLUT_BITMAP_9_BY_15;
}

inline void c_drawText(char* string, CGFloat x, CGFloat y, void* font, NSColor* color)
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


























