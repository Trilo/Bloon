//
//  JZWMrSwArrayTests.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/15/15.
//  Copyright © 2015 Jacob Weiss. All rights reserved.
//

import XCTest
@testable import Bloon

class JZWMrSwArrayTests: XCTestCase
{
    class TestObject
    {
        var value = 0
        let data = NSMutableArray(capacity: 100)
        
        init(value : Int)
        {
            self.value = value
        }
        
        deinit
        {
            //print("Deinit \(self.value)")
        }
    }
    
    override func setUp()
    {
        super.setUp()
    }
    
    override func tearDown()
    {
        super.tearDown()
    }

    func rangeTest() {
        //let nr = NSRange(location: 5, length: 20)
    }
    
    func testIterate()
    {
        var array : JZWMrSwArray<TestObject>? = nil
        array = JZWMrSwArray<TestObject>(blockSize: 500, numBlocks: 10)
        for i in 0 ..< 100
        {
            array!.append(TestObject(value: i))
        }

        var value = 0
        array?.iterateWithBlock({ (obj : JZWMrSwArrayTests.TestObject) -> Bool in
            if obj.value != value {
                print("Test failed! \(obj.value) != \(value)")
            }
            value += 1
            return false
        }, inRange: NSRange(location: 0, length: 100))
    }
    
    func testGetRaw() {
        var array : JZWMrSwArray<TestObject>? = nil
        array = JZWMrSwArray<TestObject>(blockSize: 5, numBlocks: 10)
        for i in 0 ..< 100
        {
            array!.append(TestObject(value: i))
        }

        var range = NSRange(location: 6, length: 50)
        let rawData = try! array?.getRaw(&range)
        
        for i in 0..<50 {
            print("\(rawData![i].value)")
        }
    }
    
    func testMultithread() {
        var array : JZWMrSwArray<TestObject>? = nil
        array = JZWMrSwArray<TestObject>(blockSize: 1024, numBlocks: 10)

        let group = DispatchGroup()
        
        var isWriting = true
        group.enter()
        DispatchQueue.global().async {
            for i in 0 ..< 10000000
            {
                array!.append(TestObject(value: i))
            }
            isWriting = false
            group.leave()
        }
        
        for _ in 0..<7 {
            group.enter()
            DispatchQueue.global().async {
                while isWriting {
                    var total : Int64 = 0
                    array?.iterateWithBlock({ (obj : TestObject) -> Bool in
                        total += Int64(obj.value)
                        return false
                    }, inRange: NSRange(location: 0, length: array!.count))
                    print("\(total)")
                }
                group.leave()
            }
        }

        group.wait()
    }
    
    func testAddMany()
    {
        var array : JZWMrSwArray<TestObject>? = nil

        Thread.sleep(forTimeInterval: 5)
        
        for _ in 0 ..< 10
        {
            autoreleasepool(invoking: { () -> () in
                array = JZWMrSwArray<TestObject>(blockSize: 1000, numBlocks: 10)
                
                for i in 0 ..< 1000000
                {
                    array!.append(TestObject(value: i))
                }
                
                Thread.sleep(forTimeInterval: 4)
                
                array = nil
                
                Thread.sleep(forTimeInterval: 4)
            })
        }
    }
}
