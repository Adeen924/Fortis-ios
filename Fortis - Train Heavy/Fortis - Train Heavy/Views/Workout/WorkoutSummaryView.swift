import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import MuscleMap
import UniformTypeIdentifiers

// Custom Transferable so loadTransferable works for HEIC, JPEG, PNG, etc.
private struct TransferableImage: Transferable {
    let uiImage: UIImage
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let img = UIImage(data: data) else { throw CocoaError(.coderInvalidValue) }
            return TransferableImage(uiImage: img)
        }
    }
}

private extension NSShadow {
    static var shareTextShadow: NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.5)
        shadow.shadowBlurRadius = 10
        shadow.shadowOffset = CGSize(width: 0, height: 2)
        return shadow
    }
}

struct PersonalRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let reps: Int
    let weight: Double
    let previousMax: Double
}

struct WorkoutSummaryView: View {
    @Environment(AuthManager.self) private var authManager
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var dataStore: FirebaseDataStore
    let session: WorkoutSession
    let pastSessions: [WorkoutSession]
    let onDismiss: () -> Void

    private var profile: UserProfile? { dataStore.profile }

    @State private var showShareSheet = false
    @State private var shareImage: UIImage? = nil
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var backgroundImage: UIImage? = nil
    @State private var isGeneratingImage = false
    @State private var showRenameSheet = false
    @State private var workoutNameDraft = ""
    @State private var displayedName: String

    init(session: WorkoutSession, pastSessions: [WorkoutSession], onDismiss: @escaping () -> Void) {
        self.session = session
        self.pastSessions = pastSessions
        self.onDismiss = onDismiss
        _displayedName = State(initialValue: WorkoutSession.normalizedName(session.name))
    }

    private var combinedPrimaryMuscles: [String] {
        var muscles = Set<String>()
        for ex in session.workoutExercises { muscles.formUnion(ex.primaryMuscles) }
        return Array(muscles)
    }

    private var combinedSecondaryMuscles: [String] {
        var muscles = Set<String>()
        for ex in session.workoutExercises { muscles.formUnion(ex.secondaryMuscles ?? []) }
        return Array(muscles)
    }

    private var personalRecords: [PersonalRecord] {
        var bestByKey: [String: PersonalRecord] = [:]
        let pastMaxes = getPastMaxes()
        for workoutEx in session.workoutExercises {
            for set in workoutEx.sets where set.isCompleted {
                let key = "\(workoutEx.exerciseID)_\(set.reps)"
                let pastMax = pastMaxes[key] ?? 0
                guard set.weight > pastMax else { continue }
                let candidate = PersonalRecord(
                    exerciseName: workoutEx.exerciseName,
                    reps: set.reps,
                    weight: set.weight,
                    previousMax: pastMax
                )
                if let existing = bestByKey[key], existing.weight >= set.weight { continue }
                bestByKey[key] = candidate
            }
        }
        return Array(bestByKey.values).sorted { $0.weight > $1.weight }
    }

