import Foundation

// MARK: - Education Models
struct Education: Codable, Identifiable, Equatable {
    let id: UUID
    let schoolName: String
    let startYear: Int
    let startMonth: Int? // 1-12, nil表示未设置
    let endYear: Int?
    let endMonth: Int? // 1-12, nil表示未设置
    let degree: DegreeType
    let fieldOfStudy: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case schoolName = "school_name"
        case startYear = "start_year"
        case startMonth = "start_month"
        case endYear = "end_year"
        case endMonth = "end_month"
        case degree
        case fieldOfStudy = "field_of_study"
    }
    
    init(schoolName: String, startYear: Int, startMonth: Int? = nil, endYear: Int? = nil, endMonth: Int? = nil, degree: DegreeType, fieldOfStudy: String? = nil) {
        self.id = UUID()
        self.schoolName = schoolName
        self.startYear = startYear
        self.startMonth = startMonth
        self.endYear = endYear
        self.endMonth = endMonth
        self.degree = degree
        self.fieldOfStudy = fieldOfStudy
    }
}

// MARK: - Degree Types
enum DegreeType: String, CaseIterable, Codable {
    case highSchool = "High School"
    case associate = "Associate"
    case bachelor = "Bachelor's"
    case master = "Master's"
    case phd = "Ph.D."
    case jd = "J.D."
    case llm = "LL.M."
    case mba = "MBA"
    case md = "M.D."
    case dds = "D.D.S."
    case dvm = "D.V.M."
    case pharmd = "Pharm.D."
    case dnp = "D.N.P."
    case edd = "Ed.D."
    case psyd = "Psy.D."
    case dba = "D.B.A."
    case other = "Other"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Work Experience
struct WorkExperience: Identifiable, Codable, Equatable {
    let id: UUID
    var companyName: String
    var startYear: Int
    var startMonth: Int? // 1-12, nil表示未设置
    var endYear: Int? // nil if currently working
    var endMonth: Int? // 1-12, nil表示未设置
    var position: String?
    var highlightedSkills: [String] = []
    var responsibilities: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case companyName = "company_name"
        case startYear = "start_year"
        case startMonth = "start_month"
        case endYear = "end_year"
        case endMonth = "end_month"
        case position
        case highlightedSkills = "highlighted_skills"
        case responsibilities
    }
    
    init(
        id: UUID = UUID(),
        companyName: String,
        startYear: Int,
        startMonth: Int? = nil,
        endYear: Int?,
        endMonth: Int? = nil,
        position: String?,
        highlightedSkills: [String] = [],
        responsibilities: String? = nil
    ) {
        self.id = id
        self.companyName = companyName
        self.startYear = startYear
        self.startMonth = startMonth
        self.endYear = endYear
        self.endMonth = endMonth
        self.position = position
        self.highlightedSkills = highlightedSkills
        self.responsibilities = responsibilities
    }
}

// MARK: - Year Options
struct YearOptions {
    static let currentYear = Calendar.current.component(.year, from: Date())
    static let currentMonth = Calendar.current.component(.month, from: Date())
    
    static let years: [Int] = {
        var years: [Int] = []
        let minYear = 1900
        let maxYear = currentYear + 5
        for year in minYear...maxYear {
            years.append(year)
        }
        return years.reversed()
    }()
    
    // Work experience years with extended range
    static let workExperienceYears: [Int] = {
        var years: [Int] = []
        let minYear = 1900
        let maxYear = currentYear + 50
        for year in minYear...maxYear {
            years.append(year)
        }
        return years.reversed()
    }()
    
    // Month options (1-12)
    static let months: [Int] = Array(1...12)
    
    // Years of experience options (0-40)
    static let yearsOfExperienceOptions: [Int] = Array(0...40)
    
    // Month names for display
    static let monthNames: [String] = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
    static func monthName(for month: Int) -> String {
        guard month >= 1 && month <= 12 else { return "" }
        return monthNames[month - 1]
    }
    
    static func shortMonthName(for month: Int) -> String {
        guard month >= 1 && month <= 12 else { return "" }
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return names[month - 1]
    }
}
