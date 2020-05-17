//
//  JZWIndexedDictionaryData.h
//  Bloon
//
//  Created by Jacob Weiss on 2/11/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

#ifndef JZWIndexedDictionaryData_h
#define JZWIndexedDictionaryData_h

#include <stdio.h>
#include <stdlib.h>

typedef struct
{
    void* keysToIndexes;
    void* values;
} JZWIndexedDictionaryData;

JZWIndexedDictionaryData* JZWIndexedDictionaryData_new(void* keysToIndexes, void* values);
void* JZWIndexedDictionaryData_getKeysToIndexes(JZWIndexedDictionaryData* jid);
void* JZWIndexedDictionaryData_getValues(JZWIndexedDictionaryData* jid);

#endif /* JZWIndexedDictionaryData_h */
