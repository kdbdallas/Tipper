//
//  ContentView.swift
//  Tipper
//
//  Created by Dallas Brown on 4/11/26.
//

import SwiftUI

private enum Constants {
    static let defaultPercentage: Double = 20
    static let sliderRange: ClosedRange<Double> = 10...40
}

/// Digits the local currency actually subdivides into — 2 for USD/EUR, 0 for
/// JPY. Keeps the editable fields in step with the currency-formatted labels.
private let currencyFractionDigits: Int = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = .autoupdatingCurrent
    return formatter.maximumFractionDigits
}()

/// Digits plus at most one decimal separator, capped at the currency's minor
/// units. `.decimalPad` enforces none of this on its own — it will let the user
/// type "12.5.0", which parses as nothing at all.
private func sanitizedAmountText(_ text: String) -> String {
    let separator = Locale.current.decimalSeparator ?? "."
    var result = ""
    var fractionDigits = 0
    var sawSeparator = false

    for character in text {
        // `wholeNumberValue` also folds non-Latin digits (٥, ५) down to ASCII,
        // which is what the parser and formatter below both speak.
        if let digit = character.wholeNumberValue, (0...9).contains(digit) {
            if sawSeparator {
                guard fractionDigits < currencyFractionDigits else { continue }
                fractionDigits += 1
            }
            result += String(digit)
        } else if String(character) == separator || character == "." || character == "," {
            guard !sawSeparator, currencyFractionDigits > 0 else { continue }
            sawSeparator = true
            result += separator
        }
    }
    return result
}

/// Reads text produced by `sanitizedAmountText` / `formatAmount`. The decimal
/// separator is the locale's, so `Double(_:)` cannot be used directly.
private func parseAmount(_ text: String) -> Double? {
    let separator = Locale.current.decimalSeparator ?? "."
    let normalized = text.replacingOccurrences(of: separator, with: ".")
    guard !normalized.isEmpty, normalized != "." else { return nil }
    return Double(normalized)
}

/// Formats for the text fields, not for display: ASCII digits and the locale's
/// decimal separator, so the result round-trips back through `parseAmount`.
private func formatAmount(_ value: Double) -> String {
    let separator = Locale.current.decimalSeparator ?? "."
    return String(format: "%.\(currencyFractionDigits)f", value)
        .replacingOccurrences(of: ".", with: separator)
}

/// Snaps to a whole number of cents (or yen), so that a tip which is displayed
/// rounded is also the tip that gets added to the total.
private func roundedToMinorUnits(_ value: Double) -> Double {
    let scale = pow(10.0, Double(currencyFractionDigits))
    return (value * scale).rounded() / scale
}

/// SwiftUI's `Slider` gives no hook for styling the thumb — `.tint` reaches the
/// track only — and the thumb is the one part that has to change here: when the
/// rate is outside the slider's range the knob is parked at the end of the track
/// and is no longer reporting the real value. Dimming it says so.
private struct TipSlider: UIViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let isPinned: Bool
    let accessibilityValue: String

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.accessibilityLabel = "Tip"
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        slider.addTarget(context.coordinator,
                         action: #selector(Coordinator.valueChanged(_:)),
                         for: .valueChanged)
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        context.coordinator.parent = self

        // Only reposition on an outside change; during a drag the thumb is
        // already where the finger is, and re-setting it fights the gesture.
        if abs(Double(slider.value) - value) > step / 2 {
            slider.setValue(Float(value), animated: false)
        }
        slider.minimumTrackTintColor = UIColor(Color.accentColor)
        // nil restores the stock white knob.
        slider.thumbTintColor = isPinned ? .systemGray3 : nil
        slider.accessibilityValue = accessibilityValue
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator {
        var parent: TipSlider

        init(_ parent: TipSlider) { self.parent = parent }

        @objc func valueChanged(_ slider: UISlider) {
            let stepped = (Double(slider.value) / parent.step).rounded() * parent.step
            parent.value = min(max(stepped, parent.range.lowerBound), parent.range.upperBound)
        }
    }
}

struct ContentView: View {
    /// The single source of truth for the tip. The user drives either a rate
    /// (slider, presets) or an explicit amount (typing over the total); every
    /// other number on screen is derived from whichever one it is. Keeping both
    /// independently would let the displayed rate and the displayed tip drift
    /// apart, which is exactly what a clamped slider position causes.
    private enum TipBasis: Equatable {
        case percentage(Double)
        case amount(Double)
    }

    @State private var billAmountText = ""
    @State private var totalAmountText = ""
    @State private var tipBasis: TipBasis = .percentage(Constants.defaultPercentage)

    @FocusState private var billFieldFocused: Bool
    @FocusState private var totalFieldFocused: Bool

    private let presetPercentages = [18, 20, 22, 25]

    private var billAmount: Double {
        parseAmount(billAmountText) ?? 0
    }

    private var tipAmount: Double {
        switch tipBasis {
        case .percentage(let percent):
            // Rounded here so that the tip and total on screen always add up.
            return roundedToMinorUnits(billAmount * percent / 100)
        case .amount(let amount):
            return amount
        }
    }

    private var totalAmount: Double {
        billAmount + tipAmount
    }

