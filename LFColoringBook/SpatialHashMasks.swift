//
//  SpatialHashMasks.swift
//  LFColoringBook
//
//  Created by Trabajo on 21/09/20.
//

import UIKit

//Spatial Hash
//Explanation:
//https://gamedevelopment.tutsplus.com/tutorials/redesign-your-display-list-with-spatial-hashes--cms-27586

struct SpatialHashMask {
    let xDivisions:Int
    let yDivisions:Int
    let boundingRect:CGRect
    private (set) var buckets:[Int:[Mask]]
    
    
    init(xDivisions:Int, yDivisions:Int, boundingRect:CGRect) {
        self.xDivisions = xDivisions
        self.yDivisions = yDivisions
        self.boundingRect = boundingRect
        
        self.buckets = [Int:[Mask]]()
        
        for i in 0..<(self.xDivisions * self.yDivisions){
            self.buckets[i] = [Mask]()
        }
    }
    
    mutating func add(_ mask:Mask){
        guard mask.boundingRect.intersects(self.boundingRect) else {return}
        
        var standardRect = mask.boundingRect.standardized
        
        standardRect.origin.x -= self.boundingRect.origin.x
        standardRect.origin.y -= self.boundingRect.origin.y
        
        //We crop a little bit from the size so it doesn't cross into an unecesary bucket
        standardRect.size = CGSize(width: standardRect.size.width - 0.00001,
                                   height: standardRect.size.height - 0.00001)
        
        let xLength:CGFloat = self.boundingRect.width / CGFloat(xDivisions)
        let xStart:Int = max(0,
                             Int((standardRect.origin.x / xLength).rounded(.down)))
        let xEnd:Int = min(xDivisions - 1,
                           Int(((standardRect.origin.x + standardRect.width) / xLength).rounded(.down)))
        
        let yLength:CGFloat = self.boundingRect.height / CGFloat(yDivisions)
        let yStart:Int = max(0,
                             Int((standardRect.origin.y / yLength).rounded(.down)))
        let yEnd:Int = min(yDivisions - 1,
                           Int(((standardRect.origin.y + standardRect.height) / yLength).rounded(.down)))
        
        for y in yStart...yEnd{
            for x in xStart...xEnd{
                let bucketIndex:Int = (y * xDivisions) + x
                self.buckets[bucketIndex]?.append(mask)
            }
        }
    }
    
    func masksAt(_ point:CGPoint)->[Mask]?{
        
        let xLength:CGFloat = self.boundingRect.width / CGFloat(xDivisions)
        let xIndex:Int = max(0,min(xDivisions - 1,Int(((point.x - self.boundingRect.origin.x) / xLength).rounded(.down))))
        
        let yLength:CGFloat = self.boundingRect.height / CGFloat(yDivisions)
        let yIndex:Int = max(0,min(yDivisions - 1,Int(((point.y - self.boundingRect.origin.y) / yLength).rounded(.down))))
        
        return self.buckets[(yIndex * xDivisions) + xIndex]
    }
}
