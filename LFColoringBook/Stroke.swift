//
//  Stroke.swift
//  LFColoringBook
//
//  Created by Trabajo on 17/09/20.
//

import UIKit
import simd

struct Stroke {
    private static var currentID:UInt64 = 0
    //Array of CGPoints to draw lines between them
    private (set) var points:[CGPoint] = [CGPoint]()
    //Update rect of whole stroke
    private (set) var strokeRect:CGRect = .null
    
    //LineWidth and Color of the stroke
    let lineWidth:CGFloat
    let color:UIColor
    let id:UInt64
    
    //Helper variable to know which points the active stroke has already drawn
    private (set) var lastDrawnPoint:Int = -1
    
    init(color:UIColor = .black, lineWidth:CGFloat = 5.0){
        self.color = color
        self.lineWidth = lineWidth
        
        self.id = Stroke.currentID
        Stroke.currentID += 1
    }
    
    mutating func addPoint(_ point:CGPoint){
        //If there is already one point we check the distance between the last point and the new one, we only accept points far enough to be drawn, otherwise performance might get hit. Nothing fancy about SIMD functions, I just didn't wanted to write a CGFloat distance function
        if let lastPoint = self.points.last{
            let lastSimd = simd_float2(x: Float(lastPoint.x), y: Float(lastPoint.y))
            let newSimd = simd_float2(x:Float(point.x), y:Float(point.y))
            if simd_distance(lastSimd, newSimd) < 1.0{
                return
            }
        }
        
        let pointRect = CGRect(x: point.x - self.lineWidth / 2.0 - 4.0,
                               y: point.y - self.lineWidth / 2.0 - 4.0,
                               width: self.lineWidth + 4.0,
                               height: self.lineWidth + 4.0)
        strokeRect = strokeRect.union(pointRect)
        self.points.append(point)
    }
    
    func drawInContext(_ context:CGContext){
        //Function to draw the whole stroke in the cgcontext, there's a debug option to draw small dots instead of lines
        if CommandLine.arguments.contains("-debugStrokes"){
            context.setFillColor(UIColor.red.cgColor)
            for point in self.points{
                context.fillEllipse(in: CGRect(x: point.x - 1.0,
                                               y: point.y - 1.0,
                                               width: 2.0, height: 2.0))
            }
        }
        else{
            context.setStrokeColor(self.color.cgColor)
            context.setLineWidth(self.lineWidth)
            context.addLines(between: self.points)
            context.strokePath()
        }

    }
    
    mutating func drawSinceLastIn( _ context:CGContext)->CGRect?{
        guard !self.points.isEmpty else {return nil}
        if self.lastDrawnPoint == (self.points.count - 1) {return nil}
        
        //We draw the segment that goes from the lastDrawnPoint (or the first point if none has been drawn, to the end of our points array)
        let arrayStart:Int = lastDrawnPoint >= 0 ? lastDrawnPoint:0
        let arrayEnd:Int = self.points.count - 1
        self.lastDrawnPoint = arrayEnd

        var updateRect:CGRect = .null
        var linePoints:[CGPoint] = [CGPoint]()
        
        for point in self.points[arrayStart...arrayEnd]{
            linePoints.append(point)
            
            //Create a rect that cover enough of the line width from the point, we accumulate these rects using union and send them to the coloring book view so the SetNeedsDisplay can be done more efficiently
            let pointRect = CGRect(x: point.x - self.lineWidth / 2.0 - 4.0,
                                   y: point.y - self.lineWidth / 2.0 - 4.0,
                                   width: self.lineWidth + 4.0,
                                   height: self.lineWidth + 4.0)
            updateRect = updateRect.union(pointRect)
        }
            
        if CommandLine.arguments.contains("-debugStrokes"){
            context.setFillColor(UIColor.red.cgColor)
            for point in linePoints{
                context.fillEllipse(in: CGRect(x: point.x - 1.0,
                                               y: point.y - 1.0,
                                               width: 2.0, height: 2.0))
            }
        }
        else{
            context.setStrokeColor(self.color.cgColor)
            context.setLineWidth(self.lineWidth)
            context.addLines(between: linePoints)
            context.strokePath()
        }
        
        return updateRect
    }
}
