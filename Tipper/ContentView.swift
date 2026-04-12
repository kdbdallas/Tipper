//
//  ContentView.swift
//  Tipper
//
//  Created by Dallas Brown on 4/11/26.
//

import SwiftUI

struct ContentView: View {
    @State private var billAmountText = ""
    @State private var tipPercentage: Double = 20.0
    @State private var totalAmountText = ""
    @State private var isEditingTotal = false
    @State private var overrideTipAmount: Double?

    @FocusState private var billFieldFocused: Bool
    @FocusState private var totalFieldFocused: Bool

    private let presetPercentages = [18, 20, 22, 25]
    private let sliderRange: ClosedRange<Double> = 10...40

    private var billAmount: Double {
        Double(billAmountText) ?? 0
    }

    private var tipAmount: Double {
        if let override = overrideTipAmount {
            return override
        }
        return billAmount * tipPercentage / 100.0
    }

    private var totalAmount: Double {
        billAmount + tipAmount
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Bill Amount Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bill Amount")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        HStack(spacing: 4) {
                            Text("$")
                                .font(.system(size: 40, weight: .light, design: .rounded))
                                .foregroundStyle(.secondary)

                            TextField("0.00", text: $billAmountText)
                                .font(.system(size: 40, weight: .light, design: .rounded))
                                .keyboardType(.decimalPad)
                                .focused($billFieldFocused)
                                .onChange(of: billAmountText) {
                                    if !isEditingTotal {
                                        overrideTipAmount = nil
                                        updateTotalText()
                                    }
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(billFieldFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }

                    // Tip Percentage Presets
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tip Percentage")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        HStack(spacing: 10) {
                            ForEach(presetPercentages, id: \.self) { percent in
                                Button {
                                    overrideTipAmount = nil
                                    withAnimation(.snappy(duration: 0.2)) {
                                        tipPercentage = Double(percent)
                                    }
                                    updateTotalText()
                                } label: {
                                    Text("\(percent)%")
                                        .font(.headline)
                                        .fontDesign(.rounded)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(isPresetSelected(percent) ? Color.accentColor : Color(.secondarySystemFill))
                                        )
                                        .foregroundStyle(isPresetSelected(percent) ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Slider
                        VStack(spacing: 4) {
                            Slider(value: $tipPercentage, in: sliderRange, step: 0.1) {
                                Text("Tip")
                            } minimumValueLabel: {
                                Text("10%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } maximumValueLabel: {
                                Text("40%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .tint(.accentColor)
                            .onChange(of: tipPercentage) {
                                if !isEditingTotal {
                                    overrideTipAmount = nil
                                    updateTotalText()
                                }
                            }

                            Text(String(format: "%.1f%%", tipPercentage))
                                .font(.title3)
                                .fontWeight(.medium)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color.accentColor)
                                .contentTransition(.numericText())
                                .animation(.snappy(duration: 0.15), value: tipPercentage)
                        }
                        .padding(.top, 4)
                    }

                    // Results
                    VStack(spacing: 16) {
                        // Tip Amount
                        HStack {
                            Text("Tip")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(tipAmount, format: .currency(code: "USD"))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)
                                .contentTransition(.numericText())
                                .animation(.snappy(duration: 0.15), value: tipAmount)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.secondarySystemFill))
                        )

                        // Total Amount (Editable)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Total")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            HStack(spacing: 4) {
                                Text("$")
                                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.accentColor)

                                TextField("0.00", text: $totalAmountText)
                                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.accentColor)
                                    .keyboardType(.decimalPad)
                                    .focused($totalFieldFocused)
                                    .onChange(of: totalFieldFocused) {
                                        isEditingTotal = totalFieldFocused
                                    }
                                    .onChange(of: totalAmountText) {
                                        guard isEditingTotal else { return }
                                        recalculateFromTotal()
                                    }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.accentColor.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(totalFieldFocused ? Color.accentColor : Color.accentColor.opacity(0.2), lineWidth: 2)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { billFieldFocused = true }
            .navigationTitle("Tipper")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Clear") {
                        billAmountText = ""
                        totalAmountText = ""
                        tipPercentage = 20.0
                        overrideTipAmount = nil
                        isEditingTotal = false
                        totalFieldFocused = false
                        billFieldFocused = true
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func isPresetSelected(_ percent: Int) -> Bool {
        abs(tipPercentage - Double(percent)) < 0.05
    }

    private func updateTotalText() {
        guard billAmount > 0 else {
            totalAmountText = ""
            return
        }
        totalAmountText = String(format: "%.2f", totalAmount)
    }

    private func recalculateFromTotal() {
        guard let newTotal = Double(totalAmountText), billAmount > 0 else { return }
        let newTip = max(newTotal - billAmount, 0)
        let newPercent = (newTip / billAmount) * 100.0
        let clampedPercent = min(max(newPercent, sliderRange.lowerBound), sliderRange.upperBound)
        let sliderPercent = (clampedPercent * 10).rounded() / 10
        overrideTipAmount = newTip
        withAnimation(.snappy(duration: 0.15)) {
            tipPercentage = sliderPercent
        }
    }
}

#Preview {
    ContentView()
}
