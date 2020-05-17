//
//  JZWIndexedDictionaryData.c
//  Bloon
//
//  Created by Jacob Weiss on 2/11/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

#include "JZWIndexedDictionaryData.h"


JZWIndexedDictionaryData* JZWIndexedDictionaryData_new(void* keysToIndexes, void* values)
{
    JZWIndexedDictionaryData* d = (JZWIndexedDictionaryData*)malloc(sizeof(JZWIndexedDictionaryData));
    d->keysToIndexes = keysToIndexes;
    d->values = values;
    return d;
}

void* JZWIndexedDictionaryData_getKeysToIndexes(JZWIndexedDictionaryData* jid)
{
    return jid->keysToIndexes;
}
void* JZWIndexedDictionaryData_getValues(JZWIndexedDictionaryData* jid)
{
    return jid->values;
}