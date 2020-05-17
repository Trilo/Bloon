//
//  JZWLinkedIndexList.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/17/15.
//  Copyright © 2015 Jacob Weiss. All rights reserved.
//

import XCTest
@testable import Bloon

class JZWLinkedIndexList: XCTestCase {

    let min = 5
    let max = 15
    
    override func setUp()
    {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown()
    {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testC()
    {
        Thread.sleep(forTimeInterval: 5)
        let list = JZWLinkedIndexIterator_new(Int32(min), Int32(max))
        
        self.measure { () -> Void in
            var next : Int32 = 0
            while JZWLinkedIndexIterator_next(list, &next) == 1
            {
                print(next)
                JZWLinkedIndexIterator_remove(list)
            }
        }
        
        JZWLinkedIndexIterator_destroy(list)
        
        Thread.sleep(forTimeInterval: 5)
    }
}
