// COMPLETION OF THE CONSEQUENCE GAME STORY DATABASE
// This completes the story database with all remaining scenes

const STORY_COMPLETION = {
  // Complete the alex_bond_01 scene
  alex_bond_01: {
    id: 'alex_bond_01',
    text: `Alex catches their breath. "My brother Marcus turned. In the basement. I heard him calling my name but... wrong. Am I a coward for running?"`,
    choices: [
      {
        id: 'ab1_survivor',
        text: `"You chose to live. That's not cowardice."`,
        goTo: 'alex_bond_02',
        effects: { stats: { morality: 2, stress: -2 }, persona: { nice: 2 }, relationships: { Alex: 5 }, pushEvent: 'Permission to survive granted.' },
        tags: ['nice'],
      },
      {
        id: 'ab1_purpose',
        text: '"Marcus would want you alive."',
        goTo: 'alex_bond_02',
        effects: { stats: { stress: -3 }, persona: { nice: 2 }, relationships: { Alex: 6 }, pushEvent: 'Grief becomes compass.' },
        tags: ['nice'],
      },
      {
        id: 'ab1_hard',
        text: `"Coward? No. But don't run next time."`,
        goTo: 'alex_bond_02',
        effects: { persona: { rude: 2 }, relationships: { Alex: 2 }, pushEvent: 'Steel offered as kindness.' },
        tags: ['rude'],
      },
      {
        id: 'ab1_lever',
        text: `"You'll have to prove you belong here."`,
        goTo: 'alex_bond_02',
        effects: { stats: { morality: -2 }, persona: { psycho: 2 }, relationships: { Alex: 0 }, flagsSet: ['alex_on_trial'], pushEvent: 'Guilt as leverage.' },
        tags: ['psycho'],
      },
    ],
    timeDelta: 1,
  },

  // Complete the 3b_interior scene
  '3b_interior': {
    id: '3b_interior',
    text: `Inside 3B: ransacked but recognizable. Tool belt on the workbench. Photos intact. Basement door: scratched from the inside. Something moves down there. Not Marcus anymore.`,
    choices: [
      {
        id: '3bi_tools',
        text: 'Grab tools and leave immediately',
        goTo: 'apartment_hub_01',
        effects: { inventoryAdd: ['marcus_tools'], stats: { stress: -1 }, pushEvent: 'Mission complete. Ghosts unconfronted.' },
        tags: ['chill'],
      },
      {
        id: '3bi_basement',
        text: 'Check basement—maybe Marcus left something',
        goTo: 'basement_check',
        effects: { stats: { stress: 2 }, persona: { psycho: 1 }, pushEvent: 'You face what Alex cannot.' },
        tags: ['psycho'],
      },
      {
        id: '3bi_photos',
        text: 'Take photos—Alex might want them',
        goTo: 'apartment_hub_01',
        effects: { inventoryAdd: ['family_photos'], relationships: { Alex: 3 }, pushEvent: 'Memories are heavy gifts.' },
        tags: ['nice'],
      },
    ],
    timeDelta: 1,
  },

  basement_check: {
    id: 'basement_check',
    text: `The basement door creaks. Below: Marcus's workshop. Tools scattered. Blood on the floor. A note: "ALEX—RUN. DON'T COME DOWN HERE. I LOVE YOU." Something moves in the shadows.`,
    choices: [
      {
        id: 'bc_quick',
        text: 'Grab tools and run',
        goTo: 'apartment_hub_01',
        effects: { inventoryAdd: ['marcus_tools'], stats: { stress: 2 }, pushEvent: 'You honor Marcus\'s last wish.' },
        tags: ['chill'],
      },
      {
        id: 'bc_note',
        text: 'Take the note for Alex',
        goTo: 'apartment_hub_01',
        effects: { inventoryAdd: ['marcus_note'], relationships: { Alex: 5 }, pushEvent: 'Last words are sacred.' },
        tags: ['nice'],
      },
      {
        id: 'bc_confront',
        text: 'Face whatever is down there',
        goTo: 'basement_confrontation',
        effects: { stats: { health: -3, stress: 3 }, persona: { killer: 2 }, pushEvent: 'You face the thing that was Marcus.' },
        tags: ['killer'],
      },
    ],
    timeDelta: 1,
  },

  basement_confrontation: {
    id: 'basement_confrontation',
    text: `You descend. The thing that was Marcus lunges. You fight. It's stronger than expected. Your weapon finds its mark. It falls. You stand over what used to be Marcus, breathing hard.`,
    choices: [
      {
        id: 'bc_honor',
        text: 'Say goodbye to what Marcus was',
        goTo: 'apartment_hub_01',
        effects: { stats: { morality: 2, stress: -1 }, persona: { nice: 1 }, pushEvent: 'You honor the man, not the monster.' },
        tags: ['nice'],
      },
      {
        id: 'bc_practical',
        text: 'Search for useful items',
        goTo: 'apartment_hub_01',
        effects: { inventoryAdd: ['marcus_tools', 'emergency_supplies'], persona: { fixer: 1 }, pushEvent: 'Death yields resources.' },
        tags: ['fixer'],
      },
      {
        id: 'bc_leave',
        text: 'Leave immediately',
        goTo: 'apartment_hub_01',
        effects: { stats: { stress: 1 }, pushEvent: 'Some victories feel hollow.' },
        tags: ['chill'],
      },
    ],
    timeDelta: 1,
  },

  // Complete the apartment hub scenes
  apartment_hub_01: {
    id: 'apartment_hub_01',
    text: `Day 1, Hour 8. The building is quiet. Too quiet. You and Alex need a plan. Resources are finite. The infected are learning.`,
    choices: [
      {
        id: 'ah1_3b',
        text: `Retrieve Marcus's tools from 3B`,
        goTo: 'retrieve_3b',
        effects: { stats: { stamina: -1 }, pushEvent: 'The hall smells like copper and fear.' },
        tags: ['fixer'],
        req: { flags: ['marcus_tools_goal'] },
      },
      {
        id: 'ah1_water',
        text: 'Secure water supply—bathtub, containers',
        goTo: 'water_mission',
        effects: { persona: { fixer: 1 }, pushEvent: 'Water first. Always water first.' },
        tags: ['fixer'],
        req: { notFlags: ['water_secured'] },
      },
      {
        id: 'ah1_neighbor',
        text: 'Check on neighbors—4C (Maya), 2A (elderly couple)',
        goTo: 'neighbor_check',
        effects: { stats: { stress: 1 }, persona: { nice: 1 }, pushEvent: 'Humanity tax: checking on the vulnerable.' },
        tags: ['nice'],
      },
      {
        id: 'ah1_fortify',
        text: 'Fortify apartment—barricades, traps',
        goTo: 'fortify_phase',
        effects: { stats: { stamina: -2 }, persona: { protector: 1 }, pushEvent: 'Wood and nails become peace of mind.' },
        tags: ['protector'],
      },
      {
        id: 'ah1_roof',
        text: 'Scout the roof—escape routes, signals',
        goTo: 'roof_scout',
        effects: { persona: { chill: 1 }, pushEvent: 'Up means options.' },
        tags: ['chill'],
      },
      {
        id: 'ah1_radio',
        text: 'Listen to emergency broadcasts',
        goTo: 'radio_scan',
        effects: { stats: { stress: -1 }, pushEvent: 'Voices through static feel like ghosts.' },
        tags: ['chill'],
      },
      {
        id: 'ah1_evening',
        text: 'Skip ahead to evening preparations',
        goTo: 'evening_hub',
        effects: {},
        tags: ['chill'],
      },
    ],
    timeDelta: 0,
  },

  apartment_hub_solo: {
    id: 'apartment_hub_solo',
    text: `Day 1, Hour 8. You are alone. The silence is both relief and weight. Every decision is yours. Every consequence too.`,
    choices: [
      {
        id: 'ahs_water',
        text: 'Secure water supply',
        goTo: 'water_mission_solo',
        effects: { persona: { fixer: 1 }, pushEvent: 'No one to help. No one to slow you down.' },
        tags: ['fixer'],
        req: { notFlags: ['water_secured'] },
      },
      {
        id: 'ahs_scavenge',
        text: 'Scavenge other apartments',
        goTo: 'apartment_raid',
        effects: { stats: { morality: -1 }, persona: { fixer: 2 }, pushEvent: 'The dead left supplies behind.' },
        tags: ['fixer'],
        req: { items: ['master_keys'] },
      },
      {
        id: 'ahs_fortify',
        text: 'Fortify your position',
        goTo: 'fortify_solo',
        effects: { stats: { stamina: -2 }, persona: { protector: 1 }, pushEvent: 'One person, one fortress.' },
        tags: ['protector'],
      },
      {
        id: 'ahs_roof',
        text: 'Scout roof and adjacent buildings',
        goTo: 'roof_scout_solo',
        effects: { persona: { chill: 1 }, pushEvent: 'Alone means mobile.' },
        tags: ['chill'],
      },
      {
        id: 'ahs_stranger',
        text: 'Check on the stranger across the street',
        goTo: 'stranger_mission',
        effects: { stats: { stress: 2 }, persona: { protector: 2 }, pushEvent: 'Redemption has a high price.' },
        tags: ['protector'],
        req: { flags: ['promised_help'] },
      },
      {
        id: 'ahs_radio',
        text: 'Monitor radio broadcasts',
        goTo: 'radio_scan_solo',
        effects: { stats: { stress: -1 }, pushEvent: 'Static becomes company.' },
        tags: ['chill'],
      },
      {
        id: 'ahs_evening',
        text: 'Skip to evening',
        goTo: 'evening_hub_solo',
        effects: {},
        tags: ['chill'],
      },
    ],
    timeDelta: 0,
  },

  // Additional scenes to complete the story
  water_mission: {
    id: 'water_mission',
    text: `The taps still work, but pressure is dropping. You need to store every drop you can. Alex helps fill containers.`,
    choices: [
      {
        id: 'wm_bathtub',
        text: 'Fill bathtub and every container',
        goTo: 'apartment_hub_01',
        effects: { stats: { stamina: -2 }, inventoryAdd: ['water_jugs'], flagsSet: ['water_secured'], pushEvent: 'Water slaps porcelain. Relief slaps your chest.' },
        tags: ['fixer'],
      },
      {
        id: 'wm_bleach',
        text: 'Add bleach for purification',
        goTo: 'apartment_hub_01',
        effects: { inventoryAdd: ['purified_water'], flagsSet: ['water_secured'], pushEvent: 'Future-you will thank today-you.' },
        tags: ['fixer'],
      },
    ],
    timeDelta: 2,
  },

  water_mission_solo: {
    id: 'water_mission_solo',
    text: `The taps still work, but pressure is dropping. You work alone, filling every container you can find.`,
    choices: [
      {
        id: 'wms_bathtub',
        text: 'Fill bathtub and every container',
        goTo: 'apartment_hub_solo',
        effects: { stats: { stamina: -3 }, inventoryAdd: ['water_jugs'], flagsSet: ['water_secured'], pushEvent: 'Water slaps porcelain. Relief slaps your chest.' },
        tags: ['fixer'],
      },
      {
        id: 'wms_bleach',
        text: 'Add bleach for purification',
        goTo: 'apartment_hub_solo',
        effects: { inventoryAdd: ['purified_water'], flagsSet: ['water_secured'], pushEvent: 'Future-you will thank today-you.' },
        tags: ['fixer'],
      },
    ],
    timeDelta: 2,
  },

  neighbor_check: {
    id: 'neighbor_check',
    text: `4C: Maya wheezes behind a door chain. "Inhaler's low," she rasps. 2A: Silence. You knock. Nothing.`,
    choices: [
      {
        id: 'nc_maya',
        text: 'Help Maya—share supplies',
        goTo: 'apartment_hub_01',
        effects: { stats: { morality: 2 }, relationships: { Maya: 5 }, flagsSet: ['maya_helped'], pushEvent: 'You make breath a little easier.' },
        tags: ['nice'],
      },
      {
        id: 'nc_2a',
        text: 'Check 2A—force the door',
        goTo: 'apartment_hub_01',
        effects: { stats: { morality: -2 }, inventoryAdd: ['elderly_supplies'], pushEvent: 'You find what you expected.' },
        tags: ['fixer'],
      },
      {
        id: 'nc_avoid',
        text: 'Avoid contact—too risky',
        goTo: 'apartment_hub_01',
        effects: { stats: { stress: 1 }, pushEvent: 'You choose safety over humanity.' },
        tags: ['chill'],
      },
    ],
    timeDelta: 2,
  },

  fortify_phase: {
    id: 'fortify_phase',
    text: `You and Alex work together. Barricades go up. Traps are set. The apartment becomes a fortress.`,
    choices: [
      {
        id: 'fp_interior',
        text: 'Fortify interior doors and windows',
        goTo: 'apartment_hub_01',
        effects: { stats: { stamina: -2 }, persona: { protector: 1 }, flagsSet: ['interior_fortified'], pushEvent: 'Noise now means less later.' },
        tags: ['protector'],
      },
      {
        id: 'fp_traps',
        text: 'Set noise traps and alarms',
        goTo: 'apartment_hub_01',
        effects: { persona: { warlord: 1 }, flagsSet: ['traps_set'], pushEvent: 'Early warning becomes your edge.' },
        tags: ['warlord'],
      },
    ],
    timeDelta: 2,
  },

  fortify_solo: {
    id: 'fortify_solo',
    text: `You work alone. Barricades go up. Traps are set. The apartment becomes your fortress.`,
    choices: [
      {
        id: 'fs_interior',
        text: 'Fortify interior doors and windows',
        goTo: 'apartment_hub_solo',
        effects: { stats: { stamina: -3 }, persona: { protector: 1 }, flagsSet: ['interior_fortified'], pushEvent: 'Noise now means less later.' },
        tags: ['protector'],
      },
      {
        id: 'fs_traps',
        text: 'Set noise traps and alarms',
        goTo: 'apartment_hub_solo',
        effects: { persona: { warlord: 1 }, flagsSet: ['traps_set'], pushEvent: 'Early warning becomes your edge.' },
        tags: ['warlord'],
      },
    ],
    timeDelta: 2,
  },

  roof_scout: {
    id: 'roof_scout',
    text: `The roof offers a bird's eye view. You can see the patterns of the infected, the movements of survivors.`,
    choices: [
      {
        id: 'rs_map',
        text: 'Map the area systematically',
        goTo: 'apartment_hub_01',
        effects: { persona: { fixer: 1 }, flagsSet: ['area_mapped'], pushEvent: 'You map the area systematically.' },
        tags: ['fixer'],
      },
      {
        id: 'rs_signals',
        text: 'Look for signals from other survivors',
        goTo: 'apartment_hub_01',
        effects: { persona: { chill: 1 }, flagsSet: ['signals_spotted'], pushEvent: 'You spot signals from other survivors.' },
        tags: ['chill'],
      },
    ],
    timeDelta: 2,
  },

  roof_scout_solo: {
    id: 'roof_scout_solo',
    text: `The roof offers a bird's eye view. You can see the patterns of the infected, the movements of survivors.`,
    choices: [
      {
        id: 'rss_map',
        text: 'Map the area systematically',
        goTo: 'apartment_hub_solo',
        effects: { persona: { fixer: 1 }, flagsSet: ['area_mapped'], pushEvent: 'You map the area systematically.' },
        tags: ['fixer'],
      },
      {
        id: 'rss_signals',
        text: 'Look for signals from other survivors',
        goTo: 'apartment_hub_solo',
        effects: { persona: { chill: 1 }, flagsSet: ['signals_spotted'], pushEvent: 'You spot signals from other survivors.' },
        tags: ['chill'],
      },
    ],
    timeDelta: 2,
  },

  radio_scan: {
    id: 'radio_scan',
    text: `The radio crackles with possibility. Between static: voices, numbers, the sound of other survivors.`,
    choices: [
      {
        id: 'rs_emergency',
        text: 'Scan emergency bands',
        goTo: 'apartment_hub_01',
        effects: { stats: { stress: -1 }, persona: { fixer: 1 }, flagsSet: ['emergency_bands_scanned'], pushEvent: 'Emergency bands crackle with hope.' },
        tags: ['fixer'],
      },
      {
        id: 'rs_ham',
        text: 'Try ham radio frequencies',
        goTo: 'apartment_hub_01',
        effects: { stats: { stress: -1 }, pushEvent: 'Ham operators know how to survive.' },
        tags: ['chill'],
      },
    ],
    timeDelta: 1,
  },

  radio_scan_solo: {
    id: 'radio_scan_solo',
    text: `The radio crackles with possibility. Between static: voices, numbers, the sound of other survivors.`,
    choices: [
      {
        id: 'rss_emergency',
        text: 'Scan emergency bands',
        goTo: 'apartment_hub_solo',
        effects: { stats: { stress: -1 }, persona: { fixer: 1 }, flagsSet: ['emergency_bands_scanned'], pushEvent: 'Emergency bands crackle with hope.' },
        tags: ['fixer'],
      },
      {
        id: 'rss_ham',
        text: 'Try ham radio frequencies',
        goTo: 'apartment_hub_solo',
        effects: { stats: { stress: -1 }, pushEvent: 'Ham operators know how to survive.' },
        tags: ['chill'],
      },
    ],
    timeDelta: 1,
  },

  apartment_raid: {
    id: 'apartment_raid',
    text: `You use the master keys to enter other apartments. Some are empty. Some contain supplies. Some contain death.`,
    choices: [
      {
        id: 'ar_supplies',
        text: 'Focus on finding supplies',
        goTo: 'apartment_hub_solo',
        effects: { inventoryAdd: ['apartment_supplies'], persona: { fixer: 1 }, pushEvent: 'You find supplies in the building.' },
        tags: ['fixer'],
      },
      {
        id: 'ar_survivors',
        text: 'Look for other survivors',
        goTo: 'apartment_hub_solo',
        effects: { stats: { stress: 2 }, persona: { nice: 1 }, pushEvent: 'You search for other survivors.' },
        tags: ['nice'],
      },
    ],
    timeDelta: 2,
  },

  stranger_mission: {
    id: 'stranger_mission',
    text: `You cross the street to the building with the "HELP TRAPPED 4F" sign. The lobby is dark. Stairs creak.`,
    choices: [
      {
        id: 'sm_rescue',
        text: 'Attempt rescue',
        goTo: 'apartment_hub_solo',
        effects: { stats: { health: -3, stress: 3 }, persona: { protector: 2 }, relationships: { 'Stranger': 5 }, pushEvent: 'You risk everything for a promise.' },
        tags: ['protector'],
      },
      {
        id: 'sm_abort',
        text: 'Too dangerous—abort mission',
        goTo: 'apartment_hub_solo',
        effects: { stats: { morality: -2, stress: -1 }, persona: { psycho: 1 }, pushEvent: 'You choose survival over promises.' },
        tags: ['psycho'],
      },
    ],
    timeDelta: 2,
  },

  evening_hub: {
    id: 'evening_hub',
    text: `Day 1, Hour 18. Light shifts to orange. You and Alex prepare for the longest night of your lives.`,
    choices: [
      {
        id: 'eh_rest',
        text: 'Rest and recover',
        goTo: 'night_prep',
        effects: { stats: { health: 3, stamina: 3, stress: -2 }, pushEvent: 'You steal sleep like a thief.' },
        tags: ['chill'],
      },
      {
        id: 'eh_plan',
        text: 'Plan tomorrow\'s strategy',
        goTo: 'night_prep',
        effects: { persona: { fixer: 1 }, pushEvent: 'Planning is control.' },
        tags: ['fixer'],
      },
      {
        id: 'eh_bond',
        text: 'Talk with Alex—build trust',
        goTo: 'night_prep',
        effects: { relationships: { Alex: 3 }, pushEvent: 'Words build bridges.' },
        tags: ['nice'],
      },
    ],
    timeDelta: 1,
  },

  evening_hub_solo: {
    id: 'evening_hub_solo',
    text: `Day 1, Hour 18. Light shifts to orange. You prepare for the longest night of your life. Alone.`,
    choices: [
      {
        id: 'ehs_rest',
        text: 'Rest and recover',
        goTo: 'night_prep_solo',
        effects: { stats: { health: 3, stamina: 3, stress: -2 }, pushEvent: 'You steal sleep like a thief.' },
        tags: ['chill'],
      },
      {
        id: 'ehs_plan',
        text: 'Plan tomorrow\'s strategy',
        goTo: 'night_prep_solo',
        effects: { persona: { fixer: 1 }, pushEvent: 'Planning is control.' },
        tags: ['fixer'],
      },
      {
        id: 'ehs_journal',
        text: 'Write in journal—process the day',
        goTo: 'night_prep_solo',
        effects: { stats: { stress: -1, morality: 1 }, pushEvent: 'Paper holds what memory cannot.' },
        tags: ['nice'],
      },
    ],
    timeDelta: 1,
  },

  night_prep: {
    id: 'night_prep',
    text: `Night falls. The building settles into darkness. You and Alex prepare for whatever comes.`,
    choices: [
      {
        id: 'np_watch',
        text: 'Take turns keeping watch',
        goTo: 'night_event',
        effects: { stats: { stamina: -2, stress: -1 }, pushEvent: 'You trade sleep for certainty.' },
        tags: ['protector'],
      },
      {
        id: 'np_traps',
        text: 'Rely on traps and alarms',
        goTo: 'night_event',
        effects: { stats: { stress: -2 }, pushEvent: 'You put your faith in copper and chance.' },
        tags: ['fixer'],
        req: { flags: ['traps_set'] },
      },
    ],
    timeDelta: 1,
  },

  night_prep_solo: {
    id: 'night_prep_solo',
    text: `Night falls. The building settles into darkness. You prepare for whatever comes. Alone.`,
    choices: [
      {
        id: 'nps_watch',
        text: 'Stay awake all night',
        goTo: 'night_event_solo',
        effects: { stats: { stamina: -3, stress: -2 }, pushEvent: 'You trade sleep for certainty.' },
        tags: ['protector'],
      },
      {
        id: 'nps_traps',
        text: 'Rely on traps and alarms',
        goTo: 'night_event_solo',
        effects: { stats: { stress: -2 }, pushEvent: 'You put your faith in copper and chance.' },
        tags: ['fixer'],
        req: { flags: ['traps_set'] },
      },
    ],
    timeDelta: 1,
  },

  night_event: {
    id: 'night_event',
    text: `Night holds its breath. So do you and Alex. Every creak could be death. Every silence could be worse.`,
    choices: [
      {
        id: 'ne_breach',
        text: 'Something tests your door',
        goTo: 'day2_morning',
        effects: { stats: { stress: 3 }, flagsSet: ['night_breach'], pushEvent: 'The door holds. For now.' },
        tags: ['protector'],
      },
      {
        id: 'ne_peace',
        text: 'Night passes peacefully',
        goTo: 'day2_morning',
        effects: { stats: { stress: -2 }, flagsSet: ['peaceful_night'], pushEvent: 'Silence is a gift.' },
        tags: ['chill'],
      },
    ],
    timeDelta: 6,
  },

  night_event_solo: {
    id: 'night_event_solo',
    text: `Night holds its breath. So do you. Every creak could be death. Every silence could be worse.`,
    choices: [
      {
        id: 'nes_breach',
        text: 'Something tests your door',
        goTo: 'day2_morning_solo',
        effects: { stats: { stress: 3 }, flagsSet: ['night_breach'], pushEvent: 'The door holds. For now.' },
        tags: ['protector'],
      },
      {
        id: 'nes_peace',
        text: 'Night passes peacefully',
        goTo: 'day2_morning_solo',
        effects: { stats: { stress: -2 }, flagsSet: ['peaceful_night'], pushEvent: 'Silence is a gift.' },
        tags: ['chill'],
      },
    ],
    timeDelta: 6,
  },

  day2_morning: {
    id: 'day2_morning',
    text: `Day 2, Hour 6. You wake to Alex's voice. "We made it through the night." The city outside is different. Quieter. More dangerous.`,
    choices: [
      {
        id: 'd2m_continue',
        text: 'Continue your survival',
        goTo: 'apartment_hub_01',
        effects: { flagsSet: ['day2_started'], pushEvent: 'Day 2 begins.' },
        tags: ['chill'],
      },
    ],
    timeDelta: 1,
  },

  day2_morning_solo: {
    id: 'day2_morning_solo',
    text: `Day 2, Hour 6. You wake alone. The city outside is different. Quieter. More dangerous.`,
    choices: [
      {
        id: 'd2ms_continue',
        text: 'Continue your survival',
        goTo: 'apartment_hub_solo',
        effects: { flagsSet: ['day2_started'], pushEvent: 'Day 2 begins.' },
        tags: ['chill'],
      },
    ],
    timeDelta: 1,
  },
};

// Export for integration
if (typeof module !== 'undefined' && module.exports) {
  module.exports = STORY_COMPLETION;
}