import SwiftUI

struct InteractiveCursorModifier: ViewModifier {
    let hoverCursor: NSCursor
    let draggingCursor: NSCursor?
    
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if !isDragging {
                    if hovering {
                        hoverCursor.push()
                        isHovering = true
                    } else if isHovering {
                        NSCursor.pop()
                        isHovering = false
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isDragging {
                            isDragging = true
                            if let dragCursor = draggingCursor {
                                dragCursor.push()
                            }
                        }
                    }
                    .onEnded { _ in
                        if isDragging {
                            if draggingCursor != nil {
                                NSCursor.pop()
                            }
                            isDragging = false
                        }
                    }
            )
    }
}

extension View {
    func interactiveCursor(hover: NSCursor, dragging: NSCursor? = nil) -> some View {
        self.modifier(InteractiveCursorModifier(hoverCursor: hover, draggingCursor: dragging))
    }
}

enum Ratio: String, CaseIterable, Identifiable {
    case square = "Square", sixteenNine = "16:9", twoOne = "2:1", threeOne = "3:1", fourOne = "4:1"
    var id: String { rawValue }
    var value: CGFloat {
        switch self {
        case .square: return 1; case .sixteenNine: return 16/9; case .twoOne: return 2; case .threeOne: return 3; case .fourOne: return 4
        }
    }
}

struct LayoutFrames {
    let displayedSize: CGSize
    let cropSize: CGSize
}

struct CropDimmingShape: Shape {
    var holeRect: CGRect
    var animatableData: CGRect.AnimatableData { get { holeRect.animatableData } set { holeRect.animatableData = newValue } }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRect(holeRect)
        return path
    }
}

struct CropImageView: View {
    let inputImage: NSImage
    var onSave: (NSImage, NSImage) -> Void
    var onCancel: () -> Void
    
    @State private var selectedRatio: Ratio = .square
    @State private var isResizing: Bool = false
    
    // State for layout and cropping
    @State private var displayedSize: CGSize = .zero
    @State private var cropRect: CGRect = .zero
    @State private var initialCropRect: CGRect = .zero
    @State private var dragStartRect: CGRect?
    
    private let margin: CGFloat = 40
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if displayedSize != .zero {
                    drawingArea
                        .frame(width: displayedSize.width, height: displayedSize.height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                updateLayout(containerSize: geometry.size)
            }
            .onChange(of: geometry.size) { newSize in
                updateLayout(containerSize: newSize)
            }
            .onChange(of: selectedRatio) { _ in
                resetCropToInitial()
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
        .toolbar { toolbarContent }
        .navigationTitle("Crop")
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Logic
    
    @MainActor
    private func snapshotCroppedImage() -> NSImage? {
        let cropWidth = cropRect.width
        let cropHeight = cropRect.height
        
        // 1. Define the view that represents the cropped result
        let croppedView = Image(nsImage: inputImage)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: displayedSize.width, height: displayedSize.height)
            .position(x: displayedSize.width / 2, y: displayedSize.height / 2)
            .offset(x: -cropRect.origin.x, y: -cropRect.origin.y)
            .frame(width: cropWidth, height: cropHeight, alignment: .topLeading)
            .clipped()
            .edgesIgnoringSafeArea(.all)

        // 2. Wrap in NSHostingView
        let hostingView = NSHostingView(rootView: croppedView)
        
        // 3. Set the frame to the desired crop size
        // We use the backing scale factor to ensure high resolution (Retina)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let frame = CGRect(origin: .zero, size: CGSize(width: cropWidth, height: cropHeight))
        hostingView.frame = frame
        
        // 4. Force layout
        hostingView.layout()
        
        // 5. Render to NSBitmapImageRep
        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: frame) else {
            return nil
        }
        
        // Important: Set the size of the bitmap to match the pixel dimensions for high-DPI
        bitmapRep.size = frame.size
        
        hostingView.cacheDisplay(in: frame, to: bitmapRep)
        
        // 6. Create NSImage
        let image = NSImage(size: frame.size)
        image.addRepresentation(bitmapRep)
        
        return image
    }
    