    private func getPastMaxes() -> [String: Double] {
        var maxes: [String: Double] = [:]
        for pastSession in pastSessions {
            for workoutEx in pastSession.workoutExercises {
                for set in workoutEx.sets where set.isCompleted {
                    let key = "\(workoutEx.exerciseID)_\(set.reps)"
                    maxes[key] = max(maxes[key] ?? 0, set.weight)
                }
            }
        }
        return maxes
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        summaryHero
                        statsGrid
                        exerciseBreakdown
                        personalRecordsSection
                        shareSection
                    }
                    .padding()
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("WORKOUT SUMMARY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .environmentObject(appSettings)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("DONE", action: onDismiss)
                        .font(.system(size: 12, weight: .black))
                        .tracking(2)
                        .foregroundStyle(.romanGold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRenameSheet) {
            renameSheet
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                isGeneratingImage = true
                // Load the photo into a local var — @State updates are async so
                // reading backgroundImage on the very next line would give nil.
                var pickedImage: UIImage? = nil
                if let transferable = try? await newItem.loadTransferable(type: TransferableImage.self) {
                    pickedImage = transferable.uiImage
                    backgroundImage = transferable.uiImage
                }
                let muscleMap = renderMuscleMapImage()
                shareImage = generateShareImage(background: pickedImage, muscleMap: muscleMap)
                isGeneratingImage = false
                showShareSheet = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ActivityView(activityItems: [image])
            }
        }
    }

    private var renameSheet: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    Text("RENAME WORKOUT")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.romanParchmentDim)

                    TextField("Workout name", text: $workoutNameDraft)
                        .font(.title3.bold())
                        .foregroundStyle(.romanParchment)
                        .multilineTextAlignment(.center)
                        .padding()
                        .romanCard()
                        .padding(.horizontal)
                        .textInputAutocapitalization(.words)
                }
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showRenameSheet = false }
                        .foregroundStyle(.romanParchmentDim)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        renameWorkout()
                        showRenameSheet = false
                    }
                    .foregroundStyle(.romanGold)
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero
    private var summaryHero: some View {
        VStack(spacing: 14) {
            Button(action: beginRenameWorkout) {
                HStack(spacing: 8) {
                    Text(displayedName)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Image(systemName: "pencil")
                        .font(.subheadline.bold())
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.romanParchment)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rename workout")
            .accessibilityValue(displayedName)
            .contextMenu {
                Button("Rename", action: beginRenameWorkout)
            }
            MuscleMapView(primaryMuscles: combinedPrimaryMuscles, secondaryMuscles: combinedSecondaryMuscles)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SummaryStatCard(icon: "clock.fill",      iconColor: .romanGold,    label: "Duration",     value: durationFormatted)
            SummaryStatCard(icon: "scalemass.fill",  iconColor: .romanBronze,  label: "Total Volume", value: volumeFormatted)
            SummaryStatCard(icon: "list.number",     iconColor: .romanGold,    label: "Total Sets",   value: "\(session.totalSets)")
            SummaryStatCard(icon: "dumbbell.fill",   iconColor: .romanCrimson, label: "Exercises",    value: "\(session.workoutExercises.count)")
        }
    }

    private var durationFormatted: String {
        let d = Int(session.duration); let h = d / 3600; let m = (d % 3600) / 60; let s = d % 60
        if h > 0 { return String(format: "%dh %dm", h, m) }
        if m > 0 { return String(format: "%dm %ds", m, s) }
        return "\(s)s"
    }

    private var volumeFormatted: String { formattedWeight(session.totalVolume) }

    private func formattedWeight(_ value: Double) -> String {
        let converted = appSettings.weightUnit == .kg ? value * 0.45359237 : value
        let symbol = appSettings.weightUnit.symbol
        if abs(converted) >= 1000 { return String(format: "%.1fk %@", converted / 1000, symbol) }
        return String(format: "%.0f %@", converted, symbol)
    }

    // MARK: - Exercise Breakdown
    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("EXERCISES")
            ForEach(session.workoutExercises.sorted { $0.order < $1.order }) { workoutEx in
                ExerciseSummaryRow(workoutExercise: workoutEx)
            }
        }
    }

    // MARK: - Personal Records
    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PERSONAL RECORDS")
            if personalRecords.isEmpty {
                Text("No new personal records this session.")
                    .font(.subheadline)
                    .foregroundStyle(.romanParchmentDim)
                    .padding(14)
                    .romanCard()
            } else {
                ForEach(personalRecords) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PR: \(record.exerciseName)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.romanParchment)
                            Text("\(formattedWeight(record.weight)) × \(record.reps) reps")
                                .font(.caption)
                                .foregroundStyle(.romanGold)
                            if record.previousMax > 0 {
                                Text("Previous: \(formattedWeight(record.previousMax))")
                                    .font(.caption2)
                                    .foregroundStyle(.romanParchmentDim)
                            }
                        }
                        Spacer()
                        Image(systemName: "trophy.fill")
                            .font(.title3)
                            .foregroundStyle(.romanGold)
                    }
                    .padding(14)
                    .romanCard()
                }
            }
        }
    }

    // MARK: - Share
    private var shareSection: some View {
        HStack(spacing: 12) {
            Button {} label: {
                Label("Share to Feed", systemImage: "person.2.fill")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1)
                    .foregroundStyle(.romanBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient.romanGoldGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: startExternalShare) {
                Group {
                    if isGeneratingImage {
                        ProgressView().tint(.romanBackground)
                    } else {
                        Label("Share Externally", systemImage: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.romanBackground)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LinearGradient.romanGoldGradient)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isGeneratingImage)
        }
    }

    private func startExternalShare() {
        // Reset previous state then open photo picker
        selectedPhotoItem = nil
        backgroundImage = nil
        shareImage = nil
        showPhotoPicker = true
    }

    private func renameWorkout() {
        let newName = WorkoutSession.normalizedName(workoutNameDraft)
        session.name = newName
        displayedName = newName
        Task {
            try? await dataStore.saveWorkout(session, userId: authManager.currentUserID)
        }
    }

    private func beginRenameWorkout() {
        workoutNameDraft = displayedName
        showRenameSheet = true
    }

    // MARK: - Image Generation

    /// Renders the MuscleMapView to a UIImage using ImageRenderer.
    /// Must be called on the MainActor. Uses a query-free variant for sharing.
    @MainActor
    private func renderMuscleMapImage() -> UIImage? {
        let gender = profile?.gender ?? "male"
        let mapView = ShareMuscleMapView(
            primaryMuscles: combinedPrimaryMuscles,
            secondaryMuscles: combinedSecondaryMuscles,
            gender: gender
        )
        .frame(width: 680, height: 460)
        .background(Color.clear)

        let renderer = ImageRenderer(content: mapView)
        renderer.scale = 2.0
        return renderer.uiImage
    }

    private func generateShareImage(background: UIImage?, muscleMap: UIImage?) -> UIImage {
        let W: CGFloat = 1080
        let H: CGFloat = 1920
        let canvasSize = CGSize(width: W, height: H)
        let panelTopFraction: CGFloat = 0.68
        let panelTopY = H * panelTopFraction

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // ── Background: crisp photo fills full canvas, no dark overlay ────
            UIColor(red: 0.11, green: 0.07, blue: 0, alpha: 1).setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: W, height: H))

            var drawnBgRect = CGRect(origin: .zero, size: canvasSize)
            if let bg = background {
                let imgRect = aspectFillRect(imageSize: bg.size, targetSize: canvasSize)
                bg.draw(in: imgRect)
                drawnBgRect = imgRect
            }

            // ── Blur only the panel region ────────────────────────────────────
            if let blurred = background.flatMap({ blurImage($0, radius: 28) }) {
                cgCtx.saveGState()
                UIRectClip(CGRect(x: 0, y: panelTopY, width: W, height: H - panelTopY))
                blurred.draw(in: drawnBgRect)
                cgCtx.restoreGState()
            }

            // ── Dark overlay only on panel for readability ────────────────────
            // ── Gold border at panel top ──────────────────────────────────────
            UIColor(red: 0.83, green: 0.57, blue: 0.04, alpha: 0.85).setStroke()
            let border = UIBezierPath()
            border.move(to: CGPoint(x: 0, y: panelTopY))
            border.addLine(to: CGPoint(x: W, y: panelTopY))
            border.lineWidth = 2.5
            border.stroke()

            // ── Fortis branding — small, top of photo ─────────────────────────
            let shieldSize: CGFloat = 66
            let shieldX = (W - shieldSize) / 2
            let shieldY: CGFloat = 52
            drawShield(in: cgCtx, rect: CGRect(x: shieldX, y: shieldY, width: shieldSize, height: shieldSize))
            let fortisAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 19, weight: .black),
                .foregroundColor: UIColor(red: 0.83, green: 0.57, blue: 0.04, alpha: 0.85),
                .kern: 8
            ]
            let fortisStr = "FORTIS" as NSString
            let fortisW = fortisStr.size(withAttributes: fortisAttrs).width
            fortisStr.draw(at: CGPoint(x: (W - fortisW) / 2, y: shieldY + shieldSize + 6), withAttributes: fortisAttrs)

            // ── Panel content ─────────────────────────────────────────────────
            let margin: CGFloat = 36
            var panelY = panelTopY + 26

            // Workout name
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
                .foregroundColor: UIColor.white,
                .shadow: NSShadow.shareTextShadow
            ]
            let titleH = (session.name as NSString).boundingRect(
                with: CGSize(width: W - margin * 2, height: .infinity),
                options: .usesLineFragmentOrigin, attributes: titleAttrs, context: nil
            ).height
            (session.name as NSString).draw(
                with: CGRect(x: margin, y: panelY, width: W - margin * 2, height: titleH),
                options: .usesLineFragmentOrigin, attributes: titleAttrs, context: nil
            )
            panelY += titleH + 16

            // Gold separator
            let gold = UIColor(red: 0.83, green: 0.57, blue: 0.04, alpha: 0.55)
            gold.setStroke()
            let sep = UIBezierPath()
            sep.move(to: CGPoint(x: margin, y: panelY))
            sep.addLine(to: CGPoint(x: W - margin, y: panelY))
            sep.lineWidth = 1.5
            sep.stroke()
            panelY += 22

            // ── Side-by-side: muscle map (left) + stats (right) ───────────────
            let mapMaxSize = CGSize(width: 545, height: 370)
            let statBlockHeight: CGFloat = 318
            let columnGap: CGFloat = 54
            let statsX = margin + mapMaxSize.width + columnGap
            let statsWidth = W - statsX - margin
            let statsY = panelY + 34

            if let mapImg = muscleMap {
                cgCtx.saveGState()
                let mapBounds = CGRect(origin: CGPoint(x: margin, y: panelY), size: mapMaxSize)
                UIBezierPath(roundedRect: mapBounds, cornerRadius: 14).addClip()
                let mapRect = aspectFitRect(imageSize: mapImg.size, targetRect: mapBounds)
                mapImg.draw(in: mapRect)
                cgCtx.restoreGState()
            }

            let statLabelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                .foregroundColor: UIColor(red: 0.83, green: 0.57, blue: 0.04, alpha: 1),
                .kern: 2,
                .shadow: NSShadow.shareTextShadow
            ]
            let statValueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 44, weight: .heavy),
                .foregroundColor: UIColor.white,
                .shadow: NSShadow.shareTextShadow
            ]
            let statLabels = ["DURATION", "VOLUME", "EXERCISES", "SETS"]
            let statValues = [durationFormatted, volumeFormatted,
                              "\(session.workoutExercises.count)", "\(session.totalSets)"]
            let rowH = statBlockHeight / 4
            for i in 0..<4 {
                let rowY = statsY + CGFloat(i) * rowH
                (statLabels[i] as NSString).draw(at: CGPoint(x: statsX, y: rowY + 4), withAttributes: statLabelAttrs)
                (statValues[i] as NSString).draw(
                    with: CGRect(x: statsX, y: rowY + 24, width: statsWidth, height: 58),
                    options: .usesLineFragmentOrigin, attributes: statValueAttrs, context: nil
                )
            }
            panelY = max(panelY + mapMaxSize.height, statsY + statBlockHeight) + 18

            // Gold separator 2
            gold.setStroke()
            let sep2 = UIBezierPath()
            sep2.move(to: CGPoint(x: margin, y: panelY))
            sep2.addLine(to: CGPoint(x: W - margin, y: panelY))
            sep2.lineWidth = 1.5
            sep2.stroke()
            panelY += 16

            // Hashtags
            let hashAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.55),
                .shadow: NSShadow.shareTextShadow
            ]
            let hashStr = "#Fortis  #WorkoutComplete  #Fitness" as NSString
            let hashSz = hashStr.size(withAttributes: hashAttrs)
            hashStr.draw(at: CGPoint(x: (W - hashSz.width) / 2, y: panelY), withAttributes: hashAttrs)
        }
    }

    // MARK: - Draw helpers

    /// Draws a simple shield shape as the Fortis branding icon.
    private func drawShield(in ctx: CGContext, rect: CGRect) {
        let gold = UIColor(red: 0.83, green: 0.57, blue: 0.04, alpha: 1)
        let w = rect.width; let h = rect.height
        let cx = rect.midX; let top = rect.minY

        let path = UIBezierPath()
        path.move(to: CGPoint(x: cx, y: top))
        path.addLine(to: CGPoint(x: rect.maxX, y: top + h * 0.18))
        path.addLine(to: CGPoint(x: rect.maxX, y: top + h * 0.55))
        path.addCurve(
            to: CGPoint(x: cx, y: top + h),
            controlPoint1: CGPoint(x: rect.maxX, y: top + h * 0.82),
            controlPoint2: CGPoint(x: cx + w * 0.3, y: top + h * 0.95)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: top + h * 0.55),
            controlPoint1: CGPoint(x: cx - w * 0.3, y: top + h * 0.95),
            controlPoint2: CGPoint(x: rect.minX, y: top + h * 0.82)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: top + h * 0.18))
        path.close()

        gold.withAlphaComponent(0.25).setFill()
        path.fill()
        gold.setStroke()
        path.lineWidth = 3
        path.stroke()
    }

    /// Returns a rect that aspect-fill crops `imageSize` to `targetSize`.
    private func aspectFillRect(imageSize: CGSize, targetSize: CGSize) -> CGRect {
        let wRatio = targetSize.width / imageSize.width
        let hRatio = targetSize.height / imageSize.height
        let scale = max(wRatio, hRatio)
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        return CGRect(
            x: (targetSize.width - scaledWidth) / 2,
            y: (targetSize.height - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )
    }

    private func aspectFitRect(imageSize: CGSize, targetRect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return targetRect }
        let scale = min(targetRect.width / imageSize.width, targetRect.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: targetRect.midX - scaledSize.width / 2,
            y: targetRect.midY - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }

    private func blurImage(_ image: UIImage, radius: CGFloat) -> UIImage? {
        guard let inputImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = inputImage
        filter.radius = Float(radius)
        guard let outputImage = filter.outputImage else { return nil }
        let context = CIContext(options: nil)
        let cropped = outputImage.cropped(to: inputImage.extent)
        guard let cgImage = context.createCGImage(cropped, from: inputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(3)
            .foregroundStyle(.romanParchmentDim)
    }
}

// MARK: - Activity View Representable

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.modalPresentationStyle = .automatic

        if let popover = controller.popoverPresentationController {
            popover.permittedArrowDirections = []
            let bounds = UIScreen.main.bounds
            popover.sourceRect = CGRect(x: bounds.midX, y: bounds.midY, width: 1, height: 1)
            popover.sourceView = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first { $0.isKeyWindow }
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Summary Stat Card

struct SummaryStatCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.romanParchmentDim)
                Text(value)
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(.romanParchment)
            }
            Spacer()
        }
        .padding(14)
        .romanCard()
    }
}

