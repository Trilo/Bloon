//
//  JZWPlot.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/12/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa
import AppKit
import OpenGL

class JZWPlot : NSObject
{
    var startTime : Date = Date()
    
    var plotMode : GraphMode = GraphMode.variable
    
    @objc var name = "Plot12345"
    
    // For GCMathEvaluator
    var gcMathParser = GCMathParser()
    
    var xExpressionGC: NSMutableString
    var xTokens =  NSMutableSet()
    var xSentences = [String : (String, JZWSentence)]()

    var yExpressionGC: NSMutableString
    var yTokens = NSMutableSet()
    var ySentences = [String : (String, JZWSentence)]()

    var conExpressionGC: NSMutableString
    var conTokens = NSMutableSet()
    var conSentences = [String : (String, JZWSentence)]()
    var conditionEval : (_ eval: (String) -> Double) -> (Bool)
    
    var colorExpressionGC: NSMutableString
    var colorTokens = NSMutableSet()
    var colorSentences = [String : (String, JZWSentence)]()
    @objc var colorBar : [[Double]] = [[]] // {{r0, g0, b0}, ..., {rn, gn, bn}}
    @objc var color: NSColor? // If color is nil, then use the color bar
    
    var allSentences = NSMutableSet()
    
    var mostRecentPoint: Int64 = -1
    
    @objc var scatter: Bool
    @objc var line: Bool
    @objc var plot: JZWVertexArray
    @objc var lineWidth: CGFloat = 0
    @objc var pointDim: CGFloat = 1
    @objc var hidden = false
    
    @objc var avgNum : Int = -1
    
    @objc var stop = false
    var isUpdating = false
    
    // For sorting points
    var sortsPoints : Bool = false
    
    class JZWIndexedPoint
    {
        var index : Int = 0
        var point : JZWPoint? = nil
        var color : [GLdouble]? = nil
    }
    var nextIndex = 0
    let sortingHat = JZWMinHeap<JZWIndexedPoint> { (element : JZWIndexedPoint, isLessThan : JZWIndexedPoint) -> (Bool) in
        return element.index < isLessThan.index
    }
    
    class func characterStringForIndex(_ index : Int) -> String {
        var i = index
        var str = ""
        repeat {
            str = String(Character(Unicode.Scalar(i % 26 + 65)!)) + str
            i = i / 26
        } while i > 0
        return str
    }
    
    init(x: String, y: String, con: String, colorStr: String, scatter: Bool, line: Bool, tokenLabels: [String: JZWToken], sentences: [String: JZWSentence], plotMode: GraphMode, avgNum: Int)
    {
        self.xExpressionGC = NSMutableString(string: x);
        self.yExpressionGC = NSMutableString(string: y);
        self.conExpressionGC = NSMutableString(string: con)
        self.colorExpressionGC = NSMutableString(string: colorStr)
        
        let xExp = NSMutableString(string: x)
        let yExp = NSMutableString(string: y)
        let conExp = NSMutableString(string: con)
        let colExp = NSMutableString(string: colorStr)
        
        self.avgNum = avgNum
        self.plotMode = plotMode
        
        var shortenedLabelIndex = 0;
        
        for (label, token) in tokenLabels.sorted(by: {$0.0.count > $1.0.count})
        {
            if token is JZWParsableDataToken || token is JZWConstLengthGroupToken || token is JZWGroupToken || token is JZWRepeatToken
            {
                continue
            }
                        
            // GCExpression parser variables cannot start with a number or contain .'s, so add the letter 'a' to the beginning and remove all the .'s.
            let labelGC = "var" + JZWPlot.characterStringForIndex(shortenedLabelIndex)
            shortenedLabelIndex += 1
                        
            self.xExpressionGC.replaceOccurrences(of: label,
                with: labelGC, options: NSString.CompareOptions(rawValue: 0), range: NSMakeRange(0, self.xExpressionGC.length))
            
            self.yExpressionGC.replaceOccurrences(of: label,
                with: labelGC, options: NSString.CompareOptions(rawValue: 0), range: NSMakeRange(0, self.yExpressionGC.length))
            
            self.conExpressionGC.replaceOccurrences(of: label,
                with: labelGC, options: NSString.CompareOptions(rawValue: 0), range: NSMakeRange(0, self.conExpressionGC.length))
            
            self.colorExpressionGC.replaceOccurrences(of: label,
                with: labelGC, options: NSString.CompareOptions(rawValue: 0), range: NSMakeRange(0, self.colorExpressionGC.length))

            func addSentenceAndTokens(_ expression : NSMutableString, tokenSet : NSMutableSet, dict : inout [String : (String, JZWSentence)], allSentences : NSMutableSet)
            {
                // If the expression contains this token...
                let range = expression.range(of: label)
                if range.location != NSNotFound
                {
                    // If the label isn't already a member of the set...
                    if !tokenSet.contains(label)
                    {
                        // Get the sentence associated with the token...
                        if let sentenceName = JZWPlot.associatedSentenceForToken(label, sentences: sentences)
                        {
                            // Add the sentence to the list of sentences
                            let s = sentences[sentenceName]!
                            dict[label] = (labelGC, s)
                            allSentences.add(s)
                        }
                    }
                    tokenSet.add(label)
                }
            }

            if (self.plotMode == GraphMode.variable)
            {
                addSentenceAndTokens(xExp, tokenSet: self.xTokens, dict: &self.xSentences, allSentences: self.allSentences)
            }
            addSentenceAndTokens(yExp, tokenSet: self.yTokens, dict: &self.ySentences, allSentences: self.allSentences)
            addSentenceAndTokens(conExp, tokenSet: self.conTokens, dict: &self.conSentences, allSentences: self.allSentences)
            addSentenceAndTokens(colExp, tokenSet: self.colorTokens, dict: &self.colorSentences, allSentences: self.allSentences)
        }
        
        self.conditionEval = BoolTree.parse(self.conExpressionGC as String)
        
        self.plot = JZWVertexArray(size: 100, avgNum: Int32(avgNum), numDims: 2)
        self.plot.recordNewVertices()
        self.scatter = scatter
        self.line = line
        self.sortsPoints = self.line || con.trimmingCharacters(in: CharacterSet.whitespaces) != ""

        var averages : [ObjCBool] = [false, false];
        switch self.plotMode
        {
            case .index, .time:
                averages = [false, true]
            case .variable, .date:
                averages = [true, true]
        }
        self.plot.setAverages(UnsafeMutablePointer<ObjCBool>(mutating: averages))
        
        self.color = nil
    }
    
