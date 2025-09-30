;(() => {
  "use strict";

  const WORKING_TITLE = "CONSEQUENCE";
  const SAVE_KEY = "consequence_offline_save";

  const ROUTES = ["good", "ant", "man", "killer", "socio", "neutral"];

  const ROUTE_TITLES = {
    good: "Protector",
    ant: "Warlord",
    man: "Fixer",
    killer: "Killer",
    socio: "Sociopath",
    neutral: "Neutral"
  };

  const ROUTE_PROOFS = {
    good: ["proof_protector_rescue", "proof_protector_shield", "proof_protector_convoy"],
    ant: ["proof_warlord_fear", "proof_warlord_tithe", "proof_warlord_domination"],
    man: ["proof_fixer_deal", "proof_fixer_network", "proof_fixer_lock"],
    killer: ["proof_killer_cull", "proof_killer_extraction", "proof_killer_obedience"],
    socio: ["proof_socio_stage", "proof_socio_confession", "proof_socio_mirror"]
  };

  const MUTEX = {
    faction: ["joined_militia", "joined_raiders", "faction_neutral"],
    endgame: ["goal_stadium", "goal_convoy", "goal_refinery"],
    alex: ["alex_trust", "alex_wary", "alex_dead"]
  };

  const CONSEQUENCE_FLAGS = new Set([
    "joined_militia",
    "joined_raiders",
    "faction_neutral",
    "goal_stadium",
    "goal_convoy",
    "goal_refinery",
    "refinery_burned",
    "convoy_betrayed",
    "wall_breached",
    "rescued_convoy",
    "held_line",
    "shared_rations",
    "proof_protector_rescue",
    "proof_protector_shield",
    "proof_protector_convoy",
    "proof_warlord_fear",
    "proof_warlord_tithe",
    "proof_warlord_domination",
    "proof_fixer_deal",
    "proof_fixer_network",
    "proof_fixer_lock",
    "proof_killer_cull",
    "proof_killer_extraction",
    "proof_killer_obedience",
    "proof_socio_stage",
    "proof_socio_confession",
    "proof_socio_mirror",
    "alex_trust",
    "alex_wary",
    "alex_dead"
  ]);

  const STATS_MIN_MAX = {
    health: [0, 100],
    stamina: [0, 20],
    stress: [0, 100],
    morality: [-20, 20],
    trauma: [0, 120],
    strength: [0, 20],
    agility: [0, 20],
    willpower: [0, 20],
    charisma: [0, 20]
  };

  const START_INVENTORY = {
    medic: ["medkit", "bandage_roll"],
    scrapper: ["crowbar", "flare"],
    sentinel: ["service_pistol", "ammo_mag"]
  };

  const PERSONA_BASE = {
    protector: 0,
    warlord: 0,
    fixer: 0,
    killer: 0,
    sociopath: 0
  };

  function clone(value) {
    return value ? JSON.parse(JSON.stringify(value)) : value;
  }

  function createInitialState() {
    return {
      sceneId: "neutral_act0_hub_identity",
      time: 0,
      stats: {
        health: 100,
        stamina: 12,
        stress: 0,
        morality: 0,
        trauma: 0,
        strength: 6,
        agility: 6,
        willpower: 6,
        charisma: 6
      },
      inventory: [],
      flags: { faction_neutral: true },
      relationships: { Alex: 0, Volunteers: 0, Raiders: 0, Convoy: 0, Stadium: 0, FreeCrews: 0 },
      persona: clone(PERSONA_BASE),
      identity: { name: "Alex's Neighbor", background: "Unknown" },
      journal: [],
      decisionTrace: [],
      rngSeed: 1337
    };
  }

  function setMutex(state, group, flag) {
    const peers = MUTEX[group];
    if (!peers) return;
    for (const f of peers) {
      if (f !== flag) delete state.flags[f];
    }
    state.flags[flag] = true;
  }

  function clampStats(stats) {
    for (const [key, [min, max]] of Object.entries(STATS_MIN_MAX)) {
      if (!(key in stats)) continue;
      if (stats[key] < min) stats[key] = min;
      if (stats[key] > max) stats[key] = max;
    }
  }

  function randFromSeed(seed) {
    let t = seed + 0x6D2B79F5;
    t = Math.imul(t ^ t >>> 15, t | 1);
    t ^= t + Math.imul(t ^ t >>> 7, t | 61);
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  }

  function shouldPopup(effects = {}) {
    const rel = effects.relationships || {};
    const relSpike = Object.values(rel).some((v) => Math.abs(v) >= 5);
    const flips = (effects.flagsSet || []).some((flag) => CONSEQUENCE_FLAGS.has(flag));
    return relSpike || flips;
  }

  function normalizeSceneId(id) {
    return typeof id === "string" ? id.trim() : id;
  }

  const STORY_DATABASE = {
    neutral_act0_hub_identity: {
      id: "neutral_act0_hub_identity",
      text: "Day 0, hour 0. Sirens moan outside your apartment door. Alex's fists hammer in panic. Before you unlatch anything, choose who you are in this crumbling tower.",
      timeDelta: 1,
      tags: ["social"],
      choices: [
        {
          id: "choose_name_river",
          text: "Claim the name River (calm under pressure).",
          goTo: "neutral_act0_setpiece_identity_background",
          effects: {
            identity: { name: "River", persona: "calm" },
            stats: { willpower: +1, stress: -1 },
            pushEvent: "You steady your breathing and answer to River."
          }
        },
        {
          id: "choose_name_jules",
          text: "Answer as Jules (sharp survivor).",
          goTo: "neutral_act0_setpiece_identity_background",
          effects: {
            identity: { name: "Jules", persona: "focused" },
            stats: { agility: +1, stress: +1 },
            pushEvent: "You whisper your own name to stay real."
          }
        },
        {
          id: "choose_name_morgan",
          text: "Introduce yourself as Morgan (unbreakable).",
          goTo: "neutral_act0_setpiece_identity_background",
          effects: {
            identity: { name: "Morgan", persona: "unyielding" },
            stats: { strength: +1, willpower: +1, stress: +1 },
            pushEvent: "Steel settles behind your teeth: you are Morgan."
          }
        }
      ]
    },

    neutral_act0_setpiece_identity_background: {
      id: "neutral_act0_setpiece_identity_background",
      text: "Alex muffles a sob beyond the latch. You grab the emergency locker and remember the skills that carried you before the sirens.",
      tags: ["social", "leader"],
      choices: [
        {
          id: "background_medic",
          text: "You trained as a medic — pack the trauma kit.",
          goTo: "neutral_act0_setpiece_apartment_door",
          effects: {
            identity: { background: "medic" },
            stats: { morality: +2, trauma: -2, charisma: +1 },
            inventoryAdd: START_INVENTORY.medic,
            pushEvent: "Medical instincts return in a rush."
          },
          tags: ["moral", "survival"]
        },
        {
          id: "background_scrapper",
          text: "You hustled salvage — rig the pry-bars and flares.",
          goTo: "neutral_act0_setpiece_apartment_door",
          effects: {
            identity: { background: "scrapper" },
            stats: { agility: +1, strength: +1, morality: -1 },
            inventoryAdd: START_INVENTORY.scrapper,
            pushEvent: "You sling scavenged tools across your back."
          },
          tags: ["survival", "stealth"]
        },
        {
          id: "background_sentinel",
          text: "You were building security plans — chamber the pistol.",
          goTo: "neutral_act0_setpiece_apartment_door",
          effects: {
            identity: { background: "sentinel" },
            stats: { willpower: +2, stress: +1, morality: -1 },
            inventoryAdd: START_INVENTORY.sentinel,
            pushEvent: "The old duty manual flashes in your mind."
          },
          tags: ["combat", "leader"]
        }
      ]
    },

    neutral_act0_setpiece_apartment_door: {
      id: "neutral_act0_setpiece_apartment_door",
      text: "Alex gasps through the chain: \"They're turning floors below. Please let me in. I grabbed what I could.\" Your hallway camera shows smears of blood and a shadow rounding the stairwell.",
      tags: ["social", "moral"],
      choices: [
        {
          id: "verify_blood",
          text: "Check Alex for bites before anything else.",
          goTo: "neutral_act0_side_verification",
          effects: {
            stats: { stress: +1 },
            pushEvent: "You demand proof through the chain."
          },
          tags: ["leader", "survival"]
        },
        {
          id: "pass_supplies",
          text: "Pass supplies through the gap to buy time.",
          goTo: "neutral_act0_side_supply_gap",
          cost: { items: ["bandage_roll"] },
          req: { items: ["bandage_roll"] },
          effects: {
            stats: { morality: +1, stress: +1 },
            pushEvent: "You slide bandages through the chain."
          },
          tags: ["moral", "social"]
        },
        {
          id: "open_now",
          text: "Unlatch the door and pull Alex inside.",
          goTo: "neutral_act0_side_immediate_entry",
          effects: {
            flagsSet: ["alex_trust"],
            relationships: { Alex: +6 },
            pushEvent: "You drag Alex over the barricade."
          },
          tags: ["social", "leader"]
        }
      ]
    },

    neutral_act0_side_verification: {
      id: "neutral_act0_side_verification",
      text: "Alex thrusts their wrists through the crack. Trembling fingers, bruised knuckles, a smear of someone else's blood. No bite marks. \"Please, River. I heard them behind me.\"",
      tags: ["social", "survival"],
      choices: [
        {
          id: "accept_proof",
          text: "Unlock and reinforce the door together.",
          goTo: "neutral_act0_side_immediate_entry",
          effects: {
            flagsSet: ["alex_trust"],
            relationships: { Alex: +8 },
            stats: { stress: +2, morality: +1 }
          }
        },
        {
          id: "reject_proof",
          text: "Keep Alex outside and order them to clear the stairwell.",
          goTo: "neutral_act0_side_lockout",
          effects: {
            flagsSet: ["alex_wary"],
            relationships: { Alex: -6 },
            stats: { morality: -2, stress: +3 }
          }
        }
      ]
    },

    neutral_act0_side_supply_gap: {
      id: "neutral_act0_side_supply_gap",
      text: "You brace the door while handing off sterile gauze and a ration bar. Alex nods, gratitude mixing with betrayal. \"You won't last alone,\" they warn.",
      tags: ["social", "survival"],
      choices: [
        {
          id: "invite_after_supply",
          text: "Let Alex inside after the exchange.",
          goTo: "neutral_act0_side_immediate_entry",
          effects: {
            flagsSet: ["alex_trust"],
            relationships: { Alex: +4 },
            stats: { morality: +1 }
          }
        },
        {
          id: "lock_after_supply",
          text: "Bolt the door and keep them out.",
          goTo: "neutral_act0_side_lockout",
          effects: {
            flagsSet: ["alex_wary"],
            relationships: { Alex: -8 },
            stats: { morality: -3, stress: +2 }
          }
        }
      ]
    },

    neutral_act0_side_immediate_entry: {
      id: "neutral_act0_side_immediate_entry",
      text: "Alex tumbles inside clutching a soaked duffel. Together you ram furniture against the door as a screamer slams from the hall.",
      tags: ["leader", "combat"],
      choices: [
        {
          id: "share_plan",
          text: "Share your plan to fortify the floor.",
          goTo: "neutral_act0_bridge_to_act1",
          effects: {
            relationships: { Alex: +4 },
            stats: { willpower: +1 },
            pushEvent: "Alex nods, trusting your voice." }
        },
        {
          id: "check_injury",
          text: "Check Alex's injuries and hand over painkillers.",
          goTo: "neutral_act0_bridge_to_act1",
          req: { items: ["bandage_roll"] },
          effects: {
            inventoryRemove: ["bandage_roll"],
            stats: { morality: +1, stress: -1 },
            relationships: { Alex: +6 }
          }
        }
      ]
    },

    neutral_act0_side_lockout: {
      id: "neutral_act0_side_lockout",
      text: "You seal the door. Alex's fists pound once more, then fade. Moments later a wet shriek answers them. Silence settles heavy.",
      tags: ["moral", "survival"],
      choices: [
        {
          id: "face_consequence",
          text: "Stare at the peephole until sunrise.",
          goTo: "neutral_act0_bridge_to_act1",
          effects: {
            flagsSet: ["alex_dead"],
            stats: { stress: +6, morality: -4, trauma: +8 },
            relationships: { Alex: -12 },
            pushEvent: "You feel the building remember your choice." }
        },
        {
          id: "loot_pack",
          text: "Loot the abandoned hallway for supplies.",
          goTo: "neutral_act0_bridge_to_act1",
          effects: {
            inventoryAdd: ["ration_brick"],
            stats: { stress: +2, morality: -2 }
          }
        }
      ]
    },

    neutral_act0_bridge_to_act1: {
      id: "neutral_act0_bridge_to_act1",
      text: "Dawn bleeds through the blinds. Whether Alex rests on your couch or stains the hall outside, the building looks to you for the next call.",
      tags: ["leader"],
      choices: [
        {
          id: "step_into_hall",
          text: "Rally the floor and hold the stairwell (Protector path).",
          goTo: "neutral_act1_hub_apartment",
          effects: {
            personaTilt: { protector: +1 },
            stats: { stress: +1 }
          },
          tags: ["leader", "moral"]
        },
        {
          id: "lean_on_raiders",
          text: "Signal the raider scouts and seize control (Warlord path).",
          goTo: "neutral_act1_hub_apartment",
          effects: {
            personaTilt: { warlord: +1 },
            stats: { morality: -1 }
          },
          tags: ["combat", "social"]
        },
        {
          id: "raise_dispatch",
          text: "Patch into convoy frequencies for leverage (Fixer path).",
          goTo: "neutral_act1_hub_apartment",
          effects: {
            personaTilt: { fixer: +1 },
            stats: { stress: +1 }
          },
          tags: ["social", "leader"]
        },
        {
          id: "hunt_corridors",
          text: "Prowl the dark to clear threats yourself (Killer path).",
          goTo: "neutral_act1_hub_apartment",
          effects: {
            personaTilt: { killer: +1 },
            stats: { morality: -1, stress: -1 }
          },
          tags: ["stealth", "combat"]
        },
        {
          id: "stage_reassurance",
          text: "Stage a performance that binds everyone to you (Sociopath path).",
          goTo: "neutral_act1_hub_apartment",
          effects: {
            personaTilt: { sociopath: +1 },
            stats: { charisma: +1, morality: -1 }
          },
          tags: ["social"]
        }
      ]
    },

    neutral_act1_hub_apartment: {
      id: "neutral_act1_hub_apartment",
      text: "Rain needles cracked windows as neighbors crowd the landing. Generators hiccup. Radios hiss. The first act of survival unfolds on this floor.",
      tags: ["leader"],
      choices: [
        {
          id: "coordinate_barricade",
          text: "Coordinate the barricade rotation (Protector).",
          goTo: "good_act1_setpiece_barricade",
          effects: {
            stats: { stress: +2 },
            relationships: { Volunteers: +4 },
            time: +1,
            pushEvent: "You assign shifts with clipped clarity."
          },
          tags: ["leader", "moral"]
        },
        {
          id: "intimidate_raiders",
          text: "Summon raider scouts to enforce curfew (Warlord).",
          goTo: "ant_act1_setpiece_checkpoint",
          effects: {
            stats: { morality: -2, stress: -1 },
            relationships: { Raiders: +6, Volunteers: -3 },
            time: +1
          },
          tags: ["combat", "social"]
        },
        {
          id: "call_convoy",
          text: "Call the convoy dispatcher for a supply bargain (Fixer).",
          goTo: "man_act1_setpiece_radio",
          effects: {
            stats: { stress: +1, morality: +1 },
            relationships: { Convoy: +4 },
            time: +1
          },
          tags: ["social"]
        },
        {
          id: "cleanse_corridors",
          text: "Sweep the corridors alone (Killer).",
          goTo: "killer_act1_setpiece_cull",
          effects: {
            stats: { morality: -2, stress: -2 },
            time: +1
          },
          tags: ["stealth", "combat"]
        },
        {
          id: "spin_story",
          text: "Spin a reassuring lie to keep everyone compliant (Sociopath).",
          goTo: "socio_act1_setpiece_stage",
          effects: {
            stats: { morality: -1, charisma: +1 },
            relationships: { Volunteers: +2 },
            time: +1
          },
          tags: ["social", "leader"]
        },
        {
          id: "salvage_garage",
          text: "Slip to the garage for extra supplies.",
          goTo: "neutral_act1_side_garage",
          effects: {
            stats: { stress: -1 },
            time: +1
          },
          tags: ["survival", "stealth"]
        }
      ]
    },

    neutral_act1_side_garage: {
      id: "neutral_act1_side_garage",
      text: "The garage reeks of burnt rubber. Half-toppled shelves hide fuel cans and an old quad drone.",
      tags: ["survival"],
      choices: [
        {
          id: "siphon_fuel",
          text: "Siphon fuel into canisters (−1 STA).",
          goTo: "neutral_act1_hub_apartment",
          cost: { stamina: 1 },
          effects: {
            inventoryAdd: ["fuel_can"],
            stats: { stress: +1 },
            pushEvent: "You lug a sloshing can upstairs."
          },
          tags: ["survival"]
        },
        {
          id: "repair_drone_med",
          text: "Repair the drone with your MedKit tools.",
          goTo: "neutral_act1_hub_apartment",
          req: { items: ["medkit"] },
          effects: {
            inventoryAdd: ["scout_drone"],
            stats: { willpower: +1 },
            pushEvent: "The drone's rotors whine back to life."
          },
          tags: ["stealth", "leader"]
        },
        {
          id: "pry_for_parts",
          text: "Pry spare parts loose with your crowbar.",
          goTo: "neutral_act1_hub_apartment",
          req: { items: ["crowbar"] },
          effects: {
            inventoryAdd: ["scout_drone"],
            stats: { strength: -1, stress: +1 },
            pushEvent: "Metal screams, but the drone sputters awake."
          },
          tags: ["survival", "stealth"]
        },
        {
          id: "return_empty",
          text: "Return empty-handed but wiser.",
          goTo: "neutral_act1_hub_apartment",
          effects: {
            stats: { stress: -2 }
          },
          tags: ["survival"]
        }
      ]
    },
    good_act1_setpiece_barricade: {
      id: "good_act1_setpiece_barricade",
      text: "Volunteers strain under splintered doors while infected slam below. Alex, if alive, grips a nailgun, waiting for your call.",
      tags: ["leader", "combat"],
      choices: [
        {
          id: "rotate_shifts",
          text: "Rotate shifts; keep morale high (−2 STA).",
          goTo: "neutral_act1_bridge_rooftop",
          cost: { stamina: 2 },
          effects: {
            flagsSet: ["held_line", "proof_protector_rescue"],
            stats: { stress: +3, morality: +2 },
            relationships: { Volunteers: +8, Alex: +4 },
            pushEvent: "The barricade holds because you make it hold."
          },
          tags: ["leader", "moral"]
        },
        {
          id: "evacuate_children",
          text: "Evacuate the children up the fire escape.",
          goTo: "neutral_act1_bridge_rooftop",
          effects: {
            stats: { morality: +3, stress: +2 },
            inventoryRemove: ["scout_drone"],
            flagsSet: ["proof_protector_rescue"],
            relationships: { Volunteers: +6 },
            pushEvent: "Tiny hands cling to your coat as you guide them out." }
        },
        {
          id: "hold_with_fire",
          text: "Light the stairwell with a flare and force the infected back.",
          goTo: "neutral_act1_bridge_rooftop",
          cost: { items: ["flare"] },
          req: { items: ["flare"] },
          effects: {
            stats: { stress: +1, stamina: -1 },
            flagsSet: ["proof_protector_rescue"],
            pushEvent: "Flare light paints the hall in molten red." }
        }
      ]
    },

    ant_act1_setpiece_checkpoint: {
      id: "ant_act1_setpiece_checkpoint",
      text: "Two raider scouts lounge over crates of ration bricks. They eye you like new stock walking in.",
      tags: ["combat", "social"],
      choices: [
        {
          id: "tax_residents",
          text: "Tax every resident a ration to buy the raiders' muscle.",
          goTo: "neutral_act1_bridge_rooftop",
          effects: {
            stats: { morality: -3, stress: -1 },
            flagsSet: ["proof_warlord_fear"],
            relationships: { Raiders: +6, Volunteers: -6 },
            pushEvent: "You trade fear for a night of order." },
          tags: ["combat", "moral"]
        },
        {
          id: "threaten_scout",
          text: "Threaten their scout until they guard your stairwell for free.",
          goTo: "neutral_act1_bridge_rooftop",
          effects: {
            stats: { morality: -2, stress: -2 },
            flagsSet: ["proof_warlord_fear"],
            relationships: { Raiders: +4 },
            pushEvent: "You leave them bleeding respect on the tiles." }
        },
        {
          id: "sabotage_supply",
          text: "Sabotage one crate and blame a rival faction.",
          goTo: "neutral_act1_bridge_rooftop",
          effects: {
            stats: { morality: -4, stress: +1 },
            flagsSet: ["proof_warlord_fear", "convoy_betrayed"],
            relationships: { Convoy: -4 },
            pushEvent: "You seed paranoia in their ranks." }
        }
      ]
    },

    man_act1_setpiece_radio: {
      id: "man_act1_setpiece_radio",
      text: "Rain soaks the rooftop while the convoy dispatcher demands leverage for any pickup.",
      tags: ["social", "leader"],
      choices: [
        {
          id: "offer_fuel",
          text: "Offer fuel for guaranteed evac slots (lose Fuel Can).",
          goTo: "neutral_act1_bridge_rooftop",
          req: { items: ["fuel_can"] },
          cost: { items: ["fuel_can"] },
          effects: {
            flagsSet: ["proof_fixer_deal", "shared_rations"],
            stats: { morality: +1 },
            relationships: { Convoy: +8 },
            pushEvent: "The dispatcher softens at the promise of fuel." }
        },
        {
          id: "record_leverage",
          text: "Record their desperation to blackmail later.",
          goTo: "neutral_act1_bridge_rooftop",
          effects: {
            inventoryAdd: ["blackmail_clip"],
            stats: { morality: -1, stress: +1 },
            flagsSet: ["proof_fixer_deal"],
            pushEvent: "Static hides the fear in their voice you just captured." }
        },
        {
          id: "trade_medical",
          text: "Trade your medic expertise for supply priority.",
          goTo: "neutral_act1_bridge_rooftop",
          req: { flags: ["alex_trust"] },
          effects: {
            stats: { morality: +2, stress: +2 },
            relationships: { Convoy: +6, Volunteers: +2 },
            flagsSet: ["proof_fixer_deal"],
            pushEvent: "You promise triage in exchange for fuel routes." }
        }
      ]
    },

    killer_act1_setpiece_cull: {
      id: "killer_act1_setpiece_cull",
      text: "The corridor is a slit of shadows. Four shamblers gnash over a fallen volunteer's pack.",
      tags: ["combat", "stealth"],
      choices: [
        {
          id: "silent_cull",
          text: "Cull each quietly with your blade.",
          goTo: "neutral_act1_bridge_rooftop",
          effects: {
            stats: { morality: -2, stress: -2 },
            flagsSet: ["proof_killer_cull"],
            relationships: { Raiders: +2 },
            pushEvent: "You move like the siren's knife." }
        },
        {
          id: "bait_to_stair",
          text: "Bait them to the stair and drop them four floors.",
          goTo: "neutral_act1_bridge_rooftop",
          effects: {
            stats: { morality: -1, stress: -1 },
            flagsSet: ["proof_killer_cull"],
            pushEvent: "Bone crunch echoes up the shaft." }
        },
        {
          id: "use_neighbor",
          text: "Use a panicked neighbor as bait to guarantee the kills.",
          goTo: "neutral_act1_bridge_rooftop",
          effects: {
            stats: { morality: -4, stress: -3 },
            flagsSet: ["proof_killer_cull"],
            relationships: { Volunteers: -8 },
            pushEvent: "Fear cements your legend." }
        }
      ]
    },

    socio_act1_setpiece_stage: {
      id: "socio_act1_setpiece_stage",
      text: "You gather survivors in the laundry room, stringing fairy lights from extension cords, spinning hope like silk.",
      tags: ["social", "leader"],
      choices: [
        {
          id: "promise_safety",
          text: "Promise safety if they obey every order.",
          goTo: "neutral_act1_bridge_rooftop",
          effects: {
            stats: { morality: -1, stress: -1 },
            flagsSet: ["proof_socio_stage"],
            relationships: { Volunteers: +5 },
            pushEvent: "Their trust tastes like sugar." }
        },
        {
          id: "weaponize_fear",
          text: "Describe the horrors outside until they cling to you.",
          goTo: "neutral_act1_bridge_rooftop",
          effects: {
            stats: { morality: -2, stress: -2 },
            flagsSet: ["proof_socio_stage"],
            relationships: { Volunteers: +3, Raiders: +2 },
            pushEvent: "Tears glisten, and you own every one." }
        },
        {
          id: "collect_secrets",
          text: "Collect confessions to use later.",
          goTo: "neutral_act1_bridge_rooftop",
          effects: {
            stats: { morality: -2, stress: 0 },
            flagsSet: ["proof_socio_stage"],
            inventoryAdd: ["trust_ledgers"],
            pushEvent: "Their secrets fill your ledger." }
        }
      ]
    },

    neutral_act1_bridge_rooftop: {
      id: "neutral_act1_bridge_rooftop",
      text: "From the rooftop you count stadium flares to the west and convoy headlights snaking the interstate. The first act bleeds into the second.",
      tags: ["leader"],
      choices: [
        {
          id: "descend_to_streets",
          text: "Descend to coordinate citywide defense (Act II).",
          goTo: "neutral_act2_hub_main",
          effects: {
            time: +1,
            stats: { stress: +1 }
          }
        },
        {
          id: "survey_longer",
          text: "Survey the skyline for opportunities.",
          goTo: "neutral_act1_side_rooftop_scan",
          effects: {
            stats: { willpower: +1 }
          },
          tags: ["leader", "survival"]
        }
      ]
    },

    neutral_act1_side_rooftop_scan: {
      id: "neutral_act1_side_rooftop_scan",
      text: "Lightning skates across the river. You spot convoy trucks pinned near the stadium ramp and raiders setting road flares.",
      tags: ["survival"],
      choices: [
        {
          id: "signal_convoy",
          text: "Signal the convoy with mirror flashes (needs Scout Drone).",
          goTo: "neutral_act2_hub_main",
          req: { items: ["scout_drone"] },
          effects: {
            flagsSet: ["rescued_convoy"],
            relationships: { Convoy: +5 },
            stats: { morality: +1 }
          }
        },
        {
          id: "mark_raiders",
          text: "Mark raider positions for future leverage.",
          goTo: "neutral_act2_hub_main",
          effects: {
            inventoryAdd: ["raider_map"],
            stats: { stress: -1 }
          }
        }
      ]
    },
    neutral_act2_hub_main: {
      id: "neutral_act2_hub_main",
      text: "Sirens echo through shuttered streets. Factions broadcast desperate requests while raiders tighten their nets.",
      tags: ["leader"],
      choices: [
        {
          id: "reinforce_stadium",
          text: "Reinforce the stadium barricades (Protector).",
          goTo: "good_act2_setpiece_shield",
          req: { stats: { stamina: { gte: 8 } } },
          effects: {
            stats: { stress: +2, stamina: -1 },
            relationships: { Stadium: +4 },
            time: +1
          },
          tags: ["leader", "combat"]
        },
        {
          id: "collect_tithe",
          text: "Collect a tithe from traders at the interstate (Warlord).",
          goTo: "ant_act2_setpiece_tithe",
          effects: {
            stats: { morality: -3, stress: -1 },
            relationships: { Raiders: +6, Convoy: -4 },
            time: +1
          },
          tags: ["combat", "social"]
        },
        {
          id: "broker_passage",
          text: "Broker safe passage for the convoy (Fixer).",
          goTo: "man_act2_setpiece_network",
          effects: {
            stats: { stress: +1 },
            relationships: { Convoy: +5, Stadium: +2 },
            time: +1
          },
          tags: ["social", "leader"]
        },
        {
          id: "stalk_blockade",
          text: "Stalk the blockade and remove the loudest threats (Killer).",
          goTo: "killer_act2_setpiece_harvest",
          effects: {
            stats: { morality: -2, stress: -2 },
            time: +1
          },
          tags: ["stealth", "combat"]
        },
        {
          id: "host_confession",
          text: "Host a confession circle to bind loyalty (Sociopath).",
          goTo: "socio_act2_setpiece_confession",
          effects: {
            stats: { morality: -1 },
            relationships: { Volunteers: +3, FreeCrews: +2 },
            time: +1
          },
          tags: ["social"]
        },
        {
          id: "visit_aid",
          text: "Visit the aid station for supplies and intel.",
          goTo: "neutral_act2_side_aid",
          effects: {
            stats: { stress: -2 }
          },
          tags: ["survival"]
        }
      ]
    },

    neutral_act2_side_aid: {
      id: "neutral_act2_side_aid",
      text: "An improvised clinic hums under generator light. Shelves groan with dwindling antibiotics guarded by exhausted medics.",
      tags: ["survival"],
      choices: [
        {
          id: "steal_antibiotics",
          text: "Pocket antibiotics while no one watches.",
          goTo: "neutral_act2_hub_main",
          effects: {
            stats: { morality: -2, stress: -1 },
            inventoryAdd: ["antibiotics"],
            relationships: { Stadium: -4 }
          }
        },
        {
          id: "tend_wounded",
          text: "Tend the wounded with your medic skills (needs MedKit).",
          goTo: "neutral_act2_hub_main",
          req: { items: ["medkit"] },
          cost: { items: ["medkit"] },
          effects: {
            stats: { morality: +3, stress: +1 },
            relationships: { Stadium: +6, Volunteers: +2 },
            pushEvent: "You stitch hope back into tired faces." }
        },
        {
          id: "share_drone",
          text: "Share drone intel with doctors (needs Scout Drone).",
          goTo: "neutral_act2_hub_main",
          req: { items: ["scout_drone"] },
          effects: {
            relationships: { Convoy: +2, Stadium: +2 },
            stats: { stress: -1 },
            pushEvent: "Routed medevac corridors appear on the map." }
        }
      ]
    },

    good_act2_setpiece_shield: {
      id: "good_act2_setpiece_shield",
      text: "The stadium gate buckles under a wave of infected. Families huddle in bleachers clutching glowsticks as you arrive.",
      tags: ["leader", "combat"],
      choices: [
        {
          id: "anchor_gate",
          text: "Anchor the gate with cargo haulers (requires Crowbar).",
          goTo: "neutral_act2_bridge_curfew",
          req: { items: ["crowbar"] },
          effects: {
            flagsSet: ["proof_protector_shield"],
            stats: { stamina: -1, stress: +2 },
            relationships: { Stadium: +6, Volunteers: +3 }
          }
        },
        {
          id: "flare_signal",
          text: "Signal rooftop archers with a flare (needs Flare).",
          goTo: "neutral_act2_bridge_curfew",
          req: { items: ["flare"] },
          cost: { items: ["flare"] },
          effects: {
            flagsSet: ["proof_protector_shield"],
            stats: { stress: +1 },
            relationships: { Stadium: +4 }
          }
        },
        {
          id: "hand_off_med",
          text: "Hand off antibiotics to keep casualties low (needs Antibiotics).",
          goTo: "neutral_act2_bridge_curfew",
          req: { items: ["antibiotics"] },
          cost: { items: ["antibiotics"] },
          effects: {
            flagsSet: ["proof_protector_shield"],
            stats: { morality: +2, stress: +2 },
            relationships: { Stadium: +8 }
          }
        }
      ]
    },

    ant_act2_setpiece_tithe: {
      id: "ant_act2_setpiece_tithe",
      text: "Convoy rigs idle at the interstate toll plaza. Merchants grumble as raider muscle watches you approach.",
      tags: ["combat", "social"],
      choices: [
        {
          id: "demand_half",
          text: "Demand half their haul for \"protection\".",
          goTo: "neutral_act2_bridge_curfew",
          effects: {
            stats: { morality: -4, stress: -2 },
            flagsSet: ["proof_warlord_tithe"],
            inventoryAdd: ["ration_crate"],
            relationships: { Raiders: +8, Convoy: -8 }
          }
        },
        {
          id: "burn_wagon",
          text: "Burn one wagon to prove you're serious.",
          goTo: "neutral_act2_bridge_curfew",
          effects: {
            stats: { morality: -5, stress: -3 },
            flagsSet: ["proof_warlord_tithe", "refinery_burned"],
            relationships: { Raiders: +6, Convoy: -10 },
            pushEvent: "Flames lick the night and your legend grows." }
        },
        {
          id: "cut_deal_raiders",
          text: "Share spoils with raider lieutenants to cement loyalty.",
          goTo: "neutral_act2_bridge_curfew",
          effects: {
            stats: { morality: -3 },
            flagsSet: ["proof_warlord_tithe"],
            relationships: { Raiders: +10, FreeCrews: -4 }
          }
        }
      ]
    },

    man_act2_setpiece_network: {
      id: "man_act2_setpiece_network",
      text: "You split your time between a convoy safehouse and a stadium command post, weaving promises into radio static.",
      tags: ["social", "leader"],
      choices: [
        {
          id: "trade_manifest",
          text: "Trade the raider map for convoy escort priority (requires Raider Map).",
          goTo: "neutral_act2_bridge_curfew",
          req: { items: ["raider_map"] },
          cost: { items: ["raider_map"] },
          effects: {
            flagsSet: ["proof_fixer_network"],
            relationships: { Convoy: +8, Raiders: -4 }
          }
        },
        {
          id: "blackmail_dispatch",
          text: "Use the blackmail clip to force a supply run (needs Blackmail Clip).",
          goTo: "neutral_act2_bridge_curfew",
          req: { items: ["blackmail_clip"] },
          cost: { items: ["blackmail_clip"] },
          effects: {
            flagsSet: ["proof_fixer_network"],
            stats: { morality: -2, stress: +2 },
            relationships: { Convoy: +10, Volunteers: -2 }
          }
        },
        {
          id: "mediate_stadium",
          text: "Mediate stadium and convoy tensions for mutual aid.",
          goTo: "neutral_act2_bridge_curfew",
          effects: {
            flagsSet: ["proof_fixer_network"],
            stats: { stress: +1 },
            relationships: { Stadium: +4, Convoy: +4 }
          }
        }
      ]
    },

    killer_act2_setpiece_harvest: {
      id: "killer_act2_setpiece_harvest",
      text: "You stalk the shadow of the refinery wall where raider deserters and infected strays gather in hungry packs.",
      tags: ["combat", "stealth"],
      choices: [
        {
          id: "thin_raiders",
          text: "Thin deserters to scare the rest back into line.",
          goTo: "neutral_act2_bridge_curfew",
          effects: {
            flagsSet: ["proof_killer_extraction"],
            stats: { morality: -3, stress: -3 },
            relationships: { Raiders: +4 }
          }
        },
        {
          id: "harvest_cures",
          text: "Harvest infected for reagent samples (needs MedKit).",
          goTo: "neutral_act2_bridge_curfew",
          req: { items: ["medkit"] },
          effects: {
            flagsSet: ["proof_killer_extraction"],
            stats: { morality: -2, stress: -2 },
            inventoryAdd: ["viral_reagent"],
            pushEvent: "You bottle the bloom's secrets." }
        },
        {
          id: "stage_body",
          text: "Stage a body to frame the Free Crews and spark fear.",
          goTo: "neutral_act2_bridge_curfew",
          effects: {
            flagsSet: ["proof_killer_extraction"],
            stats: { morality: -4, stress: -1 },
            relationships: { FreeCrews: -6, Raiders: +6 }
          }
        }
      ]
    },

    socio_act2_setpiece_confession: {
      id: "socio_act2_setpiece_confession",
      text: "You turn a shuttered lounge into a confession booth. Survivors queue to spill secrets in exchange for ration cards.",
      tags: ["social"],
      choices: [
        {
          id: "promise_absolution",
          text: "Promise absolution only if they betray friends.",
          goTo: "neutral_act2_bridge_curfew",
          effects: {
            flagsSet: ["proof_socio_confession"],
            stats: { morality: -3 },
            relationships: { Volunteers: +4, FreeCrews: -2 },
            pushEvent: "Confessions pile higher than rations." }
        },
        {
          id: "sell_reassurance",
          text: "Sell reassurance sessions for supplies.",
          goTo: "neutral_act2_bridge_curfew",
          effects: {
            flagsSet: ["proof_socio_confession"],
            stats: { morality: -2, stress: -1 },
            inventoryAdd: ["luxury_cache"],
            relationships: { Volunteers: +1 }
          }
        },
        {
          id: "broadcast_fear",
          text: "Broadcast curated confessions to keep everyone compliant.",
          goTo: "neutral_act2_bridge_curfew",
          effects: {
            flagsSet: ["proof_socio_confession"],
            stats: { morality: -2, stress: -2 },
            relationships: { Volunteers: -2, Raiders: +3 }
          }
        }
      ]
    },

    neutral_act2_bridge_curfew: {
      id: "neutral_act2_bridge_curfew",
      text: "Curfew klaxons throb as the city dims. Floodlights sweep rooftops and interstate ramps.",
      tags: ["leader"],
      choices: [
        {
          id: "advance_to_dawn",
          text: "Advance to dawn operations (Act III).",
          goTo: "neutral_act3_hub_main",
          effects: {
            time: +1,
            stats: { stress: +1 }
          }
        },
        {
          id: "inspect_refinery",
          text: "Inspect the refinery perimeter for vulnerabilities.",
          goTo: "neutral_act2_side_refinery",
          effects: {
            stats: { agility: +1 }
          }
        }
      ]
    },

    neutral_act2_side_refinery: {
      id: "neutral_act2_side_refinery",
      text: "Steam whistles through cracked pipes. You spot sabotage charges planted by desperate Free Crews.",
      tags: ["survival", "stealth"],
      choices: [
        {
          id: "disarm_charges",
          text: "Disarm the charges and secure the fuel.",
          goTo: "neutral_act3_hub_main",
          effects: {
            stats: { morality: +1, stress: +2 },
            relationships: { Stadium: +2 },
            flagsUnset: ["refinery_burned"],
            pushEvent: "You keep the refinery alive for another day." }
        },
        {
          id: "let_it_burn",
          text: "Let the charges stand for leverage later.",
          goTo: "neutral_act3_hub_main",
          effects: {
            stats: { morality: -2 },
            flagsSet: ["refinery_burned"],
            relationships: { FreeCrews: +3, Convoy: -2 }
          }
        }
      ]
    },
    neutral_act3_hub_main: {
      id: "neutral_act3_hub_main",
      text: "Dawn stains the skyline bruise-purple. Convoy horns and stadium sirens intertwine as factions await your third-act move.",
      tags: ["leader"],
      choices: [
        {
          id: "escort_convoy",
          text: "Escort the final convoy wave (Protector).",
          goTo: "good_act3_setpiece_convoy",
          effects: {
            stats: { stress: +2 },
            relationships: { Convoy: +4, Volunteers: +3 },
            time: +1
          },
          tags: ["leader", "survival"]
        },
        {
          id: "proclaim_rule",
          text: "Proclaim warlord rule over the skybridge (Warlord).",
          goTo: "ant_act3_setpiece_rule",
          effects: {
            stats: { morality: -4 },
            relationships: { Raiders: +6, Volunteers: -4 },
            time: +1
          },
          tags: ["combat", "leader"]
        },
        {
          id: "lockdown_network",
          text: "Lock down comms to broker final deals (Fixer).",
          goTo: "man_act3_setpiece_lockdown",
          effects: {
            stats: { stress: +1 },
            relationships: { Convoy: +4, Stadium: +3 },
            time: +1
          },
          tags: ["social"]
        },
        {
          id: "cull_defectors",
          text: "Cull defectors before they sabotage routes (Killer).",
          goTo: "killer_act3_setpiece_obedience",
          effects: {
            stats: { morality: -3, stress: -2 },
            time: +1
          },
          tags: ["combat", "stealth"]
        },
        {
          id: "mirror_faith",
          text: "Mirror each faction's faith back at them (Sociopath).",
          goTo: "socio_act3_setpiece_mirror",
          effects: {
            stats: { morality: -2, charisma: +1 },
            relationships: { Volunteers: +2, FreeCrews: +3 },
            time: +1
          },
          tags: ["social", "leader"]
        },
        {
          id: "scout_rooftops",
          text: "Scout the rooftops for last-minute advantages.",
          goTo: "neutral_act3_side_rooftops",
          effects: {
            stats: { agility: +1 }
          },
          tags: ["survival", "stealth"]
        }
      ]
    },

    neutral_act3_side_rooftops: {
      id: "neutral_act3_side_rooftops",
      text: "Wind kicks ash across rooftop gardens. Free Crews stash water barrels under tarps.",
      tags: ["survival"],
      choices: [
        {
          id: "secure_water",
          text: "Secure water barrels for the shelter.",
          goTo: "neutral_act3_hub_main",
          effects: {
            inventoryAdd: ["water_cache"],
            stats: { stress: -1 },
            relationships: { Volunteers: +2 }
          }
        },
        {
          id: "promise_refuge",
          text: "Promise refuge in exchange for intel.",
          goTo: "neutral_act3_hub_main",
          effects: {
            stats: { morality: +1 },
            relationships: { FreeCrews: +4 },
            inventoryAdd: ["freecrew_codes"]
          }
        }
      ]
    },

    good_act3_setpiece_convoy: {
      id: "good_act3_setpiece_convoy",
      text: "Convoy buses chug up the interstate ramp under sniper fire. Refugees crowd the bridge praying you clear a path.",
      tags: ["leader", "combat"],
      choices: [
        {
          id: "shield_with_bus",
          text: "Shield evacuees with a jackknifed bus.",
          goTo: "neutral_act3_bridge_dawn",
          effects: {
            flagsSet: ["proof_protector_convoy"],
            stats: { stamina: -1, stress: +3, morality: +2 },
            relationships: { Convoy: +6, Volunteers: +4 }
          }
        },
        {
          id: "escort_last",
          text: "Personally escort the last family across.",
          goTo: "neutral_act3_bridge_dawn",
          effects: {
            flagsSet: ["proof_protector_convoy"],
            stats: { stress: +2, morality: +3 },
            relationships: { Volunteers: +5, Alex: +3 }
          }
        },
        {
          id: "sacrifice_supplies",
          text: "Sacrifice your ration crate to feed evacuees (needs Ration Crate).",
          goTo: "neutral_act3_bridge_dawn",
          req: { items: ["ration_crate"] },
          cost: { items: ["ration_crate"] },
          effects: {
            flagsSet: ["proof_protector_convoy", "shared_rations"],
            stats: { morality: +2 },
            relationships: { Convoy: +8 }
          }
        }
      ]
    },

    ant_act3_setpiece_rule: {
      id: "ant_act3_setpiece_rule",
      text: "You stride onto the fractured skybridge, raider banners snapping overhead. Merchants and refugees line either side under armed guard.",
      tags: ["leader", "combat"],
      choices: [
        {
          id: "public_execution",
          text: "Publicly execute a defiant smuggler.",
          goTo: "neutral_act3_bridge_dawn",
          effects: {
            flagsSet: ["proof_warlord_domination"],
            stats: { morality: -6, stress: -2 },
            relationships: { Raiders: +10, Volunteers: -8 }
          }
        },
        {
          id: "brand_with_iron",
          text: "Brand thieves to mark your rule.",
          goTo: "neutral_act3_bridge_dawn",
          effects: {
            flagsSet: ["proof_warlord_domination"],
            stats: { morality: -4 },
            relationships: { Raiders: +6, Convoy: -4 }
          }
        },
        {
          id: "force_tribute",
          text: "Force tribute and promise protection to those who kneel.",
          goTo: "neutral_act3_bridge_dawn",
          effects: {
            flagsSet: ["proof_warlord_domination"],
            stats: { morality: -3 },
            relationships: { Raiders: +4, Convoy: -2, Volunteers: -3 }
          }
        }
      ]
    },

    man_act3_setpiece_lockdown: {
      id: "man_act3_setpiece_lockdown",
      text: "You route every major signal through your rooftop relay, deciding which pleas reach the wider city.",
      tags: ["social", "leader"],
      choices: [
        {
          id: "prioritize_allies",
          text: "Prioritize allies and mute rivals.",
          goTo: "neutral_act3_bridge_dawn",
          effects: {
            flagsSet: ["proof_fixer_lock"],
            stats: { stress: +1 },
            relationships: { Convoy: +4, Stadium: +4, Raiders: -4 }
          }
        },
        {
          id: "sell_access",
          text: "Sell signal access for promises of future loyalty.",
          goTo: "neutral_act3_bridge_dawn",
          effects: {
            flagsSet: ["proof_fixer_lock"],
            stats: { morality: -2 },
            inventoryAdd: ["favor_tokens"],
            relationships: { Convoy: +2, FreeCrews: +2 }
          }
        },
        {
          id: "archive_secrets",
          text: "Archive every plea for later leverage.",
          goTo: "neutral_act3_bridge_dawn",
          effects: {
            flagsSet: ["proof_fixer_lock"],
            stats: { morality: -1, stress: +2 },
            inventoryAdd: ["signal_archive"],
            pushEvent: "You hold the city's heartbeat on a drive." }
        }
      ]
    },

    killer_act3_setpiece_obedience: {
      id: "killer_act3_setpiece_obedience",
      text: "Rumors of your killings breed both terror and opportunity. A squad of raider hopefuls begs for training in your brutal efficiency.",
      tags: ["combat"],
      choices: [
        {
          id: "train_with_blood",
          text: "Train them by hunting Free Crew saboteurs.",
          goTo: "neutral_act3_bridge_dawn",
          effects: {
            flagsSet: ["proof_killer_obedience"],
            stats: { morality: -4, stress: -2 },
            relationships: { Raiders: +8, FreeCrews: -6 }
          }
        },
        {
          id: "purge_weak",
          text: "Cull the weakest to scare the rest straight.",
          goTo: "neutral_act3_bridge_dawn",
          effects: {
            flagsSet: ["proof_killer_obedience"],
            stats: { morality: -5, stress: -3 },
            relationships: { Raiders: +10, Volunteers: -6 }
          }
        },
        {
          id: "teach_silent",
          text: "Teach silent takedowns to protect your territory.",
          goTo: "neutral_act3_bridge_dawn",
          effects: {
            flagsSet: ["proof_killer_obedience"],
            stats: { morality: -3 },
            relationships: { Raiders: +6 },
            inventoryAdd: ["raider_mark"]
          }
        }
      ]
    },

    socio_act3_setpiece_mirror: {
      id: "socio_act3_setpiece_mirror",
      text: "You host a dawn summit on the rooftop garden, mirroring each faction's fears until they echo your script.",
      tags: ["social", "leader"],
      choices: [
        {
          id: "promise_miracles",
          text: "Promise miracles if everyone obeys your timetable.",
          goTo: "neutral_act3_bridge_dawn",
          effects: {
            flagsSet: ["proof_socio_mirror"],
            stats: { morality: -2 },
            relationships: { Volunteers: +4, Convoy: +2 }
          }
        },
        {
          id: "stage_betrayal",
          text: "Stage a fake betrayal to watch loyalties shift.",
          goTo: "neutral_act3_bridge_dawn",
          effects: {
            flagsSet: ["proof_socio_mirror"],
            stats: { morality: -3, stress: -1 },
            relationships: { Volunteers: -2, FreeCrews: +4, Raiders: +2 }
          }
        },
        {
          id: "collect_tithes",
          text: "Collect emotional tithes and store them in your ledger (needs Trust Ledgers).",
          goTo: "neutral_act3_bridge_dawn",
          req: { items: ["trust_ledgers"] },
          effects: {
            flagsSet: ["proof_socio_mirror"],
            stats: { morality: -1 },
            inventoryAdd: ["devotion_ledger"],
            relationships: { Volunteers: +3 }
          }
        }
      ]
    },

    neutral_act3_bridge_dawn: {
      id: "neutral_act3_bridge_dawn",
      text: "The sun climbs over a city scarred by your decisions. Act IV looms with converging pressures.",
      tags: ["leader"],
      choices: [
        {
          id: "prepare_act4",
          text: "Prepare the command mezzanine (Act IV).",
          goTo: "neutral_act4_hub_main",
          effects: {
            time: +1,
            stats: { stress: +2 }
          }
        },
        {
          id: "tend_barricade",
          text: "Tend to the barricade and calm survivors.",
          goTo: "neutral_act3_side_consolation",
          effects: {
            stats: { stress: -2, morality: +1 }
          }
        }
      ]
    },

    neutral_act3_side_consolation: {
      id: "neutral_act3_side_consolation",
      text: "You spend an hour patching wounds and retelling the victories that kept people alive.",
      tags: ["moral", "social"],
      choices: [
        {
          id: "back_to_mezz",
          text: "Return to command.",
          goTo: "neutral_act4_hub_main",
          effects: {
            relationships: { Volunteers: +3 },
            stats: { stress: -1 }
          }
        },
        {
          id: "leave_guard",
          text: "Leave a trusted guard with new instructions.",
          goTo: "neutral_act4_hub_main",
          effects: {
            relationships: { Volunteers: +2, Alex: +1 },
            stats: { willpower: +1 }
          }
        }
      ]
    },
    neutral_act4_hub_main: {
      id: "neutral_act4_hub_main",
      text: "Rain lashes the stadium mezzanine you now use as command. Allies compare scars while horizon lightning outlines the siege.",
      tags: ["leader"],
      choices: [
        {
          id: "stabilize_morale",
          text: "Stabilize morale with food and stories (Protector).",
          goTo: "good_act4_setpiece_mezzanine",
          effects: {
            stats: { stress: -2, morality: +1 },
            relationships: { Volunteers: +4 },
            time: +1
          },
          tags: ["moral", "leader"]
        },
        {
          id: "host_tribunal",
          text: "Host a tribunal to punish dissent (Warlord).",
          goTo: "ant_act4_setpiece_tribunal",
          effects: {
            stats: { morality: -4 },
            relationships: { Raiders: +4, Volunteers: -4 },
            time: +1
          },
          tags: ["combat", "leader"]
        },
        {
          id: "balance_factions",
          text: "Balance faction demands with promises (Fixer).",
          goTo: "man_act4_setpiece_balance",
          effects: {
            stats: { stress: +1 },
            relationships: { Convoy: +3, Stadium: +3, Raiders: -2 },
            time: +1
          },
          tags: ["social"]
        },
        {
          id: "enforce_obedience",
          text: "Enforce obedience with midnight patrols (Killer).",
          goTo: "killer_act4_setpiece_midnight",
          effects: {
            stats: { morality: -3, stress: -2 },
            time: +1
          },
          tags: ["combat", "stealth"]
        },
        {
          id: "stage_pageant",
          text: "Stage a loyalty pageant to cement adoration (Sociopath).",
          goTo: "socio_act4_setpiece_pageant",
          effects: {
            stats: { morality: -2, charisma: +1 },
            relationships: { Volunteers: +3, FreeCrews: +2 },
            time: +1
          },
          tags: ["social", "leader"]
        },
        {
          id: "jam_raiders",
          text: "Jam raider comms from the signal booth.",
          goTo: "neutral_act4_side_signal",
          effects: {
            stats: { willpower: +1 }
          },
          tags: ["stealth"]
        }
      ]
    },

    neutral_act4_side_signal: {
      id: "neutral_act4_side_signal",
      text: "Static crackles as you overload the raider comm tower. Panic spreads through their ranks.",
      tags: ["stealth", "leader"],
      choices: [
        {
          id: "return_command",
          text: "Return to command before they triangulate you.",
          goTo: "neutral_act4_hub_main",
          effects: {
            relationships: { Raiders: -4 },
            stats: { stress: -1 }
          }
        },
        {
          id: "spoof_orders",
          text: "Spoof orders to send raiders into an ambush.",
          goTo: "neutral_act4_hub_main",
          effects: {
            stats: { morality: -1, stress: -2 },
            relationships: { Raiders: -6, FreeCrews: +3 },
            pushEvent: "Their patrols crash into each other in confusion." }
        }
      ]
    },

    good_act4_setpiece_mezzanine: {
      id: "good_act4_setpiece_mezzanine",
      text: "Volunteers warm their hands over barrel fires while evac manifests sprawl across tables.",
      tags: ["leader", "moral"],
      choices: [
        {
          id: "share_last_water",
          text: "Share the last water cache to keep morale stable (needs Water Cache).",
          goTo: "neutral_act4_bridge_finale",
          req: { items: ["water_cache"] },
          cost: { items: ["water_cache"] },
          effects: {
            stats: { morality: +2, stress: -2 },
            relationships: { Volunteers: +6 },
            pushEvent: "Hope tastes like clean water." }
        },
        {
          id: "walk_the_line",
          text: "Walk the catwalk and praise every defender by name.",
          goTo: "neutral_act4_bridge_finale",
          effects: {
            stats: { stress: -1 },
            relationships: { Volunteers: +5, Alex: +2 }
          }
        },
        {
          id: "prep_med_bay",
          text: "Prep the med bay for the final night.",
          goTo: "neutral_act4_bridge_finale",
          effects: {
            stats: { stress: +1, morality: +1 },
            relationships: { Stadium: +3 }
          }
        }
      ]
    },

    ant_act4_setpiece_tribunal: {
      id: "ant_act4_setpiece_tribunal",
      text: "Floodlights glare on chained prisoners accused of hoarding and sedition.",
      tags: ["combat", "leader"],
      choices: [
        {
          id: "sentence_public",
          text: "Sentence them publicly to instill fear.",
          goTo: "neutral_act4_bridge_finale",
          effects: {
            stats: { morality: -4 },
            relationships: { Raiders: +6, Volunteers: -6 }
          }
        },
        {
          id: "offer_dread",
          text: "Offer clemency if they become dread envoys.",
          goTo: "neutral_act4_bridge_finale",
          effects: {
            stats: { morality: -3 },
            relationships: { Raiders: +4, FreeCrews: -4 },
            inventoryAdd: ["envoy_marks"]
          }
        },
        {
          id: "sacrifice_example",
          text: "Sacrifice one and release the rest under strict tribute.",
          goTo: "neutral_act4_bridge_finale",
          effects: {
            stats: { morality: -2 },
            relationships: { Raiders: +2, Volunteers: -3, Convoy: -2 }
          }
        }
      ]
    },

    man_act4_setpiece_balance: {
      id: "man_act4_setpiece_balance",
      text: "You juggle convoy demands, stadium triage, and raider threats across three cracked monitors.",
      tags: ["social", "leader"],
      choices: [
        {
          id: "promise_rotation",
          text: "Promise rotation schedules that satisfy all sides.",
          goTo: "neutral_act4_bridge_finale",
          effects: {
            stats: { stress: +2 },
            relationships: { Convoy: +3, Stadium: +3, Raiders: -3 }
          }
        },
        {
          id: "leverage_tokens",
          text: "Leverage favor tokens for a united front (needs Favor Tokens).",
          goTo: "neutral_act4_bridge_finale",
          req: { items: ["favor_tokens"] },
          cost: { items: ["favor_tokens"] },
          effects: {
            stats: { stress: +1 },
            relationships: { Convoy: +4, Stadium: +4 },
            pushEvent: "IOUs become binding oaths." }
        },
        {
          id: "silence_dissent",
          text: "Silence dissenting channels and archive proof (needs Signal Archive).",
          goTo: "neutral_act4_bridge_finale",
          req: { items: ["signal_archive"] },
          effects: {
            stats: { morality: -1, stress: -1 },
            relationships: { Convoy: +2, Raiders: -2 },
            inventoryAdd: ["sealed_orders"]
          }
        }
      ]
    },

    killer_act4_setpiece_midnight: {
      id: "killer_act4_setpiece_midnight",
      text: "Midnight patrols await your orders. The city knows the killer walks tonight.",
      tags: ["combat", "stealth"],
      choices: [
        {
          id: "mark_targets",
          text: "Mark targets that threaten your command (needs Raider Mark).",
          goTo: "neutral_act4_bridge_finale",
          req: { items: ["raider_mark"] },
          effects: {
            stats: { morality: -3, stress: -1 },
            relationships: { Raiders: +5 },
            pushEvent: "Your sigil means survival or death." }
        },
        {
          id: "patrol_solo",
          text: "Patrol alone to remind everyone who's in charge.",
          goTo: "neutral_act4_bridge_finale",
          effects: {
            stats: { morality: -2, stress: -2 },
            relationships: { Volunteers: -2, Raiders: +4 }
          }
        },
        {
          id: "harvest_reagent",
          text: "Harvest more reagent for leverage (needs Viral Reagent).",
          goTo: "neutral_act4_bridge_finale",
          req: { items: ["viral_reagent"] },
          effects: {
            stats: { morality: -2 },
            inventoryAdd: ["nightshade_toxin"],
            relationships: { Raiders: +3 }
          }
        }
      ]
    },

    socio_act4_setpiece_pageant: {
      id: "socio_act4_setpiece_pageant",
      text: "You turn the mezzanine into a stage. Floodlights halo you as survivors chant your name.",
      tags: ["social", "leader"],
      choices: [
        {
          id: "crown_favorites",
          text: "Crown favorites to keep rivals scrambling.",
          goTo: "neutral_act4_bridge_finale",
          effects: {
            stats: { morality: -2 },
            relationships: { Volunteers: +3, FreeCrews: +2, Raiders: +2 }
          }
        },
        {
          id: "auction_mercy",
          text: "Auction mercy to the highest bidder (needs Luxury Cache).",
          goTo: "neutral_act4_bridge_finale",
          req: { items: ["luxury_cache"] },
          cost: { items: ["luxury_cache"] },
          effects: {
            stats: { morality: -3 },
            inventoryAdd: ["gilded_masks"],
            relationships: { Volunteers: -2, FreeCrews: +4 }
          }
        },
        {
          id: "recite_devotion",
          text: "Recite the devotion ledger to bind them emotionally (needs Devotion Ledger).",
          goTo: "neutral_act4_bridge_finale",
          req: { items: ["devotion_ledger"] },
          effects: {
            stats: { morality: -1 },
            relationships: { Volunteers: +5, FreeCrews: +3 },
            pushEvent: "Tears shimmer like currency." }
        }
      ]
    },

    neutral_act4_bridge_finale: {
      id: "neutral_act4_bridge_finale",
      text: "Night sirens spool up again. Every faction lead watches you, waiting to see which future you demand at dawn.",
      tags: ["leader"],
      choices: [
        {
          id: "protector_finale",
          text: "Commit to the protector gambit (needs 3 Protector proofs).",
          goTo: "good_act5_setpiece_final_watch",
          req: { flags: ROUTE_PROOFS.good },
          tags: ["leader", "moral"]
        },
        {
          id: "warlord_finale",
          text: "Crown yourself warlord of the corridors (needs 3 Warlord proofs).",
          goTo: "ant_act5_setpiece_final_rule",
          req: { flags: ROUTE_PROOFS.ant },
          tags: ["combat", "leader"]
        },
        {
          id: "fixer_finale",
          text: "Pull every string in the network (needs 3 Fixer proofs).",
          goTo: "man_act5_setpiece_final_weave",
          req: { flags: ROUTE_PROOFS.man },
          tags: ["social"]
        },
        {
          id: "killer_finale",
          text: "Let the killer creed decide the night (needs 3 Killer proofs).",
          goTo: "killer_act5_setpiece_final_creed",
          req: { flags: ROUTE_PROOFS.killer },
          tags: ["combat", "stealth"]
        },
        {
          id: "socio_finale",
          text: "Curate the sociopath's reckoning (needs 3 Sociopath proofs).",
          goTo: "socio_act5_setpiece_final_reckoning",
          req: { flags: ROUTE_PROOFS.socio },
          tags: ["social", "leader"]
        },
        {
          id: "buy_hour",
          text: "Buy another hour by reorganizing patrols.",
          goTo: "neutral_act4_hub_main",
          effects: {
            stats: { stress: +2 }
          },
          tags: ["survival"]
        }
      ]
    },

    good_act5_setpiece_final_watch: {
      id: "good_act5_setpiece_final_watch",
      text: "Beacon towers blaze across rooftops. Civilians await your signal to sprint between havens.",
      tags: ["leader", "moral"],
      choices: [
        {
          id: "ignite_chain",
          text: "Ignite the full beacon chain and open the gates.",
          goTo: "good_act5_ending_the_long_watch",
          effects: {
            stats: { morality: +3, stress: +2 },
            relationships: { Volunteers: +6, Convoy: +4 },
            pushEvent: "Hope races across the skyline." }
        },
        {
          id: "hold_until_dawn",
          text: "Hold the line until every evacuee crosses.",
          goTo: "good_act5_ending_the_long_watch",
          effects: {
            stats: { stamina: -2, stress: +3 },
            relationships: { Volunteers: +8 },
            pushEvent: "You do not blink, even as night claws at you." }
        }
      ]
    },

    ant_act5_setpiece_final_rule: {
      id: "ant_act5_setpiece_final_rule",
      text: "Your banners hang from the stadium rafters. Raiders kneel awaiting your decree for the dawn.",
      tags: ["combat", "leader"],
      choices: [
        {
          id: "demand_tithe",
          text: "Demand dawn tithes from every shelter.",
          goTo: "ant_act5_ending_iron_reign",
          effects: {
            stats: { morality: -4, stress: -2 },
            relationships: { Raiders: +10 },
            pushEvent: "Fear cements your empire." }
        },
        {
          id: "march_through",
          text: "March through the mezzanine with armed escorts.",
          goTo: "ant_act5_ending_iron_reign",
          effects: {
            stats: { morality: -5, stress: -3 },
            relationships: { Volunteers: -8 },
            pushEvent: "Boots echo like verdicts." }
        }
      ]
    },

    man_act5_setpiece_final_weave: {
      id: "man_act5_setpiece_final_weave",
      text: "Every faction envoy fills the broadcast booth. Contracts and blood oaths clutter the console.",
      tags: ["social", "leader"],
      choices: [
        {
          id: "seal_ledgers",
          text: "Seal the ledgers and dictate the evacuation order.",
          goTo: "man_act5_ending_whispered_deals",
          effects: {
            stats: { stress: -1 },
            relationships: { Convoy: +6, Stadium: +4 },
            pushEvent: "No convoy moves without your nod." }
        },
        {
          id: "trade_destinies",
          text: "Trade future leadership posts for loyalty now.",
          goTo: "man_act5_ending_whispered_deals",
          effects: {
            stats: { morality: -2, stress: +1 },
            relationships: { Convoy: +4, Raiders: +2 },
            pushEvent: "Power slips into your open palm." }
        }
      ]
    },

    killer_act5_setpiece_final_creed: {
      id: "killer_act5_setpiece_final_creed",
      text: "You stand alone atop the stadium lights. Below, your patrols await the signal to cull anyone who defies curfew.",
      tags: ["combat", "stealth"],
      choices: [
        {
          id: "whisper_execute",
          text: "Whisper the execute order across encrypted channels.",
          goTo: "killer_act5_ending_midnight_creed",
          effects: {
            stats: { morality: -5, stress: -3 },
            relationships: { Raiders: +8, Volunteers: -6 },
            pushEvent: "The night belongs to predators." }
        },
        {
          id: "walk_bloodline",
          text: "Walk the perimeter drenched in your enemies' fear.",
          goTo: "killer_act5_ending_midnight_creed",
          effects: {
            stats: { morality: -4, stress: -2 },
            pushEvent: "The city breathes only when you allow it." }
        }
      ]
    },

    socio_act5_setpiece_final_reckoning: {
      id: "socio_act5_setpiece_final_reckoning",
      text: "You choreograph a final ritual in the broadcast hall. Every survivor watches, waiting to be told what their suffering meant.",
      tags: ["social", "leader"],
      choices: [
        {
          id: "crown_martyrs",
          text: "Crown martyrs and claim their grief as your power.",
          goTo: "socio_act5_ending_cold_reckoning",
          effects: {
            stats: { morality: -3 },
            relationships: { Volunteers: +4, FreeCrews: +4 },
            pushEvent: "Tears glisten in the light you command." }
        },
        {
          id: "sell_salvation",
          text: "Sell salvation to the desperate.",
          goTo: "socio_act5_ending_cold_reckoning",
          effects: {
            stats: { morality: -4, stress: -2 },
            inventoryAdd: ["final_donations"],
            pushEvent: "Their hope becomes your currency." }
        }
      ]
    },

    good_act5_ending_the_long_watch: {
      id: "good_act5_ending_the_long_watch",
      text: "Beacon chains knit the district into islands of light. Families whisper your name as they cross under your protection. You kept humanity intact.",
      isEnding: true,
      endingType: "good",
      tags: ["leader", "moral"]
    },

    ant_act5_ending_iron_reign: {
      id: "ant_act5_ending_iron_reign",
      text: "Checkpoint fires burn while ration lines snake beneath your banners. Fear is the tax that keeps your empire fed.",
      isEnding: true,
      endingType: "ruthless",
      tags: ["combat", "leader"]
    },

    man_act5_ending_whispered_deals: {
      id: "man_act5_ending_whispered_deals",
      text: "Convoy engines idle under your balcony as envoys trade sealed promises. No door opens without your quiet consent.",
      isEnding: true,
      endingType: "manipulator",
      tags: ["social"]
    },

    killer_act5_ending_midnight_creed: {
      id: "killer_act5_ending_midnight_creed",
      text: "Spotlights carve your silhouette into the rain. Every heartbeat in the district syncs to the fear you authored.",
      isEnding: true,
      endingType: "ruthless",
      tags: ["combat", "stealth"]
    },

    socio_act5_ending_cold_reckoning: {
      id: "socio_act5_ending_cold_reckoning",
      text: "The city kneels in a hushed theatre of your design. Grief, joy, and dread all orbit the performance you promised would save them.",
      isEnding: true,
      endingType: "secret",
      tags: ["social", "leader"]
    }
  };

  function applyInventoryAdd(state, items = []) {
    for (const item of items || []) {
      if (!item) continue;
      if (!state.inventory.includes(item)) state.inventory.push(item);
    }
  }

  function applyInventoryRemove(state, items = []) {
    for (const item of items || []) {
      const idx = state.inventory.indexOf(item);
      if (idx >= 0) state.inventory.splice(idx, 1);
    }
  }

  function applyRelationships(state, deltas = {}) {
    for (const [name, delta] of Object.entries(deltas || {})) {
      const current = state.relationships[name] || 0;
      let next = current + delta;
      if (next > 100) next = 100;
      if (next < -100) next = -100;
      state.relationships[name] = next;
    }
  }

  function applyPersona(state, tilt = {}) {
    if (!tilt) return;
    for (const [key, delta] of Object.entries(tilt)) {
      if (typeof delta !== "number") continue;
      state.persona[key] = (state.persona[key] || 0) + delta;
    }
  }

  function evaluateRequirements(state, choice) {
    const req = choice.req;
    if (!req) return { ok: true };

    if (req.items) {
      for (const item of req.items) {
        if (!state.inventory.includes(item)) {
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
      for (const [stat, limits] of Object.entries(req.stats)) {
        const value = state.stats[stat] || 0;
        if (limits.gte !== undefined && value < limits.gte) {
          return { ok: false, reason: `${stat} ≥ ${limits.gte}` };
        }
        if (limits.lte !== undefined && value > limits.lte) {
          return { ok: false, reason: `${stat} ≤ ${limits.lte}` };
        }
      }
    }

    if (req.flagsNone) {
      for (const flag of req.flagsNone) {
        if (state.flags[flag]) {
          return { ok: false, reason: `Cannot have ${flag}` };
        }
      }
    }

    return { ok: true };
  }

  function getChoiceTarget(choice) {
    if (typeof choice.goTo === "string") return choice.goTo;
    if (typeof choice.next === "string") return choice.next;
    return undefined;
  }

  function applyChoiceCost(state, choice) {
    const cost = choice.cost;
    if (!cost) return;
    if (cost.items) applyInventoryRemove(state, cost.items);
    if (cost.stamina) state.stats.stamina = Math.max(0, state.stats.stamina - cost.stamina);
    if (cost.time) state.time += cost.time;
  }

  function applyChoiceEffects(state, effects = {}) {
    if (effects.identity) {
      state.identity = Object.assign({}, state.identity, effects.identity);
    }
    if (effects.time) state.time += effects.time;
    if (effects.stats) {
      for (const [stat, delta] of Object.entries(effects.stats)) {
        state.stats[stat] = (state.stats[stat] || 0) + delta;
      }
      clampStats(state.stats);
    }
    if (effects.inventoryAdd) applyInventoryAdd(state, effects.inventoryAdd);
    if (effects.inventoryRemove) applyInventoryRemove(state, effects.inventoryRemove);
    if (effects.flagsSet) {
      for (const flag of effects.flagsSet) {
        let handled = false;
        for (const [group, members] of Object.entries(MUTEX)) {
          if (members.includes(flag)) {
            setMutex(state, group, flag);
            handled = true;
            break;
          }
        }
        if (!handled) state.flags[flag] = true;
      }
    }
    if (effects.flagsUnset) {
      for (const flag of effects.flagsUnset) {
        delete state.flags[flag];
      }
    }
    if (effects.relationships) applyRelationships(state, effects.relationships);
    if (effects.personaTilt) applyPersona(state, effects.personaTilt);
    if (effects.pushEvent) {
      state.events = state.events || [];
      state.events.unshift({ text: effects.pushEvent, type: "consequence", time: state.time });
    }
    if (effects.schedule) {
      state.scheduled = state.scheduled || [];
      for (const entry of effects.schedule) {
        if (!entry) continue;
        state.scheduled.push({ steps: entry.steps || 1, apply: entry.apply || {} });
      }
    }
  }

  function advanceSchedule(state) {
    if (!state.scheduled) return;
    const remain = [];
    for (const job of state.scheduled) {
      if (!job || !job.apply) continue;
      job.steps -= 1;
      if (job.steps <= 0) {
        applyChoiceEffects(state, job.apply);
      } else {
        remain.push(job);
      }
    }
    state.scheduled = remain;
  }

  function failForwardChoice(state) {
    return {
      id: "fail_forward",
      text: "Push through exhaustion (gain Stress, +1h).",
      effects: {
        time: +1,
        stats: { stress: +3 },
        pushEvent: "You force motion despite the stall."
      },
      goTo: state.sceneId,
      tags: ["survival"]
    };
  }

  function validateStoryDatabase(db) {
    const errors = [];
    const warnings = [];
    const ids = Object.keys(db);
    const idPattern = /^(good|ant|man|killer|socio|neutral)_act[0-5]_(hub|setpiece|side|bridge|ending)_[a-z0-9_]+$/;

    for (const id of ids) {
      const scene = db[id];
      if (!scene) continue;
      if (!idPattern.test(id) && !scene.isEnding) {
        warnings.push(`ID ${id} does not match naming convention`);
      }
      if (scene.isEnding && scene.choices && scene.choices.length) {
        errors.push(`Ending ${id} must not contain choices`);
      }
      const seenTargets = new Set();
      for (const choice of scene.choices || []) {
        if (!choice) continue;
        const target = getChoiceTarget(choice);
        const hasEffect = choice.effects && (Object.keys(choice.effects).length > 0);
        if (!target && !hasEffect) {
          errors.push(`Choice ${choice.id || "<no id>"} in ${id} has no goTo/next or effects`);
        }
        if (target) {
          seenTargets.add(target);
          if (!db[target] && !choice.allowMissingTarget) {
            errors.push(`Choice ${choice.id || "<no id>"} in ${id} targets missing scene ${target}`);
          }
          if (target === id && !scene.allowSelfLoop) {
            errors.push(`Choice ${choice.id || "<no id>"} in ${id} loops to itself`);
          }
        }
      }
      if (!scene.isEnding) {
        const enabledCount = (scene.choices || []).length;
        if (id.includes("_hub_") && enabledCount < 2) {
          warnings.push(`Hub ${id} has fewer than two choices`);
        }
      }
    }

    const reachable = new Set();
    const stack = ["neutral_act0_hub_identity"];
    while (stack.length) {
      const current = stack.pop();
      if (reachable.has(current)) continue;
      reachable.add(current);
      const scene = db[current];
      if (!scene || scene.isEnding) continue;
      for (const choice of scene.choices || []) {
        const target = getChoiceTarget(choice);
        if (target && !reachable.has(target)) stack.push(target);
      }
    }
    for (const id of ids) {
      if (!reachable.has(id) && !db[id].isEnding) {
        warnings.push(`Scene ${id} is unreachable`);
      }
    }

    return { errors, warnings };
  }

  function randomWalkCoverage(db, runs = 300, maxSteps = 120) {
    const visited = new Set();
    const endings = new Set();
    let seed = 1337;

    for (let i = 0; i < runs; i += 1) {
      let current = "neutral_act0_hub_identity";
      for (let step = 0; step < maxSteps; step += 1) {
        const scene = db[current];
        if (!scene) break;
        visited.add(current);
        if (scene.isEnding) {
          endings.add(current);
          break;
        }
        const choices = (scene.choices || []).filter((choice) => choice && getChoiceTarget(choice));
        if (!choices.length) break;
        seed = (seed + 31) >>> 0;
        const r = randFromSeed(seed);
        const choice = choices[Math.floor(r * choices.length)];
        const target = getChoiceTarget(choice);
        if (!target) break;
        current = target;
      }
    }

    return {
      coverage: Math.round((visited.size / Object.keys(db).length) * 100),
      visited: visited.size,
      endings: Array.from(endings)
    };
  }

  function getEl(id) {
    return document.getElementById(id);
  }

  class ConsequenceGame {
    constructor() {
      this.state = createInitialState();
      this.db = STORY_DATABASE;
      this.loadUIRefs();
      this.bindControls();
      const save = this.safeLoad();
      if (save) {
        this.state = save;
        clampStats(this.state.stats);
      }
      this.renderScene(this.state.sceneId);
    }

    loadUIRefs() {
      this.ui = {
        story: getEl("scene-text"),
        choices: getEl("choices"),
        stats: getEl("stats"),
        eventLog: getEl("event-log"),
        persona: getEl("persona-grid"),
        inventory: getEl("inventory-list"),
        traumaBar: getEl("trauma-bar"),
        traumaWarning: getEl("trauma-warning"),
        dayhour: getEl("dayhour-indicator"),
        worldTime: getEl("world-time"),
        relationshipList: getEl("relationships-list"),
        relationshipCount: getEl("relationship-count"),
        decisionTree: getEl("decision-tree"),
        flagDisplay: getEl("flag-display"),
        stateHash: getEl("state-hash"),
        characterName: getEl("char-name"),
        characterBackground: getEl("char-background"),
        popup: getEl("consequence-popup"),
        popupText: getEl("consequence-text"),
        popupOk: getEl("consequence-ok")
      };
    }

    bindControls() {
      const newBtn = getEl("new-game");
      const contBtn = getEl("continue-game");
      const saveBtn = getEl("save-game");
      const loadBtn = getEl("load-game");
      const exportBtn = getEl("export-game");
      const fileInput = getEl("file-loader");
      const toggleBackend = getEl("toggle-backend");

      if (newBtn) newBtn.addEventListener("click", () => this.reset());
      if (contBtn) contBtn.addEventListener("click", () => this.renderScene(this.state.sceneId));
      if (saveBtn) saveBtn.addEventListener("click", () => this.safeSave());
      if (loadBtn) loadBtn.addEventListener("click", () => this.promptLoad());
      if (exportBtn) exportBtn.addEventListener("click", () => this.exportSave());
      if (fileInput) fileInput.addEventListener("change", (event) => this.importSave(event));
      if (toggleBackend) toggleBackend.addEventListener("click", () => {
        const panel = getEl("backend-content");
        if (!panel) return;
        panel.classList.toggle("hidden");
      });
      if (this.ui.popupOk && this.ui.popup) {
        this.ui.popupOk.addEventListener("click", () => {
          this.ui.popup.classList.add("hidden");
        });
      }
    }

    reset() {
      this.state = createInitialState();
      this.safeSave();
      this.renderScene(this.state.sceneId);
    }

    safeSave() {
      try {
        const snapshot = JSON.stringify(this.state);
        window.localStorage.setItem(SAVE_KEY, snapshot);
      } catch (err) {
        console.warn("Save failed", err);
      }
    }

    safeLoad() {
      try {
        const raw = window.localStorage.getItem(SAVE_KEY);
        if (!raw) return null;
        return JSON.parse(raw);
      } catch (err) {
        console.warn("Load failed", err);
        return null;
      }
    }

    promptLoad() {
      const input = getEl("file-loader");
      if (input) input.click();
    }

    importSave(event) {
      const files = event && event.target && event.target.files;
      if (!files || !files.length) return;
      const file = files[0];
      const reader = new FileReader();
      reader.onload = () => {
        try {
          const parsed = JSON.parse(reader.result);
          this.state = parsed;
          clampStats(this.state.stats);
          this.renderScene(this.state.sceneId);
        } catch (err) {
          console.warn("Import failed", err);
        }
      };
      reader.readAsText(file);
    }

    exportSave() {
      try {
        const data = JSON.stringify(this.state, null, 2);
        const blob = new Blob([data], { type: "application/json" });
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = `${WORKING_TITLE.toLowerCase()}_save.json`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
      } catch (err) {
        console.warn("Export failed", err);
      }
    }

    showPopup(text) {
      if (!this.ui.popup || !this.ui.popupText) return;
      this.ui.popupText.textContent = text;
      this.ui.popup.classList.remove("hidden");
    }

    renderScene(sceneId) {
      const targetId = normalizeSceneId(sceneId) || this.state.sceneId || "neutral_act0_hub_identity";
      const scene = this.db[targetId];
      if (!scene) {
        console.warn("Missing scene", targetId);
        return;
      }

      if (this.state.sceneId !== targetId) {
        if (typeof scene.timeDelta === "number") {
          this.state.time += scene.timeDelta;
        }
        if (targetId.includes("_hub_") && this.state.sceneId !== targetId) {
          this.state.time += 1;
        }
      }

      this.state.sceneId = targetId;
      advanceSchedule(this.state);
      this.renderStory(scene);
      this.renderChoices(scene);
      this.renderStats();
      this.renderRelationships();
      this.renderFlags();
      this.renderDecisionTrace();
      this.safeSave();
    }

    renderStory(scene) {
      if (this.ui.story) {
        const name = this.state.identity && this.state.identity.name ? this.state.identity.name : "You";
        const background = this.state.identity && this.state.identity.background ? this.state.identity.background : "survivor";
        const text = scene.text.replace(/\bAlex\b/g, () => {
          if (this.state.flags.alex_dead) return "Alex's memory";
          return "Alex";
        });
        this.ui.story.innerHTML = text + `<p class="persona-flavor">${name} — ${background}</p>`;
      }
    }

    renderChoices(scene) {
      if (!this.ui.choices) return;
      this.ui.choices.innerHTML = "";
      const fragment = document.createDocumentFragment();
      const available = [];

      for (const choice of scene.choices || []) {
        if (!choice) continue;
        const requirement = evaluateRequirements(this.state, choice);
        const hasTarget = !!getChoiceTarget(choice) || (choice.effects && Object.keys(choice.effects).length > 0);
        if (!hasTarget) continue;
        available.push({ choice, requirement });
      }

      if (!available.length) {
        available.push({ choice: failForwardChoice(this.state), requirement: { ok: true } });
      }

      for (const { choice, requirement } of available) {
        const button = document.createElement("button");
        button.className = "choice";
        if (choice.tags && choice.tags.length) {
          button.dataset.type = choice.tags[0];
        }
        button.textContent = choice.text;
        if (!requirement.ok) {
          button.disabled = true;
          button.classList.add("disabled");
          button.title = requirement.reason || "Unavailable";
        } else {
          button.addEventListener("click", () => this.makeChoice(choice));
        }
        fragment.appendChild(button);
      }
      this.ui.choices.appendChild(fragment);
    }

    renderStats() {
      const stats = this.state.stats;
      const day = Math.floor(this.state.time / 24);
      const hour = this.state.time % 24;
      if (this.ui.stats) {
        this.ui.stats.innerHTML = `
          <div class="stats-group">
            <span class="stat-pill">Health ${stats.health}</span>
            <span class="stat-pill">Stamina ${stats.stamina}</span>
            <span class="stat-pill">Stress ${stats.stress}</span>
            <span class="stat-pill">Morality ${stats.morality}</span>
            <span class="stat-pill">Trauma ${stats.trauma}</span>
          </div>`;
      }
      if (this.ui.dayhour) {
        this.ui.dayhour.textContent = `Day ${day} · ${hour.toString().padStart(2, "0")}:00`;
      }
      if (this.ui.worldTime) {
        this.ui.worldTime.textContent = `T+${this.state.time}h`;
      }
      if (this.ui.characterName) {
        this.ui.characterName.textContent = this.state.identity.name || "—";
      }
      if (this.ui.characterBackground) {
        this.ui.characterBackground.textContent = this.state.identity.background || "—";
      }
      if (this.ui.inventory) {
        this.ui.inventory.innerHTML = "";
        if (!this.state.inventory.length) {
          const span = document.createElement("span");
          span.className = "empty-inventory";
          span.textContent = "(empty)";
          this.ui.inventory.appendChild(span);
        } else {
          for (const item of this.state.inventory) {
            const chip = document.createElement("span");
            chip.className = "inventory-chip";
            chip.textContent = item;
            this.ui.inventory.appendChild(chip);
          }
        }
      }
      if (this.ui.traumaBar) {
        const pct = Math.min(100, Math.round((stats.trauma / STATS_MIN_MAX.trauma[1]) * 100));
        this.ui.traumaBar.style.width = `${pct}%`;
      }
      if (this.ui.traumaWarning) {
        if (stats.trauma < 40) {
          this.ui.traumaWarning.textContent = "Stable";
          this.ui.traumaWarning.className = "trauma-warning moderate";
        } else if (stats.trauma < 80) {
          this.ui.traumaWarning.textContent = "Strained";
          this.ui.traumaWarning.className = "trauma-warning high";
        } else {
          this.ui.traumaWarning.textContent = "Critical";
          this.ui.traumaWarning.className = "trauma-warning critical";
        }
      }
      if (this.ui.persona) {
        this.ui.persona.innerHTML = "";
        for (const [key, value] of Object.entries(this.state.persona)) {
          const row = document.createElement("div");
          row.className = "persona-point";
          const label = document.createElement("span");
          label.className = "persona-name";
          label.textContent = ROUTE_TITLES[key] || key;
          const val = document.createElement("span");
          val.className = "persona-value";
          val.textContent = value.toString();
          row.appendChild(label);
          row.appendChild(val);
          this.ui.persona.appendChild(row);
        }
      }
      if (this.state.events && this.ui.eventLog) {
        this.ui.eventLog.innerHTML = "";
        for (const event of this.state.events.slice(0, 10)) {
          const entry = document.createElement("div");
          entry.className = "event-log-entry";
          entry.textContent = `${event.text}`;
          this.ui.eventLog.appendChild(entry);
        }
      }
    }

    renderRelationships() {
      if (!this.ui.relationshipList) return;
      this.ui.relationshipList.innerHTML = "";
      const entries = Object.entries(this.state.relationships || {});
      for (const [name, value] of entries) {
        const row = document.createElement("div");
        row.className = "relationship-item";
        const label = document.createElement("span");
        label.className = "relationship-name";
        label.textContent = name;
        const badge = document.createElement("span");
        badge.className = "relationship-status relationship-trust-neutral";
        badge.textContent = value.toString();
        if (value >= 20) badge.className = "relationship-status relationship-trust-positive";
        if (value <= -20) badge.className = "relationship-status relationship-trust-negative";
        row.appendChild(label);
        row.appendChild(badge);
        this.ui.relationshipList.appendChild(row);
      }
      if (this.ui.relationshipCount) {
        this.ui.relationshipCount.textContent = `${entries.length} contacts`;
      }
    }

    renderFlags() {
      if (!this.ui.flagDisplay) return;
      this.ui.flagDisplay.innerHTML = "";
      for (const [flag, value] of Object.entries(this.state.flags || {})) {
        if (!value) continue;
        const flagEl = document.createElement("div");
        flagEl.className = "flag-item";
        flagEl.textContent = flag;
        this.ui.flagDisplay.appendChild(flagEl);
      }
      if (this.ui.stateHash) {
        const summary = `${this.state.sceneId}|${Object.keys(this.state.flags).sort().join(",")}|${this.state.time}`;
        let hash = 0;
        for (let i = 0; i < summary.length; i += 1) {
          hash = (hash << 5) - hash + summary.charCodeAt(i);
          hash |= 0;
        }
        this.ui.stateHash.textContent = `#${(hash >>> 0).toString(16)}`;
      }
    }

    renderDecisionTrace() {
      if (!this.ui.decisionTree) return;
      this.ui.decisionTree.innerHTML = "";
      for (const entry of this.state.decisionTrace.slice(-12)) {
        const node = document.createElement("div");
        node.className = "decision-node";
        node.textContent = entry;
        this.ui.decisionTree.appendChild(node);
      }
    }

    makeChoice(choice) {
      const nextState = clone(this.state);
      applyChoiceCost(nextState, choice);
      applyChoiceEffects(nextState, choice.effects || {});
      const popupNeeded = shouldPopup(choice.effects);
      const popupMessage = (choice && choice.popupText) || (choice.effects && choice.effects.pushEvent) || "They will remember that.";
      const goTo = getChoiceTarget(choice) || nextState.sceneId;
      nextState.sceneId = goTo;
      nextState.decisionTrace = nextState.decisionTrace || [];
      nextState.decisionTrace.push(`${this.state.sceneId}::${choice.id || choice.text}`);
      this.state = nextState;
      clampStats(this.state.stats);
      if (popupNeeded) {
        this.showPopup(popupMessage);
      }
      this.renderScene(goTo);
    }
  }

  window.STORY_DATABASE = window.STORY_DATABASE || {};
  Object.assign(window.STORY_DATABASE, STORY_DATABASE);
  window.ConsequenceGame = ConsequenceGame;

  const validation = validateStoryDatabase(window.STORY_DATABASE);
  if (validation.errors.length) {
    console.error("Validator errors:", validation.errors);
  }
  if (validation.warnings.length) {
    console.warn("Validator warnings:", validation.warnings);
  }
  const coverage = randomWalkCoverage(window.STORY_DATABASE);
  console.log("Random walk coverage:", coverage);

})();

document.addEventListener("DOMContentLoaded", () => {
  window.game = new window.ConsequenceGame();
});
