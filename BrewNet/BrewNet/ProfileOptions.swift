import Foundation

// MARK: - Industry Options
enum IndustryOption: String, CaseIterable, Codable {
    case technology = "Technology (Software, Data, AI, IT)"
    case finance = "Finance (Banking, Investment, FinTech)"
    case marketing = "Marketing & Media (Advertising, PR, Content)"
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
        "Innovative", "Principled", "Collaborative", "Excellent", "Creative",
        "Leadership-oriented", "Empathetic", "Resilient", "Authentic", "Growth-oriented",
        "Service-oriented", "Curious", "Passionate", "Humble", "Courageous",
        "Trustworthy", "Transparent", "Diverse", "Inclusive", "Sustainable",
        "Accountable", "Adaptable", "Optimistic", "Persistent", "Wise"
    ]
}

// MARK: - Hobbies & Interests Options
struct HobbiesOptions {
    static let allHobbies = [
        "Reading", "Writing", "Photography", "Cooking", "Traveling",
        "Hiking", "Swimming", "Running", "Cycling", "Yoga",
        "Music", "Dancing", "Painting", "Drawing", "Gardening",
        "Gaming", "Movies", "Theater", "Museums", "Volunteering",
        "Chess", "Board Games", "Coffee", "Wine Tasting",
        "Fitness", "Podcasts", "Blogging"
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
