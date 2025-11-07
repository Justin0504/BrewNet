import Foundation

// MARK: - Education Models
struct Education: Codable, Identifiable, Equatable {
    let id: UUID
    let schoolName: String
    let startYear: Int
    let endYear: Int?
    let degree: DegreeType
    let fieldOfStudy: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case schoolName = "school_name"
        case startYear = "start_year"
        case endYear = "end_year"
        case degree
        case fieldOfStudy = "field_of_study"
    }
    
    init(schoolName: String, startYear: Int, endYear: Int? = nil, degree: DegreeType, fieldOfStudy: String? = nil) {
        self.id = UUID()
        self.schoolName = schoolName
        self.startYear = startYear
        self.endYear = endYear
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
    var endYear: Int? // nil if currently working
    var position: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case companyName = "company_name"
        case startYear = "start_year"
        case endYear = "end_year"
        case position
    }
    
    init(id: UUID = UUID(), companyName: String, startYear: Int, endYear: Int?, position: String?) {
        self.id = id
        self.companyName = companyName
        self.startYear = startYear
        self.endYear = endYear
        self.position = position
    }
}

// MARK: - Year Options
struct YearOptions {
    static let currentYear = Calendar.current.component(.year, from: Date())
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
}