    private func updateLayout(containerSize: CGSize) {
        let availableWidth = containerSize.width - (margin * 2)
        let availableHeight = containerSize.height - (margin * 2)
        guard availableWidth > 0, availableHeight > 0 else { return }
        
        let imageSize = inputImage.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        
        let scaleFactor = min(availableWidth / imageSize.width, availableHeight / imageSize.height)
        let newDisplayedWidth = imageSize.width * scaleFactor
        let newDisplayedHeight = imageSize.height * scaleFactor
        let newDisplayedSize = CGSize(width: newDisplayedWidth, height: newDisplayedHeight)
        
        self.displayedSize = newDisplayedSize
        
        // Calculate initial crop rect based on ratio
        resetCropToInitial()
    }
    
    private func resetCropToInitial() {
        guard displayedSize.width > 0, displayedSize.height > 0 else { return }
        
        let imageAspectRatio = displayedSize.width / displayedSize.height
        let desiredRatio = selectedRatio.value
        
        var cropWidth: CGFloat, cropHeight: CGFloat
        if desiredRatio > imageAspectRatio {
            cropWidth = displayedSize.width
            cropHeight = displayedSize.width / desiredRatio
        } else {
            cropWidth = displayedSize.height * desiredRatio
            cropHeight = displayedSize.height
        }
        
        let cropSize = CGSize(width: cropWidth, height: cropHeight)
        let x = (displayedSize.width - cropWidth) / 2
        let y = (displayedSize.height - cropHeight) / 2
        
        let newRect = CGRect(origin: CGPoint(x: x, y: y), size: cropSize)
        
        self.initialCropRect = newRect
        self.cropRect = newRect
    }
    
    private enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    private func resize(translation: CGSize, corner: Corner) {
        guard let startRect = dragStartRect else { return }
        let ratio = selectedRatio.value
        
        let anchor: CGPoint
        let xDirection: CGFloat
        let yDirection: CGFloat
        
        switch corner {
        case .topLeft:
            anchor = CGPoint(x: startRect.maxX, y: startRect.maxY)
            xDirection = -1
            yDirection = -1
        case .topRight:
            anchor = CGPoint(x: startRect.minX, y: startRect.maxY)
            xDirection = 1
            yDirection = -1
        case .bottomLeft:
            anchor = CGPoint(x: startRect.maxX, y: startRect.minY)
            xDirection = -1
            yDirection = 1
        case .bottomRight:
            anchor = CGPoint(x: startRect.minX, y: startRect.minY)
            xDirection = 1
            yDirection = 1
        }
        
        let availableW = xDirection > 0 ? (displayedSize.width - anchor.x) : anchor.x
        let availableH = yDirection > 0 ? (displayedSize.height - anchor.y) : anchor.y
        
        let maxW_byBounds = min(availableW, availableH * ratio)
        
        let maxW = min(maxW_byBounds, initialCropRect.width)
        
        let deltaWidth = translation.width * xDirection
        let proposedWidth = startRect.width + deltaWidth
        
        let finalWidth = min(max(proposedWidth, 50), maxW)
        let finalHeight = finalWidth / ratio
        
        let newX = xDirection > 0 ? anchor.x : (anchor.x - finalWidth)
        let newY = yDirection > 0 ? anchor.y : (anchor.y - finalHeight)
        
        self.cropRect = CGRect(x: newX, y: newY, width: finalWidth, height: finalHeight)
    }
    
    private func pan(translation: CGSize) {
        guard let startRect = dragStartRect else { return }
        
        let proposedX = startRect.origin.x + translation.width
        let proposedY = startRect.origin.y + translation.height
        
        let minX: CGFloat = 0
        let maxX = displayedSize.width - startRect.width
        let clampedX = min(max(proposedX, minX), maxX)
        
        let minY: CGFloat = 0
        let maxY = displayedSize.height - startRect.height
        let clampedY = min(max(proposedY, minY), maxY)
        
        self.cropRect.origin = CGPoint(x: clampedX, y: clampedY)
    }
    
