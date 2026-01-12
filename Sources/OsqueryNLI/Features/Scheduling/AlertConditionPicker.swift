import SwiftUI

/// Picker for configuring alert conditions
struct AlertConditionPicker: View {
    @Binding var condition: AlertCondition
    @State private var selectedType: AlertConditionType
    @State private var threshold: Int
    @State private var columnName: String
    @State private var columnValue: String

    init(condition: Binding<AlertCondition>) {
        self._condition = condition
        // Initialize state from current condition
        switch condition.wrappedValue {
        case .anyResults:
            _selectedType = State(initialValue: .anyResults)
            _threshold = State(initialValue: 0)
            _columnName = State(initialValue: "")
            _columnValue = State(initialValue: "")
        case .noResults:
            _selectedType = State(initialValue: .noResults)
            _threshold = State(initialValue: 0)
            _columnName = State(initialValue: "")
            _columnValue = State(initialValue: "")
        case .rowCountGreaterThan(let n):
            _selectedType = State(initialValue: .moreThan)
            _threshold = State(initialValue: n)
            _columnName = State(initialValue: "")
            _columnValue = State(initialValue: "")
        case .rowCountLessThan(let n):
            _selectedType = State(initialValue: .lessThan)
            _threshold = State(initialValue: n)
            _columnName = State(initialValue: "")
            _columnValue = State(initialValue: "")
        case .rowCountEquals(let n):
            _selectedType = State(initialValue: .equals)
            _threshold = State(initialValue: n)
            _columnName = State(initialValue: "")
            _columnValue = State(initialValue: "")
        case .rowCountNotEquals(let n):
            _selectedType = State(initialValue: .notEquals)
            _threshold = State(initialValue: n)
            _columnName = State(initialValue: "")
            _columnValue = State(initialValue: "")
        case .containsValue(let column, let value):
            _selectedType = State(initialValue: .contains)
            _threshold = State(initialValue: 0)
            _columnName = State(initialValue: column)
            _columnValue = State(initialValue: value)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Alert when", selection: $selectedType) {
                ForEach(AlertConditionType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .onChange(of: selectedType) { _, newValue in
                updateCondition()
            }

            if selectedType.needsThreshold {
                HStack {
                    Text("Threshold:")
                    TextField("", value: $threshold, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: threshold) { _, _ in
                            updateCondition()
                        }
                }
            }

            if selectedType.needsColumnValue {
                HStack {
                    Text("Column:")
                    TextField("column_name", text: $columnName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onChange(of: columnName) { _, _ in
                            updateCondition()
                        }
                }

                HStack {
                    Text("Contains:")
                    TextField("value", text: $columnValue)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onChange(of: columnValue) { _, _ in
                            updateCondition()
                        }
                }
            }
        }
    }

    private func updateCondition() {
        switch selectedType {
        case .anyResults:
            condition = .anyResults
        case .noResults:
            condition = .noResults
        case .moreThan:
            condition = .rowCountGreaterThan(max(0, threshold))
        case .lessThan:
            condition = .rowCountLessThan(max(0, threshold))
        case .equals:
            condition = .rowCountEquals(max(0, threshold))
        case .notEquals:
            condition = .rowCountNotEquals(max(0, threshold))
        case .contains:
            condition = .containsValue(column: columnName, value: columnValue)
        }
    }
}
