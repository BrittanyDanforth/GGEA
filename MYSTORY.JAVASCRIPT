;(() => {
  "use strict";

  const WORKING_TITLE = "THE LONG SIREN";
  const SAVE_KEY = "tls_offline_save";

  const WORLD_BIBLE = {
    title: WORKING_TITLE,
    outbreak: {
      vector: "Airborne prion carried in aerosols and bodily fluids.",
      incubationHours: "4-12",
      attractors: ["sound", "bright light", "fresh blood"]
    },
    scarcity: ["fuel", "antibiotics", "potable water", "ammo"],
    factions: {
      stadium: "Makeshift government focused on triage and order.",
      convoy: "Mobile traders hauling supplies between havens.",
      raiders: "Predatory crews holding choke points through fear.",
      freeCrews: "Loose coalitions of scavengers."
    },
    anchors: ["apartment block", "alley", "garage", "street", "rooftop", "stadium", "refinery", "interstate"],
    tone: "Grounded, hard decisions. Optional mature content surfaced only by explicit player opt-in.",
    cadenceHours: "Acts 1-5 unfold over roughly 48-96 in-game hours with timed pressure events."
  };

  const INITIAL_STATE = () => ({
    sceneId: "neutral_act1_hub_apartment",
    time: 0,
    stats: { health: 100, stamina: 15, stress: 0, morality: 0 },
    inventory: [],
    flags: {},
    relationships: {},
    rngSeed: 1337,
    decisionTrace: []
  });

  const MUTEX = {
    faction: ["joined_militia", "joined_raiders", "faction_neutral"],
    convoyPlan: ["plan_stadium", "plan_convoy", "plan_refinery"]
  };

  const FLAG_TO_MUTEX = (() => {
    const map = new Map();
    for (const [group, flags] of Object.entries(MUTEX)) {
      for (const flag of flags) map.set(flag, group);
    }
    return map;
  })();

  function setMutex(state, group, flag) {
    const peers = MUTEX[group] || [];
    for (const f of peers) {
      if (f !== flag) delete state.flags[f];
    }
    state.flags[flag] = true;
  }

  const CONSEQUENCE_FLAGS = new Set([
    "joined_militia",
    "joined_raiders",
    "refinery_burned",
    "convoy_betrayed",
    "wall_breached",
    "rescued_convoy",
    "held_line",
    "shared_rations"
  ]);

  const ROUTE_PROOFS = {
    good: ["proof_good_act1", "proof_good_act2", "proof_good_act3"],
    ant: ["proof_ant_act1", "proof_ant_act2", "proof_ant_act3"],
    man: ["proof_man_act1", "proof_man_act2", "proof_man_act3"]
  };

  const STATS_MIN_MAX = {
    health: [0, 100],
    stamina: [0, 20],
    stress: [0, 100],
    morality: [-20, 20]
  };

  function clampStats(stats) {
    for (const [key, value] of Object.entries(stats)) {
      const clamp = STATS_MIN_MAX[key];
      if (!clamp) continue;
      const [min, max] = clamp;
      if (value < min) stats[key] = min;
      if (value > max) stats[key] = max;
    }
  }

  function normalizeSceneId(id) {
    return id?.trim();
  }

  const TAGS_ALLOWED = new Set(["moral", "combat", "social", "stealth", "leader", "survival"]);

  const STORY_DATABASE = {
    neutral_act1_hub_apartment: {
      id: "neutral_act1_hub_apartment",
      text: "Rain needles cracked glass. The stairwell reeks of bleach and rot. Survivors crowd the hall waiting for you to call it.",
      tags: ["leader"],
      choices: [
        {
          id: "secure_stairwell",
          text: "Coordinate the volunteers (−1 STA, +1h)",
          goTo: "good_act1_setpiece_stairwell",
          cost: { stamina: 1, time: 1 },
          effects: {
            stats: { stress: +2 },
            relationships: { Volunteers: +3 }
          },
          tags: ["leader", "moral"]
        },
        {
          id: "raise_radio",
          text: "Raise the Convoy dispatcher (+1h)",
          goTo: "man_act1_setpiece_radio",
          cost: { time: 1 },
          effects: {
            stats: { stress: +1 },
            relationships: { Convoy: +2 }
          },
          tags: ["social"]
        },
        {
          id: "lean_raiders",
          text: "Lean on the raider scouts (−1 Morality)",
          goTo: "ant_act1_setpiece_intimidation",
          effects: {
            stats: { morality: -1, stress: +2 },
            flagsSet: ["faction_pressure"]
          },
          tags: ["moral", "combat"]
        },
        {
          id: "check_garage",
          text: "Slip to the garage for tools",
          goTo: "neutral_act1_side_garage",
          effects: { time: +1 },
          tags: ["survival", "stealth"]
        }
      ]
    },

    neutral_act1_side_garage: {
      id: "neutral_act1_side_garage",
      text: "The garage smells of oil and mold. A husk of a sedan hides salvage under tarps.",
      tags: ["survival"],
      choices: [
        {
          id: "salvage_fuel",
          text: "Siphon the tank (+1h, gain Fuel)",
          cost: { time: 1 },
          effects: {
            inventoryAdd: ["fuel_can"],
            stats: { stamina: -1, stress: +1 }
          },
          tags: ["survival"]
        },
        {
          id: "return_hall",
          text: "Return quietly to the hall",
          goTo: "neutral_act1_hub_apartment",
          effects: {
            stats: { stress: -1 }
          },
          tags: ["stealth"]
        }
      ],
      notes: "Simple side loop for Act 1 resources."
    },

    good_act1_setpiece_stairwell: {
      id: "good_act1_setpiece_stairwell",
      text: "Volunteers brace doors while infected claws scrape below. A kid whimpers as the barricade bows.",
      tags: ["leader", "combat"],
      choices: [
        {
          id: "hold_line",
          text: "Hold the line with shifts (−2 STA, +1h)",
          cost: { stamina: 2, time: 1 },
          effects: {
            flagsSet: ["held_line", "proof_good_act1"],
            stats: { stress: +3, morality: +2 },
            relationships: { Volunteers: +6 }
          },
          goTo: "neutral_act1_bridge_rooftop",
          tags: ["leader", "combat"]
        },
        {
          id: "evacuate_kid",
          text: "Evacuate the kid to the roof (+1h)",
          cost: { time: 1 },
          effects: {
            stats: { morality: +1, stress: +1 },
            flagsSet: ["rescued_child"],
            relationships: { Volunteers: +4 }
          },
          goTo: "neutral_act1_hub_apartment",
          tags: ["moral", "leader"]
        }
      ]
    },

    ant_act1_setpiece_intimidation: {
      id: "ant_act1_setpiece_intimidation",
      text: "Raiders squat on the stair landing with stolen crates. They smirk when you approach alone.",
      tags: ["combat", "social"],
      choices: [
        {
          id: "seize_crates",
          text: "Seize their crates (−1 STA, −2 Morality)",
          cost: { stamina: 1 },
          effects: {
            stats: { morality: -2, stress: -1 },
            flagsSet: ["proof_ant_act1", "wall_breached"],
            inventoryAdd: ["ration_brick"],
            relationships: { Raiders: -6, Volunteers: -3 }
          },
          goTo: "neutral_act1_bridge_rooftop",
          tags: ["combat", "moral"]
        },
        {
          id: "threaten_scout",
          text: "Threaten their scout for intel",
          effects: {
            flagsSet: ["raider_map"],
            stats: { stress: +1 }
          },
          goTo: "neutral_act1_hub_apartment",
          tags: ["social", "survival"]
        }
      ]
    },

    man_act1_setpiece_radio: {
      id: "man_act1_setpiece_radio",
      text: "The roof radio crackles with Convoy chatter. They want leverage before risking a pickup.",
      tags: ["social", "leader"],
      choices: [
        {
          id: "offer_fuel",
          text: "Offer fuel for evac (requires Fuel Can)",
          req: { items: ["fuel_can"] },
          effects: {
            inventoryRemove: ["fuel_can"],
            flagsSet: ["proof_man_act1", "shared_rations"],
            relationships: { Convoy: +8 },
            stats: { morality: +1 }
          },
          goTo: "neutral_act1_bridge_rooftop",
          tags: ["social"]
        },
        {
          id: "record_bargain",
          text: "Record their desperate plea (+1h)",
          cost: { time: 1 },
          effects: {
            inventoryAdd: ["blackmail_clip"],
            stats: { morality: -1, stress: +1 }
          },
          goTo: "neutral_act1_hub_apartment",
          tags: ["moral", "social"]
        }
      ]
    },

    neutral_act1_bridge_rooftop: {
      id: "neutral_act1_bridge_rooftop",
      text: "From the roof you see stadium flares and convoy headlights threading the interstate.",
      tags: ["leader"],
      choices: [
        {
          id: "signal_stadium",
          text: "Signal the Stadium wardens (+1h)",
          cost: { time: 1 },
          effects: {
            flagsSet: ["plan_stadium"],
            relationships: { Stadium: +3 }
          },
          goTo: "neutral_act2_hub_main",
          tags: ["social"]
        },
        {
          id: "descend_convoy",
          text: "Descend toward the convoy lights",
          effects: {
            flagsSet: ["plan_convoy"],
            stats: { stress: +1 }
          },
          goTo: "neutral_act2_hub_main",
          tags: ["survival"]
        }
      ]
    },

    neutral_act2_hub_main: {
      id: "neutral_act2_hub_main",
      text: "Curfew sirens sweep the streets. Havens radio for help while raiders tighten checkpoints.",
      tags: ["leader"],
      choices: [
        {
          id: "reinforce_haven",
          text: "Reinforce the Stadium perimeter (STA ≥ 10)",
          req: { stats: { stamina: { gte: 10 } } },
          goTo: "good_act2_setpiece_holdline",
          effects: { time: +1 },
          tags: ["combat", "leader"]
        },
        {
          id: "extort_checkpoint",
          text: "Extort the interstate checkpoint",
          goTo: "ant_act2_setpiece_checkpoint",
          effects: { stats: { morality: -1, stress: +1 } },
          tags: ["moral", "combat"]
        },
        {
          id: "broker_passage",
          text: "Broker passage for the Convoy",
          goTo: "man_act2_setpiece_parley",
          effects: { time: +1 },
          tags: ["social"]
        },
        {
          id: "check_aid",
          text: "Check the aid station",
          goTo: "neutral_act2_side_aidstation",
          effects: { stats: { stress: -1 } },
          tags: ["survival"]
        }
      ]
    },

    neutral_act2_side_aidstation: {
      id: "neutral_act2_side_aidstation",
      text: "An empty clinic hums under backup lights. Supplies sit behind a locked cage.",
      tags: ["survival"],
      choices: [
        {
          id: "force_cage",
          text: "Force the cage (−1 STA)",
          cost: { stamina: 1 },
          effects: {
            inventoryAdd: ["antibiotics"],
            stats: { morality: -1, stress: +2 }
          },
          tags: ["survival", "moral"],
          goTo: "neutral_act2_hub_main"
        },
        {
          id: "tend_wounded",
          text: "Tend the wounded (uses Antibiotics)",
          req: { items: ["antibiotics"] },
          effects: {
            inventoryRemove: ["antibiotics"],
            stats: { morality: +2, stress: -2 },
            relationships: { Stadium: +5 }
          },
          goTo: "neutral_act2_hub_main",
          tags: ["moral", "leader"]
        }
      ]
    },

    good_act2_setpiece_holdline: {
      id: "good_act2_setpiece_holdline",
      text: "Militia lines buckle at the stadium gate. Floodlights flicker as infected slam the barricades.",
      tags: ["combat", "leader"],
      choices: [
        {
          id: "rotate_fireteams",
          text: "Rotate fireteams (−2 STA, +1h)",
          cost: { stamina: 2, time: 1 },
          effects: {
            flagsSet: ["proof_good_act2"],
            stats: { stress: +3, morality: +1 },
            relationships: { Stadium: +6 }
          },
          goTo: "neutral_act2_bridge_curfew",
          tags: ["combat", "leader"]
        },
        {
          id: "call_volunteers",
          text: "Call for civilian bucket lines",
          effects: {
            stats: { stress: +1 },
            relationships: { Volunteers: +4 }
          },
          goTo: "neutral_act2_hub_main",
          tags: ["leader", "social"]
        }
      ]
    },

    ant_act2_setpiece_checkpoint: {
      id: "ant_act2_setpiece_checkpoint",
      text: "Your crew controls the interstate choke. Refugees huddle, clutching bribes and ration cards.",
      tags: ["combat", "moral"],
      choices: [
        {
          id: "tax_brutally",
          text: "Tax them brutally (+2h, −3 Morality)",
          cost: { time: 2 },
          effects: {
            stats: { morality: -3, stress: -2 },
            flagsSet: ["proof_ant_act2"],
            relationships: { Raiders: +6, Convoy: -5 },
            inventoryAdd: ["ammo_crate"]
          },
          goTo: "neutral_act2_bridge_curfew",
          tags: ["moral", "combat"]
        },
        {
          id: "sell_passes",
          text: "Sell passes quietly",
          effects: {
            stats: { stress: +2 },
            relationships: { Convoy: -3 }
          },
          goTo: "neutral_act2_hub_main",
          tags: ["social", "moral"]
        }
      ]
    },

    man_act2_setpiece_parley: {
      id: "man_act2_setpiece_parley",
      text: "Factions crowd a burned-out café to trade routes. Everyone watches to see who you favor.",
      tags: ["social", "leader"],
      choices: [
        {
          id: "trade_intel",
          text: "Trade raider intel for favors",
          req: { flags: ["raider_map"] },
          effects: {
            flagsSet: ["proof_man_act2"],
            relationships: { FreeCrews: +5, Raiders: -4 }
          },
          goTo: "neutral_act2_bridge_curfew",
          tags: ["social", "leader"]
        },
        {
          id: "play_both",
          text: "Play both sides (+1h)",
          cost: { time: 1 },
          effects: {
            stats: { morality: -1 },
            relationships: { Convoy: +3, Raiders: +3 }
          },
          goTo: "neutral_act2_hub_main",
          tags: ["social"]
        }
      ]
    },

    neutral_act2_bridge_curfew: {
      id: "neutral_act2_bridge_curfew",
      text: "Curfew drones buzz overhead. Decisions here will echo when dawn sirens return.",
      tags: ["leader"],
      choices: [
        {
          id: "push_to_dawn",
          text: "Push toward dawn operations",
          effects: { time: +1 },
          goTo: "neutral_act3_hub_main",
          tags: ["leader"]
        },
        {
          id: "circle_back",
          text: "Circle back for unfinished business",
          goTo: "neutral_act2_hub_main",
          effects: { stats: { stress: +1 } },
          tags: ["survival"]
        }
      ]
    },

    neutral_act3_hub_main: {
      id: "neutral_act3_hub_main",
      text: "Dawn light hits smoke columns. Proofs gathered so far decide who still answers your call.",
      tags: ["leader"],
      choices: [
        {
          id: "secure_rooftops",
          text: "Secure rooftop liaisons",
          goTo: "good_act3_setpiece_blackout",
          effects: { time: +1 },
          tags: ["leader"]
        },
        {
          id: "fortify_raiders",
          text: "Fortify raider barricades",
          goTo: "ant_act3_setpiece_barricade",
          effects: { stats: { morality: -1 } },
          tags: ["combat"]
        },
        {
          id: "broker_secret",
          text: "Broker a secret summit",
          goTo: "man_act3_setpiece_congress",
          effects: { time: +1 },
          tags: ["social"]
        }
      ]
    },

    good_act3_setpiece_blackout: {
      id: "good_act3_setpiece_blackout",
      text: "Power dies across the stadium. Refugees fumble in dark aisles while a horde gathers outside.",
      tags: ["combat", "leader"],
      choices: [
        {
          id: "ignite_flares",
          text: "Ignite emergency flares (lose Flare)",
          req: { items: ["flare"] },
          effects: {
            inventoryRemove: ["flare"],
            flagsSet: ["proof_good_act3"],
            stats: { morality: +2, stress: +3 }
          },
          goTo: "neutral_act3_bridge_dawn",
          tags: ["leader", "combat"]
        },
        {
          id: "marshal_crowd",
          text: "Marshal the crowd without light",
          effects: {
            stats: { stress: +4 },
            relationships: { Volunteers: +5 }
          },
          goTo: "neutral_act3_bridge_dawn",
          tags: ["leader"]
        }
      ]
    },

    ant_act3_setpiece_barricade: {
      id: "ant_act3_setpiece_barricade",
      text: "Raiders drag welded cars into a kill corridor. Refugees trapped inside beg for water.",
      tags: ["moral", "combat"],
      choices: [
        {
          id: "deny_water",
          text: "Deny them water (−2 Morality)",
          effects: {
            stats: { morality: -2 },
            flagsSet: ["proof_ant_act3"],
            relationships: { Raiders: +7, FreeCrews: -6 }
          },
          goTo: "neutral_act3_bridge_dawn",
          tags: ["moral", "combat"]
        },
        {
          id: "stage_execution",
          text: "Stage a public execution (STA ≥ 8)",
          req: { stats: { stamina: { gte: 8 } } },
          effects: {
            stats: { stress: -2 },
            flagsSet: ["proof_ant_act3"],
            relationships: { Raiders: +5, Volunteers: -6 }
          },
          goTo: "neutral_act3_bridge_dawn",
          tags: ["moral", "combat"]
        }
      ]
    },

    man_act3_setpiece_congress: {
      id: "man_act3_setpiece_congress",
      text: "Faction envoys whisper inside a shuttered ballroom. They want guarantees only you can trade.",
      tags: ["social", "leader"],
      choices: [
        {
          id: "swap_hostages",
          text: "Swap hostages for alliance",
          effects: {
            flagsSet: ["proof_man_act3"],
            relationships: { Stadium: +4, Raiders: -4, Convoy: +4 }
          },
          goTo: "neutral_act3_bridge_dawn",
          tags: ["social"]
        },
        {
          id: "sell_out",
          text: "Sell out a faction for secrets",
          effects: {
            stats: { morality: -2 },
            inventoryAdd: ["blackmail_dossier"],
            relationships: { FreeCrews: -5, Convoy: +5 }
          },
          goTo: "neutral_act3_bridge_dawn",
          tags: ["moral", "social"]
        }
      ]
    },

    neutral_act3_bridge_dawn: {
      id: "neutral_act3_bridge_dawn",
      text: "Sunrise paints the skyline blood-orange. Route leaders demand proof before committing to your endgame.",
      tags: ["leader"],
      choices: [
        {
          id: "protector_finale",
          text: "Rally the protector route (needs 3 proofs)",
          req: { flags: ROUTE_PROOFS.good },
          goTo: "good_act5_ending_theLongWatch",
          tags: ["leader"]
        },
        {
          id: "warlord_finale",
          text: "Cement warlord rule (needs 3 proofs)",
          req: { flags: ROUTE_PROOFS.ant },
          goTo: "ant_act5_ending_ironReign",
          tags: ["combat", "leader"]
        },
        {
          id: "fixer_finale",
          text: "Pull every string (needs 3 proofs)",
          req: { flags: ROUTE_PROOFS.man },
          goTo: "man_act5_ending_whisperedDeals",
          tags: ["social"]
        },
        {
          id: "regroup",
          text: "Regroup and reassess",
          goTo: "neutral_act3_hub_main",
          effects: { stats: { stress: +1 } },
          tags: ["survival"]
        }
      ]
    },

    good_act5_ending_theLongWatch: {
      id: "good_act5_ending_theLongWatch",
      text: "You chain rooftop beacons across the district. Civilians guide columns through the night, whispering your name with relief.",
      isEnding: true,
      endingType: "good",
      tags: ["leader"]
    },

    ant_act5_ending_ironReign: {
      id: "ant_act5_ending_ironReign",
      text: "Checkpoint fires burn while you ration water to the obedient. The city bows under sirens tuned to your command.",
      isEnding: true,
      endingType: "ruthless",
      tags: ["combat"]
    },

    man_act5_ending_whisperedDeals: {
      id: "man_act5_ending_whisperedDeals",
      text: "Convoy engines idle under your balcony as envoys trade sealed promises. No door opens without your quiet nod.",
      isEnding: true,
      endingType: "manipulator",
      tags: ["social"]
    }
  };

  window.STORY_DATABASE = STORY_DATABASE;

  function hasItem(state, item) {
    return state.inventory.includes(item);
  }

  function applyInventoryAdd(state, items = []) {
    for (const item of items || []) {
      if (!item) continue;
      state.inventory.push(item);
    }
  }

  function applyInventoryRemove(state, items = []) {
    for (const item of items || []) {
      const index = state.inventory.indexOf(item);
      if (index >= 0) state.inventory.splice(index, 1);
    }
  }

  function applyRelationships(state, deltas = {}) {
    for (const [name, delta] of Object.entries(deltas)) {
      const current = state.relationships[name] ?? 0;
      let next = current + delta;
      if (next > 100) next = 100;
      if (next < -100) next = -100;
      state.relationships[name] = next;
    }
  }

  function evaluateRequirements(state, choice) {
    const req = choice.req;
    if (!req) return { ok: true };

    if (req.items) {
      for (const item of req.items) {
        if (!hasItem(state, item)) {
          return { ok: false, reason: `Need ${item}` };
        }
      }
    }

    if (req.flags) {
      for (const flag of req.flags) {
        if (!state.flags[flag]) {
          return { ok: false, reason: `Requires ${flag}` };
        }
      }
    }

    if (req.stats) {
      for (const [stat, conditions] of Object.entries(req.stats)) {
        const value = state.stats[stat] ?? 0;
        if (conditions.gte != null && value < conditions.gte) {
          return { ok: false, reason: `${stat} ≥ ${conditions.gte}` };
        }
        if (conditions.lte != null && value > conditions.lte) {
          return { ok: false, reason: `${stat} ≤ ${conditions.lte}` };
        }
      }
    }

    return { ok: true };
  }

  function applyCost(state, cost = {}) {
    if (!cost) return;
    if (typeof cost.time === "number") {
      state.time += cost.time;
    }
    if (typeof cost.stamina === "number") {
      state.stats.stamina = (state.stats.stamina ?? 0) - cost.stamina;
    }
    if (typeof cost.stress === "number") {
      state.stats.stress = (state.stats.stress ?? 0) + cost.stress;
    }
    if (cost.items) {
      applyInventoryRemove(state, cost.items);
    }
    clampStats(state.stats);
  }

  function applyFlags(state, setList = [], unsetList = []) {
    for (const flag of setList || []) {
      const mutexGroup = FLAG_TO_MUTEX.get(flag);
      if (mutexGroup) {
        setMutex(state, mutexGroup, flag);
      } else {
        state.flags[flag] = true;
      }
    }
    for (const flag of unsetList || []) {
      delete state.flags[flag];
    }
  }

  function applyEffects(state, effects = {}) {
    if (typeof effects.time === "number") {
      state.time += effects.time;
    }
    if (effects.stats) {
      for (const [stat, delta] of Object.entries(effects.stats)) {
        state.stats[stat] = (state.stats[stat] ?? 0) + delta;
      }
    }
    if (effects.inventoryAdd) applyInventoryAdd(state, effects.inventoryAdd);
    if (effects.inventoryRemove) applyInventoryRemove(state, effects.inventoryRemove);
    if (effects.flagsSet || effects.flagsUnset) {
      applyFlags(state, effects.flagsSet, effects.flagsUnset);
    }
    if (effects.relationships) applyRelationships(state, effects.relationships);
    clampStats(state.stats);
  }

  function shouldPopup(choiceEffects = {}) {
    const rel = choiceEffects.relationships || {};
    const relSpike = Object.values(rel).some((v) => Math.abs(v) >= 5);
    const flips = (choiceEffects.flagsSet || []).some((f) => CONSEQUENCE_FLAGS.has(f));
    return relSpike || flips;
  }

  function makeHash(state) {
    return btoa(
      encodeURIComponent(
        JSON.stringify({
          sceneId: state.sceneId,
          time: state.time,
          stats: state.stats,
          inventory: state.inventory,
          flags: state.flags,
          relationships: state.relationships,
          decisionTrace: state.decisionTrace
        })
      )
    ).slice(0, 32);
  }

  function formatTime(hours) {
    const day = Math.floor(hours / 24);
    const hour = Math.floor(hours % 24);
    const minute = Math.round((hours % 1) * 60);
    const paddedHour = hour.toString().padStart(2, "0");
    const paddedMinute = minute.toString().padStart(2, "0");
    return { label: `Day ${day} · ${paddedHour}:${paddedMinute}`, absolute: `T+${hours}h` };
  }

  function wordCount(text = "") {
    return text.trim() ? text.trim().split(/\s+/).length : 0;
  }

  function validateStory(story) {
    const errors = [];
    const warnings = [];
    const idPattern = /^(good|ant|man|neutral)_act[1-5]_(hub|setpiece|side|bridge|ending)_[a-z0-9_]+$/;
    const reachable = new Set();
    const queue = ["neutral_act1_hub_apartment"];

    const allIds = Object.keys(story);

    for (const [id, scene] of Object.entries(story)) {
      if (!scene.text) {
        errors.push(`${id}: missing text`);
      }
      if (!scene.isEnding) {
        if (!Array.isArray(scene.choices) || scene.choices.length === 0) {
          errors.push(`${id}: non-ending scene must have choices`);
        }
      } else if (scene.choices && scene.choices.length > 0) {
        errors.push(`${id}: endings cannot have choices`);
      }
      if (scene.tags) {
        for (const tag of scene.tags) {
          if (!TAGS_ALLOWED.has(tag)) {
            warnings.push(`${id}: tag ${tag} not in approved set`);
          }
        }
      }
      if (scene.text && wordCount(scene.text) > 140) {
        warnings.push(`${id}: text exceeds 140 words`);
      }
      if (scene.id !== "intro" && !scene.isEnding && !idPattern.test(id)) {
        warnings.push(`${id}: id does not match expected pattern`);
      }
      if (Array.isArray(scene.choices)) {
        let goToCount = 0;
        for (const choice of scene.choices) {
          if (!choice) continue;
          const hasEffect = choice.effects && Object.keys(choice.effects).length > 0;
          if (!choice.goTo && !hasEffect) {
            errors.push(`${id}: choice "${choice.text}" lacks goTo and effects`);
          }
          if (choice.goTo === id) {
            warnings.push(`${id}: choice "${choice.text}" self-loops`);
          }
          if (choice.goTo) {
            goToCount += 1;
            if (!story[choice.goTo]) {
              errors.push(`${id}: choice "${choice.text}" targets missing scene ${choice.goTo}`);
            }
          }
          if (choice.effects?.flagsSet) {
            for (const flag of choice.effects.flagsSet) {
              const group = FLAG_TO_MUTEX.get(flag);
              if (group) {
                const others = choice.effects.flagsSet.filter((f) => FLAG_TO_MUTEX.get(f) === group);
                if (others.length > 1) {
                  errors.push(`${id}: choice "${choice.text}" sets multiple flags from mutex group ${group}`);
                }
              }
            }
          }
          if (choice.cost?.items) {
            const reqItems = new Set(choice.req?.items || []);
            for (const item of choice.cost.items) {
              if (!reqItems.has(item)) {
                warnings.push(`${id}: choice "${choice.text}" consumes ${item} without requiring it`);
              }
            }
          }
        }
        if (id.includes("_hub_") && goToCount < 2 && !story[id].isEnding) {
          warnings.push(`${id}: hub scenes should offer at least two exits`);
        }
      }
    }

    while (queue.length) {
      const current = queue.shift();
      if (reachable.has(current)) continue;
      reachable.add(current);
      const scene = story[current];
      if (!scene || !scene.choices) continue;
      for (const choice of scene.choices) {
        if (choice?.goTo && story[choice.goTo]) {
          queue.push(choice.goTo);
        }
      }
    }

    for (const id of allIds) {
      if (!reachable.has(id) && !story[id].isEnding) {
        warnings.push(`${id}: scene is unreachable from intro`);
      }
    }

    return { errors, warnings };
  }
  function mulberry32(seed) {
    return function () {
      let t = (seed += 0x6d2b79f5);
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function runRandomWalkCoverage(story, { runs = 200, maxSteps = 120 } = {}) {
    const visited = new Set();
    const endings = new Set();
    const sceneIds = Object.keys(story);
    const shortestToEnding = new Map();

    for (let r = 0; r < runs; r++) {
      let state = INITIAL_STATE();
      const rng = mulberry32(state.rngSeed + r);
      for (let step = 0; step < maxSteps; step++) {
        const scene = story[state.sceneId];
        if (!scene) break;
        visited.add(state.sceneId);
        if (scene.isEnding) {
          endings.add(scene.id);
          const currentShortest = shortestToEnding.get(scene.id) ?? step;
          if (step < currentShortest) shortestToEnding.set(scene.id, step);
          break;
        }
        const enabled = (scene.choices || []).filter((choice) => {
          const { ok } = evaluateRequirements(state, choice);
          return ok;
        });
        if (enabled.length === 0) break;
        const choice = enabled[Math.floor(rng() * enabled.length)];
        applyCost(state, choice.cost);
        applyEffects(state, choice.effects);
        if (!choice.goTo) break;
        state.decisionTrace.push(`${scene.id}::${choice.id || choice.text}`);
        state.sceneId = choice.goTo;
      }
    }

    const coverage = visited.size / sceneIds.length;
    return { coverage, visited: Array.from(visited), endings: Array.from(endings), shortestToEnding };
  }

  class ConsequenceGame {
    constructor() {
      this.story = STORY_DATABASE;
      this.state = INITIAL_STATE();
      this.eventLog = [];
      this.popupTimer = null;
      this.sceneRendered = false;
      this.dom = this.cacheDom();
      this.bindControls();
      this.loadAutosave();
      this.validation = validateStory(this.story);
      this.coverage = runRandomWalkCoverage(this.story, { runs: 100, maxSteps: 120 });
      if (!this.sceneRendered) {
        this.renderScene(this.state.sceneId);
      } else {
        this.renderStats();
      }
      if (this.validation.errors.length) {
        console.error("Story validation errors:", this.validation.errors);
      }
      if (this.validation.warnings.length) {
        console.warn("Story validation warnings:", this.validation.warnings);
      }
      console.info("Random walk coverage", this.coverage);
    }

    cacheDom() {
      return {
        stats: document.getElementById("stats"),
        story: document.getElementById("scene-text"),
        choices: document.getElementById("choices"),
        inventory: document.getElementById("inventory-list"),
        eventLog: document.getElementById("event-log"),
        relationships: document.getElementById("relationships-list"),
        relationshipCount: document.getElementById("relationship-count"),
        decisionTree: document.getElementById("decision-tree"),
        flagDisplay: document.getElementById("flag-display"),
        stateHash: document.getElementById("state-hash"),
        dayHour: document.getElementById("dayhour-indicator"),
        worldTime: document.getElementById("world-time"),
        popup: document.getElementById("consequence-popup"),
        popupText: document.getElementById("consequence-text"),
        popupOk: document.getElementById("consequence-ok"),
        personaGrid: document.getElementById("persona-grid")
      };
    }

    bindControls() {
      document.getElementById("new-game")?.addEventListener("click", () => this.newGame());
      document.getElementById("continue-game")?.addEventListener("click", () => this.renderScene());
      document.getElementById("save-game")?.addEventListener("click", () => this.save());
      document.getElementById("load-game")?.addEventListener("click", () => document.getElementById("file-loader")?.click());
      document.getElementById("export-game")?.addEventListener("click", () => this.export());
      document.getElementById("file-loader")?.addEventListener("change", (ev) => this.import(ev));
      this.dom.popupOk?.addEventListener("click", () => this.hidePopup());
    }

    loadAutosave() {
      try {
        const raw = localStorage.getItem(SAVE_KEY);
        if (!raw) return;
        const parsed = JSON.parse(raw);
        if (parsed && parsed.sceneId) {
          this.state = { ...INITIAL_STATE(), ...parsed };
          this.renderScene(parsed.sceneId);
          this.sceneRendered = true;
        }
      } catch (err) {
        console.warn("Failed to load autosave", err);
      }
    }

    newGame() {
      this.state = INITIAL_STATE();
      this.eventLog = [];
      this.persist();
      this.renderScene(this.state.sceneId);
    }

    save() {
      try {
        localStorage.setItem(SAVE_KEY, JSON.stringify(this.state));
        this.pushEvent("Game saved locally.");
      } catch (err) {
        console.warn("Failed to save", err);
      }
    }

    export() {
      const blob = new Blob([JSON.stringify(this.state, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `${WORKING_TITLE.replace(/\s+/g, "_")}_save.json`;
      a.click();
      URL.revokeObjectURL(url);
    }

    import(event) {
      const file = event.target?.files?.[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = (e) => {
        try {
          const data = JSON.parse(e.target.result);
          this.state = { ...INITIAL_STATE(), ...data };
          this.persist();
          this.renderScene(this.state.sceneId);
        } catch (err) {
          console.warn("Failed to load save", err);
        }
      };
      reader.readAsText(file);
    }

    persist() {
      try {
        localStorage.setItem(SAVE_KEY, JSON.stringify(this.state));
      } catch (err) {
        console.warn("Autosave failed", err);
      }
    }

    renderScene(nextSceneId) {
      if (nextSceneId) {
        this.state.sceneId = normalizeSceneId(nextSceneId) || this.state.sceneId;
      }
      const scene = this.story[this.state.sceneId];
      if (!scene) {
        this.displayStory(`Missing scene: ${this.state.sceneId}`);
        return;
      }

      if (scene.id.includes("_hub_")) {
        this.state.time += 1;
      }

      this.displayStory(scene.text);
      this.displayChoices(scene);
      this.renderStats();
      this.renderInventory();
      this.renderRelationships();
      this.renderDebug();
      this.persist();
      this.sceneRendered = true;
    }

    renderStats() {
      if (!this.dom.stats) return;
      const stats = this.state.stats;
      const timeFmt = formatTime(this.state.time);
      this.dom.stats.innerHTML = `
        <div class="stats-group">
          <span class="stat-pill">Health: ${stats.health}</span>
          <span class="stat-pill">Stamina: ${stats.stamina}</span>
          <span class="stat-pill">Stress: ${stats.stress}</span>
          <span class="stat-pill">Morality: ${stats.morality}</span>
        </div>
        <div class="status-pill timer-neutral">${timeFmt.absolute}</div>
      `;
      if (this.dom.dayHour) this.dom.dayHour.textContent = timeFmt.label;
      if (this.dom.worldTime) this.dom.worldTime.textContent = timeFmt.absolute;
    }

    displayStory(text) {
      if (!this.dom.story) return;
      this.dom.story.textContent = text;
    }

    displayChoices(scene) {
      if (!this.dom.choices) return;
      const container = this.dom.choices;
      container.innerHTML = "";
      if (scene.isEnding) {
        const endNotice = document.createElement("div");
        endNotice.className = "ending-banner";
        endNotice.textContent = "This route concludes here.";
        container.appendChild(endNotice);
        return;
      }

      const enabledButtons = [];
      for (const choice of scene.choices || []) {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "choice";
        button.textContent = choice.text;
        const { ok, reason } = evaluateRequirements(this.state, choice);
        if (!ok) {
          button.disabled = true;
          button.title = reason || "Unavailable";
        } else {
          button.addEventListener("click", () => this.makeChoice(scene, choice));
          enabledButtons.push(button);
        }
        container.appendChild(button);
      }

      if (enabledButtons.length === 0) {
        const fallback = document.createElement("button");
        fallback.type = "button";
        fallback.className = "choice fallback";
        fallback.textContent = "Catch your breath (+1h, +3 Stress)";
        fallback.addEventListener("click", () => {
          applyEffects(this.state, { time: +1, stats: { stress: +3 } });
          this.pushEvent("You stall, burning precious time.");
          this.renderScene(scene.id);
        });
        container.appendChild(fallback);
      }
    }

    makeChoice(scene, choice) {
      const { ok } = evaluateRequirements(this.state, choice);
      if (!ok) return;
      applyCost(this.state, choice.cost);
      applyEffects(this.state, choice.effects);
      const traceId = `${scene.id}::${choice.id || choice.text}`;
      this.state.decisionTrace.push(traceId);
      if (shouldPopup(choice.effects)) {
        this.showPopup();
      }
      this.pushEvent(choice.effects?.log || `Chose: ${choice.text}`);
      if (choice.goTo) {
        this.renderScene(choice.goTo);
      } else {
        this.renderScene(scene.id);
      }
    }

    pushEvent(text) {
      if (!text) return;
      const timestamp = formatTime(this.state.time).absolute;
      this.eventLog.unshift(`${timestamp}: ${text}`);
      if (this.eventLog.length > 20) this.eventLog.pop();
      if (!this.dom.eventLog) return;
      this.dom.eventLog.innerHTML = this.eventLog.map((line) => `<div>${line}</div>`).join("");
    }

    renderInventory() {
      if (!this.dom.inventory) return;
      const list = this.state.inventory;
      if (list.length === 0) {
        this.dom.inventory.innerHTML = '<span class="empty-inventory">(empty)</span>';
        return;
      }
      this.dom.inventory.innerHTML = list.map((item) => `<span class="inventory-item">${item}</span>`).join("");
    }

    renderRelationships() {
      if (!this.dom.relationships) return;
      const entries = Object.entries(this.state.relationships).sort((a, b) => b[1] - a[1]);
      if (entries.length === 0) {
        this.dom.relationships.innerHTML = '<div class="relationship-empty">No contacts yet.</div>';
        if (this.dom.relationshipCount) this.dom.relationshipCount.textContent = "0 contacts";
        return;
      }
      this.dom.relationships.innerHTML = entries
        .map(([name, value]) => `<div class="relationship-item"><span>${name}</span><span>${value}</span></div>`)
        .join("");
      if (this.dom.relationshipCount) this.dom.relationshipCount.textContent = `${entries.length} contacts`;
    }

    renderDebug() {
      if (this.dom.decisionTree) {
        this.dom.decisionTree.textContent = this.state.decisionTrace.join(" → ");
      }
      if (this.dom.flagDisplay) {
        const active = Object.keys(this.state.flags).filter((f) => this.state.flags[f]);
        this.dom.flagDisplay.textContent = active.join(", ");
      }
      if (this.dom.stateHash) {
        this.dom.stateHash.textContent = makeHash(this.state);
      }
    }

    showPopup() {
      if (!this.dom.popup || !this.dom.popupText) return;
      this.dom.popupText.textContent = "They'll remember that.";
      this.dom.popup.classList.remove("hidden");
      if (this.popupTimer) {
        clearTimeout(this.popupTimer);
      }
      this.popupTimer = setTimeout(() => this.hidePopup(), 2500);
    }

    hidePopup() {
      if (!this.dom.popup) return;
      this.dom.popup.classList.add("hidden");
    }
  }

  window.ConsequenceGame = ConsequenceGame;
  window.THE_LONG_SIREN_WORLD_BIBLE = WORLD_BIBLE;
  window.runConsequenceCoverage = () => runRandomWalkCoverage(STORY_DATABASE, { runs: 500, maxSteps: 200 });
})();
