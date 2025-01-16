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
                canvasView.setbrushSize(size: brushSize)
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
    
    public func setImage(image: UIImage?) {
        guard let image else { return }
        canvasView.setImage(image: image)
    }
    
    public func setMaskToImage(image: UIImage?) {
        guard let image else { return }
        canvasView.setMaskToImage(image: image)
    }
    public func getMask() -> UIImage? {
        self.canvasView.currentMaskImage?.convertTransparentToBlackAndOpaqueToWhite()
    }
    public func getImage() -> UIImage? {
        self.canvasView.currentMaskImage
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
