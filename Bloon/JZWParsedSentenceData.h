//
//  JZWParsedSentenceData.h
//  Bloon
//
//  Created by Jacob Weiss on 2/11/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

#ifndef JZWParsedSentenceData_h
#define JZWParsedSentenceData_h

#include <stdio.h>

typedef enum
{
    ParsingState_Unparsed = 0,
    ParsingState_Parsing = 1,
    ParsingState_Parsed = 2
} ParsingState;

typedef struct
{
    unsigned int index; // 4 bytes
    char state; // 1 byte
    double parsedNumericValuesArray; // 8 bytes * number of parsed values (this is secretly a variable sized array. The first element is always the timestamp)
} JZWParsedSentenceData;

JZWParsedSentenceData* JZWParsedSentenceData_new(unsigned int index, double timeStamp, unsigned int numParsedValues);

unsigned int JZWParsedSentenceData_getIndex(JZWParsedSentenceData* d);
void JZWParsedSentenceData_setIndex(JZWParsedSentenceData* d, unsigned int index);

double JZWParsedSentenceData_getTimeStamp(JZWParsedSentenceData* d);

ParsingState JZWParsedSentenceData_getState(JZWParsedSentenceData* d);
void JZWParsedSentenceData_setState(JZWParsedSentenceData* d, ParsingState state);

double* JZWParsedSentenceData_getParsedValuesArray(JZWParsedSentenceData* d);

void JZWParsedSentenceData_destroy(JZWParsedSentenceData* d);

#endif // JZWParsedSentenceData_h
