#!/usr/bin/env bash
#
# Regenerates Wingman/Lesson/lesson_questions_seed.json from Supabase.
#
# WHAT THE SEED IS FOR
#   The app ships this file so a fresh, offline, or not-yet-signed-in install
#   still has end-of-lesson questions. It is a cold-start floor, NOT the source
#   of truth: the moment a device completes one successful sync, its snapshot
#   becomes authoritative wholesale and this file is never consulted again on
#   that device (see LessonQuestionStore.loadQuestions).
#
#   So this does NOT gate content edits. Editing questions in Supabase reaches
#   users on their next sync, with no app update. Regenerating the seed only
#   changes what a brand-new install sees in the window before its first sync.
#   Run it before cutting a release; skipping it is a staleness bug, not an
#   outage.
#
# USAGE
#   SUPABASE_SERVICE_ROLE_KEY=... ./supabase/scripts/generate_lesson_question_seed.sh
#   ./supabase/scripts/generate_lesson_question_seed.sh --verify   # no key needed
#
#   --verify re-checks the committed seed's shape and lesson coverage without
#   touching the network. Cheap to run in CI.
#
#   The service role key is read from the environment and never written to disk
#   or echoed. Get it from the Supabase dashboard under Project Settings → API.
#   It is required because RLS on `questions` grants SELECT to `authenticated`
#   only — the publishable key reads as `anon` and returns an empty array with a
#   200, which is exactly the silent-empty case the app now guards against.
#
set -euo pipefail

PROJECT_REF="bnckmgnysfliiypvxxii"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SEED_PATH="$REPO_ROOT/Wingman/Lesson/lesson_questions_seed.json"
LESSON_JSON_DIR="$REPO_ROOT/Wingman/Courses/Wingman Lessons"

VERIFY_ONLY=0
[[ "${1:-}" == "--verify" ]] && VERIFY_ONLY=1

if [[ "$VERIFY_ONLY" -eq 0 ]]; then
  if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
    echo "error: SUPABASE_SERVICE_ROLE_KEY is not set." >&2
    echo "       Supabase dashboard → Project Settings → API → service_role key." >&2
    echo "       Or run with --verify to check the committed seed without fetching." >&2
    exit 1
  fi

  echo "Fetching lesson questions from $PROJECT_REF…"

  # Column list and filters mirror LessonQuestionService.fetchAllLessonQuestions()
  # exactly. If that query changes, change this one in the same commit — a seed
  # shaped differently from what the app fetches would decode into a different
  # set than a synced device holds.
  RAW="$(curl -sS --fail-with-body \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    "https://$PROJECT_REF.supabase.co/rest/v1/questions\
?select=id,lesson_id,lesson_quiz_order,question_type,question_text,options,correct_answer_index,correct_answer_indices,explanation\
&lesson_id=not.is.null\
&lesson_quiz_order=not.is.null\
&order=lesson_id.asc,lesson_quiz_order.asc\
&limit=10000")"

  printf '%s' "$RAW" | python3 -c '
import json, sys

rows = json.load(sys.stdin)
if not rows:
    sys.exit("error: server returned 0 rows. A service_role key is required; an "
             "anon key returns [] with a 200 for this table.")

grouped = {}
for r in rows:
    q = {
        # Uppercased to match Swift JSONEncoder, which is what writes the
        # on-device snapshot. UUID decoding is case-insensitive either way, but
        # matching keeps this file byte-stable across regenerations so a diff
        # shows real content changes only.
        "id": r["id"].upper(),
        "number": r["lesson_quiz_order"],
        "question": r["question_text"],
        "options": r["options"],
        "questionType": r["question_type"],
        "explanation": r["explanation"],
    }
    # Omitted rather than null when absent, matching Swift synthesized Codable,
    # which encodes optionals with encodeIfPresent.
    if r.get("correct_answer_index") is not None:
        q["correctAnswerIndex"] = r["correct_answer_index"]
    if r.get("correct_answer_indices") is not None:
        q["correctAnswerIndices"] = r["correct_answer_indices"]
    grouped.setdefault(r["lesson_id"], []).append(q)

for qs in grouped.values():
    qs.sort(key=lambda q: q["number"])

with open(sys.argv[1], "w") as f:
    json.dump(grouped, f, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    f.write("\n")
' "$SEED_PATH"

  echo "Wrote $(wc -c < "$SEED_PATH" | tr -d ' ') bytes to ${SEED_PATH#"$REPO_ROOT/"}"
fi

# ---------------------------------------------------------------------------
# Validation. Runs after a fetch and on its own under --verify.
# ---------------------------------------------------------------------------
python3 - "$SEED_PATH" "$LESSON_JSON_DIR" <<'PY'
import json, sys, glob, os

seed_path, lesson_dir = sys.argv[1], sys.argv[2]

if not os.path.exists(seed_path):
    sys.exit(f"error: seed not found at {seed_path}")

with open(seed_path) as f:
    seed = json.load(f)

questions = [q for qs in seed.values() for q in qs]
problems = []

REQUIRED = {"id", "number", "question", "options", "questionType", "explanation"}
for lesson_id, qs in seed.items():
    for q in qs:
        missing = REQUIRED - set(q)
        if missing:
            problems.append(f"{lesson_id}: question missing {sorted(missing)}")
        if q.get("questionType") not in ("single_select", "multiple_select"):
            problems.append(f"{lesson_id}: bad questionType {q.get('questionType')!r}")
        if ("correctAnswerIndex" not in q) and ("correctAnswerIndices" not in q):
            problems.append(f"{lesson_id}: no answer key")
        if not isinstance(q.get("options"), list) or not q["options"]:
            problems.append(f"{lesson_id}: options is not a non-empty list")
    if [q["number"] for q in qs] != sorted(q["number"] for q in qs):
        problems.append(f"{lesson_id}: questions are not ordered by number")

# Coverage: every lesson the app can open should have questions in the seed.
# A gap is not fatal — that lesson simply falls through to the completion screen
# until the device syncs — but it is almost always an authoring oversight.
app_lesson_ids = set()
for path in glob.glob(os.path.join(lesson_dir, "**", "*.json"), recursive=True):
    with open(path) as f:
        try:
            for lesson in json.load(f):
                app_lesson_ids.add(lesson["id"])
        except (ValueError, KeyError, TypeError):
            pass  # not a lesson file

uncovered = sorted(app_lesson_ids - set(seed))
orphaned = sorted(set(seed) - app_lesson_ids)

print(f"seed: {len(seed)} lessons, {len(questions)} questions")
print(f"app:  {len(app_lesson_ids)} lessons found in bundled JSON")
if uncovered:
    print(f"warning: {len(uncovered)} app lesson(s) have no questions: {uncovered}")
if orphaned:
    print(f"warning: {len(orphaned)} seed lesson(s) are not in the app: {orphaned}")

if problems:
    print("\n".join(f"error: {p}" for p in problems[:20]), file=sys.stderr)
    if len(problems) > 20:
        print(f"error: … and {len(problems) - 20} more", file=sys.stderr)
    sys.exit(1)

print("validation passed")
PY
