//
//  ColoringImage.swift
//  LFColoringBook
//
//  Created by Trabajo on 18/09/20.
//

import UIKit
import MobileCoreServices

struct ColoringImage {
    //Processing can be optimized or not
    let isOptimized:Bool
    
    //CGImage of the drawing
    let cgImage:CGImage
    
    //Size in pixels
    let width:Int
    let height:Int
    
    
    let bytesPerPixel:Int
    let bytesPerRow:Int
    
    //CIContext to render initial filters
    static let ciContext = CIContext()
    
    //Byte formatter for console messages
    static let byteFormatter:ByteCountFormatter = ByteCountFormatter()
    
    //Spatial hash for more efficient mask detection
    var spatialSearch:SpatialHashMask
    private (set) var maskBytes:Int64 = 0
    private (set) var totalMasks:Int = 0
    
    init(from image:UIImage, optimized:Bool = true){
        guard let bwFilter = CIFilter(name: "CIPhotoEffectTonal")
        else {
            fatalError("There is no B&W filter!!!!!!!")
        }
        
        guard let posterizeFilter = CIFilter(name: "CIColorPosterize")
        else {
            fatalError("There is no Color Posterize filter!!!!!!!")
        }
        
        guard let colorInvert = CIFilter(name: "CIColorInvert")
        else {
            fatalError("There is no Color Invert filter!!!!!!!")
        }
        
        guard let secondColorInvert = CIFilter(name: "CIColorInvert")
        else {
            fatalError("There is no Color Invert filter!!!!!!!")
        }
        
        guard let maskToAlpha = CIFilter(name: "CIMaskToAlpha")
        else {
            fatalError("There is no Mask to Alpha filter!!!!!!!")
        }
        
        guard let ciimage = CIImage(image: image) else{
            fatalError("Couldn transform UIImage to CIImage!!!!!!")
        }
        
        self.isOptimized = optimized
        
        //This isn't pretty but it's set up this way to assure a "coloreable" image
        
        //Change image to black and white
        bwFilter.setValue(ciimage, forKey: kCIInputImageKey)
        
        //Clamp values to white and black (add more levels and see if it solves some antialiasing cases)
        posterizeFilter.setValue(bwFilter.outputImage!, forKey: kCIInputImageKey)
        posterizeFilter.setValue(NSNumber(integerLiteral: 2),
                                 forKey: "inputLevels")
        
        //Invert colors (needed for next filter)
        colorInvert.setValue(posterizeFilter.outputImage!, forKey: kCIInputImageKey)
        
        //Turn black pixels to transparent
        maskToAlpha.setValue(colorInvert.outputImage!, forKey: kCIInputImageKey)
        
        //Turn white pixels to black (the lines of our drawing)
        secondColorInvert.setValue(maskToAlpha.outputImage!, forKey: kCIInputImageKey)
        
        //Create a CGImage for the Coloring View
        self.cgImage = ColoringImage.ciContext.createCGImage(secondColorInvert.outputImage!,
                                                             from: secondColorInvert.outputImage!.extent)!
        self.width = Int(image.size.width * image.scale)
        self.height = Int(image.size.height * image.scale)
        
        self.bytesPerPixel = 4
        //Not hardcoded or calculated!! the real bytes per row
        self.bytesPerRow = self.cgImage.bytesPerRow
        
        //4x4 grid seems to reduce the searchs fine
        self.spatialSearch = SpatialHashMask(xDivisions: 4, yDivisions: 4,
                                             boundingRect: CGRect(origin: .zero,
                                                                  size: CGSize(width: self.width, height: self.height)))
        
        //If it is optimized create the masks from start
        if self.isOptimized{
            self.createMasks()
        }
        
    }
    
