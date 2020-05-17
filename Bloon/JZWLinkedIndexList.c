//
//  JZWLinkedIndexList.c
//  Bloon
//
//  Created by Jacob Weiss on 8/20/15.
//  Copyright © 2015 Jacob Weiss. All rights reserved.
//

#include "JZWLinkedIndexList.h"
#include <math.h>
#include <stdlib.h>
#include <pthread.h>

inline JZWLinkedIndexIterator* JZWLinkedIndexIterator_new(const int i0, const int i1)
{
    int minI = i0;
    int maxI = i1;
    
    if (i0 > i1)
    {
        minI = i1;
        maxI = i0;
    }
    
    JZWLinkedIndexIterator* lii = (JZWLinkedIndexIterator*)malloc(sizeof(JZWLinkedIndexIterator));
    lii->startIndex = minI;
    lii->endIndex = maxI;
    lii->top = (JZWLinkedIndexList*)malloc((maxI - minI) * sizeof(JZWLinkedIndexList));
    
    JZWLinkedIndexList* lil = lii->top;
    lil->next = NULL;
    lii->previous = lil;
    
    for (int i = maxI - 1; i > minI; i--)
    {
        JZWLinkedIndexList* next = lil + 1;
        next->next = lil;
        lil = next;
    }
    
    lii->previous->next = lil;
    lii->current = lii->top;
    
    return lii;
}

inline void JZWLinkedIndexIterator_destroy(JZWLinkedIndexIterator* lii)
{
    free(lii->top);
    free(lii);
}

/**
 Returns the current index without going to the next index.
 */
inline int JZWLinkedIndexIterator_get(JZWLinkedIndexIterator* lii, int* current)
{
    if (lii->current == NULL)
    {
        return 0;
    }
    else
    {
        *current = (int)(lii->top - lii->current) + lii->endIndex - 1;
        return 1;
    }
}

/**
 When at the end of the range, next() will circle around to the beginning of the list. If the list is empy, it returns nil
 */
inline int JZWLinkedIndexIterator_next(JZWLinkedIndexIterator* lii, int* next)
{
    if (lii->current == NULL)
    {
        return 0;
    }
    else
    {
        lii->previous = lii->current;
        lii->current = lii->current->next;
        
        *next = (int)(lii->top - lii->current) + lii->endIndex - 1;
        return 1;
    }
}

/**
 If called following next(), the index that was returned is removed from the set. Otherwise, behavior is undefined.
 */
inline void JZWLinkedIndexIterator_remove(JZWLinkedIndexIterator* lii)
{
    if (lii->current == lii->previous)
    {
        lii->current = NULL;
        lii->previous = NULL;
    }
    else
    {
        lii->previous->next = lii->current->next;
        lii->current = lii->current->next;
    }
}