// MARK: - Exercise Summary Row

struct ExerciseSummaryRow: View {
    @EnvironmentObject private var appSettings: AppSettings
    let workoutExercise: WorkoutExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workoutExercise.exerciseName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.romanParchment)
                Spacer()
                Text(volumeFormatted)
                    .font(.caption.bold())
                    .foregroundStyle(.romanGold)
            }
            ForEach(uniqueSets(workoutExercise.sets)) { set in
                HStack(spacing: 14) {
                    Text("Set \(set.setNumber)")
                        .font(.caption)
                        .foregroundStyle(.romanParchmentDim)
                        .frame(width: 40, alignment: .leading)
                    Text(formattedWeight(set.weight))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.romanParchment)
                    Text("×")
                        .font(.caption)
                        .foregroundStyle(.romanParchmentDim)
                    Text("\(set.reps) reps")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.romanParchment)
                    Spacer()
                }
            }
        }
        .padding(14)
        .romanCard()
    }

    private func uniqueSets(_ sets: [ExerciseSet]) -> [ExerciseSet] {
        var seen = Set<Int>()
        return sets.sorted { $0.setNumber < $1.setNumber }.filter { seen.insert($0.setNumber).inserted }
    }

    private var volumeFormatted: String {
        let v = workoutExercise.totalVolume
        let converted = appSettings.weightUnit == .kg ? v * 0.45359237 : v
        let symbol = appSettings.weightUnit.symbol
        if abs(converted) >= 1000 { return String(format: "%.1fk %@", converted / 1000, symbol) }
        return String(format: "%.0f %@", converted, symbol)
    }

    private func formattedWeight(_ value: Double) -> String {
        let converted = appSettings.weightUnit == .kg ? value * 0.45359237 : value
        let symbol = appSettings.weightUnit.symbol
        return String(format: "%.1f %@", converted, symbol)
    }
}

