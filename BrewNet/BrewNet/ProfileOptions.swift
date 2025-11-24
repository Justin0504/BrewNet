import Foundation

// MARK: - Industry Category (一级分类)
struct IndustryCategory: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let subcategories: [String]
    
    init(name: String, subcategories: [String]) {
        self.id = name
        self.name = name
        self.subcategories = subcategories
    }
}

// MARK: - Industry Data (一级二级分类数据)
struct IndustryData {
    static let categories: [IndustryCategory] = [
        IndustryCategory(
            name: "Tech / Internet",
            subcategories: [
                "Software Engineer",
                "Backend / Infrastructure",
                "Frontend Engineer",
                "DevOps / SRE",
                "Mobile Engineer",
                "Product Manager (Tech)",
                "Data Engineer",
                "Machine Learning / AI Engineer",
                "Other"
            ]
        ),
        IndustryCategory(
            name: "Business & Finance",
            subcategories: [
                "Finance / Investment Banking",
                "Equity Research / Asset Mgmt",
                "Corporate Strategy / BizOps",
                "Management Consulting",
                "Accounting / FP&A",
                "Sales & Business Development",
                "Corporate Development / M&A",
                "Other"
            ]
        ),
        IndustryCategory(
            name: "Consumer & Retail (FMCG / CPG)",
            subcategories: [
                "Brand / Marketing Manager",
                "Category Manager / Merchandising",
                "Supply Chain / Ops",
                "Retail Strategy",
                "eCommerce Manager",
                "Product Marketing",
                "Other"
            ]
        ),
        IndustryCategory(
            name: "Product & Design",
            subcategories: [
                "Product Manager",
                "UX/UI Designer",
                "Product Designer",
                "UX Research / Researcher",
                "Product Ops",
                "Growth PM",
                "Other"
            ]
        ),
        IndustryCategory(
            name: "Data & Research",
            subcategories: [
                "Data Scientist",
                "Data Analyst / BI",
                "Research Scientist",
                "Causal Inference / Uplift Specialist",
                "Quant / ML Research",
                "Other"
            ]
        ),
        IndustryCategory(
            name: "Hardware & Engineering",
            subcategories: [
                "Hardware Engineer",
                "Mechanical Engineer",
                "Systems / Firmware Engineer",
                "Robotics / Controls Engineer",
                "Hardware PM",
                "Other"
            ]
        ),
        IndustryCategory(
            name: "Healthcare & Life Sciences",
            subcategories: [
                "Clinical Research / Scientist",
                "Biotech / Pharma R&D",
                "Healthcare Product Manager",
                "Health Data Scientist",
                "Medical Professional (MD/NP)",
                "Other"
            ]
        ),
        IndustryCategory(
            name: "Other / Startup & Ops",
            subcategories: [
                "Founder / Co-founder",
                "Operations / Program Manager",
                "HR / Recruiting",
                "Legal / Compliance",
                "Customer Success / Support",
                "Other"
            ]
        )
    ]
    
    static func category(for name: String) -> IndustryCategory? {
        return categories.first { $0.name == name }
    }
    
    static func subcategory(for categoryName: String, subcategoryName: String) -> String? {
        guard let category = category(for: categoryName) else { return nil }
        return category.subcategories.first { $0 == subcategoryName }
    }
}

// MARK: - Industry Option (保持向后兼容)
enum IndustryOption: String, CaseIterable, Codable {
    case technology = "Technology"
    case finance = "Finance"
    case marketing = "Marketing & Media"
    case consulting = "Consulting & Strategy"
    case education = "Education & Research"
    case healthcare = "Healthcare & Biotech"
    case manufacturing = "Manufacturing & Engineering"
    case ecommerce = "Internet & E-Commerce"
    case government = "Government & Public Sector"
    case arts = "Arts, Design & Entertainment"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Discussion Topics by Industry
struct DiscussionTopics {
    static let technology = [
        "AI & Machine Learning", "Software Development", "Data Science", "Cybersecurity",
        "Cloud Computing", "Mobile Development", "DevOps", "Product Management",
        "UX/UI Design", "Blockchain", "IoT", "Quantum Computing"
    ]
    
    static let finance = [
        "Investment Strategies", "FinTech Innovation", "Cryptocurrency", "Risk Management",
        "Financial Planning", "Trading", "Banking", "Insurance",
        "Real Estate", "Venture Capital", "Private Equity", "Regulatory Compliance"
    ]
    
