//
//  File.swift
//  DrawingCanvasView
//
//  Created by Wajahat on 15/01/2025.
//

import Foundation
import SwiftUI


public enum BrushType {
    case brush
    case eraser
}


@MainActor
public class CanvasController: ObservableObject {
    let canvasView: DrawingCanvasView
    
    @Published public var isUndoEnabled = false
    @Published public var isRedoEnabled = false
    @Published public var brushSize: Double {
            didSet {
                canvasView.setBrushSize(size: brushSize)
            }
        }
        
    @Published public var brushColor: Color {
            didSet {
                canvasView.setBrushColor(color: UIColor(brushColor))
            }
        }
        
    @Published public var blendMode: BrushType {
            didSet {
                canvasView.setDrawing(blendMode: blendMode == .brush ? .copy : .clear)
            }
        }
    
    public init() {
        self.canvasView = DrawingCanvasView(frame: .zero)
        self.brushSize = 30
        self.brushColor = .black
        self.blendMode = .brush
        self.canvasView.delegate = self
    }
    
    public func undo() {
        canvasView.undo()
    }
    
    public func redo() {
        canvasView.redo()
    }
    
    public func clearCanvas() {
        canvasView.clearCanvas()
    }
    
    public func setMaxThreshold(numberOfImages number: Int){
        canvasView.setMaxThresholdForStack(numberOfImages: number)
    }
    
    public func setImage(image: UIImage?) {
        guard let image else { return }
        canvasView.setImage(image: image)
        adjustCanvasSizeToAspectRatio(for: image)
    }
    
    public func setMaskToImage(image: UIImage?) {
        guard let image = image?.resizeWithAspectRatio(to: CGSize(width: 512, height: 512)) else { return }
        canvasView.setMaskToImage(image: image)
        adjustCanvasSizeToAspectRatio(for: image)
    }
    public func getMask(completion: @escaping (UIImage?) -> Void){
        self.canvasView.currentMaskImage?.convertTransparentToBlackAndOpaqueToWhite(completion: completion)
        
    }
    public func getImage() -> UIImage? {
        self.canvasView.currentMaskImage
    }
    private func adjustCanvasSizeToAspectRatio(for image: UIImage) {
           let imageWidth = image.size.width
           let imageHeight = image.size.height
           
           let aspectRatio = imageWidth / imageHeight
           
            var newSize = self.canvasView.frame.size
           newSize.height = newSize.width / aspectRatio
           
           canvasView.frame.size = newSize
       }
}

extension CanvasController: @preconcurrency DrawingCanvasDelegate {
    public func stateChangeForUndo(isAvailable: Bool) {
        isUndoEnabled = isAvailable
    }
    
    public func stateChangeForRedo(isAvailable: Bool) {
        isRedoEnabled = isAvailable
    }
}

public struct DrawingCanvas: UIViewRepresentable {
    @ObservedObject var controller: CanvasController
    
    public init(controller: CanvasController) {
        self.controller = controller
    }
    
    public func makeUIView(context: Context) -> DrawingCanvasView {
        return controller.canvasView
    }
    
    public func updateUIView(_ uiView: DrawingCanvasView, context: Context) {
        
    }
}
