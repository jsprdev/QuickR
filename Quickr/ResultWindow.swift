import AppKit
import SwiftUI

// MARK: - Bubble shape

struct BubbleShape: Shape {
    let cornerRadius: CGFloat
    let tailWidth: CGFloat
    let tailHeight: CGFloat
    let tailX: CGFloat
    let tailEdge: TailEdge

    enum TailEdge { case top, bottom }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = cornerRadius
        let tw = tailWidth
        let th = tailHeight
        let tx = max(rect.minX + r + tw / 2 + 1, min(tailX, rect.maxX - r - tw / 2 - 1))

        let body: CGRect = {
            switch tailEdge {
            case .bottom: return CGRect(x: rect.minX, y: rect.minY,      width: rect.width, height: rect.height - th)
            case .top:    return CGRect(x: rect.minX, y: rect.minY + th, width: rect.width, height: rect.height - th)
            }
        }()

        // Begin just below the top-left corner.
        path.move(to: CGPoint(x: body.minX, y: body.minY + r))

        // Top-left corner + top edge (with notch if tail is on top).
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY),
                    tangent2End: CGPoint(x: body.minX + r, y: body.minY),
                    radius: r)
        if tailEdge == .top {
            path.addLine(to: CGPoint(x: tx - tw / 2, y: body.minY))
            path.addLine(to: CGPoint(x: tx,          y: rect.minY))
            path.addLine(to: CGPoint(x: tx + tw / 2, y: body.minY))
        }
        path.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))

        // Top-right corner + right edge.
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY),
                    tangent2End: CGPoint(x: body.maxX, y: body.minY + r),
                    radius: r)
        path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))

        // Bottom-right corner + bottom edge (with notch if tail is on bottom).
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY),
                    tangent2End: CGPoint(x: body.maxX - r, y: body.maxY),
                    radius: r)
        if tailEdge == .bottom {
            path.addLine(to: CGPoint(x: tx + tw / 2, y: body.maxY))
            path.addLine(to: CGPoint(x: tx,          y: rect.maxY))
            path.addLine(to: CGPoint(x: tx - tw / 2, y: body.maxY))
        }
        path.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))

        // Bottom-left corner + close.
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY),
                    tangent2End: CGPoint(x: body.minX, y: body.maxY - r),
                    radius: r)
        path.closeSubpath()
        return path
    }
}

// MARK: - Window

@MainActor
final class ResultWindow {
    private var window: NSWindow?
    private let codes: [DetectedCode]
    private let anchor: CGRect
    private let visibleFrame: CGRect
    var onClose: (() -> Void)?

    init(codes: [DetectedCode], near anchor: CGRect, visibleFrame: CGRect) {
        self.codes = codes
        self.anchor = anchor
        self.visibleFrame = visibleFrame
    }

    func show() {
        // First pass: build with placeholder tail to measure SwiftUI's preferred size.
        let host = NSHostingController(
            rootView: BubbleHostView(
                codes: codes,
                tailEdge: .bottom,
                tailX: 0,
                onClose: { [weak self] in self?.close() }
            )
        )
        host.sizingOptions = .preferredContentSize
        host.view.layoutSubtreeIfNeeded()

        let bubbleSize = host.view.fittingSize == .zero
            ? NSSize(width: 380, height: 160)
            : host.view.fittingSize

        let placement = computePlacement(bubbleSize: bubbleSize)

        // Second pass: now we know which edge the tail goes on and where.
        host.rootView = BubbleHostView(
            codes: codes,
            tailEdge: placement.tailEdge,
            tailX: placement.tailX,
            onClose: { [weak self] in self?.close() }
        )

        let window = BubbleWindow(
            contentRect: placement.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = host
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .transient]
        window.setFrame(placement.frame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()

        self.window = window
    }

    func close() {
        window?.orderOut(nil)
        window = nil
        onClose?()
    }

    private struct Placement {
        let frame: CGRect
        let tailEdge: BubbleShape.TailEdge
        let tailX: CGFloat
    }

    private func computePlacement(bubbleSize: CGSize) -> Placement {
        let gap: CGFloat = 4
        let margin: CGFloat = 8

        let visible = visibleFrame
        let fitsAbove = (anchor.maxY + gap + bubbleSize.height) <= (visible.maxY - margin)
        let tailEdge: BubbleShape.TailEdge = fitsAbove ? .bottom : .top

        let windowMinY: CGFloat
        if fitsAbove {
            windowMinY = anchor.maxY + gap
        } else {
            windowMinY = max(visible.minY + margin,
                             anchor.minY - gap - bubbleSize.height)
        }

        var windowMinX = anchor.midX - bubbleSize.width / 2
        windowMinX = max(visible.minX + margin,
                         min(windowMinX, visible.maxX - bubbleSize.width - margin))

        let tailX = anchor.midX - windowMinX

        return Placement(
            frame: CGRect(x: windowMinX, y: windowMinY,
                          width: bubbleSize.width, height: bubbleSize.height),
            tailEdge: tailEdge,
            tailX: tailX
        )
    }
}

private final class BubbleWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - SwiftUI bubble content

private struct BubbleHostView: View {
    let codes: [DetectedCode]
    let tailEdge: BubbleShape.TailEdge
    let tailX: CGFloat
    let onClose: () -> Void

