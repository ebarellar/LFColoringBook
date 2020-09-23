//
//  LFColoringBookTests.swift
//  LFColoringBookTests
//
//  Created by Trabajo on 17/09/20.
//

import XCTest
@testable import LFColoringBook

class LFColoringBookTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testRects(){
        //Pixeles 0 a 3 en x e y
        
        let rect = CGRect(x: 0, y: 0,
                          width: 4, height: 4)
        
        XCTAssert(rect.contains(CGPoint(x: 0, y: 0)))
        XCTAssert(rect.contains(CGPoint(x: 1, y: 0)))
        XCTAssert(rect.contains(CGPoint(x: 2, y: 0)))
        XCTAssert(rect.contains(CGPoint(x: 3, y: 0)))
        //Este pixel no deberia ser valido
        XCTAssert(!rect.contains(CGPoint(x: 4, y: 0)))
    }
    
//    func testSpatial(){
//        var spatial = SpatialHashMask(xDivisions: 4, yDivisions: 4,
//                                      boundingRect: CGRect(origin: .zero,
//                                                           size: CGSize(width: 8, height: 8)))
//        
//        
//        let firstMask = Mask(boundingRect: CGRect(origin: .zero,
//                                                  size: CGSize(width: 6, height: 6)))
//        
//        let secondMask = Mask(boundingRect: CGRect(origin: CGPoint(x: 2, y: 0),
//                                                  size: CGSize(width: 1, height: 1)))
//        
//        
//        let thirdMask = Mask(boundingRect: CGRect(origin: CGPoint(x: 6, y: 6),
//                                                  size: CGSize(width: 2, height: 2)))
//        
//        spatial.add(firstMask)
//        spatial.add(secondMask)
//        spatial.add(thirdMask)
//        
//        XCTAssert(spatial.masksAt(CGPoint(x: 2, y: 0))?.count == 2)
//        XCTAssert(spatial.masksAt(CGPoint(x: 7, y: 7))?.count == 1)
//    }

}
