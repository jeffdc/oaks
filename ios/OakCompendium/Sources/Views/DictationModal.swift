import SwiftUI

/// Modal view for voice dictation with live transcription
@MainActor
struct DictationModal: View {
    let field: NoteField
    let initialText: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var speechService = SpeechService()
    @State private var editedText: String
    @State private var showingPermissionAlert = false

    init(
        field: NoteField,
        initialText: String = "",
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.field = field
        self.initialText = initialText
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedText = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Field header
                fieldHeader

                // Transcription area
                transcriptionArea

                // Recording controls
                recordingControls

                // Error display
                if let error = speechService.error {
                    errorView(error)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(field.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        speechService.cancelRecording()
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        speechService.stopRecording()
                        onSave(editedText)
                    }
                    .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Oak Compendium needs microphone and speech recognition access to transcribe your voice. Please enable these in Settings.")
            }
            .task {
                await checkPermissions()
            }
        }
    }

    // MARK: - Subviews

    private var fieldHeader: some View {
        HStack {
            Image(systemName: field.iconName)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(field.placeholder)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal)
    }

    private var transcriptionArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Live transcription indicator
            if speechService.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(pulsingOpacity)

                    Text("Listening...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Text editor
            TextEditor(text: $editedText)
                .font(.body)
                .frame(minHeight: 150)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(speechService.isRecording ? Color.red : Color.clear, lineWidth: 2)
                )
        }
        .onChange(of: speechService.transcribedText) { _, newValue in
            // Append transcribed text to edited text
            if !newValue.isEmpty {
                if editedText.isEmpty {
                    editedText = newValue
                } else if !editedText.hasSuffix(newValue) {
                    // Only update if the transcription has changed
                    editedText = newValue
                }
            }
        }
    }

    @State private var pulsingOpacity: Double = 1.0

    private var recordingControls: some View {
        VStack(spacing: 16) {
            // Main recording button
            Button {
                toggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(speechService.isRecording ? Color.red : Color.accentColor)
                        .frame(width: 72, height: 72)

                    if speechService.isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
            }
            .disabled(!canToggleRecording)
            .opacity(canToggleRecording ? 1 : 0.5)

            // Status text
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Permission status
            if speechService.authorizationStatus == .denied {
                Button("Grant Permission") {
                    showingPermissionAlert = true
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulsingOpacity = 0.3
            }
        }
    }

    private func errorView(_ error: Error) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemOrange).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Computed Properties

    private var canToggleRecording: Bool {
        speechService.authorizationStatus == .authorized &&
        speechService.recordingState != .processing
    }

    private var statusText: String {
        switch speechService.authorizationStatus {
        case .notDetermined:
            return "Tap to request permission"
        case .denied, .restricted:
            return "Permission denied"
        case .authorized:
            switch speechService.recordingState {
            case .idle:
                return "Tap to start dictation"
            case .recording:
                return "Tap to stop"
            case .processing:
                return "Processing..."
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func checkPermissions() async {
        speechService.checkAuthorizationStatus()

        if speechService.authorizationStatus == .notDetermined {
            await speechService.requestAuthorization()
        }
    }

    @MainActor
    private func toggleRecording() {
        if speechService.authorizationStatus == .notDetermined {
            Task {
                await speechService.requestAuthorization()
            }
            return
        }

        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            do {
                try speechService.startRecording()
            } catch {
                // Error will be displayed via speechService.error
            }
        }
    }
}

#Preview {
    DictationModal(
        field: .leaf,
        initialText: "",
        onSave: { _ in },
        onCancel: {}
    )
}
