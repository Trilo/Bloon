//
//  JZWParsedSentenceData.c
//  Bloon
//
//  Created by Jacob Weiss on 2/11/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

#include "JZWParsedSentenceData.h"
#include <stdlib.h>

JZWParsedSentenceData* JZWParsedSentenceData_new(unsigned int index, double timeStamp, unsigned int numParsedValues)
{
    JZWParsedSentenceData* d = (JZWParsedSentenceData*)malloc(sizeof(JZWParsedSentenceData) + (numParsedValues - 1) * sizeof(double) * 2);
    d->index = index;
    d->parsedNumericValuesArray = timeStamp;
    d->state = ParsingState_Unparsed;

    return d;
}

unsigned int JZWParsedSentenceData_getIndex(JZWParsedSentenceData* d)
{
    return d->index;
}
void JZWParsedSentenceData_setIndex(JZWParsedSentenceData* d, unsigned int index)
{
    d->index = index;
}
double JZWParsedSentenceData_getTimeStamp(JZWParsedSentenceData* d)
{
    return d->parsedNumericValuesArray;
}
double* JZWParsedSentenceData_getParsedValuesArray(JZWParsedSentenceData* d)
{
    return &(d->parsedNumericValuesArray);
}
ParsingState JZWParsedSentenceData_getState(JZWParsedSentenceData* d)
{
    return d->state;
}
void JZWParsedSentenceData_setState(JZWParsedSentenceData* d, ParsingState state)
{
    d->state = state;
}
void JZWParsedSentenceData_destroy(JZWParsedSentenceData* d)
{
    free(d);
}