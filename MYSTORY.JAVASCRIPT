(() => {
  const STORAGE_KEY = "consequence_save_v1";
  const CONSEQUENCE_FLAGS = new Set([
    "alex_alive","alex_dead","alex_abused","alex_controlled","alex_exploited",
    "route_psycho","route_nice","route_chill","route_rude",
    "route_protector","route_warlord","route_fixer","route_killer","route_sociopath",
    "proof_killer_mark","proof_killer_cull","proof_killer_fear","proof_killer_apex",
    "proof_warlord_blackout","proof_warlord_tithe","proof_warlord_stomp","proof_warlord_supremacy",
    "proof_fixer_web","proof_fixer_omnimarket",
    "proof_sociopath_dominion",
    "proof_creep_watch","proof_creep_keys","proof_creep_silence",
    "proof_split_echoes","proof_split_masks",
    "proof_chem_binge","proof_chem_trade","proof_chem_shake",
    "bloom_exposed","wall_breached"
  ]);

  const MUTEX = {
    route: ["route_psycho","route_nice","route_chill","route_rude","route_protector","route_warlord","route_fixer","route_killer","route_sociopath"]
  };

  const MAX_STAT = 100;
  const MIN_STAT = -100;

  const DEFAULT_STATE = {
    sceneId: "intro",
    time: 0,
    stats: { health: 90, stamina: 12, stress: 8, morality: 0, viralLoad: 0, chemCraving: 0 },
    persona: { psycho: 0, nice: 0, chill: 0, rude: 0, protector: 0, warlord: 0, fixer: 0, killer: 0, sociopath: 0 },
    inventory: ["pocketknife", "old_radio", "flare"],
    playerName: "Survivor",
    background: null,
    flags: {},
    relationships: {},
    rngSeed: 1776,
    decisionTrace: [],
    schedule: []
  };

  function deepClone(obj) {
    return JSON.parse(JSON.stringify(obj));
  }

  function clamp(value) {
    return Math.max(MIN_STAT, Math.min(MAX_STAT, value));
  }

  function getChoiceTarget(choice) {
    if (!choice) return null;
    const destination = choice.goTo ?? choice.next;
    return typeof destination === "string" && destination.length ? destination : null;
  }

  function ensureStats(state) {
    for (const key of Object.keys(DEFAULT_STATE.stats)) {
      if (typeof state.stats[key] !== "number") state.stats[key] = DEFAULT_STATE.stats[key];
    }
  }

  function applyEffects(state, effects) {
    if (!effects) return;
    if (effects.stats) {
      for (const [key, value] of Object.entries(effects.stats)) {
        state.stats[key] = clamp((state.stats[key] || 0) + value);
      }
    }
    if (effects.persona) {
      for (const [k, v] of Object.entries(effects.persona)) { 
        state.persona[k] = clamp((state.persona[k] || 0) + v); 
      }
    }
    if (Array.isArray(effects.inventoryAdd)) {
      for (const item of effects.inventoryAdd) { state.inventory.push(item); }
    }
    if (Array.isArray(effects.inventoryRemove)) {
      for (const item of effects.inventoryRemove) {
        const idx = state.inventory.indexOf(item);
        if (idx >= 0) state.inventory.splice(idx, 1);
      }
    }
    if (Array.isArray(effects.flagsSet)) {
      for (const flag of effects.flagsSet) {
        if (flag.startsWith("route_")) { setMutexFlag(state, "route", flag); }
        else { state.flags[flag] = true; }
      }
    }
    if (effects.relationships) {
      for (const [name, delta] of Object.entries(effects.relationships)) {
        state.relationships[name] = clamp((state.relationships[name] || 0) + delta);
      }
    }
    if (Array.isArray(effects.schedule)) {
      for (const sched of effects.schedule) {
        if (sched && typeof sched.steps === "number" && sched.apply) {
          state.schedule.push({ steps: Math.max(1, sched.steps), apply: sched.apply });
        }
      }
    }
  }

  function setMutexFlag(state, group, flag) {
    if (MUTEX[group]) {
      for (const existing of MUTEX[group]) {
        delete state.flags[existing];
      }
    }
    state.flags[flag] = true;
  }

  function meetsRequirement(state, req) {
    if (!req) return true;
    if (req.stats) {
      for (const [key, rule] of Object.entries(req.stats)) {
        const value = state.stats[key] || 0;
        if (typeof rule.gte === "number" && value < rule.gte) return false;
        if (typeof rule.lte === "number" && value > rule.lte) return false;
      }
    }
    return true;
  }

  function formatRequirement(req) {
    const parts = [];
    if (!req) return "";
    if (req.stats) {
      for (const [key, rule] of Object.entries(req.stats)) {
        if (typeof rule.gte === "number") parts.push(`${key} ≥ ${rule.gte}`);
        if (typeof rule.lte === "number") parts.push(`${key} ≤ ${rule.lte}`);
      }
    }
    if (Array.isArray(req.items) && req.items.length) { parts.push(`Need: ${req.items.join(", ")}`); }
    if (Array.isArray(req.flags) && req.flags.length) { parts.push(`Flags: ${req.flags.join(", ")}`); }
    return parts.join(" · ");
  }

  class ConsequenceGame {
    constructor() {
      this.state = deepClone(DEFAULT_STATE);
      this.dom = {
        stats: document.getElementById("stats"),
        sceneText: document.getElementById("scene-text"),
        choices: document.getElementById("choices"),
        inventory: document.getElementById("inventory-list"),
        charName: document.getElementById("char-name"),
        charBackground: document.getElementById("char-background"),
        traumaBar: document.getElementById("trauma-bar"),
        traumaWarning: document.getElementById("trauma-warning"),
        personaGrid: document.getElementById("persona-grid"),
        journal: document.getElementById("journal-list"),
        eventLog: document.getElementById("event-log"),
        relationships: document.getElementById("relationships-list"),
        relationshipCount: document.getElementById("relationship-count"),
        objectiveCount: document.getElementById("objective-count"),
        decisionTree: document.getElementById("decision-tree"),
        flagDisplay: document.getElementById("flag-display"),
        stateHash: document.getElementById("state-hash"),
        worldTime: document.getElementById("world-time"),
        dayhour: document.getElementById("dayhour-indicator"),
        consequencePopup: document.getElementById("consequence-popup"),
        consequenceText: document.getElementById("consequence-text"),
        consequenceOk: document.getElementById("consequence-ok")
      };
      this.eventLog = [];
      this.journal = [];
      this.bindControls();
      this.render();
    }

    bindControls() {
      const newGameBtn = document.getElementById("new-game");
      if (newGameBtn) { newGameBtn.addEventListener("click", () => { this.reset(); }); }
      const saveBtn = document.getElementById("save-game");
      if (saveBtn) { saveBtn.addEventListener("click", () => { this.save(); }); }
      const exportBtn = document.getElementById("export-game");
      if (exportBtn) { exportBtn.addEventListener("click", () => { this.export(); }); }
      const toggleBtn = document.getElementById("toggle-backend");
      if (toggleBtn) {
        toggleBtn.addEventListener("click", () => {
          const backend = document.getElementById("backend-content");
          if (backend) backend.classList.toggle("hidden");
        });
      }
      if (this.dom.consequenceOk) {
        this.dom.consequenceOk.addEventListener("click", () => { this.hidePopup(); });
      }
    }

    reset() {
      this.state = deepClone(DEFAULT_STATE);
      this.eventLog = [];
      this.journal = [];
      this.render();
    }

    save() {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.state));
      this.pushEvent("Game saved.", "discovery");
    }

    load() {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        this.state = { ...DEFAULT_STATE, ...JSON.parse(saved) };
        this.render();
        this.pushEvent("Game loaded.", "discovery");
      }
    }

    export() {
      const data = { ...this.state, __eventLog: this.eventLog, __journal: this.journal };
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `consequence-save-${Date.now()}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      this.pushEvent("Exported save.", "discovery");
    }

    makeChoice(choice) {
      const nextState = deepClone(this.state);
      applyEffects(nextState, choice.effects);
      ensureStats(nextState);

      if (choice.effects && choice.effects.pushEvent) {
        this.pushEvent(choice.effects.pushEvent, "consequence");
      }

      const goTo = getChoiceTarget(choice) ?? nextState.sceneId;
      nextState.sceneId = goTo;
      nextState.decisionTrace.push({ choice: choice.id, scene: this.state.sceneId, time: this.state.time });
      this.state = nextState;
      this.render();
    }

    pushEvent(text, type = "info") {
      this.eventLog.unshift({ text, type, time: this.state.time });
      if (this.eventLog.length > 50) this.eventLog.pop();
    }

    showPopup(text) {
      if (!this.dom.consequencePopup) return;
      this.dom.consequenceText.textContent = text;
      this.dom.consequencePopup.classList.remove("hidden");
    }

    hidePopup() {
      if (!this.dom.consequencePopup) return;
      this.dom.consequencePopup.classList.add("hidden");
    }

    renderScene(sceneId) {
      const scene = window.STORY_DATABASE[sceneId];
      if (!scene) {
        this.displayStory("Scene not found.", null);
        this.displayChoices(null);
        return;
      }
      this.displayStory(scene.text, scene);
      this.displayChoices(scene);
    }

    displayStory(text, scene) {
      if (!this.dom.sceneText) return;
      this.dom.sceneText.innerHTML = "";
      const p = document.createElement("p");
      p.textContent = text;
      this.dom.sceneText.appendChild(p);
    }

    displayChoices(scene) {
      if (!this.dom.choices) return;
      this.dom.choices.innerHTML = "";
      const choices = (scene.choices || []).filter((choice) => choice && (getChoiceTarget(choice) || choice.effects));

      for (const choice of choices) {
        const button = document.createElement("button");
        button.className = "choice";
        button.type = "button";
        button.dataset.type = (choice.tags && choice.tags[0]) || "";
        button.innerHTML = `<span class="choice-text">${choice.text}</span>`;

        const met = meetsRequirement(this.state, choice.req);
        if (!met) {
          button.classList.add("disabled");
          button.disabled = true;
          button.title = choice.blockedReason || formatRequirement(choice.req);
        } else {
          button.addEventListener("click", () => this.makeChoice(choice));
        }
        this.dom.choices.appendChild(button);
      }
    }

    renderStats() {
      if (!this.dom.stats) return;
      this.dom.stats.innerHTML = "";
      const group = document.createElement("div");
      group.className = "stats-group";
      const entries = [
        { key: "health", label: "HEALTH" },
        { key: "stamina", label: "STAMINA" },
        { key: "stress", label: "STRESS" },
        { key: "morality", label: "MORALITY" }
      ];
      for (const entry of entries) {
        const pill = document.createElement("div");
        pill.className = "stat-pill";
        pill.textContent = `${entry.label}: ${Math.round(this.state.stats[entry.key] || 0)}`;
        group.appendChild(pill);
      }
      this.dom.stats.appendChild(group);
    }

    renderInventory() {
      if (!this.dom.inventory) return;
      this.dom.inventory.innerHTML = "";
      if (!this.state.inventory.length) {
        const span = document.createElement("span");
        span.className = "empty-inventory";
        span.textContent = "(empty)";
        this.dom.inventory.appendChild(span);
        return;
      }
      for (const item of this.state.inventory) {
        const chip = document.createElement("span");
        chip.className = "inventory-chip";
        chip.textContent = item;
        this.dom.inventory.appendChild(chip);
      }
    }

    renderCharacter() {
      if (this.dom.charName) { this.dom.charName.textContent = this.state.playerName || "—"; }
      if (this.dom.charBackground) {
        this.dom.charBackground.textContent = this.state.background || "—";
      }
    }

    renderPersona() {
      if (!this.dom.personaGrid) return;
      this.dom.personaGrid.innerHTML = "";
      for (const [key, value] of Object.entries(this.state.persona)) {
        const row = document.createElement("div");
        row.className = "persona-point";
        const name = document.createElement("span");
        name.className = "persona-name";
        name.textContent = key;
        const val = document.createElement("span");
        val.className = "persona-value";
        val.textContent = value;
        row.appendChild(name);
        row.appendChild(val);
        this.dom.personaGrid.appendChild(row);
      }
    }

    renderRelationships() {
      if (!this.dom.relationships) return;
      this.dom.relationships.innerHTML = "";
      const entries = Object.entries(this.state.relationships || {});
      if (entries.length === 0) {
        const span = document.createElement("span");
        span.className = "empty-inventory";
        span.textContent = "No contacts.";
        this.dom.relationships.appendChild(span);
      } else {
        for (const [name, score] of entries) {
          const item = document.createElement("div");
          item.className = "relationship-item";
          const n = document.createElement("span");
          n.className = "relationship-name";
          n.textContent = name;
          const status = document.createElement("span");
          status.className = "relationship-status";
          status.textContent = score;
          if (score >= 20) status.classList.add("relationship-trust-positive");
          else if (score <= -20) status.classList.add("relationship-trust-negative");
          else status.classList.add("relationship-trust-neutral");
          item.appendChild(n);
          item.appendChild(status);
          this.dom.relationships.appendChild(item);
        }
      }
    }

    renderDebug() {
      if (this.dom.flagDisplay) {
        this.dom.flagDisplay.innerHTML = "";
        for (const flag of Object.keys(this.state.flags)) {
          const node = document.createElement("div");
          node.className = "flag-item";
          node.textContent = flag;
          this.dom.flagDisplay.appendChild(node);
        }
      }
      if (this.dom.decisionTree) {
        this.dom.decisionTree.innerHTML = "";
        for (const trace of this.state.decisionTrace.slice(-10)) {
          const node = document.createElement("div");
          node.className = "decision-item";
          node.textContent = `${trace.scene} → ${trace.choice}`;
          this.dom.decisionTree.appendChild(node);
        }
      }
      if (this.dom.stateHash) {
        this.dom.stateHash.textContent = JSON.stringify(this.state).length;
      }
      if (this.dom.worldTime) {
        this.dom.worldTime.textContent = `Day ${Math.floor(this.state.time / 24) + 1}, Hour ${this.state.time % 24}`;
      }
    }

    render() {
      this.renderScene(this.state.sceneId);
      this.renderStats();
      this.renderInventory();
      this.renderCharacter();
      this.renderPersona();
      this.renderRelationships();
      this.renderDebug();
    }
  }

  window.ConsequenceGame = ConsequenceGame;
  window.STORY_DATABASE = window.STORY_DATABASE || {};
  
  Object.assign(window.STORY_DATABASE, {
 "intro": {
  "id": "intro",
  "text": "Day 1 of the outbreak. Your apartment building has held—barely. Infected fill the streets below like a living sea. The government is gone. Radio is just static and screams. You hear hammering on your door. Through the peephole: Alex, from 3B, who used to fix everyone's fuse boxes. Their hands are covered in blood. Behind them, shadows move in the stairwell. Infected. Climbing. This moment defines everything.",
  "choices": [
   {
    "id": "i_peek",
    "text": "Study them through the peephole carefully",
    "goTo": "peek_study",
    "effects": {
     "stats": {
      "stress": -1
     },
     "persona": {
      "chill": 1
     },
     "pushEvent": "You watch. Looking for infection signs."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "i_open",
    "text": "Open immediately—Alex needs help NOW",
    "goTo": "saved_trust",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "nice": 2
     },
     "pushEvent": "No time. Alex needs you."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "i_demand",
    "text": "Demand proof they're not infected",
    "goTo": "saved_trust",
    "effects": {
     "persona": {
      "rude": 1
     },
     "relationships": {
      "Alex": -2
     },
     "pushEvent": "'SHOW YOUR ARMS!' you shout."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "i_ignore",
    "text": "Ignore. Survival means hard choices.",
    "goTo": "intro",
    "effects": {
     "stats": {
      "morality": -5,
      "stress": -3
     },
     "persona": {
      "psycho": 1
     },
     "flagsSet": [
      "ignored_alex"
     ],
     "pushEvent": "Step away. Don't care."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "intro"
  ]
 },
 "peek_study": {
  "id": "peek_study",
  "text": "Through fisheye: Alex's eyes bloodshot from crying, not infection. Pupils normal. No fever. Blood on hands but skin underneath clean—you see their pulse. Not infected. Terrified. Behind them: movement. Infected climbing. 30 seconds. Alex pounds. 'I KNOW YOU'RE THERE!' Voice cracks. You have info. What now?",
  "choices": [
   {
    "id": "pk_trust",
    "text": "Trust assessment—open",
    "goTo": "saved_trust",
    "effects": {
     "stats": {
      "stress": -2
     },
     "persona": {
      "nice": 2,
      "chill": 1
     },
     "relationships": {
      "Alex": 6
     },
     "flagsSet": [
      "alex_alive",
      "trust_assess"
     ],
     "pushEvent": "Trust eyes. Lock clicks."
    },
    "tags": [
     "chill"
    ],
    "popupText": "Observation saved you both."
   },
   {
    "id": "pk_verify",
    "text": "Open but verify verbally",
    "goTo": "saved_trust",
    "effects": {
     "persona": {
      "rude": 1
     },
     "relationships": {
      "Alex": 3
     },
     "flagsSet": [
      "alex_alive",
      "verified"
     ],
     "pushEvent": "Crack open. 'What happened?'"
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "pk_test",
    "text": "Wait—test if they survive alone",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": -2
     },
     "persona": {
      "psycho": 1
     },
     "flagsSet": [
      "tested_solo"
     ],
     "pushEvent": "Watch. Testing strength."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "pk_abandon",
    "text": "Too risky—walk away",
    "goTo": "intro",
    "effects": {
     "stats": {
      "morality": -6,
      "stress": -4
     },
     "persona": {
      "psycho": 2
     },
     "flagsSet": [
      "alex_dead_watched"
     ],
     "pushEvent": "Step back. Hear scream. Then silence."
    },
    "tags": [
     "psycho"
    ],
    "popupText": "You watched them die."
   }
  ],
  "tags": [
   "peek"
  ]
 },
 "saved_trust": {
  "id": "saved_trust",
  "text": "Door yanks open. Alex inside. SLAM shut. Infected slam door—holds by inches. Both collapse, heaving. Alex: raw gratitude. 'You didn't hesitate.' Voice breaks. 'How'd you know I was clean?' Your answer shapes this.",
  "choices": [
   {
    "id": "tr_instinct",
    "text": "Trusted my instincts",
    "goTo": "alex_deep_trust",
    "effects": {
     "stats": {
      "stress": -2
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 5
     },
     "flagsSet": [
      "trust_instinct"
     ],
     "pushEvent": "'Gut said okay.' Alex's eyes water."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "tr_science",
    "text": "Observed carefully. Science.",
    "goTo": "alex_deep_trust",
    "effects": {
     "persona": {
      "chill": 2
     },
     "relationships": {
      "Alex": 4
     },
     "flagsSet": [
      "trust_science"
     ],
     "pushEvent": "'Pupils. Skin. Pulse. No infection.' Alex nods."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "tr_lucky",
    "text": "Didn't. You got lucky.",
    "goTo": "alex_deep_trust",
    "effects": {
     "stats": {
      "stress": 1
     },
     "relationships": {
      "Alex": 2
     },
     "flagsSet": [
      "lucky_save"
     ],
     "pushEvent": "'Didn't know. Could've been infected.' Alex processes: not trust. Luck."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "tr_debt",
    "text": "You owe me now.",
    "goTo": "alex_deep_trust",
    "effects": {
     "persona": {
      "psycho": 1,
      "rude": 1
     },
     "relationships": {
      "Alex": -2
     },
     "flagsSet": [
      "debt_save"
     ],
     "pushEvent": "'You owe me.' Alex's face hardens."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "trust"
  ]
 },
 "alex_deep_trust": {
  "id": "alex_deep_trust",
  "text": "Alex sits, hands shaking. After a minute: 'My brother Marcus... turned an hour ago. Basement. Looking for water. Started coughing blood. Screaming. Eyes went black. Wasn't Marcus. Wore his face.' Hollow voice. 'I ran. Left him. Heard him following. Not him. Just... it.' Looks at you. 'Does that make me a coward?'",
  "choices": [
   {
    "id": "ad_survivor",
    "text": "Makes you a survivor",
    "goTo": "alex_bond_deep",
    "effects": {
     "stats": {
      "morality": 2,
      "stress": -2
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 5
     },
     "flagsSet": [
      "survivor_bond"
     ],
     "pushEvent": "'You survived. That's what matters.' Alex's shoulders relax."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "ad_purpose",
    "text": "What Marcus would want",
    "goTo": "alex_bond_deep",
    "effects": {
     "stats": {
      "stress": -3
     },
     "persona": {
      "nice": 2,
      "chill": 1
     },
     "relationships": {
      "Alex": 6
     },
     "flagsSet": [
      "purpose_bond"
     ],
     "pushEvent": "'Marcus would want you alive.' Alex nods, tears falling."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "ad_hard",
    "text": "No. But don't let it happen again.",
    "goTo": "alex_bond_deep",
    "effects": {
     "stats": {
      "morality": -1
     },
     "persona": {
      "rude": 1
     },
     "relationships": {
      "Alex": 3
     },
     "flagsSet": [
      "hard_bond"
     ],
     "pushEvent": "'Don't run next time.' Alex looks away."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "ad_lever",
    "text": "Prove you're not a coward",
    "goTo": "alex_bond_deep",
    "effects": {
     "persona": {
      "psycho": 2,
      "rude": 1
     },
     "relationships": {
      "Alex": 1
     },
     "flagsSet": [
      "guilt_lever"
     ],
     "pushEvent": "'Prove it.' Alex's face darkens."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "timeDelta": 1
 },
 "alex_bond_deep": {
  "id": "alex_bond_deep",
  "text": "Next hour: you and Alex sit. Share food. Alex tells about Marcus—real Marcus. How he taught electrical work. Argued about superheroes surviving apocalypse. You share losses. Walls tremble. Infected below. But not alone. Alex quiet: 'Don't know if we'll make it. Glad I'm not alone.' Pause. 'You're the only person I trust in this city. Weird?'",
  "choices": [
   {
    "id": "ab_family",
    "text": "I trust you too",
    "goTo": "alex_sworn_family",
    "effects": {
     "stats": {
      "stress": -3,
      "morality": 3
     },
     "persona": {
      "nice": 3
     },
     "relationships": {
      "Alex": 8
     },
     "flagsSet": [
      "family_bond"
     ],
     "pushEvent": "'I trust you too.' Alex smiles for the first time."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "ab_partners",
    "text": "Partners—watch backs",
    "goTo": "alex_sworn_family",
    "effects": {
     "stats": {
      "stress": -2
     },
     "persona": {
      "nice": 2,
      "chill": 1
     },
     "relationships": {
      "Alex": 6
     },
     "flagsSet": [
      "partner_bond"
     ],
     "pushEvent": "'Partners.' Alex nods firmly."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "ab_cautious",
    "text": "Survive first",
    "goTo": "alex_sworn_family",
    "effects": {
     "stats": {
      "stress": 1
     },
     "relationships": {
      "Alex": 4
     },
     "flagsSet": [
      "cautious_bond"
     ],
     "pushEvent": "'Survive first.' Alex's smile fades."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "ab_professional",
    "text": "Keep it professional",
    "goTo": "alex_sworn_family",
    "effects": {
     "persona": {
      "psycho": 1
     },
     "relationships": {
      "Alex": 0
     },
     "flagsSet": [
      "professional_bond"
     ],
     "pushEvent": "'Professional only.' Alex looks hurt."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "timeDelta": 1
 },
 "alex_sworn_family": {
  "id": "alex_sworn_family",
  "text": "You and Alex make a pact. On Marcus's memory: no one left behind. Alex sleeps with head on your shoulder. Safe. When they wake, they hand you something—Marcus's knife. 'He'd want you to have it. You're protecting me. Protect yourself too.' Well-made. Sharp. Symbol of trust. Accept?",
  "choices": [
   {
    "id": "as_accept",
    "text": "Accept knife and responsibility",
    "goTo": "act1_family_hub",
    "effects": {
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 5
     },
     "flagsSet": [
      "family_knife"
     ],
     "pushEvent": "'I'll protect us both.' Alex's eyes shine."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "as_refuse",
    "text": "Refuse—keep Marcus's knife",
    "goTo": "act1_family_hub",
    "effects": {
     "persona": {
      "chill": 1
     },
     "relationships": {
      "Alex": -1
     },
     "flagsSet": [
      "refused_knife"
     ],
     "pushEvent": "'Keep it.' Alex looks disappointed."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "as_tool",
    "text": "Accept as tool only",
    "goTo": "act1_family_hub",
    "effects": {
     "persona": {
      "rude": 1
     },
     "relationships": {
      "Alex": -2
     },
     "flagsSet": [
      "tool_knife"
     ],
     "pushEvent": "'Just a tool.' Alex's face falls."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "timeDelta": 1
 },
 "act1_family_hub": {
  "id": "act1_family_hub",
  "text": "Day 2 dawns. You and Alex have survived the night. The building creaks with infected below. Alex has been checking the radio—static mostly, but occasional voices. 'There's a group downtown. They're broadcasting from the old courthouse. Says they have supplies, medical care.' Alex looks hopeful. 'Should we try to reach them?'",
  "choices": [
   {
    "id": "ah_yes",
    "text": "Yes—safety in numbers",
    "goTo": "journey_downtown",
    "effects": {
     "stats": {
      "stress": -1
     },
     "persona": {
      "nice": 1
     },
     "relationships": {
      "Alex": 2
     },
     "flagsSet": [
      "group_decision"
     ],
     "pushEvent": "'Safety in numbers.' Alex nods eagerly."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "ah_no",
    "text": "No—stay here, safer",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": 1
     },
     "persona": {
      "chill": 1
     },
     "relationships": {
      "Alex": -1
     },
     "flagsSet": [
      "stay_decision"
     ],
     "pushEvent": "'Safer here.' Alex looks uncertain."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "ah_scout",
    "text": "Scout first, decide later",
    "goTo": "journey_downtown",
    "effects": {
     "persona": {
      "chill": 2
     },
     "relationships": {
      "Alex": 1
     },
     "flagsSet": [
      "scout_decision"
     ],
     "pushEvent": "'Scout first.' Alex nods approvingly."
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "timeDelta": 1
 },
 "journey_downtown": {
  "id": "journey_downtown",
  "text": "The journey is harrowing. Infected everywhere. You and Alex move through alleys, over rooftops. Alex is terrified but determined. 'We're almost there,' they whisper. But as you approach the courthouse, you see something wrong. The building is surrounded by infected. Too many. 'They're not broadcasting anymore,' Alex realizes. 'They're dead.'",
  "choices": [
   {
    "id": "jd_turn_back",
    "text": "Turn back—too dangerous",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "chill": 1
     },
     "relationships": {
      "Alex": 1
     },
     "flagsSet": [
      "turned_back"
     ],
     "pushEvent": "'Too dangerous.' Alex nods, disappointed."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "jd_sneak",
    "text": "Sneak in—maybe survivors",
    "goTo": "sneak_courthouse",
    "effects": {
     "stats": {
      "stress": 3,
      "health": -5
     },
     "persona": {
      "nice": 1
     },
     "relationships": {
      "Alex": 2
     },
     "flagsSet": [
      "sneaked_in"
     ],
     "pushEvent": "'Maybe survivors.' Alex follows bravely."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "jd_distract",
    "text": "Create distraction—draw them away",
    "goTo": "sneak_courthouse",
    "effects": {
     "stats": {
      "stress": 4,
      "stamina": -3
     },
     "persona": {
      "protector": 2
     },
     "relationships": {
      "Alex": 3
     },
     "flagsSet": [
      "distracted_them"
     ],
     "pushEvent": "'I'll draw them away.' Alex looks worried."
    },
    "tags": [
     "protector"
    ]
   }
  ],
  "timeDelta": 2
 },
 "sneak_courthouse": {
  "id": "sneak_courthouse",
  "text": "You and Alex slip through a side entrance. Inside: carnage. Bodies everywhere. But then—a sound. Someone alive. You find them: Sarah, a nurse, hiding in the basement. 'They came at night. We thought we were safe. They're getting smarter.' She's injured but alive. 'I have medical supplies. Can you help me get out?'",
  "choices": [
   {
    "id": "sc_help",
    "text": "Help her escape",
    "goTo": "help_sarah",
    "effects": {
     "stats": {
      "stress": 2,
      "health": -3
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 2,
      "Sarah": 5
     },
     "flagsSet": [
      "helped_sarah"
     ],
     "pushEvent": "'We'll help you.' Sarah's eyes fill with tears."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "sc_supplies",
    "text": "Take supplies, leave her",
    "goTo": "intro",
    "effects": {
     "stats": {
      "morality": -3
     },
     "persona": {
      "psycho": 1
     },
     "relationships": {
      "Alex": -2
     },
     "flagsSet": [
      "abandoned_sarah"
     ],
     "pushEvent": "'Just the supplies.' Alex looks horrified."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "sc_negotiate",
    "text": "Negotiate—supplies for help",
    "goTo": "help_sarah",
    "effects": {
     "persona": {
      "fixer": 1
     },
     "relationships": {
      "Alex": 0,
      "Sarah": 2
     },
     "flagsSet": [
      "negotiated_sarah"
     ],
     "pushEvent": "'Supplies for help.' Sarah nods reluctantly."
    },
    "tags": [
     "fixer"
    ]
   }
  ],
  "timeDelta": 1
 },
 "help_sarah": {
  "id": "help_sarah",
  "text": "You help Sarah escape. It's dangerous—infected everywhere. But you make it out. Sarah is grateful. 'I have a safe house. Medical supplies. Food. You saved my life.' She looks at you and Alex. 'You're welcome to stay. We can help each other.' Alex looks hopeful. 'Should we go?'",
  "choices": [
   {
    "id": "hs_yes",
    "text": "Yes—accept her offer",
    "goTo": "safe_house",
    "effects": {
     "stats": {
      "stress": -2,
      "health": 2
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 3,
      "Sarah": 5
     },
     "flagsSet": [
      "accepted_safe_house"
     ],
     "pushEvent": "'We'll come.' Sarah smiles warmly."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "hs_no",
    "text": "No—stay independent",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": 1
     },
     "persona": {
      "chill": 1
     },
     "relationships": {
      "Alex": -1,
      "Sarah": 1
     },
     "flagsSet": [
      "stayed_independent"
     ],
     "pushEvent": "'We'll stay independent.' Sarah looks disappointed."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "hs_visit",
    "text": "Visit but don't stay",
    "goTo": "safe_house",
    "effects": {
     "persona": {
      "chill": 1
     },
     "relationships": {
      "Alex": 1,
      "Sarah": 3
     },
     "flagsSet": [
      "visited_safe_house"
     ],
     "pushEvent": "'We'll visit.' Sarah nods understandingly."
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "timeDelta": 1
 },
 "safe_house": {
  "id": "safe_house",
  "text": "Sarah's safe house is a converted warehouse. Clean, organized, well-stocked. 'I've been preparing for this for months,' she explains. 'Medical training, supplies, security.' She shows you around. 'You're safe here. We can help each other survive.' Alex looks around in wonder. 'This is amazing.'",
  "choices": [
   {
    "id": "sh_grateful",
    "text": "Express gratitude",
    "goTo": "safe_house_settled",
    "effects": {
     "stats": {
      "stress": -3
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 2,
      "Sarah": 3
     },
     "flagsSet": [
      "grateful_settled"
     ],
     "pushEvent": "'Thank you.' Sarah smiles warmly."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "sh_contribute",
    "text": "Offer to contribute",
    "goTo": "safe_house_settled",
    "effects": {
     "persona": {
      "nice": 1,
      "chill": 1
     },
     "relationships": {
      "Alex": 1,
      "Sarah": 2
     },
     "flagsSet": [
      "contribute_settled"
     ],
     "pushEvent": "'We'll contribute.' Sarah nods approvingly."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "sh_suspicious",
    "text": "Stay cautious",
    "goTo": "safe_house_settled",
    "effects": {
     "stats": {
      "stress": 1
     },
     "persona": {
      "chill": 1
     },
     "relationships": {
      "Alex": 0,
      "Sarah": 0
     },
     "flagsSet": [
      "cautious_settled"
     ],
     "pushEvent": "'We'll be careful.' Sarah looks understanding."
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "timeDelta": 1
 },
 "safe_house_settled": {
  "id": "safe_house_settled",
  "text": "You've been at the safe house for a week. It's been good—food, medical care, safety. But today, Sarah comes to you with news. 'The infected are getting smarter. They're organizing. We need to prepare.' She looks serious. 'I have a plan. But it's dangerous. We need to strike first, before they get stronger.'",
  "choices": [
   {
    "id": "ss_yes",
    "text": "Yes—strike first",
    "goTo": "strike_plan",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "protector": 2
     },
     "relationships": {
      "Alex": 2,
      "Sarah": 3
     },
     "flagsSet": [
      "strike_decision"
     ],
     "pushEvent": "'We'll strike first.' Sarah nods grimly."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "ss_no",
    "text": "No—stay defensive",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": -1
     },
     "persona": {
      "chill": 2
     },
     "relationships": {
      "Alex": 1,
      "Sarah": 1
     },
     "flagsSet": [
      "defensive_decision"
     ],
     "pushEvent": "'Stay defensive.' Sarah looks disappointed."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "ss_negotiate",
    "text": "Negotiate—find another way",
    "goTo": "strike_plan",
    "effects": {
     "persona": {
      "fixer": 2
     },
     "relationships": {
      "Alex": 1,
      "Sarah": 2
     },
     "flagsSet": [
      "negotiate_decision"
     ],
     "pushEvent": "'Find another way.' Sarah looks thoughtful."
    },
    "tags": [
     "fixer"
    ]
   }
  ],
  "timeDelta": 1
 },
 "strike_plan": {
  "id": "strike_plan",
  "text": "Sarah's plan is bold. 'We'll hit their nest. The old hospital. They're gathering there.' She shows you maps, weapons. 'It's dangerous. But if we don't act now, they'll overwhelm us.' Alex looks scared but determined. 'I'm with you.' Sarah nods. 'We go tonight.'",
  "choices": [
   {
    "id": "sp_ready",
    "text": "I'm ready",
    "goTo": "night_strike",
    "effects": {
     "stats": {
      "stress": 3
     },
     "persona": {
      "protector": 2
     },
     "relationships": {
      "Alex": 2,
      "Sarah": 2
     },
     "flagsSet": [
      "ready_strike"
     ],
     "pushEvent": "'I'm ready.' Sarah nods approvingly."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "sp_scared",
    "text": "I'm scared but I'll go",
    "goTo": "night_strike",
    "effects": {
     "stats": {
      "stress": 4
     },
     "persona": {
      "nice": 1
     },
     "relationships": {
      "Alex": 3,
      "Sarah": 2
     },
     "flagsSet": [
      "scared_strike"
     ],
     "pushEvent": "'I'm scared but I'll go.' Alex looks proud."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "sp_refuse",
    "text": "I can't do this",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": -2
     },
     "persona": {
      "chill": 1
     },
     "relationships": {
      "Alex": -2,
      "Sarah": -1
     },
     "flagsSet": [
      "refused_strike"
     ],
     "pushEvent": "'I can't do this.' Sarah looks disappointed."
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "timeDelta": 1
 },
 "night_strike": {
  "id": "night_strike",
  "text": "The night is dark. You, Alex, and Sarah approach the hospital. It's crawling with infected. 'Remember the plan,' Sarah whispers. 'Stick together. Watch each other's backs.' Alex nods nervously. 'I trust you both.' The building looms ahead. Time to act.",
  "choices": [
   {
    "id": "ns_stick_plan",
    "text": "Stick to the plan",
    "goTo": "strike_success",
    "effects": {
     "stats": {
      "stress": 2,
      "health": -5
     },
     "persona": {
      "protector": 2
     },
     "relationships": {
      "Alex": 3,
      "Sarah": 2
     },
     "flagsSet": [
      "stuck_plan"
     ],
     "pushEvent": "'Stick to the plan.' Sarah nods approvingly."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "ns_improvise",
    "text": "Improvise as needed",
    "goTo": "strike_success",
    "effects": {
     "stats": {
      "stress": 3,
      "health": -3
     },
     "persona": {
      "chill": 1
     },
     "relationships": {
      "Alex": 1,
      "Sarah": 1
     },
     "flagsSet": [
      "improvised_strike"
     ],
     "pushEvent": "'Improvise as needed.' Sarah looks uncertain."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "ns_protect_alex",
    "text": "Protect Alex above all",
    "goTo": "strike_success",
    "effects": {
     "stats": {
      "stress": 4,
      "health": -7
     },
     "persona": {
      "nice": 2,
      "protector": 1
     },
     "relationships": {
      "Alex": 5,
      "Sarah": 1
     },
     "flagsSet": [
      "protected_alex"
     ],
     "pushEvent": "'Protect Alex above all.' Alex looks touched."
    },
    "tags": [
     "nice"
    ]
   }
  ],
  "timeDelta": 1
 },
 "strike_success": {
  "id": "strike_success",
  "text": "The strike is successful. You've destroyed the nest, killed dozens of infected. But the cost is high. Sarah is injured, Alex is shaken. 'We did it,' Sarah says weakly. 'But they'll be back. We need to prepare for the next wave.' Alex looks at you. 'We're stronger together.'",
  "choices": [
   {
    "id": "ss_stronger",
    "text": "We're stronger together",
    "goTo": "epilogue_strong",
    "effects": {
     "stats": {
      "stress": -2,
      "morality": 3
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 3,
      "Sarah": 2
     },
     "flagsSet": [
      "stronger_together"
     ],
     "pushEvent": "'We're stronger together.' Alex smiles."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "ss_prepare",
    "text": "Prepare for the next wave",
    "goTo": "epilogue_strong",
    "effects": {
     "persona": {
      "protector": 2
     },
     "relationships": {
      "Alex": 2,
      "Sarah": 3
     },
     "flagsSet": [
      "prepare_next"
     ],
     "pushEvent": "'Prepare for the next wave.' Sarah nods."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "ss_rest",
    "text": "Rest and recover",
    "goTo": "epilogue_strong",
    "effects": {
     "stats": {
      "stress": -3,
      "health": 2
     },
     "persona": {
      "chill": 1
     },
     "relationships": {
      "Alex": 1,
      "Sarah": 1
     },
     "flagsSet": [
      "rest_recover"
     ],
     "pushEvent": "'Rest and recover.' Sarah nods gratefully."
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "timeDelta": 1
 },
 "epilogue_strong": {
  "id": "epilogue_strong",
  "text": "Days pass. You, Alex, and Sarah have become a family. The infected are still out there, but you're ready. You've built something together—trust, love, hope. 'We'll survive this,' Alex says. 'Together.' Sarah nods. 'We'll survive anything.' You look at them both. 'We will.'",
  "choices": [
   {
    "id": "es_family",
    "text": "We're family now",
    "goTo": "ending_family",
    "effects": {
     "stats": {
      "stress": -5,
      "morality": 5
     },
     "persona": {
      "nice": 3
     },
     "relationships": {
      "Alex": 5,
      "Sarah": 5
     },
     "flagsSet": [
      "family_ending"
     ],
     "pushEvent": "'We're family now.' Alex and Sarah smile."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "es_survive",
    "text": "We'll survive together",
    "goTo": "ending_survive",
    "effects": {
     "stats": {
      "stress": -3
     },
     "persona": {
      "protector": 2
     },
     "relationships": {
      "Alex": 3,
      "Sarah": 3
     },
     "flagsSet": [
      "survive_ending"
     ],
     "pushEvent": "'We'll survive together.' Both nod."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "es_hope",
    "text": "There's always hope",
    "goTo": "ending_hope",
    "effects": {
     "stats": {
      "stress": -4,
      "morality": 3
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 4,
      "Sarah": 4
     },
     "flagsSet": [
      "hope_ending"
     ],
     "pushEvent": "'There's always hope.' Alex and Sarah smile."
    },
    "tags": [
     "nice"
    ]
   }
  ],
  "timeDelta": 1
 },
 "ending_family": {
  "id": "ending_family",
  "text": "The world is still dangerous. The infected still roam. But you've found something precious—family. Alex, Sarah, and you have built a bond that nothing can break. You'll face whatever comes together. You'll survive. You'll love. You'll hope. Because that's what families do.",
  "choices": [
   {
    "id": "ef_continue",
    "text": "Continue the story",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": -2
     },
     "pushEvent": "The story continues..."
    },
    "tags": [
     "continue"
    ]
   }
  ],
  "tags": [
   "ending"
  ]
 },
 "ending_survive": {
  "id": "ending_survive",
  "text": "Survival is hard. The infected are everywhere. But you've learned something important—you're stronger together. Alex, Sarah, and you have become a team. You'll face whatever comes next. You'll survive. Because that's what survivors do.",
  "choices": [
   {
    "id": "es_continue",
    "text": "Continue the story",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": -1
     },
     "pushEvent": "The story continues..."
    },
    "tags": [
     "continue"
    ]
   }
  ],
  "tags": [
   "ending"
  ]
 },
 "ending_hope": {
  "id": "ending_hope",
  "text": "Hope is fragile. The world is dark. But you've found light in each other. Alex, Sarah, and you have discovered that even in the darkest times, there's always hope. You'll carry that hope forward. You'll survive. You'll love. You'll hope. Because hope is what makes us human.",
  "choices": [
   {
    "id": "eh_continue",
    "text": "Continue the story",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": -3,
      "morality": 2
     },
     "pushEvent": "The story continues..."
    },
    "tags": [
     "continue"
    ]
   }
  ],
  "tags": [
   "ending"
  ]
 }
});

})();

document.addEventListener("DOMContentLoaded", () => {
  if (typeof window.ConsequenceGame === "function" && window.STORY_DATABASE) {
    window.game = new window.ConsequenceGame();
  }
});