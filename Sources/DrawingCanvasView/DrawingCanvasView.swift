// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import UIKit
public protocol DrawingCanvasDelegate: AnyObject {
    func stateChangeForUndo(isAvailable: Bool)
    func stateChangeForRedo(isAvailable: Bool)
}
public class DrawingCanvasView: UIView {
    
    weak var delegate: DrawingCanvasDelegate?
    private var brushColor: UIColor = UIColor.red.withAlphaComponent(0.3)
    private var imageView: UIImageView! = UIImageView()
    private var blendMode: CGBlendMode = .copy
    private var lastPoint: CGPoint!
    private var brushWidth: CGFloat = 20.0
    private var isDrawing = false
    
    private var imageStack: [UIImage] = [] {
        didSet {
            delegate?.stateChangeForUndo(isAvailable: !imageStack.isEmpty)
            isUndoEnabled = !imageStack.isEmpty
        }
    }
    private var redoStack: [UIImage] = [] {
        didSet {
            delegate?.stateChangeForRedo(isAvailable: !redoStack.isEmpty)
            isRedoEnabled = !redoStack.isEmpty
        }
    }
    
    public var isUndoEnabled = false
    public var isRedoEnabled = false
    
    public var currentMaskImage: UIImage? {
        return imageView.image
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupImageView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupImageView()
    }
    