// MARK: - Muscle Heat Map

struct MuscleSummaryHeatMap: View {
    let session: WorkoutSession

    private var trainedMuscles: [String: Int] {
        var counts: [String: Int] = [:]
        for ex in session.workoutExercises {
            for muscle in ex.primaryMuscles { counts[muscle, default: 0] += ex.sets.count }
        }
        return counts
    }

    var body: some View {
        VStack(spacing: 8) {
            let muscles = trainedMuscles
            let maxCount = muscles.values.max() ?? 1

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(MuscleGroup.allCases, id: \.rawValue) { group in
                    let count = muscles[group.rawValue] ?? 0
                    let intensity = Double(count) / Double(maxCount)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(count > 0
                                  ? Color.romanGold.opacity(0.25 + 0.75 * intensity)
                                  : Color.romanSurfaceHigh)
                            .frame(height: 40)
                            .overlay(
                                Text(count > 0 ? "\(count)" : "")
                                    .font(.caption.bold())
                                    .foregroundStyle(count > 0 ? .romanBackground : .clear)
                            )
                        Text(group.rawValue)
                            .font(.system(size: 8))
                            .foregroundStyle(.romanParchmentDim)
                            .multilineTextAlignment(.center)
                    }
                }
            }

            HStack(spacing: 6) {
                Text("Less").font(.caption2).foregroundStyle(.romanParchmentDim)
                HStack(spacing: 4) {
                    ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { opacity in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.romanGold.opacity(opacity))
                            .frame(width: 16, height: 10)
                    }
                }
                Text("More").font(.caption2).foregroundStyle(.romanParchmentDim)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .romanCard()
    }
}

