// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import UIKit
protocol DrawingCanvasDelegate: AnyObject {
    func stateChangeForUndo(isAvailable: Bool)
    func stateChangeForRedo(isAvailable: Bool)
}
class DrawingCanvasView: UIView {
    
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
    
    var isUndoEnabled = false
    var isRedoEnabled = false
    
    var currentMaskImage: UIImage? {
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
    
    func setImage(image: UIImage) {
        let ciImage = CIImage(cgImage: (image.cgImage)!)
        let filteredImage = ciImage.filteredImage()
        if let maskedImage = filteredImage.maskWithColor(color: brushColor)?.flipVertically(){
            imageView.image = maskedImage
            refresh()
        }
    }
    func setBrushColor(color: UIColor) {
        self.brushColor = color
    }
    
    func setDrawing(blendMode: CGBlendMode) {
        self.blendMode = blendMode
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDrawing = true
        if let touch = touches.first {
            lastPoint = touch.location(in: imageView)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDrawing {
            if let touch = touches.first {
                let currentPoint = touch.location(in: imageView)
                drawLineFrom(lastPoint, toPoint: currentPoint)
                lastPoint = currentPoint
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
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
        guard imageView.frame.size != .zero else { return }
        let renderer = UIGraphicsImageRenderer(size: imageView.frame.size)
        let image = renderer.image { context in
            imageView.image?.draw(at: .zero)
            context.cgContext.move(to: fromPoint)
            context.cgContext.addLine(to: toPoint)
            context.cgContext.setLineCap(.round)
            context.cgContext.setLineWidth(brushWidth)
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
    
    func undo() {
        if !imageStack.isEmpty {
            redoStack.append(imageStack.removeLast())
            imageView.image = imageStack.last
        }
    }
    
    func redo() {
        if !redoStack.isEmpty {
            imageStack.append(redoStack.removeLast())
            imageView.image = imageStack.last
        }
    }
    
    func eraser() {
        blendMode = .clear
    }
    
    func brush() {
        blendMode = .copy
    }
    
    func clearCanvas() {
        imageView.image = nil
        imageStack.removeAll()
        redoStack.removeAll()
    }
}

extension UIImage {
    func imageIsEmpty() -> Bool {
        guard let cgImage = self.cgImage, let dataProvider = cgImage.dataProvider else {
            return true
        }

        let pixelData = dataProvider.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let imageWidth = Int(self.size.width)
        let imageHeight = Int(self.size.height)
        for x in 0..<imageWidth {
            for y in 0..<imageHeight {
                let pixelIndex = ((imageWidth * y) + x) * 4
                let r = data[pixelIndex]
                let g = data[pixelIndex + 1]
                let b = data[pixelIndex + 2]
                let a = data[pixelIndex + 3]
                if a != 0, r != 0 || g != 0 || b != 0 {
                    return false
                }
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
            let aVector = CIVector(x: -1, y: -1, z: -1, w: 1)
            
            matrixFilter.setValue(rgbVector, forKey: "inputRVector")
            matrixFilter.setValue(rgbVector, forKey: "inputGVector")
            matrixFilter.setValue(rgbVector, forKey: "inputBVector")
            matrixFilter.setValue(aVector, forKey: "inputAVector")
            
            matrixFilter.setValue(CIVector(x: 1, y: 1, z: 1, w: 0), forKey: "inputBiasVector")
            
            if let matrixOutput = matrixFilter.outputImage,
               let cgImage = CIContext().createCGImage(matrixOutput, from: matrixOutput.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return UIImage()
    }
}
