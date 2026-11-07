import SwiftUI

struct SignaturePad: View {
    @Environment(\.dismiss) private var dismiss
    @State private var points: [[CGPoint]] = []
    @State private var current: [CGPoint] = []
    var onSave: (UIImage) -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Draw your signature / ارسم توقيعك").font(.headline)
                GeometryReader { geo in
                    ZStack {
                        Color.white
                        ForEach(points.indices, id: \.self) { i in path(points[i]).stroke(.black, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)) }
                        path(current).stroke(.black, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(.gray.opacity(0.3)))
                    .gesture(DragGesture(minimumDistance: 0).onChanged { current.append($0.location) }.onEnded { _ in points.append(current); current = [] })
                    .onAppear { _ = geo }
                }
                .frame(height: 280)
                HStack {
                    Button("Clear") { points = []; current = [] }.buttonStyle(.bordered)
                    Spacer()
                    Button("Save signature") { onSave(render()); dismiss() }.buttonStyle(.borderedProminent).disabled(points.isEmpty)
                }
            }.padding().navigationTitle("Signature").navigationBarTitleDisplayMode(.inline)
        }
    }
    private func path(_ pts: [CGPoint]) -> Path { var p = Path(); guard let first = pts.first else { return p }; p.move(to: first); for point in pts.dropFirst() { p.addLine(to: point) }; return p }
    private func render() -> UIImage {
        let size = CGSize(width: 1200, height: 500)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
            let scale = CGAffineTransform(scaleX: size.width / 350, y: size.height / 280)
            for stroke in points {
                let transformed = path(stroke).applying(scale)
                context.cgContext.addPath(transformed.cgPath)
                context.cgContext.setStrokeColor(UIColor.black.cgColor)
                context.cgContext.setLineWidth(9)
                context.cgContext.setLineCap(.round)
                context.cgContext.setLineJoin(.round)
                context.cgContext.strokePath()
            }
        }
    }
}
