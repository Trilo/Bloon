//
//  BoolTree.swift
//  Bloon
//
//  Created by Jacob Weiss on 6/4/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

class BoolTree
{
    enum Operation
    {
        case and
        case or
        case lessThan
        case lessThanOrEqual
        case greaterThan
        case greaterThanOrEqual
        case equal
        case notEqual
    }
    
    static let StringToOperation : [String : Operation] = [
        "&"  : Operation.and,
        "|"  : Operation.or,
        "<=" : Operation.lessThanOrEqual,
        "<"  : Operation.lessThan,
        ">=" : Operation.greaterThanOrEqual,
        ">"  : Operation.greaterThan,
        "==" : Operation.equal,
        "!=" : Operation.notEqual
    ]
    
    var expr : String = ""
    var paren : Int = 0
    var lchild : BoolTree? = nil
    var op : Operation? = nil
    var rchild : BoolTree? = nil
    
    init (expr : String, paren : Int, lchild : BoolTree? , op : Operation?, rchild : BoolTree?)
    {
        (self.expr, self.paren, self.lchild, self.op, self.rchild) = (expr, paren, lchild, op, rchild)
    }
    
    /*
     parse() takes a string formatted like: "expr == 1 & expr < expr | expr > expr" and returns a function eval().
     When calling eval(), pass in another function, convert(), that converts exprs into doubles.
     eval() takes the boolean expression, converts each expr into a double, and then evaluates the resulting boolean expression and returns a single result.
     
     Note: Use [] to group logic: expr & [expr | expr]
    */
    static func parse(_ expr : String) -> ((_ eval : (String) -> Double) -> (Bool))
    {
        if (expr.trimmingCharacters(in: CharacterSet.whitespaces) == "")
        {
            return { function in true }
        }
        
        // Separate the string by & and | to get the componenents that need to be evaluated
        let comps = expr.components(separatedBy: CharacterSet(charactersIn: "&|"))
        // Get the list of operations used to combine the components
        var ops = expr.components(separatedBy: CharacterSet(charactersIn: "&|").inverted).filter({$0 != ""}).map { StringToOperation[$0] }
        
        // Calculate grouping levels
        var vals = comps.map { (comp : String) -> BoolTree in
            let x = comp.reduce(0, { (val : Int, c : Character) -> Int in
                switch c
                {
                case "[": return val + 1
                case "]": return val - 1
                default:  return val
                }
            })
            
            let condition = comp.trimmingCharacters(in: CharacterSet(charactersIn: "[] \n"))
            
            // Order is important here. The longer ones should be checked before the shorter ones.
            for c in ["<=", ">=", "<", ">", "==", "!="]
            {
                let exprs = condition.components(separatedBy: c)
                if exprs.count == 2
                {
                    let b0 = BoolTree(expr: exprs[0], paren: 0, lchild: nil, op: nil, rchild: nil)
                    let b1 = BoolTree(expr: exprs[1], paren: 0, lchild: nil, op: nil, rchild: nil)
                    
                    return BoolTree(expr: condition, paren: x, lchild: b0, op: StringToOperation[c], rchild: b1)
                }
            }
            return BoolTree(expr: "", paren: 0, lchild: nil, op : nil, rchild: nil)
        }
        
        while vals.count > 1
        {
            var newVals : [BoolTree] = []
            var newOps : [BoolTree.Operation?] = []
            
            for i in 0 ..< vals.count - 1
            {
                let b = (vals[i], vals[i + 1]);
                
                var foundAnd = false
                for j in i ..< vals.count - 1
                {
                    let precCheck = (vals[j], vals[j + 1])

                    if precCheck.0.paren == 0 || precCheck.1.paren == 0
                    {
                        if ops[j] == Operation.and
                        {
                            precCheck.0.paren += 1
                            precCheck.1.paren -= 1
                            foundAnd = true
                            break
                        }
                    }
                    else
                    {
                        break
                    }
                }
                if !foundAnd && b.1.paren == 0
                {
                    b.0.paren += 1
                    b.1.paren -= 1
                }
                
                if b.0.paren > 0 && b.1.paren < 0
                {
                    newVals.append(BoolTree(expr: "\(b.0.expr) \(b.1.expr)", paren: b.0.paren + b.1.paren, lchild: b.0, op: ops[i], rchild: b.1))
                    newVals.append(contentsOf: vals.dropFirst(i + 2))
                    newOps.append(contentsOf: ops.dropFirst(i + 1))
                    break
                }
                else
                {
                    newVals.append(vals[i])
                    newOps.append(ops[i])
                }
            }
            (vals, ops) = (newVals, newOps)
        }
        
        func evaluate(_ expr : BoolTree, eval : (String) -> Double) -> Bool
        {
            guard let left = expr.lchild, let right = expr.rchild else
            {
                return false
            }
            
            switch expr.op!
            {
            case .and:
                return evaluate(left, eval: eval) && evaluate(right, eval: eval)
            case .or:
                return evaluate(left, eval: eval) || evaluate(right, eval: eval)
            case .lessThan:
                return eval(left.expr) < eval(right.expr)
            case .lessThanOrEqual:
                return eval(left.expr) <= eval(right.expr)
            case .greaterThan:
                return eval(left.expr) > eval(right.expr)
            case .greaterThanOrEqual:
                return eval(left.expr) >= eval(right.expr)
            case .equal:
                return eval(left.expr) == eval(right.expr)
            case .notEqual:
                return eval(left.expr) != eval(right.expr)
            }
        }
        
        return { function in evaluate(vals[0], eval: function) }
    }
}

