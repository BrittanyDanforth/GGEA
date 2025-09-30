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
  "text": "No thinking. Just action. You rip the door open. Alex stumbles forward. Behind them: infected, close. You grab Alex's collar, yank them inside with brutal force. Infected hand swipes\u2014misses by inch. You slam door. Lock. Infected slam outside. Door holds. Both on floor, hearts pounding. Alex looks at you. 'You could've been killed opening that fast.' True. You didn't even look. Just trusted. Just acted.",
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
    "popupText": "True heroism hurts."
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
    "popupText": "True heroism means sacrifice."
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
  "choices": [],
  "tags": [
   "ending"
  ],
  "isEnding": true,
  "endingType": "road_warden"
 },
 "ending_last_light": {
  "id": "ending_last_light",
  "text": "THE LAST LIGHT: The sanctuary grows. Floor by floor you reclaim the building. The infected can't break what you've built. Survivors call it 'The Light'\u2014the last place where humanity holds. You teach. You protect. You lead. The guilt over Alex transforms into purpose. You couldn't save them. But you saved everyone after. That has to count.",
  "choices": [],
  "tags": [
   "ending"
  ],
  "isEnding": true,
  "endingType": "last_light"
 },
 "ending_teacher": {
  "id": "ending_teacher",
  "text": "THE TEACHER: You teach them everything. Survival. Combat. First aid. How to read infected patterns. Your knowledge spreads. Soon there are ten teachers. Then a hundred. The city falls but the survivors carry your lessons. You die in a firefight protecting your students. They carry on. Knowledge is immortal.",
  "choices": [],
  "tags": [
   "ending"
  ],
  "isEnding": true,
  "endingType": "teacher"
 },
 "ending_burned_out": {
  "id": "ending_burned_out",
  "text": "THE BURNED OUT: You tried. God knows you tried. But there were too many. Too much need. Too few resources. One by one they died despite your efforts. The guilt compounds. Alex. Mrs. Chen. The Martinez kid. All of them. You sit in the empty building surrounded by ghosts. When the infected finally break through, you don't fight. You're already gone.",
  "choices": [],
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
  "text": "Branch scene 0: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (psycho) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb0_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_1",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "psycho": 1
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "fb0_b",
    "text": "Careful action",
    "goTo": "filler_branch_2",
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
    "id": "fb0_c",
    "text": "Social action",
    "goTo": "filler_branch_3",
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
    "id": "fb0_d",
    "text": "Selfish action",
    "goTo": "filler_branch_1",
    "effects": {
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_0"
  ]
 },
 "filler_branch_1": {
  "id": "filler_branch_1",
  "text": "Branch scene 1: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (nice) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb1_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_2",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb1_b",
    "text": "Careful action",
    "goTo": "filler_branch_3",
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
    "id": "fb1_c",
    "text": "Social action",
    "goTo": "filler_branch_4",
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
    "id": "fb1_d",
    "text": "Selfish action",
    "goTo": "filler_branch_2",
    "effects": {
     "inventoryAdd": "resource"
    },
    "tags": [
     "rude"
    ]
   }
  ],
  "tags": [
   "branch_1"
  ]
 },
 "filler_branch_2": {
  "id": "filler_branch_2",
  "text": "Branch scene 2: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (chill) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb2_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_3",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb2_b",
    "text": "Careful action",
    "goTo": "filler_branch_4",
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
    "id": "fb2_c",
    "text": "Social action",
    "goTo": "filler_branch_5",
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
    "id": "fb2_d",
    "text": "Selfish action",
    "goTo": "filler_branch_3",
    "effects": {
     "inventoryAdd": "resource"
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
  "text": "Branch scene 3: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (rude) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb3_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_4",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "rude": 1
     }
    },
    "tags": [
     "rude"
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
     }
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
     "inventoryAdd": "resource"
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
  "text": "Branch scene 4: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (psycho) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb4_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_5",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "psycho": 1
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "fb4_b",
    "text": "Careful action",
    "goTo": "filler_branch_6",
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
    "id": "fb4_c",
    "text": "Social action",
    "goTo": "filler_branch_7",
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
    "id": "fb4_d",
    "text": "Selfish action",
    "goTo": "filler_branch_5",
    "effects": {
     "inventoryAdd": "resource"
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
  "text": "Branch scene 5: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (nice) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb5_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_6",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb5_b",
    "text": "Careful action",
    "goTo": "filler_branch_7",
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
    "id": "fb5_c",
    "text": "Social action",
    "goTo": "filler_branch_8",
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
    "id": "fb5_d",
    "text": "Selfish action",
    "goTo": "filler_branch_6",
    "effects": {
     "inventoryAdd": "resource"
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
  "text": "Branch scene 6: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (chill) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb6_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_7",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "chill": 1
     }
    },
    "tags": [
     "chill"
    ]
   },
   {
    "id": "fb6_b",
    "text": "Careful action",
    "goTo": "filler_branch_8",
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
    "id": "fb6_c",
    "text": "Social action",
    "goTo": "filler_branch_9",
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
    "id": "fb6_d",
    "text": "Selfish action",
    "goTo": "filler_branch_7",
    "effects": {
     "inventoryAdd": "resource"
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
  "text": "Branch scene 7: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (rude) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb7_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_8",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "rude": 1
     }
    },
    "tags": [
     "rude"
    ]
   },
   {
    "id": "fb7_b",
    "text": "Careful action",
    "goTo": "filler_branch_9",
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
    "id": "fb7_c",
    "text": "Social action",
    "goTo": "filler_branch_10",
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
    "id": "fb7_d",
    "text": "Selfish action",
    "goTo": "filler_branch_8",
    "effects": {
     "inventoryAdd": "resource"
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
  "text": "Branch scene 8: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (psycho) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb8_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_9",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "psycho": 1
     }
    },
    "tags": [
     "psycho"
    ]
   },
   {
    "id": "fb8_b",
    "text": "Careful action",
    "goTo": "filler_branch_10",
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
    "id": "fb8_c",
    "text": "Social action",
    "goTo": "filler_branch_11",
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
    "id": "fb8_d",
    "text": "Selfish action",
    "goTo": "filler_branch_9",
    "effects": {
     "inventoryAdd": "resource"
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
  "text": "Branch scene 9: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (nice) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb9_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_10",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "nice": 1
     }
    },
    "tags": [
     "nice"
    ]
   },
   {
    "id": "fb9_b",
    "text": "Careful action",
    "goTo": "filler_branch_11",
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
    "id": "fb9_c",
    "text": "Social action",
    "goTo": "filler_branch_12",
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
    "id": "fb9_d",
    "text": "Selfish action",
    "goTo": "filler_branch_10",
    "effects": {
     "inventoryAdd": "resource"
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
  "text": "Branch scene 10: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (chill) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb10_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_11",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "chill": 1
     }
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
  "text": "Branch scene 11: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (rude) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb11_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_12",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "rude": 1
     }
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
  "text": "Branch scene 12: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (psycho) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb12_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_13",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "psycho": 1
     }
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
  "text": "Branch scene 13: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (nice) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb13_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_14",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "nice": 1
     }
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
  "text": "Branch scene 14: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (chill) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb14_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_15",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "chill": 1
     }
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
  "text": "Branch scene 15: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (rude) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb15_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_16",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "rude": 1
     }
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
  "text": "Branch scene 16: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (psycho) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb16_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_17",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "psycho": 1
     }
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
  "text": "Branch scene 17: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (nice) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb17_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_18",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "nice": 1
     }
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
  "text": "Branch scene 18: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (chill) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb18_a",
    "text": "Aggressive action",
    "goTo": "filler_branch_19",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "chill": 1
     }
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
  "text": "Branch scene 19: Complex situation requiring decision. Lives hang in balance. Resources are scarce. Time is running out. Your persona (rude) shapes your options. What do you do?",
  "choices": [
   {
    "id": "fb19_a",
    "text": "Aggressive action",
    "goTo": "hub_convergence",
    "effects": {
     "stats": {
      "stress": 2
     },
     "persona": {
      "rude": 1
     }
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
  "choices": [],
  "tags": [
   "ending"
  ],
  "isEnding": true,
  "endingType": "escaped"
 },
 "ending_stayed": {
  "id": "ending_stayed",
  "text": "THE LAST LIGHT: You stayed when everyone ran. Built sanctuary from ruins. The infected couldn't break what you protected. Months later: survivors call your building 'The Light.' Last beacon of hope in the dead city.",
  "choices": [],
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
  "choices": [],
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
"alex_bond_hard": {
 "id": "alex_bond_hard",
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
 "choices": [
  {
   "id": "alex_bond__a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_bond_hard resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_bond__b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_bond_hard resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_bond__c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_bond_hard resolved efficiently."
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
"alex_bond_purpose": {
 "id": "alex_bond_purpose",
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
 "choices": [
  {
   "id": "alex_bond__a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "alex_bond_purpose resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "alex_bond__b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "alex_bond_purpose resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "alex_bond__c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "alex_bond_purpose resolved efficiently."
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
"alex_cautious": {
 "id": "alex_cautious",
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Alex scene placeholder. This is a branching narrative moment with Alex that affects your relationship and future choices.",
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
 "text": "Apology path resolution. You apologized while opening the door. Alex is inside but hurt. Can you mend the relationship?",
 "choices": [
  {
   "id": "apology_de_a",
   "text": "Choose pragmatism",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "chill": 1
    },
    "pushEvent": "apology_deeper_accepted resolved pragmatically."
   },
   "tags": [
    "chill"
   ]
  },
  {
   "id": "apology_de_b",
   "text": "Choose compassion",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "nice": 1
    },
    "pushEvent": "apology_deeper_accepted resolved with kindness."
   },
   "tags": [
    "nice"
   ]
  },
  {
   "id": "apology_de_c",
   "text": "Choose efficiency",
   "goTo": "act1_family_hub",
   "effects": {
    "persona": {
     "rude": 1
    },
    "pushEvent": "apology_deeper_accepted resolved efficiently."
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
}
});

})();

document.addEventListener("DOMContentLoaded", () => {
  if (typeof window.ConsequenceGame === "function" && window.STORY_DATABASE) {
    window.game = new window.ConsequenceGame();
  }
});