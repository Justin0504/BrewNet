import Foundation
import PDFKit
import UniformTypeIdentifiers

// MARK: - 简历解析结果
struct ParsedResume {
    var name: String?
    var email: String?
    var phone: String?
    var location: String?
    var linkedInUrl: String?
    var githubUrl: String?
    var personalWebsite: String?
    var bio: String?
    var currentCompany: String?
    var jobTitle: String?
    var skills: [String] = []
    var certifications: [String] = []
    var languages: [String] = []
    var educations: [Education] = []
    var workExperiences: [WorkExperience] = []
    var yearsOfExperience: Double?
}

// MARK: - 简历解析器
class ResumeParser {
    
    // MARK: - 主解析方法
    static func parseResume(from url: URL) async throws -> ParsedResume {
        let fileExtension = url.pathExtension.lowercased()
        
        var text: String = ""
        
        if fileExtension == "pdf" {
            text = try await extractTextFromPDF(url: url)
        } else if fileExtension == "docx" || fileExtension == "doc" {
            text = try await extractTextFromWord(url: url)
        } else {
            throw ResumeParseError.unsupportedFormat
        }
        
        return parseText(text)
    }
    
    // MARK: - PDF文本提取
    private static func extractTextFromPDF(url: URL) async throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ResumeParseError.cannotReadFile
        }
        
        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex) {
                if let pageText = page.string {
                    fullText += pageText + "\n"
                }
            }
        }
        
        return fullText
    }
    
    // MARK: - Word文档文本提取
    private static func extractTextFromWord(url: URL) async throws -> String {
        // 对于Word文档，我们尝试读取为纯文本
        // 注意：这只能提取纯文本，不能提取格式化的内容
        // 如果需要更好的Word支持，可以考虑使用第三方库
        
        guard let data = try? Data(contentsOf: url) else {
            throw ResumeParseError.cannotReadFile
        }
        
        // 尝试作为纯文本读取
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        
        // 尝试其他编码
        if let text = String(data: data, encoding: .ascii) {
            return text
        }
        
        // 对于.docx文件，这是一个ZIP文件，需要特殊处理
        // 这里简化处理，只提取可读的文本部分
        throw ResumeParseError.cannotReadFile
    }
    
    // MARK: - 文本解析
    private static func parseText(_ text: String) -> ParsedResume {
        var resume = ParsedResume()
        let lines = text.components(separatedBy: .newlines)
        
        // 提取姓名（通常在文档开头）
        resume.name = extractName(from: text, lines: lines)
        
        // 提取邮箱
        resume.email = extractEmail(from: text)
        
        // 提取电话
        resume.phone = extractPhone(from: text)
        
        // 提取位置
        resume.location = extractLocation(from: text, lines: lines)
        
        // 提取LinkedIn URL
        resume.linkedInUrl = extractLinkedInUrl(from: text)
        
        // 提取GitHub URL
        resume.githubUrl = extractGitHubUrl(from: text)
        
        // 提取个人网站
        resume.personalWebsite = extractPersonalWebsite(from: text)
        
        // 提取Bio/Summary
        resume.bio = extractBio(from: text, lines: lines)
        
        // 提取当前公司和职位
        let currentJob = extractCurrentJob(from: text, lines: lines)
        resume.currentCompany = currentJob.company
        resume.jobTitle = currentJob.title
        
        // 提取技能
        resume.skills = extractSkills(from: text, lines: lines)
        
        // 提取证书
        resume.certifications = extractCertifications(from: text, lines: lines)
        
        // 提取语言
        resume.languages = extractLanguages(from: text, lines: lines)
        
        // 提取教育经历
        resume.educations = extractEducations(from: text, lines: lines)
        
        // 提取工作经历
        resume.workExperiences = extractWorkExperiences(from: text, lines: lines)
        
        // 计算工作年限
        resume.yearsOfExperience = calculateYearsOfExperience(from: resume.workExperiences)
        
        return resume
    }
    
    // MARK: - 提取姓名
    private static func extractName(from text: String, lines: [String]) -> String? {
        // 通常姓名在文档的第一行或前几行
        for i in 0..<min(5, lines.count) {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if !line.isEmpty && line.count > 2 && line.count < 50 {
                // 检查是否包含常见的简历关键词（排除）
                let lowercased = line.lowercased()
                let excludeKeywords = ["resume", "cv", "curriculum", "vitae", "email", "phone", "address", "objective", "summary"]
                if !excludeKeywords.contains(where: { lowercased.contains($0) }) {
                    // 检查是否看起来像姓名（包含字母和可能的空格）
                    if line.range(of: "^[A-Za-z\\s'-]+$", options: .regularExpression) != nil {
                        return line
                    }
                }
            }
        }
        return nil
    }
    
    // MARK: - 提取邮箱
    private static func extractEmail(from text: String) -> String? {
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        if let regex = try? NSRegularExpression(pattern: emailPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
           let range = Range(match.range, in: text) {
            return String(text[range])
        }
        return nil
    }
    
    // MARK: - 提取电话
    private static func extractPhone(from text: String) -> String? {
        // 匹配各种电话格式
        let phonePatterns = [
            #"\+?1?[-.\s]?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})"#, // 美国格式
            #"\+?[0-9]{1,4}[-.\s]?[0-9]{1,4}[-.\s]?[0-9]{1,4}[-.\s]?[0-9]{1,9}"#, // 国际格式
            #"\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"# // 简单格式
        ]
        
        for pattern in phonePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               let range = Range(match.range, in: text) {
                let phone = String(text[range])
                // 验证电话号码长度（至少7位数字）
                let digits = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if digits.count >= 7 {
                    return phone
                }
            }
        }
        return nil
    }
    
    // MARK: - 提取位置
    private static func extractLocation(from text: String, lines: [String]) -> String? {
        let locationKeywords = ["location", "address", "city", "based in", "located in"]
        let lowercased = text.lowercased()
        
        for keyword in locationKeywords {
            if let range = lowercased.range(of: keyword) {
                let afterKeyword = String(text[range.upperBound...])
                let lines = afterKeyword.components(separatedBy: .newlines)
                if let firstLine = lines.first {
                    let location = firstLine.trimmingCharacters(in: .whitespaces)
                    if !location.isEmpty && location.count < 100 {
                        return location
                    }
                }
            }
        }
        
        // 尝试从常见格式中提取（如 "City, State" 或 "City, Country"）
        let locationPattern = #"[A-Z][a-z]+,\s*[A-Z][a-z]+"#
        if let regex = try? NSRegularExpression(pattern: locationPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
           let range = Range(match.range, in: text) {
            return String(text[range])
        }
        
        return nil
    }
    
    // MARK: - 提取LinkedIn URL
    private static func extractLinkedInUrl(from text: String) -> String? {
        let patterns = [
            #"linkedin\.com/in/[a-zA-Z0-9-]+"#,
            #"linkedin\.com/profile/view\?id=[a-zA-Z0-9-]+"#,
            #"www\.linkedin\.com/in/[a-zA-Z0-9-]+"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               let range = Range(match.range, in: text) {
                var url = String(text[range])
                if !url.hasPrefix("http") {
                    url = "https://" + url
                }
                return url
            }
        }
        return nil
    }
    
    // MARK: - 提取GitHub URL
    private static func extractGitHubUrl(from text: String) -> String? {
        let patterns = [
            #"github\.com/[a-zA-Z0-9-]+"#,
            #"www\.github\.com/[a-zA-Z0-9-]+"#,
            #"github\.io/[a-zA-Z0-9-]+"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               let range = Range(match.range, in: text) {
                var url = String(text[range])
                if !url.hasPrefix("http") {
                    url = "https://" + url
                }
                return url
            }
        }
        return nil
    }
    
    // MARK: - 提取个人网站
    private static func extractPersonalWebsite(from text: String) -> String? {
        let websitePattern = #"https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?"#
        if let regex = try? NSRegularExpression(pattern: websitePattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
           let range = Range(match.range, in: text) {
            let url = String(text[range])
            // 排除LinkedIn和GitHub（已经单独提取）
            if !url.contains("linkedin") && !url.contains("github") {
                return url
            }
        }
        return nil
    }
    
    // MARK: - 提取Bio/Summary
    private static func extractBio(from text: String, lines: [String]) -> String? {
        let bioKeywords = ["summary", "objective", "profile", "about", "introduction", "overview"]
        let lowercased = text.lowercased()
        
        for keyword in bioKeywords {
            if let range = lowercased.range(of: keyword) {
                let afterKeyword = String(text[range.upperBound...])
                // 提取接下来的2-3行作为bio
                let lines = afterKeyword.components(separatedBy: .newlines)
                var bioLines: [String] = []
                for line in lines.prefix(3) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && trimmed.count > 10 {
                        bioLines.append(trimmed)
                    }
                }
                if !bioLines.isEmpty {
                    return bioLines.joined(separator: " ")
                }
            }
        }
        return nil
    }
    
    // MARK: - Extract Current Job
    private static func extractCurrentJob(from text: String, lines: [String]) -> (company: String?, title: String?) {
        let experienceKeywords = ["experience", "employment", "work history", "professional experience", "work experience"]
        let lowercased = text.lowercased()
        
        // Common job title keywords
        let jobTitleKeywords = [
            "engineer", "developer", "programmer", "analyst", "manager", "director", "lead", "senior", "junior",
            "architect", "designer", "consultant", "specialist", "coordinator", "assistant", "executive",
            "officer", "administrator", "supervisor", "technician", "scientist", "researcher", "intern",
            "internship", "student", "professor", "teacher", "instructor", "tutor", "counselor",
            "therapist", "nurse", "doctor", "physician", "dentist", "veterinarian", "lawyer", "attorney",
            "accountant", "auditor", "financial", "banker", "broker", "trader", "advisor", "planner",
            "marketing", "sales", "representative", "agent", "recruiter", "hr", "human resources",
            "product", "project", "program", "operations", "supply chain", "logistics", "quality",
            "business", "strategy", "consulting", "investment", "venture", "entrepreneur", "founder",
            "ceo", "cto", "cfo", "coo", "president", "vice president", "vp", "chief"
        ]
        
        var company: String? = nil
        var title: String? = nil
        
        // Find experience section
        for keyword in experienceKeywords {
            if let range = lowercased.range(of: keyword) {
                let afterKeyword = String(text[range.upperBound...])
                let lines = afterKeyword.components(separatedBy: .newlines)
                
                // Find first job (usually current job)
                var lineIndex = 0
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        // Skip lines that are just dates
                        let datePattern = #"^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4}"#
                        if trimmed.range(of: datePattern, options: [.regularExpression, .caseInsensitive]) != nil && trimmed.count < 20 {
                            lineIndex += 1
                            continue
                        }
                        
                        // Try to extract title and company
                        // Common formats: "Software Engineer at Company Name" or "Company Name - Software Engineer"
                        if let atRange = trimmed.range(of: " at ", options: .caseInsensitive) {
                            let potentialTitle = String(trimmed[..<atRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                            let potentialCompany = String(trimmed[atRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                            
                            // Check if potential title contains job keywords
                            let lowerTitle = potentialTitle.lowercased()
                            if jobTitleKeywords.contains(where: { lowerTitle.contains($0) }) {
                                title = potentialTitle
                                company = potentialCompany
                                break
                            }
                        } else if let dashRange = trimmed.range(of: " - ") {
                            let potentialCompany = String(trimmed[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                            let potentialTitle = String(trimmed[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                            
                            let lowerTitle = potentialTitle.lowercased()
                            if jobTitleKeywords.contains(where: { lowerTitle.contains($0) }) {
                                company = potentialCompany
                                title = potentialTitle
                                break
                            }
                        } else if lineIndex < 5 {
                            // Check if line contains job title keywords
                            let lowerTrimmed = trimmed.lowercased()
                            if jobTitleKeywords.contains(where: { lowerTrimmed.contains($0) }) && trimmed.count < 80 {
                                if title == nil {
                                    title = trimmed
                                }
                            } else if title != nil && company == nil && trimmed.count < 80 && !trimmed.contains("@") {
                                // If we already have a title, next non-email line might be company
                                company = trimmed
                            }
                        }
                    }
                    lineIndex += 1
                }
                break
            }
        }
        
        // If we didn't find title in experience section, try to find it near the top
        if title == nil {
            for (_, line) in lines.prefix(10).enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let lowerTrimmed = trimmed.lowercased()
                    if jobTitleKeywords.contains(where: { lowerTrimmed.contains($0) }) && trimmed.count < 80 {
                        title = trimmed
                        break
                    }
                }
            }
        }
        
        return (company: company, title: title)
    }
    
    // MARK: - 提取技能
    private static func extractSkills(from text: String, lines: [String]) -> [String] {
        var skills: [String] = []
        let skillKeywords = ["skills", "technical skills", "competencies", "expertise", "proficiencies"]
        let lowercased = text.lowercased()
        
        for keyword in skillKeywords {
            if let range = lowercased.range(of: keyword) {
                let afterKeyword = String(text[range.upperBound...])
                let lines = afterKeyword.components(separatedBy: .newlines)
                
                // 提取接下来的5-10行作为技能
                for line in lines.prefix(10) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        // 按常见分隔符分割技能
                        let separators = [",", ";", "|", "•", "-", "·"]
                        let skillLine = trimmed
                        for separator in separators {
                            if skillLine.contains(separator) {
                                let parts = skillLine.components(separatedBy: separator)
                                for part in parts {
                                    let skill = part.trimmingCharacters(in: .whitespaces)
                                    if !skill.isEmpty && skill.count < 50 {
                                        skills.append(skill)
                                    }
                                }
                                break
                            }
                        }
                        
                        // 如果没有分隔符，整行作为一个技能
                        if !separators.contains(where: { trimmed.contains($0) }) && trimmed.count < 50 {
                            skills.append(trimmed)
                        }
                    }
                }
                break
            }
        }
        
        // 去重并限制数量
        return Array(Set(skills)).prefix(20).map { $0 }
    }
    
    // MARK: - 提取证书
    private static func extractCertifications(from text: String, lines: [String]) -> [String] {
        var certifications: [String] = []
        let certKeywords = ["certifications", "certificates", "credentials", "licenses"]
        let lowercased = text.lowercased()
        
        for keyword in certKeywords {
            if let range = lowercased.range(of: keyword) {
                let afterKeyword = String(text[range.upperBound...])
                let lines = afterKeyword.components(separatedBy: .newlines)
                
                for line in lines.prefix(10) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && trimmed.count < 100 {
                        certifications.append(trimmed)
                    }
                }
                break
            }
        }
        
        return Array(Set(certifications)).prefix(10).map { $0 }
    }
    
    // MARK: - 提取语言
    private static func extractLanguages(from text: String, lines: [String]) -> [String] {
        var languages: [String] = []
        let langKeywords = ["languages", "language proficiency", "spoken languages"]
        let lowercased = text.lowercased()
        
        let commonLanguages = ["english", "chinese", "spanish", "french", "german", "japanese", "korean", "portuguese", "italian", "russian", "arabic", "hindi"]
        
        for keyword in langKeywords {
            if let range = lowercased.range(of: keyword) {
                let afterKeyword = String(text[range.upperBound...])
                let lines = afterKeyword.components(separatedBy: .newlines)
                
                for line in lines.prefix(5) {
                    let trimmed = line.lowercased().trimmingCharacters(in: .whitespaces)
                    for lang in commonLanguages {
                        if trimmed.contains(lang) {
                            languages.append(lang.capitalized)
                        }
                    }
                }
                break
            }
        }
        
        return Array(Set(languages))
    }
    
    // MARK: - Extract School Name and Field of Study
    private static func extractSchoolNameAndField(from line: String, hasDegree: Bool) -> (schoolName: String, fieldOfStudy: String?) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let lowerTrimmed = trimmed.lowercased()
        
        // Common separators that indicate end of school name or start of additional info
        let separators = ["|", "•", "GPA:", "gpa:", "Location:", "location:", "Courses:", "courses:", "Relative Courses:", "relative courses:"]
        
        var schoolName = trimmed
        var fieldOfStudy: String? = nil
        
        // First, try to extract field of study from patterns like "Bachelor of X" or "Master of X"
        let degreePatterns = [
            #"Bachelor\s+of\s+([^|•GPA:]+?)(?:\s*\||\s*•|\s*GPA:|\s*Location:|\s*Courses:|\s*$)"#,
            #"Master\s+of\s+([^|•GPA:]+?)(?:\s*\||\s*•|\s*GPA:|\s*Location:|\s*Courses:|\s*$)"#,
            #"Bachelor\s+in\s+([^|•GPA:]+?)(?:\s*\||\s*•|\s*GPA:|\s*Location:|\s*Courses:|\s*$)"#,
            #"Master\s+in\s+([^|•GPA:]+?)(?:\s*\||\s*•|\s*GPA:|\s*Location:|\s*Courses:|\s*$)"#,
            #"Ph\.?D\.?\s+in\s+([^|•GPA:]+?)(?:\s*\||\s*•|\s*GPA:|\s*Location:|\s*Courses:|\s*$)"#,
            #"Doctorate\s+in\s+([^|•GPA:]+?)(?:\s*\||\s*•|\s*GPA:|\s*Location:|\s*Courses:|\s*$)"#
        ]
        
        for pattern in degreePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count))
                if let match = matches.first, match.numberOfRanges > 1 {
                    if let range = Range(match.range(at: 1), in: trimmed) {
                        var field = String(trimmed[range]).trimmingCharacters(in: .whitespaces)
                        // Remove any remaining separators
                        for separator in separators {
                            if let sepRange = field.lowercased().range(of: separator) {
                                field = String(field[..<sepRange.lowerBound])
                            }
                        }
                        field = field.trimmingCharacters(in: .whitespaces)
                        // Remove location patterns (city, state, country)
                        let locationPattern = #",\s*[A-Z][a-z]+,\s*[A-Z][a-z]+.*$"#
                        field = field.replacingOccurrences(of: locationPattern, with: "", options: .regularExpression)
                        field = field.trimmingCharacters(in: .whitespaces)
                        if !field.isEmpty && field.count < 100 {
                            fieldOfStudy = field
                            break
                        }
                    }
                }
            }
        }
        
        // Extract school name - find where school name ends (before degree, field, or separators)
        // School name typically ends before "Bachelor of", "Master of", or separators
        var schoolNameEndIndex: String.Index? = nil
        
        // Check for degree patterns that indicate end of school name
        let degreeStartPatterns = [
            #"\bBachelor\s+(?:of|in)\b"#,
            #"\bMaster\s+(?:of|in)\b"#,
            #"\bPh\.?D\.?\s+in\b"#,
            #"\bDoctorate\s+in\b"#
        ]
        
        for pattern in degreeStartPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)),
                   let range = Range(match.range, in: trimmed) {
                    if schoolNameEndIndex == nil || range.lowerBound < schoolNameEndIndex! {
                        schoolNameEndIndex = range.lowerBound
                    }
                }
            }
        }
        
        // Also check for separators
        for separator in separators {
            if let range = lowerTrimmed.range(of: separator) {
                if schoolNameEndIndex == nil || range.lowerBound < schoolNameEndIndex! {
                    schoolNameEndIndex = range.lowerBound
                }
            }
        }
        
        // Extract school name
        if let endIndex = schoolNameEndIndex {
            schoolName = String(trimmed[..<endIndex]).trimmingCharacters(in: .whitespaces)
        }
        
        // Clean up school name - remove any trailing degree keywords
        let schoolLower = schoolName.lowercased()
        for degree in DegreeType.allCases {
            let degreeLower = degree.rawValue.lowercased()
            if schoolLower.hasSuffix(" \(degreeLower)") {
                schoolName = String(schoolName.dropLast(degreeLower.count + 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Remove any remaining separators from school name
        for separator in separators {
            if let sepRange = schoolName.lowercased().range(of: separator) {
                schoolName = String(schoolName[..<sepRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Remove location patterns from school name (e.g., "Ann Arbor, Michigan, United States")
        let locationPattern = #",\s*[A-Z][a-z]+(?:,\s*[A-Z][a-z]+)*.*$"#
        schoolName = schoolName.replacingOccurrences(of: locationPattern, with: "", options: .regularExpression)
        schoolName = schoolName.trimmingCharacters(in: .whitespaces)
        
        return (schoolName: schoolName, fieldOfStudy: fieldOfStudy)
    }
    
    // MARK: - Extract Education
    private static func extractEducations(from text: String, lines: [String]) -> [Education] {
        var educations: [Education] = []
        
        // Expanded education keywords
        let eduKeywords = [
            "education", "academic", "academic background", "academic qualifications",
            "university", "college", "school", "institute", "institution",
            "bachelor", "master", "phd", "doctorate", "degree", "diploma",
            "undergraduate", "graduate", "postgraduate", "doctoral"
        ]
        
        let schoolKeywords = [
            "university", "college", "school", "institute", "institution",
            "academy", "polytechnic", "tech", "technical", "state", "national",
            "private", "public", "community college", "high school"
        ]
        
        // Common location patterns that should be excluded
        let locationPatterns = [
            "united states", "usa", "u.s.a", "california", "new york", "texas",
            "florida", "illinois", "pennsylvania", "ohio", "georgia", "north carolina",
            "michigan", "new jersey", "virginia", "washington", "arizona", "massachusetts",
            "tennessee", "indiana", "missouri", "maryland", "wisconsin", "colorado",
            "minnesota", "south carolina", "alabama", "louisiana", "kentucky", "oregon",
            "oklahoma", "connecticut", "utah", "iowa", "nevada", "arkansas",
            "mississippi", "kansas", "new mexico", "nebraska", "west virginia", "idaho",
            "hawaii", "new hampshire", "maine", "montana", "rhode island", "delaware",
            "south dakota", "north dakota", "alaska", "vermont", "wyoming", "district of columbia"
        ]
        
        // Common company indicators (should be excluded)
        let companyIndicators = ["inc", "llc", "corp", "corporation", "ltd", "limited", "company", "co.", "co ", "technologies", "tech", "systems", "solutions", "services", "group", "holdings"]
        
        let lowercased = text.lowercased()
        
        // Try to find education section
        var educationSectionStart: Int? = nil
        for keyword in eduKeywords {
            if lowercased.range(of: keyword) != nil {
                if let index = lines.firstIndex(where: { $0.lowercased().contains(keyword) }) {
                    educationSectionStart = index
                    break
                }
            }
        }
        
        // If no explicit section, search entire document
        let searchStart = educationSectionStart ?? 0
        let searchLines = Array(lines[searchStart..<min(searchStart + 30, lines.count)])
        
        var currentSchool: String? = nil
        var currentDegree: DegreeType? = nil
        var currentField: String? = nil
        var startYear: Int? = nil
        var endYear: Int? = nil
        var years: [Int] = []
        
        for line in searchLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            let lowerTrimmed = trimmed.lowercased()
            
            // Extract all years from the line
            let yearPattern = #"\b(19|20)\d{2}\b"#
            if let regex = try? NSRegularExpression(pattern: yearPattern, options: []) {
                let matches = regex.matches(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count))
                for match in matches {
                    if let range = Range(match.range, in: trimmed),
                       let year = Int(String(trimmed[range])) {
                        years.append(year)
                    }
                }
            }
            
            // Check if line contains school keywords (strict check - must be actual school keywords)
            let containsSchoolKeyword = schoolKeywords.contains { lowerTrimmed.contains($0) }
            
            // Check if current line has degree keyword
            var foundDegree: DegreeType? = nil
            for degree in DegreeType.allCases {
                let degreeLower = degree.rawValue.lowercased()
                let degreeWithoutApostrophe = degree.rawValue.replacingOccurrences(of: "'s", with: "").lowercased()
                if lowerTrimmed.contains(degreeLower) || lowerTrimmed.contains(degreeWithoutApostrophe) {
                    foundDegree = degree
                    break
                }
            }
            
            // Check if line is just a location (like "United States", "California", etc.)
            let isJustLocation = locationPatterns.contains { lowerTrimmed == $0 || lowerTrimmed.hasSuffix(", \($0)") || lowerTrimmed.hasSuffix(" \($0)") }
            
            // Check if line contains common company indicators (should be excluded)
            let containsCompanyIndicator = companyIndicators.contains { lowerTrimmed.contains($0) }
            
            // Only start new education entry if:
            // 1. It contains school keyword AND degree keyword (most strict), OR
            // 2. It contains school keyword AND we're in education section AND it's not just a location/company
            let hasDegreeInLine = foundDegree != nil
            let shouldStartNewEntry = (containsSchoolKeyword && hasDegreeInLine) || 
                                     (containsSchoolKeyword && educationSectionStart != nil && !isJustLocation && !containsCompanyIndicator)
            
            if shouldStartNewEntry {
                // If we have accumulated data, save previous education (only if it has school keyword or degree)
                if let school = currentSchool, let start = startYear {
                    let schoolLower = school.lowercased()
                    let hasSchoolKeyword = schoolKeywords.contains { schoolLower.contains($0) }
                    let hasDegree = currentDegree != nil
                    
                    // Only save if it has school keyword OR degree - strict validation
                    if hasSchoolKeyword || hasDegree {
                        // Clean up school name to ensure it's clean
                        let (cleanedSchoolName, _) = extractSchoolNameAndField(from: school, hasDegree: hasDegree)
                        let degree = currentDegree ?? .bachelor
                        let education = Education(
                            schoolName: cleanedSchoolName,
                            startYear: start,
                            startMonth: nil,
                            endYear: endYear,
                            endMonth: nil,
                            degree: degree,
                            fieldOfStudy: currentField
                        )
                        educations.append(education)
                    }
                }
                
                // Start new education entry only if it meets strict criteria
                // This ensures we don't start entries for company names or locations
                if (containsSchoolKeyword && hasDegreeInLine) || 
                   (containsSchoolKeyword && educationSectionStart != nil && !isJustLocation && !containsCompanyIndicator) {
                    // Extract school name and field of study from the line
                    let (schoolName, fieldOfStudy) = extractSchoolNameAndField(from: trimmed, hasDegree: hasDegreeInLine)
                    currentSchool = schoolName
                    currentDegree = foundDegree ?? currentDegree  // Keep previous degree if not found in this line
                    currentField = fieldOfStudy ?? currentField  // Keep previous field if not found in this line
                    startYear = nil
                    endYear = nil
                    
                    // Use years from this line
                    if years.count >= 1 {
                        startYear = years[0]
                        if years.count >= 2 {
                            endYear = years[1]
                        }
                    }
                }
                years = []
            } else if currentSchool != nil {
                // We're in an education entry, look for more info
                if years.count >= 1 && startYear == nil {
                    startYear = years[0]
                    if years.count >= 2 {
                        endYear = years[1]
                    }
                } else if years.count >= 1 && endYear == nil {
                    endYear = years[0]
                }
                
                // Check for field of study in subsequent lines
                if currentField == nil {
                    let (_, extractedField) = extractSchoolNameAndField(from: trimmed, hasDegree: false)
                    if let field = extractedField {
                        currentField = field
                    } else if lowerTrimmed.contains(" in ") || lowerTrimmed.contains(" of ") || 
                             lowerTrimmed.contains("major") || lowerTrimmed.contains("concentration") {
                        // Extract field of study
                        if let inRange = lowerTrimmed.range(of: " in ") {
                            let afterIn = String(trimmed[inRange.upperBound...])
                            // Split by common separators
                            let separators = [",", "•", "\n", "|"]
                            var fieldParts = [afterIn]
                            for separator in separators {
                                fieldParts = fieldParts.flatMap { $0.components(separatedBy: separator) }
                            }
                            if let firstPart = fieldParts.first {
                                let cleaned = firstPart.trimmingCharacters(in: .whitespaces)
                                // Remove GPA, location, and other non-field info
                                let gpaPattern = #"GPA:\s*\d+\.?\d*/?\d*"#
                                let cleanedField = cleaned.replacingOccurrences(of: gpaPattern, with: "", options: .regularExpression)
                                    .trimmingCharacters(in: .whitespaces)
                                if !cleanedField.isEmpty && cleanedField.count < 100 {
                                    currentField = cleanedField
                                }
                            }
                        }
                    }
                }
                
                years = []
            }
        }
        
        // Save last education entry (only if it has school keyword AND degree, or school keyword in education section)
        if let school = currentSchool, let start = startYear {
            let schoolLower = school.lowercased()
            let hasSchoolKeyword = schoolKeywords.contains { schoolLower.contains($0) }
            let hasDegree = currentDegree != nil
            
            // Check if it's just a location or company name
            let isJustLocation = locationPatterns.contains { schoolLower == $0 || schoolLower.hasSuffix(", \($0)") || schoolLower.hasSuffix(" \($0)") }
            let containsCompanyIndicator = companyIndicators.contains { schoolLower.contains($0) }
            
            // Only save if:
            // 1. It has school keyword AND degree (most strict), OR
            // 2. It has school keyword AND we're in education section AND it's not just a location/company
            if (hasSchoolKeyword && hasDegree) || 
               (hasSchoolKeyword && educationSectionStart != nil && !isJustLocation && !containsCompanyIndicator) {
                // Clean up school name one more time to ensure it's clean
                let (cleanedSchoolName, _) = extractSchoolNameAndField(from: school, hasDegree: hasDegree)
                let degree = currentDegree ?? .bachelor
                let education = Education(
                    schoolName: cleanedSchoolName,
                    startYear: start,
                    startMonth: nil,
                    endYear: endYear,
                    endMonth: nil,
                    degree: degree,
                    fieldOfStudy: currentField
                )
                educations.append(education)
            }
        }
        
        return educations
    }
    
    // MARK: - Extract Work Experiences
    private static func extractWorkExperiences(from text: String, lines: [String]) -> [WorkExperience] {
        var experiences: [WorkExperience] = []
        let expKeywords = ["experience", "employment", "work history", "professional experience", "work experience"]
        let lowercased = text.lowercased()
        
        for keyword in expKeywords {
            if let range = lowercased.range(of: keyword) {
                let afterKeyword = String(text[range.upperBound...])
                let lines = afterKeyword.components(separatedBy: .newlines)
                
                var currentCompany: String? = nil
                var currentPosition: String? = nil
                var startYear: Int? = nil
                var endYear: Int? = nil
                var isCurrent = false
                var years: [Int] = []
                
                for line in lines.prefix(40) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { continue }
                    
                    let lowerTrimmed = trimmed.lowercased()
                    
                    // Check if it's current work
                    if lowerTrimmed.contains("present") || lowerTrimmed.contains("current") || lowerTrimmed.contains("now") {
                        isCurrent = true
                    }
                    
                    // Extract all years from the line
                    let yearPattern = #"\b(19|20)\d{2}\b"#
                    if let regex = try? NSRegularExpression(pattern: yearPattern, options: []) {
                        let matches = regex.matches(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count))
                        years = []
                        for match in matches {
                            if let range = Range(match.range, in: trimmed),
                               let year = Int(String(trimmed[range])) {
                                years.append(year)
                            }
                        }
                    }
                    
                    // If we found years, use them
                    if years.count >= 1 {
                        if startYear == nil {
                            startYear = years[0]
                            if years.count >= 2 && !isCurrent {
                                endYear = years[1]
                            }
                        } else if endYear == nil && !isCurrent {
                            endYear = years[0]
                        }
                    }
                    
                    // Extract company and position
                    if let atRange = trimmed.range(of: " at ", options: .caseInsensitive) {
                        let potentialPosition = String(trimmed[..<atRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                        let potentialCompany = String(trimmed[atRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                        
                        // Skip if it's just a date
                        let isDatePattern = potentialPosition.range(of: #"^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)"#, options: [.regularExpression, .caseInsensitive]) != nil
                        if !isDatePattern {
                            currentPosition = potentialPosition
                            currentCompany = potentialCompany
                        }
                    } else if let dashRange = trimmed.range(of: " - ") {
                        let potentialCompany = String(trimmed[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                        let potentialPosition = String(trimmed[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                        
                        let isCompanyDatePattern = potentialCompany.range(of: #"^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)"#, options: [.regularExpression, .caseInsensitive]) != nil
                        if !isCompanyDatePattern {
                            currentCompany = potentialCompany
                            currentPosition = potentialPosition
                        }
                    } else if currentCompany == nil && trimmed.count < 80 && !trimmed.contains("@") {
                        // Skip lines that are just dates
                        let dateOnlyPattern = #"^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4}"#
                        let isDateOnly = trimmed.range(of: dateOnlyPattern, options: [.regularExpression, .caseInsensitive]) != nil
                        if !isDateOnly {
                            currentCompany = trimmed
                        }
                    }
                    
                    // If we have enough info, create WorkExperience
                    if let company = currentCompany, let start = startYear, company.count > 2 {
                        let experience = WorkExperience(
                            companyName: company,
                            startYear: start,
                            startMonth: nil,
                            endYear: isCurrent ? nil : endYear,
                            endMonth: nil,
                            position: currentPosition,
                            highlightedSkills: [],
                            responsibilities: nil
                        )
                        experiences.append(experience)
                        
                        // Reset for next entry
                        currentCompany = nil
                        currentPosition = nil
                        startYear = nil
                        endYear = nil
                        isCurrent = false
                    }
                }
                break
            }
        }
        
        return experiences
    }
    
    // MARK: - 计算工作年限
    private static func calculateYearsOfExperience(from experiences: [WorkExperience]) -> Double? {
        guard !experiences.isEmpty else { return nil }
        
        var totalMonths = 0
        let calendar = Calendar.current
        let currentDate = Date()
        
        for exp in experiences {
            let startDate = DateComponents(year: exp.startYear, month: exp.startMonth ?? 1, day: 1)
            let start = calendar.date(from: startDate) ?? currentDate
            
            let endDate: Date
            if let endYear = exp.endYear {
                let endComponents = DateComponents(year: endYear, month: exp.endMonth ?? 12, day: 31)
                endDate = calendar.date(from: endComponents) ?? currentDate
            } else {
                endDate = currentDate
            }
            
            let months = calendar.dateComponents([.month], from: start, to: endDate).month ?? 0
            totalMonths += months
        }
        
        return Double(totalMonths) / 12.0
    }
}

// MARK: - 错误类型
enum ResumeParseError: LocalizedError {
    case unsupportedFormat
    case cannotReadFile
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported document format. Please upload a PDF or Word document."
        case .cannotReadFile:
            return "Cannot read file. Please ensure the file format is correct."
        case .parsingFailed:
            return "Failed to parse resume. Please check the file content."
        }
    }
}

