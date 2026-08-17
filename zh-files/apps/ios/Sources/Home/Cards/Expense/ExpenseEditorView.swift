import SwiftUI

/// 账目新建/编辑页：金额 + 类型 + 类别 + 备注 + 日期，本地保存。
/// 支持被 push（快捷动作「快速记账」）或被 sheet 包 NavigationStack 呈现。
struct ExpenseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let store: ExpenseStore
    var entry: ExpenseEntry?

    @State private var amountText: String
    @State private var type: ExpenseType
    @State private var category: ExpenseCategory
    @State private var note: String
    @State private var date: Date
    @State private var errorText: String?

    init(store: ExpenseStore, entry: ExpenseEntry? = nil) {
        self.store = store
        self.entry = entry
        _amountText = State(initialValue: entry.map { String(format: "%.2f", $0.amount) } ?? "")
        _type = State(initialValue: entry?.type ?? .expense)
        _category = State(initialValue: entry?.category ?? .food)
        _note = State(initialValue: entry?.note ?? "")
        _date = State(initialValue: entry?.date ?? Date())
    }

    var body: some View {
        Form {
            Section(String(localized: "Expense.Editor.Amount")) {
                TextField(String(localized: "Expense.Editor.AmountPlaceholder"), text: $amountText)
                    .keyboardType(.decimalPad)
            }
            Section(String(localized: "Expense.Editor.Type")) {
                Picker(String(localized: "Expense.Editor.Type"), selection: $type) {
                    ForEach(ExpenseType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section(String(localized: "Expense.Editor.Category")) {
                Picker(String(localized: "Expense.Editor.Category"), selection: $category) {
                    ForEach(ExpenseCategory.allCases) { category in
                        Label(category.title, systemImage: category.iconName)
                            .tag(category)
                    }
                }
                .pickerStyle(.menu)
            }
            Section(String(localized: "Expense.Editor.Note")) {
                TextField(String(localized: "Expense.Editor.NotePlaceholder"), text: $note)
            }
            Section(String(localized: "Expense.Editor.Date")) {
                DatePicker(selection: $date, displayedComponents: [.date, .hourAndMinute]) {
                    Text(String(localized: "Expense.Editor.Date"))
                }
            }
            if let errorText {
                Section {
                    Text(errorText)
                        .font(OpenClawType.footnote)
                        .foregroundStyle(OpenClawBrand.danger)
                }
            }
        }
        .navigationTitle(entry == nil ? String(localized: "Expense.Editor.New") : String(localized: "Expense.Editor.Edit"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Common.Cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Common.Save")) { save() }
            }
        }
    }

    private func save() {
        let trimmedAmount = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Double(trimmedAmount), amount > 0 else {
            errorText = String(localized: "Expense.Editor.InvalidAmount")
            return
        }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let entry {
            var updated = entry
            updated.amount = amount
            updated.type = type
            updated.category = category
            updated.note = trimmedNote
            updated.date = date
            store.update(updated)
        } else {
            store.add(amount: amount, type: type, category: category, note: trimmedNote, date: date)
        }
        dismiss()
    }
}