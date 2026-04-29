import SwiftData
import Foundation

enum ExerciseService {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let exercises = allExercises()
        exercises.forEach { context.insert($0) }

        try? context.save()
        print("✅ Seeded \(exercises.count) exercises")
    }

    static func allExercises() -> [Exercise] {
        return chest() + back() + shoulders() + biceps() + triceps() + legs() + glutes() + core()
    }

    // MARK: - Chest (8 exercises)
    private static func chest() -> [Exercise] {[
        Exercise(name: "Barbell Bench Press", category: "Chest", equipmentType: "Barbell",
                 primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps", "Front Deltoid"],
                 instructions: "Lie flat on bench, grip bar slightly wider than shoulder-width. Lower bar to mid-chest, press explosively."),
        Exercise(name: "Incline Barbell Bench Press", category: "Chest", equipmentType: "Barbell",
                 primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps", "Front Deltoid"],
                 instructions: "Set bench to 30-45°. Press bar from upper chest upward."),
        Exercise(name: "Decline Barbell Bench Press", category: "Chest", equipmentType: "Barbell",
                 primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps"],
                 instructions: "Set bench to -15°. Targets lower chest fibers."),
        Exercise(name: "Dumbbell Bench Press", category: "Chest", equipmentType: "Dumbbell",
                 primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps", "Front Deltoid"],
                 instructions: "Press dumbbells from chest level overhead with a slight arc inward."),
        Exercise(name: "Incline Dumbbell Press", category: "Chest", equipmentType: "Dumbbell",
                 primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps", "Front Deltoid"],
                 instructions: "Bench at 30-45°. Press dumbbells up and slightly inward."),
        Exercise(name: "Cable Fly", category: "Chest", equipmentType: "Cable",
                 primaryMuscles: ["Chest"], secondaryMuscles: ["Front Deltoid"],
                 instructions: "Set cables to shoulder height. Bring handles together in front of chest in an arc."),
        Exercise(name: "Pec Deck Machine", category: "Chest", equipmentType: "Machine",
                 primaryMuscles: ["Chest"], secondaryMuscles: [],
                 instructions: "Sit with back against pad. Bring arms together squeezing chest at peak contraction."),
        Exercise(name: "Push-Up", category: "Chest", equipmentType: "Bodyweight",
                 primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps", "Core"],
                 instructions: "Hands shoulder-width apart. Lower chest to ground, press back up keeping core tight."),
    ]}

    // MARK: - Back (9 exercises)
    private static func back() -> [Exercise] {[
        Exercise(name: "Barbell Deadlift", category: "Back", equipmentType: "Barbell",
                 primaryMuscles: ["Back"], secondaryMuscles: ["Glutes", "Legs", "Core"],
                 instructions: "Hinge at hips with neutral spine. Drive through heels to lift bar."),
        Exercise(name: "Barbell Bent-Over Row", category: "Back", equipmentType: "Barbell",
                 primaryMuscles: ["Back"], secondaryMuscles: ["Biceps", "Rear Deltoid"],
                 instructions: "Hinge 45° forward. Pull bar to lower chest, keeping elbows close."),
        Exercise(name: "Pull-Up", category: "Back", equipmentType: "Bodyweight",
                 primaryMuscles: ["Back"], secondaryMuscles: ["Biceps"],
                 instructions: "Dead hang grip. Pull until chin clears bar, lower under control."),
        Exercise(name: "Lat Pulldown", category: "Back", equipmentType: "Cable",
                 primaryMuscles: ["Back"], secondaryMuscles: ["Biceps"],
                 instructions: "Grip bar wide. Pull to upper chest, leaning slightly back."),
        Exercise(name: "Seated Cable Row", category: "Back", equipmentType: "Cable",
                 primaryMuscles: ["Back"], secondaryMuscles: ["Biceps", "Rear Deltoid"],
                 instructions: "Pull handle to abdomen, driving elbows back. Squeeze at peak."),
        Exercise(name: "Dumbbell Single-Arm Row", category: "Back", equipmentType: "Dumbbell",
                 primaryMuscles: ["Back"], secondaryMuscles: ["Biceps"],
                 instructions: "Brace on bench. Pull dumbbell to hip, elbow grazing side of body."),
        Exercise(name: "T-Bar Row", category: "Back", equipmentType: "Machine",
                 primaryMuscles: ["Back"], secondaryMuscles: ["Biceps", "Rear Deltoid"],
                 instructions: "Straddle bar, grip handle. Row to lower chest keeping chest against pad."),
        Exercise(name: "Straight-Arm Pulldown", category: "Back", equipmentType: "Cable",
                 primaryMuscles: ["Back"], secondaryMuscles: ["Core"],
                 instructions: "Keep arms nearly straight. Pull bar from head height to thighs."),
        Exercise(name: "Machine Row", category: "Back", equipmentType: "Machine",
                 primaryMuscles: ["Back"], secondaryMuscles: ["Biceps"],
                 instructions: "Adjust seat and chest pad. Row handles to sides keeping back neutral."),
    ]}

    // MARK: - Shoulders (7 exercises)
    private static func shoulders() -> [Exercise] {[
        Exercise(name: "Barbell Overhead Press", category: "Shoulders", equipmentType: "Barbell",
                 primaryMuscles: ["Shoulders"], secondaryMuscles: ["Triceps", "Core"],
                 instructions: "Press bar from chin to overhead. Do not hyperextend lower back."),
        Exercise(name: "Dumbbell Shoulder Press", category: "Shoulders", equipmentType: "Dumbbell",
                 primaryMuscles: ["Shoulders"], secondaryMuscles: ["Triceps"],
                 instructions: "Press dumbbells from ear level overhead. Palms face forward."),
        Exercise(name: "Dumbbell Lateral Raise", category: "Shoulders", equipmentType: "Dumbbell",
                 primaryMuscles: ["Shoulders"], secondaryMuscles: [],
                 instructions: "Raise arms to shoulder height, slight bend in elbow. Lead with elbows."),
        Exercise(name: "Dumbbell Front Raise", category: "Shoulders", equipmentType: "Dumbbell",
                 primaryMuscles: ["Shoulders"], secondaryMuscles: [],
                 instructions: "Raise one arm at a time to shoulder height. Keep slight elbow bend."),
        Exercise(name: "Cable Lateral Raise", category: "Shoulders", equipmentType: "Cable",
                 primaryMuscles: ["Shoulders"], secondaryMuscles: [],
                 instructions: "Set cable low. Cross cable and raise arm to shoulder height."),
        Exercise(name: "Machine Shoulder Press", category: "Shoulders", equipmentType: "Machine",
                 primaryMuscles: ["Shoulders"], secondaryMuscles: ["Triceps"],
                 instructions: "Adjust seat so handles are at ear level. Press overhead."),
        Exercise(name: "Face Pull", category: "Shoulders", equipmentType: "Cable",
                 primaryMuscles: ["Shoulders"], secondaryMuscles: ["Rear Deltoid"],
                 instructions: "Rope attachment at face height. Pull to forehead, rotating wrists out."),
    ]}

    // MARK: - Biceps (6 exercises)
    private static func biceps() -> [Exercise] {[
        Exercise(name: "Barbell Curl", category: "Biceps", equipmentType: "Barbell",
                 primaryMuscles: ["Biceps"], secondaryMuscles: ["Forearms"],
                 instructions: "Stand with bar at thighs. Curl to chin keeping elbows fixed at sides."),
        Exercise(name: "Dumbbell Curl", category: "Biceps", equipmentType: "Dumbbell",
                 primaryMuscles: ["Biceps"], secondaryMuscles: ["Forearms"],
                 instructions: "Alternate arms or curl together. Supinate wrist as you lift."),
        Exercise(name: "Hammer Curl", category: "Biceps", equipmentType: "Dumbbell",
                 primaryMuscles: ["Biceps"], secondaryMuscles: ["Forearms", "Brachialis"],
                 instructions: "Neutral grip (thumbs up). Curl dumbbell to shoulder."),
        Exercise(name: "EZ Bar Curl", category: "Biceps", equipmentType: "EZ Bar",
                 primaryMuscles: ["Biceps"], secondaryMuscles: ["Forearms"],
                 instructions: "Use angled grip on EZ bar. Curl to chin, squeeze at top."),
        Exercise(name: "Cable Curl", category: "Biceps", equipmentType: "Cable",
                 primaryMuscles: ["Biceps"], secondaryMuscles: [],
                 instructions: "Stand facing cable stack. Curl bar or rope attachment to chin."),
        Exercise(name: "Preacher Curl", category: "Biceps", equipmentType: "Machine",
                 primaryMuscles: ["Biceps"], secondaryMuscles: [],
                 instructions: "Arms braced on pad. Curl from full extension to peak contraction."),
    ]}

    // MARK: - Triceps (6 exercises)
    private static func triceps() -> [Exercise] {[
        Exercise(name: "Tricep Pushdown", category: "Triceps", equipmentType: "Cable",
                 primaryMuscles: ["Triceps"], secondaryMuscles: [],
                 instructions: "Elbows at sides. Push bar down to thighs, fully extending arms."),
        Exercise(name: "Skull Crusher", category: "Triceps", equipmentType: "Barbell",
                 primaryMuscles: ["Triceps"], secondaryMuscles: [],
                 instructions: "Lower bar to forehead by bending elbows. Press back to lockout."),
        Exercise(name: "Overhead Tricep Extension", category: "Triceps", equipmentType: "Dumbbell",
                 primaryMuscles: ["Triceps"], secondaryMuscles: [],
                 instructions: "Hold dumbbell overhead with both hands. Lower behind head, extend."),
        Exercise(name: "Dip", category: "Triceps", equipmentType: "Bodyweight",
                 primaryMuscles: ["Triceps"], secondaryMuscles: ["Chest", "Shoulders"],
                 instructions: "Keep torso upright to target triceps. Lower until arms at 90°."),
        Exercise(name: "Rope Pushdown", category: "Triceps", equipmentType: "Cable",
                 primaryMuscles: ["Triceps"], secondaryMuscles: [],
                 instructions: "Flare handles at bottom of movement for full tricep extension."),
        Exercise(name: "Close-Grip Bench Press", category: "Triceps", equipmentType: "Barbell",
                 primaryMuscles: ["Triceps"], secondaryMuscles: ["Chest"],
                 instructions: "Grip bar shoulder-width. Lower to chest, press with elbows tucked."),
    ]}

    // MARK: - Legs (9 exercises)
    private static func legs() -> [Exercise] {[
        Exercise(name: "Barbell Back Squat", category: "Legs", equipmentType: "Barbell",
                 primaryMuscles: ["Legs"], secondaryMuscles: ["Glutes", "Core"],
                 instructions: "Bar on traps, feet shoulder-width. Squat to parallel or below, drive up."),
        Exercise(name: "Leg Press", category: "Legs", equipmentType: "Machine",
                 primaryMuscles: ["Legs"], secondaryMuscles: ["Glutes"],
                 instructions: "Feet shoulder-width on platform. Lower sled until 90°, press up."),
        Exercise(name: "Hack Squat", category: "Legs", equipmentType: "Machine",
                 primaryMuscles: ["Legs"], secondaryMuscles: ["Glutes"],
                 instructions: "Place feet low on platform. Lower under control, press to lockout."),
        Exercise(name: "Romanian Deadlift", category: "Legs", equipmentType: "Barbell",
                 primaryMuscles: ["Legs"], secondaryMuscles: ["Glutes", "Back"],
                 instructions: "Hinge at hips with slight knee bend. Lower bar along legs, feel hamstring stretch."),
        Exercise(name: "Leg Curl", category: "Legs", equipmentType: "Machine",
                 primaryMuscles: ["Legs"], secondaryMuscles: [],
                 instructions: "Curl pad to glutes. Pause at peak, lower with control."),
        Exercise(name: "Leg Extension", category: "Legs", equipmentType: "Machine",
                 primaryMuscles: ["Legs"], secondaryMuscles: [],
                 instructions: "Extend legs to lockout. Squeeze quads at top of movement."),
        Exercise(name: "Barbell Lunge", category: "Legs", equipmentType: "Barbell",
                 primaryMuscles: ["Legs"], secondaryMuscles: ["Glutes"],
                 instructions: "Bar on traps. Step forward, lower back knee toward floor."),
        Exercise(name: "Goblet Squat", category: "Legs", equipmentType: "Dumbbell",
                 primaryMuscles: ["Legs"], secondaryMuscles: ["Glutes", "Core"],
                 instructions: "Hold dumbbell at chest. Squat deep keeping torso upright."),
        Exercise(name: "Walking Lunge", category: "Legs", equipmentType: "Dumbbell",
                 primaryMuscles: ["Legs"], secondaryMuscles: ["Glutes"],
                 instructions: "Hold dumbbells at sides. Step forward alternating legs."),
    ]}

    // MARK: - Glutes (5 exercises)
    private static func glutes() -> [Exercise] {[
        Exercise(name: "Barbell Hip Thrust", category: "Glutes", equipmentType: "Barbell",
                 primaryMuscles: ["Glutes"], secondaryMuscles: ["Legs"],
                 instructions: "Upper back on bench, bar on hips. Drive hips up, squeeze at top."),
        Exercise(name: "Cable Kickback", category: "Glutes", equipmentType: "Cable",
                 primaryMuscles: ["Glutes"], secondaryMuscles: [],
                 instructions: "Attach ankle strap. Kick leg back, squeezing glute at extension."),
        Exercise(name: "Dumbbell Hip Thrust", category: "Glutes", equipmentType: "Dumbbell",
                 primaryMuscles: ["Glutes"], secondaryMuscles: ["Legs"],
                 instructions: "Hold dumbbell on hips. Drive hips to ceiling, pause at top."),
        Exercise(name: "Sumo Deadlift", category: "Glutes", equipmentType: "Barbell",
                 primaryMuscles: ["Glutes"], secondaryMuscles: ["Legs", "Back"],
                 instructions: "Wide stance, toes pointed out. Pull bar close to body."),
        Exercise(name: "Abductor Machine", category: "Glutes", equipmentType: "Machine",
                 primaryMuscles: ["Glutes"], secondaryMuscles: [],
                 instructions: "Sit with legs on pads. Push knees outward against resistance."),
    ]}

    // MARK: - Core (6 exercises)
    private static func core() -> [Exercise] {[
        Exercise(name: "Cable Crunch", category: "Core", equipmentType: "Cable",
                 primaryMuscles: ["Core"], secondaryMuscles: [],
                 instructions: "Kneel facing cable. Pull rope down, crunching abs to hips."),
        Exercise(name: "Plank", category: "Core", equipmentType: "Bodyweight",
                 primaryMuscles: ["Core"], secondaryMuscles: ["Shoulders"],
                 instructions: "Forearms on floor, body in straight line. Hold for time."),
        Exercise(name: "Hanging Leg Raise", category: "Core", equipmentType: "Bodyweight",
                 primaryMuscles: ["Core"], secondaryMuscles: [],
                 instructions: "Hang from bar. Raise legs to 90° or higher, lower with control."),
        Exercise(name: "Ab Wheel Rollout", category: "Core", equipmentType: "Bodyweight",
                 primaryMuscles: ["Core"], secondaryMuscles: ["Shoulders"],
                 instructions: "Roll out until parallel to floor, brace core to return."),
        Exercise(name: "Russian Twist", category: "Core", equipmentType: "Bodyweight",
                 primaryMuscles: ["Core"], secondaryMuscles: [],
                 instructions: "Feet off ground, lean back 45°. Twist torso side to side."),
        Exercise(name: "Decline Sit-Up", category: "Core", equipmentType: "Bodyweight",
                 primaryMuscles: ["Core"], secondaryMuscles: [],
                 instructions: "Feet secured on decline bench. Full range of motion sit-ups."),
    ]}
}