    private mutating func createMasks(){
        guard let data = self.cgImage.dataProvider?.data else {return}
        let dataLenght:Int = CFDataGetLength(data) as Int

        
        //A copy of the bitmap from the drawing (we are going to turn in full black)
        var bitmapCopy:[UInt8] = [UInt8].init(repeating: 0, count: dataLenght)
        
        CFDataGetBytes(data, CFRangeMake(0, dataLenght),
                       &bitmapCopy)
        
        //The number of bytes needed to create a mask the same size as the drawing (8 bit image)
        let maskBytes:Int = 1 * self.width * self.height
        
        //For all pixels from the bitmapcopy
        for y in 0..<self.height{
            for x in 0..<self.width{
                //Pixel is transparent, try to create a mask here
                if bitmapCopy[(bytesPerRow * y ) + (bytesPerPixel * x) + 3] != 255{
                    autoreleasepool {
                        //Create a new mask bitmap
                        var maskBitmap:[UInt8] = [UInt8].init(repeating: 0,
                                                              count: maskBytes)
                        
                        let boundingRect = self.maskFillScanLine(x: x, y: y,
                                              bitmap: &bitmapCopy,
                                              mask: &maskBitmap)
                        //No bounding rect for mask found, shouldn't happen
                        if boundingRect.isNull {return}
                        
                        let maskData:CFData = Data(bytes: &maskBitmap,
                                                   count: maskBitmap.count * MemoryLayout<UInt8>.size) as CFData
                        
                        guard let provider:CGDataProvider = CGDataProvider(data: maskData) else {return}
                        
                        //Create a CGImage from the mask, cropping to the bounding rect of the mask
                        guard let maskImage = CGImage(width: self.width,
                                       height: self.height,
                                       bitsPerComponent: 8,
                                       bitsPerPixel: 8,
                                       bytesPerRow: self.width,
                                       space: CGColorSpaceCreateDeviceGray(),
                                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                       provider: provider, decode: nil,
                                       shouldInterpolate: true, intent: .defaultIntent)?.cropping(to: boundingRect)
                        else{return}
                        
                        let pngData:NSMutableData = NSMutableData()
                        
                        //Compress the mask image to PNG encrypted data
                        if let dest = CGImageDestinationCreateWithData(pngData,
                                                                       kUTTypePNG,
                                                                       1, nil){
                            CGImageDestinationAddImage(dest,
                                                       maskImage, nil)
                            if CGImageDestinationFinalize(dest){
                                
                                //If PNG was created create a Mask class and add it to spatial search
                                let newMask = Mask(boundingRect: boundingRect,
                                                   data: pngData)
                                
                                self.spatialSearch.add(newMask)
                                let originalBytes = ColoringImage.byteFormatter.string(fromByteCount: Int64(maskBitmap.count))
                                let pngBytes = ColoringImage.byteFormatter.string(fromByteCount: Int64(pngData.count))
                                
                                NSLog("Created Mask, compressed from \(originalBytes) to \(pngBytes)")
                                
                                self.maskBytes += Int64(pngData.count)
                                self.totalMasks += 1
                            }
                        }
                    }
                }
            }
        }
        
        let totalSize = ColoringImage.byteFormatter.string(fromByteCount: self.maskBytes)
        NSLog("Created \(totalMasks) masks with a size of \(totalSize)")
    }
    
    //X and Y are pixel position
    func getFillMaskAt(x:Int, y:Int)->(CGRect, CGImage?){
        if self.isOptimized{
            //Optimized mask is searched
            return self.getFillMaskOptimizedAt(x: x, y: y)
        }
        else{
            //None optimized mask gets created at runtime
            return self.getFillMaskNotOptimizedAt(x: x, y: y)
        }
    }
    
    private func getFillMaskNotOptimizedAt(x:Int, y:Int)->(CGRect, CGImage?){
        guard let data = self.cgImage.dataProvider?.data else {return (.null,nil)}
        
        guard var bitmapPointer = CFDataGetBytePtr(data) else {return (.null,nil)}
        
        let maskBytes:Int = 1 * self.width * self.height
        
        var maskBitmap:[UInt8] = [UInt8].init(repeating: 0,
                                              count: maskBytes)
        
        let start = ProcessInfo.processInfo.systemUptime
        if CommandLine.arguments.contains("-FloodFillRecursive"){
            self.fillFloodRecursive(x: x, y: y, bitmap: &bitmapPointer, mask: &maskBitmap)
        }
        else if CommandLine.arguments.contains("-FloodFillNonRecursive"){
            self.fillFloodNonRecursive(x: x, y: y, bitmap: &bitmapPointer, mask: &maskBitmap)
        }
        else{
            self.fillFloodScanLine(x: x, y: y, bitmap: &bitmapPointer, mask: &maskBitmap)
        }
        
        let dif = ProcessInfo.processInfo.systemUptime - start
        NSLog("Took \(dif) seconds to create mask")
    
        let maskData:CFData = Data(bytes: &maskBitmap,
                                   count: maskBitmap.count * MemoryLayout<UInt8>.size) as CFData
        
        guard let provider:CGDataProvider = CGDataProvider(data: maskData) else {return (.null,nil)}
        
        let scale = UIScreen.main.scale
        return (CGRect(x: 0, y: 0,
                       width: self.width / Int(scale),
                       height: self.height / Int(scale))
                ,CGImage(width: self.width,
                       height: self.height,
                       bitsPerComponent: 8,
                       bitsPerPixel: 8,
                       bytesPerRow: self.width,
                       space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil,
                       shouldInterpolate: true, intent: .defaultIntent))
    }
    