    private class func associatedSentenceForToken(_ tokenPath: String, sentences: [String : JZWSentence]) -> String?
    {
        var tokenComps = tokenPath.components(separatedBy: ".")
        
        let n = tokenComps.count
        for _ in 0 ..< n
        {
            let str = (tokenComps.reduce("", {"\($0).\($1)" as NSString}) as NSString).substring(from: 1)
            if sentences[str] != nil
            {
                return str
            }
            tokenComps.removeLast()
        }
        
        return nil
    }
    
    /*
    func setColor(color: NSColor)
    {
        self.color = color
    }
    */
    
    func setVariables(_ mainParsedSentence: JZWParsedSentencePointer, mainSentence: JZWSentence, sentences: [String : (String, JZWSentence)], inParser : GCMathParser) -> Bool!
    {
        //let mainSentence = mainParsedSentence.sentence
        
        for (name, tup) in sentences
        {
            let nameGC : String = tup.0
            let sentence : JZWSentence = tup.1
            
            var parsedSentence: JZWParsedSentencePointer? = nil
            
            if sentence === mainSentence
            {
                parsedSentence = mainParsedSentence
            }
            else
            {
                let (v, i) = sentence.findNextParsedData(JZWParsedSentenceData_getTimeStamp(mainParsedSentence), mindex: 0)
                parsedSentence = (i == sentence.numParsed() - 1) ? nil : v
            }
            
            if parsedSentence == nil
            {
                return false
            }
                        
            if let value = JZWParsedSentence.getNumericValueNoBlock(parsedSentence!, sentence: sentence, label: name)
            {
                inParser.setSymbolValue(value, forKey:nameGC)
            }
            else
            {
                return nil
            }
        }
        
        return true
    }
    
    static func clamp(value: Int, between: Int, and: Int) -> Int
    {
        if value < between
        {
            return between
        }
        if value > and
        {
            return and
        }
        return value
    }
    
