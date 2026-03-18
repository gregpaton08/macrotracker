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
//

import SwiftUI

private struct ChatTurn: Identifiable {
    let id = UUID()
    let userMessage: String
    var result: AIAnalysisResult?
}

struct DescribeMealView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MacroViewModel

    /// Called when the user accepts a result.
    let onApply: (_ fat: Double, _ carbs: Double, _ protein: Double, _ summary: String, _ portionSize: String?, _ portionUnit: String?) -> Void

    @State private var messages: [ChatTurn] = []
    @State private var inputText = ""
    @State private var analysisTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Message List
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
                    .onChange(of: messages.count) { _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: viewModel.isLoading) { _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
                
                // MARK: - Input Bar
                inputBar
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
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
        .onAppear { inputFocused = true }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(canSend ? Theme.tint : Color(.systemGray4))
                    .clipShape(Circle())
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
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

                Button {
                    onApply(
                        result.total_fat, result.total_carbs, result.total_protein, result.summary,
                        result.portion_size, result.portion_unit)
                    dismiss()
                } label: {
                    Text("Use These Macros").bold().frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
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
            ProgressView().padding(.vertical, 8)
            Spacer()
        }
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

        analysisTask = Task {
            if let result = await viewModel.analyzeDescription(text: trimmed) {
                if let idx = messages.firstIndex(where: { $0.id == turn.id }) {
                    messages[idx].result = result
                }
            }
        }
    }
}
