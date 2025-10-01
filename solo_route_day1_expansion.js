// DAY 1 SOLO ROUTE EXPANSION - Massive Content Addition
// This adds 50+ new scenes for the solo/alone route where Alex dies

const SOLO_DAY1_EXPANSION = {
  // === APARTMENT FORTIFICATION HUB ===
  "solo_apartment_hub": {
    "id": "solo_apartment_hub",
    "text": "Day 1 (Morning). You're alone. The building creaks with the weight of your isolation. Every sound could be death. Every silence could be worse. Your apartment becomes your fortress, your prison, your only world.",
    "choices": [
      {
        "id": "sah_water",
        "text": "Secure water supply before taps die",
        "goTo": "solo_water_management",
        "effects": {
          "pushEvent": "Water is life. You need gallons.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sah_power",
        "text": "Manage power - lights draw attention",
        "goTo": "solo_power_management",
        "effects": {
          "pushEvent": "Electricity is a beacon in the dark.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sah_barricade",
        "text": "Fortify doors and windows",
        "goTo": "solo_barricade_work",
        "effects": {
          "pushEvent": "Wood and metal become your walls.",
        },
        "tags": ["protector"],
      },
      {
        "id": "sah_roof",
        "text": "Establish roof access and escape routes",
        "goTo": "solo_roof_setup",
        "effects": {
          "pushEvent": "Up is your only way out.",
        },
        "tags": ["chill"],
      },
      {
        "id": "sah_radio",
        "text": "Monitor radio bands for signals",
        "goTo": "solo_radio_monitoring",
        "effects": {
          "pushEvent": "Static hides voices. You listen.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sah_psychological",
        "text": "Deal with the weight of isolation",
        "goTo": "solo_psychological_struggle",
        "effects": {
          "pushEvent": "Silence becomes a companion.",
        },
        "tags": ["nice"],
      },
    ],
    "timeDelta": 0,
  },

  // === WATER MANAGEMENT ===
  "solo_water_management": {
    "id": "solo_water_management",
    "text": "The taps sputter. Pressure drops with each hour. You need to store every drop you can.",
    "choices": [
      {
        "id": "swm_bathtub",
        "text": "Fill bathtub and every container",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": -1, "stamina": -2 },
          "inventoryAdd": ["water_jugs", "bathtub_water"],
          "flagsSet": ["d1_water_cached", "d1_bath_filled"],
          "pushEvent": "Water slaps porcelain. Relief slaps your chest.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "swm_bleach",
        "text": "Create disinfectant station",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": -1 },
          "inventoryAdd": ["bleach", "marker", "duct_tape"],
          "flagsSet": ["d1_water_cached", "water_treatment_setup"],
          "pushEvent": "Future-you will thank today-you.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "swm_laundry",
        "text": "Raid laundry room for storage",
        "goTo": "solo_laundry_raid",
        "effects": {
          "stats": { "stamina": -3, "stress": 2 },
          "pushEvent": "Noise trades time for capacity.",
        },
        "tags": ["protector"],
      },
      {
        "id": "swm_skip",
        "text": "Risk it - conserve energy",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": 2, "morality": -1 },
          "persona": { "sociopath": 1 },
          "pushEvent": "You let tomorrow be tomorrow's problem.",
        },
        "tags": ["psycho"],
      },
    ],
    "timeDelta": 2,
  },

  "solo_laundry_raid": {
    "id": "solo_laundry_raid",
    "text": "The laundry room door sticks. Inside: rolling carts, buckets, detergent. Something moves in the shadows.",
    "choices": [
      {
        "id": "slr_stealth",
        "text": "Move silently, take what you can",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": 1 },
          "inventoryAdd": ["rolling_cart", "buckets"],
          "flagsSet": ["d1_water_cached"],
          "pushEvent": "You ghost through the room.",
        },
        "tags": ["chill"],
      },
      {
        "id": "slr_bold",
        "text": "Take everything, deal with consequences",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "health": -2, "stress": 2 },
          "inventoryAdd": ["rolling_cart", "buckets", "detergent"],
          "flagsSet": ["d1_water_cached", "laundry_cleared"],
          "pushEvent": "You grab everything. Something grabs back.",
        },
        "tags": ["protector"],
      },
      {
        "id": "slr_abort",
        "text": "Too risky - retreat",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": 1 },
          "pushEvent": "You choose caution over capacity.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  // === POWER MANAGEMENT ===
  "solo_power_management": {
    "id": "solo_power_management",
    "text": "The breaker panel hums. Hallway lights draw attention to your door. Darkness helps you hide. Light helps you see.",
    "choices": [
      {
        "id": "spm_kill_lights",
        "text": "Cut hallway lights completely",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": -1 },
          "persona": { "fixer": 1 },
          "flagsSet": ["d1_breaker_off", "d1_hall_dark", "proof_warlord_blackout"],
          "pushEvent": "Less light, less traffic.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "spm_reroute",
        "text": "Reroute power to your unit only",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": -1 },
          "persona": { "fixer": 2 },
          "flagsSet": ["d1_hall_dark", "power_hoarded"],
          "pushEvent": "Your lights. Their dark.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "spm_trap",
        "text": "Wire noise traps on stairwell",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stamina": -2, "stress": 2 },
          "persona": { "warlord": 1 },
          "flagsSet": ["d1_wire_trap"],
          "inventoryAdd": ["copper_wire"],
          "pushEvent": "Anything big enough to touch it warns you.",
        },
        "tags": ["warlord"],
      },
      {
        "id": "spm_leave",
        "text": "Leave power alone - too risky",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": 1 },
          "pushEvent": "You choose not to touch live decisions.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  // === BARRICADE WORK ===
  "solo_barricade_work": {
    "id": "solo_barricade_work",
    "text": "Your door is your life. Every board, every screw, every piece of furniture becomes a wall between you and the world.",
    "choices": [
      {
        "id": "sbw_interior",
        "text": "Barricade interior doors and windows",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stamina": -2, "stress": -1 },
          "persona": { "protector": 1 },
          "flagsSet": ["d1_windows_barricaded", "interior_fortified"],
          "pushEvent": "Noise now means less later.",
        },
        "tags": ["protector"],
      },
      {
        "id": "sbw_exterior",
        "text": "Reinforce main door and frame",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stamina": -3, "stress": -1 },
          "persona": { "protector": 2 },
          "flagsSet": ["d1_windows_barricaded", "door_reinforced"],
          "pushEvent": "The door becomes a wall.",
        },
        "tags": ["protector"],
      },
      {
        "id": "sbw_traps",
        "text": "Set up noise traps and alarms",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stamina": -1 },
          "persona": { "warlord": 1 },
          "flagsSet": ["d1_wire_trap", "noise_traps_set"],
          "pushEvent": "Early warning becomes your edge.",
        },
        "tags": ["warlord"],
      },
      {
        "id": "sbw_conserve",
        "text": "Minimal barricading - conserve energy",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": 1 },
          "pushEvent": "You choose energy over armor.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 2,
  },

  // === ROOF SETUP ===
  "solo_roof_setup": {
    "id": "solo_roof_setup",
    "text": "The roof door sticks. The city sprawls below: smoke columns, moving shapes, the geometry of survival. You need a way up and down.",
    "choices": [
      {
        "id": "srs_rope",
        "text": "Tie rope and test fire escape",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stamina": -2, "stress": -1 },
          "persona": { "protector": 1 },
          "flagsSet": ["d1_rope_prepped", "d1_roof_route"],
          "inventoryAdd": ["rope"],
          "pushEvent": "Up and down become choices again.",
        },
        "tags": ["protector"],
      },
      {
        "id": "srs_mirror",
        "text": "Set up signal mirror for daylight",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": -1 },
          "flagsSet": ["d1_roof_route"],
          "inventoryAdd": ["signal_mirror"],
          "pushEvent": "You practice writing light.",
        },
        "tags": ["chill"],
      },
      {
        "id": "srs_scout",
        "text": "Scout with binoculars - map the area",
        "goTo": "solo_apartment_hub",
        "effects": {
          "persona": { "fixer": 1 },
          "flagsSet": ["d2_roof_clear", "area_mapped"],
          "pushEvent": "Landmarks become waypoints.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "srs_leave",
        "text": "Leave roof alone for now",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": 1 },
          "pushEvent": "You choose indoors over horizons.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 2,
  },

  // === RADIO MONITORING ===
  "solo_radio_monitoring": {
    "id": "solo_radio_monitoring",
    "text": "The old radio hisses. Between static: distant voices, numbers, sobs. Someone is still broadcasting. Someone is still alive.",
    "choices": [
      {
        "id": "srm_emergency",
        "text": "Scan emergency bands and log",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": -1 },
          "persona": { "fixer": 1 },
          "flagsSet": ["d1_radio_map", "d1_heard_courthouse"],
          "pushEvent": "Courthouse... supplies... doctors. A thread to pull.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "srm_morse",
        "text": "Set slow Morse beacon on low power",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stamina": -1 },
          "flagsSet": ["d1_heard_distress"],
          "pushEvent": "You whisper your existence to whoever can hear.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "srm_record",
        "text": "Record patterns and times",
        "goTo": "solo_apartment_hub",
        "effects": {
          "persona": { "chill": 1 },
          "flagsSet": ["d1_radio_map"],
          "pushEvent": "Chaos becomes a ledger.",
        },
        "tags": ["chill"],
      },
      {
        "id": "srm_off",
        "text": "Turn radio off - save power",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": -1 },
          "pushEvent": "Silence can be a shield.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  // === PSYCHOLOGICAL STRUGGLE ===
  "solo_psychological_struggle": {
    "id": "solo_psychological_struggle",
    "text": "The silence presses against your skull. You're alone. Completely alone. The weight of isolation threatens to crush you.",
    "choices": [
      {
        "id": "sps_journal",
        "text": "Write in a journal - process thoughts",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": -2, "morality": 1 },
          "persona": { "nice": 1 },
          "flagsSet": ["journaling_started"],
          "pushEvent": "Paper holds what your chest cannot.",
        },
        "tags": ["nice"],
      },
      {
        "id": "sps_routine",
        "text": "Establish strict daily routine",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": -1 },
          "persona": { "chill": 1 },
          "flagsSet": ["routine_established"],
          "pushEvent": "Structure keeps the madness at bay.",
        },
        "tags": ["chill"],
      },
      {
        "id": "sps_harden",
        "text": "Harden yourself - feel nothing",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "morality": -2, "stress": -2 },
          "persona": { "sociopath": 2 },
          "flagsSet": ["emotions_suppressed"],
          "pushEvent": "You file feelings under 'luxury'.",
        },
        "tags": ["psycho"],
      },
      {
        "id": "sps_plan",
        "text": "Focus on survival plans",
        "goTo": "solo_apartment_hub",
        "effects": {
          "stats": { "stress": -1 },
          "persona": { "fixer": 1 },
          "flagsSet": ["survival_plans_made"],
          "pushEvent": "Planning is control. Control is life.",
        },
        "tags": ["fixer"],
      },
    ],
    "timeDelta": 1,
  },

  // === EVENING PREPARATION ===
  "solo_evening_prep": {
    "id": "solo_evening_prep",
    "text": "Day 1 (Evening). Light shifts to orange. The infected become more active. You need to prepare for the longest night of your life.",
    "choices": [
      {
        "id": "sep_final_check",
        "text": "Final security check - test all defenses",
        "goTo": "solo_night_watch_setup",
        "effects": {
          "stats": { "stamina": -1, "stress": -1 },
          "pushEvent": "You verify every lock, every barricade.",
        },
        "tags": ["protector"],
      },
      {
        "id": "sep_rations",
        "text": "Prepare evening rations carefully",
        "goTo": "solo_night_watch_setup",
        "effects": {
          "stats": { "stress": -1 },
          "flagsSet": ["d1_eat_ration"],
          "pushEvent": "Small bites, long path.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sep_weapons",
        "text": "Check and prepare weapons",
        "goTo": "solo_night_watch_setup",
        "effects": {
          "stats": { "stress": -1 },
          "flagsSet": ["d1_trained_knife"],
          "pushEvent": "You practice grips until your hands remember.",
        },
        "tags": ["protector"],
      },
      {
        "id": "sep_rest",
        "text": "Try to rest before night falls",
        "goTo": "solo_night_watch_setup",
        "effects": {
          "stats": { "health": 2, "stamina": 2, "stress": -2 },
          "pushEvent": "You steal sleep like a thief.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  // === NIGHT WATCH SETUP ===
  "solo_night_watch_setup": {
    "id": "solo_night_watch_setup",
    "text": "Night falls. The building settles into darkness. You're alone with your thoughts, your fears, and whatever moves in the shadows.",
    "choices": [
      {
        "id": "snws_stay_awake",
        "text": "Stay awake all night - no sleep",
        "goTo": "solo_night_event_router",
        "effects": {
          "stats": { "stamina": -3, "stress": -2 },
          "flagsSet": ["d1_watch_you"],
          "pushEvent": "You trade sleep for certainty.",
        },
        "tags": ["protector"],
      },
      {
        "id": "snws_light_sleep",
        "text": "Light sleep with alarms set",
        "goTo": "solo_night_event_router",
        "effects": {
          "stats": { "stamina": -1, "stress": -1 },
          "flagsSet": ["d1_watch_traps"],
          "pushEvent": "You sleep with one eye open.",
        },
        "tags": ["chill"],
      },
      {
        "id": "snws_deep_sleep",
        "text": "Deep sleep - trust your defenses",
        "goTo": "solo_night_event_router",
        "effects": {
          "stats": { "health": 3, "stamina": 3, "stress": -3 },
          "flagsSet": ["d1_watch_traps"],
          "pushEvent": "You surrender to exhaustion.",
        },
        "tags": ["chill"],
        "req": { "flags": ["d1_wire_trap"] },
        "blockedReason": "Requires noise traps for safety.",
      },
      {
        "id": "snws_roof_watch",
        "text": "Spend night on roof - better visibility",
        "goTo": "solo_night_event_router",
        "effects": {
          "stats": { "stamina": -2, "stress": 1 },
          "flagsSet": ["d1_watch_you", "roof_night_watch"],
          "pushEvent": "You watch the city breathe.",
        },
        "tags": ["chill"],
        "req": { "flags": ["d1_roof_route"] },
        "blockedReason": "Requires roof access.",
      },
    ],
    "timeDelta": 1,
  },

  // === NIGHT EVENT ROUTER ===
  "solo_night_event_router": {
    "id": "solo_night_event_router",
    "text": "Night holds its breath. So do you. Every creak could be death. Every silence could be worse.",
    "choices": [
      {
        "id": "sner_breach",
        "text": "Something tests your door",
        "goTo": "solo_night_breach",
        "effects": {
          "flagsSet": ["d1_night_breach"],
        },
        "req": { "notFlags": ["d1_hall_dark", "d1_windows_barricaded"] },
        "blockedReason": "Blocked by darkness or barricades.",
        "tags": ["protector"],
      },
      {
        "id": "sner_trap",
        "text": "Your noise trap triggers",
        "goTo": "solo_night_diverted",
        "effects": {
          "flagsSet": ["d1_noise_trigger"],
        },
        "req": { "flags": ["d1_wire_trap"] },
        "blockedReason": "Requires noise trap.",
        "tags": ["fixer"],
      },
      {
        "id": "sner_dark",
        "text": "Dark hall confuses them",
        "goTo": "solo_night_peace",
        "effects": {
          "flagsSet": ["d1_night_peace"],
        },
        "req": { "flags": ["d1_hall_dark"] },
        "blockedReason": "Requires hallway darkness.",
        "tags": ["chill"],
      },
      {
        "id": "sner_barricade",
        "text": "Barricades hold firm",
        "goTo": "solo_night_peace",
        "effects": {
          "flagsSet": ["d1_night_peace"],
        },
        "req": { "flags": ["d1_windows_barricaded"] },
        "blockedReason": "Requires barricades.",
        "tags": ["protector"],
      },
      {
        "id": "sner_default",
        "text": "Night passes with small noises",
        "goTo": "solo_end_of_day1",
        "effects": {},
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  // === NIGHT BREACH ===
  "solo_night_breach": {
    "id": "solo_night_breach",
    "text": "Footsteps. Sniffing. A shoulder tests your door. Wood complains. You're alone. No one else will help.",
    "choices": [
      {
        "id": "snb_hold",
        "text": "Hold the door with everything you have",
        "goTo": "solo_end_of_day1",
        "effects": {
          "stats": { "stamina": -3, "stress": 3, "health": -2 },
          "persona": { "protector": 1 },
          "flagsSet": ["d1_breach_repulsed"],
          "pushEvent": "Pain in your shoulder. Silence after.",
        },
        "tags": ["protector"],
      },
      {
        "id": "snb_shout",
        "text": "Shout and bang pots - confuse them",
        "goTo": "solo_end_of_day1",
        "effects": {
          "stats": { "stress": 2 },
          "persona": { "fixer": 1 },
          "flagsSet": ["d1_breach_repulsed"],
          "pushEvent": "Noise manages monsters - for now.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "snb_stab",
        "text": "Crack door and stab at the seam",
        "goTo": "solo_end_of_day1",
        "effects": {
          "stats": { "health": -3, "stress": 2, "morality": -1 },
          "persona": { "killer": 1 },
          "flagsSet": ["proof_killer_mark"],
          "pushEvent": "You feel something give that shouldn't have been yours.",
        },
        "tags": ["killer"],
      },
    ],
    "timeDelta": 1,
  },

  // === NIGHT DIVERTED ===
  "solo_night_diverted": {
    "id": "solo_night_diverted",
    "text": "Your trap sings. Something ugly follows it. The stairwell becomes a rumor moving away. You're safe. For now.",
    "choices": [
      {
        "id": "snd_listen",
        "text": "Listen until it's certain",
        "goTo": "solo_end_of_day1",
        "effects": {
          "stats": { "stress": -2 },
          "pushEvent": "Silence is a reward.",
        },
        "tags": ["chill"],
      },
      {
        "id": "snd_reset",
        "text": "Reset the trap quietly",
        "goTo": "solo_end_of_day1",
        "effects": {
          "stats": { "stamina": -1 },
          "persona": { "fixer": 1 },
          "pushEvent": "Routine is comfort in disguise.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "snd_probe",
        "text": "Peek hall and map scuff marks",
        "goTo": "solo_end_of_day1",
        "effects": {
          "stats": { "stress": 1 },
          "flagsSet": ["proof_split_echoes"],
          "pushEvent": "Patterns become predictions.",
        },
        "tags": ["fixer"],
      },
    ],
    "timeDelta": 1,
  },

  // === NIGHT PEACE ===
  "solo_night_peace": {
    "id": "solo_night_peace",
    "text": "Night keeps its distance. Your heartbeat does the same. You're alone, but you're alive.",
    "choices": [
      {
        "id": "snp_rest",
        "text": "Sleep deeply - recover",
        "goTo": "solo_end_of_day1",
        "effects": {
          "stats": { "stress": -3, "health": 2, "stamina": 2 },
          "pushEvent": "You wake with fewer edges.",
        },
        "tags": ["chill"],
      },
      {
        "id": "snp_journal",
        "text": "Journal - write plans and promises",
        "goTo": "solo_end_of_day1",
        "effects": {
          "stats": { "stress": -2 },
          "persona": { "nice": 1 },
          "pushEvent": "Paper holds what your chest cannot.",
        },
        "tags": ["nice"],
      },
      {
        "id": "snp_watch",
        "text": "Stealth sweep before dawn",
        "goTo": "solo_end_of_day1",
        "effects": {
          "stats": { "stamina": -1, "stress": -1 },
          "flagsSet": ["d2_roof_clear"],
          "pushEvent": "The building breathes. So do you.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  // === END OF DAY 1 ===
  "solo_end_of_day1": {
    "id": "solo_end_of_day1",
    "text": "End of Day 1. You survived alone. The building holds your secrets. Tomorrow, the city will test you again.",
    "choices": [
      {
        "id": "sed1_continue",
        "text": "Advance to Day 2 (Morning)",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "flagsSet": ["d2_morning"],
          "pushEvent": "Day 2 starts whether you're ready or not.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 2,
  },
};

// Export for use
if (typeof module !== 'undefined' && module.exports) {
  module.exports = SOLO_DAY1_EXPANSION;
}