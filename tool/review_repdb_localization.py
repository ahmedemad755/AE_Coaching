"""Apply the recorded contextual name review and report actual Arabic coverage.

Only app-local text changes. Never changes official JSON, artwork, mapping or Hive.
Instruction review cannot be inferred from the presence of Arabic text.
"""
import argparse
import hashlib
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def context_hash(row):
    return hashlib.sha256(json.dumps({k: row.get(k) for k in
        ("id", "name_en", "equipment", "description_en")},
        sort_keys=True, ensure_ascii=False).encode("utf-8")).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply-name-review", action="store_true")
    parser.add_argument("--apply-instruction-review", action="store_true")
    args = parser.parse_args()
    source = read("lib/assets/repdb/exercises.json")["exercises"]
    overlay = read("lib/assets/repdb/ar.json")
    review = read("tool/repdb_arabic_name_review.json")
    assert overlay["dataset_commit"] == review["dataset_commit"]
    assert len(source) == review["reviewed_count"] == 701
    assert set(overlay["exercises"]) == {"repdb:" + row["id"] for row in source}
    if args.apply_name_review:
        for row in source:
            canonical = "repdb:" + row["id"]
            entry = overlay["exercises"][canonical]
            entry["name_ar"] = review["corrections"].get(canonical, entry["name_ar"])
            entry["name_review_status"] = "context_reviewed"
            entry["name_review_source_sha256"] = context_hash(row)
    if args.apply_instruction_review:
        instructions = read("tool/repdb_arabic_reviewed_instructions.json")
        assert instructions["dataset_commit"] == overlay["dataset_commit"]
        by_id = {"repdb:" + row["id"]: row for row in source}
        for canonical, steps in instructions["exercises"].items():
            original = by_id[canonical]["instructions_en"]
            assert len(steps) == len(original) and all(isinstance(s, str) and s.strip() for s in steps), canonical
            entry = overlay["exercises"][canonical]
            entry["instructions_ar"] = steps
            entry["review_status"] = "reviewed"
            entry["tips_review_status"] = "translation_pending"
            entry["instruction_review_source_sha256"] = hashlib.sha256(
                json.dumps(original, ensure_ascii=False).encode("utf-8")).hexdigest()
    if args.apply_name_review or args.apply_instruction_review:
        (ROOT / "lib/assets/repdb/ar.json").write_text(
            json.dumps(overlay, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    duplicate_names = defaultdict(list)
    names_reviewed = []
    instructions_complete = []
    instructions_reviewed = []
    gaps = []
    for row in source:
        canonical = "repdb:" + row["id"]
        ar = overlay["exercises"][canonical]
        duplicate_names[ar["name_ar"]].append(canonical)
        if ar.get("name_review_status") == "context_reviewed" and ar.get("name_review_source_sha256") == context_hash(row):
            names_reviewed.append(canonical)
        en = row.get("instructions_en", [])
        translated = ar.get("instructions_ar", [])
        complete = len(translated) == len(en) and all(translated)
        if complete:
            instructions_complete.append(canonical)
        reviewed_source = hashlib.sha256(json.dumps(en, ensure_ascii=False).encode("utf-8")).hexdigest()
        if complete and ar.get("review_status") == "reviewed" and ar.get("instruction_review_source_sha256") == reviewed_source:
            instructions_reviewed.append(canonical)
        else:
            gaps.append({"exercise_id": canonical, "name_en": row["name_en"],
                "english_steps": len(en), "arabic_steps": len(translated),
                "status": ar.get("review_status", "unknown")})
    report = {"dataset_commit": overlay["dataset_commit"], "total_exercises": len(source),
        "english_instruction_steps": sum(len(row.get("instructions_en", [])) for row in source),
        "arabic_names_authored": len(overlay["exercises"]), "arabic_names_context_reviewed": len(names_reviewed),
        "arabic_instructions_complete": len(instructions_complete),
        "arabic_instructions_reviewed": len(instructions_reviewed),
        "arabic_instruction_steps_reviewed": sum(len(overlay["exercises"][key]["instructions_ar"]) for key in instructions_reviewed),
        "arabic_tip_translation_exercises": sum(bool(row.get("tips_ar")) for row in overlay["exercises"].values()),
        "instruction_gaps": gaps,
        "duplicate_arabic_names": {name: ids for name, ids in duplicate_names.items() if len(ids) > 1},
        "complete": len(names_reviewed) == len(instructions_reviewed) == len(source)}
    (ROOT / "docs/repdb-translation-coverage.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in report.items() if k not in ("instruction_gaps", "duplicate_arabic_names")}))
    print("Duplicate Arabic names:", report["duplicate_arabic_names"])


if __name__ == "__main__":
    main()
