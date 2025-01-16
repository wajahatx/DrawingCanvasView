
# DrawingCanvasView

![Screenshot 2025-01-16 at 3 58 56 PM](https://github.com/user-attachments/assets/0d9b694d-590d-4d8a-bf78-3b54dd0f4fa6)


## SwiftUI Usage

`DrawingCanvasView` can be easily integrated into a SwiftUI project as follows:

### 1. Basic Integration in SwiftUI

To integrate **DrawingCanvasView** in your SwiftUI view, you can use the `DrawingCanvas` component, which wraps the UIKit-based `DrawingCanvasView`. Here is an example:

```swift
struct ContentView: View {
    @State private var currentImage: UIImage?
    @State private var brushColor: Color = .red.opacity(0.3)
    @State private var blendMode: BrushType = .brush
    @State private var brushSize: CGFloat = 10
    
    @StateObject private var canvasController = CanvasController()
    
    var body: some View {
        VStack {
            Image(.source)
                .resizable()
                .scaledToFit()
                .overlay {
                    DrawingCanvas(controller: canvasController)
                }
            
            HStack {
                Button("Undo") {
                    canvasController.undo()
                }
                .disabled(!canvasController.isUndoEnabled)
                
                Button("Redo") {
                    canvasController.redo()
                }
                .disabled(!canvasController.isRedoEnabled)
                
                Button("Clear") {
                    canvasController.clearCanvas()
                }
                Button("Save") {
                    let output = canvasController.getImage()
                    
                }
            }
            
            ColorPicker("Brush Color", selection: $canvasController.brushColor)
            
            Picker("Blend Mode", selection: $canvasController.blendMode) {
                Text("Brush").tag(BrushType.brush)
                Text("Eraser").tag(BrushType.eraser)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Slider(value: $canvasController.brushSize, in: 1...100) {
                Text("Brush Size")
            } minimumValueLabel: {
                Text("1")
            } maximumValueLabel: {
                Text("100")
            }
        }
        .padding()
    }
}
```

This code demonstrates how to use **DrawingCanvasView** with SwiftUI, allowing users to draw on the canvas, change brush size, color, and mode, and perform undo/redo actions.

## UIKit Usage

To integrate **DrawingCanvasView** in a UIKit-based project, you can either subclass `DrawingCanvasView` or use it directly as a `UIView` in your view controller. Below are the steps for both approaches:

### 1. Subclassing `DrawingCanvasView`

You can create a custom subclass of **DrawingCanvasView** to add further customizations if necessary. Here's an example of subclassing:

```swift
class CustomDrawingCanvasView: DrawingCanvasView {
    // Customize the canvas as needed
}
```

### 2. Instantiating and Using `DrawingCanvasView` Directly

You can also directly instantiate **DrawingCanvasView** in your view controller. Here's an example of how to use it:

```swift
// Initialize the canvas view
let canvasView = DrawingCanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
view.addSubview(canvasView)

// Set the brush size and color
canvasView.setbrushSize(size: 30)
canvasView.setBrushColor(color: UIColor.red)

// Set the drawing mode (brush or eraser)
canvasView.setDrawing(blendMode: .copy)  // Use .clear for eraser
```

### 3. Setting an Image or Mask on the Canvas

You can also set an image or a mask on the canvas using the `CanvasController`:

```swift
// Set an image to the canvas
canvasController.setImage(image: UIImage(named: "yourImage"))

// Set a mask to the canvas
canvasController.setMaskToImage(image: UIImage(named: "yourMaskImage"))
```

### 4. Handling Undo and Redo Actions

You can enable undo and redo functionality by calling the following methods:

```swift
canvasController.undo()  // Undo the last drawing action
canvasController.redo()  // Redo the last undone action
```

You can also check if undo/redo is enabled:

```swift
canvasController.isUndoEnabled   // Bool indicating if undo is available
canvasController.isRedoEnabled   // Bool indicating if redo is available
```

## License

Include your licensing information here.

---

This section should help guide users who are integrating **DrawingCanvasView** into their SwiftUI or UIKit-based projects.
