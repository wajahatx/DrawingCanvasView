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
    
    @Binding var currentMaskImage: UIImage?
    @Published public var isUndoEnabled = false
    @Published public var isRedoEnabled = false
    @Published public var brushSize: Double {
            didSet {
                canvasView.setbrushSize(size: brushSize)
            }
        }
        
    @Published public var image: UIImage? {
            didSet {
                updateCanvasIfNeeded()
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
        self._currentMaskImage = .constant(nil)
        self.brushSize = 30
        self.image = nil
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
    
    public func updateCanvasIfNeeded() {
        if let newImage = image, newImage != currentMaskImage {
            canvasView.setImage(image: newImage)
        }
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
        Task { @MainActor in
            controller.currentMaskImage = uiView.currentMaskImage
            controller.updateCanvasIfNeeded()
        }
    }
}
