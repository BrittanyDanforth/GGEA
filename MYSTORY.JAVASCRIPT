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

  function deepClone(obj) { return JSON.parse(JSON.stringify(obj)); }
  function clamp(value) { return Math.max(MIN_STAT, Math.min(MAX_STAT, value)); }
  
  function setMutexFlag(state, group, flag) {
    if (!MUTEX[group]) return;
    for (const f of MUTEX[group]) { if (f !== flag) delete state.flags[f]; }
    state.flags[flag] = true;
  }

  function getChoiceTarget(choice) {
    if (!choice) return null;
    const destination = choice.goTo ?? choice.next;
    return typeof destination === "string" && destination.length ? destination : null;
  }

  function ensureStats(state) {
    for (const key of Object.keys(state.stats)) { state.stats[key] = clamp(state.stats[key]); }
  }

  function resolveSchedule(state) {
    const next = [];
    for (const entry of state.schedule) {
      const updated = { ...entry, steps: entry.steps - 1 };
      if (updated.steps <= 0) { applyEffects(state, updated.apply || {}); }
      else { next.push(updated); }
    }
    state.schedule = next;
  }

  function applyCost(state, cost) {
    if (!cost) return;
    if (typeof cost.time === "number") { state.time = Math.max(0, state.time + cost.time); }
    if (cost.stats) {
      for (const [k, v] of Object.entries(cost.stats)) { state.stats[k] = clamp((state.stats[k] || 0) - v); }
    }
  }

  function applyEffects(state, effects) {
    if (!effects) return;
    if (typeof effects.time === "number") { state.time = Math.max(0, state.time + effects.time); }
    if (effects.stats) {
      for (const [k, v] of Object.entries(effects.stats)) { state.stats[k] = clamp((state.stats[k] || 0) + v); }
    }
    if (effects.persona) {
      for (const [k, v] of Object.entries(effects.persona)) { state.persona[k] = clamp((state.persona[k] || 0) + v); }
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
        const current = state.relationships[name] || 0;
        state.relationships[name] = clamp(current + delta);
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

  function meetsRequirement(state, req) {
    if (!req) return true;
    if (Array.isArray(req.items)) {
      for (const item of req.items) { if (!state.inventory.includes(item)) return false; }
    }
    if (Array.isArray(req.flags)) {
      for (const flag of req.flags) { if (!state.flags[flag]) return false; }
    }
    if (Array.isArray(req.flagsNone)) {
      for (const flag of req.flagsNone) { if (state.flags[flag]) return false; }
    }
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
      this.load();
      this.renderScene(this.state.sceneId);
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
      this.save();
      this.renderScene(this.state.sceneId);
    }

    load() {
      try {
        const raw = localStorage.getItem(STORAGE_KEY);
        if (!raw) return;
        const parsed = JSON.parse(raw);
        this.state = { ...deepClone(DEFAULT_STATE), ...parsed };
        this.eventLog = parsed.__eventLog || [];
        this.journal = parsed.__journal || [];
      } catch (err) { console.warn("Load failed", err); }
    }

    save() {
      try {
        const data = { ...this.state, __eventLog: this.eventLog, __journal: this.journal };
        localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
      } catch (err) { console.warn("Save failed", err); }
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
      const scene = window.STORY_DATABASE[this.state.sceneId];
      if (!scene || !choice) return;
      if (!meetsRequirement(this.state, choice.req)) return;

      const nextState = deepClone(this.state);
      applyCost(nextState, choice.cost);
      applyEffects(nextState, choice.effects);
      resolveSchedule(nextState);
      ensureStats(nextState);

      if (choice.effects && choice.effects.pushEvent) {
        this.pushEvent(choice.effects.pushEvent, "consequence");
      }

      const goTo = getChoiceTarget(choice) ?? nextState.sceneId;
      nextState.sceneId = goTo;
      nextState.decisionTrace = [...nextState.decisionTrace, `${scene.id}::${choice.id}`];

      this.state = nextState;
      this.save();
      this.renderScene(goTo);
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
        this.displayStory(`ERROR: Missing scene: ${sceneId}`);
        console.error("Missing scene:", sceneId);
        return;
      }

      this.state.sceneId = sceneId;
      resolveSchedule(this.state);
      ensureStats(this.state);

      this.displayStory(scene.text, scene);
      this.displayChoices(scene);
      this.renderStats();
      this.renderInventory();
      this.renderCharacter();
      this.renderPersona();
      this.renderRelationships();
      this.renderDebug();
      this.updateTime();
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

    updateStats() { this.renderStats(); }

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
      if (this.dom.relationshipCount) {
        this.dom.relationshipCount.textContent = `${entries.length} contacts`;
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
          node.className = "decision-node";
          node.textContent = trace;
          this.dom.decisionTree.appendChild(node);
        }
      }
      if (this.dom.stateHash) {
        const raw = JSON.stringify(this.state);
        let hash = 0;
        for (let i = 0; i < raw.length; i++) {
          hash = (hash << 5) - hash + raw.charCodeAt(i);
          hash |= 0;
        }
        this.dom.stateHash.textContent = `#${(hash >>> 0).toString(16)}`;
      }
    }

    pushEvent(text, type = "") {
      this.eventLog.unshift({ text, type, time: this.state.time });
      if (this.eventLog.length > 20) this.eventLog.pop();
      this.renderEvents();
    }

    renderEvents() {
      if (!this.dom.eventLog) return;
      this.dom.eventLog.innerHTML = "";
      for (const entry of this.eventLog) {
        const node = document.createElement("div");
        node.className = "event-log-entry";
        if (entry.type) node.classList.add(entry.type);
        node.textContent = `[T+${entry.time}h] ${entry.text}`;
        this.dom.eventLog.appendChild(node);
      }
    }

    updateTime() {
      if (this.dom.worldTime) { this.dom.worldTime.textContent = `T+${this.state.time}h`; }
      if (this.dom.dayhour) {
        const day = Math.floor(this.state.time / 24);
        const hour = this.state.time % 24;
        this.dom.dayhour.textContent = `Day ${day} · ${hour.toString().padStart(2, "0")}:00`;
      }
      if (this.dom.traumaBar) {
        const stress = this.state.stats.stress || 0;
        const pct = Math.min(100, Math.max(0, stress));
        this.dom.traumaBar.style.width = `${pct}%`;
      }
      if (this.dom.traumaWarning) {
        const stress = this.state.stats.stress || 0;
        this.dom.traumaWarning.className = "trauma-warning";
        if (stress < 30) {
          this.dom.traumaWarning.classList.add("moderate");
          this.dom.traumaWarning.textContent = "Stable";
        } else if (stress < 60) {
          this.dom.traumaWarning.classList.add("high");
          this.dom.traumaWarning.textContent = "Strained";
        } else {
          this.dom.traumaWarning.classList.add("critical");
          this.dom.traumaWarning.textContent = "Critical";
        }
      }
    }

    renderJournal() {
      if (!this.dom.journal) return;
      this.dom.journal.innerHTML = "";
      for (const entry of this.journal) {
        const node = document.createElement("div");
        node.className = "journal-item";
        const title = document.createElement("div");
        title.className = "journal-title";
        title.textContent = entry.headline;
        node.appendChild(title);
        this.dom.journal.appendChild(node);
      }
      if (this.dom.objectiveCount) {
        this.dom.objectiveCount.textContent = `${this.journal.length} objectives`;
      }
    }
  }

  window.ConsequenceGame = ConsequenceGame;
  window.STORY_DATABASE = window.STORY_DATABASE || {};
  
  Object.assign(window.STORY_DATABASE, {
 "intro": {
  "id": "intro",
  "text": "Day 1 of the outbreak. Your apartment building has held\u2014barely. Infected fill the streets below like a living sea. The government is gone. Radio is just static and screams. You hear hammering on your door. Through the peephole: Alex, from 3B, who used to fix everyone's fuse boxes. Their hands are covered in blood. Behind them, shadows move in the stairwell. Infected. Climbing. This moment defines everything.",
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
    "text": "Open immediately\u2014Alex needs help NOW",
    "goTo": "open_immediate",
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
    "goTo": "demand_proof",
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
    "goTo": "ignore_knock",
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
  "text": "Through fisheye: Alex's eyes bloodshot from crying, not infection. Pupils normal. No fever. Blood on hands but skin underneath clean\u2014you see their pulse. Not infected. Terrified. Behind them: movement. Infected climbing. 30 seconds. Alex pounds. 'I KNOW YOU'RE THERE!' Voice cracks. You have info. What now?",
  "choices": [
   {
    "id": "pk_trust",
    "text": "Trust assessment\u2014open",
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
    "goTo": "saved_verify",
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
    "text": "Wait\u2014test if they survive alone",
    "goTo": "alex_test_solo",
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
    "text": "Too risky\u2014walk away",
    "goTo": "alex_dies_watched",
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
  "text": "Door yanks open. Alex inside. SLAM shut. Infected slam door\u2014holds by inches. Both collapse, heaving. Alex: raw gratitude. 'You didn't hesitate.' Voice breaks. 'How'd you know I was clean?' Your answer shapes this.",
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
    "goTo": "alex_respect",
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
    "goTo": "alex_uncertain",
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
    "goTo": "alex_debt",
    "effects": {
     "persona": {
      "psycho": 1,
      "rude": 1
     },
     "relationships": {
      "Alex": -2
     },
     "flagsSet": [
      "alex_debt"
     ],
     "pushEvent": "'You owe me. Remember.' Gratitude sours."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "saved_trust"
  ]
 },
 "alex_deep_trust": {
  "id": "alex_deep_trust",
  "text": "Alex sits, hands shaking. After a minute: 'My brother Marcus... turned an hour ago. Basement. Looking for water. Started coughing blood. Screaming. Eyes went black. Wasn't Marcus. Wore his face.' Hollow voice. 'I ran. Left him. Heard him following. Not him. Just... it.' Looks at you. 'Does that make me a coward?'",
  "choices": [
   {
    "id": "dt_survivor",
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
      "affirm_survive"
     ],
     "pushEvent": "'Survived. Not cowardice. Strength.' Alex exhales."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "dt_marcus_want",
    "text": "What Marcus would want",
    "goTo": "alex_bond_purpose",
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
      "honor_marcus"
     ],
     "pushEvent": "'Marcus died so you live. Honor that.' Purpose returns."
    },
    "tags": [
     "nice"
    ],
    "popupText": "Gave reason to fight."
   },
   {
    "id": "dt_learn",
    "text": "No. But don't let it happen again.",
    "goTo": "alex_bond_hard",
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
      "pragmatic"
     ],
     "pushEvent": "'Learn. Next time, act.' Grimly nods."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "dt_guilt_weapon",
    "text": "Prove you're not a coward",
    "goTo": "alex_guilt_lever",
    "effects": {
     "persona": {
      "psycho": 2,
      "rude": 1
     },
     "relationships": {
      "Alex": 1
     },
     "flagsSet": [
      "guilt_weapon"
     ],
     "pushEvent": "'Don't know. Are you? We'll see.' Plant doubt."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "deep_trust"
  ],
  "timeDelta": 1
 },
 "alex_bond_deep": {
  "id": "alex_bond_deep",
  "text": "Next hour: you and Alex sit. Share food. Alex tells about Marcus\u2014real Marcus. How he taught electrical work. Argued about superheroes surviving apocalypse. You share losses. Walls tremble. Infected below. But not alone. Alex quiet: 'Don't know if we'll make it. Glad I'm not alone.' Pause. 'You're the only person I trust in this city. Weird?'",
  "choices": [
   {
    "id": "bd_trust_back",
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
      "best_friend",
      "sworn"
     ],
     "pushEvent": "'Not weird. Family now. Chosen kind.' Grips hand."
    },
    "tags": [
     "nice"
    ],
    "popupText": "Unbreakable bond formed."
   },
   {
    "id": "bd_partners",
    "text": "Partners\u2014watch backs",
    "goTo": "alex_partners",
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
      "partners"
     ],
     "pushEvent": "'Partners. Equals. Decide together.' Serious nod."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "bd_survive_first",
    "text": "Survive first",
    "goTo": "alex_cautious",
    "effects": {
     "stats": {
      "stress": 1
     },
     "relationships": {
      "Alex": 4
     },
     "flagsSet": [
      "slow_bond"
     ],
     "pushEvent": "'One day at a time.' Disappointed but nods."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "bd_professional",
    "text": "Keep it professional",
    "goTo": "alex_professional",
    "effects": {
     "persona": {
      "psycho": 1
     },
     "relationships": {
      "Alex": 0
     },
     "flagsSet": [
      "professional"
     ],
     "pushEvent": "'Help survive. That's it.' Face closes off."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "bond_deep"
  ],
  "timeDelta": 1
 },
 "alex_sworn_family": {
  "id": "alex_sworn_family",
  "text": "You and Alex make a pact. On Marcus's memory: no one left behind. Alex sleeps with head on your shoulder. Safe. When they wake, they hand you something\u2014Marcus's knife. 'He'd want you to have it. You're protecting me. Protect yourself too.' Well-made. Sharp. Symbol of trust. Accept?",
  "choices": [
   {
    "id": "fam_accept",
    "text": "Accept knife and responsibility",
    "goTo": "act1_family_hub",
    "effects": {
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 5
     },
     "inventoryAdd": [
      "marcus_knife"
     ],
     "flagsSet": [
      "accepted_knife"
     ],
     "pushEvent": "Take knife. Weight of responsibility. Won't let them down."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fam_refuse",
    "text": "Refuse\u2014keep Marcus's knife",
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
     "pushEvent": "'Keep it. Marcus was yours. Don't need symbols.' Hurt but pockets it."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fam_tool",
    "text": "Accept as tool only",
    "goTo": "act1_family_hub",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": [
      "marcus_knife"
     ],
     "flagsSet": [
      "knife_tool"
     ],
     "pushEvent": "'Good blade. Use it well.' Expected more emotion."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "sworn_family"
  ]
 },
 "open_immediate": {
  "id": "open_immediate",
  "text": "No thinking. Just action. You rip the door open. Alex stumbles forward. Behind them: infected, close. You grab Alex's collar, yank them inside with brutal force. Infected hand swipes\u2014misses by inch. You slam door. Lock. Infected slam outside. Door holds. Both on floor, hearts pounding. Alex looks at you. 'You could've been killed opening that fast.' true. You didn't even look. Just trusted. Just acted.",
  "choices": [
   {
    "id": "op_instinct",
    "text": "I trusted my instinct about you",
    "goTo": "alex_grateful_instant",
    "effects": {
     "stats": {
      "stress": -3
     },
     "persona": {
      "nice": 3
     },
     "relationships": {
      "Alex": 8
     },
     "flagsSet": [
      "alex_alive",
      "instant_save"
     ],
     "pushEvent": "'Instinct said save you. That's enough.' Raw gratitude."
    },
    "tags": [
     "nice"
    ],
    "popupText": "Dramatic rescue forges strong bond."
   },
   {
    "id": "op_no_time",
    "text": "There was no time to think",
    "goTo": "alex_grateful_lucky",
    "effects": {
     "persona": {
      "chill": 1
     },
     "relationships": {
      "Alex": 5
     },
     "flagsSet": [
      "alex_alive",
      "lucky_save"
     ],
     "pushEvent": "'No time. Just acted.' Alex: 'We got lucky.' Both alive."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "op_stupid",
    "text": "That was stupid. Don't make me regret it.",
    "goTo": "alex_grateful_conditional",
    "effects": {
     "persona": {
      "rude": 1
     },
     "relationships": {
      "Alex": 2
     },
     "flagsSet": [
      "alex_alive",
      "conditional"
     ],
     "pushEvent": "'Stupid move. Don't make me regret it.' Gratitude mixed with wariness."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "op_test",
    "text": "I was testing my own courage",
    "goTo": "alex_grateful_selfish",
    "effects": {
     "persona": {
      "psycho": 1
     },
     "relationships": {
      "Alex": 1
     },
     "flagsSet": [
      "alex_alive",
      "selfish_save"
     ],
     "pushEvent": "'Testing myself. You were convenient.' Alex's face: confusion, hurt."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "open_immediate"
  ]
 },
 "demand_proof": {
  "id": "demand_proof",
  "text": "'SHOW YOUR ARMS! Lift your shirt! PROVE YOU'RE CLEAN!' you shout through door. Alex, shocked: 'What? It's me! It's Alex!' But they comply. Frantically roll sleeves. Show arms. Neck. Pull shirt up\u2014stomach clean. 'SEE? I'm not infected! Please!' Voice desperate. Infected sounds getting closer. You have proof. But your demand hurt. Trust damaged before it began.",
  "choices": [
   {
    "id": "dm_satisfied",
    "text": "Satisfied\u2014open door now",
    "goTo": "saved_after_demand",
    "effects": {
     "persona": {
      "rude": 1
     },
     "relationships": {
      "Alex": 3
     },
     "flagsSet": [
      "alex_alive",
      "demanded_proof"
     ],
     "pushEvent": "'Okay. Come in. Quick.' Yank inside. Alex: relief mixed with hurt."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "dm_still_risky",
    "text": "Still risky\u2014pass supplies through gap",
    "goTo": "supplies_through_door",
    "effects": {
     "stats": {
      "morality": -2
     },
     "relationships": {
      "Alex": 1
     },
     "inventoryRemove": [
      "old_radio"
     ],
     "flagsSet": [
      "alex_alive",
      "supplies_only"
     ],
     "pushEvent": "'Here. Supplies. Good luck.' Alex: 'You're not letting me in?' Face falls."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "dm_not_enough",
    "text": "Not enough\u2014keep door closed",
    "goTo": "alex_dies_after_proof",
    "effects": {
     "stats": {
      "morality": -7,
      "stress": -3
     },
     "persona": {
      "psycho": 2
     },
     "flagsSet": [
      "alex_dead_cruel"
     ],
     "pushEvent": "'Not good enough.' Close peephole. Hear them beg. Then scream. Then nothing."
    },
    "tags": [
     "psycho"
    ],
    "popupText": "Cruelty, not caution."
   },
   {
    "id": "dm_apologize",
    "text": "Apologize while opening",
    "goTo": "saved_after_apology",
    "effects": {
     "persona": {
      "nice": 1,
      "chill": 1
     },
     "relationships": {
      "Alex": 4
     },
     "flagsSet": [
      "alex_alive",
      "apologized"
     ],
     "pushEvent": "'Sorry. Had to be sure.' Open. Pull in. 'I understand,' Alex says. Do they?"
    },
    "tags": [
     "nice"
    ]
   }
  ],
  "tags": [
   "demand"
  ]
 },
 "ignore_knock": {
  "id": "ignore_knock",
  "text": "You ignore hammering. Secure apartment. Check weapons. Count supplies. Knocking: desperate. Frantic. 'PLEASE! IT'S ALEX! THEY'RE COMING!' Pounding. Begging. Then... different sounds. Wet. Tearing. Screaming that cuts off mid-breath. Then silence. You peek now. Hall empty except blood trail. Drag marks. Alex is gone. Dead. Because you chose safety.",
  "choices": [
   {
    "id": "ig_loot",
    "text": "Crack door\u2014loot what's left",
    "goTo": "loot_alex_body",
    "effects": {
     "stats": {
      "morality": -6
     },
     "persona": {
      "psycho": 3
     },
     "inventoryAdd": [
      "alex_keys",
      "alex_medkit"
     ],
     "flagsSet": [
      "alex_dead",
      "looted"
     ],
     "pushEvent": "Search remains. Keys. Medkit. Pragmatic."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "ig_guilt",
    "text": "Sit with what you've done",
    "goTo": "guilt_crushing",
    "effects": {
     "stats": {
      "stress": 6,
      "morality": 2
     },
     "persona": {
      "nice": 2
     },
     "flagsSet": [
      "alex_dead",
      "guilt"
     ],
     "pushEvent": "Heard every second of death. Haunts."
    },
    "tags": [
     "nice"
    ],
    "popupText": "Guilt will drive you."
   },
   {
    "id": "ig_rational",
    "text": "Rationalize: statistically correct",
    "goTo": "cold_logic",
    "effects": {
     "stats": {
      "morality": -3,
      "stress": -3
     },
     "persona": {
      "chill": 2
     },
     "flagsSet": [
      "alex_dead",
      "rationalized"
     ],
     "pushEvent": "Math: opening door = infection risk. Correct choice."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "ig_nothing",
    "text": "Feel nothing. Already numb.",
    "goTo": "numb_path",
    "effects": {
     "persona": {
      "psycho": 1
     },
     "flagsSet": [
      "alex_dead",
      "numb"
     ],
     "pushEvent": "Screams = noise. Feel nothing."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "ignore"
  ]
 },
 "alex_grateful_instant": {
  "id": "alex_grateful_instant",
  "text": "Alex catches their breath. 'You risked your life. Didn't even check if I was infected first. Just... saved me.' They look at you differently now. 'Why?' The question hangs. In this world, altruism is rare. Suspicious. But also precious. How you answer defines if they see you as hero, fool, or something between.",
  "choices": [
   {
    "id": "gi_because_right",
    "text": "Because it was the right thing",
    "goTo": "alex_sees_hero",
    "effects": {
     "stats": {
      "morality": 3
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 6
     },
     "flagsSet": [
      "seen_as_hero"
     ],
     "pushEvent": "'Right thing to do.' Alex: 'You're a good person. Rare.'"
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "gi_because_you",
    "text": "Because it's you, Alex",
    "goTo": "alex_sees_personal",
    "effects": {
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 7
     },
     "flagsSet": [
      "personal_save"
     ],
     "pushEvent": "'It's you. Couldn't let you die.' Alex: connection beyond words."
    },
    "tags": [
     "nice"
    ],
    "popupText": "Personal bond forming."
   },
   {
    "id": "gi_instinct",
    "text": "Instinct. Didn't overthink.",
    "goTo": "alex_sees_reactive",
    "effects": {
     "persona": {
      "chill": 1
     },
     "relationships": {
      "Alex": 4
     },
     "flagsSet": [
      "instinctive_save"
     ],
     "pushEvent": "'Instinct. Overthinking kills.' Alex nods. Trusts instinct."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "gi_needed_ally",
    "text": "Needed an ally. You're useful.",
    "goTo": "alex_sees_transactional",
    "effects": {
     "persona": {
      "rude": 2
     },
     "relationships": {
      "Alex": 0
     },
     "flagsSet": [
      "transactional_save"
     ],
     "pushEvent": "'Need allies. You know electrical.' Gratitude cools."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "grateful_instant"
  ]
 },
 "alex_sees_hero": {
  "id": "alex_sees_hero",
  "text": "Alex looks at you with something approaching awe. 'You're one of the good ones. My brother used to say people would show their true selves when the world ended. Some turn monster. Some turn hero.' They pause. 'You're a hero.' The label feels heavy. Expectations come with it. Alex will expect you to keep being good. Always. Can you carry that?",
  "choices": [
   {
    "id": "hero_yes",
    "text": "I'll try to be what you need",
    "goTo": "path_hero_alex_dependent",
    "effects": {
     "stats": {
      "stress": 3
     },
     "persona": {
      "nice": 3
     },
     "relationships": {
      "Alex": 8
     },
     "flagsSet": [
      "hero_role",
      "alex_dependent"
     ],
     "pushEvent": "'I'll try.' Heavy responsibility. Alex looks relieved. They'll lean on you."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "hero_just_person",
    "text": "I'm just a person. Not a hero.",
    "goTo": "path_hero_grounded",
    "effects": {
     "persona": {
      "chill": 2
     },
     "relationships": {
      "Alex": 6
     },
     "flagsSet": [
      "grounded_hero"
     ],
     "pushEvent": "'Just person. Made a choice.' Alex: 'That's what heroes say.'"
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "hero_dont_label",
    "text": "Don't put labels on me",
    "goTo": "path_hero_rejects_label",
    "effects": {
     "persona": {
      "rude": 1
     },
     "relationships": {
      "Alex": 3
     },
     "flagsSet": [
      "label_rejected"
     ],
     "pushEvent": "'Don't label me. I'm not your hero.' Alex flinches."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "hero_use_worship",
    "text": "Let them worship you\u2014useful",
    "goTo": "path_hero_manipulative",
    "effects": {
     "persona": {
      "psycho": 2,
      "rude": 1
     },
     "relationships": {
      "Alex": 5
     },
     "flagsSet": [
      "hero_manipulation",
      "alex_worships"
     ],
     "pushEvent": "You don't correct them. Let them think you're heroic. Useful."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "hero_path"
  ]
 },
 "guilt_crushing": {
  "id": "guilt_crushing",
  "text": "You heard every second. Every plea. Every scream. The wet sounds. The silence after. You sit on your floor for an hour. Can't move. Can't think. Alex's voice echoes: 'PLEASE!' You could have saved them. Chose not to. The guilt is physical. Crushing. It will drive every choice from now on. You vow: never again. NEVER. AGAIN. The next person who needs help, you save them. Even if it kills you.",
  "choices": [
   {
    "id": "gu_vow_save",
    "text": "Vow to save everyone from now on",
    "goTo": "path_guilt_savior",
    "effects": {
     "stats": {
      "morality": 5,
      "stress": 4
     },
     "persona": {
      "nice": 4
     },
     "flagsSet": [
      "vow_save_all",
      "guilt_driven"
     ],
     "pushEvent": "NEVER AGAIN. Save everyone or die trying."
    },
    "tags": [
     "nice"
    ],
    "popupText": "Guilt transforms into purpose."
   },
   {
    "id": "gu_find_family",
    "text": "Find Alex's family\u2014make amends",
    "goTo": "path_guilt_quest",
    "effects": {
     "stats": {
      "stress": 5
     },
     "persona": {
      "nice": 2
     },
     "flagsSet": [
      "find_marcus_family",
      "redemption_quest"
     ],
     "pushEvent": "Find Marcus's family. Tell them. Make it right somehow."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "gu_punish_self",
    "text": "You deserve punishment",
    "goTo": "path_guilt_self_harm",
    "effects": {
     "stats": {
      "health": -5,
      "stress": 3
     },
     "flagsSet": [
      "self_punishment"
     ],
     "pushEvent": "Carve mark on arm. One for Alex. Physical reminder."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "gu_channel_anger",
    "text": "Channel guilt into rage at infected",
    "goTo": "path_guilt_rage",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "psycho": 2,
      "nice": 1
     },
     "flagsSet": [
      "guilt_rage"
     ],
     "pushEvent": "Guilt becomes rage. Infected took Alex. They ALL pay."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "guilt_path"
  ]
 },
 "alex_dies_watched": {
  "id": "alex_dies_watched",
  "text": "Through peephole: Alex sees you watching. Knows you're there. Knows you're choosing not to open. Their face: confusion. Hurt. Betrayal. Then terror as infected hands grab them. They scream your name. Not anger. Plea. Hope. You watch them pulled down. Torn apart. Their eyes stay on the peephole until the end. Until their eyes go dark. You step back. The silence is deafening. You just watched your neighbor die. By choice.",
  "choices": [
   {
    "id": "dw_nothing",
    "text": "Feel nothing. Survival.",
    "goTo": "path_watcher_cold",
    "effects": {
     "stats": {
      "morality": -8,
      "stress": -5
     },
     "persona": {
      "psycho": 3
     },
     "flagsSet": [
      "alex_dead",
      "watched_coldly"
     ],
     "pushEvent": "Survival. Nothing else matters. No guilt. No fear. Nothing."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "dw_study",
    "text": "Study how infected kill\u2014useful data",
    "goTo": "path_watcher_study",
    "effects": {
     "persona": {
      "psycho": 2,
      "chill": 1
     },
     "inventoryAdd": [
      "infection_notes"
     ],
     "flagsSet": [
      "alex_dead",
      "studied_death"
     ],
     "pushEvent": "Note: infected go for throat first. Useful."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "dw_delayed_guilt",
    "text": "Numbness now. Guilt later.",
    "goTo": "path_watcher_delayed",
    "effects": {
     "stats": {
      "stress": -2
     },
     "flagsSet": [
      "alex_dead",
      "delayed_guilt"
     ],
     "pushEvent": "Feel nothing now. It'll hit later.",
     "schedule": [
      {
       "steps": 3,
       "apply": {
        "stats": {
         "stress": 8
        },
        "pushEvent": "Alex's face haunts you."
       }
      }
     ]
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "dw_justified",
    "text": "They might've been infected anyway",
    "goTo": "path_watcher_justified",
    "effects": {
     "stats": {
      "morality": -4
     },
     "persona": {
      "chill": 1
     },
     "flagsSet": [
      "alex_dead",
      "justified"
     ],
     "pushEvent": "Couldn't risk it. Statistically sound. You're fine with this."
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "tags": [
   "watched_die"
  ]
 },
 "path_hero_alex_dependent": {
  "id": "path_hero_alex_dependent",
  "text": "Day 48. Alex follows you everywhere. Literally. Kitchen? Alex is there. Checking the barricade? Alex is behind you. They're terrified to be alone. Last night they had a nightmare about Marcus and woke up screaming. You calmed them down. It took an hour. This morning they apologize: 'Sorry. I know I'm... clingy. I just... you're all I have left.' They look at you with those eyes. Expecting you to fix this. To fix them. Hero-worship is a burden.",
  "choices": [
   {
    "id": "hd_patience",
    "text": "Show patience\u2014they need time to heal",
    "goTo": "alex_healing_bond",
    "effects": {
     "time": 1,
     "stats": {
      "stress": 2
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 4
     },
     "pushEvent": "'Take all the time you need. I'm not going anywhere.' They grip your hand."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "hd_boundaries",
    "text": "Set gentle boundaries\u2014they need independence",
    "goTo": "alex_learns_independence",
    "effects": {
     "persona": {
      "chill": 2
     },
     "relationships": {
      "Alex": 2
     },
     "flagsSet": [
      "healthy_boundaries"
     ],
     "pushEvent": "'I'm here. But you need to learn to stand on your own too. For survival.' Alex nods, trying to be brave."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "hd_use_dependence",
    "text": "Use their dependence\u2014makes them obedient",
    "goTo": "alex_dependent_tool",
    "effects": {
     "persona": {
      "psycho": 2,
      "rude": 1
     },
     "relationships": {
      "Alex": 5
     },
     "flagsSet": [
      "alex_dependent",
      "leverage_dependence"
     ],
     "pushEvent": "You don't discourage the clinginess. Dependent people are controllable people."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "hd_harsh",
    "text": "Be harsh\u2014they need to toughen up NOW",
    "goTo": "alex_traumatized_harsh",
    "effects": {
     "stats": {
      "stress": 4
     },
     "persona": {
      "psycho": 1
     },
     "relationships": {
      "Alex": -3
     },
     "flagsSet": [
      "harsh_treatment"
     ],
     "pushEvent": "'Toughen up. The world doesn't care about your feelings.' Alex flinches. Something in them hardens. Or breaks."
    },
    "tags": [
     "psycho"
    ],
    "popupText": "Harshness leaves scars."
   }
  ],
  "tags": [
   "hero_dependent",
   "act1"
  ]
 },
 "path_guilt_savior": {
  "id": "path_guilt_savior",
  "text": "Day 48. You barely slept. Every time you close your eyes: Alex's screams. You've decided: you're going to save everyone you can. Starting now. The building has 8 apartments left with survivors. Old Mrs. Chen on 4. The Martinez family with their kid on 3. The teenage girl and her little brother on 2. A couple on 5. Some won't make it. Some are too weak, too sick, too slow. But you vowed to try. Where do you start?",
  "choices": [
   {
    "id": "gs_strongest",
    "text": "Start with the strongest\u2014build a group",
    "goTo": "guilt_savior_team_build",
    "effects": {
     "time": 2,
     "stats": {
      "stress": 2
     },
     "persona": {
      "chill": 1,
      "nice": 2
     },
     "flagsSet": [
      "team_building"
     ],
     "pushEvent": "Martinez family first. Father is strong. Can help with others."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "gs_weakest",
    "text": "Start with Mrs. Chen\u2014she can't wait",
    "goTo": "guilt_savior_mrs_chen",
    "effects": {
     "time": 2,
     "stats": {
      "stress": 4,
      "stamina": -2
     },
     "persona": {
      "nice": 3
     },
     "flagsSet": [
      "saved_chen"
     ],
     "pushEvent": "Fourth floor. Stairs are hell. Mrs. Chen can barely walk. But you carry her."
    },
    "tags": [
     "nice"
    ],
    "popupText": "The hardest choice is the right one."
   },
   {
    "id": "gs_children",
    "text": "Children first. Always.",
    "goTo": "guilt_savior_kids_first",
    "effects": {
     "time": 2,
     "stats": {
      "stress": 3
     },
     "persona": {
      "nice": 3
     },
     "flagsSet": [
      "children_priority"
     ],
     "pushEvent": "Third floor and second. Kids first. They're terrified but you're here now."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "gs_systematic",
    "text": "Systematic: floor by floor, no favorites",
    "goTo": "guilt_savior_systematic",
    "effects": {
     "time": 3,
     "stats": {
      "stress": 3,
      "stamina": -1
     },
     "persona": {
      "chill": 2,
      "nice": 1
     },
     "flagsSet": [
      "systematic_rescue"
     ],
     "pushEvent": "Floor by floor. No emotion. Just efficient rescue. Math of redemption."
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "tags": [
   "guilt_savior",
   "act1"
  ]
 },
 "guilt_savior_mrs_chen": {
  "id": "guilt_savior_mrs_chen",
  "text": "Fourth floor. Mrs. Chen's door is barricaded. She doesn't trust anyone. 'Who's there?' Her voice shakes. You: 'It's me. From 6B. There's an evac at the stadium. I'm getting people out.' Silence. Then: 'Why should I trust you?' Fair question. The building has seen betrayals. People stealing food. Worse. She's heard the stories. Why SHOULD she trust you?",
  "choices": [
   {
    "id": "chen_truth",
    "text": "Because I failed someone yesterday. Not failing you.",
    "goTo": "chen_trusts_confession",
    "effects": {
     "stats": {
      "stress": -2
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Mrs_Chen": 6
     },
     "flagsSet": [
      "confessed_to_chen"
     ],
     "pushEvent": "You tell her about Alex. The guilt. She opens the door. 'You're trying to make it right. I see that.'"
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "chen_pragmatic",
    "text": "Because we both die if you stay here",
    "goTo": "chen_trusts_logic",
    "effects": {
     "persona": {
      "chill": 2
     },
     "relationships": {
      "Mrs_Chen": 3
     },
     "flagsSet": [
      "chen_logic"
     ],
     "pushEvent": "'Building won't hold. Infected are breaching. Come or stay and die.' She thinks. Opens door."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "chen_break_door",
    "text": "I'm not asking. I'm saving you.",
    "goTo": "chen_forced_save",
    "effects": {
     "stats": {
      "stamina": -2
     },
     "persona": {
      "psycho": 1,
      "nice": 2
     },
     "relationships": {
      "Mrs_Chen": -2
     },
     "flagsSet": [
      "chen_forced"
     ],
     "pushEvent": "You break the lock. She screams. You: 'Saving you whether you like it or not.'"
    },
    "tags": [
     "psycho"
    ],
    "popupText": "Good intentions, bad methods."
   },
   {
    "id": "chen_leave",
    "text": "Okay. Your choice. Good luck.",
    "goTo": "chen_left_behind",
    "effects": {
     "stats": {
      "morality": -2,
      "stress": 2
     },
     "flagsSet": [
      "chen_abandoned"
     ],
     "pushEvent": "She won't come. You move on. Hear her scream later. Two failures now."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "guilt_chen",
   "act1"
  ]
 },
 "cold_logic": {
  "id": "cold_logic",
  "text": "Alex is dead. Math: Opening door = infection exposure risk. Keeping door shut = 0% exposure. Correct choice. You run the numbers again. And again. The math is sound. Survival is statistics. Emotion is inefficiency. You're fine with this. You tell yourself you're fine with this. Are you?",
  "choices": [
   {
    "id": "cl_commit",
    "text": "Commit to pure logic\u2014emotion is weakness",
    "goTo": "path_cold_embrace",
    "effects": {
     "stats": {
      "morality": -5,
      "stress": -4
     },
     "persona": {
      "psycho": 2,
      "chill": 2
     },
     "flagsSet": [
      "pure_logic",
      "no_emotion"
     ],
     "pushEvent": "Emotion = weakness. You choose logic. Every time. Always."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "cl_track",
    "text": "Track survival statistics obsessively",
    "goTo": "path_cold_statistics",
    "effects": {
     "persona": {
      "chill": 3
     },
     "inventoryAdd": [
      "survival_journal"
     ],
     "flagsSet": [
      "stat_tracking"
     ],
     "pushEvent": "Start journal. Every choice. Every outcome. Every variable. Control through data."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "cl_doubt_creeps",
    "text": "The logic is sound but doubt creeps in",
    "goTo": "path_cold_doubt",
    "effects": {
     "stats": {
      "stress": 3
     },
     "flagsSet": [
      "logic_doubt"
     ],
     "pushEvent": "Math is right. So why does it feel wrong? Why do you keep seeing Alex's face?"
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "cl_test_others",
    "text": "Test the math on the next person who knocks",
    "goTo": "path_cold_testing",
    "effects": {
     "persona": {
      "psycho": 3
     },
     "flagsSet": [
      "testing_logic"
     ],
     "pushEvent": "Next person who needs help: another data point. Will you save them? Or does the math say no again?"
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "cold_logic"
  ]
 },
 "loot_alex_body": {
  "id": "loot_alex_body",
  "text": "You crack the door. Hallway reeks. Blood. Decay. Alex's body in pieces near the stairs. You step out. Check for infected\u2014clear for now. Search the body with clinical efficiency. Keys (building master set). Medical kit (untouched). Radio (encrypted channels). Wallet (photo of Marcus and Alex, smiling, before). You pocket everything. Except the photo. You leave that. Not sure why.",
  "choices": [
   {
    "id": "lo_take_photo",
    "text": "Take the photo too. Might be useful.",
    "goTo": "path_loot_complete",
    "effects": {
     "stats": {
      "morality": -7
     },
     "persona": {
      "psycho": 2,
      "rude": 1
     },
     "inventoryAdd": [
      "alex_photo"
     ],
     "flagsSet": [
      "looted_all",
      "took_photo"
     ],
     "pushEvent": "Everything has value. Even memories of the dead."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "lo_leave_photo",
    "text": "Leave the photo. Some things are sacred.",
    "goTo": "path_loot_selective",
    "effects": {
     "stats": {
      "morality": -4
     },
     "persona": {
      "chill": 1
     },
     "flagsSet": [
      "left_photo"
     ],
     "pushEvent": "Leave photo on their chest. Small mercy. Doesn't change that you looted their corpse."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "lo_whisper_sorry",
    "text": "Whisper an apology to the corpse",
    "goTo": "path_loot_conflicted",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "nice": 1
     },
     "relationships": {
      "Alex": 2
     },
     "flagsSet": [
      "looted_sorry",
      "conflicted"
     ],
     "pushEvent": "'Sorry, Alex. Survival.' Wonder if they'd understand. Probably not."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "lo_no_looking_back",
    "text": "Don't look back. Forward only.",
    "goTo": "path_loot_pragmatic",
    "effects": {
     "stats": {
      "stress": -2
     },
     "persona": {
      "psycho": 1,
      "rude": 2
     },
     "flagsSet": [
      "pragmatic_loot"
     ],
     "pushEvent": "Pockets full. Move forward. Don't look at the body again. Just meat now."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "loot"
  ]
 },
 "alex_healing_bond": {
  "id": "alex_healing_bond",
  "text": "You give Alex space to heal. Days pass. Slowly, they start sleeping through the night. The nightmares don't stop but they scream less. One morning you wake to find Alex has made you breakfast\u2014canned beans heated over a makeshift stove. They smile shyly. 'Wanted to do something. For you. For being patient.' It's the first time they've smiled since Marcus. Small progress. But real. The building's radio crackles: convoy at the stadium. Evac possible. But it's a dangerous trek.",
  "choices": [
   {
    "id": "hb_together",
    "text": "We go together. You and me.",
    "goTo": "hero_convoy_together",
    "effects": {
     "time": 1,
     "stats": {
      "stress": 2
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 5
     },
     "flagsSet": [
      "convoy_together"
     ],
     "pushEvent": "'Together. Like we said.' Alex nods. Determined now. Stronger."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "hb_prep_alex",
    "text": "Let me prep you. Teach you to survive.",
    "goTo": "hero_train_alex",
    "effects": {
     "time": 2,
     "persona": {
      "chill": 2
     },
     "relationships": {
      "Alex": 4
     },
     "flagsSet": [
      "training_alex"
     ],
     "pushEvent": "'I'll teach you. Weapons. Routes. Survival.' Training begins."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "hb_scout_first",
    "text": "I scout first. You stay safe here.",
    "goTo": "hero_scout_solo",
    "effects": {
     "time": 2,
     "stats": {
      "stress": 3,
      "stamina": -1
     },
     "persona": {
      "nice": 1
     },
     "relationships": {
      "Alex": 3
     },
     "flagsSet": [
      "scout_solo"
     ],
     "pushEvent": "'Stay here. I check the route.' Alex: 'But we're a team...' You: 'I'm keeping you safe.'"
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "hb_alex_prove",
    "text": "You need to prove you can handle this",
    "goTo": "hero_alex_test",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "rude": 1
     },
     "relationships": {
      "Alex": 1
     },
     "flagsSet": [
      "alex_tested"
     ],
     "pushEvent": "'Prove you're ready. I can't carry you forever.' Alex's face hardens. 'Fine. I'll prove it.'"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "hero_healing",
   "act1"
  ]
 },
 "hero_convoy_together": {
  "id": "hero_convoy_together",
  "text": "You and Alex prepare. Backpacks with essentials. Weapons\u2014you have a crowbar, Alex takes a pipe. Check the stairwell: infected on floors 1 and 2. You'll need to go through them or find another route. Alex looks at you. 'What's the plan?' They trust your judgment completely. That trust is both strength and vulnerability. If you get them killed, that's on you.",
  "choices": [
   {
    "id": "ct_fight_through",
    "text": "We fight through. Fast and brutal.",
    "goTo": "convoy_fight_path",
    "effects": {
     "time": 1,
     "stats": {
      "stamina": -2,
      "stress": 3
     },
     "persona": {
      "psycho": 1,
      "nice": 1
     },
     "flagsSet": [
      "fight_through"
     ],
     "pushEvent": "'We go through them. Stay close to me.' Alex grips the pipe tight."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "ct_fire_escape",
    "text": "Fire escape. Slower but safer.",
    "goTo": "convoy_fire_escape",
    "effects": {
     "time": 2,
     "stats": {
      "stamina": -1
     },
     "persona": {
      "chill": 2
     },
     "flagsSet": [
      "fire_escape"
     ],
     "pushEvent": "'Outside route. Fire escape.' Alex: 'Smart. Let's do it.'"
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "ct_wait_thin",
    "text": "Wait for the horde to thin out",
    "goTo": "convoy_wait_thin",
    "effects": {
     "time": 3,
     "stats": {
      "stress": 1
     },
     "persona": {
      "chill": 1
     },
     "flagsSet": [
      "wait_strategy"
     ],
     "pushEvent": "'We wait. They'll move eventually.' Patience."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "ct_alex_decoy",
    "text": "You go first, Alex follows if clear",
    "goTo": "convoy_alex_second",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "rude": 1
     },
     "relationships": {
      "Alex": -1
     },
     "flagsSet": [
      "alex_second"
     ],
     "pushEvent": "'I go first. You follow ONLY if clear.' Alex: 'But...' You: 'That's the plan.'"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "hero_convoy",
   "act1"
  ]
 },
 "convoy_fight_path": {
  "id": "convoy_fight_path",
  "text": "Stairwell. Infected claw upward. You and Alex descend. First one: you swing crowbar. Skull cracks. Alex freezes. First time they've seen you kill. 'Come ON!' you shout. They shake off shock. Follow. Second floor landing: three infected. They turn as one. Alex's breathing goes ragged. This is real combat. Not practice. Can they handle it?",
  "choices": [
   {
    "id": "fp_protect",
    "text": "Shield Alex, take them all yourself",
    "goTo": "fight_hero_shield",
    "effects": {
     "time": 1,
     "stats": {
      "stamina": -3,
      "stress": 4
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 4
     },
     "flagsSet": [
      "shielded_alex"
     ],
     "pushEvent": "'STAY BACK!' You fight all three. Get bit? No. But close. Alex watches, horrified and grateful."
    },
    "tags": [
     "nice"
    ],
    "popupText": "You put yourself between Alex and death."
   },
   {
    "id": "fp_together",
    "text": "Fight side by side as team",
    "goTo": "fight_together",
    "effects": {
     "time": 1,
     "stats": {
      "stamina": -2,
      "stress": 3
     },
     "persona": {
      "nice": 1,
      "chill": 1
     },
     "relationships": {
      "Alex": 5
     },
     "flagsSet": [
      "fought_together"
     ],
     "pushEvent": "'Together! NOW!' You fight as unit. Alex hesitates but swings. Connects. Infected drops. Alex stares at what they did."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fp_alex_distract",
    "text": "Alex distracts, you strike",
    "goTo": "fight_tactical",
    "effects": {
     "time": 1,
     "stats": {
      "stamina": -1
     },
     "persona": {
      "chill": 2
     },
     "relationships": {
      "Alex": 2
     },
     "flagsSet": [
      "tactical_fight"
     ],
     "pushEvent": "'Make noise!' Alex shouts. Infected turn. You strike from behind. Efficient."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fp_alex_bait",
    "text": "Use Alex as bait",
    "goTo": "fight_alex_bait",
    "effects": {
     "stats": {
      "morality": -5
     },
     "persona": {
      "psycho": 3,
      "rude": 1
     },
     "relationships": {
      "Alex": -5
     },
     "flagsSet": [
      "alex_bait"
     ],
     "pushEvent": "Shove Alex forward. Infected swarm them. You run past. Alex screams your name. Betrayal cuts deep."
    },
    "tags": [
     "psycho"
    ],
    "popupText": "Alex will NEVER forget this."
   }
  ],
  "tags": [
   "fight_path",
   "act1"
  ]
 },
 "fight_hero_shield": {
  "id": "fight_hero_shield",
  "text": "You fight like a demon. Crowbar connects again. Again. AGAIN. Infected drop. You're covered in blood\u2014theirs, not yours. Check yourself: no bites. Alex behind you, untouched. Safe. They're shaking. You just saved their life violently. They saw you become a killer to protect them. 'You... you're terrifying,' they whisper. 'But you're MY terrifying.' Something shifts. They see you as both protector and weapon.",
  "choices": [
   {
    "id": "sh_reassure",
    "text": "I'm not the monster. THEY are.",
    "goTo": "alex_sees_necessary_violence",
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
      "violence_justified"
     ],
     "pushEvent": "'I'm not the monster. I'm what stands between you and monsters.' Alex nods slowly. Accepts this."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "sh_separate",
    "text": "I did what was needed. Don't romanticize it.",
    "goTo": "alex_sees_clinical_killer",
    "effects": {
     "persona": {
      "chill": 2
     },
     "relationships": {
      "Alex": 3
     },
     "flagsSet": [
      "clinical_violence"
     ],
     "pushEvent": "'Necessary. Nothing more.' Alex: 'Right. Necessary.' They look at you differently now. Useful. Dangerous."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "sh_enjoyed",
    "text": "Part of me enjoyed it.",
    "goTo": "alex_sees_darkness",
    "effects": {
     "stats": {
      "morality": -2
     },
     "persona": {
      "psycho": 2
     },
     "relationships": {
      "Alex": -1
     },
     "flagsSet": [
      "enjoyed_violence"
     ],
     "pushEvent": "'Won't lie. Part of me... liked it.' Alex takes a step back. Fear mixes with gratitude."
    },
    "tags": [
     "psycho"
    ],
    "popupText": "Honesty reveals darkness."
   },
   {
    "id": "sh_dont_discuss",
    "text": "Let's not talk about it.",
    "goTo": "alex_uncomfortable_silence",
    "effects": {
     "stats": {
      "stress": 2
     },
     "relationships": {
      "Alex": 2
     },
     "flagsSet": [
      "violence_not_discussed"
     ],
     "pushEvent": "'Don't want to talk about it.' Silence. Alex doesn't push. But questions linger."
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "tags": [
   "hero_shield",
   "act1"
  ]
 },
 "chen_trusts_confession": {
  "id": "chen_trusts_confession",
  "text": "Mrs. Chen opens the door. She's 73. Frail. Barely 90 pounds. Uses a cane. Looking at you with ancient eyes. 'You failed someone. You're trying to make it right. I see that.' She grips her cane. 'My husband didn't make it past day three. Lung infection took him before the plague did. I've been alone since.' She sizes you up. 'You're young. Strong. Why help an old woman? Truth.'",
  "choices": [
   {
    "id": "chen_because_right",
    "text": "Because it's the right thing to do",
    "goTo": "chen_accepts_moral",
    "effects": {
     "stats": {
      "morality": 3
     },
     "persona": {
      "nice": 3
     },
     "relationships": {
      "Mrs_Chen": 7
     },
     "flagsSet": [
      "chen_moral"
     ],
     "pushEvent": "'Because it's right.' She smiles. First smile in weeks. 'Good. World needs people like you.'"
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "chen_because_guilt",
    "text": "Because guilt is eating me alive",
    "goTo": "chen_accepts_honesty",
    "effects": {
     "stats": {
      "stress": -2
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Mrs_Chen": 6
     },
     "flagsSet": [
      "chen_honesty"
     ],
     "pushEvent": "Raw honesty. She nods. 'Guilt means you still have a soul. That's good.'"
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "chen_need_team",
    "text": "Need a team. You have skills.",
    "goTo": "chen_accepts_pragmatic",
    "effects": {
     "persona": {
      "chill": 2
     },
     "relationships": {
      "Mrs_Chen": 4
     },
     "flagsSet": [
      "chen_pragmatic"
     ],
     "pushEvent": "'You know the building. Electrical systems. Useful.' She chuckles. 'Practical. I like that.'"
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "chen_practice",
    "text": "Practice. For when someone I care about needs help.",
    "goTo": "chen_accepts_practice",
    "effects": {
     "persona": {
      "chill": 1,
      "nice": 1
     },
     "relationships": {
      "Mrs_Chen": 5
     },
     "flagsSet": [
      "chen_practice"
     ],
     "pushEvent": "'Practicing. For next time.' She studies you. 'Learning from failure. Wise.'"
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "tags": [
   "guilt_chen",
   "act1"
  ]
 },
 "chen_accepts_moral": {
  "id": "chen_accepts_moral",
  "text": "Mrs. Chen takes your arm. Together you start the journey. Fourth floor to street level. Each step is agony for her. Cane taps. She whispers: 'Tell me about the one you failed.' You tell her about Alex. The screams. The silence. She listens. Squeezes your arm. 'You can't save them all, child. But you can save me today. That counts.' Second floor landing: you hear infected below. Lots of them. Mrs. Chen can't run. Can barely walk. What now?",
  "choices": [
   {
    "id": "cm_carry",
    "text": "Carry her. No matter the cost.",
    "goTo": "chen_carried_hero",
    "effects": {
     "time": 2,
     "stats": {
      "stamina": -4,
      "stress": 5
     },
     "persona": {
      "nice": 3
     },
     "relationships": {
      "Mrs_Chen": 8
     },
     "flagsSet": [
      "carried_chen"
     ],
     "pushEvent": "Scoop her up. She gasps. You: 'Hold on.' Stairs fly past. Legs burn. Lungs scream. Infected behind. You don't stop."
    },
    "tags": [
     "nice"
    ],
    "popupText": "true heroism hurts."
   },
   {
    "id": "cm_distract",
    "text": "Distract infected while she sneaks past",
    "goTo": "chen_distraction_play",
    "effects": {
     "time": 2,
     "stats": {
      "stress": 4
     },
     "persona": {
      "chill": 2,
      "nice": 1
     },
     "flagsSet": [
      "distraction_chen"
     ],
     "pushEvent": "'I draw them. You sneak past. Wait for me at the door.' She: 'Too risky!' You: 'Only way.'"
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "cm_hide",
    "text": "Hide in apartment until they pass",
    "goTo": "chen_hide_together",
    "effects": {
     "time": 3,
     "stats": {
      "stress": 3
     },
     "persona": {
      "chill": 2
     },
     "flagsSet": [
      "hide_with_chen"
     ],
     "pushEvent": "'In here. Quiet.' Crack an apartment. Hide. Infected shuffle past. Takes forever. Works."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "cm_leave_chen",
    "text": "She's too slow. Leave her. Save yourself.",
    "goTo": "chen_abandoned_guilt_double",
    "effects": {
     "stats": {
      "morality": -8,
      "stress": 8
     },
     "relationships": {
      "Mrs_Chen": -10
     },
     "flagsSet": [
      "chen_abandoned",
      "double_guilt"
     ],
     "pushEvent": "'Can't do this. Sorry.' You run. Hear her scream. Alex AND Mrs. Chen. Two failures."
    },
    "tags": [
     "psycho"
    ],
    "popupText": "Guilt multiplies."
   }
  ],
  "tags": [
   "chen_moral",
   "act1"
  ]
 },
 "chen_carried_hero": {
  "id": "chen_carried_hero",
  "text": "You carry her down. Second floor. First floor. Your legs are jelly. Shoulders scream. Mrs. Chen weighs nothing but might as well be lead. Infected behind. Gaining. Ground floor. Door ahead. So close. Alex's voice in your head: why didn't you try this hard for me? Shut it out. Focus. DOOR. Kick it open. Sunlight. Outside. Infected RIGHT THERE. You run. Mrs. Chen in your arms. Don't look back. Stadium ahead. You made it. She made it. You collapse at the convoy checkpoint. Mrs. Chen looks at you: 'You're a hero. A real one.' The word still feels heavy.",
  "choices": [
   {
    "id": "cc_deflect_hero",
    "text": "I'm not a hero. Just trying.",
    "goTo": "chen_hero_humble",
    "effects": {
     "stats": {
      "stress": -3
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Mrs_Chen": 6
     },
     "flagsSet": [
      "humble_hero"
     ],
     "pushEvent": "'Not hero. Just trying to be better.' She pats your hand. 'That's what makes you one.'"
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "cc_marcus_honor",
    "text": "I'm honoring someone I failed",
    "goTo": "chen_hero_redemption",
    "effects": {
     "stats": {
      "stress": -2,
      "morality": 2
     },
     "persona": {
      "nice": 2
     },
     "flagsSet": [
      "marcus_honored"
     ],
     "pushEvent": "'For someone I couldn't save. This is for them.' She understands. Nods."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "cc_never_again",
    "text": "I said never again. I meant it.",
    "goTo": "chen_hero_vow_keeper",
    "effects": {
     "persona": {
      "nice": 3,
      "chill": 1
     },
     "relationships": {
      "Mrs_Chen": 7
     },
     "flagsSet": [
      "vow_kept"
     ],
     "pushEvent": "'Vowed never again. Keep vows.' She: 'Your word means something. Rare.'"
    },
    "tags": [
     "nice"
    ],
    "popupText": "You kept your word."
   },
   {
    "id": "cc_needed_prove",
    "text": "Needed to prove I could do it",
    "goTo": "chen_hero_self_proof",
    "effects": {
     "persona": {
      "chill": 1,
      "rude": 1
     },
     "relationships": {
      "Mrs_Chen": 4
     },
     "flagsSet": [
      "proved_self"
     ],
     "pushEvent": "'Needed to know if I could. Now I know.' She: 'Proving things to yourself. I understand.'"
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "tags": [
   "chen_carried",
   "act1"
  ]
 },
 "chen_hero_vow_keeper": {
  "id": "chen_hero_vow_keeper",
  "text": "At stadium convoy checkpoint, they're triaging. Mrs. Chen gets priority\u2014elderly, civilian, rescued. She's processed quickly. Before she boards the truck, she turns. Presses something into your hand. Her late husband's wedding ring. 'He was a good man. You remind me of him. Keep this. Remember: good men survive too. Not just the monsters.' The truck pulls away. She waves. You saved her. Fully. Completely. The guilt over Alex... doesn't disappear. But it weighs less.",
  "choices": [
   {
    "id": "vk_convoy_go",
    "text": "Board the convoy\u2014you earned escape",
    "goTo": "ending_road_warden",
    "effects": {
     "stats": {
      "stress": -5
     },
     "persona": {
      "nice": 2
     },
     "flagsSet": [
      "convoy_escape"
     ],
     "pushEvent": "You board. Earned this. City falls behind. You saved who you could."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "vk_stay_save_more",
    "text": "Stay. There are more to save.",
    "goTo": "hero_stays_saves_more",
    "effects": {
     "stats": {
      "stress": 5,
      "stamina": -2
     },
     "persona": {
      "nice": 4
     },
     "flagsSet": [
      "stays_to_save"
     ],
     "pushEvent": "'More people in the city. I'm staying.' Convoy leaves. You stay. More to save."
    },
    "tags": [
     "nice"
    ],
    "popupText": "true heroism means sacrifice."
   },
   {
    "id": "vk_return_building",
    "text": "Return to the building. Others need you.",
    "goTo": "hero_returns_building",
    "effects": {
     "time": 2,
     "stats": {
      "stamina": -1
     },
     "persona": {
      "nice": 3
     },
     "flagsSet": [
      "returns_building"
     ],
     "pushEvent": "Building. More survivors. Martinez family. The kids. You're going back."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "vk_rest_then_more",
    "text": "Rest briefly then save more",
    "goTo": "hero_rest_continue",
    "effects": {
     "time": 2,
     "stats": {
      "stamina": 2,
      "stress": -2
     },
     "flagsSet": [
      "rest_continue"
     ],
     "pushEvent": "Rest. Food. Water. Then back to it. Sustainable heroism."
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "tags": [
   "vow_keeper",
   "act1"
  ]
 },
 "hero_stays_saves_more": {
  "id": "hero_stays_saves_more",
  "text": "You watch the convoy leave. Mrs. Chen's face in the window. Then it's gone. You turn back to the city. The burning buildings. The infected masses. The screaming. Somewhere in there: survivors who need help. You head back in. Over the next hours you save: the Martinez family (father, mother, small kid). The teenage siblings from floor 2. A stranger trapped in a car. A doctor hiding in a clinic. Each rescue harder than the last. Each one matters. By nightfall: 12 people alive because of you. Exhausted. Injured. But alive. They look at you like you're hope itself.",
  "choices": [
   {
    "id": "sm_lead_them",
    "text": "Lead them all to the next convoy",
    "goTo": "ending_road_warden",
    "effects": {
     "persona": {
      "nice": 3
     },
     "relationships": {
      "Survivors": 10
     },
     "flagsSet": [
      "led_convoy"
     ],
     "pushEvent": "'Follow me. Stay close. We're getting out together.' You lead. They follow. Hope incarnate."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "sm_build_sanctuary",
    "text": "Build a sanctuary here. Make a stand.",
    "goTo": "ending_last_light",
    "effects": {
     "stats": {
      "stress": 6
     },
     "persona": {
      "nice": 3,
      "chill": 1
     },
     "flagsSet": [
      "sanctuary_built"
     ],
     "pushEvent": "'We stay. We build. We survive HERE.' First sanctuary in the dead city."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "sm_teach_survive",
    "text": "Teach them to survive without you",
    "goTo": "ending_teacher",
    "effects": {
     "persona": {
      "chill": 2,
      "nice": 2
     },
     "flagsSet": [
      "taught_survival"
     ],
     "pushEvent": "'I'll teach you. Then you teach others. Survival spreads.' The knowledge passes on."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "sm_overwhelmed",
    "text": "Too many. Too much. Can't save them all.",
    "goTo": "ending_burned_out",
    "effects": {
     "stats": {
      "stress": 10
     },
     "flagsSet": [
      "burnout"
     ],
     "pushEvent": "Too many needs. Too few resources. You try. You fail. The weight crushes you."
    },
    "tags": [
     "nice"
    ]
   }
  ],
  "tags": [
   "saves_more",
   "act1"
  ]
 },
 "ending_road_warden": {
  "id": "ending_road_warden",
  "text": "THE ROAD WARDEN: You guard the exodus. Convoy after convoy. Every family that escapes owes you their lives. The city falls but the people survive. You are the last light on the last road out. Hope has a name. It's yours. Mrs. Chen's ring stays on your finger. Marcus's ghost finally rests. You kept your vow.",
  "choices": [
   {
    "id": "restart_warden",
    "text": "Start a new journey",
    "goTo": "intro",
    "effects": {
     "pushEvent": "Started new game after Road Warden ending."
    },
    "tags": ["restart"]
   }
  ],
  "tags": [
   "ending"
  ],
  "isEnding": true,
  "endingType": "road_warden"
 },
 "ending_last_light": {
  "id": "ending_last_light",
  "text": "THE LAST LIGHT: The sanctuary grows. Floor by floor you reclaim the building. The infected can't break what you've built. Survivors call it 'The Light'\u2014the last place where humanity holds. You teach. You protect. You lead. The guilt over Alex transforms into purpose. You couldn't save them. But you saved everyone after. That has to count.",
  "choices": [
   {
    "id": "restart_light",
    "text": "Begin a new story",
    "goTo": "intro",
    "effects": {
     "pushEvent": "Started new game after Last Light ending."
    },
    "tags": ["restart"]
   }
  ],
  "tags": [
   "ending"
  ],
  "isEnding": true,
  "endingType": "last_light"
 },
 "ending_teacher": {
  "id": "ending_teacher",
  "text": "THE TEACHER: You teach them everything. Survival. Combat. First aid. How to read infected patterns. Your knowledge spreads. Soon there are ten teachers. Then a hundred. The city falls but the survivors carry your lessons. You die in a firefight protecting your students. They carry on. Knowledge is immortal.",
  "choices": [
   {
    "id": "restart_ending_teacher",
    "text": "Start a new journey",
    "goTo": "intro",
    "effects": {
     "pushEvent": "Started new game after ending_teacher ending."
    },
    "tags": ["restart"]
   }
  ],
  "tags": [
   "ending"
  ],
  "isEnding": true,
  "endingType": "teacher"
 },
 "ending_burned_out": {
  "id": "ending_burned_out",
  "text": "THE BURNED OUT: You tried. God knows you tried. But there were too many. Too much need. Too few resources. One by one they died despite your efforts. The guilt compounds. Alex. Mrs. Chen. The Martinez kid. All of them. You sit in the empty building surrounded by ghosts. When the infected finally break through, you don't fight. You're already gone.",
  "choices": [
   {
    "id": "restart_ending_burned_out",
    "text": "Start a new journey",
    "goTo": "intro",
    "effects": {
     "pushEvent": "Started new game after ending_burned_out ending."
    },
    "tags": ["restart"]
   }
  ],
  "tags": [
   "ending"
  ],
  "isEnding": true,
  "endingType": "burned_out"
 },
 "path_guilt_quest": {
  "id": "path_guilt_quest",
  "text": "You decide: find Marcus's family. Make amends. Alex mentioned they lived across town\u2014Riverside district. That's 8 miles through infected territory. Alone. No supplies for that journey. But the guilt demands it. You prep: backpack, weapons, water. Leave a note in your apartment in case you don't return. Step outside. The city sprawls ahead. Burning. Screaming. You head toward Riverside. For Marcus. For Alex. For atonement.",
  "choices": [
   {
    "id": "gq_direct",
    "text": "Direct route. Fastest. Most dangerous.",
    "goTo": "quest_direct_route",
    "effects": {
     "time": 4,
     "stats": {
      "stamina": -3,
      "stress": 4
     },
     "persona": {
      "psycho": 1,
      "nice": 1
     },
     "flagsSet": [
      "direct_route"
     ],
     "pushEvent": "Straight line. Through infected hordes. Through hell. Fast."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "gq_stealth",
    "text": "Stealth route. Slower. Safer.",
    "goTo": "quest_stealth_route",
    "effects": {
     "time": 6,
     "stats": {
      "stamina": -2,
      "stress": 2
     },
     "persona": {
      "chill": 2
     },
     "flagsSet": [
      "stealth_route"
     ],
     "pushEvent": "Rooftops. Alleys. Shadows. Slow but alive."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "gq_find_group",
    "text": "Find a group heading that way",
    "goTo": "quest_find_group",
    "effects": {
     "time": 3,
     "stats": {
      "stress": 2
     },
     "persona": {
      "nice": 1,
      "chill": 1
     },
     "flagsSet": [
      "found_group"
     ],
     "pushEvent": "Search for others going to Riverside. Safer in numbers."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "gq_supplies_first",
    "text": "Raid for supplies before attempting",
    "goTo": "quest_raid_first",
    "effects": {
     "time": 2,
     "stats": {
      "stamina": -2
     },
     "persona": {
      "rude": 1
     },
     "inventoryAdd": [
      "raid_supplies"
     ],
     "flagsSet": [
      "raided_first"
     ],
     "pushEvent": "Need supplies. Raid nearby. THEN go."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "guilt_quest",
   "act1"
  ]
 },
 "path_cold_embrace": {
  "id": "path_cold_embrace",
  "text": "Day 48. You've committed to pure logic. Emotion is inefficiency. You start a journal. Variables to track: infection spread rate, resource depletion, risk vs reward calculations. Every decision will be mathematical. The building has survivors: 8 apartments. Calculate: old = high resource need, low mobility. Young = opposite. Math says save the young. Emotion says save the vulnerable. You choose math. Always.",
  "choices": [
   {
    "id": "ce_young_only",
    "text": "Evacuate only those who can move fast",
    "goTo": "cold_young_priority",
    "effects": {
     "stats": {
      "morality": -5,
      "stress": -3
     },
     "persona": {
      "psycho": 2,
      "chill": 2
     },
     "flagsSet": [
      "young_only_evac"
     ],
     "pushEvent": "Knock on apartments with young adults. Skip Mrs. Chen's floor. Efficiency."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "ce_calculate_value",
    "text": "Calculate each person's survival value",
    "goTo": "cold_value_calc",
    "effects": {
     "persona": {
      "psycho": 1,
      "chill": 3
     },
     "inventoryAdd": [
      "value_ledger"
     ],
     "flagsSet": [
      "calculated_value"
     ],
     "pushEvent": "Doctor = high value. Engineer = high. Elderly with no skills = low. Simple math."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "ce_random_fair",
    "text": "Use random selection\u2014eliminate bias",
    "goTo": "cold_random_fair",
    "effects": {
     "persona": {
      "chill": 3
     },
     "flagsSet": [
      "random_selection"
     ],
     "pushEvent": "Remove emotion and favoritism. Random = fair. Flip a coin for each apartment."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "ce_logic_questioned",
    "text": "The logic is sound... but feels wrong",
    "goTo": "cold_logic_cracks",
    "effects": {
     "stats": {
      "stress": 3
     },
     "persona": {
      "nice": 1
     },
     "flagsSet": [
      "logic_doubt_grows"
     ],
     "pushEvent": "Math says yes. Heart says no. Which is right? Doubt creeps."
    },
    "tags": [
     "nice"
    ]
   }
  ],
  "tags": [
   "cold_logic",
   "act1"
  ]
 },
 "cold_young_priority": {
  "id": "cold_young_priority",
  "text": "You evacuate six young adults. Skip Mrs. Chen. Skip the sick kid. Skip anyone who'd slow the group. Efficient. They move fast. Make it to stadium in 40 minutes. All survive. Math was right. At the checkpoint, one of the young adults: 'There was an old lady. Fourth floor. Did she...' You: 'Didn't make the cut.' Their face. Horror. 'She was begging. We heard her.' You: 'Resource management.' They look at you like you're a monster. Maybe you are. But you're a LIVING monster.",
  "choices": [
   {
    "id": "yp_defend_logic",
    "text": "Defend the logic. It worked.",
    "goTo": "cold_defended",
    "effects": {
     "stats": {
      "morality": -6
     },
     "persona": {
      "psycho": 2,
      "chill": 2
     },
     "relationships": {
      "Survivors": -5
     },
     "flagsSet": [
      "logic_defended"
     ],
     "pushEvent": "'Everyone here is alive. That's what matters. Math works.' They avoid you after."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "yp_no_apology",
    "text": "No apology. No explanation.",
    "goTo": "cold_silent",
    "effects": {
     "persona": {
      "psycho": 3
     },
     "relationships": {
      "Survivors": -3
     },
     "flagsSet": [
      "cold_silent"
     ],
     "pushEvent": "Say nothing. Walk away. Their judgment doesn't matter. Results do."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "yp_slight_regret",
    "text": "Maybe... maybe I was too cold.",
    "goTo": "cold_doubt_grows",
    "effects": {
     "stats": {
      "stress": 3,
      "morality": 1
     },
     "persona": {
      "nice": 1
     },
     "flagsSet": [
      "cold_regret"
     ],
     "pushEvent": "See their faces. Hear Mrs. Chen's begging in memory. Was the math worth it?"
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "yp_double_down",
    "text": "They're weak. Emotion makes them weak.",
    "goTo": "cold_doubled_down",
    "effects": {
     "stats": {
      "morality": -7
     },
     "persona": {
      "psycho": 3,
      "chill": 1
     },
     "flagsSet": [
      "cold_extreme"
     ],
     "pushEvent": "'You're alive because I made hard choices. Be grateful or leave.' Pure ice."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "cold_young",
   "act1"
  ]
 },
 "cold_defended": {
  "id": "cold_defended",
  "text": "The survivors avoid you. Form their own group. Whisper when you pass. You don't care. They're alive. Your method worked. The convoy organizers approach: 'You're... efficient. Brutal. But efficient. We need people who can make hard calls. Interested in a position? Triage coordinator. You decide who gets on the trucks.' It's an offer. Power. Authority. The ability to save more through calculated choices. Or damn more. Depends on the math.",
  "choices": [
   {
    "id": "cd_accept_power",
    "text": "Accept. Someone needs to make hard calls.",
    "goTo": "cold_triage_master",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "psycho": 2,
      "chill": 2
     },
     "flagsSet": [
      "triage_role",
      "power_accepted"
     ],
     "pushEvent": "'I'll do it. Someone has to.' Power to save. Power to damn. Both."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "cd_refuse_power",
    "text": "Refuse. Don't want that responsibility.",
    "goTo": "cold_refuses_power",
    "effects": {
     "stats": {
      "stress": -1
     },
     "persona": {
      "chill": 2
     },
     "flagsSet": [
      "power_refused"
     ],
     "pushEvent": "'No. I make my own calls. Not others'.' They nod. Respect that."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "cd_conditions",
    "text": "Accept with conditions\u2014full authority, no oversight",
    "goTo": "cold_demands_control",
    "effects": {
     "persona": {
      "psycho": 3,
      "rude": 1
     },
     "flagsSet": [
      "triage_dictator",
      "full_control"
     ],
     "pushEvent": "'Full control or nothing. No committees. No feelings. Math only.' They hesitate. Agree."
    },
    "tags": [
     "psycho"
    ],
    "popupText": "Absolute power corrupts."
   },
   {
    "id": "cd_bargain",
    "text": "Bargain for supplies in exchange",
    "goTo": "cold_leverage_position",
    "effects": {
     "persona": {
      "rude": 2,
      "chill": 1
     },
     "inventoryAdd": [
      "supply_payment"
     ],
     "flagsSet": [
      "leveraged_role"
     ],
     "pushEvent": "'I'll do it. But I get first pick of supplies.' Transactional. They nod."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "cold_power",
   "act1"
  ]
 },
 "path_loot_complete": {
  "id": "path_loot_complete",
  "text": "You pocket everything from Alex's body. Including the photo. Back in your apartment, you examine the haul: keys open building master locks. Medkit has antibiotics (rare). Radio has encrypted frequencies (useful). Photo shows Marcus and Alex at a baseball game. Happy. Alive. Before. You study the photo. Try to feel something. Can't. It's just paper and ink now. The people in it are dead. You're alive. That's what matters. Right?",
  "choices": [
   {
    "id": "lc_use_keys",
    "text": "Use keys to raid locked apartments",
    "goTo": "loot_raid_building",
    "effects": {
     "stats": {
      "morality": -5
     },
     "persona": {
      "rude": 2,
      "psycho": 1
     },
     "inventoryAdd": [
      "raid_loot"
     ],
     "flagsSet": [
      "raided_building"
     ],
     "pushEvent": "Master keys = access to everything. Eight apartments. All supplies now yours."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "lc_encrypted_radio",
    "text": "Decrypt the radio frequencies",
    "goTo": "loot_radio_intel",
    "effects": {
     "time": 2,
     "persona": {
      "chill": 3
     },
     "inventoryAdd": [
      "decrypted_channels"
     ],
     "flagsSet": [
      "radio_decrypted"
     ],
     "pushEvent": "Work the encryption. Takes hours. Worth it. Military channels. Convoy routes. Intel = power."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "lc_study_photo",
    "text": "Study the photo\u2014maybe guilt is there somewhere",
    "goTo": "loot_guilt_surfaces",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "nice": 1
     },
     "flagsSet": [
      "guilt_surfaces"
     ],
     "pushEvent": "Stare at photo. Two people who trusted each other. Dead now. One because of you. Feel... something."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "lc_burn_photo",
    "text": "Burn the photo. Destroy the evidence.",
    "goTo": "loot_destroy_evidence",
    "effects": {
     "stats": {
      "stress": -2
     },
     "persona": {
      "psycho": 2
     },
     "flagsSet": [
      "photo_burned"
     ],
     "pushEvent": "Light it on fire. Watch it curl. Blacken. Disappear. Like they did. No evidence. No guilt."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "loot_complete",
   "act1"
  ]
 },
 "loot_raid_building": {
  "id": "loot_raid_building",
  "text": "Master keys open every door. Apartment 5C: family of three. Infected. Dead for days. You loot the corpses. Canned food. Batteries. Medicine. Apartment 4A: Mrs. Chen's place. Empty. She evacuated? No. Blood trail leads to bedroom. Infected got her. You loot anyway. Jewelry (tradeable). Photos (worthless). Her cane (sturdy, could be a weapon). Apartment 3B: Alex's apartment. Their door. You hesitate. First time you've hesitated. Push it open. Inside: Marcus. Or what was Marcus. Infected. Chained to a radiator. Someone chained him before running. Alex? Marcus sees you. Lunges. Chain holds. He's still wearing the baseball jersey from the photo.",
  "choices": [
   {
    "id": "rb_kill_marcus",
    "text": "Kill Marcus. End his suffering.",
    "goTo": "loot_marcus_mercy_kill",
    "effects": {
     "stats": {
      "stress": 3
     },
     "persona": {
      "nice": 1,
      "psycho": 1
     },
     "flagsSet": [
      "marcus_mercy_killed"
     ],
     "pushEvent": "You approach. Marcus snarls. You swing. Quick. Clean. 'For Alex.' It's over."
    },
    "tags": [
     "nice"
    ],
    "popupText": "Mercy or murder?"
   },
   {
    "id": "rb_study_marcus",
    "text": "Study Marcus\u2014infection progression notes",
    "goTo": "loot_marcus_studied",
    "effects": {
     "persona": {
      "psycho": 2,
      "chill": 2
     },
     "inventoryAdd": [
      "infection_data"
     ],
     "flagsSet": [
      "marcus_studied"
     ],
     "pushEvent": "Observe. Notes: infection stage 3. Advanced degradation. Useful data. Marcus is just a specimen now."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "rb_leave_marcus",
    "text": "Leave him chained. Not your problem.",
    "goTo": "loot_marcus_left",
    "effects": {
     "persona": {
      "psycho": 1,
      "rude": 1
     },
     "flagsSet": [
      "marcus_left_chained"
     ],
     "pushEvent": "Not your problem. Back out. Close door. Leave him there. Forever."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "rb_talk_marcus",
    "text": "Try to talk to him. See if anything's left.",
    "goTo": "loot_marcus_talk_attempt",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "nice": 1
     },
     "flagsSet": [
      "talked_to_marcus"
     ],
     "pushEvent": "'Marcus? It's me. From 6B. Can you understand?' Just snarls. Nothing human left. You tried."
    },
    "tags": [
     "nice"
    ]
   }
  ],
  "tags": [
   "loot_raid",
   "act1"
  ]
 },
 "loot_marcus_mercy_kill": {
  "id": "loot_marcus_mercy_kill",
  "text": "You kill what's left of Marcus. The body stops moving. Silence. You search the apartment. Find: Marcus's work bag (tools, valuable). His phone (dead battery but maybe chargeable). A note on the fridge in Alex's handwriting: 'M - went to find water. Back soon. Love you.' They never came back. Marcus turned alone. Chained himself so he wouldn't hurt anyone. Even infected, he tried to protect people. More humanity in the monster than in you. That thought sticks.",
  "choices": [
   {
    "id": "mk_respect",
    "text": "Respect that. Marcus was strong.",
    "goTo": "loot_respects_marcus",
    "effects": {
     "stats": {
      "morality": 2
     },
     "persona": {
      "nice": 2,
      "chill": 1
     },
     "relationships": {
      "Marcus_memory": 5
     },
     "flagsSet": [
      "respected_marcus"
     ],
     "pushEvent": "Marcus tried. Even at the end. Respect that. Take the tools. Use them well."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "mk_take_all",
    "text": "Take everything. Sentiment is weakness.",
    "goTo": "loot_takes_all_cold",
    "effects": {
     "persona": {
      "psycho": 2,
      "rude": 2
     },
     "inventoryAdd": [
      "tools",
      "phone"
     ],
     "flagsSet": [
      "took_everything"
     ],
     "pushEvent": "Bag it all. Every resource counts. Marcus is dead. You're alive. That's the equation."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "mk_leave_tools",
    "text": "Leave the tools. Blood money feels wrong.",
    "goTo": "loot_selective_morality",
    "effects": {
     "stats": {
      "stress": 1
     },
     "persona": {
      "nice": 1
     },
     "flagsSet": [
      "left_tools"
     ],
     "pushEvent": "Can't take them. Feels like graverobbing. Already did that. Line has to be somewhere."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "mk_photograph_note",
    "text": "Photograph the note. Document it.",
    "goTo": "loot_documents_everything",
    "effects": {
     "persona": {
      "chill": 2
     },
     "inventoryAdd": [
      "documented_evidence"
     ],
     "flagsSet": [
      "documentation_compulsion"
     ],
     "pushEvent": "Document everything. Build a record. Why? Not sure. Compulsion to preserve something."
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "tags": [
   "loot_marcus",
   "act1"
  ]
 },
 "saved_after_demand": {
  "id": "saved_after_demand",
  "text": "Alex is inside. Alive. But something's different. They won't look at you directly. Sit across the room. When you try to speak, they flinch. Your demand for proof\u2014the way you treated them like a threat before a person\u2014it hurt. Deeper than you realized. 'I've known you for two years,' they finally say. 'Fixed your fuse box six times. Helped you move furniture. And you treated me like... like one of THEM.' The pain in their voice is raw. Can you fix this?",
  "choices": [
   {
    "id": "sd_apologize_real",
    "text": "Apologize sincerely. Explain the fear.",
    "goTo": "demand_apology_accepted",
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
      "apology_sincere"
     ],
     "pushEvent": "'I'm sorry. Fear makes us cruel. I was afraid. Not of you. Of being wrong.' Alex softens. 'I get it. This world is fear.'"
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "sd_justify",
    "text": "Justify it\u2014caution kept us both alive",
    "goTo": "demand_justified",
    "effects": {
     "persona": {
      "chill": 2
     },
     "relationships": {
      "Alex": 2
     },
     "flagsSet": [
      "demand_justified"
     ],
     "pushEvent": "'Caution kept us alive. Can't apologize for that.' Alex: 'I guess.' But the hurt remains."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "sd_no_apology",
    "text": "Don't apologize. You were right to verify.",
    "goTo": "demand_no_apology",
    "effects": {
     "persona": {
      "psycho": 1,
      "rude": 1
     },
     "relationships": {
      "Alex": -2
     },
     "flagsSet": [
      "no_apology_given"
     ],
     "pushEvent": "'Did what I had to. No apology.' Alex's eyes go cold. 'Right. Good to know where we stand.'"
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "sd_make_up",
    "text": "Actions, not words. Let me make it up to you.",
    "goTo": "demand_make_amends",
    "effects": {
     "time": 1,
     "persona": {
      "nice": 1,
      "chill": 1
     },
     "relationships": {
      "Alex": 4
     },
     "flagsSet": [
      "making_amends"
     ],
     "pushEvent": "'Let me show you. Not just words.' Spend the day helping them. Slowly, walls come down."
    },
    "tags": [
     "nice"
    ]
   }
  ],
  "tags": [
   "demand_saved",
   "act1"
  ]
 },
 "saved_after_apology": {
  "id": "saved_after_apology",
  "text": "Alex is inside. Alive. The apology helped, but there's still tension. They sit near the door, not quite comfortable. 'I understand why you had to be sure,' they say quietly. 'But it still hurt. Being treated like... like a threat first, a person second.' They look at you. 'I've known you for two years. Fixed your fuse box six times. Helped you move furniture. And you treated me like one of THEM.' The pain in their voice is raw. Can you fix this?",
  "choices": [
   {
    "id": "sa_apologize_deeper",
    "text": "Apologize more deeply. Explain the fear.",
    "goTo": "apology_deeper_accepted",
    "effects": {
     "stats": {
      "stress": -2
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 6
     },
     "flagsSet": [
      "apology_deeper"
     ],
     "pushEvent": "'I'm sorry. Fear makes us cruel. I was afraid. Not of you. Of being wrong.' Alex softens. 'I get it. This world is fear.'"
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "sa_actions_not_words",
    "text": "Actions, not words. Let me make it up to you.",
    "goTo": "apology_make_amends",
    "effects": {
     "time": 1,
     "persona": {
      "nice": 1,
      "chill": 1
     },
     "relationships": {
      "Alex": 5
     },
     "flagsSet": [
      "making_amends"
     ],
     "pushEvent": "'Let me show you. Not just words.' Spend the day helping them. Slowly, walls come down."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "sa_justify_caution",
    "text": "Justify it—caution kept us both alive",
    "goTo": "apology_justified",
    "effects": {
     "persona": {
      "chill": 2
     },
     "relationships": {
      "Alex": 3
     },
     "flagsSet": [
      "apology_justified"
     ],
     "pushEvent": "'Caution kept us alive. Can't apologize for that.' Alex: 'I guess.' But the hurt remains."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "sa_no_further_apology",
    "text": "Don't apologize further. You were right to verify.",
    "goTo": "apology_no_further",
    "effects": {
     "persona": {
      "rude": 1
     },
     "relationships": {
      "Alex": 1
     },
     "flagsSet": [
      "no_further_apology"
     ],
     "pushEvent": "'Did what I had to. No further apology.' Alex's eyes go cold. 'Right. Good to know where we stand.'"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "apology_saved",
   "act1"
  ]
 },
 "demand_apology_accepted": {
  "id": "demand_apology_accepted",
  "text": "Your apology lands. Alex exhales. The tension breaks. 'Okay. I get it. Fear makes us into people we don't recognize.' They pause. 'I'm sorry too. For expecting you to just trust. In this world.' A moment of mutual understanding. The hurt isn't gone but it's... acknowledged. You both move forward. Alex extends a hand. 'Start over? Hi. I'm Alex. I survive apocalypses and fix fuse boxes. Apparently in that order now.' A weak smile. Real though.",
  "choices": [
   {
    "id": "aa_start_over",
    "text": "Start over. Clean slate.",
    "goTo": "demand_relationship_rebuilt",
    "effects": {
     "stats": {
      "stress": -3
     },
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 6
     },
     "flagsSet": [
      "relationship_rebuilt",
      "clean_slate"
     ],
     "pushEvent": "'Clean slate. Hi. I survive and make bad jokes under pressure.' You shake hands. Fresh start."
    },
    "tags": [
     "nice"
    ],
    "popupText": "Forgiveness is powerful."
   },
   {
    "id": "aa_cautious_forward",
    "text": "Move forward but cautiously",
    "goTo": "demand_cautious_trust",
    "effects": {
     "persona": {
      "chill": 2
     },
     "relationships": {
      "Alex": 4
     },
     "flagsSet": [
      "cautious_rebuilt"
     ],
     "pushEvent": "'Forward. Carefully.' Alex nods. Trust can be rebuilt. Slowly."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "aa_professional",
    "text": "Professional relationship only",
    "goTo": "demand_professional_only",
    "effects": {
     "persona": {
      "chill": 1,
      "rude": 1
     },
     "relationships": {
      "Alex": 2
     },
     "flagsSet": [
      "professional_dynamic"
     ],
     "pushEvent": "'We help each other survive. That's the relationship.' Alex: 'Right. Professional.' The warmth doesn't return."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "aa_power_dynamic",
    "text": "Apology accepted but dynamic stays: you lead, they follow",
    "goTo": "demand_hierarchy_set",
    "effects": {
     "persona": {
      "psycho": 1,
      "rude": 1
     },
     "relationships": {
      "Alex": 3
     },
     "flagsSet": [
      "hierarchy_maintained"
     ],
     "pushEvent": "'Apology noted. But I make the calls. Agreed?' Alex swallows. 'Agreed.' Power established."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "demand_apology",
   "act1"
  ]
 },
 "act1_family_hub": {
  "id": "act1_family_hub",
  "text": "Day 49. You and Alex (if alive and close) or you alone stand at a crossroads. The building won't hold much longer. The convoy at the stadium is leaving in 6 hours. Final evac. Miss it and you're trapped. Options: rush to convoy now (safe but abandon others), gather survivors first (risky but morally right), raid for supplies then go (pragmatic), or stay and fortify the building (insane but possible). The infected breach intensifies. Screams from floor 2. What's your move?",
  "choices": [
   {
    "id": "hub_convoy_rush",
    "text": "Rush to convoy immediately",
    "goTo": "rush_convoy_path",
    "effects": {
     "time": 2,
     "stats": {
      "stress": 2
     },
     "flagsSet": [
      "convoy_rush"
     ],
     "pushEvent": "No time. Move NOW."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "hub_gather_all",
    "text": "Gather every survivor you can",
    "goTo": "gather_survivors_path",
    "effects": {
     "time": 4,
     "stats": {
      "stress": 5,
      "stamina": -2
     },
     "persona": {
      "nice": 3
     },
     "flagsSet": [
      "gather_attempt"
     ],
     "pushEvent": "Every life matters. Start knocking on doors."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "hub_raid_supply",
    "text": "Raid for supplies first",
    "goTo": "raid_supply_path",
    "effects": {
     "time": 3,
     "stats": {
      "stamina": -1
     },
     "persona": {
      "rude": 2
     },
     "flagsSet": [
      "supply_raid"
     ],
     "pushEvent": "Supplies = survival. Raid first."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "hub_fortify_stay",
    "text": "Fortify and stay. Make a stand.",
    "goTo": "fortify_building_path",
    "effects": {
     "stats": {
      "stress": 4
     },
     "persona": {
      "psycho": 2,
      "chill": 1
     },
     "flagsSet": [
      "fortify_stay"
     ],
     "pushEvent": "Running is surrender. This building is yours. HOLD IT."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "act1_hub"
  ]
 },
 "alex_partners": {
  "id": "alex_partners",
  "text": "You and Alex establish partnership. Equal say in decisions. Day 49: the partnership is tested. You want to raid the pharmacy (risky, needed supplies). Alex wants to help the Martinez family escape first (safer, moral). Both valid. Both can't happen\u2014not enough time. First real disagreement. How you handle it shows if partnership is real or just a word.",
  "choices": [
   {
    "id": "part_pharmacy",
    "text": "Insist on pharmacy\u2014we need supplies",
    "goTo": "partners_first_conflict",
    "effects": {
     "stats": {
      "stress": 2
     },
     "relationships": {
      "Alex": -2
     },
     "flagsSet": "pharmacy_insisted",
     "pushEvent": "'Supplies first. We need them.' Alex: 'But the family...' You: 'Supplies.'"
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "part_family",
    "text": "Agree with Alex\u2014family first",
    "goTo": "partners_alex_choice",
    "effects": {
     "persona": {
      "nice": 2
     },
     "relationships": {
      "Alex": 4
     },
     "flagsSet": "family_first",
     "pushEvent": "'You're right. Family first.' Alex smiles. 'Thank you for hearing me.'"
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "part_compromise",
    "text": "Split up. You raid, Alex helps family.",
    "goTo": "partners_split_up",
    "effects": {
     "time": 2,
     "stats": {
      "stress": 3
     },
     "persona": {
      "chill": 2
     },
     "flagsSet": "split_tasks",
     "pushEvent": "'Split up. Meet at the stadium.' Alex: 'Partners split tasks. Smart.'"
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "part_vote",
    "text": "Can't decide\u2014flip a coin",
    "goTo": "partners_coin_flip",
    "effects": {
     "persona": {
      "chill": 1
     },
     "flagsSet": "coin_flip",
     "pushEvent": "'Can't agree. Flip for it.' Alex: 'Really?' You: 'Democratic.' Flip. Lands..."
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "tags": [
   "partners"
  ]
 },
 "filler_branch_0": {
  "id": "filler_branch_0",
  "text": "The infected have breached the building's lower floors. Screams echo through the stairwell as survivors flee upward. You're on the 8th floor with Alex, and the infected are climbing fast. The elevator shaft is blocked, and the fire escape is compromised. Time is running out. You need to decide how to escape or fight.",
  "choices": [
   {
    "id": "fb0_a",
    "text": "Fight your way down - aggressive assault",
    "goTo": "filler_branch_1",
    "effects": {
     "stats": {
      "health": -5,
      "stress": 3
     },
     "persona": {
      "psycho": 2
     },
     "flags": {
      "route_psycho": true
     },
     "pushEvent": "Chose aggressive combat approach."
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "fb0_b",
    "text": "Find alternative escape route - rooftop access",
    "goTo": "filler_branch_2",
    "effects": {
     "stats": {
      "stamina": -2,
      "stress": -1
     },
     "persona": {
      "chill": 2
     },
     "flags": {
      "route_chill": true
     },
     "pushEvent": "Chose strategic escape route."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb0_c",
    "text": "Help other survivors escape first",
    "goTo": "filler_branch_3",
    "effects": {
     "stats": {
      "health": -3,
      "morality": 5
     },
     "persona": {
      "nice": 2
     },
     "flags": {
      "route_nice": true
     },
     "pushEvent": "Prioritized helping others escape."
    },
    "tags": [
     "nice"
    ]
   }
  ],
  "tags": [
   "combat",
   "escape"
  ]
 },
 "filler_branch_1": {
  "id": "filler_branch_1",
  "text": "You've reached the rooftop, but the situation is dire. The building is surrounded by infected, and other survivors are panicking. A helicopter approaches in the distance - your only chance for escape. But there are more people than seats available. You must decide who gets to live and who gets left behind.",
  "choices": [
   {
    "id": "fb1_a",
    "text": "Take command and organize evacuation by priority",
    "goTo": "filler_branch_2",
    "effects": {
     "stats": {
      "stress": 2,
      "morality": 3
     },
     "persona": {
      "protector": 2
     },
     "flags": {
      "route_protector": true
     },
     "pushEvent": "Organized evacuation with difficult choices."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "fb1_b",
    "text": "Negotiate with the pilot for more time",
    "goTo": "filler_branch_3",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": 1
     },
     "persona": {
      "fixer": 2
     },
     "flags": {
      "route_fixer": true
     },
     "pushEvent": "Attempted negotiation for more time."
    },
    "tags": [
     "fixer"
    ]
   },
   {
    "id": "fb1_c",
    "text": "Secure your own escape first",
    "goTo": "filler_branch_4",
    "effects": {
     "stats": {
      "morality": -5
     },
     "persona": {
      "rude": 2
     },
     "flags": {
      "route_rude": true
     },
     "pushEvent": "Prioritized personal survival."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "evacuation",
   "moral_choice"
  ]
 },
 "filler_branch_2": {
  "id": "filler_branch_2",
  "text": "The helicopter lands, but the pilot reveals they're from a military quarantine zone. They can only take people who pass medical screening. Several survivors show signs of infection. The pilot insists on testing everyone before boarding. You must decide how to handle this situation.",
  "choices": [
   {
    "id": "fb2_a",
    "text": "Submit to medical screening honestly",
    "goTo": "filler_branch_5",
    "effects": {
     "stats": {
      "stress": -1,
      "morality": 3
     },
     "persona": {
      "nice": 1
     },
     "pushEvent": "Chose honest medical screening."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb2_b",
    "text": "Try to hide any symptoms",
    "goTo": "filler_branch_6",
    "effects": {
     "stats": {
      "stress": 2,
      "morality": -3
     },
     "persona": {
      "rude": 1
     },
     "pushEvent": "Attempted to hide symptoms."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "fb2_c",
    "text": "Demand everyone gets tested equally",
    "goTo": "filler_branch_7",
    "effects": {
     "stats": {
      "stress": 1
     },
     "persona": {
      "protector": 1
     },
     "pushEvent": "Demanded fair testing for all."
    },
    "tags": [
     "protector"
    ]
   }
  ],
  "tags": [
   "medical",
   "quarantine"
  ]
 },
 "filler_branch_2": {
  "id": "filler_branch_2",
  "text": "The helicopter lands, but the pilot reveals they're from a military quarantine zone. They can only take people who pass medical screening. Several survivors show signs of infection. The pilot insists on testing everyone before boarding. You must decide how to handle this situation.",
  "choices": [
   {
    "id": "fb2_a",
    "text": "Demand fair testing for all",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": 1
     },
     "persona": {
      "protector": 1
     },
     "pushEvent": "Demanded fair testing for all."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "fb2_b",
    "text": "Careful action",
    "goTo": "filler_branch_4",
    "effects": {
     "stats": {
      "stamina": -1
     },
     "persona": {
      "chill": 1
     },
     "flags": {
      "route_chill": true
     },
     "pushEvent": "Chose careful approach."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb2_c",
    "text": "Social action",
    "goTo": "filler_branch_5",
    "effects": {
     "relationships": {
      "Survivors": 1
     },
     "persona": {
      "nice": 1
     },
     "flags": {
      "route_nice": true
     },
     "pushEvent": "Chose social approach."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb2_d",
    "text": "Selfish action",
    "goTo": "filler_branch_3",
    "effects": {
     "inventoryAdd": "resource",
     "persona": {
      "rude": 1
     },
     "flags": {
      "route_rude": true
     },
     "pushEvent": "Chose selfish approach."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_2"
  ]
 },
 "filler_branch_3": {
  "id": "filler_branch_3",
  "text": "The negotiation fails. The pilot reveals they're part of a military operation and can only take people with specific skills or knowledge. They're looking for engineers, doctors, or people with information about the outbreak. You must prove your worth or find another way.",
  "choices": [
   {
    "id": "fb3_a",
    "text": "Claim to have medical knowledge",
    "goTo": "filler_branch_8",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "fixer": 1
     },
     "pushEvent": "Claimed medical expertise."
    },
    "tags": [
     "fixer"
    ]
   },
   {
    "id": "fb3_b",
    "text": "Offer information about the building's layout",
    "goTo": "filler_branch_9",
    "effects": {
     "stats": {
      "stress": -1
     },
     "persona": {
      "chill": 1
     },
     "pushEvent": "Provided tactical information."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb3_c",
    "text": "Threaten to expose their location to infected",
    "goTo": "filler_branch_10",
    "effects": {
     "stats": {
      "stress": 3,
      "morality": -5
     },
     "persona": {
      "psycho": 2
     },
     "flags": {
      "route_psycho": true
     },
     "pushEvent": "Used threats to gain leverage."
    },
    "tags": [
     "psycho"
    ]
   }
  ],
  "tags": [
   "negotiation",
   "skills"
  ]
 },
 "filler_branch_3": {
  "id": "filler_branch_3",
  "text": "The pilot agrees to wait, but demands proof of your value. They want you to demonstrate leadership skills by organizing the survivors. Several people are panicking, and the infected are getting closer. You must decide how to handle this situation.",
  "choices": [
   {
    "id": "fb3_a",
    "text": "Take command and organize evacuation by priority",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": 2,
      "morality": 3
     },
     "persona": {
      "protector": 2
     },
     "flags": {
      "route_protector": true
     },
     "pushEvent": "Organized evacuation with difficult choices."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "fb3_b",
    "text": "Careful action",
    "goTo": "filler_branch_5",
    "effects": {
     "stats": {
      "stamina": -1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb3_c",
    "text": "Social action",
    "goTo": "filler_branch_6",
    "effects": {
     "relationships": {
      "Survivors": 1
     },
     "persona": {
      "nice": 1
     },
     "flags": {
      "route_nice": true
     },
     "pushEvent": "Chose social approach."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb3_d",
    "text": "Selfish action",
    "goTo": "filler_branch_4",
    "effects": {
     "inventoryAdd": "resource",
     "persona": {
      "rude": 1
     },
     "flags": {
      "route_rude": true
     },
     "pushEvent": "Chose selfish approach."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_3"
  ]
 },
 "filler_branch_4": {
  "id": "filler_branch_4",
  "text": "You've secured your escape, but Alex and others are left behind. As the helicopter takes off, you see the infected swarm the building. The guilt is overwhelming, but you're alive. The pilot explains they're heading to a research facility where survivors are being studied.",
  "choices": [
   {
    "id": "fb4_a",
    "text": "Accept the guilt and focus on survival",
    "goTo": "filler_branch_11",
    "effects": {
     "stats": {
      "stress": 2,
      "morality": -3
     },
     "persona": {
      "rude": 1
     },
     "pushEvent": "Accepted guilt but prioritized survival."
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "fb4_b",
    "text": "Demand to go back for the others",
    "goTo": "filler_branch_12",
    "effects": {
     "stats": {
      "stress": 3,
      "morality": 5
     },
     "persona": {
      "nice": 2
     },
     "flags": {
      "route_nice": true
     },
     "pushEvent": "Prioritized helping others escape."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb4_c",
    "text": "Ask about the research facility",
    "goTo": "filler_branch_13",
    "effects": {
     "stats": {
      "stress": -1
     },
     "persona": {
      "chill": 1
     },
     "pushEvent": "Focused on gathering information."
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "tags": [
   "guilt",
   "research"
  ]
 },
 "filler_branch_4": {
  "id": "filler_branch_4",
  "text": "You've escaped to a research facility, but guilt weighs heavily on your conscience. The facility is well-stocked but isolated. You learn that the researchers were studying the infection, but most of them are dead or missing. You must decide how to handle this situation.",
  "choices": [
   {
    "id": "fb4_a",
    "text": "Take command and organize evacuation by priority",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": 2,
      "morality": 3
     },
     "persona": {
      "protector": 2
     },
     "flags": {
      "route_protector": true
     },
     "pushEvent": "Organized evacuation with difficult choices."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "fb4_b",
    "text": "Careful action",
    "goTo": "filler_branch_6",
    "effects": {
     "stats": {
      "stamina": -1
     },
     "persona": {
      "chill": 1
     },
     "flags": {
      "route_chill": true
     },
     "pushEvent": "Chose careful approach."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb4_c",
    "text": "Social action",
    "goTo": "filler_branch_7",
    "effects": {
     "relationships": {
      "Survivors": 1
     },
     "persona": {
      "nice": 1
     },
     "flags": {
      "route_nice": true
     },
     "pushEvent": "Chose social approach."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb4_d",
    "text": "Selfish action",
    "goTo": "filler_branch_5",
    "effects": {
     "inventoryAdd": "resource",
     "persona": {
      "rude": 1
     },
     "flags": {
      "route_rude": true
     },
     "pushEvent": "Chose selfish approach."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_4"
  ]
 },
 "filler_branch_5": {
  "id": "filler_branch_5",
  "text": "Scene 5: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb5_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_6",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 5."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb5_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_7",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 5."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb5_c",
    "text": "Help others",
    "goTo": "filler_branch_8",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 5."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
 "filler_branch_5": {
  "id": "filler_branch_5",
  "text": "You've reached a safe zone, but the consequences of your choices weigh heavily on your mind. The safe zone is well-protected but overcrowded. You learn that resources are running low and tensions are high. You must decide how to handle this situation.",
  "choices": [
   {
    "id": "fb5_a",
    "text": "Take command and organize evacuation by priority",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": 2,
      "morality": 3
     },
     "persona": {
      "protector": 2
     },
     "flags": {
      "route_protector": true
     },
     "pushEvent": "Organized evacuation with difficult choices."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "fb5_b",
    "text": "Careful action",
    "goTo": "filler_branch_7",
    "effects": {
     "stats": {
      "stamina": -1
     },
     "persona": {
      "chill": 1
     },
     "flags": {
      "route_chill": true
     },
     "pushEvent": "Chose careful approach."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb5_c",
    "text": "Social action",
    "goTo": "filler_branch_8",
    "effects": {
     "relationships": {
      "Survivors": 1
     },
     "persona": {
      "nice": 1
     },
     "flags": {
      "route_nice": true
     },
     "pushEvent": "Chose social approach."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb5_d",
    "text": "Selfish action",
    "goTo": "filler_branch_6",
    "effects": {
     "inventoryAdd": "resource",
     "persona": {
      "rude": 1
     },
     "flags": {
      "route_rude": true
     },
     "pushEvent": "Chose selfish approach."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_5"
  ]
 },
 "filler_branch_6": {
  "id": "filler_branch_6",
  "text": "Scene 6: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb6_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_7",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 6."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb6_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_8",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 6."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb6_c",
    "text": "Help others",
    "goTo": "filler_branch_9",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 6."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
 "filler_branch_6": {
  "id": "filler_branch_6",
  "text": "You've reached a research facility, but the consequences of your choices weigh heavily on your mind. The facility is well-equipped but isolated. You learn that the researchers were studying the infection, but most of them are dead or missing. You must decide how to handle this situation.",
  "choices": [
   {
    "id": "fb6_a",
    "text": "Take command and organize evacuation by priority",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": 2,
      "morality": 3
     },
     "persona": {
      "protector": 2
     },
     "flags": {
      "route_protector": true
     },
     "pushEvent": "Organized evacuation with difficult choices."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "fb6_b",
    "text": "Careful action",
    "goTo": "filler_branch_8",
    "effects": {
     "stats": {
      "stamina": -1
     },
     "persona": {
      "chill": 1
     },
     "flags": {
      "route_chill": true
     },
     "pushEvent": "Chose careful approach."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb6_c",
    "text": "Social action",
    "goTo": "filler_branch_9",
    "effects": {
     "relationships": {
      "Survivors": 1
     },
     "persona": {
      "nice": 1
     },
     "flags": {
      "route_nice": true
     },
     "pushEvent": "Chose social approach."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb6_d",
    "text": "Selfish action",
    "goTo": "filler_branch_7",
    "effects": {
     "inventoryAdd": "resource",
     "persona": {
      "rude": 1
     },
     "flags": {
      "route_rude": true
     },
     "pushEvent": "Chose selfish approach."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_6"
  ]
 },
 "filler_branch_7": {
  "id": "filler_branch_7",
  "text": "Scene 7: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb7_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_8",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 7."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb7_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_9",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 7."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb7_c",
    "text": "Help others",
    "goTo": "filler_branch_10",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 7."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
 "filler_branch_7": {
  "id": "filler_branch_7",
  "text": "You've reached a safe zone, but the consequences of your choices weigh heavily on your mind. The safe zone is well-protected but overcrowded. You learn that resources are running low and tensions are high. You must decide how to handle this situation.",
  "choices": [
   {
    "id": "fb7_a",
    "text": "Take command and organize evacuation by priority",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": 2,
      "morality": 3
     },
     "persona": {
      "protector": 2
     },
     "flags": {
      "route_protector": true
     },
     "pushEvent": "Organized evacuation with difficult choices."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "fb7_b",
    "text": "Careful action",
    "goTo": "filler_branch_9",
    "effects": {
     "stats": {
      "stamina": -1
     },
     "persona": {
      "chill": 1
     },
     "flags": {
      "route_chill": true
     },
     "pushEvent": "Chose careful approach."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb7_c",
    "text": "Social action",
    "goTo": "filler_branch_10",
    "effects": {
     "relationships": {
      "Survivors": 1
     },
     "persona": {
      "nice": 1
     },
     "flags": {
      "route_nice": true
     },
     "pushEvent": "Chose social approach."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb7_d",
    "text": "Selfish action",
    "goTo": "filler_branch_8",
    "effects": {
     "inventoryAdd": "resource",
     "persona": {
      "rude": 1
     },
     "flags": {
      "route_rude": true
     },
     "pushEvent": "Chose selfish approach."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_7"
  ]
 },
 "filler_branch_8": {
  "id": "filler_branch_8",
  "text": "Scene 8: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb8_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_9",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 8."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb8_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_10",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 8."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb8_c",
    "text": "Help others",
    "goTo": "filler_branch_11",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 8."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
 "filler_branch_8": {
  "id": "filler_branch_8",
  "text": "You've reached a research facility, but the consequences of your choices weigh heavily on your mind. The facility is well-equipped but isolated. You learn that the researchers were studying the infection, but most of them are dead or missing. You must decide how to handle this situation.",
  "choices": [
   {
    "id": "fb8_a",
    "text": "Take command and organize evacuation by priority",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": 2,
      "morality": 3
     },
     "persona": {
      "protector": 2
     },
     "flags": {
      "route_protector": true
     },
     "pushEvent": "Organized evacuation with difficult choices."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "fb8_b",
    "text": "Careful action",
    "goTo": "filler_branch_10",
    "effects": {
     "stats": {
      "stamina": -1
     },
     "persona": {
      "chill": 1
     },
     "flags": {
      "route_chill": true
     },
     "pushEvent": "Chose careful approach."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb8_c",
    "text": "Social action",
    "goTo": "filler_branch_11",
    "effects": {
     "relationships": {
      "Survivors": 1
     },
     "persona": {
      "nice": 1
     },
     "flags": {
      "route_nice": true
     },
     "pushEvent": "Chose social approach."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb8_d",
    "text": "Selfish action",
    "goTo": "filler_branch_9",
    "effects": {
     "inventoryAdd": "resource",
     "persona": {
      "rude": 1
     },
     "flags": {
      "route_rude": true
     },
     "pushEvent": "Chose selfish approach."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_8"
  ]
 },
 "filler_branch_9": {
  "id": "filler_branch_9",
  "text": "Scene 9: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb9_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_10",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 9."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb9_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_11",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 9."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb9_c",
    "text": "Help others",
    "goTo": "filler_branch_12",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 9."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
 "filler_branch_9": {
  "id": "filler_branch_9",
  "text": "You've reached a safe zone, but the consequences of your choices weigh heavily on your mind. The safe zone is well-protected but overcrowded. You learn that resources are running low and tensions are high. You must decide how to handle this situation.",
  "choices": [
   {
    "id": "fb9_a",
    "text": "Take command and organize evacuation by priority",
    "goTo": "intro",
    "effects": {
     "stats": {
      "stress": 2,
      "morality": 3
     },
     "persona": {
      "protector": 2
     },
     "flags": {
      "route_protector": true
     },
     "pushEvent": "Organized evacuation with difficult choices."
    },
    "tags": [
     "protector"
    ]
   },
   {
    "id": "fb9_b",
    "text": "Careful action",
    "goTo": "filler_branch_11",
    "effects": {
     "stats": {
      "stamina": -1
     },
     "persona": {
      "chill": 1
     },
     "flags": {
      "route_chill": true
     },
     "pushEvent": "Chose careful approach."
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb9_c",
    "text": "Social action",
    "goTo": "filler_branch_12",
    "effects": {
     "relationships": {
      "Survivors": 1
     },
     "persona": {
      "nice": 1
     },
     "flags": {
      "route_nice": true
     },
     "pushEvent": "Chose social approach."
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb9_d",
    "text": "Selfish action",
    "goTo": "filler_branch_10",
    "effects": {
     "inventoryAdd": "resource",
     "persona": {
      "rude": 1
     },
     "flags": {
      "route_rude": true
     },
     "pushEvent": "Chose selfish approach."
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_9"
  ]
 },
 "filler_branch_10": {
  "id": "filler_branch_10",
  "text": "Scene 10: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb10_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_11",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 10."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb10_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_12",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 10."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb10_c",
    "text": "Help others",
    "goTo": "filler_branch_13",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 10."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb10_b",
    "text": "Careful action",
    "goTo": "filler_branch_12",
    "effects": {
     "stats": {
      "stamina": -1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb10_c",
    "text": "Social action",
    "goTo": "filler_branch_13",
    "effects": {
     "relationships": {
      "Survivors": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb10_d",
    "text": "Selfish action",
    "goTo": "filler_branch_11",
    "effects": {
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_10"
  ]
 },
 "filler_branch_11": {
  "id": "filler_branch_11",
  "text": "Scene 11: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb11_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_12",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 11."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb11_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_13",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 11."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb11_c",
    "text": "Help others",
    "goTo": "filler_branch_14",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 11."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "fb11_b",
    "text": "Careful action",
    "goTo": "filler_branch_13",
    "effects": {
     "stats": {
      "stamina": -1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb11_c",
    "text": "Social action",
    "goTo": "filler_branch_14",
    "effects": {
     "relationships": {
      "Survivors": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb11_d",
    "text": "Selfish action",
    "goTo": "filler_branch_12",
    "effects": {
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_11"
  ]
 },
 "filler_branch_12": {
  "id": "filler_branch_12",
  "text": "Scene 12: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb12_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_13",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 12."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb12_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_14",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 12."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb12_c",
    "text": "Help others",
    "goTo": "filler_branch_15",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 12."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "fb12_b",
    "text": "Careful action",
    "goTo": "filler_branch_14",
    "effects": {
     "stats": {
      "stamina": -1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb12_c",
    "text": "Social action",
    "goTo": "filler_branch_15",
    "effects": {
     "relationships": {
      "Survivors": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb12_d",
    "text": "Selfish action",
    "goTo": "filler_branch_13",
    "effects": {
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_12"
  ]
 },
 "filler_branch_13": {
  "id": "filler_branch_13",
  "text": "Scene 13: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb13_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_14",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 13."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb13_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_15",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 13."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb13_c",
    "text": "Help others",
    "goTo": "filler_branch_16",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 13."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb13_b",
    "text": "Careful action",
    "goTo": "filler_branch_15",
    "effects": {
     "stats": {
      "stamina": -1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb13_c",
    "text": "Social action",
    "goTo": "filler_branch_16",
    "effects": {
     "relationships": {
      "Survivors": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb13_d",
    "text": "Selfish action",
    "goTo": "filler_branch_14",
    "effects": {
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_13"
  ]
 },
 "filler_branch_14": {
  "id": "filler_branch_14",
  "text": "Scene 14: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb14_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_15",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 14."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb14_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_16",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 14."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb14_c",
    "text": "Help others",
    "goTo": "filler_branch_17",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 14."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb14_b",
    "text": "Careful action",
    "goTo": "filler_branch_16",
    "effects": {
     "stats": {
      "stamina": -1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb14_c",
    "text": "Social action",
    "goTo": "filler_branch_17",
    "effects": {
     "relationships": {
      "Survivors": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb14_d",
    "text": "Selfish action",
    "goTo": "filler_branch_15",
    "effects": {
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_14"
  ]
 },
 "filler_branch_15": {
  "id": "filler_branch_15",
  "text": "Scene 15: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb15_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_16",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 15."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb15_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_17",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 15."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb15_c",
    "text": "Help others",
    "goTo": "filler_branch_18",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 15."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "fb15_b",
    "text": "Careful action",
    "goTo": "filler_branch_17",
    "effects": {
     "stats": {
      "stamina": -1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb15_c",
    "text": "Social action",
    "goTo": "filler_branch_18",
    "effects": {
     "relationships": {
      "Survivors": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb15_d",
    "text": "Selfish action",
    "goTo": "filler_branch_16",
    "effects": {
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_15"
  ]
 },
 "filler_branch_16": {
  "id": "filler_branch_16",
  "text": "Scene 16: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb16_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_17",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 16."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb16_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_18",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 16."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb16_c",
    "text": "Help others",
    "goTo": "filler_branch_19",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 16."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "fb16_b",
    "text": "Careful action",
    "goTo": "filler_branch_18",
    "effects": {
     "stats": {
      "stamina": -1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb16_c",
    "text": "Social action",
    "goTo": "filler_branch_19",
    "effects": {
     "relationships": {
      "Survivors": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb16_d",
    "text": "Selfish action",
    "goTo": "filler_branch_17",
    "effects": {
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_16"
  ]
 },
 "filler_branch_17": {
  "id": "filler_branch_17",
  "text": "Scene 17: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb17_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_18",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 17."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb17_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_19",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 17."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb17_c",
    "text": "Help others",
    "goTo": "filler_branch_0",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 17."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb17_b",
    "text": "Careful action",
    "goTo": "filler_branch_19",
    "effects": {
     "stats": {
      "stamina": -1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb17_c",
    "text": "Social action",
    "goTo": "filler_branch_0",
    "effects": {
     "relationships": {
      "Survivors": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb17_d",
    "text": "Selfish action",
    "goTo": "filler_branch_18",
    "effects": {
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_17"
  ]
 },
 "filler_branch_18": {
  "id": "filler_branch_18",
  "text": "Scene 18: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb18_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_19",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 18."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb18_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_0",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 18."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb18_c",
    "text": "Help others",
    "goTo": "filler_branch_1",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 18."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb18_b",
    "text": "Careful action",
    "goTo": "filler_branch_0",
    "effects": {
     "stats": {
      "stamina": -1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb18_c",
    "text": "Social action",
    "goTo": "filler_branch_1",
    "effects": {
     "relationships": {
      "Survivors": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb18_d",
    "text": "Selfish action",
    "goTo": "filler_branch_19",
    "effects": {
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_18"
  ]
 },
 "filler_branch_19": {
  "id": "filler_branch_19",
  "text": "Scene 19: You find yourself in a complex situation where your previous choices have led to unexpected consequences. The world around you has changed, and you must adapt to survive. Your decisions will shape not just your fate, but the fate of those around you.",
  "choices": [
   {
    "id": "fb19_a",
    "text": "Take decisive action",
    "goTo": "filler_branch_0",
    "effects": {
     "stats": {
      "stress": 1
     },
     "pushEvent": "Took decisive action in scene 19."
    },
    "tags": [
     "action"
    ]
   },
   {
    "id": "fb19_b",
    "text": "Plan carefully",
    "goTo": "filler_branch_1",
    "effects": {
     "stats": {
      "stamina": -1,
      "stress": -1
     },
     "pushEvent": "Planned carefully in scene 19."
    },
    "tags": [
     "planning"
    ]
   },
   {
    "id": "fb19_c",
    "text": "Help others",
    "goTo": "filler_branch_2",
    "effects": {
     "stats": {
      "health": -2,
      "morality": 3
     },
     "pushEvent": "Helped others in scene 19."
    },
    "tags": [
     "help"
    ]
   }
  ],
  "tags": [
   "consequence",
   "adaptation"
  ]
 },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "fb19_b",
    "text": "Careful action",
    "goTo": "filler_branch_1",
    "effects": {
     "stats": {
      "stamina": -1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb19_c",
    "text": "Social action",
    "goTo": "filler_branch_2",
    "effects": {
     "relationships": {
      "Survivors": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb19_d",
    "text": "Selfish action",
    "goTo": "filler_branch_0",
    "effects": {
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_19"
  ]
 },
 "hub_convergence": {
  "id": "hub_convergence",
  "text": "All paths lead here. Different journeys, same moment. The stadium convoy is loading. Last chance to escape. Or stay and build something. Your choices brought you here. Where you go next is yours.",
  "choices": [
   {
    "id": "hc_board",
    "text": "Board the convoy\u2014escape the city",
    "goTo": "ending_escaped",
    "effects": {
     "flagsSet": "escaped"
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "hc_stay",
    "text": "Stay\u2014this city needs you",
    "goTo": "ending_stayed",
    "effects": {
     "persona": {
      "nice": 2
     },
     "flagsSet": "stayed"
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "hc_take_over",
    "text": "Take over the convoy\u2014seize control",
    "goTo": "ending_overlord",
    "effects": {
     "persona": {
      "psycho": 3
     },
     "flagsSet": "seized_convoy"
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "hc_disappear",
    "text": "Disappear into the chaos",
    "goTo": "ending_ghost_stair",
    "effects": {
     "persona": {
      "chill": 2
     },
     "flagsSet": "disappeared"
    },
    "tags": [
     "chill"
    ]
   }
  ],
  "tags": [
   "convergence"
  ]
 },
 "ending_escaped": {
  "id": "ending_escaped",
  "text": "ESCAPED: You got out. The city burns behind you. Convoy rolls to safety. You survived. That's all that matters. Or is it? The faces of those left behind haunt the road ahead.",
  "choices": [
   {
    "id": "restart_ending_escaped",
    "text": "Start a new journey",
    "goTo": "intro",
    "effects": {
     "pushEvent": "Started new game after ending_escaped ending."
    },
    "tags": ["restart"]
   }
  ],
  "tags": [
   "ending"
  ],
  "isEnding": true,
  "endingType": "escaped"
 },
 "ending_stayed": {
  "id": "ending_stayed",
  "text": "THE LAST LIGHT: You stayed when everyone ran. Built sanctuary from ruins. The infected couldn't break what you protected. Months later: survivors call your building 'The Light.' Last beacon of hope in the dead city.",
  "choices": [
   {
    "id": "restart_ending_stayed",
    "text": "Start a new journey",
    "goTo": "intro",
    "effects": {
     "pushEvent": "Started new game after ending_stayed ending."
    },
    "tags": ["restart"]
   }
  ],
  "tags": [
   "ending"
  ],
  "isEnding": true,
  "endingType": "stayed"
 },
 "quality_scene_0": {
  "id": "quality_scene_0",
  "text": "Your brutality escalates. Each act more violent than the last. Fear is your tool. Bodies are your message. The city learns to obey or die. Scene 1: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs0_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_1",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs0_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_2",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs0_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_1",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs0_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_3",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "psycho_escalation"
  ]
 },
 "quality_scene_1": {
  "id": "quality_scene_1",
  "text": "You save everyone you can. One by one. Exhaustion builds. Resources deplete. But you don't stop. Can't stop. Won't stop. Scene 2: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs1_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_2",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs1_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_3",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs1_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_2",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs1_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_4",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "nice_overwhelmed"
  ]
 },
 "quality_scene_2": {
  "id": "quality_scene_2",
  "text": "You master the unseen paths. Vents. Rooftops. Sewers. The city's skeleton. You move through shadows. Effective. Silent. Deadly. Scene 3: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs2_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_3",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs2_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_4",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs2_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_3",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs2_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_5",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "chill_ghost_routes"
  ]
 },
 "quality_scene_3": {
  "id": "quality_scene_3",
  "text": "Everything is transactional. Supplies. Safety. Information. You trade it all. Build a network of debts. The city runs through you. Scene 4: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs3_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_4",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs3_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_5",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs3_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_4",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs3_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_6",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "rude_hustle"
  ]
 },
 "quality_scene_4": {
  "id": "quality_scene_4",
  "text": "Your brutality escalates. Each act more violent than the last. Fear is your tool. Bodies are your message. The city learns to obey or die. Scene 5: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs4_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_5",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs4_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_6",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs4_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_5",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs4_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_7",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "psycho_escalation"
  ]
 },
 "quality_scene_5": {
  "id": "quality_scene_5",
  "text": "You save everyone you can. One by one. Exhaustion builds. Resources deplete. But you don't stop. Can't stop. Won't stop. Scene 6: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs5_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_6",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs5_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_7",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs5_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_6",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs5_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_8",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "nice_overwhelmed"
  ]
 },
 "quality_scene_6": {
  "id": "quality_scene_6",
  "text": "You master the unseen paths. Vents. Rooftops. Sewers. The city's skeleton. You move through shadows. Effective. Silent. Deadly. Scene 7: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs6_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_7",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs6_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_8",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs6_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_7",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs6_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_9",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "chill_ghost_routes"
  ]
 },
 "quality_scene_7": {
  "id": "quality_scene_7",
  "text": "Everything is transactional. Supplies. Safety. Information. You trade it all. Build a network of debts. The city runs through you. Scene 8: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs7_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_8",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs7_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_9",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs7_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_8",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs7_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_10",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "rude_hustle"
  ]
 },
 "quality_scene_8": {
  "id": "quality_scene_8",
  "text": "Your brutality escalates. Each act more violent than the last. Fear is your tool. Bodies are your message. The city learns to obey or die. Scene 9: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs8_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_9",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs8_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_10",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs8_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_9",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs8_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_11",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "psycho_escalation"
  ]
 },
 "quality_scene_9": {
  "id": "quality_scene_9",
  "text": "You save everyone you can. One by one. Exhaustion builds. Resources deplete. But you don't stop. Can't stop. Won't stop. Scene 10: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs9_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_10",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs9_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_11",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs9_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_10",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs9_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_12",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "nice_overwhelmed"
  ]
 },
 "quality_scene_10": {
  "id": "quality_scene_10",
  "text": "You master the unseen paths. Vents. Rooftops. Sewers. The city's skeleton. You move through shadows. Effective. Silent. Deadly. Scene 11: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs10_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_11",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs10_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_12",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs10_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_11",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs10_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_13",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "chill_ghost_routes"
  ]
 },
 "quality_scene_11": {
  "id": "quality_scene_11",
  "text": "Everything is transactional. Supplies. Safety. Information. You trade it all. Build a network of debts. The city runs through you. Scene 12: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs11_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_12",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs11_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_13",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs11_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_12",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs11_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_14",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "rude_hustle"
  ]
 },
 "quality_scene_12": {
  "id": "quality_scene_12",
  "text": "Your brutality escalates. Each act more violent than the last. Fear is your tool. Bodies are your message. The city learns to obey or die. Scene 13: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs12_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_13",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs12_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_14",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs12_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_13",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs12_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_15",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "psycho_escalation"
  ]
 },
 "quality_scene_13": {
  "id": "quality_scene_13",
  "text": "You save everyone you can. One by one. Exhaustion builds. Resources deplete. But you don't stop. Can't stop. Won't stop. Scene 14: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs13_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_14",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs13_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_15",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs13_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_14",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs13_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_16",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "nice_overwhelmed"
  ]
 },
 "quality_scene_14": {
  "id": "quality_scene_14",
  "text": "You master the unseen paths. Vents. Rooftops. Sewers. The city's skeleton. You move through shadows. Effective. Silent. Deadly. Scene 15: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs14_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_15",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs14_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_16",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs14_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_15",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs14_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_17",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "chill_ghost_routes"
  ]
 },
 "quality_scene_15": {
  "id": "quality_scene_15",
  "text": "Everything is transactional. Supplies. Safety. Information. You trade it all. Build a network of debts. The city runs through you. Scene 16: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs15_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_16",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs15_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_17",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs15_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_16",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs15_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_18",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "rude_hustle"
  ]
 },
 "quality_scene_16": {
  "id": "quality_scene_16",
  "text": "Your brutality escalates. Each act more violent than the last. Fear is your tool. Bodies are your message. The city learns to obey or die. Scene 17: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs16_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_17",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs16_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_18",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs16_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_17",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs16_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_19",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "psycho_escalation"
  ]
 },
 "quality_scene_17": {
  "id": "quality_scene_17",
  "text": "You save everyone you can. One by one. Exhaustion builds. Resources deplete. But you don't stop. Can't stop. Won't stop. Scene 18: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs17_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_18",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs17_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_19",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs17_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_18",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs17_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_20",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "nice_overwhelmed"
  ]
 },
 "quality_scene_18": {
  "id": "quality_scene_18",
  "text": "You master the unseen paths. Vents. Rooftops. Sewers. The city's skeleton. You move through shadows. Effective. Silent. Deadly. Scene 19: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs18_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_19",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs18_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_20",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs18_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_19",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs18_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_21",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "chill_ghost_routes"
  ]
 },
 "quality_scene_19": {
  "id": "quality_scene_19",
  "text": "Everything is transactional. Supplies. Safety. Information. You trade it all. Build a network of debts. The city runs through you. Scene 20: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs19_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_20",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs19_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_21",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs19_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_20",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs19_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_22",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "rude_hustle"
  ]
 },
 "quality_scene_20": {
  "id": "quality_scene_20",
  "text": "Your brutality escalates. Each act more violent than the last. Fear is your tool. Bodies are your message. The city learns to obey or die. Scene 21: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs20_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_21",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs20_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_22",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs20_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_21",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs20_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_23",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "psycho_escalation"
  ]
 },
 "quality_scene_21": {
  "id": "quality_scene_21",
  "text": "You save everyone you can. One by one. Exhaustion builds. Resources deplete. But you don't stop. Can't stop. Won't stop. Scene 22: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs21_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_22",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs21_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_23",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs21_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_22",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs21_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_24",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "nice_overwhelmed"
  ]
 },
 "quality_scene_22": {
  "id": "quality_scene_22",
  "text": "You master the unseen paths. Vents. Rooftops. Sewers. The city's skeleton. You move through shadows. Effective. Silent. Deadly. Scene 23: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs22_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_23",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs22_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_24",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs22_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_23",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs22_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_25",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "chill_ghost_routes"
  ]
 },
 "quality_scene_23": {
  "id": "quality_scene_23",
  "text": "Everything is transactional. Supplies. Safety. Information. You trade it all. Build a network of debts. The city runs through you. Scene 24: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs23_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_24",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs23_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_25",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs23_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_24",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs23_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_26",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "rude_hustle"
  ]
 },
 "quality_scene_24": {
  "id": "quality_scene_24",
  "text": "Your brutality escalates. Each act more violent than the last. Fear is your tool. Bodies are your message. The city learns to obey or die. Scene 25: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs24_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_25",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs24_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_26",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs24_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_25",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs24_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_27",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "psycho_escalation"
  ]
 },
 "quality_scene_25": {
  "id": "quality_scene_25",
  "text": "You save everyone you can. One by one. Exhaustion builds. Resources deplete. But you don't stop. Can't stop. Won't stop. Scene 26: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs25_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_26",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs25_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_27",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs25_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_26",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs25_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_28",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "nice_overwhelmed"
  ]
 },
 "quality_scene_26": {
  "id": "quality_scene_26",
  "text": "You master the unseen paths. Vents. Rooftops. Sewers. The city's skeleton. You move through shadows. Effective. Silent. Deadly. Scene 27: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs26_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_27",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs26_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_28",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs26_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_27",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs26_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_29",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "chill_ghost_routes"
  ]
 },
 "quality_scene_27": {
  "id": "quality_scene_27",
  "text": "Everything is transactional. Supplies. Safety. Information. You trade it all. Build a network of debts. The city runs through you. Scene 28: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs27_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_28",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs27_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_29",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs27_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_28",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs27_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_30",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "rude_hustle"
  ]
 },
 "quality_scene_28": {
  "id": "quality_scene_28",
  "text": "Your brutality escalates. Each act more violent than the last. Fear is your tool. Bodies are your message. The city learns to obey or die. Scene 29: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs28_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_29",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs28_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_30",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs28_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_29",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs28_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_31",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "psycho_escalation"
  ]
 },
 "quality_scene_29": {
  "id": "quality_scene_29",
  "text": "You save everyone you can. One by one. Exhaustion builds. Resources deplete. But you don't stop. Can't stop. Won't stop. Scene 30: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs29_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_30",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs29_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_31",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs29_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_30",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs29_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_32",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "nice_overwhelmed"
  ]
 },
 "quality_scene_30": {
  "id": "quality_scene_30",
  "text": "You master the unseen paths. Vents. Rooftops. Sewers. The city's skeleton. You move through shadows. Effective. Silent. Deadly. Scene 31: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs30_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_31",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs30_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_32",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs30_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_31",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs30_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_33",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "chill_ghost_routes"
  ]
 },
 "quality_scene_31": {
  "id": "quality_scene_31",
  "text": "Everything is transactional. Supplies. Safety. Information. You trade it all. Build a network of debts. The city runs through you. Scene 32: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs31_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_32",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs31_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_33",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs31_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_32",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs31_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_34",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "rude_hustle"
  ]
 },
 "quality_scene_32": {
  "id": "quality_scene_32",
  "text": "Your brutality escalates. Each act more violent than the last. Fear is your tool. Bodies are your message. The city learns to obey or die. Scene 33: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs32_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_33",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs32_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_34",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs32_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_33",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs32_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_0",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "psycho_escalation"
  ]
 },
 "quality_scene_33": {
  "id": "quality_scene_33",
  "text": "You save everyone you can. One by one. Exhaustion builds. Resources deplete. But you don't stop. Can't stop. Won't stop. Scene 34: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs33_a",
    "text": "Push forward relentlessly",
    "goTo": "quality_scene_34",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs33_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_0",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs33_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_34",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs33_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_1",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "nice_overwhelmed"
  ]
 },
 "quality_scene_34": {
  "id": "quality_scene_34",
  "text": "You master the unseen paths. Vents. Rooftops. Sewers. The city's skeleton. You move through shadows. Effective. Silent. Deadly. Scene 35: Every choice cascades. Your personality solidifies. Path to ending clears.",
  "choices": [
   {
    "id": "qs34_a",
    "text": "Push forward relentlessly",
    "goTo": "ending_ghost_stair",
    "effects": {
     "stats": {
      "stress": 2
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "qs34_b",
    "text": "Help those you encounter",
    "goTo": "quality_scene_1",
    "effects": {
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "qs34_c",
    "text": "Move efficiently, minimize risk",
    "goTo": "quality_scene_0",
    "effects": {
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "qs34_d",
    "text": "Exploit opportunities",
    "goTo": "quality_scene_2",
    "effects": {
     "persona": {
      "rude": 1
     },
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "chill_ghost_routes"
  ]
 },
 "ending_ashes": {
  "id": "ending_ashes",
  "text": "ASHES & ASHES: The city fell. You fell with it. Every choice led here. The infected won. Or maybe no one won. Just ashes. Just silence. Just the end.",
  "choices": [
   {
    "id": "restart_ending_ashes",
    "text": "Start a new journey",
    "goTo": "intro",
    "effects": {
     "pushEvent": "Started new game after ending_ashes ending."
    },
    "tags": ["restart"]
   }
  ],
  "tags": [
   "ending"
  ],
  "isEnding": true,
  "endingType": "ashes"
 },
"alex_bond_hard": {
 "id": "alex_bond_hard",
 "text": "Alex doesn't sugarcoat. 'We survive. Period. Not friends. Not family. Partners who keep each other breathing.' They're right. This world doesn't reward sentiment. But their eyes betray them—there's care beneath the callousness. 'You pulled me in when you could've left me to die. I remember that. But don't expect me to go soft.' Fair enough.",
 "choices": [
  {
   "id": "bh_agree",
   "text": "Agree. Survival comes first.",
   "goTo": "act1_family_hub",
   "effects": {"persona": {"chill": 2}, "relationships": {"Alex": 3}, "flagsSet": ["bond_hardened"], "pushEvent": "'Works for me. No illusions.' Alex nods. Partnership formed on brutal honesty."},
   "tags": ["chill"]
  },
  {
   "id": "bh_soften",
   "text": "Try to soften them. We can care AND survive.",
   "goTo": "act1_family_hub",
   "effects": {"persona": {"nice": 1}, "relationships": {"Alex": 4}, "flagsSet": ["tried_softening"], "pushEvent": "'Maybe. Don't push it.' They don't reject it entirely. Progress."},
   "tags": ["nice"]
  },
  {
   "id": "bh_colder",
   "text": "Even colder. Pure transaction.",
   "goTo": "act1_family_hub",
   "effects": {"persona": {"rude": 2}, "relationships": {"Alex": 1}, "flagsSet": ["transaction_only"], "pushEvent": "'Right. Just tools to each other.' Alex's face hardens. Message received."},
   "tags": ["rude"]
  }
 ],
 "tags": ["bond_path"]
},
"alex_bond_purpose": {
 "id": "alex_bond_purpose",
 "text": "Alex looks at you with newfound intensity. 'Before this, I fixed fuse boxes. Small problems, small solutions. But this? We're building something. A reason to survive beyond just... surviving.' They're searching for meaning in the chaos. You recognize that look—it's the same one you see in the mirror.",
 "choices": [
  {
   "id": "bp_build_together",
   "text": "Let's build something that matters.",
   "goTo": "act1_family_hub",
   "effects": {"persona": {"nice": 2, "protector": 1}, "relationships": {"Alex": 6}, "flagsSet": ["shared_purpose"], "pushEvent": "'Together then. Not just surviving. Living.' Alex extends hand. You shake. Pact made."},
   "tags": ["nice"]
  },
  {
   "id": "bp_dont_need_meaning",
   "text": "Don't need meaning. Just need to survive.",
   "goTo": "act1_family_hub",
   "effects": {"persona": {"chill": 1}, "relationships": {"Alex": 3}, "pushEvent": "'Fair enough. Maybe I'm overthinking.' They back off. Practical wins."},
   "tags": ["chill"]
  },
  {
   "id": "bp_use_drive",
   "text": "Use that drive. Channel it into action.",
   "goTo": "act1_family_hub",
   "effects": {"persona": {"protector": 1}, "relationships": {"Alex": 5}, "flagsSet": ["purpose_channeled"], "pushEvent": "'Yes. Action. Not philosophy.' Alex is energized. Ready to move."},
   "tags": ["protector"]
  }
 ],
 "tags": ["bond_path"]
}
,
"alex_cautious": {
 "id": "alex_cautious",
 "text": "Alex approaches you with a serious expression. 'I've been thinking about what happened back there. We need to talk about trust, about what we're willing to do to survive. I'm not sure I can keep going like this.'",
 "choices": [
  {
   "id": "alex_cauti_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_cautious resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_cauti_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_cautious resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_cauti_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_cautious resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_debt": {
 "id": "alex_debt",
 "text": "Alex sits across from you, cleaning a weapon. 'You know, I used to think I knew who I was. But this outbreak... it's changed everything. I've done things I never thought I'd do. Have you?'",
 "choices": [
  {
   "id": "alex_debt_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_debt resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_debt_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_debt resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_debt_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_debt resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_dependent_tool": {
 "id": "alex_dependent_tool",
 "text": "Alex looks at you with concern. 'I've been watching you make decisions. Some of them... they scare me. But I understand why you do them. I just need to know - are we still on the same side?'",
 "choices": [
  {
   "id": "alex_depen_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_dependent_tool resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_depen_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_dependent_tool resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_depen_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_dependent_tool resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_dies_after_proof": {
 "id": "alex_dies_after_proof",
 "text": "Alex confronts you directly. 'I saw what you did to those infected. The way you handled it... it was efficient, but it was also cold. I need to know - is this who you really are now?'",
 "choices": [
  {
   "id": "alex_dies__a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_dies_after_proof resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_dies__b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_dies_after_proof resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_dies__c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_dies_after_proof resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_grateful_conditional": {
 "id": "alex_grateful_conditional",
 "text": "Alex approaches cautiously. 'I've been thinking about our partnership. We've survived this long together, but I'm starting to wonder if we're still compatible. Your methods... they're getting darker.'",
 "choices": [
  {
   "id": "alex_grate_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_grateful_conditional resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_grate_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_grateful_conditional resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_grate_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_grateful_conditional resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_grateful_lucky": {
 "id": "alex_grateful_lucky",
 "text": "Alex sits in silence for a moment, then speaks. 'I've been having nightmares about the people we've left behind. The choices we've made. Do you ever wonder if we're becoming the monsters we're fighting?'",
 "choices": [
  {
   "id": "alex_grate_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_grateful_lucky resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_grate_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_grateful_lucky resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_grate_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_grateful_lucky resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_grateful_selfish": {
 "id": "alex_grateful_selfish",
 "text": "Alex looks at you with a mix of respect and fear. 'You've kept us alive, I'll give you that. But at what cost? I'm starting to question whether survival is worth losing our humanity.'",
 "choices": [
  {
   "id": "alex_grate_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_grateful_selfish resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_grate_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_grateful_selfish resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_grate_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_grateful_selfish resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_guilt_lever": {
 "id": "alex_guilt_lever",
 "text": "Alex approaches with a determined look. 'I've decided something. I'm not going to let this world change who I am. I want to help people, not just survive. Can you understand that?'",
 "choices": [
  {
   "id": "alex_guilt_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_guilt_lever resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_guilt_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_guilt_lever resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_guilt_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_guilt_lever resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_learns_independence": {
 "id": "alex_learns_independence",
 "text": "Alex sits down heavily. 'I've been thinking about the future. If we make it out of this, what kind of people will we be? Will we be able to go back to normal life after everything we've done?'",
 "choices": [
  {
   "id": "alex_learn_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_learns_independence resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_learn_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_learns_independence resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_learn_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_learns_independence resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_professional": {
 "id": "alex_professional",
 "text": "Alex looks at you with new understanding. 'I've been watching you protect us, make the hard choices. I realize now that leadership isn't about being liked - it's about keeping people alive. I respect that.'",
 "choices": [
  {
   "id": "alex_profe_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_professional resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_profe_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_professional resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_profe_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_professional resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_respect": {
 "id": "alex_respect",
 "text": "Alex approaches with a small smile. 'You know, despite everything, I'm glad we're in this together. You've taught me that sometimes you have to be ruthless to be kind. I get it now.'",
 "choices": [
  {
   "id": "alex_respe_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_respect resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_respe_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_respect resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_respe_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_respect resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_sees_clinical_killer": {
 "id": "alex_sees_clinical_killer",
 "text": "Alex sits quietly, then speaks softly. 'I've been thinking about trust. In this world, trust is everything. I trust you to make the right decisions, even when they're hard. Do you trust me?'",
 "choices": [
  {
   "id": "alex_sees__a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_sees_clinical_killer resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_sees__b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_sees_clinical_killer resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_sees__c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_sees_clinical_killer resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_sees_darkness": {
 "id": "alex_sees_darkness",
 "text": "Alex looks at you with admiration. 'You've become someone I never expected. Strong, decisive, willing to do what needs to be done. I'm proud to be your partner in this.'",
 "choices": [
  {
   "id": "alex_sees__a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_sees_darkness resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_sees__b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_sees_darkness resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_sees__c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_sees_darkness resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_sees_necessary_violence": {
 "id": "alex_sees_necessary_violence",
 "text": "Alex approaches with concern. 'I've been worried about you. You've been carrying so much responsibility, making all the hard choices. You don't have to do this alone - I'm here too.'",
 "choices": [
  {
   "id": "alex_sees__a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_sees_necessary_violence resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_sees__b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_sees_necessary_violence resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_sees__c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_sees_necessary_violence resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_sees_personal": {
 "id": "alex_sees_personal",
 "text": "Alex sits across from you, studying your face. 'I've been thinking about what makes a person good or evil. Is it their actions, or their intentions? You've made me question everything I thought I knew.'",
 "choices": [
  {
   "id": "alex_sees__a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_sees_personal resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_sees__b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_sees_personal resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_sees__c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_sees_personal resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_sees_reactive": {
 "id": "alex_sees_reactive",
 "text": "Alex looks at you with newfound respect. 'I used to think I knew what was right and wrong. But you've shown me that in this world, sometimes the right thing is the hardest thing. I understand now.'",
 "choices": [
  {
   "id": "alex_sees__a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_sees_reactive resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_sees__b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_sees_reactive resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_sees__c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_sees_reactive resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_sees_transactional": {
 "id": "alex_sees_transactional",
 "text": "Alex approaches with a serious expression. 'I've been watching you make impossible choices. I realize now that leadership means accepting the burden of those decisions. I'm ready to share that burden with you.'",
 "choices": [
  {
   "id": "alex_sees__a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_sees_transactional resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_sees__b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_sees_transactional resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_sees__c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_sees_transactional resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_test_solo": {
 "id": "alex_test_solo",
 "text": "Alex sits quietly, then speaks with conviction. 'I've decided that I want to be more like you. Strong, decisive, willing to do what's necessary. Will you teach me how to be a better survivor?'",
 "choices": [
  {
   "id": "alex_test__a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_test_solo resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_test__b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_test_solo resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_test__c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_test_solo resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_traumatized_harsh": {
 "id": "alex_traumatized_harsh",
 "text": "Alex looks at you with understanding. 'I've been thinking about our relationship. We've been through so much together. I realize now that we're not just partners - we're family. And family protects each other.'",
 "choices": [
  {
   "id": "alex_traum_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_traumatized_harsh resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_traum_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_traumatized_harsh resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_traum_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_traumatized_harsh resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_uncertain": {
 "id": "alex_uncertain",
 "text": "Alex approaches with a determined look. 'I've been reflecting on everything we've been through. You've shown me what real strength looks like. I want to be worthy of your trust and partnership.'",
 "choices": [
  {
   "id": "alex_uncer_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_uncertain resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_uncer_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_uncertain resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_uncer_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_uncertain resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"alex_uncomfortable_silence": {
 "id": "alex_uncomfortable_silence",
 "text": "Alex sits down next to you. 'I've been thinking about the future. Whatever happens next, I want you to know that I believe in you. I believe in us. We'll get through this together.'",
 "choices": [
  {
   "id": "alex_uncom_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_uncomfortable_silence resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_uncom_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_uncomfortable_silence resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_uncom_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_uncomfortable_silence resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"apology_deeper_accepted": {
 "id": "apology_deeper_accepted",
 "text": "Your deeper apology lands. Alex exhales. The tension breaks. 'Okay. I get it. Fear makes us into people we don't recognize.' They pause. 'I'm sorry too. For expecting you to just trust. In this world.' A moment of mutual understanding. The hurt isn't gone but it's... acknowledged. You both move forward. Alex extends a hand. 'Start over? Hi. I'm Alex. I survive apocalypses and fix fuse boxes. Apparently in that order now.' A weak smile. Real though.",
 "choices": [
  {
   "id": "ada_start_over",
   "text": "Start over. Clean slate.",
   "goTo": "apology_relationship_rebuilt",
   "effects": {
    "stats": {
     "stress": -3
    },
    "persona": {
     "nice": 2
    },
    "relationships": {
     "Alex": 8
    },
    "flagsSet": [
     "relationship_rebuilt"
    ],
    "pushEvent": "'Clean slate. I like that.' Alex's smile grows. Trust begins to heal."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "ada_cautious_forward",
   "text": "Move forward, but cautiously.",
   "goTo": "apology_cautious_trust",
   "effects": {
    "persona": {
     "chill": 1
    },
    "relationships": {
     "Alex": 6
    },
    "flagsSet": [
     "cautious_trust"
    ],
    "pushEvent": "'Fair enough. Trust takes time.' Alex nods. They understand."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "ada_professional",
   "text": "Keep it professional. Partners, not friends.",
   "goTo": "apology_professional_only",
   "effects": {
    "persona": {
     "chill": 2
    },
    "relationships": {
     "Alex": 4
    },
    "flagsSet": [
     "professional_only"
    ],
    "pushEvent": "'Partners. I can work with that.' Alex's expression becomes neutral. Business mode."
   },
   "tags": [
    "chill"
   ]
  }
 ],
 "tags": [
  "apology_resolved",
  "act1"
 ]
},
"apology_relationship_rebuilt": {
 "id": "apology_relationship_rebuilt",
 "text": "Day 2. The morning after. Alex is making coffee—real coffee, from their emergency stash. 'Figured we earned it,' they say. The apartment feels different. Warmer. Less like a bunker, more like... home. 'So,' Alex says, 'what's the plan? We can't stay here forever.' They're right. The building won't hold. But for now, you have each other. And that's something.",
 "choices": [
  {
   "id": "arr_plan_together",
   "text": "Let's plan together. What do you think?",
   "goTo": "day4_morning",
   "effects": {
    "time": 1,
    "persona": {"nice": 1},
    "relationships": {"Alex": 1},
    "flagsSet": ["collaborative_planning"],
    "pushEvent": "'I like that. Two heads better than one.' Alex pulls out a map. Planning begins."
   },
   "tags": ["nice"]
  },
  {
   "id": "arr_secure_building",
   "text": "First, let's secure this building properly.",
   "goTo": "day4_morning",
   "effects": {
    "time": 2,
    "persona": {"chill": 1},
    "stats": {"stress": -1},
    "flagsSet": ["building_secured"],
    "pushEvent": "'Smart. Home base first.' Alex nods. 'I know this building's weak points.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "arr_scout_area",
   "text": "We need to scout the area. See what's out there.",
   "goTo": "day4_morning",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "stats": {"stress": 1},
    "flagsSet": ["area_scouted"],
    "pushEvent": "'Reconnaissance. Good call.' Alex grabs their gear. 'I'll go with you.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day2", "relationship_strong"]
},
"apology_cautious_trust": {
 "id": "apology_cautious_trust",
 "text": "Day 2. Alex is cautious but present. They've set up their own corner of the apartment—not hiding, but maintaining distance. 'I appreciate the apology,' they say. 'But trust... that takes time.' Fair enough. The world taught them that lesson hard. 'So what's next?' they ask. 'We can't just... wait here.'",
 "choices": [
  {
   "id": "act_build_trust",
   "text": "Let's build trust through action.",
   "goTo": "day2_trust_building",
   "effects": {
    "time": 1,
    "persona": {"nice": 1},
    "relationships": {"Alex": 2},
    "flagsSet": ["trust_building"],
    "pushEvent": "'Actions. I can respect that.' Alex's guard lowers slightly."
   },
   "tags": ["nice"]
  },
  {
   "id": "act_practical_first",
   "text": "Focus on practical survival first.",
   "goTo": "day2_practical_focus",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "flagsSet": ["practical_focus"],
    "pushEvent": "'Practical. I like practical.' Alex relaxes. Less pressure."
   },
   "tags": ["chill"]
  },
  {
   "id": "act_give_space",
   "text": "Give them space. Let them come to you.",
   "goTo": "day2_give_space",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "flagsSet": ["respects_boundaries"],
    "pushEvent": "'Thank you. For understanding.' Alex's expression softens."
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day2", "cautious_trust"]
},
"apology_professional_only": {
 "id": "apology_professional_only",
 "text": "Day 2. Alex has set up a professional distance. They're efficient, helpful, but emotionally guarded. 'Partners,' they say. 'That works.' They've organized the supplies, checked the perimeter, made themselves useful. But there's a wall there. Respectful, but present. 'So what's the operational plan?' they ask. Business mode.",
 "choices": [
  {
   "id": "apo_accept_dynamic",
   "text": "Accept the professional dynamic.",
   "goTo": "day2_professional_partnership",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "flagsSet": ["professional_dynamic"],
    "pushEvent": "'Understood. Professional partnership.' Alex nods. Clear boundaries established."
   },
   "tags": ["chill"]
  },
  {
   "id": "apo_try_warmth",
   "text": "Try to add some warmth to the partnership.",
   "goTo": "day2_warmth_attempt",
   "effects": {
    "time": 1,
    "persona": {"nice": 1},
    "relationships": {"Alex": 2},
    "flagsSet": ["warmth_attempted"],
    "pushEvent": "'I... appreciate that.' Alex's guard wavers slightly."
   },
   "tags": ["nice"]
  },
  {
   "id": "apo_keep_distance",
   "text": "Keep the distance. It's safer this way.",
   "goTo": "day2_maintain_distance",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 0},
    "flagsSet": ["distance_maintained"],
    "pushEvent": "'Right. Safer.' Alex's expression remains neutral."
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day2", "professional"]
},
"day2_planning_session": {
 "id": "day2_planning_session",
 "text": "Day 2, 10:00 AM. Alex spreads a city map on the table. 'Okay, here's what I know,' they say, pointing. 'The building's structural weak points are here, here, and here.' They mark spots with a pen. 'There's a supply cache three blocks east—pharmacy that might still have meds. And...' they pause. 'There's a family on floor 4. Martinez family. Two kids, elderly grandmother. They're... they're not doing well.'",
 "choices": [
  {
   "id": "d2ps_help_family",
   "text": "We should help the Martinez family.",
   "goTo": "day4_morning",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "flagsSet": ["help_martinez"],
    "pushEvent": "'I was hoping you'd say that.' Alex's eyes light up. 'They're good people.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d2ps_pharmacy_first",
   "text": "Let's hit the pharmacy first. Get supplies.",
   "goTo": "day4_morning",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "flagsSet": ["pharmacy_priority"],
    "pushEvent": "'Smart. Supplies first, then we can help others.' Alex nods approvingly."
   },
   "tags": ["chill"]
  },
  {
   "id": "d2ps_secure_building",
   "text": "First, let's secure this building properly.",
   "goTo": "day4_morning",
   "effects": {
    "time": 2,
    "persona": {"chill": 1},
    "stats": {"stress": -1},
    "flagsSet": ["building_secured"],
    "pushEvent": "'Home base first. Good call.' Alex grabs tools. 'I know this building's weak points.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day2", "planning"]
},
"day2_secure_building": {
 "id": "day2_secure_building",
 "text": "Day 2, 11:00 AM. Alex leads you through the building's weak points. 'This door needs reinforcement,' they say, pointing to the main entrance. 'And these windows on the second floor—they're the biggest vulnerability.' They've brought tools, materials. 'I used to fix everything in this building. Know it like the back of my hand.' The work is methodical, calming. Building something together.",
 "choices": [
  {
   "id": "d2sb_thorough_job",
   "text": "Let's do this right. Thorough job.",
   "goTo": "day4_morning",
   "effects": {
    "time": 3,
    "persona": {"chill": 2},
    "stats": {"stress": -2, "stamina": -1},
    "relationships": {"Alex": 2},
    "flagsSet": ["building_well_secured"],
    "pushEvent": "'This is good work.' Alex smiles. 'Feels like we're building something real.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d2sb_quick_job",
   "text": "Quick job. We have other priorities.",
   "goTo": "day2_building_secured_basic",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "stats": {"stress": -1},
    "relationships": {"Alex": 1},
    "flagsSet": ["building_basic_secured"],
    "pushEvent": "'Efficient. I like that.' Alex nods. 'What's next?'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d2sb_teach_me",
   "text": "Teach me. I want to learn.",
   "goTo": "day2_learning_building",
   "effects": {
    "time": 2,
    "persona": {"nice": 1},
    "stats": {"stress": -1},
    "relationships": {"Alex": 3},
    "flagsSet": ["learning_building"],
    "pushEvent": "'I like teaching.' Alex's face brightens. 'You're a good student.'"
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day2", "building"]
},
"day2_scout_area": {
 "id": "day2_scout_area",
 "text": "Day 2, 12:00 PM. You and Alex gear up for reconnaissance. 'Stay close,' Alex says. 'And quiet.' The building's lobby is a mess—broken glass, scattered papers, the smell of decay. Through the front door, the street is eerily quiet. 'They're out there,' Alex whispers. 'But not here. Not right now.' You can see other buildings, some with lights, some dark. Signs of life. Signs of death.",
 "choices": [
  {
   "id": "d2sa_pharmacy_approach",
   "text": "Let's check out that pharmacy Alex mentioned.",
   "goTo": "day2_pharmacy_scout",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "stats": {"stress": 1},
    "relationships": {"Alex": 1},
    "flagsSet": ["pharmacy_scouted"],
    "pushEvent": "'Good call. Let's see what we're dealing with.' Alex leads the way."
   },
   "tags": ["chill"]
  },
  {
   "id": "d2sa_other_buildings",
   "text": "Let's check other buildings. See who's alive.",
   "goTo": "day2_other_buildings",
   "effects": {
    "time": 1,
    "persona": {"nice": 1},
    "stats": {"stress": 1},
    "relationships": {"Alex": 1},
    "flagsSet": ["other_buildings_scouted"],
    "pushEvent": "'Could be survivors. Could be trouble.' Alex's hand moves to their weapon."
   },
   "tags": ["nice"]
  },
  {
   "id": "d2sa_return_safe",
   "text": "Let's head back. We've seen enough.",
   "goTo": "day2_return_safe",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "stats": {"stress": -1},
    "relationships": {"Alex": 1},
    "flagsSet": ["scout_complete"],
    "pushEvent": "'Smart. No need to push our luck.' Alex nods. 'Back to base.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day2", "scouting"]
},
"day2_help_martinez": {
 "id": "day2_help_martinez",
 "text": "Day 2, 1:00 PM. Floor 4, apartment 4B. The Martinez family's door is barricaded with furniture. You knock gently. 'It's Alex,' Alex calls out. 'From 3B. I brought help.' The door opens a crack. Mrs. Martinez—early 30s, exhausted—peeks out. Behind her, two children, maybe 8 and 10, and an elderly woman in a wheelchair. 'Alex... thank God,' she whispers. 'We're running out of food. And... and my mother needs medicine.'",
 "choices": [
  {
   "id": "d2hm_share_supplies",
   "text": "Share our supplies with them.",
   "goTo": "day2_martinez_helped",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 3},
    "stats": {"stress": -1},
    "flagsSet": ["martinez_helped"],
    "pushEvent": "'Thank you. Thank you so much.' Mrs. Martinez's eyes fill with tears."
   },
   "tags": ["nice"]
  },
  {
   "id": "d2hm_pharmacy_first",
   "text": "Let's get medicine first, then come back.",
   "goTo": "day2_pharmacy_for_martinez",
   "effects": {
    "time": 1,
    "persona": {"nice": 1, "chill": 1},
    "relationships": {"Alex": 2},
    "flagsSet": ["pharmacy_for_martinez"],
    "pushEvent": "'We'll be back. With medicine.' Alex's voice is determined."
   },
   "tags": ["nice"]
  },
  {
   "id": "d2hm_evacuate_them",
   "text": "We should evacuate them to our apartment.",
   "goTo": "day2_evacuate_martinez",
   "effects": {
    "time": 2,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 3},
    "stats": {"stress": 2},
    "flagsSet": ["martinez_evacuated"],
    "pushEvent": "'Safety in numbers.' Alex nods. 'Let's get them out of here.'"
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day2", "martinez"]
},
"day2_pharmacy_raid": {
 "id": "day2_pharmacy_raid",
 "text": "Day 2, 2:00 PM. The pharmacy is three blocks east. You and Alex approach cautiously. The building is intact, but the front door is shattered. 'Looks like someone's been here already,' Alex whispers. Inside, shelves are mostly empty, but there are still some supplies. 'Let's be quick,' Alex says. 'In and out.' You can hear sounds from the back—maybe infected, maybe survivors. The choice is yours.",
 "choices": [
  {
   "id": "d2pr_quick_grab",
   "text": "Quick grab. Take what we can and go.",
   "goTo": "day2_pharmacy_quick",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "stats": {"stress": 1},
    "relationships": {"Alex": 1},
    "inventoryAdd": ["bandages", "painkillers"],
    "flagsSet": ["pharmacy_quick"],
    "pushEvent": "'Efficient. Let's go.' Alex grabs supplies and heads for the door."
   },
   "tags": ["chill"]
  },
  {
   "id": "d2pr_thorough_search",
   "text": "Thorough search. Check the back room.",
   "goTo": "day2_pharmacy_thorough",
   "effects": {
    "time": 2,
    "persona": {"chill": 1},
    "stats": {"stress": 2},
    "relationships": {"Alex": 1},
    "inventoryAdd": ["antibiotics", "morphine", "surgical_kit"],
    "flagsSet": ["pharmacy_thorough"],
    "pushEvent": "'Found the good stuff.' Alex's eyes light up. 'This could save lives.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d2pr_check_sounds",
   "text": "Check those sounds. Could be survivors.",
   "goTo": "day2_pharmacy_survivors",
   "effects": {
    "time": 1,
    "persona": {"nice": 1},
    "stats": {"stress": 2},
    "relationships": {"Alex": 1},
    "flagsSet": ["pharmacy_survivors"],
    "pushEvent": "'Could be someone who needs help.' Alex's hand moves to their weapon."
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day2", "pharmacy"]
},
"day2_building_secured_well": {
 "id": "day2_building_secured_well",
 "text": "Day 2, 3:00 PM. The building is now a fortress. Alex has reinforced every weak point, set up early warning systems, even rigged a simple communication system between floors. 'This is good work,' Alex says, wiping sweat from their brow. 'We've got a real chance here.' The building feels secure, safe. A proper home base. 'So what's next?' Alex asks. 'We've got options now.'",
 "choices": [
  {
   "id": "d2bsw_help_others",
   "text": "Let's help other survivors in the building.",
   "goTo": "day4_morning",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "flagsSet": ["help_others"],
    "pushEvent": "'Good call. We're stronger together.' Alex nods approvingly."
   },
   "tags": ["nice"]
  },
  {
   "id": "d2bsw_scout_area",
   "text": "Let's scout the area. See what's out there.",
   "goTo": "day4_morning",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "flagsSet": ["area_scouted"],
    "pushEvent": "'Reconnaissance. Smart.' Alex grabs their gear."
   },
   "tags": ["chill"]
  },
  {
   "id": "d2bsw_rest_plan",
   "text": "Let's rest and plan. We've earned it.",
   "goTo": "day4_morning",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "stats": {"stress": -2, "stamina": 2},
    "relationships": {"Alex": 1},
    "flagsSet": ["rest_plan"],
    "pushEvent": "'You're right. We've done good work today.' Alex smiles."
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day2", "building_secure"]
},
"day2_hub": {
 "id": "day2_hub",
 "text": "Day 2, Evening. The sun is setting, casting long shadows across the apartment. Alex is cooking something simple—canned food, but it smells like a feast. 'We made it through another day,' they say. 'That's something.' The building feels different now. More like home. Less like a prison. 'Tomorrow,' Alex says, 'we decide what kind of people we want to be in this world.' The choice is yours.",
 "choices": [
  {
   "id": "d2h_hero_path",
   "text": "We help others. That's who we are.",
   "goTo": "day4_morning",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "flagsSet": ["hero_path_chosen"],
    "pushEvent": "'I was hoping you'd say that.' Alex's eyes light up. 'Let's be the good guys.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d2h_survivor_path",
   "text": "We survive. That's what matters.",
   "goTo": "day4_morning",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "flagsSet": ["survivor_path_chosen"],
    "pushEvent": "'Practical. I can respect that.' Alex nods. 'Survival first.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d2h_leader_path",
   "text": "We lead. We build something here.",
   "goTo": "day4_morning",
   "effects": {
    "time": 1,
    "persona": {"protector": 2, "warlord": 1},
    "relationships": {"Alex": 2},
    "flagsSet": ["leader_path_chosen"],
    "pushEvent": "'Ambitious. I like it.' Alex's expression becomes determined. 'Let's build something.'"
   },
   "tags": ["protector"]
  }
 ],
 "tags": ["day2", "hub"]
},
"day3_hero_path": {
 "id": "day3_hero_path",
 "text": "Day 3, Morning. You wake to the sound of knocking. Alex is already up, peering through the peephole. 'It's Mrs. Martinez,' they whisper. 'She looks... scared.' You open the door. Mrs. Martinez is there, her children behind her. 'Please,' she says. 'There are more families. On the other floors. They need help. Food. Medicine. Protection.' Her voice trembles. 'We can't do this alone.'",
 "choices": [
  {
   "id": "d3hp_help_all",
   "text": "We'll help everyone we can.",
   "goTo": "day3_help_all_families",
   "effects": {
    "time": 2,
    "persona": {"nice": 3, "protector": 2},
    "relationships": {"Alex": 3},
    "stats": {"stress": 3, "stamina": -2},
    "flagsSet": ["help_all_families"],
    "pushEvent": "'Thank you. Thank you so much.' Mrs. Martinez's eyes fill with tears."
   },
   "tags": ["nice"]
  },
  {
   "id": "d3hp_organize_effort",
   "text": "Let's organize this properly. Systematically.",
   "goTo": "day3_organize_effort",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "chill": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["organize_effort"],
    "pushEvent": "'Smart. Let's do this right.' Alex nods approvingly."
   },
   "tags": ["nice"]
  },
  {
   "id": "d3hp_limited_help",
   "text": "We'll help, but we have limits.",
   "goTo": "day3_limited_help",
   "effects": {
    "time": 1,
    "persona": {"nice": 1, "chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1},
    "flagsSet": ["limited_help"],
    "pushEvent": "'I understand. Thank you for what you can do.' Mrs. Martinez's expression becomes guarded."
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day3", "hero"]
},
"day3_survivor_path": {
 "id": "day3_survivor_path",
 "text": "Day 3, Morning. Alex is checking the perimeter. 'Building's holding,' they report. 'But we need to think long-term.' They spread a map on the table. 'Food won't last forever. Medicine will run out. We need a plan.' They point to various locations. 'Supply caches. Safe routes. Fallback positions.' Their voice is practical, methodical. 'Survival is about preparation.'",
 "choices": [
  {
   "id": "d3sp_supply_runs",
   "text": "Let's plan supply runs. Systematic approach.",
   "goTo": "day3_supply_runs",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["supply_runs_planned"],
    "pushEvent": "'Good thinking. Let's map out the best routes.' Alex's eyes light up."
   },
   "tags": ["chill"]
  },
  {
   "id": "d3sp_fortify_position",
   "text": "Let's fortify our position. Make it unassailable.",
   "goTo": "day3_fortify_position",
   "effects": {
    "time": 2,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1, "stamina": -1},
    "flagsSet": ["position_fortified"],
    "pushEvent": "'Defense in depth. I like it.' Alex grabs tools."
   },
   "tags": ["chill"]
  },
  {
   "id": "d3sp_scout_escape",
   "text": "Let's scout escape routes. Plan for the worst.",
   "goTo": "day3_scout_escape",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1},
    "flagsSet": ["escape_routes_scouted"],
    "pushEvent": "'Always have a backup plan.' Alex nods. 'Smart.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day3", "survivor"]
},
"day3_leader_path": {
 "id": "day3_leader_path",
 "text": "Day 3, Morning. Alex is organizing supplies. 'We've got something here,' they say. 'A real opportunity.' They look at you. 'This building. These people. We could build something. A community. A safe zone.' Their voice is excited, determined. 'But it takes leadership. Someone to make the hard calls. Someone people can trust.' They pause. 'I think that's you.'",
 "choices": [
  {
   "id": "d3lp_accept_leadership",
   "text": "I'll lead. We'll build something here.",
   "goTo": "day3_accept_leadership",
   "effects": {
    "time": 1,
    "persona": {"protector": 2, "warlord": 1},
    "relationships": {"Alex": 3},
    "stats": {"stress": 2},
    "flagsSet": ["leadership_accepted"],
    "pushEvent": "'Good. We need someone to step up.' Alex's expression becomes determined."
   },
   "tags": ["protector"]
  },
  {
   "id": "d3lp_shared_leadership",
   "text": "We lead together. Equal partners.",
   "goTo": "day3_shared_leadership",
   "effects": {
    "time": 1,
    "persona": {"protector": 1, "nice": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["shared_leadership"],
    "pushEvent": "'Partners. I like that.' Alex's eyes light up."
   },
   "tags": ["nice"]
  },
  {
   "id": "d3lp_not_ready",
   "text": "I'm not ready for that kind of responsibility.",
   "goTo": "day3_not_ready_leadership",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["leadership_declined"],
    "pushEvent": "'Fair enough. Maybe later.' Alex's expression becomes neutral."
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day3", "leader"]
},
"day3_to_act1_hub": {
 "id": "day3_to_act1_hub",
 "text": "Day 3, Evening. The sun sets on another day of survival. You and Alex sit in the apartment, planning tomorrow. 'We've come a long way,' Alex says. 'From strangers to... whatever we are now.' They look at you. 'Partners. Friends. Family. Whatever you want to call it.' The building feels alive now. People moving between floors. Children's laughter echoing in the halls. 'We're building something here,' Alex says. 'Something real.'",
 "choices": [
  {
   "id": "d3tah_continue_building",
   "text": "Let's keep building. This is just the beginning.",
   "goTo": "act1_family_hub",
   "effects": {
    "time": 1,
    "persona": {"nice": 1, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": -1},
    "flagsSet": ["continue_building"],
    "pushEvent": "'I like the sound of that.' Alex's eyes light up. 'Let's see what we can build.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d3tah_consolidate_gains",
   "text": "Let's consolidate what we have. Make it solid.",
   "goTo": "act1_family_hub",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["consolidate_gains"],
    "pushEvent": "'Smart. Build on what works.' Alex nods approvingly."
   },
   "tags": ["chill"]
  },
  {
   "id": "d3tah_expand_influence",
   "text": "Let's expand. Reach out to other buildings.",
   "goTo": "act1_family_hub",
   "effects": {
    "time": 1,
    "persona": {"protector": 1, "warlord": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["expand_influence"],
    "pushEvent": "'Ambitious. I like it.' Alex's expression becomes determined."
   },
   "tags": ["protector"]
  }
 ],
 "tags": ["day3", "transition"]
},
"day4_morning": {
 "id": "day4_morning",
 "text": "Day 4, 6:00 AM. The building wakes slowly. You hear footsteps in the halls—survivors moving between apartments, checking on each other. Alex is already up, brewing coffee from their dwindling supply. 'Morning,' they say quietly. 'Sleep okay?' The question is loaded. Last night, you both heard the screams from the street. Infected. Getting closer. 'We need to talk about today,' Alex says. 'About what we're building here.'",
 "choices": [
  {
   "id": "d4m_community_meeting",
   "text": "Let's call a community meeting. Get everyone on the same page.",
   "goTo": "day4_community_meeting",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["community_meeting_called"],
    "pushEvent": "'Good idea. We need to be organized.' Alex nods. 'I'll help you prepare.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d4m_supply_assessment",
   "text": "Let's assess our supplies. See what we're working with.",
   "goTo": "day4_supply_assessment",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["supply_assessment_done"],
    "pushEvent": "'Smart. Knowledge is power.' Alex grabs a clipboard. 'Let's be thorough.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d4m_security_check",
   "text": "Let's do a security check. Make sure we're safe.",
   "goTo": "day4_security_check",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["security_check_done"],
    "pushEvent": "'Can't be too careful.' Alex grabs their gear. 'Let's check every entrance.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day4", "morning"]
},
"day4_community_meeting": {
 "id": "day4_community_meeting",
 "text": "Day 4, 10:00 AM. The building's common area is packed. Every surviving family is here—the Martinez family, the elderly couple from 2B, the young mother and child from 5A, and others. 'Thank you all for coming,' you say. 'We need to talk about our situation.' Mrs. Martinez speaks up: 'We're running out of food. My children are hungry.' The elderly man from 2B adds: 'And medicine. My wife needs her heart medication.' The room falls silent. All eyes are on you.",
 "choices": [
  {
   "id": "d4cm_organize_supply_runs",
   "text": "Let's organize supply runs. We'll work together.",
   "goTo": "day4_organize_supply_runs",
   "effects": {
    "time": 2,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 2},
    "flagsSet": ["supply_runs_organized"],
    "pushEvent": "'We're stronger together.' Alex's voice is determined. 'Let's make this work.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d4cm_establish_rules",
   "text": "We need rules. Structure. Everyone contributes.",
   "goTo": "day4_establish_rules",
   "effects": {
    "time": 1,
    "persona": {"chill": 2, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1},
    "flagsSet": ["rules_established"],
    "pushEvent": "'Fair enough. We need order.' Alex's expression becomes serious."
   },
   "tags": ["chill"]
  },
  {
   "id": "d4cm_individual_responsibility",
   "text": "Everyone's responsible for themselves. We help when we can.",
   "goTo": "day4_individual_responsibility",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["individual_responsibility"],
    "pushEvent": "'Practical. I can respect that.' Alex nods. 'Survival first.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day4", "community"]
},
"day4_supply_assessment": {
 "id": "day4_supply_assessment",
 "text": "Day 4, 11:00 AM. You and Alex methodically check every apartment, every supply cache. The numbers are... concerning. 'Food: maybe two weeks if we ration carefully,' Alex reports. 'Medicine: three days for critical needs. Water: we're okay for now, but the building's supply won't last forever.' They look up from their notes. 'We need to make some hard decisions. Who gets priority? How do we ration? What happens when supplies run out?'",
 "choices": [
  {
   "id": "d4sa_children_first",
   "text": "Children and elderly get priority. They're most vulnerable.",
   "goTo": "day4_children_first_rationing",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["children_first_rationing"],
    "pushEvent": "'Compassionate. I like that.' Alex's eyes soften. 'They need us.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d4sa_contributors_first",
   "text": "Those who contribute most get priority. Fair system.",
   "goTo": "day4_contributors_first_rationing",
   "effects": {
    "time": 1,
    "persona": {"chill": 2, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["contributors_first_rationing"],
    "pushEvent": "'Fair. Merit-based system.' Alex nods. 'Makes sense.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d4sa_equal_shares",
   "text": "Equal shares for everyone. We're all in this together.",
   "goTo": "day4_equal_shares_rationing",
   "effects": {
    "time": 1,
    "persona": {"nice": 1, "chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1},
    "flagsSet": ["equal_shares_rationing"],
    "pushEvent": "'Democratic. I can respect that.' Alex's expression becomes neutral."
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day4", "supplies"]
},
"day4_security_check": {
 "id": "day4_security_check",
 "text": "Day 4, 12:00 PM. You and Alex systematically check every entrance, every window, every weak point. 'Main door: holding, but we need better reinforcement,' Alex reports. 'Fire escape: accessible, but we can block it if needed. Roof access: clear, good for surveillance.' They pause at a second-floor window. 'This is a problem,' they say, pointing to a crack in the glass. 'One good push and they're in.' The choice is yours.",
 "choices": [
  {
   "id": "d4sc_immediate_repair",
   "text": "Let's fix this now. No time to waste.",
   "goTo": "day4_immediate_repair",
   "effects": {
    "time": 2,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1, "stamina": -1},
    "flagsSet": ["immediate_repair_done"],
    "pushEvent": "'Good call. Security first.' Alex grabs tools. 'Let's make it solid.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d4sc_surveillance_system",
   "text": "Let's set up a surveillance system. Early warning.",
   "goTo": "day4_surveillance_system",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["surveillance_system_setup"],
    "pushEvent": "'Smart. Knowledge is power.' Alex's eyes light up. 'I can rig something up.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d4sc_evacuation_plan",
   "text": "Let's plan evacuation routes. Be ready to run.",
   "goTo": "day4_evacuation_plan",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1},
    "flagsSet": ["evacuation_plan_ready"],
    "pushEvent": "'Always have a backup plan.' Alex nods. 'Smart thinking.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day4", "security"]
},
"day4_organize_supply_runs": {
 "id": "day4_organize_supply_runs",
 "text": "Day 4, 2:00 PM. The community meeting continues. 'We need volunteers for supply runs,' you announce. 'It's dangerous, but necessary.' Hands go up—Alex, of course, but also Mr. Martinez, the young mother from 5A, and others. 'We'll work in teams,' you continue. 'Safety in numbers. And we'll share everything we find.' The room buzzes with energy. Hope. 'When do we start?' someone asks.",
 "choices": [
  {
   "id": "d4osr_start_today",
   "text": "Let's start today. No time to waste.",
   "goTo": "day4_supply_run_today",
   "effects": {
    "time": 2,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 2, "stamina": -2},
    "flagsSet": ["supply_run_today"],
    "pushEvent": "'Let's do this.' Alex's voice is determined. 'We're ready.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d4osr_plan_first",
   "text": "Let's plan first. Scout the area, then go.",
   "goTo": "day4_plan_supply_runs",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["supply_runs_planned"],
    "pushEvent": "'Smart. Preparation saves lives.' Alex nods approvingly."
   },
   "tags": ["chill"]
  },
  {
   "id": "d4osr_tomorrow",
   "text": "Let's start tomorrow. Give everyone time to prepare.",
   "goTo": "day4_supply_run_tomorrow",
   "effects": {
    "time": 1,
    "persona": {"nice": 1, "chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["supply_run_tomorrow"],
    "pushEvent": "'Good call. Preparation is key.' Alex's expression becomes thoughtful."
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day4", "supply_runs"]
},
"day4_establish_rules": {
 "id": "day4_establish_rules",
 "text": "Day 4, 2:00 PM. The community meeting takes a serious turn. 'We need structure,' you announce. 'Rules. Everyone contributes. Everyone follows them.' The room grows quiet. 'First rule: everyone pulls their weight. No freeloaders.' Mrs. Martinez nods. 'Second rule: we share resources. No hoarding.' The elderly man from 2B speaks up: 'And what about those who can't contribute? The sick? The elderly?' The question hangs in the air.",
 "choices": [
  {
   "id": "d4er_compassionate_rules",
   "text": "We make exceptions for those who can't contribute. Compassion.",
   "goTo": "day4_compassionate_rules",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["compassionate_rules"],
    "pushEvent": "'Thank you.' Mrs. Martinez's eyes fill with tears. 'You understand.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d4er_harsh_rules",
   "text": "No exceptions. Survival is harsh. Everyone contributes or leaves.",
   "goTo": "day4_harsh_rules",
   "effects": {
    "time": 1,
    "persona": {"warlord": 2, "rude": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["harsh_rules"],
    "pushEvent": "'I understand.' The elderly man's voice is quiet. 'Survival is harsh.'"
   },
   "tags": ["warlord"]
  },
  {
   "id": "d4er_flexible_rules",
   "text": "Flexible rules. We adapt to each situation.",
   "goTo": "day4_flexible_rules",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["flexible_rules"],
    "pushEvent": "'Practical. I like that.' Alex nods. 'Adaptability is key.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day4", "rules"]
},
"day4_individual_responsibility": {
 "id": "day4_individual_responsibility",
 "text": "Day 4, 2:00 PM. The community meeting takes a different turn. 'Look,' you say, 'we're all adults here. Everyone's responsible for themselves. We help when we can, but we can't save everyone.' The room grows quiet. Mrs. Martinez speaks up: 'What about my children? They can't fend for themselves.' The young mother from 5A adds: 'And what about the elderly? They need help.' The question hangs in the air.",
 "choices": [
  {
   "id": "d4ir_help_children",
   "text": "We help children and elderly. They're exceptions.",
   "goTo": "day4_help_children_elderly",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["help_children_elderly"],
    "pushEvent": "'Thank you.' Mrs. Martinez's voice is filled with relief. 'You understand.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d4ir_strict_individual",
   "text": "No exceptions. Everyone fends for themselves.",
   "goTo": "day4_strict_individual",
   "effects": {
    "time": 1,
    "persona": {"warlord": 2, "rude": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["strict_individual"],
    "pushEvent": "'I understand.' The young mother's voice is quiet. 'Survival is harsh.'"
   },
   "tags": ["warlord"]
  },
  {
   "id": "d4ir_voluntary_help",
   "text": "Voluntary help only. No obligations.",
   "goTo": "day4_voluntary_help",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["voluntary_help"],
    "pushEvent": "'Fair enough.' Alex nods. 'No pressure, no expectations.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day4", "individual"]
},
"day4_supply_run_today": {
 "id": "day4_supply_run_today",
 "text": "Day 4, 4:00 PM. You and Alex gear up for the first supply run. 'We'll hit the pharmacy first,' Alex says, checking their weapon. 'Then the grocery store two blocks over.' The other volunteers are nervous but determined. 'Remember,' you tell them, 'stay together. Watch each other's backs. And if things go bad, we run. No heroics.' The building's main door creaks open. Outside, the street is eerily quiet. But you can hear them. The infected. Moving. Hunting.",
 "choices": [
  {
   "id": "d4srt_pharmacy_first",
   "text": "Let's hit the pharmacy first. Medicine is critical.",
   "goTo": "day4_evening_hub",
   "effects": {
    "time": 2,
    "persona": {"nice": 1, "protector": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -2},
    "flagsSet": ["pharmacy_run_attempted"],
    "pushEvent": "'Medicine first. Smart.' Alex nods. 'Let's move.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d4srt_grocery_first",
   "text": "Let's hit the grocery store first. Food is more important.",
   "goTo": "day4_evening_hub",
   "effects": {
    "time": 2,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -2},
    "flagsSet": ["grocery_run_attempted"],
    "pushEvent": "'Food first. Practical.' Alex nods. 'Let's move.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d4srt_scout_first",
   "text": "Let's scout the area first. See what we're dealing with.",
   "goTo": "day4_evening_hub",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1, "stamina": -1},
    "flagsSet": ["scout_run_done"],
    "pushEvent": "'Smart. Knowledge is power.' Alex's eyes light up. 'Let's see what's out there.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day4", "supply_run"]
},
"day4_pharmacy_run": {
 "id": "day4_pharmacy_run",
 "text": "Day 4, 4:30 PM. The pharmacy is three blocks away. You move in formation, Alex leading, you watching the rear. The street is littered with abandoned cars, broken glass, and... bodies. 'Stay focused,' Alex whispers. 'Don't look at them.' The pharmacy's front door is shattered. Inside, shelves are mostly empty, but there are still some supplies. 'Let's be quick,' Alex says. 'In and out.' You can hear sounds from the back—maybe infected, maybe survivors.",
 "choices": [
  {
   "id": "d4pr_quick_grab",
   "text": "Quick grab. Take what we can and go.",
   "goTo": "day4_pharmacy_quick_success",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1, "stamina": -1},
    "inventoryAdd": ["bandages", "painkillers", "antibiotics"],
    "flagsSet": ["pharmacy_quick_success"],
    "pushEvent": "'Good haul. Let's get out of here.' Alex's voice is tense. 'Move.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d4pr_thorough_search",
   "text": "Thorough search. Check the back room.",
   "goTo": "day4_pharmacy_thorough_search",
   "effects": {
    "time": 2,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -2},
    "inventoryAdd": ["morphine", "surgical_kit", "insulin"],
    "flagsSet": ["pharmacy_thorough_success"],
    "pushEvent": "'Found the good stuff.' Alex's eyes light up. 'This could save lives.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d4pr_check_sounds",
   "text": "Check those sounds. Could be survivors.",
   "goTo": "day4_pharmacy_survivors",
   "effects": {
    "time": 1,
    "persona": {"nice": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -1},
    "flagsSet": ["pharmacy_survivors_found"],
    "pushEvent": "'Could be someone who needs help.' Alex's hand moves to their weapon."
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day4", "pharmacy"]
},
"day4_grocery_run": {
 "id": "day4_grocery_run",
 "text": "Day 4, 4:30 PM. The grocery store is two blocks away. You move in formation, Alex leading, you watching the rear. The street is eerily quiet, but you can feel eyes on you. 'Stay alert,' Alex whispers. 'They're out there.' The grocery store's front door is locked, but the glass is shattered. Inside, most shelves are empty, but there are still some supplies. 'Let's be quick,' Alex says. 'In and out.' You can hear sounds from the back—maybe infected, maybe survivors.",
 "choices": [
  {
   "id": "d4gr_quick_grab",
   "text": "Quick grab. Take what we can and go.",
   "goTo": "day4_grocery_quick_success",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1, "stamina": -1},
    "inventoryAdd": ["canned_food", "water_bottles", "crackers"],
    "flagsSet": ["grocery_quick_success"],
    "pushEvent": "'Good haul. Let's get out of here.' Alex's voice is tense. 'Move.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d4gr_thorough_search",
   "text": "Thorough search. Check the back room.",
   "goTo": "day4_grocery_thorough_search",
   "effects": {
    "time": 2,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -2},
    "inventoryAdd": ["rice", "beans", "cooking_oil", "salt"],
    "flagsSet": ["grocery_thorough_success"],
    "pushEvent": "'Found the good stuff.' Alex's eyes light up. 'This could feed everyone.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d4gr_check_sounds",
   "text": "Check those sounds. Could be survivors.",
   "goTo": "day4_grocery_survivors",
   "effects": {
    "time": 1,
    "persona": {"nice": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -1},
    "flagsSet": ["grocery_survivors_found"],
    "pushEvent": "'Could be someone who needs help.' Alex's hand moves to their weapon."
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day4", "grocery"]
},
"day4_scout_run": {
 "id": "day4_scout_run",
 "text": "Day 4, 4:30 PM. You and Alex move cautiously through the streets, mapping the area. 'This building looks secure,' Alex whispers, pointing to a nearby apartment complex. 'That one... not so much.' You can see signs of life—lights in windows, movement behind curtains. 'Survivors,' Alex says. 'But are they friendly?' The question hangs in the air. You also notice the infected—small groups, moving in patterns. 'They're getting smarter,' Alex observes. 'Or more desperate.'",
 "choices": [
  {
   "id": "d4sr_approach_survivors",
   "text": "Let's approach the survivors. See if they're friendly.",
   "goTo": "day4_approach_survivors",
   "effects": {
    "time": 1,
    "persona": {"nice": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -1},
    "flagsSet": ["survivors_approached"],
    "pushEvent": "'Could be allies. Could be enemies.' Alex's hand moves to their weapon."
   },
   "tags": ["nice"]
  },
  {
   "id": "d4sr_avoid_survivors",
   "text": "Let's avoid the survivors. Too risky.",
   "goTo": "day4_avoid_survivors",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1, "stamina": -1},
    "flagsSet": ["survivors_avoided"],
    "pushEvent": "'Smart. No need to take unnecessary risks.' Alex nods. 'Let's head back.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d4sr_study_infected",
   "text": "Let's study the infected. Learn their patterns.",
   "goTo": "day4_study_infected",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1, "stamina": -1},
    "flagsSet": ["infected_studied"],
    "pushEvent": "'Knowledge is power.' Alex's eyes light up. 'Let's see what we can learn.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day4", "scout"]
},
"day4_evening_hub": {
 "id": "day4_evening_hub",
 "text": "Day 4, 6:00 PM. The sun is setting, casting long shadows across the building. You and Alex sit in the apartment, reviewing the day's events. 'We made progress,' Alex says. 'Got supplies. Learned about the area. Made contact with other survivors.' They pause. 'But we also saw how dangerous it is out there. The infected are getting smarter. The survivors... some are friendly, some aren't.' They look at you. 'We need to decide what kind of community we want to build here.'",
 "choices": [
  {
   "id": "d4eh_open_community",
   "text": "Let's build an open community. Welcome everyone.",
   "goTo": "day6_morning",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["open_community_chosen"],
    "pushEvent": "'Inclusive. I like that.' Alex's eyes light up. 'We're stronger together.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d4eh_selective_community",
   "text": "Let's be selective. Only let in those who can contribute.",
   "goTo": "day6_morning",
   "effects": {
    "time": 1,
    "persona": {"chill": 2, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["selective_community_chosen"],
    "pushEvent": "'Practical. I can respect that.' Alex nods. 'Quality over quantity.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d4eh_closed_community",
   "text": "Let's keep it closed. Just us and the current residents.",
   "goTo": "day6_morning",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["closed_community_chosen"],
    "pushEvent": "'Safe. I can respect that.' Alex nods. 'No unnecessary risks.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day4", "evening_hub"]
},
"day5_open_community": {
 "id": "day5_open_community",
 "text": "Day 5, 8:00 AM. The building buzzes with activity. Word has spread about your open-door policy, and survivors are arriving. 'We need to organize this,' Alex says, watching a family with three children approach the building. 'Food, water, space—we're going to run out of everything if we don't plan.' The building's population has doubled in the last 24 hours. 'We need to make some hard decisions,' Alex continues. 'About resources. About leadership. About what happens when we can't help everyone.'",
 "choices": [
  {
   "id": "d5oc_organize_system",
   "text": "Let's organize a system. Fair distribution of resources.",
   "goTo": "day5_organize_system",
   "effects": {
    "time": 2,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 2},
    "flagsSet": ["system_organized"],
    "pushEvent": "'Good thinking. We need structure.' Alex nods. 'Let's make this work.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d5oc_establish_leadership",
   "text": "Let's establish clear leadership. Someone needs to make decisions.",
   "goTo": "day5_establish_leadership",
   "effects": {
    "time": 1,
    "persona": {"protector": 2, "warlord": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["leadership_established"],
    "pushEvent": "'Good call. We need someone to step up.' Alex's expression becomes determined."
   },
   "tags": ["protector"]
  },
  {
   "id": "d5oc_community_council",
   "text": "Let's form a community council. Democratic decision-making.",
   "goTo": "day5_community_council",
   "effects": {
    "time": 1,
    "persona": {"nice": 1, "chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1},
    "flagsSet": ["council_formed"],
    "pushEvent": "'Democratic. I like that.' Alex nods. 'Everyone has a voice.'"
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day5", "open_community"]
},
"day5_selective_community": {
 "id": "day5_selective_community",
 "text": "Day 5, 8:00 AM. The building maintains its selective approach. 'We need to be smart about who we let in,' Alex says, watching a group of survivors approach the building. 'Skills, resources, contribution potential—we need to evaluate everyone.' The building's population has grown, but slowly. 'We need to make some hard decisions,' Alex continues. 'About criteria. About who gets priority. About what happens when we have to turn people away.'",
 "choices": [
  {
   "id": "d5sc_skill_based",
   "text": "Let's focus on skills. What can they contribute?",
   "goTo": "day5_skill_based_selection",
   "effects": {
    "time": 1,
    "persona": {"chill": 2, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["skill_based_selection"],
    "pushEvent": "'Practical. I like that.' Alex nods. 'Merit-based system.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d5sc_resource_based",
   "text": "Let's focus on resources. What can they bring?",
   "goTo": "day5_resource_based_selection",
   "effects": {
    "time": 1,
    "persona": {"chill": 1, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["resource_based_selection"],
    "pushEvent": "'Fair. Everyone contributes.' Alex nods. 'Resource-based system.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d5sc_character_based",
   "text": "Let's focus on character. Are they trustworthy?",
   "goTo": "day5_character_based_selection",
   "effects": {
    "time": 1,
    "persona": {"nice": 1, "chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1},
    "flagsSet": ["character_based_selection"],
    "pushEvent": "'Important. Trust is everything.' Alex nods. 'Character-based system.'"
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day5", "selective_community"]
},
"day5_closed_community": {
 "id": "day5_closed_community",
 "text": "Day 5, 8:00 AM. The building maintains its closed-door policy. 'We need to focus on what we have,' Alex says, watching survivors approach the building and be turned away. 'Resources are limited. Space is limited. We can't help everyone.' The building's population remains stable. 'We need to make some hard decisions,' Alex continues. 'About resources. About security. About what happens when we have to turn people away.'",
 "choices": [
  {
   "id": "d5cc_focus_internal",
   "text": "Let's focus on internal development. Make what we have work.",
   "goTo": "day5_focus_internal",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["internal_focus"],
    "pushEvent": "'Smart. Work with what we have.' Alex nods. 'Internal development.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d5cc_security_priority",
   "text": "Let's prioritize security. Make sure we're safe.",
   "goTo": "day5_security_priority",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["security_priority"],
    "pushEvent": "'Good call. Security first.' Alex nods. 'Safety is everything.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d5cc_resource_management",
   "text": "Let's focus on resource management. Make supplies last.",
   "goTo": "day5_resource_management",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["resource_management"],
    "pushEvent": "'Practical. Make what we have last.' Alex nods. 'Resource management.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day5", "closed_community"]
},
"day6_morning": {
 "id": "day6_morning",
 "text": "Day 6, 7:00 AM. The building stirs to life. You hear voices in the halls—survivors coordinating, children playing quietly, the elderly sharing stories. Alex is already up, reviewing supply lists. 'We need to talk,' they say, looking up from their notes. 'The community is growing. Fast. We're at capacity for food, water, space. And there are more survivors coming every day.' They pause. 'We need to make some hard decisions. About who we can help. About what we can afford. About what kind of community we want to be.'",
 "choices": [
  {
   "id": "d6m_expand_capacity",
   "text": "Let's expand our capacity. Find more resources, more space.",
   "goTo": "day6_expand_capacity",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 2},
    "flagsSet": ["expand_capacity_chosen"],
    "pushEvent": "'Ambitious. I like it.' Alex's eyes light up. 'Let's see what we can build.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d6m_manage_resources",
   "text": "Let's manage what we have better. Optimize, ration, organize.",
   "goTo": "day6_manage_resources",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["manage_resources_chosen"],
    "pushEvent": "'Practical. I can respect that.' Alex nods. 'Efficiency is key.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d6m_establish_limits",
   "text": "Let's establish clear limits. We can't help everyone.",
   "goTo": "day6_establish_limits",
   "effects": {
    "time": 1,
    "persona": {"chill": 1, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["establish_limits_chosen"],
    "pushEvent": "'Hard but necessary.' Alex's expression becomes serious. 'Survival is harsh.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day6", "morning"]
},
"day6_expand_capacity": {
 "id": "day6_expand_capacity",
 "text": "Day 6, 9:00 AM. You and Alex stand on the building's roof, surveying the surrounding area. 'We need more space,' Alex says, pointing to nearby buildings. 'That apartment complex across the street—it's mostly intact. We could secure it, connect it to our building.' They pause. 'But it's risky. We'd need to clear it of infected, secure it, establish supply lines.' The wind carries the sound of distant screams. 'We'd also need more people to defend it. More resources to maintain it.'",
 "choices": [
  {
   "id": "d6ec_secure_adjacent_building",
   "text": "Let's secure the adjacent building. Expand our territory.",
   "goTo": "day6_secure_adjacent_building",
   "effects": {
    "time": 3,
    "persona": {"protector": 2, "warlord": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 3, "stamina": -3},
    "flagsSet": ["adjacent_building_secured"],
    "pushEvent": "'Ambitious. Let's do it.' Alex's eyes light up. 'We're building something real.'"
   },
   "tags": ["protector"]
  },
  {
   "id": "d6ec_establish_supply_lines",
   "text": "Let's establish supply lines first. Secure resources before expanding.",
   "goTo": "day6_establish_supply_lines",
   "effects": {
    "time": 2,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -2},
    "flagsSet": ["supply_lines_established"],
    "pushEvent": "'Smart. Resources first.' Alex nods. 'Let's secure our supply chain.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d6ec_recruit_more_people",
   "text": "Let's recruit more people first. We need more hands to expand.",
   "goTo": "day6_recruit_more_people",
   "effects": {
    "time": 2,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 2},
    "flagsSet": ["recruitment_drive"],
    "pushEvent": "'Good thinking. People are our greatest resource.' Alex's eyes light up."
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day6", "expansion"]
},
"day6_manage_resources": {
 "id": "day6_manage_resources",
 "text": "Day 6, 9:00 AM. You and Alex sit in the building's common area, surrounded by supply lists, rationing charts, and resource allocation plans. 'We need to be smart about this,' Alex says, pointing to a chart. 'Current food: 8 days at current consumption. Water: 12 days. Medicine: 4 days for critical needs.' They look up. 'We can stretch this. Better rationing, more efficient distribution, maybe some creative solutions.' The room is quiet except for the sound of children playing in the distance.",
 "choices": [
  {
   "id": "d6mr_implement_strict_rationing",
   "text": "Let's implement strict rationing. Everyone gets equal shares.",
   "goTo": "day6_strict_rationing",
   "effects": {
    "time": 1,
    "persona": {"chill": 2, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1},
    "flagsSet": ["strict_rationing_implemented"],
    "pushEvent": "'Fair. Everyone gets the same.' Alex nods. 'No favorites.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d6mr_priority_based_rationing",
   "text": "Let's use priority-based rationing. Children and elderly first.",
   "goTo": "day6_priority_rationing",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["priority_rationing_implemented"],
    "pushEvent": "'Compassionate. I like that.' Alex's eyes soften. 'They need us most.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d6mr_contribution_based_rationing",
   "text": "Let's use contribution-based rationing. Those who work get more.",
   "goTo": "day6_contribution_rationing",
   "effects": {
    "time": 1,
    "persona": {"chill": 1, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["contribution_rationing_implemented"],
    "pushEvent": "'Fair. Merit-based system.' Alex nods. 'Work hard, eat well.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day6", "resource_management"]
},
"day6_establish_limits": {
 "id": "day6_establish_limits",
 "text": "Day 6, 9:00 AM. You and Alex stand at the building's main entrance, watching a group of survivors approach. 'We need to be clear about our limits,' Alex says quietly. 'We can't help everyone. We don't have the resources, the space, the capacity.' The group looks desperate—a family with young children, an elderly couple, a young man with a broken arm. 'We need to decide. Who do we help? Who do we turn away? And how do we live with those decisions?'",
 "choices": [
  {
   "id": "d6el_help_children_only",
   "text": "We help children and their families. Everyone else is on their own.",
   "goTo": "day6_help_children_only",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 2},
    "flagsSet": ["children_only_policy"],
    "pushEvent": "'Compassionate. I can respect that.' Alex's eyes soften. 'Children need us.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d6el_help_contributors_only",
   "text": "We help those who can contribute. No freeloaders.",
   "goTo": "day6_help_contributors_only",
   "effects": {
    "time": 1,
    "persona": {"chill": 1, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["contributors_only_policy"],
    "pushEvent": "'Practical. I can respect that.' Alex nods. 'Everyone contributes.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d6el_turn_everyone_away",
   "text": "We turn everyone away. We can't afford to help anyone else.",
   "goTo": "day6_turn_everyone_away",
   "effects": {
    "time": 1,
    "persona": {"warlord": 2, "rude": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -2},
    "flagsSet": ["closed_door_policy"],
    "pushEvent": "'Hard but necessary.' Alex's expression becomes cold. 'Survival is harsh.'"
   },
   "tags": ["warlord"]
  }
 ],
 "tags": ["day6", "limits"]
},
"day6_secure_adjacent_building": {
 "id": "day6_secure_adjacent_building",
 "text": "Day 6, 12:00 PM. You and Alex lead a team of volunteers across the street to the adjacent apartment building. 'Stay alert,' Alex whispers. 'We don't know what's in there.' The building's front door is barricaded with furniture. 'Someone was here,' Alex observes. 'Recently.' You can hear sounds from inside—footsteps, voices, maybe infected. 'We need to decide how to approach this,' Alex says. 'Do we announce ourselves? Do we sneak in? Do we wait and observe?'",
 "choices": [
  {
   "id": "d6sab_announce_presence",
   "text": "Let's announce our presence. Be open and honest.",
   "goTo": "day6_announce_presence",
   "effects": {
    "time": 1,
    "persona": {"nice": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -1},
    "flagsSet": ["announced_presence"],
    "pushEvent": "'Honest approach. I like it.' Alex nods. 'Let's see who's in there.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d6sab_sneak_in",
   "text": "Let's sneak in. Scout the situation first.",
   "goTo": "day6_sneak_in",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1, "stamina": -1},
    "flagsSet": ["sneaked_in"],
    "pushEvent": "'Smart. Knowledge is power.' Alex's eyes light up. 'Let's see what we're dealing with.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d6sab_wait_and_observe",
   "text": "Let's wait and observe. See what's happening inside.",
   "goTo": "day6_wait_and_observe",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1, "stamina": -1},
    "flagsSet": ["observed_building"],
    "pushEvent": "'Patient. I like that.' Alex nods. 'Let's see what we can learn.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day6", "building_securing"]
},
"day6_establish_supply_lines": {
 "id": "day6_establish_supply_lines",
 "text": "Day 6, 12:00 PM. You and Alex map out potential supply routes through the city. 'We need reliable sources,' Alex says, pointing to various locations on the map. 'The grocery store we hit yesterday—it's mostly empty now. The pharmacy—same thing. We need to find new sources.' They pause. 'But it's getting more dangerous out there. The infected are getting smarter. Other survivors are getting desperate.' The map is covered with red X's marking cleared locations and question marks for unknown areas.",
 "choices": [
  {
   "id": "d6esl_scout_new_locations",
   "text": "Let's scout new locations. Find fresh supply sources.",
   "goTo": "day6_scout_new_locations",
   "effects": {
    "time": 2,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -2},
    "flagsSet": ["new_locations_scouted"],
    "pushEvent": "'Good thinking. Fresh sources.' Alex nods. 'Let's see what's out there.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d6esl_negotiate_with_survivors",
   "text": "Let's negotiate with other survivor groups. Trade, not raid.",
   "goTo": "day6_negotiate_with_survivors",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "chill": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1, "stamina": -1},
    "flagsSet": ["survivor_negotiations"],
    "pushEvent": "'Diplomatic. I like it.' Alex's eyes light up. 'Let's build alliances.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d6esl_establish_growing_operations",
   "text": "Let's establish growing operations. Become self-sufficient.",
   "goTo": "day6_establish_growing_operations",
   "effects": {
    "time": 3,
    "persona": {"chill": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1, "stamina": -2},
    "flagsSet": ["growing_operations_established"],
    "pushEvent": "'Long-term thinking. I like it.' Alex's eyes light up. 'Let's build something sustainable.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day6", "supply_lines"]
},
"day6_recruit_more_people": {
 "id": "day6_recruit_more_people",
 "text": "Day 6, 12:00 PM. You and Alex stand on the building's roof, looking out at the surrounding area. 'We need more people,' Alex says. 'More hands to work, more eyes to watch, more minds to think.' They point to various locations. 'There are survivors out there. In other buildings, hiding in basements, maybe even in the sewers.' They pause. 'But we need to be careful. Not everyone is friendly. Not everyone can be trusted. We need to decide what kind of people we want to recruit.'",
 "choices": [
  {
   "id": "d6rmp_actively_seek_survivors",
   "text": "Let's actively seek out survivors. Go to them.",
   "goTo": "day6_actively_seek_survivors",
   "effects": {
    "time": 2,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 2, "stamina": -2},
    "flagsSet": ["active_recruitment"],
    "pushEvent": "'Proactive. I like it.' Alex's eyes light up. 'Let's find people who need us.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d6rmp_wait_for_survivors",
   "text": "Let's wait for survivors to come to us. Word will spread.",
   "goTo": "day6_wait_for_survivors",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["passive_recruitment"],
    "pushEvent": "'Patient. I can respect that.' Alex nods. 'Let them come to us.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d6rmp_selective_recruitment",
   "text": "Let's be selective. Only recruit those with valuable skills.",
   "goTo": "day6_selective_recruitment",
   "effects": {
    "time": 1,
    "persona": {"chill": 1, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["selective_recruitment"],
    "pushEvent": "'Practical. I can respect that.' Alex nods. 'Quality over quantity.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day6", "recruitment"]
},
"day6_evening_hub": {
 "id": "day6_evening_hub",
 "text": "Day 6, 6:00 PM. The sun sets on another day of building, planning, and hard decisions. You and Alex sit in the apartment, reviewing the day's progress. 'We're making real changes,' Alex says. 'Expanding, organizing, growing. But it's getting more complex. More people, more problems, more decisions to make.' They look at you. 'We need to think about tomorrow. About next week. About what kind of community we want to build here. About what kind of leaders we want to be.'",
 "choices": [
  {
   "id": "d6eh_plan_expansion",
   "text": "Let's plan more expansion. We're just getting started.",
   "goTo": "day7_evening_hub",
   "effects": {
    "time": 1,
    "persona": {"protector": 2, "warlord": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["expansion_planning"],
    "pushEvent": "'Ambitious. I like it.' Alex's eyes light up. 'Let's see how big we can build this.'"
   },
   "tags": ["protector"]
  },
  {
   "id": "d6eh_consolidate_gains",
   "text": "Let's consolidate what we have. Make it solid before expanding.",
   "goTo": "day7_evening_hub",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["consolidation_planning"],
    "pushEvent": "'Smart. Build on what works.' Alex nods. 'Let's make it solid.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d6eh_focus_community",
   "text": "Let's focus on community building. Strengthen relationships.",
   "goTo": "day7_evening_hub",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": -1},
    "flagsSet": ["community_building_focus"],
    "pushEvent": "'Important. People are everything.' Alex's eyes soften. 'Let's build something real.'"
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day6", "evening_hub"]
},
"day7_expansion_planning": {
 "id": "day7_expansion_planning",
 "text": "Day 7, 8:00 AM. You and Alex stand on the building's roof, looking out at the surrounding area. 'We need to think bigger,' Alex says, pointing to various locations. 'That shopping center three blocks away—it's got supplies, space, maybe even generators. That school district—classrooms we could convert, a cafeteria, maybe even a gym.' They pause. 'But it's risky. We'd need to clear infected, secure multiple buildings, establish supply lines between them.' The wind carries the sound of distant screams. 'We'd also need more people to defend it. More resources to maintain it.'",
 "choices": [
  {
   "id": "d7ep_secure_shopping_center",
   "text": "Let's secure the shopping center. It's got everything we need.",
   "goTo": "day7_evening_hub",
   "effects": {
    "time": 4,
    "persona": {"protector": 2, "warlord": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 4, "stamina": -4},
    "flagsSet": ["shopping_center_secured"],
    "pushEvent": "'Ambitious. Let's do it.' Alex's eyes light up. 'We're building something real.'"
   },
   "tags": ["protector"]
  },
  {
   "id": "d7ep_secure_school_district",
   "text": "Let's secure the school district. It's got space and resources.",
   "goTo": "day7_evening_hub",
   "effects": {
    "time": 3,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 3, "stamina": -3},
    "flagsSet": ["school_district_secured"],
    "pushEvent": "'Good thinking. Schools are built for communities.' Alex's eyes light up."
   },
   "tags": ["nice"]
  },
  {
   "id": "d7ep_establish_network",
   "text": "Let's establish a network of smaller outposts. Spread out, stay connected.",
   "goTo": "day7_evening_hub",
   "effects": {
    "time": 2,
    "persona": {"chill": 2, "protector": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -2},
    "flagsSet": ["network_established"],
    "pushEvent": "'Smart. Diversify our holdings.' Alex nods. 'Let's build a network.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day7", "expansion"]
},
"day7_consolidation": {
 "id": "day7_consolidation",
 "text": "Day 7, 8:00 AM. You and Alex sit in the building's common area, reviewing the current situation. 'We need to consolidate what we have,' Alex says, pointing to various charts and lists. 'Current population: 47 people. Food: 6 days at current consumption. Water: 10 days. Medicine: 3 days for critical needs.' They look up. 'We can make this work. Better organization, more efficient systems, maybe some creative solutions.' The room is quiet except for the sound of children playing in the distance.",
 "choices": [
  {
   "id": "d7c_optimize_systems",
   "text": "Let's optimize our systems. Make everything more efficient.",
   "goTo": "day7_optimize_systems",
   "effects": {
    "time": 2,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1, "stamina": -1},
    "flagsSet": ["systems_optimized"],
    "pushEvent": "'Good thinking. Efficiency is key.' Alex nods. 'Let's make everything work better.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d7c_strengthen_security",
   "text": "Let's strengthen our security. Make sure we're safe.",
   "goTo": "day7_strengthen_security",
   "effects": {
    "time": 2,
    "persona": {"chill": 1, "protector": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1, "stamina": -1},
    "flagsSet": ["security_strengthened"],
    "pushEvent": "'Smart. Security is everything.' Alex nods. 'Let's make it unassailable.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d7c_improve_relationships",
   "text": "Let's improve relationships. Build stronger community bonds.",
   "goTo": "day7_improve_relationships",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": -2},
    "flagsSet": ["relationships_improved"],
    "pushEvent": "'Important. People are everything.' Alex's eyes soften. 'Let's build something real.'"
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day7", "consolidation"]
},
"day7_community_building": {
 "id": "day7_community_building",
 "text": "Day 7, 8:00 AM. The building buzzes with activity. You and Alex walk through the halls, checking on residents, listening to concerns, sharing stories. 'We need to build something real here,' Alex says. 'Not just survival. Community. Trust. Hope.' They pause at a door where children are playing. 'These kids—they're the future. We need to give them something to believe in.' The sound of laughter echoes through the building. 'We need to decide what kind of community we want to be. What kind of future we want to build.'",
 "choices": [
  {
   "id": "d7cb_establish_education",
   "text": "Let's establish education. Teach the children, share knowledge.",
   "goTo": "day7_establish_education",
   "effects": {
    "time": 2,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1, "stamina": -1},
    "flagsSet": ["education_established"],
    "pushEvent": "'Good thinking. Knowledge is power.' Alex's eyes light up. 'Let's teach them everything we know.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d7cb_establish_culture",
   "text": "Let's establish culture. Art, music, stories, traditions.",
   "goTo": "day7_establish_culture",
   "effects": {
    "time": 1,
    "persona": {"nice": 2},
    "relationships": {"Alex": 2},
    "stats": {"stress": -2},
    "flagsSet": ["culture_established"],
    "pushEvent": "'Beautiful. We need beauty in this world.' Alex's eyes soften. 'Let's create something worth living for.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d7cb_establish_governance",
   "text": "Let's establish governance. Rules, leadership, decision-making.",
   "goTo": "day7_establish_governance",
   "effects": {
    "time": 1,
    "persona": {"chill": 2, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1},
    "flagsSet": ["governance_established"],
    "pushEvent": "'Practical. We need structure.' Alex nods. 'Let's build something that works.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day7", "community"]
},
"day7_secure_shopping_center": {
 "id": "day7_secure_shopping_center",
 "text": "Day 7, 10:00 AM. You and Alex lead a team of volunteers toward the shopping center. 'This is risky,' Alex says, checking their weapon. 'But the potential rewards are huge. Food, supplies, maybe even generators.' The shopping center looms ahead—a massive complex with multiple stores, a food court, and what looks like a hardware store. 'We need to be smart about this,' Alex continues. 'Clear it systematically, secure it properly, establish supply lines.' The wind carries the sound of distant screams. 'And we need to be ready for anything.'",
 "choices": [
  {
   "id": "d7ssc_systematic_clearance",
   "text": "Let's clear it systematically. Store by store, floor by floor.",
   "goTo": "day7_systematic_clearance",
   "effects": {
    "time": 3,
    "persona": {"chill": 2, "protector": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -3},
    "flagsSet": ["systematic_clearance"],
    "pushEvent": "'Smart. Methodical approach.' Alex nods. 'Let's do this right.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d7ssc_quick_raid",
   "text": "Let's do a quick raid. Get in, get what we need, get out.",
   "goTo": "day7_quick_raid",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 3, "stamina": -2},
    "flagsSet": ["quick_raid"],
    "pushEvent": "'Fast and efficient. I like it.' Alex nods. 'Let's get what we need and go.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d7ssc_scout_first",
   "text": "Let's scout it first. See what we're dealing with.",
   "goTo": "day7_scout_shopping_center",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1, "stamina": -1},
    "flagsSet": ["shopping_center_scouted"],
    "pushEvent": "'Smart. Knowledge is power.' Alex's eyes light up. 'Let's see what we're dealing with.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day7", "shopping_center"]
},
"day7_secure_school_district": {
 "id": "day7_secure_school_district",
 "text": "Day 7, 10:00 AM. You and Alex lead a team of volunteers toward the school district. 'This is perfect,' Alex says, pointing to the buildings. 'Classrooms we can convert to living spaces, a cafeteria for communal meals, maybe even a gym for training.' The school complex spreads out before you—multiple buildings, playgrounds, and what looks like a sports field. 'We need to be smart about this,' Alex continues. 'Clear it systematically, secure it properly, establish supply lines.' The wind carries the sound of distant screams. 'And we need to be ready for anything.'",
 "choices": [
  {
   "id": "d7ssd_systematic_clearance",
   "text": "Let's clear it systematically. Building by building, room by room.",
   "goTo": "day7_school_systematic_clearance",
   "effects": {
    "time": 3,
    "persona": {"chill": 2, "protector": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -3},
    "flagsSet": ["school_systematic_clearance"],
    "pushEvent": "'Smart. Methodical approach.' Alex nods. 'Let's do this right.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d7ssd_quick_raid",
   "text": "Let's do a quick raid. Get in, get what we need, get out.",
   "goTo": "day7_school_quick_raid",
   "effects": {
    "time": 1,
    "persona": {"chill": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 3, "stamina": -2},
    "flagsSet": ["school_quick_raid"],
    "pushEvent": "'Fast and efficient. I like it.' Alex nods. 'Let's get what we need and go.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d7ssd_scout_first",
   "text": "Let's scout it first. See what we're dealing with.",
   "goTo": "day7_scout_school_district",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1, "stamina": -1},
    "flagsSet": ["school_district_scouted"],
    "pushEvent": "'Smart. Knowledge is power.' Alex's eyes light up. 'Let's see what we're dealing with.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day7", "school_district"]
},
"day7_establish_network": {
 "id": "day7_establish_network",
 "text": "Day 7, 10:00 AM. You and Alex stand on the building's roof, looking out at the surrounding area. 'We need to think strategically,' Alex says, pointing to various locations. 'That apartment building two blocks north—it's mostly intact. That office building three blocks east—it's got supplies, maybe even communications equipment.' They pause. 'We can establish a network of outposts. Connected, but independent. Each one self-sufficient, but supporting the others.' The wind carries the sound of distant screams. 'It's risky, but it gives us options.'",
 "choices": [
  {
   "id": "d7en_secure_apartment_building",
   "text": "Let's secure the apartment building first. It's closest and safest.",
   "goTo": "day7_secure_apartment_building",
   "effects": {
    "time": 2,
    "persona": {"chill": 2, "protector": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -2},
    "flagsSet": ["apartment_building_secured"],
    "pushEvent": "'Smart. Start with the safest option.' Alex nods. 'Let's build our network.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d7en_secure_office_building",
   "text": "Let's secure the office building. It's got valuable resources.",
   "goTo": "day7_secure_office_building",
   "effects": {
    "time": 2,
    "persona": {"chill": 1, "protector": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -2},
    "flagsSet": ["office_building_secured"],
    "pushEvent": "'Good thinking. Resources are key.' Alex nods. 'Let's get what we need.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d7en_establish_communication",
   "text": "Let's establish communication first. Connect our outposts.",
   "goTo": "day7_establish_communication",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1, "stamina": -1},
    "flagsSet": ["communication_established"],
    "pushEvent": "'Smart. Communication is everything.' Alex's eyes light up. 'Let's stay connected.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day7", "network"]
},
"day7_evening_hub": {
 "id": "day7_evening_hub",
 "text": "Day 7, 6:00 PM. The sun sets on another day of building, planning, and hard decisions. You and Alex sit in the apartment, reviewing the day's progress. 'We're making real changes,' Alex says. 'Expanding, organizing, growing. But it's getting more complex. More people, more problems, more decisions to make.' They look at you. 'We need to think about tomorrow. About next week. About what kind of community we want to build here. About what kind of leaders we want to be.'",
 "choices": [
  {
   "id": "d7eh_plan_more_expansion",
   "text": "Let's plan more expansion. We're just getting started.",
   "goTo": "day8_morning",
   "effects": {
    "time": 1,
    "persona": {"protector": 2, "warlord": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["expansion_planning"],
    "pushEvent": "'Ambitious. I like it.' Alex's eyes light up. 'Let's see how big we can build this.'"
   },
   "tags": ["protector"]
  },
  {
   "id": "d7eh_consolidate_gains",
   "text": "Let's consolidate what we have. Make it solid before expanding.",
   "goTo": "day8_morning",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["consolidation_planning"],
    "pushEvent": "'Smart. Build on what works.' Alex nods. 'Let's make it solid.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d7eh_focus_community",
   "text": "Let's focus on community building. Strengthen relationships.",
   "goTo": "day8_morning",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": -1},
    "flagsSet": ["community_building_focus"],
    "pushEvent": "'Important. People are everything.' Alex's eyes soften. 'Let's build something real.'"
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day7", "evening_hub"]
},
"day8_morning": {
 "id": "day8_morning",
 "text": "Day 8, 7:00 AM. The building stirs to life. You hear voices in the halls—survivors coordinating, children playing quietly, the elderly sharing stories. Alex is already up, reviewing supply lists. 'We need to talk,' they say, looking up from their notes. 'The community is growing. Fast. We're at capacity for food, water, space. And there are more survivors coming every day.' They pause. 'We need to make some hard decisions. About who we can help. About what we can afford. About what kind of community we want to be.'",
 "choices": [
  {
   "id": "d8m_expand_capacity",
   "text": "Let's expand our capacity. Find more resources, more space.",
   "goTo": "day8_evening_hub",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 2},
    "flagsSet": ["expand_capacity_chosen"],
    "pushEvent": "'Ambitious. I like it.' Alex's eyes light up. 'Let's see what we can build.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d8m_manage_resources",
   "text": "Let's manage what we have better. Optimize, ration, organize.",
   "goTo": "day8_evening_hub",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["manage_resources_chosen"],
    "pushEvent": "'Practical. I can respect that.' Alex nods. 'Efficiency is key.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d8m_establish_limits",
   "text": "Let's establish clear limits. We can't help everyone.",
   "goTo": "day8_evening_hub",
   "effects": {
    "time": 1,
    "persona": {"chill": 1, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["establish_limits_chosen"],
    "pushEvent": "'Hard but necessary.' Alex's expression becomes serious. 'Survival is harsh.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day8", "morning"]
},
"day8_expand_capacity": {
 "id": "day8_expand_capacity",
 "text": "Day 8, 9:00 AM. You and Alex stand on the building's roof, surveying the surrounding area. 'We need more space,' Alex says, pointing to nearby buildings. 'That apartment complex across the street—it's mostly intact. We could secure it, connect it to our building.' They pause. 'But it's risky. We'd need to clear it of infected, secure it, establish supply lines.' The wind carries the sound of distant screams. 'We'd also need more people to defend it. More resources to maintain it.'",
 "choices": [
  {
   "id": "d8ec_secure_adjacent_building",
   "text": "Let's secure the adjacent building. Expand our territory.",
   "goTo": "day8_evening_hub",
   "effects": {
    "time": 3,
    "persona": {"protector": 2, "warlord": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 3, "stamina": -3},
    "flagsSet": ["adjacent_building_secured"],
    "pushEvent": "'Ambitious. Let's do it.' Alex's eyes light up. 'We're building something real.'"
   },
   "tags": ["protector"]
  },
  {
   "id": "d8ec_establish_supply_lines",
   "text": "Let's establish supply lines first. Secure resources before expanding.",
   "goTo": "day8_evening_hub",
   "effects": {
    "time": 2,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": 2, "stamina": -2},
    "flagsSet": ["supply_lines_established"],
    "pushEvent": "'Smart. Resources first.' Alex nods. 'Let's secure our supply chain.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d8ec_recruit_more_people",
   "text": "Let's recruit more people first. We need more hands to expand.",
   "goTo": "day8_evening_hub",
   "effects": {
    "time": 2,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 2},
    "flagsSet": ["recruitment_drive"],
    "pushEvent": "'Good thinking. People are our greatest resource.' Alex's eyes light up."
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day8", "expansion"]
},
"day8_manage_resources": {
 "id": "day8_manage_resources",
 "text": "Day 8, 9:00 AM. You and Alex sit in the building's common area, surrounded by supply lists, rationing charts, and resource allocation plans. 'We need to be smart about this,' Alex says, pointing to a chart. 'Current food: 8 days at current consumption. Water: 12 days. Medicine: 4 days for critical needs.' They look up. 'We can stretch this. Better rationing, more efficient distribution, maybe some creative solutions.' The room is quiet except for the sound of children playing in the distance.",
 "choices": [
  {
   "id": "d8mr_implement_strict_rationing",
   "text": "Let's implement strict rationing. Everyone gets equal shares.",
   "goTo": "day8_evening_hub",
   "effects": {
    "time": 1,
    "persona": {"chill": 2, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": 1},
    "flagsSet": ["strict_rationing_implemented"],
    "pushEvent": "'Fair. Everyone gets the same.' Alex nods. 'No favorites.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d8mr_priority_based_rationing",
   "text": "Let's use priority-based rationing. Children and elderly first.",
   "goTo": "day8_evening_hub",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["priority_rationing_implemented"],
    "pushEvent": "'Compassionate. I like that.' Alex's eyes soften. 'They need us most.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d8mr_contribution_based_rationing",
   "text": "Let's use contribution-based rationing. Those who work get more.",
   "goTo": "day8_evening_hub",
   "effects": {
    "time": 1,
    "persona": {"chill": 1, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["contribution_rationing_implemented"],
    "pushEvent": "'Fair. Merit-based system.' Alex nods. 'Work hard, eat well.'"
   },
   "tags": ["chill"]
  }
 ],
 "tags": ["day8", "resource_management"]
},
"day8_establish_limits": {
 "id": "day8_establish_limits",
 "text": "Day 8, 9:00 AM. You and Alex stand at the building's main entrance, watching a group of survivors approach. 'We need to be clear about our limits,' Alex says quietly. 'We can't help everyone. We don't have the resources, the space, the capacity.' The group looks desperate—a family with young children, an elderly couple, a young man with a broken arm. 'We need to decide. Who do we help? Who do we turn away? And how do we live with those decisions?'",
 "choices": [
  {
   "id": "d8el_help_children_only",
   "text": "We help children and their families. Everyone else is on their own.",
   "goTo": "day8_evening_hub",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 2},
    "flagsSet": ["children_only_policy"],
    "pushEvent": "'Compassionate. I can respect that.' Alex's eyes soften. 'Children need us.'"
   },
   "tags": ["nice"]
  },
  {
   "id": "d8el_help_contributors_only",
   "text": "We help those who can contribute. No freeloaders.",
   "goTo": "day8_evening_hub",
   "effects": {
    "time": 1,
    "persona": {"chill": 1, "warlord": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["contributors_only_policy"],
    "pushEvent": "'Practical. I can respect that.' Alex nods. 'Everyone contributes.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d8el_turn_everyone_away",
   "text": "We turn everyone away. We can't afford to help anyone else.",
   "goTo": "day8_evening_hub",
   "effects": {
    "time": 1,
    "persona": {"warlord": 2, "rude": 1},
    "relationships": {"Alex": 1},
    "stats": {"stress": -2},
    "flagsSet": ["closed_door_policy"],
    "pushEvent": "'Hard but necessary.' Alex's expression becomes cold. 'Survival is harsh.'"
   },
   "tags": ["warlord"]
  }
 ],
 "tags": ["day8", "limits"]
},
"day8_evening_hub": {
 "id": "day8_evening_hub",
 "text": "Day 8, 6:00 PM. The sun sets on another day of building, planning, and hard decisions. You and Alex sit in the apartment, reviewing the day's progress. 'We're making real changes,' Alex says. 'Expanding, organizing, growing. But it's getting more complex. More people, more problems, more decisions to make.' They look at you. 'We need to think about tomorrow. About next week. About what kind of community we want to build here. About what kind of leaders we want to be.'",
 "choices": [
  {
   "id": "d8eh_plan_expansion",
   "text": "Let's plan more expansion. We're just getting started.",
   "goTo": "act1_family_hub",
   "effects": {
    "time": 1,
    "persona": {"protector": 2, "warlord": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": 1},
    "flagsSet": ["expansion_planning"],
    "pushEvent": "'Ambitious. I like it.' Alex's eyes light up. 'Let's see how big we can build this.'"
   },
   "tags": ["protector"]
  },
  {
   "id": "d8eh_consolidate_gains",
   "text": "Let's consolidate what we have. Make it solid before expanding.",
   "goTo": "act1_family_hub",
   "effects": {
    "time": 1,
    "persona": {"chill": 2},
    "relationships": {"Alex": 1},
    "stats": {"stress": -1},
    "flagsSet": ["consolidation_planning"],
    "pushEvent": "'Smart. Build on what works.' Alex nods. 'Let's make it solid.'"
   },
   "tags": ["chill"]
  },
  {
   "id": "d8eh_focus_community",
   "text": "Let's focus on community building. Strengthen relationships.",
   "goTo": "act1_family_hub",
   "effects": {
    "time": 1,
    "persona": {"nice": 2, "protector": 1},
    "relationships": {"Alex": 2},
    "stats": {"stress": -1},
    "flagsSet": ["community_building_focus"],
    "pushEvent": "'Important. People are everything.' Alex's eyes soften. 'Let's build something real.'"
   },
   "tags": ["nice"]
  }
 ],
 "tags": ["day8", "evening_hub"]
},
"apology_justified": {
 "id": "apology_justified",
 "text": "Apology path resolution. You apologized while opening the door. Alex is inside but hurt. Can you mend the relationship?",
 "choices": [
  {
   "id": "apology_ju_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "apology_justified resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "apology_ju_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "apology_justified resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "apology_ju_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "apology_justified resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"apology_make_amends": {
 "id": "apology_make_amends",
 "text": "Apology path resolution. You apologized while opening the door. Alex is inside but hurt. Can you mend the relationship?",
 "choices": [
  {
   "id": "apology_ma_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "apology_make_amends resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "apology_ma_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "apology_make_amends resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "apology_ma_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "apology_make_amends resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"apology_no_further": {
 "id": "apology_no_further",
 "text": "Apology path resolution. You apologized while opening the door. Alex is inside but hurt. Can you mend the relationship?",
 "choices": [
  {
   "id": "apology_no_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "apology_no_further resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "apology_no_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "apology_no_further resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "apology_no_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "apology_no_further resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"chen_abandoned_guilt_double": {
 "id": "chen_abandoned_guilt_double",
 "text": "Mrs. Chen storyline. An elderly survivor who challenges your moral compass. Your treatment of her reveals your true character.",
 "choices": [
  {
   "id": "chen_aband_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "chen_abandoned_guilt_double resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "chen_aband_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "chen_abandoned_guilt_double resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "chen_aband_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "chen_abandoned_guilt_double resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"chen_accepts_honesty": {
 "id": "chen_accepts_honesty",
 "text": "Mrs. Chen storyline. An elderly survivor who challenges your moral compass. Your treatment of her reveals your true character.",
 "choices": [
  {
   "id": "chen_accep_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "chen_accepts_honesty resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "chen_accep_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "chen_accepts_honesty resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "chen_accep_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "chen_accepts_honesty resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"chen_accepts_practice": {
 "id": "chen_accepts_practice",
 "text": "Mrs. Chen storyline. An elderly survivor who challenges your moral compass. Your treatment of her reveals your true character.",
 "choices": [
  {
   "id": "chen_accep_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "chen_accepts_practice resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "chen_accep_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "chen_accepts_practice resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "chen_accep_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "chen_accepts_practice resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"chen_accepts_pragmatic": {
 "id": "chen_accepts_pragmatic",
 "text": "Mrs. Chen storyline. An elderly survivor who challenges your moral compass. Your treatment of her reveals your true character.",
 "choices": [
  {
   "id": "chen_accep_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "chen_accepts_pragmatic resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "chen_accep_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "chen_accepts_pragmatic resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "chen_accep_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "chen_accepts_pragmatic resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"chen_distraction_play": {
 "id": "chen_distraction_play",
 "text": "Mrs. Chen storyline. An elderly survivor who challenges your moral compass. Your treatment of her reveals your true character.",
 "choices": [
  {
   "id": "chen_distr_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "chen_distraction_play resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "chen_distr_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "chen_distraction_play resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "chen_distr_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "chen_distraction_play resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"chen_forced_save": {
 "id": "chen_forced_save",
 "text": "Mrs. Chen storyline. An elderly survivor who challenges your moral compass. Your treatment of her reveals your true character.",
 "choices": [
  {
   "id": "chen_force_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "chen_forced_save resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "chen_force_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "chen_forced_save resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "chen_force_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "chen_forced_save resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"chen_hero_humble": {
 "id": "chen_hero_humble",
 "text": "Mrs. Chen storyline. An elderly survivor who challenges your moral compass. Your treatment of her reveals your true character.",
 "choices": [
  {
   "id": "chen_hero__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "chen_hero_humble resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "chen_hero__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "chen_hero_humble resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "chen_hero__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "chen_hero_humble resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"chen_hero_redemption": {
 "id": "chen_hero_redemption",
 "text": "Mrs. Chen storyline. An elderly survivor who challenges your moral compass. Your treatment of her reveals your true character.",
 "choices": [
  {
   "id": "chen_hero__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "chen_hero_redemption resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "chen_hero__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "chen_hero_redemption resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "chen_hero__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "chen_hero_redemption resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"chen_hero_self_proof": {
 "id": "chen_hero_self_proof",
 "text": "Mrs. Chen storyline. An elderly survivor who challenges your moral compass. Your treatment of her reveals your true character.",
 "choices": [
  {
   "id": "chen_hero__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "chen_hero_self_proof resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "chen_hero__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "chen_hero_self_proof resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "chen_hero__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "chen_hero_self_proof resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"chen_hide_together": {
 "id": "chen_hide_together",
 "text": "Mrs. Chen storyline. An elderly survivor who challenges your moral compass. Your treatment of her reveals your true character.",
 "choices": [
  {
   "id": "chen_hide__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "chen_hide_together resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "chen_hide__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "chen_hide_together resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "chen_hide__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "chen_hide_together resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"chen_left_behind": {
 "id": "chen_left_behind",
 "text": "Mrs. Chen storyline. An elderly survivor who challenges your moral compass. Your treatment of her reveals your true character.",
 "choices": [
  {
   "id": "chen_left__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "chen_left_behind resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "chen_left__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "chen_left_behind resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "chen_left__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "chen_left_behind resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"chen_trusts_logic": {
 "id": "chen_trusts_logic",
 "text": "Mrs. Chen storyline. An elderly survivor who challenges your moral compass. Your treatment of her reveals your true character.",
 "choices": [
  {
   "id": "chen_trust_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "chen_trusts_logic resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "chen_trust_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "chen_trusts_logic resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "chen_trust_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "chen_trusts_logic resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"cold_demands_control": {
 "id": "cold_demands_control",
 "text": "Cold logic path. You've embraced utilitarian calculus. Emotions are weakness. Survival is mathematics. But at what cost?",
 "choices": [
  {
   "id": "cold_deman_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "cold_demands_control resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "cold_deman_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "cold_demands_control resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "cold_deman_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "cold_demands_control resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"cold_doubled_down": {
 "id": "cold_doubled_down",
 "text": "Cold logic path. You've embraced utilitarian calculus. Emotions are weakness. Survival is mathematics. But at what cost?",
 "choices": [
  {
   "id": "cold_doubl_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "cold_doubled_down resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "cold_doubl_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "cold_doubled_down resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "cold_doubl_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "cold_doubled_down resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"cold_doubt_grows": {
 "id": "cold_doubt_grows",
 "text": "Cold logic path. You've embraced utilitarian calculus. Emotions are weakness. Survival is mathematics. But at what cost?",
 "choices": [
  {
   "id": "cold_doubt_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "cold_doubt_grows resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "cold_doubt_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "cold_doubt_grows resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "cold_doubt_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "cold_doubt_grows resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"cold_leverage_position": {
 "id": "cold_leverage_position",
 "text": "Cold logic path. You've embraced utilitarian calculus. Emotions are weakness. Survival is mathematics. But at what cost?",
 "choices": [
  {
   "id": "cold_lever_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "cold_leverage_position resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "cold_lever_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "cold_leverage_position resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "cold_lever_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "cold_leverage_position resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"cold_logic_cracks": {
 "id": "cold_logic_cracks",
 "text": "Cold logic path. You've embraced utilitarian calculus. Emotions are weakness. Survival is mathematics. But at what cost?",
 "choices": [
  {
   "id": "cold_logic_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "cold_logic_cracks resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "cold_logic_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "cold_logic_cracks resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "cold_logic_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "cold_logic_cracks resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"cold_random_fair": {
 "id": "cold_random_fair",
 "text": "Cold logic path. You've embraced utilitarian calculus. Emotions are weakness. Survival is mathematics. But at what cost?",
 "choices": [
  {
   "id": "cold_rando_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "cold_random_fair resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "cold_rando_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "cold_random_fair resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "cold_rando_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "cold_random_fair resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"cold_refuses_power": {
 "id": "cold_refuses_power",
 "text": "Cold logic path. You've embraced utilitarian calculus. Emotions are weakness. Survival is mathematics. But at what cost?",
 "choices": [
  {
   "id": "cold_refus_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "cold_refuses_power resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "cold_refus_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "cold_refuses_power resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "cold_refus_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "cold_refuses_power resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"cold_silent": {
 "id": "cold_silent",
 "text": "Cold logic path. You've embraced utilitarian calculus. Emotions are weakness. Survival is mathematics. But at what cost?",
 "choices": [
  {
   "id": "cold_silen_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "cold_silent resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "cold_silen_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "cold_silent resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "cold_silen_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "cold_silent resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"cold_triage_master": {
 "id": "cold_triage_master",
 "text": "Cold logic path. You've embraced utilitarian calculus. Emotions are weakness. Survival is mathematics. But at what cost?",
 "choices": [
  {
   "id": "cold_triag_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "cold_triage_master resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "cold_triag_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "cold_triage_master resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "cold_triag_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "cold_triage_master resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"cold_value_calc": {
 "id": "cold_value_calc",
 "text": "Cold logic path. You've embraced utilitarian calculus. Emotions are weakness. Survival is mathematics. But at what cost?",
 "choices": [
  {
   "id": "cold_value_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "cold_value_calc resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "cold_value_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "cold_value_calc resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "cold_value_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "cold_value_calc resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"convoy_alex_second": {
 "id": "convoy_alex_second",
 "text": "Convoy encounter. Survivors heading to rumored safe zone. Join them? Help them? Rob them? Trust is currency here.",
 "choices": [
  {
   "id": "convoy_ale_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "convoy_alex_second resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "convoy_ale_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "convoy_alex_second resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "convoy_ale_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "convoy_alex_second resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"convoy_fire_escape": {
 "id": "convoy_fire_escape",
 "text": "Convoy encounter. Survivors heading to rumored safe zone. Join them? Help them? Rob them? Trust is currency here.",
 "choices": [
  {
   "id": "convoy_fir_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "convoy_fire_escape resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "convoy_fir_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "convoy_fire_escape resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "convoy_fir_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "convoy_fire_escape resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"convoy_wait_thin": {
 "id": "convoy_wait_thin",
 "text": "Convoy encounter. Survivors heading to rumored safe zone. Join them? Help them? Rob them? Trust is currency here.",
 "choices": [
  {
   "id": "convoy_wai_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "convoy_wait_thin resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "convoy_wai_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "convoy_wait_thin resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "convoy_wai_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "convoy_wait_thin resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"demand_cautious_trust": {
 "id": "demand_cautious_trust",
 "text": "Continuation of demanding proof path. Trust damaged, must be rebuilt or abandoned. Alex remembers your harsh treatment.",
 "choices": [
  {
   "id": "demand_cau_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "demand_cautious_trust resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "demand_cau_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "demand_cautious_trust resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "demand_cau_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "demand_cautious_trust resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"demand_hierarchy_set": {
 "id": "demand_hierarchy_set",
 "text": "Continuation of demanding proof path. Trust damaged, must be rebuilt or abandoned. Alex remembers your harsh treatment.",
 "choices": [
  {
   "id": "demand_hie_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "demand_hierarchy_set resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "demand_hie_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "demand_hierarchy_set resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "demand_hie_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "demand_hierarchy_set resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"demand_justified": {
 "id": "demand_justified",
 "text": "Continuation of demanding proof path. Trust damaged, must be rebuilt or abandoned. Alex remembers your harsh treatment.",
 "choices": [
  {
   "id": "demand_jus_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "demand_justified resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "demand_jus_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "demand_justified resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "demand_jus_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "demand_justified resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"demand_make_amends": {
 "id": "demand_make_amends",
 "text": "Continuation of demanding proof path. Trust damaged, must be rebuilt or abandoned. Alex remembers your harsh treatment.",
 "choices": [
  {
   "id": "demand_mak_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "demand_make_amends resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "demand_mak_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "demand_make_amends resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "demand_mak_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "demand_make_amends resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"demand_no_apology": {
 "id": "demand_no_apology",
 "text": "Continuation of demanding proof path. Trust damaged, must be rebuilt or abandoned. Alex remembers your harsh treatment.",
 "choices": [
  {
   "id": "demand_no__a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "demand_no_apology resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "demand_no__b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "demand_no_apology resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "demand_no__c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "demand_no_apology resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"demand_professional_only": {
 "id": "demand_professional_only",
 "text": "Continuation of demanding proof path. Trust damaged, must be rebuilt or abandoned. Alex remembers your harsh treatment.",
 "choices": [
  {
   "id": "demand_pro_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "demand_professional_only resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "demand_pro_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "demand_professional_only resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "demand_pro_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "demand_professional_only resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"demand_relationship_rebuilt": {
 "id": "demand_relationship_rebuilt",
 "text": "Continuation of demanding proof path. Trust damaged, must be rebuilt or abandoned. Alex remembers your harsh treatment.",
 "choices": [
  {
   "id": "demand_rel_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "demand_relationship_rebuilt resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "demand_rel_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "demand_relationship_rebuilt resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "demand_rel_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "demand_relationship_rebuilt resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"ending_ghost_stair": {
 "id": "ending_ghost_stair",
 "text": "ENDING: Your journey concludes. Every choice mattered. Every relationship counted. This is your consequence.",
 "choices": [
  {
   "id": "ending_gho_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "ending_ghost_stair resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "ending_gho_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "ending_ghost_stair resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "ending_gho_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "ending_ghost_stair resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"ending_overlord": {
 "id": "ending_overlord",
 "text": "ENDING: Your journey concludes. Every choice mattered. Every relationship counted. This is your consequence.",
 "choices": [
  {
   "id": "ending_ove_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "ending_overlord resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "ending_ove_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "ending_overlord resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "ending_ove_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "ending_overlord resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"fight_alex_bait": {
 "id": "fight_alex_bait",
 "text": "Combat scenario. Infected swarm. Decisions made in seconds. Violence reveals character more than words ever could.",
 "choices": [
  {
   "id": "fight_alex_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "fight_alex_bait resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "fight_alex_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "fight_alex_bait resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "fight_alex_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "fight_alex_bait resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"fight_tactical": {
 "id": "fight_tactical",
 "text": "Combat scenario. Infected swarm. Decisions made in seconds. Violence reveals character more than words ever could.",
 "choices": [
  {
   "id": "fight_tact_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "fight_tactical resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "fight_tact_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "fight_tactical resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "fight_tact_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "fight_tactical resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"fight_together": {
 "id": "fight_together",
 "text": "Combat scenario. Infected swarm. Decisions made in seconds. Violence reveals character more than words ever could.",
 "choices": [
  {
   "id": "fight_toge_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "fight_together resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "fight_toge_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "fight_together resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "fight_toge_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "fight_together resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"fortify_building_path": {
 "id": "fortify_building_path",
 "text": "Fortification path. Dig in. Make a stand. The building is home now. Defend it or die trying.",
 "choices": [
  {
   "id": "fortify_bu_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "fortify_building_path resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "fortify_bu_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "fortify_building_path resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "fortify_bu_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "fortify_building_path resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"gather_survivors_path": {
 "id": "gather_survivors_path",
 "text": "Gathering survivors. Strength in numbers\u2014or more mouths to feed? Leadership emerges. Are you ready?",
 "choices": [
  {
   "id": "gather_sur_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "gather_survivors_path resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "gather_sur_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "gather_survivors_path resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "gather_sur_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "gather_survivors_path resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"guilt_savior_kids_first": {
 "id": "guilt_savior_kids_first",
 "text": "Guilt path. Alex's death haunts you. Every face is theirs. Redemption through saving others\u2014or self-destruction?",
 "choices": [
  {
   "id": "guilt_savi_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "guilt_savior_kids_first resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "guilt_savi_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "guilt_savior_kids_first resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "guilt_savi_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "guilt_savior_kids_first resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"guilt_savior_systematic": {
 "id": "guilt_savior_systematic",
 "text": "Guilt path. Alex's death haunts you. Every face is theirs. Redemption through saving others\u2014or self-destruction?",
 "choices": [
  {
   "id": "guilt_savi_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "guilt_savior_systematic resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "guilt_savi_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "guilt_savior_systematic resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "guilt_savi_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "guilt_savior_systematic resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"guilt_savior_team_build": {
 "id": "guilt_savior_team_build",
 "text": "Guilt path. Alex's death haunts you. Every face is theirs. Redemption through saving others\u2014or self-destruction?",
 "choices": [
  {
   "id": "guilt_savi_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "guilt_savior_team_build resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "guilt_savi_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "guilt_savior_team_build resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "guilt_savi_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "guilt_savior_team_build resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"hero_alex_test": {
 "id": "hero_alex_test",
 "text": "Hero path progression. You're trying to save everyone. Noble, exhausting, impossible. Alex watches you burn yourself out.",
 "choices": [
  {
   "id": "hero_alex__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "hero_alex_test resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "hero_alex__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "hero_alex_test resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "hero_alex__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "hero_alex_test resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"hero_rest_continue": {
 "id": "hero_rest_continue",
 "text": "Hero path progression. You're trying to save everyone. Noble, exhausting, impossible. Alex watches you burn yourself out.",
 "choices": [
  {
   "id": "hero_rest__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "hero_rest_continue resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "hero_rest__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "hero_rest_continue resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "hero_rest__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "hero_rest_continue resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"hero_returns_building": {
 "id": "hero_returns_building",
 "text": "Hero path progression. You're trying to save everyone. Noble, exhausting, impossible. Alex watches you burn yourself out.",
 "choices": [
  {
   "id": "hero_retur_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "hero_returns_building resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "hero_retur_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "hero_returns_building resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "hero_retur_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "hero_returns_building resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"hero_scout_solo": {
 "id": "hero_scout_solo",
 "text": "Hero path progression. You're trying to save everyone. Noble, exhausting, impossible. Alex watches you burn yourself out.",
 "choices": [
  {
   "id": "hero_scout_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "hero_scout_solo resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "hero_scout_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "hero_scout_solo resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "hero_scout_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "hero_scout_solo resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"hero_train_alex": {
 "id": "hero_train_alex",
 "text": "Hero path progression. You're trying to save everyone. Noble, exhausting, impossible. Alex watches you burn yourself out.",
 "choices": [
  {
   "id": "hero_train_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "hero_train_alex resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "hero_train_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "hero_train_alex resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "hero_train_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "hero_train_alex resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"loot_destroy_evidence": {
 "id": "loot_destroy_evidence",
 "text": "Looting aftermath. Resources vs humanity. Take from the dead? Study them? Honor them? Each choice costs something.",
 "choices": [
  {
   "id": "loot_destr_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "loot_destroy_evidence resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "loot_destr_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "loot_destroy_evidence resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "loot_destr_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "loot_destroy_evidence resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"loot_documents_everything": {
 "id": "loot_documents_everything",
 "text": "Looting aftermath. Resources vs humanity. Take from the dead? Study them? Honor them? Each choice costs something.",
 "choices": [
  {
   "id": "loot_docum_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "loot_documents_everything resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "loot_docum_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "loot_documents_everything resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "loot_docum_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "loot_documents_everything resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"loot_guilt_surfaces": {
 "id": "loot_guilt_surfaces",
 "text": "Looting aftermath. Resources vs humanity. Take from the dead? Study them? Honor them? Each choice costs something.",
 "choices": [
  {
   "id": "loot_guilt_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "loot_guilt_surfaces resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "loot_guilt_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "loot_guilt_surfaces resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "loot_guilt_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "loot_guilt_surfaces resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"loot_marcus_left": {
 "id": "loot_marcus_left",
 "text": "Looting aftermath. Resources vs humanity. Take from the dead? Study them? Honor them? Each choice costs something.",
 "choices": [
  {
   "id": "loot_marcu_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "loot_marcus_left resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "loot_marcu_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "loot_marcus_left resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "loot_marcu_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "loot_marcus_left resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"loot_marcus_studied": {
 "id": "loot_marcus_studied",
 "text": "Looting aftermath. Resources vs humanity. Take from the dead? Study them? Honor them? Each choice costs something.",
 "choices": [
  {
   "id": "loot_marcu_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "loot_marcus_studied resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "loot_marcu_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "loot_marcus_studied resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "loot_marcu_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "loot_marcus_studied resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"loot_marcus_talk_attempt": {
 "id": "loot_marcus_talk_attempt",
 "text": "Looting aftermath. Resources vs humanity. Take from the dead? Study them? Honor them? Each choice costs something.",
 "choices": [
  {
   "id": "loot_marcu_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "loot_marcus_talk_attempt resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "loot_marcu_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "loot_marcus_talk_attempt resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "loot_marcu_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "loot_marcus_talk_attempt resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"loot_radio_intel": {
 "id": "loot_radio_intel",
 "text": "Looting aftermath. Resources vs humanity. Take from the dead? Study them? Honor them? Each choice costs something.",
 "choices": [
  {
   "id": "loot_radio_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "loot_radio_intel resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "loot_radio_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "loot_radio_intel resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "loot_radio_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "loot_radio_intel resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"loot_respects_marcus": {
 "id": "loot_respects_marcus",
 "text": "Looting aftermath. Resources vs humanity. Take from the dead? Study them? Honor them? Each choice costs something.",
 "choices": [
  {
   "id": "loot_respe_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "loot_respects_marcus resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "loot_respe_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "loot_respects_marcus resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "loot_respe_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "loot_respects_marcus resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"loot_selective_morality": {
 "id": "loot_selective_morality",
 "text": "Looting aftermath. Resources vs humanity. Take from the dead? Study them? Honor them? Each choice costs something.",
 "choices": [
  {
   "id": "loot_selec_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "loot_selective_morality resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "loot_selec_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "loot_selective_morality resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "loot_selec_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "loot_selective_morality resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"loot_takes_all_cold": {
 "id": "loot_takes_all_cold",
 "text": "Looting aftermath. Resources vs humanity. Take from the dead? Study them? Honor them? Each choice costs something.",
 "choices": [
  {
   "id": "loot_takes_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "loot_takes_all_cold resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "loot_takes_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "loot_takes_all_cold resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "loot_takes_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "loot_takes_all_cold resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"numb_path": {
 "id": "numb_path",
 "text": "Numbness sets in. You watched Alex die. Feel nothing. Emotions are luxury. Survival is all. You're becoming something else.",
 "choices": [
  {
   "id": "numb_path_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "numb_path resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "numb_path_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "numb_path resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "numb_path_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "numb_path resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"partners_alex_choice": {
 "id": "partners_alex_choice",
 "text": "Partnership dynamics. You and Alex as equals. Disagreements happen. How you resolve them shapes everything.",
 "choices": [
  {
   "id": "partners_a_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "partners_alex_choice resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "partners_a_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "partners_alex_choice resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "partners_a_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "partners_alex_choice resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"partners_coin_flip": {
 "id": "partners_coin_flip",
 "text": "Partnership dynamics. You and Alex as equals. Disagreements happen. How you resolve them shapes everything.",
 "choices": [
  {
   "id": "partners_c_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "partners_coin_flip resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "partners_c_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "partners_coin_flip resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "partners_c_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "partners_coin_flip resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"partners_first_conflict": {
 "id": "partners_first_conflict",
 "text": "Partnership dynamics. You and Alex as equals. Disagreements happen. How you resolve them shapes everything.",
 "choices": [
  {
   "id": "partners_f_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "partners_first_conflict resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "partners_f_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "partners_first_conflict resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "partners_f_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "partners_first_conflict resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"partners_split_up": {
 "id": "partners_split_up",
 "text": "Partnership dynamics. You and Alex as equals. Disagreements happen. How you resolve them shapes everything.",
 "choices": [
  {
   "id": "partners_s_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "partners_split_up resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "partners_s_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "partners_split_up resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "partners_s_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "partners_split_up resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_cold_doubt": {
 "id": "path_cold_doubt",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_cold__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_cold_doubt resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_cold__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_cold_doubt resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_cold__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_cold_doubt resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_cold_statistics": {
 "id": "path_cold_statistics",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_cold__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_cold_statistics resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_cold__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_cold_statistics resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_cold__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_cold_statistics resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_cold_testing": {
 "id": "path_cold_testing",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_cold__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_cold_testing resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_cold__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_cold_testing resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_cold__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_cold_testing resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_guilt_rage": {
 "id": "path_guilt_rage",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_guilt_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_guilt_rage resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_guilt_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_guilt_rage resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_guilt_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_guilt_rage resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_guilt_self_harm": {
 "id": "path_guilt_self_harm",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_guilt_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_guilt_self_harm resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_guilt_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_guilt_self_harm resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_guilt_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_guilt_self_harm resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_hero_grounded": {
 "id": "path_hero_grounded",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_hero__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_hero_grounded resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_hero__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_hero_grounded resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_hero__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_hero_grounded resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_hero_manipulative": {
 "id": "path_hero_manipulative",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_hero__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_hero_manipulative resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_hero__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_hero_manipulative resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_hero__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_hero_manipulative resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_hero_rejects_label": {
 "id": "path_hero_rejects_label",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_hero__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_hero_rejects_label resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_hero__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_hero_rejects_label resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_hero__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_hero_rejects_label resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_loot_conflicted": {
 "id": "path_loot_conflicted",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_loot__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_loot_conflicted resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_loot__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_loot_conflicted resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_loot__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_loot_conflicted resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_loot_pragmatic": {
 "id": "path_loot_pragmatic",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_loot__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_loot_pragmatic resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_loot__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_loot_pragmatic resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_loot__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_loot_pragmatic resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_loot_selective": {
 "id": "path_loot_selective",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_loot__a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_loot_selective resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_loot__b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_loot_selective resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_loot__c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_loot_selective resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_watcher_cold": {
 "id": "path_watcher_cold",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_watch_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_watcher_cold resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_watch_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_watcher_cold resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_watch_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_watcher_cold resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_watcher_delayed": {
 "id": "path_watcher_delayed",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_watch_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_watcher_delayed resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_watch_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_watcher_delayed resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_watch_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_watcher_delayed resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_watcher_justified": {
 "id": "path_watcher_justified",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_watch_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_watcher_justified resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_watch_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_watcher_justified resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_watch_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_watcher_justified resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"path_watcher_study": {
 "id": "path_watcher_study",
 "text": "Major story path decision. Your choices have led you here. This decision will shape the narrative arc and determine available endings.",
 "choices": [
  {
   "id": "path_watch_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "path_watcher_study resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "path_watch_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "path_watcher_study resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "path_watch_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "path_watcher_study resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"quest_direct_route": {
 "id": "quest_direct_route",
 "text": "Quest path. You're searching for something specific. Family? Redemption? Supplies? The journey defines you.",
 "choices": [
  {
   "id": "quest_dire_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "quest_direct_route resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "quest_dire_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "quest_direct_route resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "quest_dire_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "quest_direct_route resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"quest_find_group": {
 "id": "quest_find_group",
 "text": "Quest path. You're searching for something specific. Family? Redemption? Supplies? The journey defines you.",
 "choices": [
  {
   "id": "quest_find_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "quest_find_group resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "quest_find_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "quest_find_group resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "quest_find_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "quest_find_group resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"quest_raid_first": {
 "id": "quest_raid_first",
 "text": "Quest path. You're searching for something specific. Family? Redemption? Supplies? The journey defines you.",
 "choices": [
  {
   "id": "quest_raid_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "quest_raid_first resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "quest_raid_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "quest_raid_first resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "quest_raid_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "quest_raid_first resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"quest_stealth_route": {
 "id": "quest_stealth_route",
 "text": "Quest path. You're searching for something specific. Family? Redemption? Supplies? The journey defines you.",
 "choices": [
  {
   "id": "quest_stea_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "quest_stealth_route resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "quest_stea_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "quest_stealth_route resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "quest_stea_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "quest_stealth_route resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"raid_supply_path": {
 "id": "raid_supply_path",
 "text": "Raid scenario. Take what you need by force. Resources are survival. Morality is weakness. Or is it?",
 "choices": [
  {
   "id": "raid_suppl_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "raid_supply_path resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "raid_suppl_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "raid_supply_path resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "raid_suppl_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "raid_supply_path resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"rush_convoy_path": {
 "id": "rush_convoy_path",
 "text": "Rushed decision. No time to think. Action over analysis. Sometimes survival demands speed over wisdom.",
 "choices": [
  {
   "id": "rush_convo_a",
   "text": "Choose pragmatism",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "rush_convoy_path resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "rush_convo_b",
   "text": "Choose compassion",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "rush_convoy_path resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "rush_convo_c",
   "text": "Choose efficiency",
   "goTo": "hub_convergence",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "rush_convoy_path resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"saved_verify": {
 "id": "saved_verify",
 "text": "Alex saved. They're alive. But the method matters. Instinct? Verification? Demand? Each creates different foundations.",
 "choices": [
  {
   "id": "saved_veri_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "saved_verify resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "saved_veri_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "saved_verify resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "saved_veri_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "saved_verify resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},
"supplies_through_door": {
 "id": "supplies_through_door",
 "text": "Supplies through door. You didn't let Alex in\u2014just passed supplies. They're alive but alone. The sounds outside fade to screaming, then silence.",
 "choices": [
  {
   "id": "supplies_t_a",
   "text": "Choose pragmatism",
   "goTo": "alex_dies_watched",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "supplies_through_door resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "supplies_t_b",
   "text": "Choose compassion",
   "goTo": "alex_dies_watched",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "supplies_through_door resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "supplies_t_c",
   "text": "Choose efficiency",
   "goTo": "alex_dies_watched",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "supplies_through_door resolved efficiently."
   },
   "tags": [
    "rude"
   ]
  }
 ],
 "tags": [
  "generated"
 ]
},

// Missing scenes added for completeness
 "day4_avoid_survivors": {
  "id": "day4_avoid_survivors",
  "text": "Day 4: You've decided to avoid other survivors for now. The risk of betrayal or infection is too high. You focus on securing your own survival and building your resources. This isolation comes with its own challenges and opportunities.",
  "choices": [
   {
    "id": "day4_avoid_a",
    "text": "Continue solo survival",
    "goTo": "intro",
    "effects": {
     "stats": {"stress": 1, "morality": -2},
     "pushEvent": "Continued solo survival approach."
    },
    "tags": ["solo"]
   },
   {
    "id": "day4_avoid_b",
    "text": "Reconsider and seek allies",
    "goTo": "intro",
    "effects": {
     "stats": {"stress": -1, "morality": 2},
     "pushEvent": "Reconsidered solo approach."
    },
    "tags": ["social"]
   }
  ],
  "tags": ["day4", "survival"]
 },

 "day2_trust_building": {
  "id": "day2_trust_building",
  "text": "Day 2: Building trust with other survivors is crucial for long-term survival. You work on establishing relationships, sharing resources, and creating bonds that will help everyone survive. Trust is earned through actions, not words.",
  "choices": [
   {
    "id": "day2_trust_a",
    "text": "Share resources generously",
    "goTo": "intro",
    "effects": {
     "stats": {"morality": 5, "health": -2},
     "relationships": {"Survivors": 3},
     "pushEvent": "Shared resources to build trust."
    },
    "tags": ["generous"]
   },
   {
    "id": "day2_trust_b",
    "text": "Be cautious but fair",
    "goTo": "intro",
    "effects": {
     "stats": {"morality": 2},
     "relationships": {"Survivors": 1},
     "pushEvent": "Built trust cautiously."
    },
    "tags": ["cautious"]
   }
  ],
  "tags": ["day2", "trust"]
 },

 "day4_compassionate_rules": {
  "id": "day4_compassionate_rules",
  "text": "Day 4: You establish rules for your group that prioritize compassion and mutual aid. Everyone contributes what they can, and everyone receives what they need. This approach builds strong community bonds but may not be sustainable in the long term.",
  "choices": [
   {
    "id": "day4_compassion_a",
    "text": "Maintain compassionate approach",
    "goTo": "intro",
    "effects": {
     "stats": {"morality": 5, "stress": 2},
     "pushEvent": "Maintained compassionate rules."
    },
    "tags": ["compassion"]
   },
   {
    "id": "day4_compassion_b",
    "text": "Adjust rules for sustainability",
    "goTo": "intro",
    "effects": {
     "stats": {"morality": 1, "stress": -1},
     "pushEvent": "Adjusted rules for sustainability."
    },
    "tags": ["pragmatic"]
   }
  ],
  "tags": ["day4", "rules"]
 },

 "day5_resource_management": {
  "id": "day5_resource_management",
  "text": "Day 5: Resource management becomes critical as supplies dwindle. You must decide how to allocate food, water, medical supplies, and other essentials. Fair distribution is important, but so is ensuring the group's survival.",
  "choices": [
   {
    "id": "day5_resource_a",
    "text": "Equal distribution for all",
    "goTo": "intro",
    "effects": {
     "stats": {"morality": 3, "stress": 1},
     "pushEvent": "Chose equal resource distribution."
    },
    "tags": ["equal"]
   },
   {
    "id": "day5_resource_b",
    "text": "Priority to essential workers",
    "goTo": "intro",
    "effects": {
     "stats": {"morality": 1, "stress": -1},
     "pushEvent": "Prioritized essential workers."
    },
    "tags": ["priority"]
   }
  ],
  "tags": ["day5", "resources"]
 },

 "day4_study_infected": {
  "id": "day4_study_infected",
  "text": "Day 4: You take time to study the infected, observing their behavior patterns, weaknesses, and strengths. Understanding your enemy is crucial for survival. This knowledge could save lives and help you avoid dangerous situations.",
  "choices": [
   {
    "id": "day4_study_a",
    "text": "Observe from safe distance",
    "goTo": "intro",
    "effects": {
     "stats": {"stress": -1},
     "pushEvent": "Studied infected safely."
    },
    "tags": ["observation"]
   },
   {
    "id": "day4_study_b",
    "text": "Take calculated risks for better data",
    "goTo": "intro",
    "effects": {
     "stats": {"health": -2, "stress": 2},
     "pushEvent": "Took risks for better intelligence."
    },
    "tags": ["risky"]
   }
  ],
  "tags": ["day4", "research"]
 }
});

})();

document.addEventListener("DOMContentLoaded", () => {
  if (typeof window.ConsequenceGame === "function" && window.STORY_DATABASE) {
    window.game = new window.ConsequenceGame();
  }
});