    @objc func update(_ maxAdd : Int = -1) -> Bool
    {
        self.isUpdating = true
        
        var updated = false

        let mainVariableSentences = self.plotMode != GraphMode.variable ? self.ySentences : self.xSentences
        
        for (_, tup) in mainVariableSentences
        {
            if self.stop
            {
                break
            }

            let sentence = tup.1
            
            if (sentence.numParsed() == 0)
            {
                self.isUpdating = false
                return false
            }
            
            let lastObject = sentence.getMostRecentParsedValue()
            
            if Int64(JZWParsedSentenceData_getIndex(lastObject)) > self.mostRecentPoint
            {
                var startIndex : Int
                
                (_, startIndex) = sentence.findNextParsedDataByIndex(self.mostRecentPoint, mindex: 0)
                
                let numParsed = sentence.numParsed()
                
                let endIndex = maxAdd < 0 ? numParsed : ((numParsed - startIndex) > maxAdd ? startIndex + maxAdd : numParsed)
                
                self.mostRecentPoint = Int64(JZWParsedSentenceData_getIndex(sentence.getParsedValue(endIndex - 1)))
                
                let indexes = JZWLinkedIndexIterator_new(Int32(startIndex), Int32(endIndex))
                
                if (self.sortsPoints && nextIndex != startIndex)
                {
                    print("Non-Fatal Error: NextIndex \(nextIndex) and StartIndex \(startIndex) should be equal.")
                    self.nextIndex = startIndex
                }
                
                var i : Int32 = 0
                let parser = self.gcMathParser
                var pointToAdd = JZWIndexedPoint()
                while JZWLinkedIndexIterator_next(indexes, &i) == 1 && !self.stop
                {                    
                    pointToAdd.index = Int(i)
                    pointToAdd.point = nil
                    pointToAdd.color = nil
                    
                    autoreleasepool(invoking: { () -> () in
                        let mainParsedSentence = sentence.getParsedValue(Int(i))
                        
                        var shouldSkip = false
                        var mathFailed = false
                        let shouldGraph = self.conditionEval({ (expression : String) -> Double in
                            if shouldSkip || mathFailed
                            {
                                return 0
                            }
                            if self.setVariables(mainParsedSentence, mainSentence: sentence, sentences: self.conSentences, inParser: parser) == nil
                            {
                                shouldSkip = true
                                return 0
                            }
                            var failedInteral : ObjCBool = false
                            let value = parser.evaluate(expression, failed: &failedInteral)
                            if failedInteral.boolValue
                            {
                                mathFailed = true
                                return 0
                            }
                            return value
                        })
                        
                        if shouldSkip
                        {
                            return
                        }
                        
                        var vertexColor : [GLdouble]? = nil

                        if shouldGraph && !mathFailed
                        {
                            if self.plotMode == GraphMode.variable
                            {
                                if self.setVariables(mainParsedSentence, mainSentence: sentence, sentences: self.xSentences, inParser: parser) == nil
                                {
                                    return
                                }
                            }
                            if self.setVariables(mainParsedSentence, mainSentence: sentence, sentences: self.ySentences, inParser: parser) == nil
                            {
                                return
                            }
                            
                            var failed : ObjCBool = false
                            var x : Double = 0.0
                            
                            switch self.plotMode
                            {
                                case .variable, .date:
                                    x = parser.evaluate(self.xExpressionGC as String, failed: &failed)
                                case .index:
                                    x = Double(i)
                                case .time:
                                    x = JZWParsedSentenceData_getTimeStamp(mainParsedSentence) - self.startTime.timeIntervalSince1970
                            }
                            
                            if !failed.boolValue
                            {
                                let y = parser.evaluate(self.yExpressionGC as String, failed: &failed)
                                if !failed.boolValue
                                {
                                    pointToAdd.point = JZWPoint(x: GLdouble(x), y: GLdouble(y))
                                }
                            }
                            if let c = self.color
                            {
                                vertexColor = [Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent)];
                            }
                            else
                            {
                                if self.setVariables(mainParsedSentence, mainSentence: sentence, sentences: self.colorSentences, inParser: parser) == nil
                                {
                                    return
                                }
                                var failed : ObjCBool = false
                                let colorIndex = parser.evaluate(self.colorExpressionGC as String?, failed: &failed)
                                if !failed.boolValue
                                {
                                    let index = JZWPlot.clamp(value: Int(Double(self.colorBar.count) * colorIndex), between: 0, and: self.colorBar.count - 1)
                                    vertexColor = self.colorBar[index]
                                }
                            }
                        }
                        
                        JZWLinkedIndexIterator_remove(indexes)
                        
                        if self.sortsPoints
                        {
                            pointToAdd.color = vertexColor
                            self.sortingHat.push(pointToAdd)
                            pointToAdd = JZWIndexedPoint()
                            while let min = self.sortingHat.peekMin(), min.index == self.nextIndex
                            {
                                if let point = min.point, let color = min.color
                                {
                                    updated = true
                                    let vertex = [GLdouble(point.x), GLdouble(point.y)];
                                    let color : [GLdouble] = color
                                    self.plot.appendVertex(UnsafeMutablePointer<GLdouble>(mutating: vertex),
                                                           at: Int32(self.plot.length()), // Because the points are guarunteed to come out in the proper order, we can simply append
                                                           withColor:UnsafeMutablePointer<GLdouble>(mutating: color))
                                }
                                _ = self.sortingHat.popMin()
                                self.nextIndex += 1
                            }
                        }
                        else if let point = pointToAdd.point
                        {
                            let vertex = [GLdouble(point.x), GLdouble(point.y)];
                            updated = true
                            self.plot.appendVertex(UnsafeMutablePointer<GLdouble>(mutating: vertex),
                                                   at: Int32(pointToAdd.index),
                                                   withColor:UnsafeMutablePointer<GLdouble>(mutating: vertexColor))
                            pointToAdd = JZWIndexedPoint()
                        }
                    })
                }
                
                JZWLinkedIndexIterator_destroy(indexes)
            }
        }
        
        if self.stop
        {
            self.isUpdating = false
            return false
        }
        
        self.isUpdating = false
        return updated
    }

}







