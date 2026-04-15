//
//  ContentView.swift
//  Aperture
//
//  Created by Alexander Craig on 15.04.2026.
//

import SwiftUI
import AVFoundation

// MARK: - Quote data model
// A simple structure to hold a quote and its author.
// Adding new authors later is as easy as adding new entries to the `allQuotes` list below.
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

// MARK: - Main view
struct ContentView: View {
    // State — values SwiftUI watches. When any of these change, the UI redraws.
    @State private var selectedMinutes: Int = 10
    @State private var remainingSeconds: Int = 0
    @State private var isRunning: Bool = false
    @State private var timer: Timer? = nil
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var displayedQuote: Quote? = nil  // when set, the quote screen is shown

    // Persistent storage — saved on the iPhone and survives app restarts.
    @AppStorage("totalSecondsMeditated") private var totalSecondsMeditated: Int = 0

    var body: some View {
        ZStack {
            if let quote = displayedQuote {
                // Quote screen — shown after a session completes.
                quoteView(quote: quote)
            } else {
                // Default screen — picker or active countdown.
                mainView
            }
        }
        .padding()
        .onAppear {
            configureAudioSession()
        }
    }

    // The picker / countdown / button view.
    var mainView: some View {
        VStack(spacing: 40) {
            // Total time meditated — only shown when not actively running.
            if !isRunning && totalSecondsMeditated > 0 {
                Text(formatTotalTime(totalSecondsMeditated))
                    .font(.system(size: 14, weight: .light, design: .serif))
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
            }

            Spacer()

            if isRunning {
                Text(formatTime(remainingSeconds))
                    .font(.system(size: 80, weight: .light, design: .serif))
                    .monospacedDigit()
            } else {
                Picker("Minutes", selection: $selectedMinutes) {
                    ForEach(1...120, id: \.self) { minute in
                        Text("\(minute) min").tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 200)
            }

            Spacer()

            Button(action: {
                if isRunning {
                    stopTimer()
                } else {
                    startTimer()
                }
            }) {
                Text(isRunning ? "Stop" : "Begin")
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .foregroundColor(.white)
                    .frame(width: 180, height: 60)
                    .background(Color.black)
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }

    // The quote screen — shown when a session completes.
    // Tap anywhere to dismiss and return to the picker.
    func quoteView(quote: Quote) -> some View {
        VStack(spacing: 30) {
            Spacer()

            Text("“\(quote.text)”")
                .font(.system(size: 22, weight: .light, design: .serif))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Text("— \(quote.author)")
                .font(.system(size: 16, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(.secondary)

            Spacer()

            Text("Tap to return")
                .font(.system(size: 14, weight: .light, design: .serif))
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle()) // makes the whole area tappable
        .onTapGesture {
            displayedQuote = nil
        }
    }

    // MARK: - Timer logic

    func startTimer() {
        remainingSeconds = selectedMinutes * 60
        isRunning = true
        playDong() // dong at start
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                completeSession()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    // Called when the timer reaches zero — plays the dong, shows a random quote,
    // adds the session to the lifetime total, and resets the timer state.
    func completeSession() {
        playDong()
        totalSecondsMeditated += selectedMinutes * 60  // only completed sessions count
        displayedQuote = allQuotes.randomElement()
        stopTimer()
    }

    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    // Format the lifetime total nicely, e.g. "47 minutes meditated" or "3h 12m meditated".
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
