import PartwayCore
import SwiftUI

/// The pill (what it hears) and, while you talk, Jev's read below it: the three likeliest actions,
/// the yes/no "opens an app?", and each command as it fires.
struct BarView: View {
    static let width: CGFloat = 520
    static let threshold = 0.8

    @ObservedObject var model: BarModel

    var body: some View {
        VStack(spacing: 0) {
            pill
            if model.expanded, let decision = model.decision {
                tray(decision).transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: Self.width)
        .foregroundStyle(.white)
        .background { BarBackground(cornerRadius: model.expanded ? 20 : 22) }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 3)
            .onChanged { _ in model.drag(.moved) }
            .onEnded { _ in model.drag(.ended) })
        .animation(.easeOut(duration: 0.2), value: model.expanded)
        .animation(.easeOut(duration: 0.25), value: model.decision)
    }

    private var pill: some View {
        HStack(spacing: 12) {
            Button(action: model.toggle) {
                Image(systemName: model.listening ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.14), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(model.listening ? "Pause listening (⌥Space)" : "Start listening (⌥Space)")
            .accessibilityLabel(model.listening ? "Pause listening" : "Start listening")
            if model.listening { Waveform() }
            line.frame(maxWidth: .infinity, alignment: .leading)
            if !model.expanded {
                Text("⌥Space")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(.white.opacity(0.08), in: Capsule())
                    .padding(.trailing, 4)
            }
            if model.expanded, model.flash, let last = model.fired.last {
                Label(last.command, systemImage: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Color.fire, in: Capsule())
            } else if model.expanded {
                Text(model.paused ? "you paused" : "listening")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.trailing, 9)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 7)
        .frame(height: 44)
    }

    @ViewBuilder private var line: some View {
        if !model.expanded, let notice = model.notice {
            Text(notice).font(.system(size: 13)).lineLimit(2)
        } else if !model.expanded, let last = model.fired.last {
            (Text(last.command).foregroundStyle(Color.fire).bold()
                + Text(last.lead.map { " · " + $0 } ?? "").foregroundStyle(.white.opacity(0.7)))
                .font(.system(size: 14))
                .lineLimit(1)
        } else if model.words.isEmpty {
            Text(model.listening ? "Listening…" : "Paused")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
        } else {
            model.words
                .reduce(Text("")) { line, word in
                    line + Text(word.text + " ").strikethrough(word.used).foregroundStyle(.white.opacity(word.used ? 0.35 : 1))
                }
                .font(.system(size: 15))
                .lineLimit(1)
                .truncationMode(.head)
        }
    }

    private func tray(_ decision: Decision) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("JEV’S READ")
                Spacer()
                Text("mid-sentence at 0.80")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))
            ForEach(decision.top(3), id: \.action) { score in
                Meter(label: score.action.label, value: score.probability,
                      fill: score.action == decision.action ? .white : .white.opacity(0.32))
            }
            Meter(label: "opens an app?", value: decision.opensApp,
                  fill: decision.opensApp >= Self.threshold ? Color.fire : Color.fire.opacity(0.45))
            HStack(spacing: 6) {
                if let app = decision.app { Tag(text: "app · \(app)") }
                if let argument = decision.argument, [.webSearch, .typeText, .openURL].contains(decision.action) {
                    Tag(text: "text · “\(argument)”")
                }
            }
            .frame(minHeight: 26)
            ForEach(model.fired) { fire in
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text(fire.command).bold()
                    if let lead = fire.lead { Text(lead).foregroundStyle(.white.opacity(0.7)) }
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.fire)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .background(Color.fire.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }
}

private struct Meter: View {
    let label: String
    let value: Double
    let fill: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 100, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule().fill(fill).frame(width: geometry.size.width * min(max(value, 0), 1))
                    Rectangle()
                        .fill(.white.opacity(0.55))
                        .frame(width: 1, height: 16)
                        .offset(x: geometry.size.width * BarView.threshold)
                }
            }
            .frame(height: 8)
            Text(String(format: "%.2f", value))
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 36, alignment: .trailing)
        }
    }
}

private struct Tag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(.white.opacity(0.1), in: Capsule())
    }
}

/// Decorative. ponytail: not the real mic level; drive it from the audio tap's RMS if it should mean something.
private struct Waveform: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { bar in
                    Capsule()
                        .fill(Color.green)
                        .frame(width: 3, height: 5 + 9 * abs(sin(t * 5 + Double(bar) * 0.8)))
                }
            }
            .frame(height: 16)
        }
    }
}

/// Liquid Glass on macOS 26, tinted dark so white text reads over any wallpaper; flat smoke before that.
private struct BarBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            #if compiler(>=6.2)  // Liquid Glass needs the macOS 26 SDK; older toolchains build the flat look
            if #available(macOS 26, *) {
                shape.fill(.clear).glassEffect(.regular.tint(.black.opacity(0.55)), in: shape)
            } else {
                shape.fill(Color(white: 0.11, opacity: 0.88))
            }
            #else
            shape.fill(Color(white: 0.11, opacity: 0.88))
            #endif
        }
        .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
    }
}

extension Color {
    static let fire = Color(red: 1, green: 0.84, blue: 0.04)
}