    private func getFillMaskOptimizedAt(x:Int, y:Int)->(CGRect, CGImage?){
        guard let data = self.cgImage.dataProvider?.data else {return (.null,nil)}
        
        guard let bitmapPointer = CFDataGetBytePtr(data) else {return (.null,nil)}
        
        //Check if touch is inside a black pixel, no point in searching after this
        if bitmapPointer[(self.bytesPerRow * y) + (bytesPerPixel * x) + 3] == 255{
            print("Touched black line")
            return (.null,nil)
        }
        
        let start = ProcessInfo.processInfo.systemUptime
        
        defer {
            let dif = ProcessInfo.processInfo.systemUptime - start
            NSLog("Took \(dif) seconds to find correct mask")
        }
        
        //Get the number of masks spanning the sector of the touch start
        guard var masks = spatialSearch.masksAt(CGPoint(x: x, y: y)) else {return (.null,nil)}
        
        //Reduce the mask array keeping only the masks that actually contain the point
        masks = masks.compactMap{
            if $0.contains(CGPoint(x: x, y: y)){
                return $0
            }
            else{
                return nil
            }
        }
        
        //Order mask with origin closer to point first
        masks = masks.sorted(by: { (mask0, mask1) -> Bool in
            return mask0.squaredDistanceFromOriginTo(CGPoint(x: x, y: y)) <
            mask1.squaredDistanceFromOriginTo(CGPoint(x: x, y: y))
        })
        
        NSLog("\(masks.count) masks detected")
        
        //Ideally only 1 mask will be found
        for mask in masks{
            var returnRect:CGRect? = nil
            var returnMask:CGImage? = nil
            autoreleasepool {
                guard let dataProvider = CGDataProvider(data: mask.pngData as CFData)
                else {return}
                
                guard let maskImage = CGImage(pngDataProviderSource: dataProvider,
                                              decode: nil,
                                              shouldInterpolate: true,
                                              intent: .defaultIntent) else {return}
                
                //Collision detection with the bitmap data
                guard let bitmapData = maskImage.dataProvider?.data else {return}
                
                guard let bitmapPointer = CFDataGetBytePtr(bitmapData) else {return}
                
                let translatedX = x - Int(mask.boundingRect.origin.x)
                let translatedY = y - Int(mask.boundingRect.origin.y)
                
                let index = (maskImage.bytesPerRow * translatedY) + translatedX
                //If hit point has full alpha (white) this is the correct mask
                if bitmapPointer[index] == 255{
                    returnRect = mask.boundingRect
                    returnMask = maskImage
                }
            }
            
            if let boundingRect = returnRect, let imageMask = returnMask{
                let scale = UIScreen.main.scale
                return(CGRect(x: boundingRect.origin.x / scale ,
                              y: boundingRect.origin.y / scale,
                              width: boundingRect.width / scale,
                              height: boundingRect.height / scale),
                       imageMask)
            }
        }
        
        //No mask found, shouldn't happen :| Fatal error maybe?
        let scale = UIScreen.main.scale
        return (CGRect(x: 0, y: 0,
                       width: self.width / Int(scale),
                       height: self.height / Int(scale)),nil)
    }
    
