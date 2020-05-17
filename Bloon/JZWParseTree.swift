//
//  JZWParseTree.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/3/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa

@inline(__always) func +<T>(lhs : Array<T>?, rhs : Array<T>?) -> Array<T>?
{
    switch (lhs, rhs)
    {
    case (nil, nil):
        return nil
    case (let vb, nil):
        return vb
    case (nil, let cb):
        return cb
    case (let vb, let cb):
        return vb! + cb!
    }
}

class JZWParseTree
{
    weak var parent: JZWParseTree?
    weak var root: JZWToken!
    var children: [JZWParseTree]?
    var sentences: [JZWSentence]
    
    init(root: JZWToken, children: [JZWParseTree]?, sentences: [JZWSentence])
    {
        self.root = root
        self.children = children
        self.sentences = sentences
                
        if (self.children != nil)
        {
            for tree in self.children!
            {
                tree.parent = self
            }
        }
    }
    
    func errorReport() -> String
    {
        var errors = self.root.errorReport()
        if let childs = self.children
        {
            for child in childs
            {
                errors = "\(errors)\r\n\(child.errorReport())"
            }
        }
        return errors
    }
    
    func parse(_ data: JZWData, start: Int, index: Int) -> (parsedSentence: JZWParsedSentencePointer?, sentence: JZWSentence?, increment: Int, validBlocks: [() -> Void]?)
    {
        // Check to see if the current token is pointing to valid data
        // valid = whether or not the token is valid
        // bytesRead = the number of bytes that the token consumed if valid, or the number that should be skipped if invalid
        // validBlocks = closures that should be executed if this is a valid sentence.
        let (valid, bytesRead, validBlocks) = self.root.dataIsValid(data, start: start, index: index, end: Int(data.length()) - 1)
    
        if valid
        {
            // If we have children, then continue parsing
            if let children = self.children
            {
                // Keep track of the minimum increment returned by any of the tokens.
                var mincrement = Int.max
                
                for child in children
                {
                    // Parse the child (recursive)
                    let (parsed, sentence, increment, childBlocks) = child.parse(data, start: start, index: index + bytesRead)
                    
                    if (increment < mincrement)
                    {
                        mincrement = increment
                    }
                    
                    // This is the success path. It mans that we parsed a valid sentence somewhere down the line.
                    if parsed != nil
                    {
                        return (parsed, sentence, increment + bytesRead, validBlocks + childBlocks)
                    }
                }
                
                // This is the failure path. We checked all the children and were unable to match anything.
                // Return the minimum number of bytes that we can increment by.
                return (nil, nil, mincrement, nil)
            }
            // If we have reached the end, then we have a valid sentence.
            else
            {
                // This should never happen, but if it does, print a message and go with it.
                if self.sentences.count > 1
                {
                    Swift.print("Sentence type is indeterminate.")
                }                
                
                let newParsedValue = JZWParsedSentence.new(self.sentences[0], index: index)
                return (newParsedValue, self.sentences[0], bytesRead, validBlocks)
            }
        }
        
        return (nil, nil, bytesRead, nil)
    }
    
    class func build(_ sentences: [JZWSentence], index: Int = 0) -> [JZWParseTree]?
    {
        var groups = [[JZWSentence]]()
        for s in sentences
        {
            if let t = s.getToken(index)
            {
                var added = false

                for i in 0 ..< groups.count
                {
                    let preexistingToken = groups[i][0].getToken(index)!
                    if t.equals(preexistingToken)
                    {
                        t.builtToken = preexistingToken
                        groups[i].append(s)
                        added = true
                        break
                    }
                }
                if (!added)
                {
                    var newGroup = [JZWSentence]()
                    newGroup.append(s)
                    groups.append(newGroup)
                }
            }
        }        
        
        var trees = [JZWParseTree]()

        if groups.isEmpty
        {
            return nil
        }
        
        for group in groups
        {
            let root = group[0].getToken(index)
            trees.append(JZWParseTree(root: root!, children: JZWParseTree.build(group, index: index + 1), sentences: group))
        }
        
        return trees
    }
    
    var description: String
    {
        return self.root.description
    }
    
    func print()
    {
        Swift.print(self.root)
        if self.children != nil
        {
            for child in self.children!
            {
                child.print()
            }
        }
    }
    
    deinit
    {
        self.parent = nil
        self.root = nil
        self.children = []
        self.sentences = []
    }
}