    static let marketing = [
        "Digital Marketing", "Brand Strategy", "Content Creation", "Social Media",
        "SEO/SEM", "Email Marketing", "Influencer Marketing", "Marketing Analytics",
        "Creative Direction", "Public Relations", "Event Planning", "Customer Experience"
    ]
    
    static let consulting = [
        "Business Strategy", "Management Consulting", "Operations", "Change Management",
        "Process Improvement", "Organizational Design", "Performance Management",
        "Strategic Planning", "Market Research", "Competitive Analysis", "Digital Transformation"
    ]
    
    static let education = [
        "Educational Technology", "Curriculum Design", "Research Methods", "Student Engagement",
        "Online Learning", "Assessment", "Educational Policy", "Learning Analytics",
        "Academic Writing", "Grant Writing", "Peer Review", "Teaching Innovation"
    ]
    
    static let healthcare = [
        "Medical Research", "Healthcare Technology", "Drug Development", "Clinical Trials",
        "Medical Devices", "Healthcare Policy", "Telemedicine", "Mental Health",
        "Public Health", "Medical Ethics", "Healthcare Innovation", "Patient Care"
    ]
    
    static let manufacturing = [
        "Industrial Engineering", "Supply Chain", "Quality Control", "Lean Manufacturing",
        "Automation", "Sustainability", "Product Design", "Materials Science",
        "Process Engineering", "Safety Management", "Innovation", "Digital Manufacturing"
    ]
    
    static let ecommerce = [
        "E-commerce Strategy", "Digital Commerce", "Customer Experience", "Supply Chain",
        "Marketplace Management", "Conversion Optimization", "Mobile Commerce",
        "International Expansion", "Payment Systems", "Logistics", "Analytics", "Personalization"
    ]
    
    static let government = [
        "Public Policy", "Government Innovation", "Civic Technology", "Public Administration",
        "Regulatory Affairs", "Public Finance", "Urban Planning", "Environmental Policy",
        "Social Services", "Emergency Management", "Transparency", "Digital Government"
    ]
    
    static let arts = [
        "Creative Process", "Art Direction", "Graphic Design", "User Experience Design",
        "Photography", "Video Production", "Music", "Writing",
        "Theater", "Film", "Fashion", "Digital Art"
    ]
    
    static func topicsForIndustry(_ industry: IndustryOption) -> [String] {
        switch industry {
        case .technology: return technology
        case .finance: return finance
        case .marketing: return marketing
        case .consulting: return consulting
        case .education: return education
        case .healthcare: return healthcare
        case .manufacturing: return manufacturing
        case .ecommerce: return ecommerce
        case .government: return government
        case .arts: return arts
        }
    }
}

// MARK: - Values Options
struct ValuesOptions {
    static let allValues = [
        "Innovative", "Collaborative", "Creative", "Empathetic", "Authentic",
        "Growth-oriented", "Curious", "Passionate", "Resilient", "Optimistic",
        "Trustworthy", "Adaptable"
    ]
}


// MARK: - Hobbies & Interests Options
struct HobbiesOptions {
    // 精简为6个最大众的 hobby
    static let popularHobbies = [
        "Reading", "Music", "Sports", "Travel", "Cooking", "Photography"
    ]
    
    // 保留完整列表用于兼容（如果需要）
    static let allHobbies = [
        "Reading", "Writing", "Photography", "Cooking", "Traveling",
        "Hiking", "Running", "Yoga", "Music", "Painting",
        "Gaming", "Movies", "Volunteering", "Coffee", "Fitness"
    ]
}

// MARK: - Selection Helper
class SelectionHelper: ObservableObject {
    @Published var selectedTopics: Set<String> = []
    @Published var selectedValues: Set<String> = []
    @Published var selectedHobbies: Set<String> = []
    
    let maxSelections = 6
    
    func addTopic(_ topic: String) {
        if selectedTopics.count < maxSelections && !selectedTopics.contains(topic) {
            selectedTopics.insert(topic)
        }
    }
    
    func removeTopic(_ topic: String) {
        selectedTopics.remove(topic)
    }
    
    func addValue(_ value: String) {
        if selectedValues.count < maxSelections && !selectedValues.contains(value) {
            selectedValues.insert(value)
        }
    }
    
    func removeValue(_ value: String) {
        selectedValues.remove(value)
    }
    
    func addHobby(_ hobby: String) {
        if selectedHobbies.count < maxSelections && !selectedHobbies.contains(hobby) {
            selectedHobbies.insert(hobby)
        }
    }
    
    func removeHobby(_ hobby: String) {
        selectedHobbies.remove(hobby)
    }
}
