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

A Capacitor web build and iOS shell live in a new app/ folder beside the untouched Flutter app, the iOS project taking over bundle com.academic-tools.fermi and its build numbers; a new deploy workflow replaces 02_deploy_web.yml and, on a push to main, applies Supabase migrations, deploys edge functions, builds, packages the live update, deploys the fermi-plus Worker (wrangler.toml rewritten to assets only on workers.dev) and passes the health check; access-policy and edge-function tests run in CI; an iOS build installed through TestFlight internal testing offers to restart onto each new deploy. Every later epic builds on this pipeline.

## Outcome

Every later epic ships by pushing to main: the website on workers.dev and the TestFlight iOS build update themselves with no hand deploy (initiative K7, R23).

## Done when

- A push to main runs migrations, edge functions, build, live-update packaging, wrangler deploy and the health check from CI, with no hand step
- The workers.dev site serves the Capacitor web build, and `src/index.js` and the fermi-plus.com route are gone from `wrangler.toml`
- Access-policy and edge-function tests run in CI and fail the run when they fail
- A TestFlight build on the owner's iPhone offers to restart onto the next deploy

## Boundaries

- Out: any user-facing feature; the landing page is epic-invite-sign-in's
- Out: removing Flutter or the old workflows other than 02_deploy_web.yml (epic-app-store-release)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R23, Constraints
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md
