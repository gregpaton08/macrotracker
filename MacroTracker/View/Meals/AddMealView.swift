//
//  AddMealView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//

import SwiftUI
import CoreData
import VisionKit

struct AddMealView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: MacroViewModel
    
    // External Date Logic
    var targetDate: Date
    
    // Inputs
    @State private var description: String = ""
    @State private var portionSize: String = ""
    @State private var selectedUnit: String = "g"
    
    // Macros
    @State private var fat: String = ""
    @State private var carbs: String = ""
    @State private var protein: String = ""
    
    // API key check
    @AppStorage("google_api_key") private var googleKey: String = ""
    private var apiKeyConfigured: Bool { !googleKey.isEmpty }
    private var geminiKeyConfigured: Bool { !googleKey.isEmpty }
    
    // Camera / Photo
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showImageSourcePicker = false
    
    // Scanner State
    @State private var showScanner = false
    private let barcodeClient = OpenFoodFactsClient()
    
    // Logic
    @State private var activeCachedMeal: CachedMealEntity? = nil
    
    // Focus
    @FocusState private var focusedField: Field?
    enum Field: Hashable {
        case description, portion, fat, carbs, protein
    }
    
    // Autocomplete
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CachedMealEntity.lastUsed, ascending: false)],
        animation: .default
    )
    private var cachedMeals: FetchedResults<CachedMealEntity>
    
    var suggestions: [CachedMealEntity] {
        if description.isEmpty { return [] }
        return cachedMeals.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(description)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - API KEY BANNER
                if !apiKeyConfigured {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("API Key Required")
                                    .font(.subheadline).bold()
                                Text("Add your Google API key in Settings to enable AI auto-fill.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // MARK: - SECTION 1: FOOD DETAILS
                Section(header: Text("Food Details")) {
                    // Description
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Description (e.g. Chicken)", text: $description)
                            .focused($focusedField, equals: .description)
                            .submitLabel(.next)
                            .onChange(of: description) { _, newValue in
                                if let active = activeCachedMeal, active.name != newValue {
                                    // activeCachedMeal = nil
                                }
                            }
                        
                        if !suggestions.isEmpty && focusedField == .description {
                            List {
                                ForEach(suggestions.prefix(3), id: \.self) { meal in
                                    Button(action: { applyCachedMeal(meal) }) {
                                        VStack(alignment: .leading) {
                                            Text(meal.name ?? "Unknown").foregroundColor(.primary)
                                            Text("Base: \(meal.portionSize ?? "100") \(meal.unit ?? "g") • P:\(Int(meal.protein))")
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .frame(height: 120)
                            .listStyle(.plain)
                        }
                    }
                    
                    // Portion & Unit
                    HStack {
                        TextField("Portion", text: $portionSize)
                            .focused($focusedField, equals: .portion)
                            .keyboardType(.decimalPad)
                            .onChange(of: portionSize) { _, _ in recalculateMacros() }
                        
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(MealEntity.validUnits, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: selectedUnit) { _, _ in recalculateMacros() }
                    }
                    
                    // MARK: - Action Buttons
                    HStack(spacing: 12) {
                        // AI Button
                        Button(action: performAIAnalysis) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Fill with AI")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(description.isEmpty || viewModel.isLoading)
                        
                        // Scan Nutrition Label Button
                        Button(action: { showImageSourcePicker = true }) {
                            HStack {
                                Image(systemName: "camera")
                                Text("Scan Nutrition Label")
                            }
                        }
                        .disabled(!geminiKeyConfigured || viewModel.isLoading)
                        .confirmationDialog("Choose Image Source", isPresented: $showImageSourcePicker) {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button("Take Photo") { showCamera = true }
                            }
                            Button("Choose from Library") { showPhotoLibrary = true }
                            Button("Cancel", role: .cancel) {}
                        }
                        
                        // Scan Button
                        Button(action: { showScanner = true }) {
                            HStack {
                                Image(systemName: "barcode.viewfinder")
                                Text("Scan")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
                
                // MARK: - SECTION 2: MACROS (Compact Row)
                Section(header: Text("Macros (Auto-Scales)")) {
                    HStack(spacing: 20) {
                        // FAT
                        VStack(alignment: .center, spacing: 4) {
                            Text("Fat").font(.caption).bold().foregroundColor(Theme.over)
                            TextField("0", text: $fat)
                                .focused($focusedField, equals: .fat)
                                .multilineTextAlignment(.center)
                                .keyboardType(.decimalPad)
                                .padding(8)
                                .background(Theme.secondaryBackground)
                                .cornerRadius(8)
                        }
                        
                        // CARBS
                        VStack(alignment: .center, spacing: 4) {
                            Text("Carbs").font(.caption).bold().foregroundColor(Theme.tint)
                            TextField("0", text: $carbs)
                                .focused($focusedField, equals: .carbs)
                                .multilineTextAlignment(.center)
                                .keyboardType(.decimalPad)
                                .padding(8)
                                .background(Theme.secondaryBackground)
                                .cornerRadius(8)
                        }
                        
                        // PROTEIN
                        VStack(alignment: .center, spacing: 4) {
                            Text("Protein").font(.caption).bold().foregroundColor(Theme.good)
                            TextField("0", text: $protein)
                                .focused($focusedField, equals: .protein)
                                .multilineTextAlignment(.center)
                                .keyboardType(.decimalPad)
                                .padding(8)
                                .background(Theme.secondaryBackground)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Bottom Save Button
                Section {
                    Button("Save Meal") { saveMeal() }
                        .disabled(description.isEmpty)
                }
            }
            .navigationTitle("Add Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveMeal() }
                        .disabled(description.isEmpty)
                        .bold()
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Button(action: { moveFocus(-1) }) { Image(systemName: "chevron.up") }
                        .disabled(focusedField == .description)
                    Button(action: { moveFocus(1) }) { Image(systemName: "chevron.down") }
                        .disabled(focusedField == .protein)
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            // Auto-Select Text Logic
            .onChange(of: focusedField) { _, newValue in
                guard newValue != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                }
            }
            // Error Alert
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(sourceType: .camera, isPresented: $showCamera) { image in
                    processNutritionLabelImage(image)
                }
            }
            .sheet(isPresented: $showPhotoLibrary) {
                CameraPicker(sourceType: .photoLibrary, isPresented: $showPhotoLibrary) { image in
                    processNutritionLabelImage(image)
                }
            }
            // Scanner Sheet
            .sheet(isPresented: $showScanner) {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    BarcodeScannerView { code in
                        handleBarcode(code)
                    }
                } else {
                    VStack {
                        Image(systemName: "camera.fill.badge.ellipsis")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Camera not available")
                            .font(.headline)
                        Text("Barcode scanning requires a physical device with a camera.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .presentationDetents([.medium])
                }
            }
        }
        // Loading Overlay
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Analyzing...")
                            .foregroundColor(.white)
                            .bold()
                            .padding(.top, 8)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func moveFocus(_ direction: Int) {
        let order: [Field] = [.description, .portion, .fat, .carbs, .protein]
        guard let current = focusedField, let index = order.firstIndex(of: current) else { return }
        let next = index + direction
        if next >= 0 && next < order.count { focusedField = order[next] }
    }
    
    private func applyCachedMeal(_ meal: CachedMealEntity) {
        self.activeCachedMeal = meal
        self.description = meal.name ?? ""
        self.selectedUnit = meal.unit ?? "g"
        if portionSize.isEmpty { self.portionSize = meal.portionSize ?? "100" }
        recalculateMacros()
        focusedField = nil
    }
    
    private func recalculateMacros() {
        guard let cached = activeCachedMeal else { return }
        let currentSize = Double(portionSize) ?? 0
        let baseSize = Double(cached.portionSize ?? "0") ?? 0
        
        if currentSize > 0, baseSize > 0, cached.unit == selectedUnit {
            let ratio = currentSize / baseSize
            self.fat = String(format: "%.1f", cached.fat * ratio)
            self.carbs = String(format: "%.1f", cached.carbs * ratio)
            self.protein = String(format: "%.1f", cached.protein * ratio)
        } else {
            self.fat = String(format: "%.1f", cached.fat)
            self.carbs = String(format: "%.1f", cached.carbs)
            self.protein = String(format: "%.1f", cached.protein)
        }
    }
    
    private func processNutritionLabelImage(_ image: UIImage) {
        focusedField = nil
        Task {
            if let result = await viewModel.scanNutritionLabel(image: image) {
                fat = String(format: "%.1f", result.fat_grams)
                carbs = String(format: "%.1f", result.carbs_grams)
                protein = String(format: "%.1f", result.protein_grams)
                
                if let size = result.serving_size, !size.isEmpty {
                    portionSize = size
                }
                if let unit = result.serving_unit, MealEntity.validUnits.contains(unit) {
                    selectedUnit = unit
                }
                if let desc = result.description, !desc.isEmpty, description.isEmpty {
                    description = desc
                }
                
                activeCachedMeal = nil
            }
        }
    }
    
    private func performAIAnalysis() {
        guard !description.isEmpty else { return }
        focusedField = nil
        Task {
            let query = portionSize.isEmpty ? description : "\(portionSize) \(selectedUnit) \(description)"
            if let result = await viewModel.calculateMacros(description: query) {
                fat = String(format: "%.1f", result.f)
                carbs = String(format: "%.1f", result.c)
                protein = String(format: "%.1f", result.p)
                activeCachedMeal = nil
            }
        }
    }
    
    private func handleBarcode(_ code: String) {
        viewModel.isLoading = true
        
        Task {
            if let product = try? await barcodeClient.fetchProduct(barcode: code) {
                // Update UI on Main Actor
                await MainActor.run {
                    self.description = product.name
                    self.selectedUnit = "g"
                    self.portionSize = "100" // OFF data is always per 100g
                    
                    // Auto-fill Macros (per 100g base)
                    self.protein = String(format: "%.1f", product.p)
                    self.carbs = String(format: "%.1f", product.c)
                    self.fat = String(format: "%.1f", product.f)
                    
                    // Treat this like a "Cached Meal" so scaling works if they change portion
                    // We mock a CachedMeal logic or just leave it raw.
                    // For now, raw update is safer.
                    
                    viewModel.isLoading = false
                }
            } else {
                await MainActor.run {
                    viewModel.errorMessage = "Product not found."
                    viewModel.showError = true
                    viewModel.isLoading = false
                }
            }
        }
    }
    
    private func saveMeal() {
        let p = max(0, Double(protein) ?? 0)
        let f = max(0, Double(fat) ?? 0)
        let c = max(0, Double(carbs) ?? 0)
        let amount = max(0, Double(portionSize) ?? 0)
        
        let success = viewModel.saveMeal(
            description: description,
            p: p, f: f, c: c,
            portion: amount,
            portionUnit: selectedUnit,
            date: targetDate
        )
        
        guard success else { return }
        
        MealCacheManager.shared.cacheMeal(
            name: description, p: p, f: f, c: c, portion: portionSize, unit: selectedUnit
        )
        
        presentationMode.wrappedValue.dismiss()
    }
}