    private func setupImageView() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        self.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: self.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        self.isUserInteractionEnabled = true
    }
    
    public func setImage(image: UIImage) {
            imageView.image = image
            refresh()
    }
    public func setMaskToImage(image: UIImage) {
        let ciImage = CIImage(cgImage: (image.cgImage)!)
        let filteredImage = ciImage.filteredImage()
        if let maskedImage = filteredImage.maskWithColor(color: brushColor)?.flipVertically(){
            imageView.image = maskedImage
            refresh()
        }
    }
    public func setbrushSize(size: CGFloat) {
        self.brushWidth = size
    }
    public func setBrushColor(color: UIColor) {
        self.brushColor = color
    }
    
    public func setDrawing(blendMode: CGBlendMode) {
        self.blendMode = blendMode
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDrawing = true
        if let touch = touches.first {
            lastPoint = touch.location(in: imageView)
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDrawing {
            if let touch = touches.first {
                let currentPoint = touch.location(in: imageView)
                drawLineFrom(lastPoint, toPoint: currentPoint)
                lastPoint = currentPoint
            }
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDrawing {
            if let touch = touches.first {
                let currentPoint = touch.location(in: imageView)
                drawLineFrom(lastPoint, toPoint: currentPoint)
                lastPoint = currentPoint
            }
            isDrawing = false
            if let image = imageView.image, !image.imageIsEmpty() {
                imageStack.append(image)
                redoStack.removeAll() // Clear redo stack after new drawing
            }
        }
    }
    

    private func drawLineFrom(_ fromPoint: CGPoint, toPoint: CGPoint) {
        guard let originalImage = imageView.image else { return }
        guard originalImage.size != .zero else { return }

        let scaleX = originalImage.size.width / imageView.frame.size.width
        let scaleY = originalImage.size.height / imageView.frame.size.height

        let scaledFromPoint = CGPoint(x: fromPoint.x * scaleX, y: fromPoint.y * scaleY)
        let scaledToPoint = CGPoint(x: toPoint.x * scaleX, y: toPoint.y * scaleY)

        let renderer = UIGraphicsImageRenderer(size: originalImage.size)
        let image = renderer.image { context in
            // Draw the original image
            originalImage.draw(at: .zero)
            
            context.cgContext.move(to: scaledFromPoint)
            context.cgContext.addLine(to: scaledToPoint)
            context.cgContext.setLineCap(.round)
            context.cgContext.setLineWidth(brushWidth * scaleX)
            context.cgContext.setStrokeColor(brushColor.cgColor)
            context.cgContext.setBlendMode(blendMode)
            context.cgContext.strokePath()
        }
        imageView.image = image
    }
    
    private func refresh() {
        guard imageView.frame.size != .zero else { return }
        let renderer = UIGraphicsImageRenderer(size: imageView.frame.size)
        let currentImage = renderer.image { context in
            imageView.image?.draw(in: imageView.bounds)
            context.cgContext.setLineCap(.round)
            context.cgContext.setLineWidth(0.1)
            context.cgContext.setStrokeColor(brushColor.cgColor)
            context.cgContext.setBlendMode(blendMode)
            context.cgContext.strokePath()
        }
        imageView.image = currentImage
        imageStack.append(currentImage)
    }
    
    public func undo() {
        if !imageStack.isEmpty {
            redoStack.append(imageStack.removeLast())
            imageView.image = imageStack.last
        }
    }
    
    public func redo() {
        if !redoStack.isEmpty {
            imageStack.append(redoStack.removeLast())
            imageView.image = imageStack.last
        }
    }
    
    public func clearCanvas() {
        imageView.image = nil
        imageStack.removeAll()
        redoStack.removeAll()
    }
}

extension UIImage {
    func convertTransparentToBlackAndOpaqueToWhite() -> UIImage? {
            guard let cgImage = self.cgImage else { return nil }
            
            let width = cgImage.width
            let height = cgImage.height
            let colorSpace = CGColorSpaceCreateDeviceGray()
            
            // Create a bitmap context with only alpha channel (1 bit per pixel)
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
            
            // Draw the image in the context
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            // Get the pixel data from the context
            guard let data = context.data else { return nil }
            
            // Convert the pixel data
            let pixelBuffer = data.bindMemory(to: UInt8.self, capacity: width * height)
            for y in 0..<height {
                for x in 0..<width {
                    let pixelIndex = y * width + x
                    let alphaValue = pixelBuffer[pixelIndex]
                    pixelBuffer[pixelIndex] = alphaValue > 0 ? 255 : 0
                }
            }
            
            // Create a new image from the pixel data
            guard let newCGImage = context.makeImage() else { return nil }
            
            return UIImage(cgImage: newCGImage)
        }
        func imageIsEmpty() -> Bool {
            guard let cgImage = self.cgImage else {
                return true
            }

            let width = cgImage.width
            let height = cgImage.height
            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * width
            let bitsPerComponent = 8

            var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let context = CGContext(data: &pixelData,
                                    width: width,
                                    height: height,
                                    bitsPerComponent: bitsPerComponent,
                                    bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)

            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            // Check for any non-transparent pixel
            for pixel in stride(from: 3, to: pixelData.count, by: bytesPerPixel) {
                if pixelData[pixel] > 0 {
                    return false
                }
            }

            return true
        }
    
   
    func maskWithColor(color: UIColor) -> UIImage? {
        let maskingColors: [CGFloat] = [1, 255, 1, 255, 1, 255]
        let bounds = CGRect(origin: .zero, size: size)
        guard let maskImage = cgImage else{return nil}
        var returnImage: UIImage?
        
        // make sure image has no alpha channel
        let rFormat = UIGraphicsImageRendererFormat()
        rFormat.opaque = true
        let size = size
        UIGraphicsBeginImageContextWithOptions(size, true, 0.0)
        draw(in: CGRect(origin: CGPoint.zero, size: size))
        let noAlphaImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let noAlphaCGRef = noAlphaImage?.cgImage
        
        if let imgRefCopy = noAlphaCGRef?.copy(maskingColorComponents: maskingColors) {
            
            let rFormat = UIGraphicsImageRendererFormat()
            rFormat.opaque = false
            let renderer = UIGraphicsImageRenderer(size: size, format: rFormat)
            returnImage = renderer.image {
                (context) in
                context.cgContext.clip(to: bounds, mask: maskImage)
                context.cgContext.setFillColor(color.cgColor)
                context.cgContext.fill(bounds)
                context.cgContext.draw(imgRefCopy, in: bounds)
            }
            
        }
        return returnImage
    }
    func flipVertically() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.translateBy(x: self.size.width/2, y: self.size.height/2)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -self.size.width/2, y: -self.size.height/2)
        
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
extension CIImage{
    func filteredImage() -> UIImage {
        if let matrixFilter = CIFilter(name: "CIColorMatrix") {
            matrixFilter.setDefaults()
            matrixFilter.setValue(self, forKey: kCIInputImageKey)
            let rgbVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            let aVector = CIVector(x: 1, y: 1, z: 1, w: 0)
            matrixFilter.setValue(rgbVector, forKey: "inputRVector")
            matrixFilter.setValue(rgbVector, forKey: "inputGVector")
            matrixFilter.setValue(rgbVector, forKey: "inputBVector")
            matrixFilter.setValue(aVector, forKey: "inputAVector")
            matrixFilter.setValue(CIVector(x: 1, y: 1, z: 1, w: 0), forKey: "inputBiasVector")
            
            if let matrixOutput = matrixFilter.outputImage, let cgImage = CIContext().createCGImage(matrixOutput, from: matrixOutput.extent) {
                let finalImage = UIImage(cgImage: cgImage)
                return finalImage
            }
            
        }
        return UIImage()
    }
}
