import SwiftUI

struct AuthView: View {
    @StateObject private var authManager = AuthManager.shared

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoginMode: Bool = true
    @State private var gender: String = ""
    @State private var ageString: String = ""
    @State private var timezone: String = TimeZone.current.identifier

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                SecureField("Password", text: $password)
            } header: {
                Text("Account")
            }

            if !isLoginMode {
                Section {
                    TextField("Gender", text: $gender)
                    TextField("Age", text: $ageString)
                        .keyboardType(.numberPad)
                    TextField("Timezone (e.g., \(TimeZone.current.identifier))", text: $timezone)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                } header: {
                    Text("Profile")
                }
            }

            Section {
                Button {
                    Task {
                        await submit()
                    }
                } label: {
                    if authManager.isLoading {
                        ProgressView()
                    } else {
                        Text(isLoginMode ? "Log In" : "Sign Up")
                    }
                }
                .disabled(isSubmitDisabled)

                HStack(spacing: 4) {
                    Text(isLoginMode ? "Need an account?" : "Have an account?")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Button(isLoginMode ? "Sign Up" : "Log In") {
                        isLoginMode.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.footnote)
                    .foregroundColor(.accentColor)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            if let error = authManager.error {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(isLoginMode ? "Log In" : "Sign Up")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() async {
        if isLoginMode {
            await authManager.login(email: email, password: password)
        } else {
            let age = Int(ageString)
            let profile = UserProfile(
                gender: gender.isEmpty ? nil : gender,
                age: age,
                timezone: timezone.isEmpty ? nil : timezone
            )
            await authManager.signUp(email: email, password: password, profile: profile)
        }
    }

    private var isSubmitDisabled: Bool {
        if authManager.isLoading { return true }
        guard !email.isEmpty, !password.isEmpty else { return true }
        return false
    }
}