    /// The rate actually being applied. Never clamped to the slider's range —
    /// the slider position may be pinned, but the number shown must not lie.
    /// `nil` when there is no bill to express a rate against.
    private var tipPercentage: Double? {
        switch tipBasis {
        case .percentage(let percent):
            return percent
        case .amount(let amount):
            guard billAmount > 0 else { return nil }
            return amount / billAmount * 100
        }
    }

    /// What `totalAmountText` reads when it reflects the current state. Used to
    /// tell an edit made by the user apart from one made by `syncTotalText()`.
    private var canonicalTotalText: String {
        billAmount > 0 ? formatAmount(totalAmount) : ""
    }

    private var sliderValue: Binding<Double> {
        Binding(
            get: {
                let percent = tipPercentage ?? Constants.defaultPercentage
                return min(max(percent, Constants.sliderRange.lowerBound),
                           Constants.sliderRange.upperBound)
            },
            set: { newValue in
                tipBasis = .percentage(newValue)
                syncTotalText()
            }
        )
    }

    /// True when the rate in force is outside the slider's range, so the knob is
    /// parked at one end and is no longer pointing at the real value. The
    /// tolerance keeps a rate that *displays* as 10.0% or 40.0% from counting.
    private var isRatePinned: Bool {
        guard let tipPercentage else { return false }
        return tipPercentage < Constants.sliderRange.lowerBound - 0.05
            || tipPercentage > Constants.sliderRange.upperBound + 0.05
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    private var currencySymbol: String {
        Locale.current.currencySymbol ?? "$"
    }

    private var tipPercentageLabel: String {
        guard let tipPercentage else { return "—" }
        return (tipPercentage / 100).formatted(.percent.precision(.fractionLength(1)))
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
                            Text(currencySymbol)
                                .font(.system(size: 40, weight: .light, design: .rounded))
                                .foregroundStyle(.secondary)

                            TextField(formatAmount(0), text: $billAmountText)
                                .font(.system(size: 40, weight: .light, design: .rounded))
                                .keyboardType(.decimalPad)
                                .focused($billFieldFocused)
                                .onChange(of: billAmountText) { oldValue, newValue in
                                    billTextChanged(from: oldValue, to: newValue)
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
                                    withAnimation(.snappy(duration: 0.2)) {
                                        tipBasis = .percentage(Double(percent))
                                    }
                                    syncTotalText()
                                } label: {
                                    Text((Double(percent) / 100).formatted(.percent.precision(.fractionLength(0))))
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
                            HStack(spacing: 8) {
                                Text((Constants.sliderRange.lowerBound / 100).formatted(.percent.precision(.fractionLength(0))))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                TipSlider(value: sliderValue,
                                          range: Constants.sliderRange,
                                          step: 0.1,
                                          isPinned: isRatePinned,
                                          accessibilityValue: tipPercentageLabel)

                                Text((Constants.sliderRange.upperBound / 100).formatted(.percent.precision(.fractionLength(0))))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Text(tipPercentageLabel)
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
                            Text(tipAmount, format: .currency(code: currencyCode))
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
                                Text(currencySymbol)
                                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.accentColor)

                                TextField(formatAmount(0), text: $totalAmountText)
                                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.accentColor)
                                    .keyboardType(.decimalPad)
                                    .focused($totalFieldFocused)
                                    .onChange(of: totalFieldFocused) { _, isFocused in
                                        // Snap the field back to bill + tip on the way out, so a
                                        // total the math could not honour never lingers on screen.
                                        if !isFocused { syncTotalText() }
                                    }
                                    .onChange(of: totalAmountText) { _, newValue in
                                        totalTextChanged(to: newValue)
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
                    Button("Clear", action: clearAll)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func isPresetSelected(_ percent: Int) -> Bool {
        guard let tipPercentage else { return false }
        return abs(tipPercentage - Double(percent)) < 0.001
    }

    private func syncTotalText() {
        let text = canonicalTotalText
        guard text != totalAmountText else { return }
        totalAmountText = text
    }

    private func billTextChanged(from oldText: String, to newText: String) {
        let cleaned = sanitizedAmountText(newText)
        if cleaned != newText {
            billAmountText = cleaned
        }
        // Editing the bill hands control back to the rate. Convert an explicit
        // tip into the rate it represented against the *previous* bill, so the
        // user's intent survives the edit instead of snapping to a clamp.
        if case .amount(let amount) = tipBasis {
            let previousBill = parseAmount(oldText) ?? 0
            tipBasis = .percentage(previousBill > 0
                                   ? amount / previousBill * 100
                                   : Constants.defaultPercentage)
        }
        syncTotalText()
    }

    private func totalTextChanged(to newText: String) {
        // Already consistent with bill + tip: either this view just wrote it, or
        // the user typed the number the current state already produces.
        guard newText != canonicalTotalText else { return }

        let cleaned = sanitizedAmountText(newText)
        if cleaned != newText {
            totalAmountText = cleaned
        }
        // Without a bill there is nothing to split into bill + tip. The field is
        // normalised when it loses focus.
        guard billAmount > 0 else { return }

        let typedTotal = parseAmount(cleaned) ?? 0
        tipBasis = .amount(roundedToMinorUnits(max(typedTotal - billAmount, 0)))
    }

    private func clearAll() {
        tipBasis = .percentage(Constants.defaultPercentage)
        billAmountText = ""
        totalAmountText = ""
        totalFieldFocused = false
        billFieldFocused = true
    }
}

#Preview {
    ContentView()
}
