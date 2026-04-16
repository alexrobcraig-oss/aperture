//
//  ContentView.swift
//  Aperture
//
//  Created by Alexander Craig on 15.04.2026.
//

import SwiftUI
import AVFoundation

// MARK: - Color Palette
// "Rustic Japanese" — moss greens, charcoal grays, warm paper whites.
extension Color {
    static let paperWhite = Color(red: 242/255, green: 237/255, blue: 227/255)
    static let sumiCharcoal = Color(red: 43/255, green: 43/255, blue: 43/255)
    static let mossGreen = Color(red: 107/255, green: 123/255, blue: 90/255)
}

// MARK: - Quote data model
struct Quote: Identifiable {
    let id = UUID()
    let text: String
    let author: String
}

// MARK: - Quote library
let allQuotes: [Quote] = [
    Quote(text: "Man suffers only because he takes seriously what the gods made for fun.", author: "Alan Watts"),
    Quote(text: "This is the real secret of life — to be completely engaged with what you are doing in the here and now. And instead of calling it work, realize it is play.", author: "Alan Watts"),
    Quote(text: "Muddy water is best cleared by leaving it alone.", author: "Alan Watts"),
    Quote(text: "The meaning of life is just to be alive. It is so plain and so obvious and so simple. And yet, everybody rushes around in a great panic as if it were necessary to achieve something beyond themselves.", author: "Alan Watts"),
    Quote(text: "The only way to make sense out of change is to plunge into it, move with it, and join the dance.", author: "Alan Watts"),
    Quote(text: "You are an aperture through which the universe is looking at and exploring itself.", author: "Alan Watts"),
    Quote(text: "The more a thing tends to be permanent, the more it tends to be lifeless.", author: "Alan Watts"),
    Quote(text: "Try to imagine what it will be like to go to sleep and never wake up… now try to imagine what it was like to wake up having never gone to sleep.", author: "Alan Watts"),
    Quote(text: "Never pretend to a love which you do not actually feel, for love is not ours to command.", author: "Alan Watts"),
    Quote(text: "Zen does not confuse spirituality with thinking about God while one is peeling potatoes. Zen spirituality is just to peel the potatoes.", author: "Alan Watts"),
    Quote(text: "But I'll tell you what hermits realize. If you go off into a far, far forest and get very quiet, you'll come to understand that you're connected with everything.", author: "Alan Watts"),
    Quote(text: "What we have to discover is that there is no safety, that seeking is painful, and that when we imagine that we have found it, we don't like it.", author: "Alan Watts"),
    Quote(text: "It's better to have a short life that is full of what you like doing, than a long life spent in a miserable way.", author: "Alan Watts")
]

// MARK: - Ensō View
// Uses the real ensō brush-stroke image (transparent PNG), revealed
// progressively with a circular "wipe" mask (like a clock hand sweeping
// around). The image starts ghostly and becomes bold as the session progresses.
struct EnsoView: View {
    let progress: CGFloat  // 0.0 (invisible) to 1.0 (fully drawn)

    // Start very faint, end fully bold
    private var inkOpacity: CGFloat {
        0.10 + progress * 0.90
    }

    var body: some View {
        Image("enso_circle")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .opacity(inkOpacity)
            .mask(
                // AngularGradient acts as a circular wipe:
                // a sharp edge sweeps clockwise, revealing more of the image.
                // startAngle is set to ~7 o'clock to match where the
                // ensō's brush stroke naturally begins.
                AngularGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: max(0, progress - 0.01)),
                        .init(color: .clear, location: progress),
                        .init(color: .clear, location: 1)
                    ],
                    center: .center,
                    startAngle: .degrees(90),
                    endAngle: .degrees(450)
                )
            )
            .animation(.linear(duration: 1), value: progress)
    }
}

// MARK: - Main View
struct ContentView: View {
    @State private var selectedMinutes: Int = 10
    @State private var remainingSeconds: Int = 0
    @State private var totalSessionSeconds: Int = 0  // saved at start for progress calc
    @State private var isRunning: Bool = false
    @State private var timer: Timer? = nil
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var displayedQuote: Quote? = nil

    @AppStorage("totalSecondsMeditated") private var totalSecondsMeditated: Int = 0

    // How far around the ensō has been drawn (0 = nothing, 1 = complete).
    // Recalculates automatically whenever remainingSeconds changes.
    var ensoProgress: CGFloat {
        guard totalSessionSeconds > 0 else { return 0 }
        return CGFloat(totalSessionSeconds - remainingSeconds) / CGFloat(totalSessionSeconds)
    }

    var body: some View {
        ZStack {
            // Full-bleed warm paper background
            Color.paperWhite
                .ignoresSafeArea()

            if let quote = displayedQuote {
                quoteView(quote: quote)
                    .transition(.opacity)
            } else if isRunning {
                meditationView
                    .transition(.opacity)
            } else {
                setupView
                    .transition(.opacity)
            }
        }
        .onAppear {
            configureAudioSession()
        }
    }

