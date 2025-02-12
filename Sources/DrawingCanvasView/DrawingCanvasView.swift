// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import UIKit
public protocol DrawingCanvasDelegate: AnyObject {
    func stateChangeForUndo(isAvailable: Bool)
    func stateChangeForRedo(isAvailable: Bool)
}
public class DrawingCanvasView: UIView {
    
    // MARK: - Properties
    weak var delegate: DrawingCanvasDelegate?
    private var brushColor: UIColor = UIColor.red.withAlphaComponent(0.3)
    private var brushWidth: CGFloat = 20.0
    private var blendMode: CGBlendMode = .copy
    
    private var lastPoint: CGPoint = .zero
    private var isDrawing = false
    
    private var mainImage: UIImage?
    
    private var maxUndoRedoStackSize = 5
    
    private var undoStack: [UIImage] = [] {
        didSet {
            delegate?.stateChangeForUndo(isAvailable: !undoStack.isEmpty)
        }
    }
    private var redoStack: [UIImage] = [] {
        didSet {
            delegate?.stateChangeForRedo(isAvailable: !redoStack.isEmpty)
        }
    }
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: self.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        return imageView
    }()
    
    // MARK: - Public API
    public var currentMaskImage: UIImage? {
        return mainImage
    }
    
    public var isUndoEnabled: Bool {
        return !undoStack.isEmpty
    }
    
    public var isRedoEnabled: Bool {
        return !redoStack.isEmpty
    }
    
    public func setImage(image: UIImage) {
        mainImage = image
        undoStack.removeAll()
        redoStack.removeAll()
        updateCanvas()
    }
    
    public func setMaskToImage(image: UIImage) {
        let ciImage = CIImage(cgImage: (image.cgImage)!)
        let filteredImage = ciImage.filteredImage()
        if let maskedImage = filteredImage.maskWithColor(color: brushColor)?.flipVertically(){
            setImage(image: maskedImage)
        }
        
    }
    
    public func setMaxThresholdForStack(numberOfImages number: Int){
        self.maxUndoRedoStackSize = number
    }
    public func setBrushSize(size: CGFloat) {
        brushWidth = size
    }
    
    public func setBrushColor(color: UIColor) {
        brushColor = color
    }
    
    public func setDrawing(blendMode: CGBlendMode) {
        self.blendMode = blendMode
    }
    
    
    public func undo() {
        guard !undoStack.isEmpty else { return }
        
        if let lastImage = undoStack.popLast() {
            redoStack.append(mainImage ?? UIImage())
            if redoStack.count > maxUndoRedoStackSize {
                redoStack.removeFirst()
            }
            
            mainImage = lastImage
            updateCanvas()
        }
    }
    
    public func redo() {
        guard !redoStack.isEmpty else { return }
        
        if let redoImage = redoStack.popLast() {
            undoStack.append(mainImage ?? UIImage())
            if undoStack.count > maxUndoRedoStackSize {
                undoStack.removeFirst()
            }
            
            mainImage = redoImage
            updateCanvas()
        }
    }
    
    public func clearCanvas() {
        mainImage = nil
        undoStack.removeAll()
        redoStack.removeAll()
        updateCanvas()
    }
    
    // MARK: - Initializers
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Touch Handling
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDrawing = true
        guard let touch = touches.first else { return }
        lastPoint = touch.location(in: self)
        
        // Push the current image state onto the undo stack before drawing
        if let currentImage = mainImage {
            undoStack.append(currentImage)
            if undoStack.count > maxUndoRedoStackSize {
                undoStack.removeFirst()  // Remove oldest image to maintain the limit
            }
        } else {
            undoStack.append(UIImage())
        }
        
        // Clear the redo stack because new drawing invalidates redo history
        redoStack.removeAll()
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let currentPoint = touch.location(in: self)
        drawLine(from: lastPoint, to: currentPoint)
        lastPoint = currentPoint
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let currentPoint = touch.location(in: self)
        drawLine(from: lastPoint, to: currentPoint)
        lastPoint = .zero
    }
    
    // MARK: - Drawing Logic
    private func drawLine(from startPoint: CGPoint, to endPoint: CGPoint) {
        let size = bounds.size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Draw the main image
            mainImage?.draw(in: bounds)
            
            // Configure the drawing context
            context.cgContext.setLineCap(.round)
            context.cgContext.setLineWidth(brushWidth)
            context.cgContext.setStrokeColor(brushColor.cgColor)
            context.cgContext.setBlendMode(blendMode)
            
            // Draw the line
            context.cgContext.move(to: startPoint)
            context.cgContext.addLine(to: endPoint)
            context.cgContext.strokePath()
        }
        
        mainImage = image
        updateCanvas()
    }
    
    private func updateCanvas() {
        imageView.image = mainImage
    }
}

extension UIImage {
    @MainActor
    func convertTransparentToBlackAndOpaqueToWhite(completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = self.cgImage else {
                Task { @MainActor in completion(nil) }
                return
            }

            let width = cgImage.width
            let height = cgImage.height
            let colorSpace = CGColorSpaceCreateDeviceGray()

            // Create a bitmap context with only alpha channel (1 bit per pixel)
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
                Task { @MainActor in completion(nil) }
                return
            }

            // Draw the image in the context
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            // Get the pixel data from the context
            guard let data = context.data else {
                Task { @MainActor in completion(nil) }
                return
            }

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
            guard let newCGImage = context.makeImage() else {
                Task { @MainActor in completion(nil) }
                return
            }

            let resultImage = UIImage(cgImage: newCGImage)

            Task { @MainActor in completion(resultImage) }
        }
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
