import SwiftUI
import SwiftData

struct SignUpView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Step tracking
    @State private var step = 1
    private let totalSteps = 4

    // Step 1 — Contact
    enum ContactMethod { case email, phone }
    @State private var contactMethod: ContactMethod = .email
    @State private var email        = ""
    @State private var phoneNumber  = ""
    @State private var password     = ""
    @State private var confirmPass  = ""

    // Step 2 — Identity
    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var username  = ""
    @State private var gender    = "male"

    // Step 3 — Physical
    @State private var age          = ""
    @State private var heightFeet   = 5
    @State private var heightInches = 10
    @State private var weightText   = ""

    // Step 4 — Goals
    @State private var selectedGoals: Set<String> = []

    @State private var validationError: String? = nil
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    progressBar.padding(.horizontal, 24).padding(.top, 4)

                    // Animate step transitions
                    ZStack {
                        switch step {
                        case 1: step1View.transition(.asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading)))
                        case 2: step2View.transition(.asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading)))
                        case 3: step3View.transition(.asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading)))
                        case 4: step4View.transition(.asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading)))
                        default: EmptyView()
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: step)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: goBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(step == 1 ? "Back" : "Previous")
                        }
                        .foregroundStyle(.romanParchmentDim)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(stepTitle)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.romanParchmentDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(1...totalSteps, id: \.self) { s in
                Capsule()
                    .fill(s <= step ? Color.romanGold : Color.romanSurfaceHigh)
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
        .padding(.bottom, 16)
    }

    private var stepTitle: String {
        switch step {
        case 1: return "CONTACT INFO"
        case 2: return "YOUR IDENTITY"
        case 3: return "PHYSICAL PROFILE"
        case 4: return "YOUR GOALS"
        default: return ""
        }
    }

    // MARK: - Step 1: Contact
    private var step1View: some View {
        ScrollView {
            VStack(spacing: 28) {
                stepHeader(
                    icon: "envelope.fill",
                    title: "How do we reach you?",
                    subtitle: "Your contact info is used to secure your account."
                )

                VStack(spacing: 16) {
                    // Contact method toggle
                    Picker("Contact", selection: $contactMethod) {
                        Text("Email").tag(ContactMethod.email)
                        Text("Phone").tag(ContactMethod.phone)
                    }
                    .pickerStyle(.segmented)
                    .padding(3)
                    .background(Color.romanSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    if contactMethod == .email {
                        romanField(placeholder: "Email address", text: $email, keyboard: .emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        romanField(placeholder: "Phone number (10 digits)", text: $phoneNumber, keyboard: .phonePad)
                    }

                    romanSecureField(placeholder: "Password (8+ characters)", text: $password)
                    romanSecureField(placeholder: "Confirm password", text: $confirmPass)
                }

                if let error = validationError {
                    errorLabel(error)
                }

                continueButton(action: validateAndAdvanceStep1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 2: Identity
    private var step2View: some View {
        ScrollView {
            VStack(spacing: 28) {
                stepHeader(
                    icon: "person.fill",
                    title: "Who are you?",
                    subtitle: "Choose a username that other athletes will see."
                )

                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        romanField(placeholder: "First name", text: $firstName)
                        romanField(placeholder: "Last name",  text: $lastName)
                    }
                    HStack(spacing: 0) {
                        Text("@")
                            .font(.subheadline.bold())
                            .foregroundStyle(.romanGoldDim)
                            .padding(.leading, 16)
                            .padding(.trailing, 4)
                        TextField("username", text: $username)
                            .font(.subheadline)
                            .foregroundStyle(.romanParchment)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.vertical, 16)
                            .padding(.trailing, 16)
                    }
                    .background(Color.romanSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.romanBorder, lineWidth: 0.5))

                    Picker("Gender", selection: $gender) {
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                    }
                    .pickerStyle(.segmented)
                    .background(Color.romanSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.romanBorder, lineWidth: 0.5))
                }

                if let error = validationError { errorLabel(error) }

                continueButton(action: validateAndAdvanceStep2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 3: Physical Profile
    private var step3View: some View {
        ScrollView {
            VStack(spacing: 28) {
                stepHeader(
                    icon: "figure.stand",
                    title: "Your physical profile",
                    subtitle: "Used to personalise your training stats and goals."
                )

                VStack(spacing: 20) {
                    // Age
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("AGE")
                        romanField(placeholder: "Years (e.g. 25)", text: $age, keyboard: .numberPad)
                    }

                    // Height
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("HEIGHT")
                        HStack(spacing: 0) {
                            Picker("Feet", selection: $heightFeet) {
                                ForEach(4...7, id: \.self) { Text("\($0) ft").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .clipped()

                            Rectangle().fill(Color.romanBorder).frame(width: 0.5).padding(.vertical, 8)

                            Picker("Inches", selection: $heightInches) {
                                ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .clipped()
                        }
                        .background(Color.romanSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.romanBorder, lineWidth: 0.5))
                    }

                    // Weight
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("WEIGHT")
                        HStack(spacing: 0) {
                            romanField(placeholder: "lbs (e.g. 175)", text: $weightText, keyboard: .decimalPad)
                            Text("lbs")
                                .font(.subheadline.bold())
                                .foregroundStyle(.romanParchmentDim)
                                .padding(.trailing, 16)
                                .padding(.leading, -8)
                        }
                        .background(Color.romanSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.romanBorder, lineWidth: 0.5))
                    }
                }

                if let error = validationError { errorLabel(error) }

                continueButton(action: validateAndAdvanceStep3)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 4: Goals
    private var step4View: some View {
        ScrollView {
            VStack(spacing: 28) {
                stepHeader(
                    icon: "trophy.fill",
                    title: "What are your goals?",
                    subtitle: "Select all that apply. You can change these later."
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(GymGoal.allCases) { goal in
                        GoalCard(
                            goal: goal,
                            isSelected: selectedGoals.contains(goal.rawValue)
                        ) {
                            if selectedGoals.contains(goal.rawValue) {
                                selectedGoals.remove(goal.rawValue)
                            } else {
                                selectedGoals.insert(goal.rawValue)
                            }
                        }
                    }
                }

                if let error = validationError { errorLabel(error) }

                // Final create account button
                Button(action: createAccount) {
                    HStack(spacing: 8) {
                        if isCreating {
                            ProgressView().tint(.romanBackground)
                        } else {
                            Image(systemName: "shield.fill")
                            Text("CREATE ACCOUNT")
                                .font(.system(size: 14, weight: .black))
                                .tracking(3)
                        }
                    }
                    .foregroundStyle(.romanBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(LinearGradient.romanGoldGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .romanGold.opacity(0.35), radius: 14, x: 0, y: 6)
                }
                .disabled(isCreating)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Validation & Navigation
    private func goBack() {
        validationError = nil
        if step > 1 { withAnimation { step -= 1 } } else { dismiss() }
    }

    private func validateAndAdvanceStep1() {
        validationError = nil
        if contactMethod == .email {
            guard email.contains("@"), email.contains(".") else {
                validationError = "Enter a valid email address."; return
            }
        } else {
            let digits = phoneNumber.filter { $0.isNumber }
            guard digits.count == 10 else {
                validationError = "Enter a 10-digit phone number."; return
            }
        }
        guard password.count >= 8 else { validationError = "Password must be at least 8 characters."; return }
        guard password == confirmPass   else { validationError = "Passwords do not match."; return }
        withAnimation { step = 2 }
    }

    private func validateAndAdvanceStep2() {
        validationError = nil
        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty else { validationError = "First name is required."; return }
        guard !lastName.trimmingCharacters(in: .whitespaces).isEmpty  else { validationError = "Last name is required."; return }
        let u = username.trimmingCharacters(in: .whitespaces)
        guard u.count >= 3 else { validationError = "Username must be at least 3 characters."; return }
        guard !u.contains(" ") else { validationError = "Username cannot contain spaces."; return }
        withAnimation { step = 3 }
    }

    private func validateAndAdvanceStep3() {
        validationError = nil
        guard let ageVal = Int(age), ageVal >= 13, ageVal <= 100 else {
            validationError = "Enter a valid age between 13 and 100."; return
        }
        guard let w = Double(weightText), w > 0 else {
            validationError = "Enter a valid weight in lbs."; return
        }
        withAnimation { step = 4 }
    }

    private func createAccount() {
        guard !selectedGoals.isEmpty else { validationError = "Select at least one goal."; return }
        validationError = nil
        isCreating = true

        let profile = UserProfile(
            firstName:    firstName.trimmingCharacters(in: .whitespaces),
            lastName:     lastName.trimmingCharacters(in: .whitespaces),
            username:     username.trimmingCharacters(in: .whitespaces).lowercased(),
            email:        contactMethod == .email ? email.lowercased() : nil,
            phoneNumber:  contactMethod == .phone ? phoneNumber : nil,
            age:          Int(age) ?? 18,
            gender:       gender,
            heightFeet:   heightFeet,
            heightInches: heightInches,
            weightLbs:    Double(weightText) ?? 160,
            goals:        Array(selectedGoals),
            authProvider: contactMethod == .email ? "email" : "phone"
        )
        modelContext.insert(profile)
        try? modelContext.save()
        authManager.completeSignIn(userID: profile.id.uuidString)
    }

    // MARK: - Reusable Sub-views
    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.romanGold)
                .padding(.top, 8)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.romanParchment)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.romanParchmentDim)
                .multilineTextAlignment(.center)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(3)
            .foregroundStyle(.romanParchmentDim)
    }

    private func romanField(placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .font(.subheadline)
            .foregroundStyle(.romanParchment)
            .padding(16)
            .background(Color.romanSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.romanBorder, lineWidth: 0.5))
    }

    private func romanSecureField(placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .font(.subheadline)
            .foregroundStyle(.romanParchment)
            .padding(16)
            .background(Color.romanSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.romanBorder, lineWidth: 0.5))
    }

    private func errorLabel(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle")
            .font(.caption.bold())
            .foregroundStyle(.romanCrimson)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func continueButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("CONTINUE")
                    .font(.system(size: 14, weight: .black))
                    .tracking(3)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.romanBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(LinearGradient.romanGoldGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Goal Card
struct GoalCard: View {
    let goal: GymGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: goal.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.romanBackground : Color.romanGold)
                Text(goal.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? Color.romanBackground : Color.romanParchment)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(isSelected ? LinearGradient.romanGoldGradient : LinearGradient(colors: [.romanSurface], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : Color.romanBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
