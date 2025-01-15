//
//  File.swift
//  DrawingCanvasView
//
//  Created by Wajahat on 15/01/2025.
//

import Foundation
import SwiftUI
struct SUDrawingCanvasView: UIViewRepresentable {
    @Binding var isUndoAvailable: Bool
    @Binding var isRedoAvailable: Bool
    @Binding var brushColor: UIColor
    @Binding var brushType: BrushType
    @Binding var currentMaskImage: UIImage?

    enum BrushType {
        case brush
        case eraser
    }

    enum CanvasAction {
        case undo
        case redo
        case clearCanvas
    }

    var actionHandler: ((CanvasAction) -> Void)?

    class Coordinator: NSObject, @preconcurrency DrawingCanvasDelegate {
        var parent: SUDrawingCanvasView
        var canvasView: DrawingCanvasView?

        init(parent: SUDrawingCanvasView) {
            self.parent = parent
        }

        @MainActor func stateChangeForUndo(isAvailable: Bool) {
                self.parent.isUndoAvailable = isAvailable
            
        }

        @MainActor func stateChangeForRedo(isAvailable: Bool) {
            
                self.parent.isRedoAvailable = isAvailable
            
        }

        @MainActor func updateBrushType(to brushType: BrushType) {
            switch brushType {
            case .brush:
                canvasView?.brush()
            case .eraser:
                canvasView?.eraser()
            }
        }

        @MainActor func handleAction(_ action: CanvasAction) {
            switch action {
            case .undo:
                canvasView?.undo()
            case .redo:
                canvasView?.redo()
            case .clearCanvas:
                canvasView?.clearCanvas()
            }
            updateCurrentMaskImage()
        }

        @MainActor func updateCurrentMaskImage() {
            
                self.parent.currentMaskImage = self.canvasView?.currentMaskImage
            
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> DrawingCanvasView {
        let canvasView = DrawingCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.setBrushColor(color: brushColor)

        // Save reference for the Coordinator
        context.coordinator.canvasView = canvasView

        return canvasView
    }

    func updateUIView(_ uiView: DrawingCanvasView, context: Context) {
        uiView.setBrushColor(color: brushColor)
        context.coordinator.updateBrushType(to: brushType)
        context.coordinator.updateCurrentMaskImage()
    }
}
