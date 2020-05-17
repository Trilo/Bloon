//
//  JZWBoolArrayTests.swift
//  Bloon
//
//  Created by Jacob Weiss on 6/5/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

import XCTest
@testable import Bloon

class JZWBoolArrayTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample()
    {
        let getBoolValue = BoolTree.parse("1 > 2 & 3 > 4 | 5 < 6 & 6 < 7")
        
        print(getBoolValue { (expr : String) -> Double in
            print(expr)
            return 20;//Double(expr.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()))!
        })
        
        print("\(1 > 2 && 3 > 4 || 5 < 6 && 6 < 7)")
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
