//
//  JZWDataTest.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/17/15.
//  Copyright © 2015 Jacob Weiss. All rights reserved.
//

import XCTest
@testable import Bloon

class JZWDataTest: XCTestCase {

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
        var data : JZWData? = nil
        
        for _ in 0 ..< 100
        {
            autoreleasepool(invoking: { () -> () in
                Thread.sleep(forTimeInterval: 4)
                
                data = JZWData(blockSize: 100, numBlocks: 2)
                
                let file = try! Data(contentsOf: URL(fileURLWithPath: "/Users/jacob/Dropbox/Programming/Swift/Bloonv3.3/InputData/Testfile5.txt"))
                data?.appendData(file)
                data?.appendData(file)
                
                Thread.sleep(forTimeInterval: 4)
                
                data = nil
            })
        }
    }
}
