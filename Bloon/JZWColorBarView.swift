//
//  JZWColorBarView.swift
//  Bloon
//
//  Created by Jacob Weiss on 12/18/16.
//  Copyright © 2016 Jacob Weiss. All rights reserved.
//

import Cocoa
import SpriteKit

class JZWColorBarView: SKView {
    var sprite : SKSpriteNode?
    let parser = GCMathParser()
    
    var redFunc : String = "cos(2 * 3.14159 * t) / 2 + 0.5"
    var greenFunc : String = "cos(2 * 3.14159 * (t+0.333)) / 2 + 0.5"
    var blueFunc : String = "cos(2 * 3.14159 * (t+0.666)) / 2 + 0.5"
    
    var colorBar : [[GLdouble]] = [[]]
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.initScene()
    }
    
    func initScene()
    {
        let scn = SKScene(size: CGSize(width: 1, height: 1000))
        self.sprite = SKSpriteNode(texture: self.buildTexture())
        scn.addChild(sprite!)
        self.sprite?.anchorPoint = CGPoint(x: 0, y: 0)
        self.sprite?.position = CGPoint(x: 0, y: 0)
        self.presentScene(scn)
    }
    
    public struct PixelData {
        var a:UInt8 = 255
        var r:UInt8
        var g:UInt8
        var b:UInt8
    }
    
    private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    private let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
    
    public func imageFromARGB32Bitmap(pixels:[PixelData], width:Int, height:Int) -> NSImage
    {
        let bitsPerComponent : Int = 8
        let bitsPerPixel : Int = 32
        
        assert(pixels.count == Int(width * height))
        
        var data = pixels // Copy to mutable []
        let providerRef = CGDataProvider(
            data: NSData(bytes: &data, length: data.count * MemoryLayout<PixelData>.size)
        )
        
        let cgim = CGImage(width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: bitsPerPixel,
                bytesPerRow: width * MemoryLayout<PixelData>.size,
                space: rgbColorSpace,
                bitmapInfo: bitmapInfo,
                provider: providerRef!,
                decode: nil,
                shouldInterpolate: true,
                intent: CGColorRenderingIntent.defaultIntent)
        
        return NSImage(cgImage: cgim!, size: NSSize(width: width, height: height))
    }

    func buildTexture() -> SKTexture?
    {
        self.colorBar = [[]]
        var data = [PixelData](repeating: PixelData(a: 255, r: 0, g: 200, b: 0), count: 1000)
        for y in 0 ..< 1000
        {
            parser.setSymbolValue(Double(y) / 990.0, forKey: "t")
            var rfailed : ObjCBool = false
            let red = parser.evaluate(redFunc, failed: &rfailed)
            var gfailed : ObjCBool = false
            let green = parser.evaluate(greenFunc, failed: &gfailed)
            var bfailed : ObjCBool = false
            let blue = parser.evaluate(blueFunc, failed: &bfailed)
            if rfailed.boolValue || gfailed.boolValue || bfailed.boolValue
            {
                return nil
            }
            data[y] = PixelData(a: 255, r: UInt8(red * 255), g: UInt8(green * 255), b: UInt8(blue * 255))
            self.colorBar.append([red, green, blue])
        }
        let img = self.imageFromARGB32Bitmap(pixels: data, width: 1, height: 1000)
        return SKTexture(image: img)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.initScene()
    }
}
