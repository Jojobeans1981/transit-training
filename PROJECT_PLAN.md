# FutureEng Project Plan

Maintained by the `project-planning-critique` skill. This file is refreshed, not appended to — each run re-verifies Current State against the actual repo/app and rewrites all four sections below.

Last verified: 2026-07-29

## 1. North Star

**FutureEng is an engine, not a multi-tenant app.** This repo is the template that gets deployed as a separate variant app per industry/customer — each deployment serves exactly one industry, configured at deploy time (branding via env vars, training content + system prompt specific to that customer). Confirmed directly with the user 2026-07-29.

Within one deployed instance: an admin manages that single industry's training material and system prompt, the platform generates quizzes/study guides/scenario exercises from it, and trainees who sign up work through that material, take quizzes, earn badges, climb a leaderboard, and can consult an AI tutor.

**This directly changes what "done" looks like for the signup gap below** — a trainee never picks an industry at signup, because a given deployment only ever has one. The fix is auto-association, not a picker.

### Reference target (concrete, from a working prior build)

A base44 build (`nycdot-dispatcher-exam-prep`) already implements this concept for the NYC DOT industry variant, and its source (`README_DEVELOPER.jsx`/`README_USER.jsx`, pasted into this session 2026-07-29) gives an actual bar to hit instead of a vague feature list:

**Pages:** Dashboard, StudyManual, QuizPractice, AITutor, Leaderboard, Badges

