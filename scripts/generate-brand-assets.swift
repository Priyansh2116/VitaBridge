#!/usr/bin/env swift
// Original, deterministic vector drawing. No third-party artwork or image service.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let iconFolder = root.appendingPathComponent("Sources/VitaBridgeApp/Assets.xcassets/AppIcon.appiconset")
let docsFolder = root.appendingPathComponent("docs/assets")
try FileManager.default.createDirectory(at:iconFolder,withIntermediateDirectories:true)
try FileManager.default.createDirectory(at:docsFolder,withIntermediateDirectories:true)
func color(_ hex: UInt32) -> CGColor {
    CGColor(red:Double((hex >> 16) & 255)/255,green:Double((hex >> 8) & 255)/255,blue:Double(hex & 255)/255,alpha:1)
}
func render(size: Int,to url: URL) throws {
    let space = CGColorSpaceCreateDeviceRGB()
    guard let c = CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:size*4,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("Cannot create icon context") }
    c.translateBy(x:0,y:CGFloat(size)); c.scaleBy(x:CGFloat(size)/512,y:-CGFloat(size)/512)
    func rounded(_ x: Double,_ y: Double,_ w: Double,_ h: Double,_ radius: Double) -> CGPath {
        CGPath(roundedRect:CGRect(x:x,y:y,width:w,height:h),cornerWidth:radius,cornerHeight:radius,transform:nil)
    }
    c.saveGState(); c.addPath(rounded(8,8,496,496,112)); c.clip()
    let background = CGGradient(colorsSpace:space,colors:[color(0x19253B),color(0x0C121F)] as CFArray,locations:[0,1])!
    c.drawLinearGradient(background,start:CGPoint(x:8,y:8),end:CGPoint(x:504,y:504),options:[]); c.restoreGState()
    c.addPath(rounded(25,25,462,462,98)); c.setStrokeColor(color(0x2B3B55)); c.setLineWidth(2); c.strokePath()
    c.addPath(rounded(70,159,372,194,78)); c.setFillColor(color(0x101C30)); c.fillPath()
    c.saveGState(); c.addPath(rounded(70,159,372,194,78)); c.setLineWidth(14); c.replacePathWithStrokedPath(); c.clip()
    let edge = CGGradient(colorsSpace:space,colors:[color(0x73DAFF),color(0x4A7DFF)] as CFArray,locations:[0,1])!
    c.drawLinearGradient(edge,start:CGPoint(x:70,y:256),end:CGPoint(x:442,y:256),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation]); c.restoreGState()
    c.setStrokeColor(color(0xE9F4FF)); c.setLineWidth(13); c.setLineCap(.round); c.setLineJoin(.round)
    c.move(to:CGPoint(x:138,y:232)); c.addLine(to:CGPoint(x:138,y:280)); c.move(to:CGPoint(x:114,y:256)); c.addLine(to:CGPoint(x:162,y:256)); c.strokePath()
    c.setLineWidth(12); c.move(to:CGPoint(x:210,y:285)); c.addLine(to:CGPoint(x:210,y:244))
    c.addCurve(to:CGPoint(x:256,y:200),control1:CGPoint(x:210,y:218),control2:CGPoint(x:230,y:200))
    c.addCurve(to:CGPoint(x:302,y:244),control1:CGPoint(x:282,y:200),control2:CGPoint(x:302,y:218))
    c.addLine(to:CGPoint(x:302,y:285)); c.move(to:CGPoint(x:196,y:285)); c.addLine(to:CGPoint(x:316,y:285)); c.strokePath()
    c.setStrokeColor(color(0x73DAFF)); c.setLineWidth(7); c.move(to:CGPoint(x:210,y:248)); c.addLine(to:CGPoint(x:302,y:248)); c.strokePath()
    c.setFillColor(color(0x77C9FF))
    for (x,y) in [(374,231),(399,256),(374,281),(349,256)] { c.fillEllipse(in:CGRect(x:x-9,y:y-9,width:18,height:18)) }
    c.setFillColor(color(0x45617E)); c.addPath(rounded(223,323,24,5,2.5)); c.addPath(rounded(265,323,24,5,2.5)); c.fillPath()
    guard let image = c.makeImage(),let destination = CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil) else { fatalError("Cannot encode icon") }
    CGImageDestinationAddImage(destination,image,nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write icon") }
}
var images: [[String:String]] = []
for points in [16,32,128,256,512] {
    for scale in [1,2] {
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(size:points*scale,to:iconFolder.appendingPathComponent(filename))
        images.append(["idiom":"mac","size":"\(points)x\(points)","scale":"\(scale)x","filename":filename])
    }
}
let json: [String:Any] = ["images":images,"info":["author":"xcode","version":1]]
try JSONSerialization.data(withJSONObject:json,options:[.prettyPrinted,.sortedKeys]).write(to:iconFolder.appendingPathComponent("Contents.json"))
try render(size:512,to:docsFolder.appendingPathComponent("vitabridge-logo.png"))
print("Generated original VitaBridge PNG logo and all ten macOS app-icon sizes.")
