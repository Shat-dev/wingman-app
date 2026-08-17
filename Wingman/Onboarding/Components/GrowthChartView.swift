//
//  GrowthChartView.swift
//  Wingman
//
//  The "you vs. doing nothing" growth curve used by the onboarding
//  projection screen. Two smoothed lines draw themselves left-to-right over
//  ~1.5s, each with a dot riding the head of the stroke, and the callout
//  bubbles pop in once the lines land.
//
//  No dependency, no Lottie, no chart library. The whole effect is a
//  `Shape` + `.trim(from:to:)`, which is animatable out of the box: SwiftUI
//  interpolates the trim end from 0 to 1 and re-strokes the partial path
//  every frame. The travelling dot is a second `Shape` whose
//  `animatableData` is the same 0→1 value, so it reads the point off
//  `trimmedPath(...).currentPoint` on each of those frames and cannot drift
//  out of sync with the line — both are driven by one `withAnimation`.
//
//  Curves are declared as normalized points (0…1, y=0 at the top) and
//  mapped into the plot rect at draw time, so the shape of the story is
//  editable without touching any geometry code.
//

import SwiftUI

// MARK: - Curve geometry

/// Applies a SwiftUI `EdgeInsets` to a rect. `CGRect.inset(by:)` only takes
/// `UIEdgeInsets`, and mixing the two types across the file is the kind of
/// thing that silently flips leading/trailing under RTL later.
private func inset(_ rect: CGRect, by insets: EdgeInsets) -> CGRect {
    CGRect(
        x: rect.minX + insets.leading,
        y: rect.minY + insets.top,
        width: max(0, rect.width - insets.leading - insets.trailing),
        height: max(0, rect.height - insets.top - insets.bottom)
    )
}

/// Builds a Catmull-Rom-smoothed path through `points`, mapped from
/// normalized space into `rect`.
///
/// Catmull-Rom rather than `addQuadCurve` midpoint smoothing because the
/// resulting curve passes *through* every control point — the wiggle in the
/// rising line is authored as literal coordinates and lands where written.
private func smoothedPath(through points: [CGPoint], in rect: CGRect) -> Path {
    var path = Path()
    guard points.count > 1 else { return path }

    // Normalized → plot-rect space.
    func map(_ p: CGPoint) -> CGPoint {
        CGPoint(x: rect.minX + p.x * rect.width,
                y: rect.minY + p.y * rect.height)
    }

    let pts = points.map(map)
    path.move(to: pts[0])

    for i in 0..<(pts.count - 1) {
        let p0 = pts[max(i - 1, 0)]
        let p1 = pts[i]
        let p2 = pts[i + 1]
        let p3 = pts[min(i + 2, pts.count - 1)]

        // Standard Catmull-Rom → cubic Bézier control-point conversion
        // (tension 0.5, i.e. the /6 divisor).
        let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6,
                         y: p1.y + (p2.y - p0.y) / 6)
        let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6,
                         y: p2.y - (p3.y - p1.y) / 6)

        path.addCurve(to: p2, control1: c1, control2: c2)
    }

    return path
}

/// The line itself. `progress` is applied by the caller via `.trim`, which
/// is why this shape carries no animatable state of its own.
private struct GrowthCurveShape: Shape {
    let points: [CGPoint]
    let insets: EdgeInsets

    func path(in rect: CGRect) -> Path {
        smoothedPath(through: points, in: inset(rect, by: insets))
    }
}

/// A dot sitting on the curve at `progress` along its length.
///
/// Exists as a `Shape` rather than a positioned `Circle` because a `Shape`
/// gets `animatableData` for free: SwiftUI hands it every interpolated value
/// between 0 and 1, so the dot is re-drawn at a new point each frame instead
/// of jumping to the final position the moment the state changes.
private struct CurveHeadDot: Shape {
    let points: [CGPoint]
    let insets: EdgeInsets
    let radius: CGFloat
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let curve = smoothedPath(through: points, in: inset(rect, by: insets))
        // Clamped above 0: `trimmedPath(from: 0, to: 0)` is empty and its
        // `currentPoint` is nil, which would park the dot at the origin for
        // the first frame.
        let t = min(max(progress, 0.0001), 1)
        guard let head = curve.trimmedPath(from: 0, to: t).currentPoint else {
            return Path()
        }
        return Path(ellipseIn: CGRect(x: head.x - radius,
                                      y: head.y - radius,
                                      width: radius * 2,
                                      height: radius * 2))
    }
}

// MARK: - Chart

struct GrowthChartView: View {

    /// Callout text on the rising line (e.g. "Using Wingman daily").
    let positiveLabel: String
    /// Callout text on the falling line (e.g. "Doing nothing").
    let negativeLabel: String
    /// Axis captions under the plot.
    var startCaption: String = "TODAY"
    var endCaption: String = "IN 1 MONTH"

