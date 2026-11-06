---
type: epic
title: "Behavior points"
parent: initiative-capacitor-supabase-port
covers: [R7]
sources: []
companions: []
after: []
refined: false
risk: low
---

# Behavior points

## Description

On epic 3's classes and checks, a teacher manages a class's behaviors, awards and undoes points, and sees totals and filtered history; a student sees only their own points and history, and loses them when removed from the class; an archived class takes no new points. Hands points to epic 11 for recent activity.

## Outcome

Teachers track behavior points, and students see only their own (initiative R7).

## Done when

- On the deployed site, a teacher manages behaviors, awards and undoes points, and sees totals and filtered history
- A student sees only their own points and history, and automated checks refuse reading a classmate's or awarding points in an archived class
- A `bmad-tea-trace` run at closure maps each Requirements line to passing tests, and its gate is PASS or each gap has a waiver in Notes

## Boundaries

- Out: dashboard widgets (epic-dashboards)

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R7, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-2, AD-4, AD-9
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 8 Behavior points, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-classes-rosters because: classes, enrollment and the class checks
- Decision: 2026-11-06, `bmad-tea-test-design` runs on this epic at epic level during its refinement, after its Requirements are written and before its stories are planned; its test plan is adopted as a companion, each story names the scenarios it covers, and the plan settles whether the epic closes with an end-to-end suite