**Entities (this is the real data shape to match, not FutureEng's current one):**
- `QuizQuestion` — individual questions tagged by category (they had ~100), not one JSON blob per upload
- `StudySection` — searchable study content by category, markdown `content` + `key_points` array, `is_placeholder` flag
- `Badge` — 12 badges, tiered (bronze/silver/gold/platinum), e.g. "First Quiz," "Quiz Veteran," "Perfect Score," "Unstoppable"
- `UserBadge` — join table, badges earned per user
- `UserProgress` — quiz stats, streaks, scores
- `LeaderboardEntry` — live rankings

**Mechanics (from the user-facing FAQ):**
- Quiz flow: pick a category (or all) + question count → answer each → **immediate per-question feedback with explanation** → score shown → result auto-saved
- Scoring: 10 points per correct answer; accuracy % tracked; total score drives leaderboard rank
- Streaks: ≥1 quiz/day maintains a streak; longer streaks unlock badges and show on the leaderboard
- Badges: earned automatically from activity (quiz completion, correct-answer count, streaks, perfect scores) — not manually assigned
- AI Tutor: answers questions about the job, generates realistic practice scenarios, explains concepts — a chat-style interface
- 10 topic categories for this specific industry (Radio Communications, Emergency Procedures, Route Knowledge, Scheduling & Operations, Safety Protocols, Customer Service, Regulations & Compliance, Equipment & Systems, Incident Management, Crew Coordination) — industry-specific, would differ per deployed variant

## 2. Current State (verified this session, not carried over from memory)

**Working, real, end-to-end verified:**
- Admin auth (signup/login/logout) via Supabase, role-based routing (`ProtectedRoute.jsx`)
- Admin creates an "industry" (name + system prompt), stored in `industries` table
- Admin uploads a training file → stored in Supabase Storage + `training_materials` row
- Upload triggers quiz generation via Groq (`llama-3.1-8b-instant`) → stored in `generated_materials` (confirmed via direct SQL query against the actual row)

**Exists in code but has no path to ever run:**
- `userSignUp()` in `authStore.js` hardcodes `industryId: null`. In the one-industry-per-deployment model this *shouldn't* need a signup-time picker — but nothing auto-fills it either. There is currently no concept anywhere in the code of "the industry this deployment belongs to" (no env var, no config lookup, no single-row assumption). Every signed-up user still ends up with `industry_id: null` regardless of intent.
- Bigger mismatch: the admin dashboard lets one admin create *multiple* industries (`industries` table is `admin_id` → many rows) and switch between them via a list. That's multi-tenant scaffolding built for a model that isn't the target. In a one-industry-per-deployment world, "Industries" shouldn't be a creatable list at all — it should be at most one row (or a config value), with the admin UI showing "your industry's settings," not "create another industry."
- `generateStudyGuide()` and `generateScenario()` in `src/lib/claude.js`, and the matching `study_guide`/`scenario` branches in `api/generate-material.js`, have zero callers. Only the `quiz` path is wired from the UI.
- `db.getLeaderboard()` in `supabase.js` is never called anywhere.
- `config.features.{enableTutor,enableLeaderboard,enableBadges,enableStudyManual}` are hardcoded `true` and never read by any component.
- `config.theme.{primary,headerBg}` are never consumed — every page uses hardcoded Tailwind classes (`bg-black`, `bg-blue-600`) instead.

**Pure placeholder (looks like UI, does nothing):**
- `UserDashboard.jsx`: "Quizzes Completed: 0" and "Average Score: --" are hardcoded, not queries. "Quiz Practice" / "Study Manual" / "AI Tutor" are `<div>`s styled to look clickable (`cursor-pointer`) with no `onClick`. The leaderboard panel is static placeholder text.
- No quiz-taking UI exists anywhere — quizzes are generated and stored, but no trainee can ever see or take one.

**Infrastructure:**
- Git repo initialized and pushed to `github.com/Jojobeans1981/transit-training` this session.
- Local dev requires `vercel dev` (not plain `vite`) because `/api/*` is a Vercel serverless function — this caused real confusion this session (three different ports/instances running simultaneously before being cleaned up).
- `GROQ_API_KEY` lives in local `.env` only. Not confirmed present in the actual Vercel project's cloud environment variables — deploying today would likely reproduce the exact "key not found" failure we just spent time debugging locally, except in production.
- Supabase project dashboard shows this is the **PRODUCTION** branch/environment — all of this session's manual testing (including ~13 throwaway `training_materials` rows created while debugging) happened directly against it. No dev/staging separation exists.
- RLS policies on any table have not been independently verified this session (no query run against `pg_policies`) — their existence is assumed from an earlier, unverified claim.

## 3. Gap Analysis

| North Star piece | Gap |
|---|---|
| Trainees consume this deployment's content | No signup path ever sets `industry_id`, and there's no notion of "the one industry this deployment is for" to auto-fill it with — the content-generation pipeline has no reachable consumer |
| One-industry-per-deployment model | Admin dashboard/schema still model many industries per admin — mismatched with the confirmed target architecture |
| Study guides + scenarios | Backend supports it, nothing calls it — 2/3 of the generation feature is dead code |
| Quiz-taking experience (category picker, per-question feedback+explanation, scoring) | Doesn't exist. Content is generated and stored with nowhere to go |
| Quiz data shape (`QuizQuestion` rows, filterable by category/count) | Current schema stores one opaque JSON blob per upload in `generated_materials` — can't filter by category or reuse/pool individual questions without parsing the blob every time |
| Study Manual (searchable, by category) | No `StudySection`-equivalent exists; `study_guide` generation type exists server-side but has no caller and no searchable-by-category structure |
| Streaks + scoring (10 pts/correct, accuracy %, daily streak) | No `UserProgress`-equivalent table or logic exists at all |
| Leaderboard | Table + query helper exist, nothing populates or renders it; no live/real-time behavior |
| Badges (12, tiered, auto-earned) | Feature flag exists, zero implementation, zero `Badge`/`UserBadge`-equivalent schema |
| AI tutor (chat, scenario generation) | Feature flag + non-functional UI list item exist, zero implementation |
| White-label theming | Env vars + config object exist, zero components read them |
| Safe local dev loop | No single documented "run this one command" workflow; `vite` alone silently fails to serve `/api/*` |
| Safe to deploy | Cloud env vars unconfirmed; no dev/staging Supabase separation |

## 4. Critique (the roast)

- **The core loop doesn't close.** You just spent this session getting quiz generation working end-to-end, but a trainee can never reach it — nothing in the code knows "the one industry this deployment is for," so `industry_id` is permanently `null` for every user account. This isn't a rough edge, it's a missing weld in the middle of the pipeline.
- **The schema was built for the wrong tenancy model.** `industries` is `admin_id` → many rows, with a UI for creating and switching between them. That's architecture for a multi-tenant app. The confirmed target is one-industry-per-deployment, where that entire list-and-switch UI shouldn't exist — there should be at most one industry, configured once, not created repeatedly through a form.
- **The dashboard is a stage set.** `UserDashboard.jsx` has hover states, cursor pointers, and metric cards that all imply a working product. None of it is wired to anything. Anyone clicking around would reasonably conclude more is built than actually is.
- **You're testing against production.** The Supabase project is tagged `PRODUCTION` in its own dashboard, and today's debugging left ~13 junk rows in `training_materials`. If this project ever gets a second admin or a real customer, today's session would have been polluting their environment. There is currently no dev/staging Supabase project.
- **Config that configures nothing.** `enableTutor`, `enableLeaderboard`, `enableBadges`, `enableStudyManual`, and the entire `theme` object exist purely to look like the app is more configurable than it is. Either wire them up or delete them — half-wired feature flags are worse than none, because they read as intentional gates when they're actually just unused constants.
- **Unused dependencies as unwritten IOUs.** `recharts`, `framer-motion`, `react-hook-form`, `zod`, `@hookform/resolvers`, `lucide-react`, `@tanstack/react-query` are all installed, none are imported anywhere in `src`. Either there's a plan to use each of these soon, or they're dead weight inflating install size and signaling planned work that isn't actually scheduled.
- **The deploy path is untested and will probably break the same way local dev did.** You burned real time today on `CLAUDE_API_KEY`/`GROQ_API_KEY` not being visible to the function process locally. Nothing suggests the Vercel cloud project has `GROQ_API_KEY` set — if it doesn't, the first production request will 500 in exactly the way you just fixed locally, except a real user will see it.
- **The data model doesn't match the actual target.** Now that there's a concrete reference, it's clear `generated_materials` (one opaque JSON blob per upload) can't cleanly support what "Quiz Practice" actually needs: pick a category, pick a count, pull matching questions, give per-question feedback, track which ones were missed. That needs individual `QuizQuestion` rows, queryable by category — not a blob you'd have to parse and re-slice every time. Building the quiz-taking UI directly on top of today's schema means rebuilding it again once category filtering or question reuse comes up. This is a decision to make deliberately, not discover mid-build.
- **Two-thirds of the generation feature was built and is untestable by design.** `study_guide` and `scenario` types are fully implemented server-side with no frontend caller. That's effort spent on a feature nobody can currently exercise, verify, or notice if it silently breaks.
- **Dev workflow fragility bit you today and will bite again.** Plain `npm run dev` (`vite`) doesn't serve `/api/*` at all — only `vercel dev` does. This isn't written down anywhere in the repo, so the next session (you, a collaborator, or another LLM) can easily repeat today's multi-port chaos.

## 5. Prioritized Next Steps (pick one, don't build ahead of a decision)

1. **[SMALL, unblocks everything else] Auto-associate every signup with this deployment's one industry.** No picker needed — the deployment has exactly one industry. Needs a way to know which `industries` row that is (e.g. an env var like `VITE_INDUSTRY_ID`, or a "there is only ever one row" query), then pass it through to `userSignUp()`/`db.createUser()`. Pairs naturally with simplifying the admin dashboard's "create industry" list down to a single industry-settings panel. Without this, nothing built after it has a real user to serve.
2. **[LARGE, decide before building] Redesign the quiz data model to match the reference target**: a `quiz_questions` table (category, question, options, correct answer, explanation) instead of one JSON blob per upload — Groq generates questions that get inserted as rows, not a single opaque object. This is what makes category-filtered quizzes, per-question feedback, and question reuse possible. Do this *before* #3, not after — building the quiz UI on the current blob shape means redoing it here later.
3. **[LARGE] Build the actual quiz-taking UI**: category + count picker, one question at a time, immediate feedback + explanation per answer, score at the end (10 pts/correct), save a `UserProgress`-equivalent result. This is the first feature that would make the product demoable to a non-technical person — but depends on #2's shape being right first.
4. **[SMALL] Confirm/set `GROQ_API_KEY` in the Vercel cloud project's env vars** and do one real deployment, before more local features pile up on an unverified deploy path.
5. **[SMALL] Document the dev workflow** (`vercel dev`, not `vite`, is required) in a `README.md` or `CLAUDE.md` — five minutes now prevents another session like today's port confusion.

Not recommended yet: badges, streaks, AI tutor, leaderboard UI, theming — all downstream of #1/#2/#3, and building them now would be more decoration on top of a pipeline that doesn't reach a user yet.

---
**Your call:** which of the above (or something else) do you want to tackle next?
