---
type: epic
title: "The new app ships from CI"
parent: initiative-capacitor-supabase-port
covers: [R23]
sources: []
companions: []
after: []
refined: false
risk: high
---

# The new app ships from CI

## Description

A Capacitor web build and iOS shell live in a new app/ folder beside the untouched Flutter app, the iOS project taking over bundle com.academic-tools.fermi and its build numbers, with the app/src/api/ client and its error map (AD-17); a new deploy workflow replaces 02_deploy_web.yml and, on a push to main, applies Supabase migrations, pushes the hosted Auth config and sets Realtime private-only, deploys edge functions, builds, packages the live update with its minimum native build (AD-18), deploys the fermi-plus Worker from an assets-only wrangler.jsonc on workers.dev, which replaces wrangler.toml and passes a health check that also asserts the Auth and Realtime config, with sign-up off until epic 2's hook exists (AD-21); the empty app and internal schemas, pg_cron, pg_net and pgtap, the job-health check the keep-alive calls, the job-failure table, the privilege fixture and its catalog test exist (AD-3); access-policy and edge-function tests run in CI; scheduled workflows keep the Free project awake and take a weekly encrypted backup (K18); an iOS build installed through TestFlight internal testing offers to restart onto each new deploy. Every later epic builds on this pipeline.

## Outcome

Every later epic ships by pushing to main: the website on workers.dev and the TestFlight iOS build update themselves with no hand deploy, and the Free Supabase project stays awake and backed up (initiative K7, K18, R23).

## Done when

- A push to main runs migrations, the Auth config push, the Realtime private-only setting, edge functions, build, live-update packaging, wrangler deploy and a health check that asserts the hosted config, with no hand step
- The workers.dev site serves the Capacitor web build from an assets-only `wrangler.jsonc`, and `wrangler.toml` with `src/index.js` and the fermi-plus.com route is gone
- Access-policy, privilege-fixture and edge-function tests run in CI and fail the run when they fail
- The keep-alive and weekly backup workflows run on schedule, and the backup restores into a throwaway local database
- A TestFlight build on the owner's iPhone offers to restart onto the next deploy, and skips a bundle above its native build

## Boundaries

- Out: any user-facing feature; the landing page is epic-invite-sign-in's
- Out: removing Flutter or the old workflows other than 02_deploy_web.yml (epic-app-store-release)
- Out: the sign-in hook and its health-check assertion (epic-invite-sign-in)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R23, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-3, AD-17, AD-18, AD-20, AD-21, Structural Seed, Stack
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 1 Platform baseline, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md
