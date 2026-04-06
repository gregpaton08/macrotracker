//
//  DescribeMealView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/28/26.
//
//  Chat-style sheet for free-text meal description.
//  Each message is sent to Gemini independently; responses appear as
//  AI bubbles with macro estimates, a per-item breakdown, and a
//  "Use These Macros" button to apply the result to AddMealView.
//  Chat history is persisted to UserDefaults so conversations survive
//  dismissal and can be continued from the edit meal screen.
//

import SwiftUI

private struct ChatTurn: Identifiable, Codable {
    let id: UUID
    let userMessage: String
    var result: AIAnalysisResult?

    init(userMessage: String, result: AIAnalysisResult? = nil) {
        self.id = UUID()
        self.userMessage = userMessage
        self.result = result
    }
}

struct DescribeMealView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MacroViewModel

    /// A unique identifier for this meal or session, used to persist chat history independently.
    let contextID: String

    /// Called when the user taps "Use These Macros" to fill in the calling form.
    let onApply: (_ fat: Double, _ carbs: Double, _ protein: Double, _ summary: String, _ portionSize: String?, _ portionUnit: String?) -> Void

    /// If set, shows an "Add Meal" button that saves directly and closes everything.
    var onSave: ((_ result: AIAnalysisResult) -> Void)?

    /// Called when the user wants to auto-accept the current analysis in the background and exit.
    var onAutoAccept: ((_ text: String) -> Void)?

    @State private var messages: [ChatTurn] = []
    @State private var inputText = ""
    @State private var analysisTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    private var chatHistoryKey: String {
        "ai_chat_history_\(contextID)"
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(messages) { turn in
                            userBubble(turn.userMessage)

                            if let result = turn.result {
                                aiResponseBubble(result)
                            } else if viewModel.isLoading && turn.id == messages.last?.id {
                                typingIndicator
                            }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    inputBar
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.isLoading) { isLoading in
                    if isLoading {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            .navigationTitle("Describe Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        analysisTask?.cancel()
                        dismiss()
                    }
                }
                if !messages.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear") {
                            messages = []
                            UserDefaults.standard.removeObject(forKey: chatHistoryKey)
                        }
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
        .onAppear {
            inputFocused = true
            if let data = UserDefaults.standard.data(forKey: chatHistoryKey),
               let saved = try? JSONDecoder().decode([ChatTurn].self, from: data) {
                messages = saved
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // MARK: - Persistence

    private func persistMessages() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: chatHistoryKey)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Describe your meal…", text: $inputText, axis: .vertical)
                    .focused($inputFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(canSend ? Theme.tint : Color(.systemGray4))
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }

    // MARK: - Bubbles

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 60)
            Text(text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.tint)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder
    private func aiResponseBubble(_ result: AIAnalysisResult) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundColor(Theme.tint)
                .frame(width: 28, height: 28)
                .background(Theme.tint.opacity(0.1))
                .clipShape(Circle())
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 10) {
                Text(result.summary)
                    .font(.subheadline)

                // Macro pills
                HStack(spacing: 8) {
                    macroPill(label: "Fat", value: result.total_fat, color: Theme.over)
                    macroPill(label: "Carbs", value: result.total_carbs, color: Theme.tint)
                    macroPill(label: "Protein", value: result.total_protein, color: Theme.good)
                }

                // Per-item breakdown
                if !result.items.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(result.items.indices, id: \.self) { i in
                            HStack {
                                Text("· \(result.items[i].name)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(result.items[i].estimated_calories)) kcal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        applyResult(result)
                    } label: {
                        Text("Use Macros")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if let save = onSave {
                        Button {
                            save(result)
                            dismiss()
                        } label: {
                            Text("Add Meal")
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
    }

    private func applyResult(_ result: AIAnalysisResult) {
        onApply(
            result.total_fat, result.total_carbs, result.total_protein,
            result.summary, result.portion_size, result.portion_unit)
        dismiss()
    }

    private var typingIndicator: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundColor(Theme.tint)
                .frame(width: 28, height: 28)
                .background(Theme.tint.opacity(0.1))
                .clipShape(Circle())
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("AI is analyzing your meal...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    if let lastMsg = messages.last?.userMessage {
                        analysisTask?.cancel()
                        onAutoAccept?(lastMsg)
                        dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Auto-Accept & Exit")
                    }
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.tint)
                    .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Macro Pill

    private func macroPill(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).bold().foregroundColor(color)
            Text("\(Int(value))g").font(.caption).bold().monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Send

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""

        let turn = ChatTurn(userMessage: trimmed, result: nil)
        messages.append(turn)
        persistMessages()

        analysisTask = Task {
            if let result = await viewModel.analyzeDescription(text: trimmed) {
                if let idx = messages.firstIndex(where: { $0.id == turn.id }) {
                    messages[idx].result = result
                    persistMessages()
                }
            }
        }
    }
}
