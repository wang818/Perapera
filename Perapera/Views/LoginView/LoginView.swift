import SwiftUI
import Moya
import RxSwift

class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var verificationCode: String = ""
    @Published var isCodeSent: Bool = false
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var countdown: Int = 60
    @Published var isTimerRunning: Bool = false
    
    private let disposeBag = DisposeBag()
    private var timer: Timer?
    
    var isButtonDisabled: Bool {
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
    
    func sendCode() {
        guard isValidEmail(email) else { return }
        
        appApi.rx.request(.sendCaptcha(email: email))
            .asObservable()
            .subscribe(onNext: { [weak self] response in
                // 直接判断 HTTP 状态码，因为 SendCaptchaModel 里的 statusCode 是误用的 Log 字段
                if response.statusCode == 200 {
                    DispatchQueue.main.async {
                        self?.isCodeSent = true
                        self?.toastMessage = "login_send_code_success".localized()
                        self?.showToast = true
                        self?.startTimer()
                    }
                } else {
                    self?.isCodeSent = true
                    print("Send captcha failed: \(response.statusCode)")
                    // 尝试解析错误信息
                    if let json = try? response.mapJSON() as? [String: Any],
                       let detail = json["detail"] as? String {
                        self?.toastMessage = detail
                        self!.showToast = true
                        print("Error detail: \(detail)")
                    }
                }
            }, onError: { error in
                print("Send captcha error: \(error.localizedDescription)")
            })
            .disposed(by: disposeBag)
    }
    
    func startTimer() {
        stopTimer()
        countdown = 60
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.countdown > 0 {
                self.countdown -= 1
            } else {
                self.stopTimer()
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
    }
    
    deinit {
        stopTimer()
    }
    
    func login(completion: @escaping () -> Void) {
        guard !email.isEmpty && !verificationCode.isEmpty else { return }
        
        appApi.rx.request(.login(email: email, captcha: verificationCode))
            .asObservable()
            .mapObject(LoginModel.self) // 将 response.data 转换为 LoginModel
            .subscribe(onNext: { [weak self] model in
                // 登录成功，获取到可视化数据 model
                
                print("Login success: AccessToken=\(model.access_token), TokenType=\(model.token_type)")
                PUserDefault.setValueForKey(model.access_token, key: "access_token")
                // 这里可以保存用户信息，例如:
                if let email = self?.email {
                    UserManager.shared.save(model: model, email: email)
                }
                
                if model.statusCode == 200 {
                    DispatchQueue.main.async {
                        self?.toastMessage = "login_success".localized()
                        self?.showToast = true
                        
                        // 延迟调用 completion 以便显示 Toast
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            completion()
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }, onError: { [weak self] error in
                print("Login error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.toastMessage = error.localizedDescription
                    self?.showToast = true
                }
            })
            .disposed(by: disposeBag)
    }
}

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Email Input
                VStack(alignment: .leading, spacing: 8) {
                    TextField("login_email_placeholder".localized(), text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Code Input
                if viewModel.isCodeSent {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("login_code_placeholder".localized(), text: $viewModel.verificationCode)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        
                        // Resend Button
                        HStack {
                            Spacer()
                            Button(action: {
                                viewModel.sendCode()
                            }) {
                                Text(viewModel.isTimerRunning ? String(format: "login_resend_code_timer".localized(), viewModel.countdown) : "login_resend_code".localized())
                                    .font(.subheadline)
                                    .foregroundColor(viewModel.isTimerRunning ? .gray : Color.Ex.main)
                            }
                            .disabled(viewModel.isTimerRunning)
                        }
                    }
                }
                
                Spacer()
                    .frame(height: 20)
                
                // Action Button (Next or Login)
                Button(action: {
                    if viewModel.isCodeSent {
                        viewModel.login {
                            dismiss()
                        }
                    } else {
                        viewModel.sendCode()
                    }
                }) {
                    Text(viewModel.isCodeSent ? "login_button".localized() : "login_next_button".localized())
                        .font(.headline)
                        .foregroundColor(viewModel.isButtonDisabled ? .white.opacity(0.6) : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isButtonDisabled ? Color.gray : Color.Ex.main)
                        .cornerRadius(12)
                }
                .disabled(viewModel.isButtonDisabled)
                
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
            .toast(isPresented: $viewModel.showToast, message: viewModel.toastMessage)
        }
    }
}
