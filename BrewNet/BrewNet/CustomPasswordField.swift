import SwiftUI

// MARK: - Custom Password Field
struct CustomPasswordField: View {
    @Binding var text: String
    let placeholder: String
    @State private var isSecure: Bool = true
    
    var body: some View {
        HStack {
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textContentType(.none)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } else {
                    TextField(placeholder, text: $text)
                        .textContentType(.none)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .font(.system(size: 16))
            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Button(action: {
                isSecure.toggle()
            }) {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview
struct CustomPasswordField_Previews: PreviewProvider {
    @State static var password = ""
    
    static var previews: some View {
        VStack(spacing: 20) {
            CustomPasswordField(text: $password, placeholder: "Enter password")
            
            Text("Password: \(password)")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
