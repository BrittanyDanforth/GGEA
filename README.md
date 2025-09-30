# THE LONG SIREN

Offline interactive fiction prototype for a grounded outbreak drama. This repository bundles the narrative database and engine into a single JavaScript file for local play and validation.

## Running locally

Open `debug_test.html` in any modern browser. The page loads `MYSTORY.js` and `MYSTORY.CSS` directly without network calls. Use the control buttons in the UI to start a new game, continue from autosave, or import/export save files.

## Narrative architecture

The story database uses the following conventions:

- Scene IDs follow `<route>_act<1-5>_<type>_<slug>` (for example `good_act2_setpiece_holdline`).
- Each scene provides short, present-tense prose (≤ 140 words) and at least two meaningful choices unless it is an ending.
- Choices declare requirements (`req`), costs (`cost`), and effects (`effects`) so the engine can display gating information and apply consequences consistently.
- Global mutex groups ensure mutually exclusive faction alignments and endgame plans.

The engine performs strict validation on load, runs a random-walk coverage check, and exposes helper functions (`runConsequenceCoverage`) for additional QA.

## Credits

Design direction, world bible, and narrative scaffolding follow the "Long Siren" brief supplied with this repository.
