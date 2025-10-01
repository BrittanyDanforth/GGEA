// COMPREHENSIVE SOLO ROUTE INTEGRATION
// This script integrates all solo route expansions into the main game

// Import the expansions
const SOLO_DAY1_EXPANSION = require('./solo_route_day1_expansion.js');
const SOLO_DAY2_EXPANSION = require('./solo_route_day2_expansion.js');

// Additional solo route scenes for deeper content
const ADDITIONAL_SOLO_SCENES = {
  // === PSYCHOLOGICAL DAY 2 ===
  "solo_psychological_day2": {
    "id": "solo_psychological_day2",
    "text": "Day 2 brings new weight. The guilt of Alex's death presses against your chest. The isolation gnaws at your sanity. You must choose how to carry this burden.",
    "choices": [
      {
        "id": "spd2_guilt",
        "text": "Face the guilt head-on",
        "goTo": "solo_guilt_confrontation",
        "effects": {
          "stats": { "morality": 2, "stress": 2 },
          "persona": { "nice": 1 },
          "pushEvent": "You face what you've done.",
        },
        "tags": ["nice"],
      },
      {
        "id": "spd2_suppress",
        "text": "Suppress the guilt - focus on survival",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "morality": -2, "stress": -2 },
          "persona": { "sociopath": 2 },
          "pushEvent": "You bury the guilt deep.",
        },
        "tags": ["psycho"],
      },
      {
        "id": "spd2_rationalize",
        "text": "Rationalize your choices",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": -1 },
          "persona": { "chill": 1 },
          "pushEvent": "You find reasons for your actions.",
        },
        "tags": ["chill"],
      },
      {
        "id": "spd2_redemption",
        "text": "Seek redemption through helping others",
        "goTo": "solo_redemption_path",
        "effects": {
          "stats": { "morality": 3, "stress": 1 },
          "persona": { "protector": 2 },
          "flagsSet": ["route_protector"],
          "pushEvent": "You choose to protect others.",
        },
        "tags": ["protector"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_guilt_confrontation": {
    "id": "solo_guilt_confrontation",
    "text": "You sit with Alex's memory. The weight of their death presses against your chest. You could have saved them. You chose not to. This truth cannot be undone.",
    "choices": [
      {
        "id": "sgc_accept",
        "text": "Accept the weight and carry it",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "morality": 3, "stress": 2 },
          "persona": { "nice": 2 },
          "flagsSet": ["guilt_accepted"],
          "pushEvent": "You carry the weight of your choices.",
        },
        "tags": ["nice"],
      },
      {
        "id": "sgc_memorial",
        "text": "Create a memorial for Alex",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "morality": 2, "stress": -1 },
          "persona": { "nice": 1 },
          "flagsSet": ["alex_memorial"],
          "pushEvent": "You honor their memory.",
        },
        "tags": ["nice"],
      },
      {
        "id": "sgc_vow",
        "text": "Vow to never let someone die again",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "morality": 2, "stress": 1 },
          "persona": { "protector": 2 },
          "flagsSet": ["route_protector", "never_again_vow"],
          "pushEvent": "You make a promise to the dead.",
        },
        "tags": ["protector"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_redemption_path": {
    "id": "solo_redemption_path",
    "text": "You choose redemption. You will protect others. You will save lives. You will make Alex's death mean something.",
    "choices": [
      {
        "id": "srp_neighbors",
        "text": "Check on other building residents",
        "goTo": "solo_neighbor_check",
        "effects": {
          "persona": { "protector": 1 },
          "pushEvent": "You choose to help others.",
        },
        "tags": ["protector"],
      },
      {
        "id": "srp_signals",
        "text": "Broadcast help signals",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "persona": { "protector": 1 },
          "flagsSet": ["help_signals_broadcast"],
          "pushEvent": "You offer help to the world.",
        },
        "tags": ["protector"],
      },
      {
        "id": "srp_supplies",
        "text": "Gather supplies for others",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "persona": { "protector": 1 },
          "flagsSet": ["supplies_for_others"],
          "pushEvent": "You gather supplies for others.",
        },
        "tags": ["protector"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_neighbor_check": {
    "id": "solo_neighbor_check",
    "text": "You check on other building residents. Some are dead. Some are missing. Some are still alive, hiding in their apartments.",
    "choices": [
      {
        "id": "snc_help",
        "text": "Help the living residents",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "morality": 3, "stress": 2 },
          "persona": { "protector": 2 },
          "relationships": { "Neighbors": 5 },
          "flagsSet": ["neighbors_helped"],
          "pushEvent": "You help the living.",
        },
        "tags": ["protector"],
      },
      {
        "id": "snc_supplies",
        "text": "Take supplies from empty apartments",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "morality": -2, "stress": -1 },
          "persona": { "fixer": 1 },
          "inventoryAdd": ["neighbor_supplies"],
          "pushEvent": "You take what you need.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "snc_avoid",
        "text": "Avoid contact - too risky",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": 1 },
          "pushEvent": "You choose safety over help.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 2,
  },

  // === APARTMENT FORTIFICATION ===
  "solo_apartment_fortification": {
    "id": "solo_apartment_fortification",
    "text": "Your apartment becomes your fortress. Every board, every screw, every piece of furniture becomes a wall between you and the world.",
    "choices": [
      {
        "id": "saf_interior",
        "text": "Fortify interior doors and windows",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stamina": -2, "stress": -1 },
          "persona": { "protector": 1 },
          "flagsSet": ["interior_fortified"],
          "pushEvent": "You fortify your interior.",
        },
        "tags": ["protector"],
      },
      {
        "id": "saf_exterior",
        "text": "Reinforce main door and frame",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stamina": -3, "stress": -1 },
          "persona": { "protector": 2 },
          "flagsSet": ["door_reinforced"],
          "pushEvent": "You reinforce your door.",
        },
        "tags": ["protector"],
      },
      {
        "id": "saf_traps",
        "text": "Set up noise traps and alarms",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stamina": -1 },
          "persona": { "warlord": 1 },
          "flagsSet": ["noise_traps_set"],
          "pushEvent": "You set up early warning.",
        },
        "tags": ["warlord"],
      },
      {
        "id": "saf_conserve",
        "text": "Minimal fortification - conserve energy",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": 1 },
          "pushEvent": "You choose energy over armor.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 2,
  },

  // === BUILDING EXPLORATION ===
  "solo_building_exploration": {
    "id": "solo_building_exploration",
    "text": "Your building is a maze of locked doors and hidden secrets. Every apartment could hold supplies, danger, or answers.",
    "choices": [
      {
        "id": "sbe_floor_by_floor",
        "text": "Systematically check each floor",
        "goTo": "solo_floor_exploration",
        "effects": {
          "persona": { "fixer": 1 },
          "pushEvent": "You map the building systematically.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sbe_targeted",
        "text": "Target specific apartments",
        "goTo": "solo_targeted_exploration",
        "effects": {
          "persona": { "chill": 1 },
          "pushEvent": "You focus on specific targets.",
        },
        "tags": ["chill"],
      },
      {
        "id": "sbe_avoid",
        "text": "Avoid exploration - too dangerous",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": 1 },
          "pushEvent": "You choose safety over exploration.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 1,
  },

  "solo_floor_exploration": {
    "id": "solo_floor_exploration",
    "text": "You explore floor by floor. Some apartments are empty. Some contain supplies. Some contain death.",
    "choices": [
      {
        "id": "sfe_supplies",
        "text": "Focus on finding supplies",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "inventoryAdd": ["building_supplies"],
          "persona": { "fixer": 1 },
          "pushEvent": "You find supplies in the building.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "sfe_survivors",
        "text": "Look for other survivors",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": 2 },
          "persona": { "nice": 1 },
          "pushEvent": "You search for other survivors.",
        },
        "tags": ["nice"],
      },
      {
        "id": "sfe_avoid",
        "text": "Avoid dangerous areas",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": -1 },
          "pushEvent": "You avoid dangerous areas.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 2,
  },

  "solo_targeted_exploration": {
    "id": "solo_targeted_exploration",
    "text": "You target specific apartments based on what you know about the residents. Some were prepared. Some were not.",
    "choices": [
      {
        "id": "ste_prepared",
        "text": "Check apartments of prepared residents",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "inventoryAdd": ["prepared_supplies"],
          "persona": { "fixer": 1 },
          "pushEvent": "You find supplies from prepared residents.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "ste_vulnerable",
        "text": "Check apartments of vulnerable residents",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "morality": 2, "stress": 2 },
          "persona": { "nice": 1 },
          "pushEvent": "You find vulnerable residents.",
        },
        "tags": ["nice"],
      },
      {
        "id": "ste_avoid",
        "text": "Avoid exploration - too risky",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": 1 },
          "pushEvent": "You choose safety over exploration.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 2,
  },

  // === ROOF RECONNAISSANCE ===
  "solo_roof_reconnaissance": {
    "id": "solo_roof_reconnaissance",
    "text": "The roof offers a bird's eye view of the city. You can see the patterns of the infected, the movements of survivors, the geometry of survival.",
    "choices": [
      {
        "id": "srr_map",
        "text": "Map the area systematically",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "persona": { "fixer": 1 },
          "flagsSet": ["area_mapped"],
          "pushEvent": "You map the area systematically.",
        },
        "tags": ["fixer"],
      },
      {
        "id": "srr_signals",
        "text": "Look for signals from other survivors",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "persona": { "chill": 1 },
          "flagsSet": ["signals_spotted"],
          "pushEvent": "You spot signals from other survivors.",
        },
        "tags": ["chill"],
      },
      {
        "id": "srr_escape",
        "text": "Plan escape routes",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "persona": { "chill": 1 },
          "flagsSet": ["escape_routes_planned"],
          "pushEvent": "You plan your escape routes.",
        },
        "tags": ["chill"],
      },
      {
        "id": "srr_avoid",
        "text": "Avoid the roof - too exposed",
        "goTo": "solo_day2_morning_hub",
        "effects": {
          "stats": { "stress": 1 },
          "pushEvent": "You choose safety over visibility.",
        },
        "tags": ["chill"],
      },
    ],
    "timeDelta": 2,
  },
};

