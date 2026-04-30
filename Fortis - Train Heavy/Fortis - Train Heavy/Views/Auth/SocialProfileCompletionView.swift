import SwiftUI

/// Shown after Apple/Google sign-in to collect the profile fields
/// that social auth doesn't provide (username, age, height, weight, goals).
struct SocialProfileCompletionView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext

    @State private var step = 1
    @State private var firstName    = ""
    @State private var lastName     = ""
    @State private var username     = ""
    @State private var age          = ""
    @State private var heightFeet   = 5
    @State private var heightInches = 10
    @State private var weightText   = ""
    @State private var selectedGoals: Set<String> = []
    @State private var validationError: String? = nil
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    progressBar.padding(.horizontal, 24).padding(.top, 4)
                    ZStack {
                        switch step {
                        case 1: identityStep.transition(.asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading)))
                        case 2: physicalStep.transition(.asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading)))
                        case 3: goalsStep.transition(.asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading)))
                        default: EmptyView()
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: step)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("COMPLETE YOUR PROFILE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.romanParchmentDim)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if step > 1 {
                        Button(action: { withAnimation { step -= 1 } }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .foregroundStyle(.romanParchmentDim)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(1...3, id: \.self) { s in
                Capsule().fill(s <= step ? Color.romanGold : Color.romanSurfaceHigh).frame(height: 3)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }.padding(.bottom, 16)
    }

    // MARK: - Steps (reuse helper views from SignUpView style)
    private var identityStep: some View {
        ScrollView {
            VStack(spacing: 28) {
                stepHeader(icon: "person.fill", title: "Tell us who you are", subtitle: "Choose a username athletes will see.")
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        inputField("First name", text: $firstName)
                        inputField("Last name",  text: $lastName)
                    }
                    HStack(spacing: 0) {
                        Text("@").font(.subheadline.bold()).foregroundStyle(.romanGoldDim).padding(.leading, 16).padding(.trailing, 4)
                        TextField("username", text: $username).font(.subheadline).foregroundStyle(.romanParchment)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .padding(.vertical, 16).padding(.trailing, 16)
                    }
                    .background(Color.romanSurface).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.romanBorder, lineWidth: 0.5))
                }
                if let e = validationError { errorLabel(e) }
                continueBtn {
                    validationError = nil
                    guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty else { validationError = "First name required."; return }
                    guard !lastName.trimmingCharacters(in: .whitespaces).isEmpty  else { validationError = "Last name required."; return }
                    let u = username.trimmingCharacters(in: .whitespaces)
                    guard u.count >= 3, !u.contains(" ") else { validationError = "Username: 3+ chars, no spaces."; return }
                    withAnimation { step = 2 }
                }
            }.padding(.horizontal, 24).padding(.bottom, 40)
        }
    }

    private var physicalStep: some View {
        ScrollView {
            VStack(spacing: 28) {
                stepHeader(icon: "figure.stand", title: "Physical profile", subtitle: "Personalises your training stats.")
                VStack(spacing: 20) {
                    inputField("Age (e.g. 25)", text: $age, keyboard: .numberPad)
                    HStack(spacing: 0) {
                        Picker("Feet", selection: $heightFeet) {
                            ForEach(4...7, id: \.self) { Text("\($0) ft").tag($0) }
                        }.pickerStyle(.wheel).frame(maxWidth: .infinity).frame(height: 110).clipped()
                        Rectangle().fill(Color.romanBorder).frame(width: 0.5).padding(.vertical, 8)
                        Picker("Inches", selection: $heightInches) {
                            ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                        }.pickerStyle(.wheel).frame(maxWidth: .infinity).frame(height: 110).clipped()
                    }
                    .background(Color.romanSurface).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.romanBorder, lineWidth: 0.5))
                    inputField("Weight in lbs (e.g. 175)", text: $weightText, keyboard: .decimalPad)
                }
                if let e = validationError { errorLabel(e) }
                continueBtn {
                    validationError = nil
                    guard let a = Int(age), a >= 13, a <= 100 else { validationError = "Enter a valid age (13–100)."; return }
                    guard let w = Double(weightText), w > 0 else { validationError = "Enter a valid weight."; return }
                    withAnimation { step = 3 }
                }
            }.padding(.horizontal, 24).padding(.bottom, 40)
        }
    }

    private var goalsStep: some View {
        ScrollView {
            VStack(spacing: 28) {
                stepHeader(icon: "trophy.fill", title: "Set your goals", subtitle: "Select all that apply.")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(GymGoal.allCases) { goal in
                        GoalCard(goal: goal, isSelected: selectedGoals.contains(goal.rawValue)) {
                            if selectedGoals.contains(goal.rawValue) { selectedGoals.remove(goal.rawValue) }
                            else { selectedGoals.insert(goal.rawValue) }
                        }
                    }
                }
                if let e = validationError { errorLabel(e) }
                Button(action: finishProfile) {
                    HStack(spacing: 8) {
                        if isCreating { ProgressView().tint(.romanBackground) }
                        else {
                            Image(systemName: "shield.fill")
                            Text("ENTER THE ARENA").font(.system(size: 14, weight: .black)).tracking(3)
                        }
                    }
                    .foregroundStyle(.romanBackground).frame(maxWidth: .infinity).frame(height: 54)
                    .background(LinearGradient.romanGoldGradient).clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .romanGold.opacity(0.35), radius: 14, x: 0, y: 6)
                }
                .disabled(isCreating)
            }.padding(.horizontal, 24).padding(.bottom, 40)
        }
    }

    private func finishProfile() {
        guard !selectedGoals.isEmpty else { validationError = "Select at least one goal."; return }
        validationError = nil; isCreating = true
        guard let userID = authManager.currentUserID else { return }
        let profile = UserProfile(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName:  lastName.trimmingCharacters(in: .whitespaces),
            username:  username.trimmingCharacters(in: .whitespaces).lowercased(),
            age:          Int(age) ?? 18,
            heightFeet:   heightFeet,
            heightInches: heightInches,
            weightLbs:    Double(weightText) ?? 160,
            goals:        Array(selectedGoals),
            authProvider: "apple"
        )
        modelContext.insert(profile)
        try? modelContext.save()
        authManager.completeSignIn(userID: userID)
    }

    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 32)).foregroundStyle(.romanGold).padding(.top, 8)
            Text(title).font(.title3.bold()).foregroundStyle(.romanParchment)
            Text(subtitle).font(.subheadline).foregroundStyle(.romanParchmentDim).multilineTextAlignment(.center)
        }
    }

    private func inputField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text).keyboardType(keyboard).font(.subheadline).foregroundStyle(.romanParchment)
            .padding(16).background(Color.romanSurface).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.romanBorder, lineWidth: 0.5))
    }

    private func errorLabel(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle").font(.caption.bold()).foregroundStyle(.romanCrimson)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func continueBtn(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("CONTINUE").font(.system(size: 14, weight: .black)).tracking(3)
                Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.romanBackground).frame(maxWidth: .infinity).frame(height: 54)
            .background(LinearGradient.romanGoldGradient).clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