    // Every visibility toggle is its own `Bool` rather than a comparison
    // against `progress`. `progress` is written inside a `withAnimation`, so a
    // derived `progress > x ? 1 : 0` opacity does not *switch* at x — SwiftUI
    // sees a 0→1 opacity change in that transaction and interpolates it across
    // the whole 1.5s draw. That shipped as a half-faded halo trailing each head
    // dot and an end-of-chart guide visible from the first frame.
    @State private var progress: CGFloat = 0
    @State private var showCallouts = false
    @State private var showStartDot = false
    @State private var showEndMarkers = false

    /// Plot inset inside the view's frame. The top gap is headroom for the
    /// callout bubbles, the trailing gap keeps the rising line's bubble from
    /// running off the edge, and the leading gap leaves the start dot clear
    /// of the gridline origin.
    private let plotInset = EdgeInsets(top: 58, leading: 44, bottom: 26, trailing: 62)

    /// Rising line: flat-ish start, an early kick, a plateau, then the climb.
    /// The plateau is deliberate — a pure exponential reads as a sales chart;
    /// a curve that stalls and recovers reads as learning.
    private let risingPoints: [CGPoint] = [
        CGPoint(x: 0.00, y: 0.62),
        CGPoint(x: 0.16, y: 0.56),
        CGPoint(x: 0.30, y: 0.36),
        CGPoint(x: 0.44, y: 0.34),
        CGPoint(x: 0.58, y: 0.40),
        CGPoint(x: 0.74, y: 0.20),
        CGPoint(x: 0.88, y: 0.14),
        CGPoint(x: 1.00, y: 0.06)
    ]

    /// Falling line: same origin, shallow and monotonic. It should read as
    /// drift, not collapse, so it never drops below ~0.9.
    private let fallingPoints: [CGPoint] = [
        CGPoint(x: 0.00, y: 0.62),
        CGPoint(x: 0.22, y: 0.68),
        CGPoint(x: 0.48, y: 0.78),
        CGPoint(x: 0.74, y: 0.85),
        CGPoint(x: 1.00, y: 0.88)
    ]

    /// Half the widest a callout can be (`maxWidth` + horizontal padding),
    /// used to keep `.position` from pushing one off the frame.
    private let calloutHalfWidth: CGFloat = 64

    private let risingColor = Color(hex: "#2FA96B")
    private let fallingColor = Color(hex: "#D9673F")
    private let originColor = Color(hex: "#5B6CF0")

    var body: some View {
        GeometryReader { geo in
            let plot = inset(CGRect(origin: .zero, size: geo.size), by: plotInset)
            let start = point(risingPoints[0], in: plot)
            let risingEnd = point(risingPoints[risingPoints.count - 1], in: plot)
            let fallingEnd = point(fallingPoints[fallingPoints.count - 1], in: plot)

            ZStack(alignment: .topLeading) {
                gridlines(in: geo.size, plot: plot)

                // Vertical guides. Drawn under the lines so the dots sit on
                // top of them where they meet.
                dashedGuide(x: start.x, from: start.y, to: plot.maxY + 10, color: originColor)
                    .opacity(showStartDot ? 1 : 0)
                dashedGuide(x: risingEnd.x, from: risingEnd.y, to: plot.maxY + 10, color: risingColor)
                    .opacity(showEndMarkers ? 1 : 0)

                curve(fallingPoints, gradient: fallingGradient)
                curve(risingPoints, gradient: risingGradient)

                headDot(on: fallingPoints, color: fallingColor)
                headDot(on: risingPoints, color: risingColor)

                // Shared origin dot, drawn last so it sits above both strokes.
                Circle()
                    .fill(originColor)
                    .frame(width: 13, height: 13)
                    .position(start)
                    .opacity(showStartDot ? 1 : 0)
                    .scaleEffect(showStartDot ? 1 : 0.4)

                // Bubbles are centred over their endpoint where there's room,
                // and pulled back off the right edge where there isn't —
                // `.position` centres on the given point with no awareness of
                // the container, so an uncentred bubble would otherwise hang
                // off the frame and get clipped by the screen's padding.
                callout(positiveLabel, color: risingColor, background: Color(hex: "#DFF3E8"))
                    .position(x: min(risingEnd.x, geo.size.width - calloutHalfWidth),
                              y: risingEnd.y - 42)
                    .opacity(showCallouts ? 1 : 0)
                    .scaleEffect(showCallouts ? 1 : 0.7, anchor: .bottom)

                // Offset left of its endpoint rather than above it: centred,
                // it would sit directly on the rising line's dashed guide and
                // read as belonging to the green line.
                callout(negativeLabel, color: fallingColor, background: Color(hex: "#F7E4DC"))
                    .position(x: max(fallingEnd.x - 74, calloutHalfWidth),
                              y: fallingEnd.y - 44)
                    .opacity(showCallouts ? 1 : 0)
                    .scaleEffect(showCallouts ? 1 : 0.7, anchor: .bottom)

                // Axis captions, anchored to the guides they belong to.
                axisCaption(startCaption, color: originColor)
                    .position(x: start.x, y: plot.maxY + 20)
                    .opacity(showStartDot ? 1 : 0)

                axisCaption(endCaption, color: risingColor)
                    .position(x: risingEnd.x, y: plot.maxY + 20)
                    .opacity(showEndMarkers ? 1 : 0)
            }
        }
        // Flexible rather than an exact 260. Everything else on
        // `GrowthProjectionScreen` is rigid — the headline and all three
        // bullet rows are `.fixedSize`d vertically and the gaps are exact —
        // so this chart is the only element that can absorb a short canvas.
        // With a hard 260 there was nothing to give and the overflow went to
        // the screen's own edges instead: the progress bar rode up under the
        // status bar and the Continue button was clipped off the bottom on a
        // stock iPhone SE (375×667), and worse under Display Zoom, which
        // renders a 6.1" phone at 320×693 with no API to opt out.
        //
        // `idealHeight` is what keeps this at exactly 260 wherever there is
        // room, so nothing moves on the canvases that already worked. It must
        // NOT be `maxHeight: 260` alone — the frame would then size to the
        // chart's own content and shift the copy up on every device.
        //
        // The 170 floor keeps the callout bubbles and axis captions from
        // crowding the curves; everything inside is positioned off
        // `GeometryReader` proportions, so the chart rescales cleanly down to
        // it rather than clipping.
        .frame(minHeight: 170, idealHeight: 260, maxHeight: 260)
        .onAppear(perform: runAnimation)
        // The chart is decorative; the copy underneath carries the meaning.
        .accessibilityHidden(true)
    }

