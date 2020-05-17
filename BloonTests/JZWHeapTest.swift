//
//  JZWHeapTest.swift
//  Bloon
//
//  Created by Jacob Weiss on 6/11/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

import XCTest
@testable import Bloon

class JZWHeapTest: XCTestCase {

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
        let heap = JZWMinHeap<Int> { (element : Int, isLessThan : Int) -> (Bool) in
            return element < isLessThan
        }
        
        for i in (0 ..< 100).reversed()
        {
            heap.push(i)
        }
        
        while let i = heap.popMin()
        {
            print(i)
        }
    }
    
    func test()
    {
        let heap = JZWMinHeap<Int> { (element : Int, isLessThan : Int) -> (Bool) in
            return element < isLessThan
        }
        
        self.measure {
            for i in (0 ..< 10000).sorted(by : { (a : Int, b : Int) -> Bool in return arc4random() % 2 == 0 })
            {
                heap.push(i)
            }
            
            for i in (0 ..< 10000)
            {
                if i != heap.popMin()! {
                    print("FAIL!!!");
                    return;
                }
            }
        }
        
        print("Success!!");
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