// Function to integrate all solo route expansions
function integrateSoloRouteExpansions() {
  // Merge all expansions into the main STORY_DATABASE
  Object.assign(window.STORY_DATABASE, SOLO_DAY1_EXPANSION);
  Object.assign(window.STORY_DATABASE, SOLO_DAY2_EXPANSION);
  Object.assign(window.STORY_DATABASE, ADDITIONAL_SOLO_SCENES);
  
  // Update the existing solo route scenes to point to new content
  if (window.STORY_DATABASE.act1_alone_hub) {
    window.STORY_DATABASE.act1_alone_hub.goTo = "solo_apartment_hub";
  }
  
  console.log("Solo route expansions integrated successfully!");
  console.log("Total scenes added:", Object.keys(SOLO_DAY1_EXPANSION).length + Object.keys(SOLO_DAY2_EXPANSION).length + Object.keys(ADDITIONAL_SOLO_SCENES).length);
}

// Auto-integrate when this script loads
if (typeof window !== 'undefined') {
  // Wait for the main game to load
  setTimeout(() => {
    if (window.STORY_DATABASE) {
      integrateSoloRouteExpansions();
    } else {
      console.error("STORY_DATABASE not found. Make sure the main game script loads first.");
    }
  }, 100);
}

// Export for manual integration
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    integrateSoloRouteExpansions,
    SOLO_DAY1_EXPANSION,
    SOLO_DAY2_EXPANSION,
    ADDITIONAL_SOLO_SCENES
  };
}