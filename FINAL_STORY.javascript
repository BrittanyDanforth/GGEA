;(() => {
  /** @typedef {{
   *   id: string,
   *   text: string,
   *   tags?: string[],
   *   isEnding?: boolean,
   *   // optional UI flavor lines
   *   personaFlavor?: { ruthless?: string, compassionate?: string, survivalist?: string, scholar?: string },
   *   // choices gated by preconditions; each must have effects and/or goTo
   *   choices: Array<{
   *     id?: string,
   *     text: string,
   *     goTo?: string,
   *     type?: "moral"|"combat"|"social"|"stealth",
   *     consequence?: "major"|"minor"|"ripple",
   *     // PRE: must be satisfied to enable click
   *     pre?: {
   *       flagsAll?: string[],    // all of these flags must be set
   *       flagsNone?: string[],   // none of these flags may be set
   *       min?: Partial<Record<"strength"|"agility"|"willpower"|"charisma"|"morality"|"stress"|"trauma", number>>,
   *       max?: Partial<Record<"stress"|"trauma", number>>,
   *       hasItems?: string[],
   *     },
   *     // If PRE fails, show why and disable
   *     blockedReason?: string,
   *     // EFFECTS: must produce a real delta (state or navigation)
   *     effects?: {
   *       setFlags?: string[],
   *       clearFlags?: string[],
   *       addItems?: string[],
   *       removeItems?: string[],
   *       delta?: Partial<Record<"strength"|"agility"|"willpower"|"charisma"|"morality"|"stress"|"trauma", number>>,
   *       // deferred ripples resolved after N steps
   *       schedule?: Array<{ steps: number, apply: { setFlags?: string[], clearFlags?: string[], delta?: any, pushEvent?: string } }>,
   *       pushEvent?: string // for event log
   *     }
   *   }>
   * }} Scene
   */

  // ========= SAMPLE: embed your DB here =========
  window.STORY_DATABASE = /** @type {Record<string, Scene>} */ ({
    intro: {
      id: "intro",
      text: "Sirens fade. The city rots. You wake to pounding on your door.",
      choices: [
        {
          text: "Barricade the door and arm yourself.",
          type: "combat",
          consequence: "minor",
          effects: { setFlags: ["door_barricaded"], delta: { stress: +3, willpower: +1 }, pushEvent: "You brace the door" },
          goTo: "apt_search"
        },
        {
          text: "Open and call for survivors.",
          type: "social",
          pre: { max: { stress: 60 } },
          blockedReason: "You’re too shaken to think clearly.",
          consequence: "ripple",
          effects: { setFlags: ["met_neighbor"], delta: { morality: +2, stress: -2 }, pushEvent: "You risk contact" },
          goTo: "hallway_meet"
        },
        {
          text: "Slip out the window fire escape.",
          type: "stealth",
          effects: { delta: { agility: +1, stress: +1 }, pushEvent: "You climb into the ash" },
          goTo: "alley_exit"
        }
      ]
    },

    apt_search: {
      id: "apt_search",
      text: "Inside, you scavenge your apartment in the dark.",
      choices: [
        {
          text: "Take the first-aid kit (adds MedKit).",
          effects: { addItems: ["MedKit"], pushEvent: "You pocket a MedKit" },
          goTo: "apt_after_loot"
        },
        {
          text: "You… do nothing. (DEV should flag this as useless)", // will fail audit
          // no effects and no goTo => engine will mark as invalid in dev/audit
        }
      ]
    },

    apt_after_loot: {
      id: "apt_after_loot",
      text: "You’ve got what you can carry. Where now?",
      choices: [
        {
          text: "Try the stairwell.",
          effects: { delta: { stress: +2 } },
          goTo: "stairwell_ambush"
        },
        {
          text: "Backtrack to the window.",
          pre: { flagsAll: ["door_barricaded"] },
          effects: { delta: { stress: +1 } },
          goTo: "alley_exit"
        }
      ]
    },

    hallway_meet: {
      id: "hallway_meet",
      text: "A neighbor peeks out, bleeding. “I can help you if you help me.”",
      choices: [
        {
          text: "Stabilize them (uses MedKit if you have one; big morale bump).",
          pre: { hasItems: ["MedKit"] },
          effects: { removeItems: ["MedKit"], delta: { morality: +6, stress: -4 }, setFlags: ["neighbor_saved"] },
          goTo: "ally_join"
        },
        {
          text: "Use them as bait and run.",
          type: "moral",
          consequence: "major",
          effects: { setFlags: ["ruthless_reputation"], delta: { morality: -6, stress: -1, trauma: +4 }, pushEvent: "You chose survival over mercy" },
          goTo: "stairwell_ambush"
        }
      ]
    },

    alley_exit: {
      id: "alley_exit",
      text: "The alley yawns open. You hear guttural clicks nearby.",
      choices: [
        {
          text: "Sprint (Agility 50+).",
          pre: { min: { agility: 50 } },
          blockedReason: "You’re not quick enough yet.",
          effects: { delta: { stress: +2 }, setFlags: ["escaped_alley"] },
          goTo: "street_crossroads"
        },
        {
          text: "Hide in the dumpster.",
          type: "stealth",
          effects: { delta: { stress: +1, trauma: +1 }, pushEvent: "You hold your breath" },
          goTo: "alley_wait"
        }
      ]
    },

    stairwell_ambush: {
      id: "stairwell_ambush",
      text: "Something lunges on the landing.",
      choices: [
        {
          text: "Fight through.",
          type: "combat",
          effects: {
            delta: { strength: +1, stress: +3, trauma: +2 },
            schedule: [{ steps: 2, apply: { delta: { trauma: +2 }, pushEvent: "Wounds throb later" } }]
          },
          goTo: "street_crossroads"
        },
        {
          text: "Shove it over the rail (ruthless).",
          type: "moral",
          effects: { setFlags: ["ruthless_reputation"], delta: { morality: -3, stress: +1 } },
          goTo: "street_crossroads"
        }
      ]
    },

    alley_wait: {
      id: "alley_wait",
      text: "Minutes crawl. Footsteps pass. You re-emerge.",
      choices: [
        { text: "Head for the street.", goTo: "street_crossroads" }
      ]
    },

    street_crossroads: {
      id: "street_crossroads",
      text: "Smoke toward downtown; radio chatter to the docks; a clinic sign flickers north.",
      choices: [
        { text: "Downtown fires (hard mode).", effects: { setFlags: ["route_downtown"] }, goTo: "chapter_downtown" },
        { text: "Shipyard radio (faction path).", effects: { setFlags: ["route_docks"] }, goTo: "chapter_docks" },
        { text: "Clinic (support/med path).", effects: { setFlags: ["route_clinic"] }, goTo: "chapter_clinic" }
      ]
    },

    // … more chapters …
    chapter_downtown: { id: "chapter_downtown", text: "Downtown is hell.", isEnding: false, choices: [/* … */] },
    chapter_docks:    { id: "chapter_docks",    text: "The docks crackle with signals.", isEnding: false, choices: [/* … */] },
    chapter_clinic:   { id: "chapter_clinic",   text: "The clinic reeks of antiseptic and fear.", isEnding: false, choices: [/* … */] }
  });
