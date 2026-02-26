//
//  GeminiClient.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/5/26.
//
//  HTTP client for the Google Gemini API. Provides capabilities:
//    analyzeFood     — One-shot macro estimation (text → macros).
//    parseNutritionLabel — Multimodal vision (photo → label macros).
//

import Foundation
import OSLog
import UIKit

/// Generic Gemini error body (used when decoding non-200 responses).
struct ApiResponse: Codable {
  let message: String
}

// MARK: - Gemini Client

class GeminiClient {
  private let session = URLSession.shared
  private let logger = Logger(subsystem: "com.macrotracker", category: "GeminiClient")
  private let apiKey: String

  init(apiKey: String) {
    self.apiKey = apiKey
  }

  // MARK: - One-Shot Analysis

  /// Sends a food description directly to Gemini and receives complete macro
  /// estimates in a single round-trip.
  func analyzeFood(userText: String) async throws -> AIAnalysisResult {
    let model = "gemini-3-flash-preview"
    let urlString =
      "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
    guard let url = URL(string: urlString) else { throw URLError(.badURL) }

    let promptText = """
      You are a nutritionist. Analyze this food log: "\(userText)".

      1. Identify the food items and estimate portion sizes if not specified.
      2. Calculate the total macronutrients (Protein, Fat, Carbs) and Calories.
      3. Return ONLY valid JSON matching this schema:
      {
          "summary": "Short readable summary of food",
          "total_calories": number,
          "total_protein": number (grams),
          "total_carbs": number (grams),
          "total_fat": number (grams),
          "items": [
              { "name": "Item Name", "estimated_calories": number }
          ]
      }
      """

    let requestBody = GeminiRequest(
      contents: [.init(parts: [.init(text: promptText)])],
      generationConfig: .init(response_mime_type: "application/json")
    )

    let data = try await performRequest(url: url, body: requestBody)
    let jsonText = try extractJSON(from: data)
    guard let cleanData = jsonText.data(using: .utf8) else { throw URLError(.cannotParseResponse) }

    return try JSONDecoder().decode(AIAnalysisResult.self, from: cleanData)
  }

  // MARK: - Nutrition Label Scanning

  /// Sends a photo of a nutrition facts label to Gemini Vision and extracts
  /// macro values directly from the label.
  func parseNutritionLabel(image: UIImage) async throws -> ParsedNutritionLabel {
    guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
      throw URLError(
        .cannotParseResponse,
        userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG."])
    }
    let base64String = jpegData.base64EncodedString()

    let model = "gemini-3-flash-preview"
    let urlString =
      "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
    guard let url = URL(string: urlString) else { throw URLError(.badURL) }

    let prompt = """
      Analyze this nutrition facts label photo and extract the macronutrient information.
      Return ONLY valid JSON with this schema:
      {
        "description": "food name from the label if visible, otherwise null",
        "serving_size": "numeric serving size value as a string (e.g. \"28\"), or null if not visible",
        "serving_unit": "serving unit (e.g. \"g\", \"ml\", \"oz\"), or null if not visible",
        "calories": number or null,
        "protein_grams": number,
        "fat_grams": number,
        "carbs_grams": number
      }
      Extract the values exactly as printed on the label. If a macro value is not visible, use 0.
      """

    let requestBody = GeminiRequest(
      contents: [
        .init(parts: [
          .init(text: prompt, inlineData: nil),
          .init(text: nil, inlineData: .init(mimeType: "image/jpeg", data: base64String)),
        ])
      ],
      generationConfig: .init(response_mime_type: "application/json")
    )

    let data = try await performRequest(url: url, body: requestBody)
    let jsonText = try extractJSON(from: data)
    logger.debug("Nutrition label JSON: \(jsonText)")

    guard let cleanData = jsonText.data(using: .utf8) else {
      throw URLError(
        .cannotParseResponse,
        userInfo: [NSLocalizedDescriptionKey: "Could not parse the nutrition label response."])
    }

    return try JSONDecoder().decode(ParsedNutritionLabel.self, from: cleanData)
  }

  // MARK: - Recipe Scanning

  /// Sends a photo of a cookbook recipe to Gemini Vision and estimates
  /// per-serving macros by identifying ingredients and portion count.
  func parseRecipe(image: UIImage) async throws -> ParsedNutritionLabel {
    guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
      throw URLError(
        .cannotParseResponse,
        userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG."])
    }
    let base64String = jpegData.base64EncodedString()

    let model = "gemini-3-flash-preview"
    let urlString =
      "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
    guard let url = URL(string: urlString) else { throw URLError(.badURL) }

    // TODO: have this return the macros for the entire recipe, as well as the recipe weight in grams.
    let prompt = """
      Analyze this recipe photo from a cookbook. Identify the recipe name, all ingredients \
      with their quantities, and the number of servings.
      Estimate the total macronutrients for the entire recipe, then calculate per-serving values.
      Return ONLY valid JSON with this schema:
      {
        "description": "recipe name",
        "serving_size": "1",
        "serving_unit": "serving",
        "calories": number per serving or null,
        "protein_grams": number per serving,
        "fat_grams": number per serving,
        "carbs_grams": number per serving
      }
      If the number of servings is not stated, estimate based on context or assume 4.
      If a macro value cannot be determined, use 0.
      """

    let requestBody = GeminiRequest(
      contents: [
        .init(parts: [
          .init(text: prompt, inlineData: nil),
          .init(text: nil, inlineData: .init(mimeType: "image/jpeg", data: base64String)),
        ])
      ],
      generationConfig: .init(response_mime_type: "application/json")
    )

    let data = try await performRequest(url: url, body: requestBody)
    let jsonText = try extractJSON(from: data)
    logger.debug("Recipe scan JSON: \(jsonText)")

    guard let cleanData = jsonText.data(using: .utf8) else {
      throw URLError(
        .cannotParseResponse,
        userInfo: [NSLocalizedDescriptionKey: "Could not parse the recipe response."])
    }

    return try JSONDecoder().decode(ParsedNutritionLabel.self, from: cleanData)
  }

  // MARK: - Shared Helpers

  /// Sends an encoded request body to the Gemini API and returns the raw response data.
  /// Handles 429 rate-limiting and other HTTP errors with descriptive messages.
  private func performRequest(url: URL, body: GeminiRequest) async throws -> Data {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await session.data(for: request)

    if let httpResponse = response as? HTTPURLResponse {
      if httpResponse.statusCode == 429 {
        logger.warning("Rate Limited.")
        throw URLError(
          .badServerResponse,
          userInfo: [
            NSLocalizedDescriptionKey: "Rate limited by Gemini API. Please try again shortly."
          ])
      }
      if httpResponse.statusCode != 200 {
        logger.error("HTTP \(httpResponse.statusCode)")
        if let decoded = try? JSONDecoder().decode(ApiResponse.self, from: data) {
          throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: decoded.message])
        }
        throw URLError(.badServerResponse)
      }
    }

    return data
  }

  /// Decodes a `GeminiResponse`, pulls the first candidate's text, and strips
  /// any Markdown code-fence wrappers that Gemini sometimes adds.
  private func extractJSON(from data: Data) throws -> String {
    let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
    guard var jsonText = geminiResponse.candidates?.first?.content.parts.first?.text else {
      throw URLError(
        .cannotParseResponse,
        userInfo: [NSLocalizedDescriptionKey: "Could not read the AI response."])
    }
    // Strip Markdown code fences
    jsonText =
      jsonText
      .replacingOccurrences(of: "```json", with: "")
      .replacingOccurrences(of: "```", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return jsonText
  }
}
