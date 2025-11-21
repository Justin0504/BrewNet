import SwiftUI

// MARK: - Industry Selection Data Model (for Industry Edit View)
struct IndustryEditSelection: Identifiable, Codable, Equatable {
    let id: String
    let categoryName: String
    let subcategoryName: String
    
    init(categoryName: String, subcategoryName: String) {
        self.id = "\(categoryName)-\(subcategoryName)"
        self.categoryName = categoryName
        self.subcategoryName = subcategoryName
    }
}

// MARK: - Industry Edit View
struct IndustryEditView: View {
    @Binding var industrySelections: [IndustryEditSelection]
    
    @State private var expandedCategories: Set<String> = []
    
    private let themeBrown = Color(red: 0.4, green: 0.2, blue: 0.1)
    private let lightBrown = Color(red: 0.6, green: 0.4, blue: 0.2)
    private let lightBackground = Color(red: 0.98, green: 0.97, blue: 0.95)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Industry Categories
                VStack(spacing: 16) {
                    ForEach(IndustryData.categories, id: \.id) { category in
                        IndustryCategoryCard(
                            category: category,
                            industrySelections: $industrySelections,
                            isExpanded: Binding(
                                get: { expandedCategories.contains(category.id) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedCategories.insert(category.id)
                                    } else {
                                        expandedCategories.remove(category.id)
                                    }
                                }
                            )
                        )
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(lightBackground)
        .onChange(of: industrySelections) { newSelections in
            print("🔄 [IndustryEditView] industrySelections changed, refreshing view. Count: \(newSelections.count)")
            
            // Auto-expand categories that have selections
            let categoriesWithSelections = Set(newSelections.map { $0.categoryName })
            for categoryName in categoriesWithSelections {
                if let category = IndustryData.categories.first(where: { $0.name == categoryName }) {
                    expandedCategories.insert(category.id)
                    print("📂 [IndustryEditView] Auto-expanded category: \(categoryName)")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ExpandCategoriesWithSelections"))) { notification in
            if let selections = notification.userInfo?["selections"] as? [IndustryEditSelection] {
                let categoriesWithSelections = Set(selections.map { $0.categoryName })
                for categoryName in categoriesWithSelections {
                    if let category = IndustryData.categories.first(where: { $0.name == categoryName }) {
                        expandedCategories.insert(category.id)
                        print("📂 [IndustryEditView] Expanded category from notification: \(categoryName)")
                    }
                }
            }
        }
    }
}

// MARK: - Industry Category Card
struct IndustryCategoryCard: View {
    let category: IndustryCategory
    @Binding var industrySelections: [IndustryEditSelection]
    @Binding var isExpanded: Bool
    
    private let themeBrown = Color(red: 0.4, green: 0.2, blue: 0.1)
    private let lightBrown = Color(red: 0.6, green: 0.4, blue: 0.2)
    private let cardBackground = Color.white
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(category.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(themeBrown)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(lightBrown)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(cardBackground)
            }
            
            // Expanded Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Subcategories List
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(category.subcategories, id: \.self) { subcategory in
                            IndustrySubcategoryRow(
                                categoryName: category.name,
                                subcategoryName: subcategory,
                                industrySelections: $industrySelections
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .background(cardBackground)
            }
        }
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // Helper functions
    private func getSelection(categoryName: String, subcategoryName: String) -> IndustryEditSelection? {
        return industrySelections.first { $0.categoryName == categoryName && $0.subcategoryName == subcategoryName }
    }
    
    private func addSelection(categoryName: String, subcategoryName: String) {
        if getSelection(categoryName: categoryName, subcategoryName: subcategoryName) == nil {
            let newSelection = IndustryEditSelection(
                categoryName: categoryName,
                subcategoryName: subcategoryName
            )
            industrySelections.append(newSelection)
        }
    }
    
    private func removeSelection(categoryName: String, subcategoryName: String) {
        if let index = industrySelections.firstIndex(where: { $0.categoryName == categoryName && $0.subcategoryName == subcategoryName }) {
            industrySelections.remove(at: index)
        }
    }
    
}

// MARK: - Industry Subcategory Row
struct IndustrySubcategoryRow: View {
    let categoryName: String
    let subcategoryName: String
    @Binding var industrySelections: [IndustryEditSelection]
    
    private let themeBrown = Color(red: 0.4, green: 0.2, blue: 0.1)
    private let lightBrown = Color(red: 0.6, green: 0.4, blue: 0.2)
    
    private var isSelected: Bool {
        industrySelections.contains { $0.categoryName == categoryName && $0.subcategoryName == subcategoryName }
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                if isSelected {
                    // Remove selection
                    if let index = industrySelections.firstIndex(where: { $0.categoryName == categoryName && $0.subcategoryName == subcategoryName }) {
                        industrySelections.remove(at: index)
                    }
                } else {
                    // Add selection
                    let newSelection = IndustryEditSelection(
                        categoryName: categoryName,
                        subcategoryName: subcategoryName
                    )
                    industrySelections.append(newSelection)
                }
            }
        }) {
            HStack(spacing: 12) {
                // Subcategory Name
                Text(subcategoryName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSelected ? .white : themeBrown)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Checkmark icon
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .white : Color.gray.opacity(0.4))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(isSelected ? lightBrown : Color.gray.opacity(0.05))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct IndustryEditView_Previews: PreviewProvider {
    static var previews: some View {
        IndustryEditView(industrySelections: .constant([]))
    }
}

