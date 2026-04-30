#!/usr/bin/env python3
"""
convert_exercises.py
Downloads the free-exercise-db dataset and converts it to Fortis Exercise
model format, saving exercises.json into the Xcode project's Resources folder.

Usage:
    python3 convert_exercises.py
    python3 convert_exercises.py --input /path/to/exercises.json   # use cached copy
"""

import argparse
import json
import os
import urllib.request

SOURCE_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"
OUT_PATH   = "Fortis - Train Heavy/Fortis - Train Heavy/Resources/ExerciseData/exercises.json"

# ── Muscle normalisation ──────────────────────────────────────────────────────
# Maps the source dataset's muscle names to the values used by our MuscleGroup enum.
MUSCLE_MAP = {
    "abdominals":   "Core",
    "abductors":    "Glutes",
    "adductors":    "Legs",
    "biceps":       "Biceps",
    "calves":       "Calves",
    "chest":        "Chest",
    "forearms":     "Forearms",
    "glutes":       "Glutes",
    "hamstrings":   "Legs",
    "lats":         "Back",
    "lower back":   "Back",
    "middle back":  "Back",
    "neck":         "Back",
    "quadriceps":   "Legs",
    "shoulders":    "Shoulders",
    "traps":        "Back",
    "triceps":      "Triceps",
}

# ── Equipment normalisation ───────────────────────────────────────────────────
# Maps the source equipment strings to our EquipmentType enum values.
EQUIPMENT_MAP = {
    "barbell":       "Barbell",
    "dumbbell":      "Dumbbell",
    "machine":       "Machine",
    "cable":         "Cable",
    "body only":     "Bodyweight",
    "e-z curl bar":  "EZ Bar",
    "kettlebells":   "Kettlebell",
    "bands":         "Resistance Bands",
    "exercise ball": "Machine",    # closest gym equivalent
    "medicine ball": "Machine",
    "foam roll":     "Bodyweight",
    "other":         "Bodyweight",
    "":              "Bodyweight",
}


def normalise_muscles(muscles) -> list:  # muscles: list[str]
    """Map source muscle names → our enum values, deduplicate, preserve order."""
    seen = set()
    result = []
    for m in muscles:
        mapped = MUSCLE_MAP.get(m.lower(), m.title())
        if mapped not in seen:
            seen.add(mapped)
            result.append(mapped)
    return result


def normalise_equipment(raw) -> str:  # raw: str | None
    key = (raw or "").strip().lower()
    return EQUIPMENT_MAP.get(key, "Bodyweight")


def derive_category(primary_muscles: list[str]) -> str:
    """Use the first primary muscle's mapped value as the exercise category."""
    if not primary_muscles:
        return "Other"
    return MUSCLE_MAP.get(primary_muscles[0].lower(), primary_muscles[0].title())


def convert(source: list[dict]) -> list[dict]:
    converted = []
    for ex in source:
        name = ex.get("name", "").strip()
        if not name:
            continue

        raw_primary   = ex.get("primaryMuscles") or []
        raw_secondary = ex.get("secondaryMuscles") or []
        raw_instr     = ex.get("instructions") or []

        primary   = normalise_muscles(raw_primary)
        secondary = normalise_muscles(raw_secondary)

        # Remove muscles already listed in primary from secondary
        secondary = [m for m in secondary if m not in set(primary)]

        category      = derive_category(raw_primary)
        equipment     = normalise_equipment(ex.get("equipment"))
        instructions  = " ".join(step.strip() for step in raw_instr if step.strip())

        converted.append({
            "name":             name,
            "category":         category,
            "equipmentType":    equipment,
            "primaryMuscles":   primary,
            "secondaryMuscles": secondary,
            "instructions":     instructions,
            "isCustom":         False,
        })

    return converted


def main():
    parser = argparse.ArgumentParser(description="Convert free-exercise-db → Fortis format")
    parser.add_argument("--input", help="Path to local exercises.json (skips download)")
    args = parser.parse_args()

    # Load source data
    if args.input:
        print(f"Reading from {args.input}")
        with open(args.input) as f:
            source = json.load(f)
    else:
        print(f"Downloading from {SOURCE_URL} …")
        with urllib.request.urlopen(SOURCE_URL) as r:
            source = json.loads(r.read().decode())

    print(f"Source exercises: {len(source)}")

    converted = convert(source)
    print(f"Converted:        {len(converted)}")

    # Print category breakdown
    from collections import Counter
    cats = Counter(e["category"] for e in converted)
    for cat, n in sorted(cats.items()):
        print(f"  {cat:<14} {n}")

    # Write output
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        json.dump(converted, f, indent=2, ensure_ascii=False)

    size_kb = os.path.getsize(OUT_PATH) / 1024
    print(f"\nSaved {len(converted)} exercises → {OUT_PATH}  ({size_kb:.0f} KB)")


if __name__ == "__main__":
    main()