    // MARK: - View Builders
    @ViewBuilder
    private var drawingArea: some View {
        ZStack {
            Image(nsImage: inputImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: displayedSize.width, height: displayedSize.height)
            
            CropDimmingShape(holeRect: cropRect)
                .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                .frame(width: displayedSize.width, height: displayedSize.height)
                .allowsHitTesting(false)
                .animation(.easeOut, value: selectedRatio)
            
            cropGuidesView
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
                .animation(.easeOut, value: selectedRatio)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                onCancel()
            }
        }
        ToolbarItem(placement: .principal) {
            Picker("Ratio", selection: $selectedRatio) {
                ForEach(Ratio.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
        }
        ToolbarItem(placement: .primaryAction) {
            Button("OK") {
                if let cropped = snapshotCroppedImage() {
                    onSave(inputImage, cropped)
                } else {
                    // Fallback if snapshot fails (shouldn't happen)
                    onSave(inputImage, inputImage)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private let gridLinesWidth: CGFloat = 1
    private let borderWidth: CGFloat = 1
    private let cornersWidth: CGFloat = 3
    private let cornersSize: CGFloat = 20
    private let borderColor: Color = .white
    private let gridColor: Color = .white.opacity(0.8)
    private let cornersColor: Color = .white
    
    private var cropGuidesView: some View {
        ZStack {
            Color.white.opacity(0.001)
                .interactiveCursor(hover: .openHand, dragging: .closedHand)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragStartRect == nil {
                                dragStartRect = cropRect
                                isResizing = true
                            }
                            pan(translation: value.translation)
                        }
                        .onEnded { _ in
                            dragStartRect = nil
                            isResizing = false
                        }
                )
            
//            ZStack {
//                HStack { Spacer(); Rectangle().fill(gridColor).frame(width: gridLinesWidth); Spacer(); Rectangle().fill(gridColor).frame(width: gridLinesWidth); Spacer() }
//                VStack { Spacer(); Rectangle().fill(gridColor).frame(height: gridLinesWidth); Spacer(); Rectangle().fill(gridColor).frame(height: gridLinesWidth); Spacer() }
//            }
//            .opacity(isResizing ? 1 : 0)
//            .allowsHitTesting(false)

            Rectangle().fill(Color.clear).border(borderColor, width: borderWidth).allowsHitTesting(false)

            cropCorners
        }
    }
    
    private var cropCorners: some View {
        ZStack {
            VStack {
                HStack {
                    interactiveCorner(cursor: .frameResize(position: .topLeft, directions: .all), alignment: .topLeading, corner: .topLeft)
                    Spacer()
                }
                Spacer()
            }
            VStack {
                HStack {
                    Spacer()
                    interactiveCorner(cursor: .frameResize(position: .topRight, directions: .all), alignment: .topTrailing, corner: .topRight)
                }
                Spacer()
            }
            VStack {
                Spacer()
                HStack {
                    interactiveCorner(cursor: .frameResize(position: .bottomLeft, directions: .all), alignment: .bottomLeading, corner: .bottomLeft)
                    Spacer()
                }
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    interactiveCorner(cursor: .frameResize(position: .bottomRight, directions: .all), alignment: .bottomTrailing, corner: .bottomRight)
                }
            }
        }
        .padding(-cornersWidth)
    }
    
    private func interactiveCorner(cursor: NSCursor, alignment: Alignment, corner: Corner) -> some View {
        ZStack(alignment: alignment) {
            Color.white.opacity(0.001).frame(width: 30, height: 30)
            ZStack(alignment: alignment) {
                Rectangle().fill(cornersColor).frame(width: cornersWidth, height: cornersSize)
                Rectangle().fill(cornersColor).frame(width: cornersSize, height: cornersWidth)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStartRect == nil {
                        dragStartRect = cropRect
                        isResizing = true
                    }
                    resize(translation: value.translation, corner: corner)
                }
                .onEnded { _ in
                    dragStartRect = nil
                    isResizing = false
                }
        )
        .interactiveCursor(hover: cursor)
    }
}

#Preview {
    let testImage: NSImage = {
        let size = NSSize(width: 800, height: 600)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGradient(starting: .darkGray, ending: .black)?.draw(in: NSRect(origin: .zero, size: size), angle: 90)
        NSColor.systemTeal.setFill(); NSBezierPath(rect: NSRect(x: 100, y: 100, width: 600, height: 400)).fill()
        image.unlockFocus()
        return image
    }()
    CropImageView(inputImage: testImage, onSave: { _,_  in }, onCancel: {})
}
