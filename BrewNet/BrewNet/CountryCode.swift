import Foundation

enum CountryCode: CaseIterable {
    case china
    case usa
    case canada
    case uk
    case japan
    case korea
    case singapore
    case australia
    case germany
    case france
    case india
    case brazil
    case russia
    case mexico
    case italy
    case spain
    case netherlands
    case sweden
    case norway
    case denmark
    case finland
    case switzerland
    case austria
    case belgium
    case portugal
    case ireland
    case newZealand
    case southAfrica
    case argentina
    case chile
    case colombia
    case peru
    case thailand
    case vietnam
    case indonesia
    case malaysia
    case philippines
    case taiwan
    case hongKong
    case israel
    case turkey
    case egypt
    
    var code: String {
        switch self {
        case .china: return "+86"
        case .usa: return "+1"
        case .canada: return "+1"
        case .uk: return "+44"
        case .japan: return "+81"
        case .korea: return "+82"
        case .singapore: return "+65"
        case .australia: return "+61"
        case .germany: return "+49"
        case .france: return "+33"
        case .india: return "+91"
        case .brazil: return "+55"
        case .russia: return "+7"
        case .mexico: return "+52"
        case .italy: return "+39"
        case .spain: return "+34"
        case .netherlands: return "+31"
        case .sweden: return "+46"
        case .norway: return "+47"
        case .denmark: return "+45"
        case .finland: return "+358"
        case .switzerland: return "+41"
        case .austria: return "+43"
        case .belgium: return "+32"
        case .portugal: return "+351"
        case .ireland: return "+353"
        case .newZealand: return "+64"
        case .southAfrica: return "+27"
        case .argentina: return "+54"
        case .chile: return "+56"
        case .colombia: return "+57"
        case .peru: return "+51"
        case .thailand: return "+66"
        case .vietnam: return "+84"
        case .indonesia: return "+62"
        case .malaysia: return "+60"
        case .philippines: return "+63"
        case .taiwan: return "+886"
        case .hongKong: return "+852"
        case .israel: return "+972"
        case .turkey: return "+90"
        case .egypt: return "+20"
        }
    }
    
    var displayName: String {
        switch self {
        case .china: return "+86 China"
        case .usa: return "+1 U.S"
        case .canada: return "+1 Canada"
        case .uk: return "+44 UK"
        case .japan: return "+81 Japan"
        case .korea: return "+82 Korea"
        case .singapore: return "+65 Singapore"
        case .australia: return "+61 Australia"
        case .germany: return "+49 Germany"
        case .france: return "+33 France"
        case .india: return "+91 India"
        case .brazil: return "+55 Brazil"
        case .russia: return "+7 Russia"
        case .mexico: return "+52 Mexico"
        case .italy: return "+39 Italy"
        case .spain: return "+34 Spain"
        case .netherlands: return "+31 Netherlands"
        case .sweden: return "+46 Sweden"
        case .norway: return "+47 Norway"
        case .denmark: return "+45 Denmark"
        case .finland: return "+358 Finland"
        case .switzerland: return "+41 Switzerland"
        case .austria: return "+43 Austria"
        case .belgium: return "+32 Belgium"
        case .portugal: return "+351 Portugal"
        case .ireland: return "+353 Ireland"
        case .newZealand: return "+64 New Zealand"
        case .southAfrica: return "+27 South Africa"
        case .argentina: return "+54 Argentina"
        case .chile: return "+56 Chile"
        case .colombia: return "+57 Colombia"
        case .peru: return "+51 Peru"
        case .thailand: return "+66 Thailand"
        case .vietnam: return "+84 Vietnam"
        case .indonesia: return "+62 Indonesia"
        case .malaysia: return "+60 Malaysia"
        case .philippines: return "+63 Philippines"
        case .taiwan: return "+886 Taiwan"
        case .hongKong: return "+852 Hong Kong"
        case .israel: return "+972 Israel"
        case .turkey: return "+90 Turkey"
        case .egypt: return "+20 Egypt"
        }
    }
    
    var phoneNumberLength: Int {
        switch self {
        case .china: return 11
        case .usa, .canada: return 10
        case .uk: return 11
        case .japan: return 11
        case .korea: return 11
        case .singapore: return 8
        case .australia: return 9
        case .germany: return 11
        case .france: return 10
        case .india: return 10
        case .brazil: return 11
        case .russia: return 10
        case .mexico: return 10
        case .italy: return 10
        case .spain: return 9
        case .netherlands: return 9
        case .sweden: return 9
        case .norway: return 8
        case .denmark: return 8
        case .finland: return 9
        case .switzerland: return 9
        case .austria: return 10
        case .belgium: return 9
        case .portugal: return 9
        case .ireland: return 9
        case .newZealand: return 8
        case .southAfrica: return 9
        case .argentina: return 10
        case .chile: return 9
        case .colombia: return 10
        case .peru: return 9
        case .thailand: return 9
        case .vietnam: return 9
        case .indonesia: return 10
        case .malaysia: return 9
        case .philippines: return 10
        case .taiwan: return 9
        case .hongKong: return 8
        case .israel: return 9
        case .turkey: return 10
        case .egypt: return 10
        }
    }
}