    @AppStorage("bubbleStyle") private var styleRaw: String = BubbleStyle.liquidGlass.rawValue
    @AppStorage("bubbleColor") private var colorHex: String = "#1E1E1EE6"

    private let cornerRadius: CGFloat = 14
    private let tailWidth: CGFloat = 18
    private let tailHeight: CGFloat = 10
    private let contentPadding: CGFloat = 16

    private var style: BubbleStyle { BubbleStyle(rawValue: styleRaw) ?? .liquidGlass }
    private var solidColor: Color { Color(hex: colorHex) }

    var body: some View {
        let shape = BubbleShape(
            cornerRadius: cornerRadius,
            tailWidth: tailWidth,
            tailHeight: tailHeight,
            tailX: tailX,
            tailEdge: tailEdge
        )

        ResultContent(codes: codes, onClose: onClose)
            .padding(contentPadding)
            .padding(tailEdge == .top ? .top : .bottom, tailHeight)
            .frame(width: 360 + contentPadding * 2)
            .quickrBubbleBackground(shape: shape, style: style, color: solidColor)
    }
}

private extension View {
    @ViewBuilder
    func quickrBubbleBackground<S: Shape>(shape: S, style: BubbleStyle, color: Color) -> some View {
        switch style {
        case .liquidGlass:
            if #available(macOS 26.0, *) {
                self.glassEffect(.regular, in: shape)
            } else {
                self.background(shape.fill(.regularMaterial))
            }
        case .material:
            self.background(shape.fill(.regularMaterial))
        case .solid:
            self.background(shape.fill(color))
        }
    }
}

private struct ResultContent: View {
    let codes: [DetectedCode]
    let onClose: () -> Void

    @AppStorage("browserBundleID") private var browserBundleID: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if codes.count == 1 {
                singleCode(codes[0])
                singleActions(codes[0])
            } else {
                Text("\(codes.count) QR codes")
                    .font(.headline)
                ForEach(codes) { code in
                    multiRow(code)
                    if code.id != codes.last?.id { Divider() }
                }
                HStack {
                    Spacer()
                    Button("Done", action: onClose)
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .frame(width: 360)
    }

    @ViewBuilder
    private func singleCode(_ code: DetectedCode) -> some View {
        let display = PayloadAction.display(for: code)
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: display.icon)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                if let title = display.title {
                    Text(title)
                        .font(.headline)
                }
                Text(display.subtitle)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func singleActions(_ code: DetectedCode) -> some View {
        let primary = PayloadAction.primary(for: code)
        HStack {
            Button("Copy") {
                copy(PayloadAction.copyableText(for: code))
                onClose()
            }
            .keyboardShortcut("c", modifiers: .command)

            Spacer()

            Button("Cancel", action: onClose)
                .keyboardShortcut(.cancelAction)

            if let primary {
                Button(primary.label) {
                    primary.run(browserBundleID)
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private func multiRow(_ code: DetectedCode) -> some View {
        let primary = PayloadAction.primary(for: code)
        HStack {
            Text(PayloadAction.display(for: code).subtitle)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let primary {
                Button(primary.label) {
                    primary.run(browserBundleID)
                    onClose()
                }
            }
            Button("Copy") { copy(PayloadAction.copyableText(for: code)) }
        }
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