    // MARK: - Animation

    private func runAnimation() {
        // Reduce Motion: skip the draw-on and present the finished chart.
        // The information is in the end state, so there is nothing to lose.
        guard !UIAccessibility.isReduceMotionEnabled else {
            progress = 1
            showStartDot = true
            showEndMarkers = true
            showCallouts = true
            return
        }

        withAnimation(.easeOut(duration: 0.3).delay(0.15)) {
            showStartDot = true
        }
        // `easeInOut` rather than linear: a constant-speed draw looks
        // mechanical, and the ease-out tail lands the head dot softly under
        // the callout instead of stopping dead.
        withAnimation(.easeInOut(duration: 1.5).delay(0.3)) {
            progress = 1
        }
        // Both fire as the line lands: 0.3s delay + 1.5s draw = 1.8s.
        withAnimation(.easeIn(duration: 0.3).delay(1.7)) {
            showEndMarkers = true
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.68).delay(1.8)) {
            showCallouts = true
        }
    }

    // MARK: - Pieces

    private func point(_ normalized: CGPoint, in plot: CGRect) -> CGPoint {
        CGPoint(x: plot.minX + normalized.x * plot.width,
                y: plot.minY + normalized.y * plot.height)
    }

    private var risingGradient: LinearGradient {
        // Explicit stops rather than even spacing: the curve occupies the
        // middle ~70% of the frame, so evenly-spaced colours put the whole
        // blue→green handover past the last data point and the line reads as
        // uniformly blue.
        LinearGradient(
            stops: [
                .init(color: originColor, location: 0.10),
                .init(color: Color(hex: "#3D8FD6"), location: 0.38),
                .init(color: risingColor, location: 0.72)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var fallingGradient: LinearGradient {
        LinearGradient(
            colors: [originColor.opacity(0.85), fallingColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func curve(_ points: [CGPoint], gradient: LinearGradient) -> some View {
        GrowthCurveShape(points: points, insets: plotInset)
            .trim(from: 0, to: progress)
            .stroke(gradient, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
    }

    private func headDot(on points: [CGPoint], color: Color) -> some View {
        CurveHeadDot(points: points, insets: plotInset, radius: 6.5, progress: progress)
            .fill(color)
            .opacity(showStartDot ? 1 : 0)
    }

    private func gridlines(in size: CGSize, plot: CGRect) -> some View {
        // Four rules across the plot band. Full-bleed horizontally, like the
        // reference: they read as a backdrop rather than as a boxed axis.
        ForEach(0..<4, id: \.self) { i in
            let y = plot.minY + plot.height * (CGFloat(i) / 3.0)
            Rectangle()
                .fill(Color.wingmanBlack.opacity(0.08))
                .frame(width: size.width, height: 1)
                .position(x: size.width / 2, y: y)
        }
    }

    private func dashedGuide(x: CGFloat, from yStart: CGFloat, to yEnd: CGFloat, color: Color) -> some View {
        Path { path in
            path.move(to: CGPoint(x: x, y: yStart))
            path.addLine(to: CGPoint(x: x, y: yEnd))
        }
        .stroke(color.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
    }

    private func callout(_ text: String, color: Color, background: Color) -> some View {
        Text(text)
            .font(.manropeSemiBold(size: 13))
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 108)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(background)
            )
    }

    private func axisCaption(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.manropeSemiBold(size: 11))
            .kerning(0.5)
            .foregroundColor(color)
            .fixedSize()
    }
}

#Preview {
    VStack {
        GrowthChartView(
            positiveLabel: "Using Wingman every day",
            negativeLabel: "Doing nothing"
        )
        .padding(.horizontal, 16)
        Spacer()
    }
    .background(Color.white)
}
