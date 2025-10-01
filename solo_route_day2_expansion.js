// DAY 2 SOLO ROUTE EXPANSION - Massive Content Addition
// This adds 60+ new scenes for Day 2 solo survival

const SOLO_DAY2_EXPANSION = {
  // === DAY 2 MORNING HUB ===
  "solo_day2_morning_hub": {
    "id": "solo_day2_morning_hub",
    "text": "Day 2 (Morning). You wake alone. The city didn't get the memo that you're still alive. Your apartment feels smaller. Your world feels larger. Choose your path.",
    "choices": [
      {
        "id": "sd2mh_scavenge",
        "text": "Street scavenging - find supplies",
        "goTo": "solo_street_scavenging",
        "effects": {
          "persona": { "chill": 1 },
          "pushEvent": "You sketch a path between shadows.",
        },
        "tags": ["chill"],
      },
      {
        "id": "sd2mh_radio",
        "text": "Monitor radio bands for signals",
        "goTo": "solo_radio_hunting",
        "effects": {
          "stats": { "stress": -1 },
          "pushEvent": "Static becomes a language when you're lonely.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sd2mh_fortify",
        "text": "Fortify apartment further",
        "goTo": "solo_apartment_fortification",
        "effects": {
          "persona": { "protector": 1 },
          "pushEvent": "Walls before roads.",
        },
        "tags": ["protector"],
      },
      {
        "id": "sd2mh_explore",
        "text": "Explore building - check other units",
        "goTo": "solo_building_exploration",
        "effects": {
          "persona": { "fixer": 1 },
          "pushEvent": "Every door is a question.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sd2mh_psychological",
        "text": "Deal with isolation and guilt",
        "goTo": "solo_psychological_day2",
        "effects": {
          "stats": { "morality": 1, "stress": 1 },
          "pushEvent": "You hold your own trial without a jury.",
        },
        "tags": ["nice"],
      },
      {
        "id": "sd2mh_roof",
        "text": "Roof reconnaissance - map the area",
        "goTo": "solo_roof_reconnaissance",
        "effects": {
          "persona": { "chill": 1 },
          "pushEvent": "Up is information.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  // === STREET SCAVENGING ===
  "solo_street_scavenging": {
    "id": "solo_street_scavenging",
    "text": "The street is a graveyard of normalcy. Cars abandoned mid-turn. Stores with shattered windows. Every shadow could be death.",
    "choices": [
      {
        "id": "sss_pharmacy",
        "text": "Hit the pharmacy - medical supplies",
        "goTo": "solo_pharmacy_raid",
        "effects": {
          "persona": { "fixer": 1 },
          "pushEvent": "Medicine is worth the risk.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sss_grocery",
        "text": "Raid grocery store - food supplies",
        "goTo": "solo_grocery_raid",
        "effects": {
          "persona": { "fixer": 1 },
          "pushEvent": "Calories are currency.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sss_hardware",
        "text": "Hardware store - tools and materials",
        "goTo": "solo_hardware_raid",
        "effects": {
          "persona": { "fixer": 1 },
          "pushEvent": "Tools make everything easier.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sss_cars",
        "text": "Search abandoned cars for supplies",
        "goTo": "solo_car_search",
        "effects": {
          "persona": { "chill": 1 },
          "pushEvent": "Every car is a treasure chest.",
        },
        "tags": ["chill"],
      },
      {
        "id": "sss_abort",
        "text": "Too dangerous - return to apartment",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": 1 },
          "pushEvent": "You choose safety over supplies.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 2,
  },

  "solo_pharmacy_raid": {
    "id": "solo_pharmacy_raid",
    "text": "The pharmacy door hangs open. Inside: shelves of possibility, shadows of danger. Medicine could save your life. The infected could end it.",
    "choices": [
      {
        "id": "spr_stealth",
        "text": "Move silently, take what you can",
        "goTo": "solo_narrow_escape",
        "effects": {
          "stats": { "stress": 1 },
          "inventoryAdd": ["bandages", "painkillers"],
          "pushEvent": "You ghost through the aisles.",
        },
        "tags": ["chill"],
      },
      {
        "id": "spr_bold",
        "text": "Take everything, deal with consequences",
        "goTo": "solo_narrow_escape",
        "effects": {
          "stats": { "health": -2, "stress": 2 },
          "inventoryAdd": ["medical_kit", "antibiotics", "gauze"],
          "pushEvent": "You grab everything. Something grabs back.",
        },
        "tags": ["protector"],
      },
      {
        "id": "spr_specific",
        "text": "Target specific medicines only",
        "goTo": "solo_narrow_escape",
        "effects": {
          "stats": { "stress": 1 },
          "inventoryAdd": ["antibiotics"],
          "pushEvent": "You take only what you need.",
        },
        "tags": ["fixer"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_grocery_raid": {
    "id": "solo_grocery_raid",
    "text": "The grocery store reeks of rot and possibility. Canned goods line the shelves like promises. Something moves in the back.",
    "choices": [
      {
        "id": "sgr_cans",
        "text": "Grab canned goods and protein bars",
        "goTo": "solo_narrow_escape",
        "effects": {
          "inventoryAdd": ["canned_beans", "protein_bars"],
          "stats": { "stress": -1 },
          "pushEvent": "Calories in, fear out.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sgr_fresh",
        "text": "Risk fresh produce in the back",
        "goTo": "solo_narrow_escape",
        "effects": {
          "stats": { "health": -3, "stress": 2 },
          "inventoryAdd": ["fresh_vegetables"],
          "pushEvent": "Fresh food tastes like victory.",
        },
        "tags": ["protector"],
      },
      {
        "id": "sgr_water",
        "text": "Focus on bottled water",
        "goTo": "solo_narrow_escape",
        "effects": {
          "inventoryAdd": ["bottled_water"],
          "stats": { "stress": -1 },
          "pushEvent": "Water is life.",
        },
        "tags": ["fixer"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_hardware_raid": {
    "id": "solo_hardware_raid",
    "text": "The hardware store is a treasure trove of survival. Tools, materials, everything you need to fortify your world.",
    "choices": [
      {
        "id": "shr_tools",
        "text": "Grab tools and hardware",
        "goTo": "solo_narrow_escape",
        "effects": {
          "inventoryAdd": ["screwdriver_set", "nails", "screws"],
          "persona": { "fixer": 1 },
          "pushEvent": "Tools make everything possible.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "shr_materials",
        "text": "Focus on building materials",
        "goTo": "solo_narrow_escape",
        "effects": {
          "inventoryAdd": ["plywood", "metal_sheets"],
          "persona": { "protector": 1 },
          "pushEvent": "Materials become walls.",
        },
        "tags": ["protector"],
      },
      {
        "id": "shr_wire",
        "text": "Take wire and electrical supplies",
        "goTo": "solo_narrow_escape",
        "effects": {
          "inventoryAdd": ["copper_wire", "electrical_tape"],
          "persona": { "warlord": 1 },
          "pushEvent": "Wire becomes traps.",
        },
        "tags": ["warlord"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_car_search": {
    "id": "solo_car_search",
    "text": "Abandoned cars line the street like metal coffins. Each one could hold supplies, fuel, or death.",
    "choices": [
      {
        "id": "scs_fuel",
        "text": "Siphon fuel from cars",
        "goTo": "solo_narrow_escape",
        "effects": {
          "stats": { "stamina": -2, "stress": 1 },
          "inventoryAdd": ["jerry_can"],
          "pushEvent": "You smell like tomorrow.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "scs_supplies",
        "text": "Search for supplies in cars",
        "goTo": "solo_narrow_escape",
        "effects": {
          "inventoryAdd": ["emergency_kit", "flashlight"],
          "pushEvent": "Every car is a treasure chest.",
        },
        "tags": ["chill"],
      },
      {
        "id": "scs_battery",
        "text": "Harvest car batteries",
        "goTo": "solo_narrow_escape",
        "effects": {
          "stats": { "stamina": -3, "stress": 2 },
          "inventoryAdd": ["car_battery"],
          "pushEvent": "Power becomes portable.",
        },
        "tags": ["fixer"],
      },
    ],
    "timeDelta": 1,
  },

  // === NARROW ESCAPE ===
  "solo_narrow_escape": {
    "id": "solo_narrow_escape",
    "text": "You make it out with lungs on fire and something rattling in your bag. Small wins keep you alive.",
    "choices": [
      {
        "id": "sne_back",
        "text": "Return to apartment to regroup",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": -1 },
          "pushEvent": "You learn to breathe between alarms.",
        },
        "tags": ["chill"],
      },
      {
        "id": "sne_continue",
        "text": "Continue scavenging - push your luck",
        "goTo": "solo_street_scavenging",
        "effects": {
          "stats": { "stress": 1 },
          "pushEvent": "You push your luck one more time.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sne_roof",
        "text": "Escape via rooftops",
        "goTo": "solo_roof_reconnaissance",
        "effects": {
          "stats": { "stamina": -2, "stress": 1 },
          "pushEvent": "You climb until your legs burn.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  // === RADIO HUNTING ===
  "solo_radio_hunting": {
    "id": "solo_radio_hunting",
    "text": "The radio crackles with possibility. Between static: voices, numbers, the sound of other survivors. Someone is still broadcasting.",
    "choices": [
      {
        "id": "srh_emergency",
        "text": "Scan emergency bands",
        "goTo": "solo_radio_signals",
        "effects": {
          "stats": { "stress": -1 },
          "persona": { "fixer": 1 },
          "flagsSet": ["d1_radio_map"],
          "pushEvent": "Emergency bands crackle with hope.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "srh_ham",
        "text": "Try ham radio frequencies",
        "goTo": "solo_radio_signals",
        "effects": {
          "stats": { "stress": -1 },
          "pushEvent": "Ham operators know how to survive.",
        },
        "tags": ["chill"],
      },
      {
        "id": "srh_broadcast",
        "text": "Send your own weak signal",
        "goTo": "solo_radio_signals",
        "effects": {
          "stats": { "stamina": -1 },
          "pushEvent": "You whisper your existence to the void.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "srh_record",
        "text": "Record patterns and times",
        "goTo": "solo_radio_signals",
        "effects": {
          "persona": { "chill": 1 },
          "pushEvent": "Chaos becomes a ledger.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_radio_signals": {
    "id": "solo_radio_signals",
    "text": "Through static: a calm voice recites street names and tide tables. Not rescue—routing. Someone is mapping the horde.",
    "choices": [
      {
        "id": "srs_trace",
        "text": "Trace the source signal",
        "goTo": "solo_signal_tracing",
        "effects": {
          "persona": { "fixer": 1 },
          "pushEvent": "You mark the path with chalk and memory.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "srs_note",
        "text": "Record patterns to predict movements",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": -2 },
          "flagsSet": ["proof_split_echoes"],
          "pushEvent": "The city starts making cruel sense.",
        },
        "tags": ["chill"],
      },
      {
        "id": "srs_bait",
        "text": "Broadcast bait to pull horde away",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stamina": -1 },
          "flagsSet": ["proof_warlord_blackout"],
          "pushEvent": "You move monsters like a shepherd.",
        },
        "tags": ["warlord"],
      },
      {
        "id": "srs_ignore",
        "text": "Ignore the signals - focus on survival",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": -1 },
          "pushEvent": "You choose your own path.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_signal_tracing": {
    "id": "solo_signal_tracing",
    "text": "You follow the signal through the city. The voice leads you to an industrial district. Rooftops bristle with antennas.",
    "choices": [
      {
        "id": "sst_approach",
        "text": "Approach the building cautiously",
        "goTo": "solo_mysterious_broadcaster",
        "effects": {
          "stats": { "stress": 2 },
          "pushEvent": "You approach the source of the voice.",
        },
        "tags": ["chill"],
      },
      {
        "id": "sst_observe",
        "text": "Observe from a distance",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": -1 },
          "flagsSet": ["broadcaster_observed"],
          "pushEvent": "You watch from the shadows.",
        },
        "tags": ["chill"],
      },
      {
        "id": "sst_avoid",
        "text": "Avoid the area - too dangerous",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": -1 },
          "pushEvent": "You choose safety over curiosity.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 2,
  },

  "solo_mysterious_broadcaster": {
    "id": "solo_mysterious_broadcaster",
    "text": "The building is a maze of antennas and equipment. A figure moves between consoles. They're broadcasting something. They're not alone.",
    "choices": [
      {
        "id": "smb_contact",
        "text": "Make contact - announce yourself",
        "goTo": "solo_broadcaster_meeting",
        "effects": {
          "stats": { "stress": 2 },
          "pushEvent": "You step into the light.",
        },
        "tags": ["nice"],
      },
      {
        "id": "smb_sneak",
        "text": "Sneak closer and listen",
        "goTo": "solo_broadcaster_eavesdrop",
        "effects": {
          "stats": { "stress": 1 },
          "pushEvent": "You become a shadow.",
        },
        "tags": ["chill"],
      },
      {
        "id": "smb_leave",
        "text": "Leave immediately - too risky",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": -1 },
          "pushEvent": "You choose discretion over valor.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_broadcaster_meeting": {
    "id": "solo_broadcaster_meeting",
    "text": "The figure turns. It's a woman in her 40s, eyes sharp with survival. 'You're the first living person I've seen in days,' she says. 'I'm Dr. Sarah Chen. I'm trying to coordinate survivors.'",
    "choices": [
      {
        "id": "sbm_trust",
        "text": "Trust her - join her network",
        "goTo": "solo_join_network",
        "effects": {
          "stats": { "stress": -2 },
          "persona": { "nice": 2 },
          "relationships": { "Sarah": 5 },
          "flagsSet": ["joined_network"],
          "pushEvent": "You choose trust over isolation.",
        },
        "tags": ["nice"],
      },
      {
        "id": "sbm_cautious",
        "text": "Be cautious - ask questions first",
        "goTo": "solo_network_interrogation",
        "effects": {
          "persona": { "chill": 1 },
          "relationships": { "Sarah": 2 },
          "pushEvent": "You choose knowledge over trust.",
        },
        "tags": ["chill"],
      },
      {
        "id": "sbm_refuse",
        "text": "Refuse - stay independent",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": 1 },
          "persona": { "chill": 1 },
          "relationships": { "Sarah": -1 },
          "pushEvent": "You choose independence over community.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_broadcaster_eavesdrop": {
    "id": "solo_broadcaster_eavesdrop",
    "text": "You listen from the shadows. Dr. Chen speaks into her microphone: 'All survivors, this is Dr. Sarah Chen. I'm establishing a safe zone at the courthouse. Medical supplies available. Come if you can.'",
    "choices": [
      {
        "id": "sbe_reveal",
        "text": "Reveal yourself and join",
        "goTo": "solo_join_network",
        "effects": {
          "stats": { "stress": -1 },
          "persona": { "nice": 1 },
          "relationships": { "Sarah": 3 },
          "flagsSet": ["joined_network"],
          "pushEvent": "You step from the shadows.",
        },
        "tags": ["nice"],
      },
      {
        "id": "sbe_listen",
        "text": "Keep listening - gather more intel",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": -1 },
          "flagsSet": ["network_intel_gathered"],
          "pushEvent": "You gather information in silence.",
        },
        "tags": ["chill"],
      },
      {
        "id": "sbe_leave",
        "text": "Leave - don't get involved",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": -1 },
          "pushEvent": "You choose isolation over involvement.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_join_network": {
    "id": "solo_join_network",
    "text": "Dr. Chen welcomes you into her network. 'We're establishing a safe zone at the courthouse. Medical supplies, food, protection. But we need people who can contribute.'",
    "choices": [
      {
        "id": "sjn_medical",
        "text": "Offer medical knowledge",
        "goTo": "solo_courthouse_safe_zone",
        "effects": {
          "persona": { "nice": 1 },
          "relationships": { "Sarah": 3 },
          "flagsSet": ["medical_contributor"],
          "pushEvent": "You offer your knowledge.",
        },
        "tags": ["nice"],
      },
      {
        "id": "sjn_scavenging",
        "text": "Offer scavenging skills",
        "goTo": "solo_courthouse_safe_zone",
        "effects": {
          "persona": { "fixer": 1 },
          "relationships": { "Sarah": 2 },
          "flagsSet": ["scavenging_contributor"],
          "pushEvent": "You offer your skills.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sjn_security",
        "text": "Offer security and protection",
        "goTo": "solo_courthouse_safe_zone",
        "effects": {
          "persona": { "protector": 1 },
          "relationships": { "Sarah": 2 },
          "flagsSet": ["security_contributor"],
          "pushEvent": "You offer your strength.",
        },
        "tags": ["protector"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_network_interrogation": {
    "id": "solo_network_interrogation",
    "text": "You ask questions. Dr. Chen answers patiently: 'The courthouse is defensible. We have medical supplies. We need people who can contribute. What can you offer?'",
    "choices": [
      {
        "id": "sni_join",
        "text": "Join after hearing her answers",
        "goTo": "solo_join_network",
        "effects": {
          "stats": { "stress": -1 },
          "persona": { "chill": 1 },
          "relationships": { "Sarah": 3 },
          "pushEvent": "You choose knowledge over trust.",
        },
        "tags": ["chill"],
      },
      {
        "id": "sni_refuse",
        "text": "Refuse - too many unknowns",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": 1 },
          "persona": { "chill": 1 },
          "relationships": { "Sarah": -1 },
          "pushEvent": "You choose caution over community.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  // === COURTHOUSE SAFE ZONE ===
  "solo_courthouse_safe_zone": {
    "id": "solo_courthouse_safe_zone",
    "text": "The courthouse is a fortress of law and order. Barricades line the perimeter. People move with purpose. You're not alone anymore.",
    "choices": [
      {
        "id": "scsz_medical",
        "text": "Work in the medical bay",
        "goTo": "solo_medical_work",
        "effects": {
          "persona": { "nice": 1 },
          "relationships": { "Sarah": 2 },
          "pushEvent": "You help heal the wounded.",
        },
        "tags": ["nice"],
      },
      {
        "id": "scsz_scavenging",
        "text": "Join scavenging teams",
        "goTo": "solo_scavenging_teams",
        "effects": {
          "persona": { "fixer": 1 },
          "pushEvent": "You contribute to the community.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "scsz_security",
        "text": "Join security detail",
        "goTo": "solo_security_detail",
        "effects": {
          "persona": { "protector": 1 },
          "pushEvent": "You protect the community.",
        },
        "tags": ["protector"],
      },
      {
        "id": "scsz_rest",
        "text": "Rest and recover",
        "goTo": "solo_safe_zone_rest",
        "effects": {
          "stats": { "health": 5, "stamina": 5, "stress": -3 },
          "pushEvent": "You finally feel safe.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_medical_work": {
    "id": "solo_medical_work",
    "text": "The medical bay is a symphony of pain and healing. Dr. Chen works alongside you, treating wounds, managing supplies, saving lives.",
    "choices": [
      {
        "id": "smw_help",
        "text": "Help with patient care",
        "goTo": "solo_day2_evening_hub",
        "effects": {
          "stats": { "stress": -2, "morality": 2 },
          "persona": { "nice": 2 },
          "relationships": { "Sarah": 3 },
          "pushEvent": "You help heal the wounded.",
        },
        "tags": ["nice"],
      },
      {
        "id": "smw_supplies",
        "text": "Manage medical supplies",
        "goTo": "solo_day2_evening_hub",
        "effects": {
          "persona": { "fixer": 1 },
          "relationships": { "Sarah": 2 },
          "pushEvent": "You organize the supplies.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "smw_learn",
        "text": "Learn medical procedures",
        "goTo": "solo_day2_evening_hub",
        "effects": {
          "persona": { "chill": 1 },
          "relationships": { "Sarah": 2 },
          "pushEvent": "You learn to heal.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 2,
  },

  "solo_scavenging_teams": {
    "id": "solo_scavenging_teams",
    "text": "The scavenging teams move like clockwork. You join them, learning their routes, their methods, their survival.",
    "choices": [
      {
        "id": "sst_medical",
        "text": "Focus on medical supplies",
        "goTo": "solo_day2_evening_hub",
        "effects": {
          "persona": { "nice": 1 },
          "relationships": { "Sarah": 2 },
          "pushEvent": "You find medicine for the wounded.",
        },
        "tags": ["nice"],
      },
      {
        "id": "sst_food",
        "text": "Focus on food supplies",
        "goTo": "solo_day2_evening_hub",
        "effects": {
          "persona": { "fixer": 1 },
          "pushEvent": "You find food for the hungry.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sst_materials",
        "text": "Focus on building materials",
        "goTo": "solo_day2_evening_hub",
        "effects": {
          "persona": { "protector": 1 },
          "pushEvent": "You find materials for the walls.",
        },
        "tags": ["protector"],
      },
    ],
    "timeDelta": 2,
  },

  "solo_security_detail": {
    "id": "solo_security_detail",
    "text": "The security detail patrols the perimeter. You join them, learning their routes, their methods, their protection.",
    "choices": [
      {
        "id": "ssd_perimeter",
        "text": "Patrol the perimeter",
        "goTo": "solo_day2_evening_hub",
        "effects": {
          "persona": { "protector": 1 },
          "pushEvent": "You protect the perimeter.",
        },
        "tags": ["protector"],
      },
      {
        "id": "ssd_gates",
        "text": "Guard the main gates",
        "goTo": "solo_day2_evening_hub",
        "effects": {
          "persona": { "protector": 1 },
          "pushEvent": "You guard the gates.",
        },
        "tags": ["protector"],
      },
      {
        "id": "ssd_training",
        "text": "Train with the security team",
        "goTo": "solo_day2_evening_hub",
        "effects": {
          "persona": { "protector": 1 },
          "pushEvent": "You train with the team.",
        },
        "tags": ["protector"],
      },
    ],
    "timeDelta": 2,
  },

  "solo_safe_zone_rest": {
    "id": "solo_safe_zone_rest",
    "text": "You rest in the safe zone. For the first time in days, you feel safe. You sleep deeply, knowing others are watching.",
    "choices": [
      {
        "id": "sszr_sleep",
        "text": "Sleep deeply and recover",
        "goTo": "solo_day2_evening_hub",
        "effects": {
          "stats": { "health": 5, "stamina": 5, "stress": -3 },
          "pushEvent": "You sleep without fear.",
        },
        "tags": ["chill"],
      },
      {
        "id": "sszr_socialize",
        "text": "Socialize with other survivors",
        "goTo": "solo_day2_evening_hub",
        "effects": {
          "stats": { "stress": -2 },
          "persona": { "nice": 1 },
          "pushEvent": "You connect with other survivors.",
        },
        "tags": ["nice"],
      },
      {
        "id": "sszr_plan",
        "text": "Plan your next moves",
        "goTo": "solo_day2_evening_hub",
        "effects": {
          "persona": { "fixer": 1 },
          "pushEvent": "You plan your future.",
        },
        "tags": ["fixer"],
      },
    ],
    "timeDelta": 2,
  },

  // === DAY 2 EVENING HUB ===
  "solo_day2_evening_hub": {
    "id": "solo_day2_evening_hub",
    "text": "Day 2 (Evening). You've survived another day. Whether alone or with others, you're still alive. The night approaches with its own challenges.",
    "choices": [
      {
        "id": "sd2eh_continue",
        "text": "Continue to Day 3",
        "goTo": "solo_day3_morning_hub",
        "effects": {
          "flagsSet": ["d3_morning"],
          "pushEvent": "Day 3 begins.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 2,
  },

  // === DAY 3 MORNING HUB ===
  "solo_day3_morning_hub": {
    "id": "solo_day3_morning_hub",
    "text": "Day 3 (Morning). You've survived two days alone. The city is changing. The infected are learning. You must adapt or die.",
    "choices": [
      {
        "id": "sd3mh_continue",
        "text": "Continue your survival",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "pushEvent": "You continue your survival.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },
};

// Export for use
if (typeof module !== 'undefined' && module.exports) {
  module.exports = SOLO_DAY2_EXPANSION;
}