// MARK: - Share Muscle Map (no @Query — safe to use with ImageRenderer)

struct ShareMuscleMapView: View {
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let gender: String

    private var bodyGender: BodyGender { gender == "female" ? .female : .male }

    var body: some View {
        HStack(spacing: 4) {
            highlightedBodyView(side: .front).frame(maxWidth: .infinity)
            highlightedBodyView(side: .back).frame(maxWidth: .infinity)
        }
        .padding(6)
        .background(Color.clear)
    }

    private func highlightedBodyView(side: BodySide) -> some View {
        var view = BodyView(gender: bodyGender, side: side).bodyStyle(.minimal)
        for muscle in primaryMuscles.compactMap({ mapToMuscle($0) }) {
            view = view.highlight(muscle, color: Color(red: 0.83, green: 0.57, blue: 0.04).opacity(0.9))
        }
        for muscle in secondaryMuscles.compactMap({ mapToMuscle($0) }) {
            view = view.highlight(muscle, color: Color(red: 0.83, green: 0.57, blue: 0.04).opacity(0.45))
        }
        return view
    }

    private func mapToMuscle(_ name: String) -> Muscle? {
        switch name.lowercased() {
        case "chest":      return .chest
        case "shoulders":  return .deltoids
        case "biceps":     return .biceps
        case "triceps":    return .triceps
        case "forearms":   return .forearm
        case "core":       return .obliques
        case "abs":        return .abs
        case "quads":      return .quadriceps
        case "glutes":     return .gluteal
        case "hamstrings": return .hamstring
        case "calves":     return .calves
        case "back", "lats": return .upperBack
        case "lower back": return .lowerBack
        case "traps":      return .trapezius
        default:           return nil
        }
    }
}