    //Extremely naive approach, most likely to crash app due to stack overflow
    func fillFloodRecursive(x:Int, y:Int, bitmap: inout UnsafePointer<UInt8>, mask: inout [UInt8]){
        
        //Check if we are still inside the image
        if x < 0 || x >= self.width ||
            y < 0 || y >= self.height{
            return
        }
        
        let pixelStart:Int = (self.bytesPerRow * y) + (bytesPerPixel * x)
        let originalR:UInt8 = bitmap[pixelStart]
        let originalG:UInt8 = bitmap[pixelStart + 1]
        let originalB:UInt8 = bitmap[pixelStart + 2]
        let originalA:UInt8 = bitmap[pixelStart + 3]
        
        let maskIndex = (self.width * ((self.height - 1) - y)) + (x)
        let maskPixel:UInt8 = mask[maskIndex]
        
        //If original at postion is black, return
        if originalR == 0 && originalG == 0 && originalB == 0 && originalA == 255{
            return
        }
        
        //If mask is already white return
        if maskPixel == 255{
            return
        }
        
        mask[maskIndex] = 255
        
        //Left
        self.fillFloodRecursive(x: x - 1, y: y, bitmap: &bitmap, mask: &mask)
        //Right
        self.fillFloodRecursive(x: x + 1, y: y, bitmap: &bitmap, mask: &mask)
        //Down
        self.fillFloodRecursive(x: x, y: y - 1, bitmap: &bitmap, mask: &mask)
        //Up
        self.fillFloodRecursive(x: x, y: y + 1, bitmap: &bitmap, mask: &mask)
    }
    
    //Extremely naive approach, will not crash the app but take a long time
    func fillFloodNonRecursive(x:Int, y:Int, bitmap: inout UnsafePointer<UInt8>, mask: inout [UInt8]){
        
        var positions = Queue<PixelPosition>()
        
        positions.enqueue(PixelPosition(x: x, y: y))
        
        while !positions.isEmpty {
            
            guard let position = positions.dequeue() else {break}
            
            //Check if we are still inside the image
            if position.x < 0 || position.x >= self.width ||
                position.y < 0 || position.y >= self.height{
                continue
            }
            
            let pixelStart:Int = (self.bytesPerRow * position.y) + (bytesPerPixel * position.x)
            let originalR:UInt8 = bitmap[pixelStart]
            let originalG:UInt8 = bitmap[pixelStart + 1]
            let originalB:UInt8 = bitmap[pixelStart + 2]
            let originalA:UInt8 = bitmap[pixelStart + 3]
            
            let maskIndex = (self.width * ((self.height - 1) - position.y)) + (position.x)
            let maskPixel:UInt8 = mask[maskIndex]
            
            //If original at postion is black, return
            if originalR == 0 && originalG == 0 && originalB == 0 && originalA == 255{
                continue
            }
            
            //If mask is already white return
            if maskPixel == 255{
                continue
            }
            
            mask[maskIndex] = 255
            
            //Left
            positions.enqueue(PixelPosition(x: position.x - 1, y: position.y))
            //Right
            positions.enqueue(PixelPosition(x: position.x + 1, y: position.y))
            //Down
            positions.enqueue(PixelPosition(x: position.x, y: position.y - 1))
            //Up
            positions.enqueue(PixelPosition(x: position.x, y: position.y + 1))
            
        }
        
    }
    
    //Best approach, takes around 10% of the previous method, Taken from:
    //https://lodev.org/cgtutor/floodfill.html#Scanline_Floodfill_Algorithm_With_Stack
    func fillFloodScanLine(x:Int, y:Int, bitmap: inout UnsafePointer<UInt8>, mask: inout [UInt8]){
        
        var x1:Int = 0
        var spanAbove:Bool = false
        var spanBelow:Bool = false
        
        var stack:Stack<PixelPosition> = Stack<PixelPosition>()
        
        stack.push(PixelPosition(x: x, y: y))
        while let position = stack.pop() {
            x1 = position.x
            
            while( x1 >= 0 &&
                    bitmap[(bytesPerRow * position.y ) + (bytesPerPixel * x1) + 3] != 255 &&
                    mask[(self.width * ((self.height - 1) - position.y)) + x1] != 255){
                x1 -= 1
            }
            x1 += 1
            
            spanAbove = false
            spanBelow = false
            
            while ( x1 < self.width &&
                        bitmap[(bytesPerRow * position.y ) + (bytesPerPixel * x1) + 3] != 255 &&
                        mask[(self.width * ((self.height - 1) - position.y)) + x1] != 255){
                
                let maskIndex = (self.width * ((self.height - 1) - position.y)) + (x1)
                mask[maskIndex] = 255
                
                if !spanAbove && position.y > 0 &&
                    bitmap[self.bytesPerRow * (position.y - 1) + (bytesPerPixel * x1) + 3] != 255
                   && mask[(self.width * ((self.height - 1) - (position.y - 1))) + x1] != 255{
                    stack.push(PixelPosition(x: x1, y: position.y - 1))
                    spanAbove = true
                }
                else if spanAbove && position.y > 0 &&
                bitmap[self.bytesPerRow * (position.y - 1) + (bytesPerPixel * x1) + 3] == 255
                {
                    spanAbove = false
                }
                
                if !spanBelow && position.y < (self.height - 1) &&
                    bitmap[self.bytesPerRow * (position.y + 1) + (bytesPerPixel * x1) + 3] != 255
                    && mask[(self.width * ((self.height - 1) - (position.y + 1))) + x1] != 255{
                    stack.push(PixelPosition(x: x1, y: position.y + 1))
                    spanBelow = true
                }
                else if spanBelow && position.y < (self.height - 1) &&
                    bitmap[self.bytesPerRow * (position.y + 1) + (bytesPerPixel * x1) + 3] == 255{
                    spanBelow = false
                }
                
                x1 += 1
            }
        }
    }
    
