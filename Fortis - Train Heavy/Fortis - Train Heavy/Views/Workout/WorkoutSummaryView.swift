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
    let onDismiss: () -> Void

    private var profile: UserProfile? { dataStore.profile }
    private var pastSessions: [WorkoutSession] { dataStore.workouts }

    @State private var showShareSheet = false
    @State private var shareImage: UIImage? = nil
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var backgroundImage: UIImage? = nil
    @State private var isGeneratingImage = false
    @State private var showRenameAlert = false
    @State private var workoutNameDraft = ""

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
        var records: [PersonalRecord] = []
        let pastMaxes = getPastMaxes()
        for workoutEx in session.workoutExercises {
            for set in workoutEx.sets where set.isCompleted {
                let key = "\(workoutEx.exerciseID)_\(set.reps)"
                let pastMax = pastMaxes[key] ?? 0
                if set.weight > pastMax {
                    records.append(PersonalRecord(
                        exerciseName: workoutEx.exerciseName,
                        reps: set.reps,
                        weight: set.weight,
                        previousMax: pastMax
                    ))
                }
            }
        }
        return records.sorted { $0.weight > $1.weight }
    }

    private func getPastMaxes() -> [String: Double] {
        var maxes: [String: Double] = [:]
        for pastSession in pastSessions where pastSession.id != session.id {
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
            .alert("Rename Workout", isPresented: $showRenameAlert) {
                TextField("Workout name", text: $workoutNameDraft)
                Button("Save") { renameWorkout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for this workout.")
            }
        }
        .preferredColorScheme(.dark)
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

    // MARK: - Hero
    private var summaryHero: some View {
        VStack(spacing: 14) {
            Text(session.name)
                .font(.title2.bold())
                .foregroundStyle(.romanParchment)
                .onTapGesture {
                    workoutNameDraft = session.name
                    showRenameAlert = true
                }
                .contextMenu {
                    Button("Rename") {
                        workoutNameDraft = session.name
                        showRenameAlert = true
                    }
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
        let trimmed = workoutNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        session.name = trimmed
        Task {
            try? await dataStore.saveWorkout(session, userId: authManager.currentUserID)
        }
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
        .frame(width: 960, height: 280)  // wide/short: front+back side by side
        .background(Color.clear)

        let renderer = ImageRenderer(content: mapView)
        renderer.scale = 2.0
        return renderer.uiImage
    }

    /// Builds the 1080×1920 share card:
    ///   • User's photo fills the full frame (aspect-fill)
    ///   • Dark gradient sweeps from transparent → 85% black across the bottom 55%
    ///   • Fortis shield sits small and centred near the top of the photo
    ///   • A frosted panel (semi-transparent dark + gold border) covers the bottom ~38%
    ///     and contains: workout name / muscle map / 2×2 stats / hashtags
    private func generateShareImage(background: UIImage?, muscleMap: UIImage?) -> UIImage {
        let W: CGFloat = 1080
        let H: CGFloat = 1920
        let canvasSize = CGSize(width: W, height: H)

        let panelTopFraction: CGFloat = 0.62
        var blurredPanelBg: UIImage? = nil
        if let bg = background {
            blurredPanelBg = blurRegion(of: bg,
                                        panelTopFraction: panelTopFraction,
                                        canvasSize: canvasSize)
        }
        _ = blurredPanelBg

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // ── Full-canvas photo (aspect-fill) ──────────────────────────────
            UIColor(red: 0.11, green: 0.07, blue: 0, alpha: 1).setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: W, height: H))

            var drawnBgRect = CGRect(origin: .zero, size: canvasSize)
            if let bg = background {
                let imgRect = aspectFillRect(imageSize: bg.size, targetSize: canvasSize)
                bg.draw(in: imgRect)
                drawnBgRect = imgRect
                UIColor.black.withAlphaComponent(0.30).setFill()
                UIRectFill(CGRect(origin: .zero, size: canvasSize))
            }

            let blurredBackground = background.flatMap { blurImage($0, radius: 30) }

            // ── Top branding ─────────────────────────────────────────────────
            let shieldSize: CGFloat = 80
            let shieldX = (W - shieldSize) / 2
            let shieldY: CGFloat = 72
            let logoRect = CGRect(x: shieldX - 24, y: shieldY - 18, width: shieldSize + 48, height: shieldSize + 72)
            if let blurred = blurredBackground {
                cgCtx.saveGState()
                let logoPath = UIBezierPath(roundedRect: logoRect, cornerRadius: 28)
                logoPath.addClip()
                blurred.draw(in: drawnBgRect)
                cgCtx.restoreGState()
                UIColor(white: 0.04, alpha: 0.35).setFill()
                logoPath.fill()
            }
            drawShield(in: cgCtx, rect: CGRect(x: shieldX, y: shieldY, width: shieldSize, height: shieldSize))

            let fortisAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .black),
                .foregroundColor: UIColor(red: 0.83, green: 0.57, blue: 0.04, alpha: 1),
                .kern: 10
            ]
            let fortisStr = "FORTIS" as NSString
            let fortisW = fortisStr.size(withAttributes: fortisAttrs).width
            fortisStr.draw(at: CGPoint(x: (W - fortisW) / 2, y: shieldY + shieldSize + 10), withAttributes: fortisAttrs)

            // ── Stats overlay panel ──────────────────────────────────────────
            let panelMargin: CGFloat = 48
            let panelTop: CGFloat = shieldY + shieldSize + 86
            let panelH: CGFloat = 540
            let panelRect = CGRect(x: panelMargin, y: panelTop, width: W - panelMargin * 2, height: panelH)
            let panelPath = UIBezierPath(roundedRect: panelRect, cornerRadius: 28)

            if let blurred = blurredBackground {
                cgCtx.saveGState()
                panelPath.addClip()
                blurred.draw(in: drawnBgRect)
                cgCtx.restoreGState()
            } else {
                UIColor.black.withAlphaComponent(0.72).setFill()
                panelPath.fill()
            }

            UIColor(red: 0.83, green: 0.57, blue: 0.04, alpha: 0.65).setStroke()
            panelPath.lineWidth = 2
            panelPath.stroke()

            // ── Panel content (flows top-to-bottom) ──────────────────────────
            let cX = panelRect.minX + 26
            let cW = panelRect.width - 52
            var cY = panelRect.minY + 22

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            let titleH = (session.name as NSString).boundingRect(
                with: CGSize(width: cW, height: .infinity),
                options: .usesLineFragmentOrigin, attributes: titleAttrs, context: nil
            ).height
            (session.name as NSString).draw(
                with: CGRect(x: cX, y: cY, width: cW, height: titleH),
                options: .usesLineFragmentOrigin, attributes: titleAttrs, context: nil
            )
            cY += titleH + 14

            let gold = UIColor(red: 0.83, green: 0.57, blue: 0.04, alpha: 0.5)
            gold.setStroke()
            let sepPath = UIBezierPath()
            sepPath.move(to: CGPoint(x: cX, y: cY))
            sepPath.addLine(to: CGPoint(x: cX + cW, y: cY))
            sepPath.lineWidth = 1.5
            sepPath.stroke()
            cY += 14

            let mapH = cW * (280.0 / 960.0)
            if let mapImg = muscleMap {
                cgCtx.saveGState()
                UIBezierPath(roundedRect: CGRect(x: cX, y: cY, width: cW, height: mapH), cornerRadius: 12).addClip()
                mapImg.draw(in: CGRect(x: cX, y: cY, width: cW, height: mapH))
                cgCtx.restoreGState()
            }
            cY += mapH + 16

            gold.setStroke()
            let sep2 = UIBezierPath()
            sep2.move(to: CGPoint(x: cX, y: cY))
            sep2.addLine(to: CGPoint(x: cX + cW, y: cY))
            sep2.lineWidth = 1.5
            sep2.stroke()
            cY += 14

            let col1X = cX
            let col2X = cX + cW / 2 + 6
            let colW  = cW / 2 - 6

            drawStatBlock(label: "DURATION",     value: durationFormatted,                    x: col1X, y: cY,       width: colW, in: cgCtx)
            drawStatBlock(label: "TOTAL VOLUME", value: volumeFormatted,                      x: col2X, y: cY,       width: colW, in: cgCtx)
            drawStatBlock(label: "EXERCISES",    value: "\(session.workoutExercises.count)",   x: col1X, y: cY + 88, width: colW, in: cgCtx)
            drawStatBlock(label: "TOTAL SETS",   value: "\(session.totalSets)",               x: col2X, y: cY + 88, width: colW, in: cgCtx)

            let hashAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.40)
            ]
            let hashStr = "#Fortis  #WorkoutComplete  #Fitness" as NSString
            let hashW = hashStr.size(withAttributes: hashAttrs).width
            hashStr.draw(at: CGPoint(x: (W - hashW) / 2, y: panelRect.maxY - 34), withAttributes: hashAttrs)
        }
    }

    /// Crops the region of `image` that maps to the panel area on the canvas,
    /// then applies a Gaussian blur — used for the frosted glass panel background.
    private func blurRegion(of image: UIImage, panelTopFraction: CGFloat, canvasSize: CGSize) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        // Map the panel rect back to image-pixel coordinates (accounting for aspect-fill offset)
        let fillRect = aspectFillRect(imageSize: image.size, targetSize: canvasSize)
        let scaleX = image.size.width  / fillRect.width
        let scaleY = image.size.height / fillRect.height
        let imgPanelY = (canvasSize.height * panelTopFraction - fillRect.minY) * scaleY
        let cropRect = CGRect(
            x: 0,
            y: max(0, imgPanelY),
            width: image.size.width,
            height: image.size.height - max(0, imgPanelY)
        )
        guard cropRect.height > 0, let cropped = cgImage.cropping(to: cropRect) else { return nil }

        let ci = CIImage(cgImage: cropped)
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = ci
        blur.radius = 24

        guard let output = blur.outputImage else { return nil }
        let ciCtx = CIContext()
        guard let result = ciCtx.createCGImage(output, from: ci.extent) else { return nil }
        return UIImage(cgImage: result)
    }

    // MARK: - Draw helpers

    private func drawStatBlock(label: String, value: String, x: CGFloat, y: CGFloat, width: CGFloat, in ctx: CGContext) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .bold),
            .foregroundColor: UIColor(red: 0.83, green: 0.57, blue: 0.04, alpha: 0.85),
            .kern: 2.5
        ]
        (label as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: labelAttrs)

        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 38, weight: .heavy),
            .foregroundColor: UIColor.white
        ]
        (value as NSString).draw(
            with: CGRect(x: x, y: y + 26, width: width, height: 56),
            options: .usesLineFragmentOrigin,
            attributes: valueAttrs,
            context: nil
        )
    }

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
            ForEach(workoutExercise.sets.sorted { $0.setNumber < $1.setNumber }) { set in
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
        HStack(spacing: 20) {
            highlightedBodyView(side: .front).frame(maxWidth: .infinity)
            highlightedBodyView(side: .back).frame(maxWidth: .infinity)
        }
        .padding(12)
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