    // MARK: - Setup Screen
    // Shown before a session starts: app title, lifetime stats, time picker, begin button.
    var setupView: some View {
        VStack(spacing: 0) {
            // App title
            Text("Aperture")
                .font(.system(size: 32, weight: .light, design: .serif))
                .foregroundColor(.sumiCharcoal)
                .padding(.top, 70)

            // Lifetime meditation total
            if totalSecondsMeditated > 0 {
                Text(formatTotalTime(totalSecondsMeditated))
                    .font(.system(size: 14, weight: .light, design: .serif))
                    .foregroundColor(.sumiCharcoal.opacity(0.4))
                    .padding(.top, 8)
            }

            Spacer()

            // Time picker — scroll wheel, 1 to 120 minutes
            Picker("Minutes", selection: $selectedMinutes) {
                ForEach(1...120, id: \.self) { minute in
                    Text("\(minute) min").tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 200)

            Spacer()

            // Begin button — moss green pill
            Button(action: startTimer) {
                Text("Begin")
                    .font(.system(size: 20, weight: .light, design: .serif))
                    .foregroundColor(.paperWhite)
                    .frame(width: 160, height: 54)
                    .background(Color.mossGreen)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 60)
        }
    }

    // MARK: - Meditation Screen
    // Shown during an active session: the ensō slowly draws itself
    // with the countdown timer displayed in its centre.
    var meditationView: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                // The ensō — draws itself as the session progresses
                EnsoView(progress: ensoProgress)
                    .frame(width: 320, height: 320)

                // Countdown timer inside the circle
                Text(formatTime(remainingSeconds))
                    .font(.system(size: 52, weight: .ultraLight, design: .serif))
                    .foregroundColor(.sumiCharcoal)
                    .monospacedDigit()
            }

            Spacer()

            // Stop button — subtle, ghost-style pill
            Button(action: cancelSession) {
                Text("Stop")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .foregroundColor(.sumiCharcoal.opacity(0.5))
                    .frame(width: 140, height: 48)
                    .background(Color.sumiCharcoal.opacity(0.06))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 60)
        }
    }

    // MARK: - Quote Screen
    // Shown after a completed session: a random Alan Watts quote
    // with the finished ensō as a subtle background watermark.
    func quoteView(quote: Quote) -> some View {
        ZStack {
            // Completed ensō as a faint background element
            EnsoView(progress: 1.0)
                .frame(width: 340, height: 340)
                .opacity(0.08)

            VStack(spacing: 24) {
                Spacer()

                Text("\u{201C}\(quote.text)\u{201D}")
                    .font(.system(size: 20, weight: .light, design: .serif))
                    .foregroundColor(.sumiCharcoal)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 36)

                Text("— \(quote.author)")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(.sumiCharcoal.opacity(0.5))

                Spacer()

                Text("Tap to return")
                    .font(.system(size: 13, weight: .light, design: .serif))
                    .foregroundColor(.sumiCharcoal.opacity(0.3))
                    .padding(.bottom, 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.5)) {
                displayedQuote = nil
            }
        }
    }

    // MARK: - Timer Logic

    // Start a new meditation session.
    // The timer begins counting down immediately, but the dong sound
    // plays after a 2-second delay to give you time to close your eyes.
    func startTimer() {
        totalSessionSeconds = selectedMinutes * 60
        remainingSeconds = totalSessionSeconds

        withAnimation(.easeInOut(duration: 0.5)) {
            isRunning = true
        }

        // 2-second delay before the opening dong
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            playDong()
        }

        // Countdown — ticks every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                completeSession()
            }
        }
    }

    // User taps Stop — cancel the session (no credit for partial sessions).
    func cancelSession() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeInOut(duration: 0.5)) {
            isRunning = false
        }
    }

    // Timer reaches zero — session complete!
    // Plays the closing dong, records the time, and shows a quote.
    func completeSession() {
        timer?.invalidate()
        timer = nil
        playDong()
        totalSecondsMeditated += selectedMinutes * 60
        withAnimation(.easeInOut(duration: 0.8)) {
            isRunning = false
            displayedQuote = allQuotes.randomElement()
        }
    }

    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    func formatTotalTime(_ seconds: Int) -> String {
        let totalMinutes = seconds / 60
        if totalMinutes < 60 {
            return "\(totalMinutes) min meditated"
        } else {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return "\(hours)h \(mins)m meditated"
        }
    }

    // MARK: - Audio

    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func playDong() {
        guard let url = Bundle.main.url(forResource: "singing_bowl_sound", withExtension: "mp3") else {
            print("Could not find singing_bowl_sound.mp3 in app bundle")
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Failed to play sound: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
