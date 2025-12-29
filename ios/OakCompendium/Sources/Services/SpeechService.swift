import Foundation
import Speech
import AVFoundation

/// Service for handling speech recognition and live transcription
@Observable
final class SpeechService: @unchecked Sendable {
    // MARK: - State

    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case denied
        case restricted
    }

    enum RecordingState {
        case idle
        case recording
        case processing
    }

    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    private(set) var recordingState: RecordingState = .idle
    private(set) var transcribedText: String = ""
    private(set) var error: Error?

    /// Whether speech recognition is available on this device
    var isAvailable: Bool {
        SFSpeechRecognizer()?.isAvailable ?? false
    }

    /// Whether we can start recording
    var canRecord: Bool {
        authorizationStatus == .authorized && recordingState == .idle && isAvailable
    }

    /// Whether we're currently recording
    var isRecording: Bool {
        recordingState == .recording
    }

    // MARK: - Private Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    // MARK: - Initialization

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Authorization

    /// Check and update current authorization status
    @MainActor
    func checkAuthorizationStatus() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        switch speechStatus {
        case .notDetermined:
            authorizationStatus = .notDetermined
        case .authorized:
            // Also need to check microphone
            checkMicrophoneAuthorization()
        case .denied:
            authorizationStatus = .denied
        case .restricted:
            authorizationStatus = .restricted
        @unknown default:
            authorizationStatus = .denied
        }
    }

    @MainActor
    private func checkMicrophoneAuthorization() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            authorizationStatus = .authorized
        case .denied:
            authorizationStatus = .denied
        case .undetermined:
            authorizationStatus = .notDetermined
        @unknown default:
            authorizationStatus = .denied
        }
    }

    /// Request authorization for speech recognition and microphone
    @MainActor
    func requestAuthorization() async {
        // Request speech recognition permission
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechGranted else {
            authorizationStatus = .denied
            return
        }

        // Request microphone permission
        let micGranted = await AVAudioApplication.requestRecordPermission()

        authorizationStatus = micGranted ? .authorized : .denied
    }

    // MARK: - Recording

    /// Start live transcription
    @MainActor
    func startRecording() throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        // Reset state
        transcribedText = ""
        error = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine else {
            throw SpeechError.audioEngineError
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true
        // Don't require on-device - allow server fallback
        recognitionRequest.requiresOnDeviceRecognition = false

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                // Ignore callbacks after we've stopped recording
                guard self.recordingState == .recording else { return }

                if let result {
                    self.transcribedText = result.bestTranscription.formattedString

                    if result.isFinal {
                        self.finishRecording()
                    }
                }

                if let error = error as NSError? {
                    // Ignorable errors that don't need to stop recording or show to user
                    // 1107 = cancelled, 216 = no speech detected, 1110 = audio interrupted
                    let ignoredErrors = [1107, 216, 1110]

                    // Fatal errors that should stop recording
                    // 1101 = assets not available (on-device recognition failed)
                    let fatalErrors = [1101]

                    if fatalErrors.contains(error.code) {
                        self.error = SpeechError.recognizerUnavailable
                        self.finishRecording()
                    } else if !ignoredErrors.contains(error.code) {
                        self.error = error
                    }
                }
            }
        }

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        recordingState = .recording
    }

    /// Stop recording and finalize transcription
    @MainActor
    func stopRecording() {
        guard recordingState == .recording else { return }

        recordingState = .processing

        // Stop audio engine first
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        // Signal end of audio to get final transcription
        recognitionRequest?.endAudio()

        // Give a brief moment for final results, then clean up
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            self.cleanupRecognition()
        }
    }

    /// Called when recognition naturally finishes (isFinal = true)
    @MainActor
    private func finishRecording() {
        guard recordingState == .recording || recordingState == .processing else { return }

        // Stop audio if still running
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        cleanupRecognition()
    }

    /// Clean up recognition resources
    @MainActor
    private func cleanupRecognition() {
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        recordingState = .idle
    }

    /// Cancel recording and discard transcription
    @MainActor
    func cancelRecording() {
        guard recordingState != .idle else { return }

        recordingState = .processing

        // Stop audio
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        // Cancel the recognition task (this will trigger error 1107, which we ignore)
        recognitionTask?.cancel()

        cleanupRecognition()
        transcribedText = ""
    }

    /// Reset the service state
    @MainActor
    func reset() {
        cancelRecording()
        error = nil
    }
}

// MARK: - Errors

enum SpeechError: LocalizedError {
    case recognizerUnavailable
    case audioEngineError
    case requestCreationFailed
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is not available on this device."
        case .audioEngineError:
            return "Could not initialize audio engine."
        case .requestCreationFailed:
            return "Could not create speech recognition request."
        case .notAuthorized:
            return "Speech recognition or microphone access was denied."
        }
    }
}
