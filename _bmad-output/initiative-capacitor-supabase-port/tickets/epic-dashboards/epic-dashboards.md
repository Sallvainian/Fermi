---
type: epic
title: "Dashboards show real data"
parent: initiative-capacitor-supabase-port
covers: [R19]
sources: []
companions: []
after: []
refined: false
risk: low
---

# Dashboards show real data

## Description

A teacher's dashboard shows assignment stats and recent activity; a student's shows upcoming assignments, recent grades, assignment stats and GPA; every widget reads views over data epics 4, 7 and 8 write and epic 4's grade-summary function, and writes none of its own.

## Outcome

Dashboards show each role's real numbers instead of empty widgets (initiative R19).

## Done when

- On the deployed site, a teacher's and a student's dashboards show their real stats, activity, upcoming work, recent grades and GPA from data the other epics write

## Boundaries

- Out: writing any new data; widgets only read

## References

- parent — _bmad-output/initiative-capacitor-supabase-port/initiative-capacitor-supabase-port.md, Requirements R19, Constraints
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/architecture-capacitor-supabase-port.md, AD-3, Consistency Conventions (shared data shapes)
- architecture — _bmad-output/initiative-capacitor-supabase-port/architecture-capacitor-supabase-port/epic-map-capacitor-supabase-port.md, Ownership row 11 Dashboards, Seams to watch
- companion — _bmad-output/initiative-capacitor-supabase-port/parity-inventory.md

## Notes

- Waits on epic-assignments-grades because: assignments, submissions, grades and the grade-summary function
- Waits on epic-boards-announcements because: posts for recent activity
- Waits on epic-behavior-points because: points for recent activity
