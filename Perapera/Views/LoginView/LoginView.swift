import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var verificationCode: String = ""
    @State private var isCodeSent: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Email Input
                VStack(alignment: .leading, spacing: 8) {
                    TextField("login_email_placeholder".localized(), text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Code Input
                if isCodeSent {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("login_code_placeholder".localized(), text: $verificationCode)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                    .frame(height: 20)
                
                // Action Button (Next or Login)
                Button(action: isCodeSent ? login : sendCode) {
                    Text(isCodeSent ? "login_button".localized() : "login_next_button".localized())
                        .font(.headline)
                        .foregroundColor(isButtonDisabled ? .white.opacity(0.6) : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isButtonDisabled ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(isButtonDisabled)
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("login_title".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    private var isButtonDisabled: Bool {
        if isCodeSent {
            return verificationCode.isEmpty
        } else {
            return !isValidEmail(email)
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func sendCode() {
        guard isValidEmail(email) else { return }
        // TODO: Implement actual code sending logic
        print("Sending code to \(email)")
        
        isCodeSent = true
    }
    
    private func login() {
        // TODO: Implement login logic
        print("Logging in with \(email) and code \(verificationCode)")
        dismiss()
    }
}
