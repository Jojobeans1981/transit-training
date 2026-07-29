# FutureEng Project Context (Handoff Prompt)

Paste this whole file into a new LLM/chat session to bring it up to speed on the FutureEng project, then add your specific request at the bottom.

## What FutureEng Is

A white-label training platform: admins configure an "industry" (a system prompt + uploaded training material), and Claude generates quizzes, study guides, and scenario exercises from that material for end users to work through. Built solo by Giuseppe Panetta, currently local-only (not yet deployed live, not yet in git).

## Tech Stack

- Frontend: React + Vite + Tailwind CSS
- Backend: a single Vercel serverless function (`api/generate-material.js`)
- Database + Auth: Supabase (Postgres + built-in auth)
- AI: Anthropic Claude API (`@anthropic-ai/sdk`), model `claude-opus-4-1`
- State: Zustand (`src/stores/authStore.js`)
- Deployment target: Vercel (project already linked — `.vercel/` exists — but not yet pushed to git; no git repo initialized in this folder yet)

## Actual File Layout (verified 2026-07-28)

```
api/generate-material.js   - POST endpoint, calls Claude, returns {quiz|guide|scenario}
src/lib/claude.js          - frontend wrapper: generateQuiz/generateStudyGuide/generateScenario -> fetch('/api/generate-material')
src/lib/supabase.js        - supabase client + db helper object (see schema below)
src/stores/authStore.js    - zustand auth state
src/pages/Login.jsx
src/pages/AdminDashboard.jsx
src/pages/UserDashboard.jsx
src/components/ProtectedRoute.jsx
complete-setup.sh          - the original scaffolding script that generated the whole project
```

## Real Database Schema (from src/lib/supabase.js, not guessed)

- `admins` (user_id, email)
- `users` (user_id, email, full_name, industry_id)
- `industries` (admin_id, name, system_prompt)
- `training_materials` (industry_id, admin_id, file_name, file_path, file_size)
- `generated_materials` (training_material_id, material_type, content)
- `leaderboard` (industry_id, total_score, ...) — read-only view/table, ordered by total_score

RLS policies on these tables have not been independently verified in this session — confirm in the Supabase dashboard before relying on that claim.

## Environment Variables (real names, verified against `.env.local` / `.env.example`)

| Variable | Prefix | Visibility | Used by |
|---|---|---|---|
| `VITE_SUPABASE_URL` | VITE_ | Public (browser) | frontend `src/lib/supabase.js` |
| `VITE_SUPABASE_ANON_KEY` | VITE_ | Public (browser) | frontend |
| `CLAUDE_API_KEY` | none | Private (server only) | `api/generate-material.js` |
| `VITE_APP_NAME`, `VITE_APP_DESCRIPTION`, `VITE_THEME_PRIMARY`, `VITE_THEME_HEADER_BG` | VITE_ | Public | branding/white-label config |

The "never prefix a secret with `VITE_`" rule is correctly followed as of this check — `CLAUDE_API_KEY` has no `VITE_` prefix, so it stays server-side only. `.env.local` and `.env` are both correctly listed in `.gitignore`.

## Bugs Found & Fixed This Session

**`api/generate-material.js` was corrupted.** It contained literal Windows shell error text ("The AT command has been deprecated. Please use schtasks.exe instead. / The binding handle is invalid.") instead of the actual handler code — almost certainly from a stray command whose stderr/stdout got redirected into the file at some point. This meant the entire quiz/study-guide/scenario generation feature was silently broken (any request to `/api/generate-material` would have failed to even parse as JS). Restored from the known-good source embedded in `complete-setup.sh` (lines 873-974). **If you're picking this up fresh, verify `npm run dev` + a real generate-material request now works before assuming this feature is done.**

## Lessons From Earlier Sessions (why the dev process changed)

1. Built incrementally with no upfront architecture plan → wasted time on `.env` vs `.env.local` confusion and Vercel Functions not reading the API key.
2. Had to be reminded of the `VITE_` secret-exposure rule.
3. Assumed Supabase RLS/storage/policies existed before they did → repeated stop-fix-retry cycles.
4. Wrote code against Claude API / Supabase / Vercel Functions before confirming those connections worked, making failures hard to diagnose.
5. Built several features before testing any of them, so a broken piece (see bug above) went unnoticed.

## Process Going Forward: Three Skills

Three skill docs were authored to prevent repeats of the above (currently at `/mnt/skills/user/*.md` in the environment where they were written — if you're in a different Claude Code setup, port the content into this project's `CLAUDE.md` or `.claude/skills/`):

**`architecture-planning.md`** — template for a full system design doc (diagram, env var table, Supabase checklist, API endpoint specs, data flows, error table) to produce before writing code on anything non-trivial.

**`code-review-agent.md`** — T-shirt-sizes every feature request:
- **LARGE** (auth, schema, payments, API redesign): Phase 1 architecture doc → Phase 2 smoke tests → Phase 3 code-structure review → Phase 4 incremental build, with user sign-off at each phase.
- **SMALL** (button, styling, layout, single input): skip phases 1-2, go straight to a one-paragraph code plan, then build and test immediately.

**`pre-build-validation.md`** — for LARGE features only, four lightweight smoke tests to run *before* writing feature code: Supabase `SELECT 1` ping, a 5-token Claude API ping, an env-var presence check, and an RLS-enabled check on the relevant tables. If any fail, stop and fix infra before coding.

**Working agreement:** for any new feature request, size it first (LARGE vs SMALL), run only the phases that size requires, and stop for explicit user sign-off at each phase rather than building ahead of confirmation.

## Current State / What's Left

Working (per code present, not independently load-tested beyond the fix above):
- Auth (signup/login), admin dashboard shell, user dashboard shell, protected routing
- Supabase client + db helpers for all 6 tables above
- `/api/generate-material` endpoint (just restored — needs a real end-to-end test)

Not yet verified or likely incomplete:
- End-to-end generation test (upload → generate → store in `generated_materials`)
- Leaderboard UI wiring to the `leaderboard` table
- AI tutor interface, badge/achievement system (mentioned as goals, no files found for them yet)
- No git repository has been initialized for this project yet

---

**My request:** [fill in what you want the next LLM/session to do]