    //Same method as last one except used exclusively for optimized images, it fills the original bitmap with black pixels and produces a correctly oriented mask for faster hit detection
    func maskFillScanLine(x:Int, y:Int, bitmap: inout [UInt8], mask: inout [UInt8])->CGRect{
        
        var x1:Int = 0
        var spanAbove:Bool = false
        var spanBelow:Bool = false
        
        var minX:Int? = nil
        var minY:Int? = nil
        var maxX:Int? = nil
        var maxY:Int? = nil
        
        var stack:Stack<PixelPosition> = Stack<PixelPosition>()
        
        stack.push(PixelPosition(x: x, y: y))
        while let position = stack.pop() {
            x1 = position.x
            
            while( x1 >= 0 &&
                    bitmap[(bytesPerRow * position.y ) + (bytesPerPixel * x1) + 3] != 255){
                x1 -= 1
            }
            x1 += 1
            
            spanAbove = false
            spanBelow = false
            
            while ( x1 < self.width &&
                        bitmap[(bytesPerRow * position.y ) + (bytesPerPixel * x1) + 3] != 255){
                
                let maskIndex = (self.width *  position.y) + (x1)
                mask[maskIndex] = 255
                //Fill bitmap copy in black
                bitmap[(bytesPerRow * position.y ) + (bytesPerPixel * x1) + 3] = 255
                
                //Keep mins and max to process bounding rect
                minX = minX == nil ? x1:min(minX!,x1)
                minY = minY == nil ? position.y:min(minY!,position.y)
                maxX = maxX == nil ? x1:max(maxX!,x1)
                maxY = maxY == nil ? position.y:max(maxY!,position.y)
                
                if !spanAbove && position.y > 0 &&
                    bitmap[self.bytesPerRow * (position.y - 1) + (bytesPerPixel * x1) + 3] != 255{
                    stack.push(PixelPosition(x: x1, y: position.y - 1))
                    spanAbove = true
                }
                else if spanAbove && position.y > 0 &&
                bitmap[self.bytesPerRow * (position.y - 1) + (bytesPerPixel * x1) + 3] == 255
                {
                    spanAbove = false
                }
                
                if !spanBelow && position.y < (self.height - 1) &&
                    bitmap[self.bytesPerRow * (position.y + 1) + (bytesPerPixel * x1) + 3] != 255{
                    stack.push(PixelPosition(x: x1, y: position.y + 1))
                    spanBelow = true
                }
                else if spanBelow && position.y < (self.height - 1) &&
                    bitmap[self.bytesPerRow * (position.y + 1) + (bytesPerPixel * x1) + 3] == 255{
                    spanBelow = false
                }
                
                x1 += 1
            }
        }
        
        if let maxX = maxX, let maxY = maxY, let minX = minX, let minY = minY{
            return CGRect(x: minX,
                          y: minY,
                          width: (maxX - minX) + 1,
                          height: (maxY - minY) + 1)
        }
        else{
            return .null
        }
    }
}

struct PixelPosition {
    let x:Int
    let y:Int
}
