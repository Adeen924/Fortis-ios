import SwiftUI
import SwiftData
import UIKit
import CoreImage
import PhotosUI
import MuscleMap

struct PersonalRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let reps: Int
    let weight: Double
    let previousMax: Double
}

struct WorkoutSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSettings: AppSettings
    let session: WorkoutSession
    let onDismiss: () -> Void

    @Query private var profiles: [UserProfile]
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var pastSessions: [WorkoutSession]

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
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    pickedImage = uiImage
                    backgroundImage = uiImage
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

    // MARK: - Image Generation

    /// Renders the MuscleMapView to a UIImage using ImageRenderer.
    /// Must be called on the MainActor. Uses a query-free variant to avoid
    /// SwiftData context issues inside ImageRenderer.
    @MainActor
    private func renderMuscleMapImage() -> UIImage? {
        let gender = profiles.first?.gender ?? "male"
        let mapView = ShareMuscleMapView(
            primaryMuscles: combinedPrimaryMuscles,
            secondaryMuscles: combinedSecondaryMuscles,
            gender: gender
        )
        .frame(width: 960, height: 520)
        .background(Color.clear)

        let renderer = ImageRenderer(content: mapView)
        renderer.scale = 2.0
        return renderer.uiImage
    }

    /// Composites a 1080×1920 (9:16) shareable image.
    /// Background: user photo (aspect-fill) with darkening overlay.
    /// Middle: muscle map rendered from ShareMuscleMapView.
    /// Bottom: semi-transparent stats panel with workout data.
    private func generateShareImage(background: UIImage?, muscleMap: UIImage?) -> UIImage {
        let width: CGFloat = 1080
        let height: CGFloat = 1920
        let size = CGSize(width: width, height: height)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // ── Background ──────────────────────────────────────────────────
            UIColor(red: 0.11, green: 0.07, blue: 0, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            var drawnBgRect = CGRect(origin: .zero, size: size)
            if let bg = background {
                let imgRect = aspectFillRect(imageSize: bg.size, targetSize: size)
                bg.draw(in: imgRect)
                drawnBgRect = imgRect
                UIColor.black.withAlphaComponent(0.30).setFill()
                UIRectFill(CGRect(origin: .zero, size: size))
            }

            let blurredBackground = background.flatMap { blurImage($0, radius: 30) }

            // ── Top branding ─────────────────────────────────────────────────
            let shieldSize: CGFloat = 80
            let shieldX = (width - shieldSize) / 2
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
                .font: UIFont.systemFont(ofSize: 28, weight: .black),
                .foregroundColor: UIColor(red: 0.83, green: 0.57, blue: 0.04, alpha: 1),
                .kern: 12
            ]
            let fortisStr = "FORTIS" as NSString
            let fortisSize = fortisStr.size(withAttributes: fortisAttrs)
            fortisStr.draw(
                at: CGPoint(x: (width - fortisSize.width) / 2, y: shieldY + shieldSize + 14),
                withAttributes: fortisAttrs
            )

            // ── Stats overlay panel ──────────────────────────────────────────
            let panelMargin: CGFloat = 48
            let panelTop: CGFloat = shieldY + shieldSize + 86
            let panelH: CGFloat = 540
            let panelRect = CGRect(x: panelMargin, y: panelTop, width: width - panelMargin * 2, height: panelH)

            if let blurred = blurredBackground {
                cgCtx.saveGState()
                let panelPath = UIBezierPath(roundedRect: panelRect, cornerRadius: 28)
                panelPath.addClip()
                blurred.draw(in: drawnBgRect)
                cgCtx.restoreGState()
            }

            let panelPath = UIBezierPath(roundedRect: panelRect, cornerRadius: 28)
            UIColor(white: 0.05, alpha: 0.45).setFill()
            panelPath.fill()
            UIColor(red: 0.83, green: 0.57, blue: 0.04, alpha: 0.8).setStroke()
            panelPath.lineWidth = 2.5
            panelPath.stroke()

            // Workout title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            let titleStr = session.name as NSString
            let titleBounds = titleStr.boundingRect(
                with: CGSize(width: panelRect.width - 56, height: .infinity),
                options: .usesLineFragmentOrigin,
                attributes: titleAttrs,
                context: nil
            )
            titleStr.draw(
                with: CGRect(x: panelRect.minX + 28, y: panelRect.minY + 24,
                             width: panelRect.width - 56, height: titleBounds.height),
                options: .usesLineFragmentOrigin,
                attributes: titleAttrs,
                context: nil
            )

            let contentTop = panelRect.minY + 24 + titleBounds.height + 18
            let leftWidth = panelRect.width * 0.45
            let rightX = panelRect.minX + leftWidth + 20
            let rightWidth = panelRect.width - leftWidth - 40
            let mapHeight: CGFloat = 400
            let mapRect = CGRect(x: panelRect.minX + 24, y: contentTop, width: leftWidth, height: mapHeight)

            if let mapImg = muscleMap {
                cgCtx.saveGState()
                let clipPath = UIBezierPath(roundedRect: mapRect, cornerRadius: 22)
                clipPath.addClip()
                mapImg.draw(in: mapRect)
                cgCtx.restoreGState()

                UIColor(white: 0, alpha: 0.18).setFill()
                UIBezierPath(roundedRect: mapRect, cornerRadius: 22).fill()
            }

            let statTitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor(white: 0.95, alpha: 0.9),
                .kern: 1.5
            ]
            let statValueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 38, weight: .heavy),
                .foregroundColor: UIColor.white
            ]

            let statLabels = ["DURATION", "TOTAL VOLUME", "EXERCISES", "TOTAL SETS"]
            let statValues = [durationFormatted, volumeFormatted, "\(session.workoutExercises.count)", "\(session.totalSets)"]
            let statYStart = contentTop
            let statLineHeight: CGFloat = 90
            for index in 0..<statLabels.count {
                let rowY = statYStart + CGFloat(index) * statLineHeight
                let labelStr = statLabels[index] as NSString
                labelStr.draw(at: CGPoint(x: rightX, y: rowY), withAttributes: statTitleAttrs)
                let valueStr = statValues[index] as NSString
                valueStr.draw(
                    with: CGRect(x: rightX, y: rowY + 28, width: rightWidth, height: 56),
                    options: .usesLineFragmentOrigin,
                    attributes: statValueAttrs,
                    context: nil
                )
            }

            // Hashtag footer
            let hashAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.55)
            ]
            let hashStr = "#Fortis  #WorkoutComplete  #Fitness" as NSString
            let hashSz = hashStr.size(withAttributes: hashAttrs)
            hashStr.draw(
                at: CGPoint(x: (width - hashSz.width) / 2, y: panelRect.maxY - 44),
                withAttributes: hashAttrs
            )
        }
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
        .padding(16)
        .background(Color(red: 0.15, green: 0.10, blue: 0.02))
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
