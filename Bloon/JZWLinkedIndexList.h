//
//  JZWLinkedIndexList.h
//  Bloon
//
//  Created by Jacob Weiss on 8/20/15.
//  Copyright © 2015 Jacob Weiss. All rights reserved.
//

#ifndef JZWLinkedIndexList_h
#define JZWLinkedIndexList_h

#include <stdio.h>

typedef struct JZWLinkedIndexList
{
    struct JZWLinkedIndexList* next;
} JZWLinkedIndexList;

/**
 JZWLinkedIndexIterator
 
 This class provides an efficient mechanism for looping through a range of integers while simultaneously removing them from the range. The integers in the range are not guaranteed to be provided in any particular order.
 */
typedef struct JZWLinkedIndexIterator
{
    int startIndex;
    int endIndex;
    JZWLinkedIndexList* top;
    JZWLinkedIndexList* current;
    JZWLinkedIndexList* previous;
} JZWLinkedIndexIterator;

/**
 Crate a new iterator that goes from [ min(i0,i1), max(i0,i1) )
 */
JZWLinkedIndexIterator* JZWLinkedIndexIterator_new(const int i0, const int i1);

void JZWLinkedIndexIterator_destroy(JZWLinkedIndexIterator* lii);

/**
 Returns the current index without going to the next index.
 */
int JZWLinkedIndexIterator_get(JZWLinkedIndexIterator* lii, int* current);

/**
 When at the end of the range, next() will circle around to the beginning of the list. If the list is empy, it returns nil
 */
int JZWLinkedIndexIterator_next(JZWLinkedIndexIterator* lii, int* next);


/**
 If called following next(), the index that was returned is removed from the set. Otherwise, behavior is undefined.
 */
void JZWLinkedIndexIterator_remove(JZWLinkedIndexIterator* lii);


#endif /* JZWLinkedIndexList_h */
