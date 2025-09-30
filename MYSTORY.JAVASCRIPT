(() => {
  const STORAGE_KEY = "consequence_save_v1";
  const CONSEQUENCE_FLAGS = new Set([
    "joined_militia",
    "joined_raiders",
    "route_protector",
    "route_warlord",
    "route_fixer",
    "route_killer",
    "route_sociopath",
    "proof_protector_rescue",
    "proof_protector_stand",
    "proof_protector_beacon",
    "proof_protector_safeconvoy",
    "proof_warlord_blackout",
    "proof_warlord_tithe",
    "proof_warlord_stomp",
    "proof_warlord_supremacy",
    "proof_fixer_conduit",
    "proof_fixer_barter",
    "proof_fixer_web",
    "proof_fixer_omnimarket",
    "proof_killer_mark",
    "proof_killer_cull",
    "proof_killer_fear",
    "proof_killer_apex",
    "proof_sociopath_mirror",
    "proof_sociopath_isolate",
    "proof_sociopath_purge",
    "proof_sociopath_dominion",
    "rescued_convoy",
    "held_line",
    "shared_rations",
    "wall_breached",
    "convoy_betrayed",
    "refinery_burned"
  ]);

  const MUTEX = {
    faction: ["joined_militia", "joined_raiders", "faction_neutral"],
    route: [
      "route_protector",
      "route_warlord",
      "route_fixer",
      "route_killer",
      "route_sociopath"
    ]
  };

  const MAX_STAT = 100;
  const MIN_STAT = -100;

  const DEFAULT_STATE = {
    sceneId: "neutral_act1_hub_apartment",
    time: 0,
    stats: { health: 90, stamina: 12, stress: 8, morality: 0 },
    persona: {
      protector: 0,
      warlord: 0,
      fixer: 0,
      killer: 0,
      sociopath: 0
    },
    inventory: ["pocketknife", "old_radio", "flare"],
    flags: {},
    relationships: {},
    rngSeed: 1776,
    decisionTrace: [],
    schedule: []
  };

  function deepClone(obj) {
    return JSON.parse(JSON.stringify(obj));
  }

  function mulberry32(a) {
    return function () {
      let t = (a += 0x6d2b79f5);
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function clamp(value) {
    return Math.max(MIN_STAT, Math.min(MAX_STAT, value));
  }

  function getChoiceTarget(choice) {
    if (!choice) return null;
    const destination = choice.goTo ?? choice.next;
    return typeof destination === "string" && destination.length ? destination : null;
  }

  function setMutexFlag(state, group, flag) {
    if (!MUTEX[group]) return;
    for (const f of MUTEX[group]) {
      if (f !== flag) delete state.flags[f];
    }
    state.flags[flag] = true;
  }

  function ensureStats(state) {
    for (const key of Object.keys(state.stats)) {
      state.stats[key] = clamp(state.stats[key]);
    }
  }

  function resolveSchedule(state) {
    const next = [];
    for (const entry of state.schedule) {
      const updated = { ...entry, steps: entry.steps - 1 };
      if (updated.steps <= 0) {
        applyEffects(state, updated.apply || {});
      } else {
        next.push(updated);
      }
    }
    state.schedule = next;
  }

  function applyCost(state, cost) {
    if (!cost) return;
    if (typeof cost.time === "number") {
      state.time = Math.max(0, state.time + cost.time);
    }
    if (cost.stats) {
      for (const [k, v] of Object.entries(cost.stats)) {
        state.stats[k] = clamp((state.stats[k] || 0) - v);
      }
    }
    if (Array.isArray(cost.items)) {
      for (const item of cost.items) {
        const idx = state.inventory.indexOf(item);
        if (idx >= 0) state.inventory.splice(idx, 1);
      }
    }
  }

  function applyEffects(state, effects) {
    if (!effects) return;
    if (typeof effects.time === "number") {
      state.time = Math.max(0, state.time + effects.time);
    }
    if (effects.stats) {
      for (const [k, v] of Object.entries(effects.stats)) {
        state.stats[k] = clamp((state.stats[k] || 0) + v);
      }
    }
    if (effects.persona) {
      for (const [k, v] of Object.entries(effects.persona)) {
        state.persona[k] = clamp((state.persona[k] || 0) + v);
      }
    }
    if (Array.isArray(effects.inventoryAdd)) {
      for (const item of effects.inventoryAdd) {
        state.inventory.push(item);
      }
    }
    if (Array.isArray(effects.inventoryRemove)) {
      for (const item of effects.inventoryRemove) {
        const idx = state.inventory.indexOf(item);
        if (idx >= 0) state.inventory.splice(idx, 1);
      }
    }
    if (Array.isArray(effects.flagsSet)) {
      for (const flag of effects.flagsSet) {
        if (flag.startsWith("route_")) {
          setMutexFlag(state, "route", flag);
        } else if (MUTEX.faction && MUTEX.faction.includes(flag)) {
          setMutexFlag(state, "faction", flag);
        } else {
          state.flags[flag] = true;
        }
      }
    }
    if (Array.isArray(effects.flagsUnset)) {
      for (const flag of effects.flagsUnset) {
        delete state.flags[flag];
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
    if (effects.decisionTrace) {
      state.decisionTrace.push(effects.decisionTrace);
    }
  }

  function meetsRequirement(state, req) {
    if (!req) return true;
    if (Array.isArray(req.items)) {
      for (const item of req.items) {
        if (!state.inventory.includes(item)) return false;
      }
    }
    if (Array.isArray(req.flags)) {
      for (const flag of req.flags) {
        if (!state.flags[flag]) return false;
      }
    }
    if (Array.isArray(req.flagsNone)) {
      for (const flag of req.flagsNone) {
        if (state.flags[flag]) return false;
      }
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
    if (Array.isArray(req.items) && req.items.length) {
      parts.push(`Need: ${req.items.join(", ")}`);
    }
    if (Array.isArray(req.flags) && req.flags.length) {
      parts.push(`Flags: ${req.flags.join(", ")}`);
    }
    return parts.join(" · ");
  }

  function shouldPopup(choice) {
    const fx = choice.effects || {};
    const rel = fx.relationships || {};
    const relSpike = Object.values(rel).some((v) => Math.abs(v) >= 5);
    const flips = (fx.flagsSet || []).some((f) => CONSEQUENCE_FLAGS.has(f));
    return relSpike || flips;
  }

  class ConsequenceGame {
    constructor() {
      this.state = deepClone(DEFAULT_STATE);
      this.random = mulberry32(this.state.rngSeed);
      this.dom = {
        stats: document.getElementById("stats"),
        sceneText: document.getElementById("scene-text"),
        choices: document.getElementById("choices"),
        inventory: document.getElementById("inventory-list"),
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
      if (newGameBtn) {
        newGameBtn.addEventListener("click", () => {
          this.reset();
        });
      }

      const continueBtn = document.getElementById("continue-game");
      if (continueBtn) {
        continueBtn.addEventListener("click", () => {
          this.load();
          this.renderScene(this.state.sceneId);
        });
      }

      const saveBtn = document.getElementById("save-game");
      if (saveBtn) {
        saveBtn.addEventListener("click", () => {
          this.save();
        });
      }

      const loadBtn = document.getElementById("load-game");
      if (loadBtn) {
        loadBtn.addEventListener("click", () => {
          const fileInput = document.getElementById("file-loader");
          if (fileInput) fileInput.click();
        });
      }

      const exportBtn = document.getElementById("export-game");
      if (exportBtn) {
        exportBtn.addEventListener("click", () => {
          this.export();
        });
      }

      const fileLoader = document.getElementById("file-loader");
      if (fileLoader) {
        fileLoader.addEventListener("change", (ev) => {
          const files = ev.target && ev.target.files;
          const file = files && files[0];
          if (!file) return;
          const reader = new FileReader();
          reader.onload = (e) => {
            try {
              const data = JSON.parse(e.target.result);
              this.state = { ...deepClone(DEFAULT_STATE), ...data };
              this.random = mulberry32(this.state.rngSeed || 1337);
              this.renderScene(this.state.sceneId);
            } catch (err) {
              console.warn("Failed to load save", err);
            }
          };
          reader.readAsText(file);
        });
      }

      const toggleBtn = document.getElementById("toggle-backend");
      if (toggleBtn) {
        toggleBtn.addEventListener("click", () => {
          const backend = document.getElementById("backend-content");
          if (!backend) return;
          backend.classList.toggle("hidden");
          const expanded = backend.classList.contains("hidden") ? "false" : "true";
          toggleBtn.setAttribute("aria-expanded", expanded);
        });
      }

      if (this.dom.consequenceOk) {
        this.dom.consequenceOk.addEventListener("click", () => {
          this.hidePopup();
        });
      }
    }

    reset() {
      this.state = deepClone(DEFAULT_STATE);
      this.random = mulberry32(this.state.rngSeed);
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
        this.random = mulberry32(this.state.rngSeed || 1337);
        this.eventLog = parsed.__eventLog || [];
        this.journal = parsed.__journal || [];
      } catch (err) {
        console.warn("Failed to load save", err);
      }
    }

    save() {
      try {
        const data = {
          ...this.state,
          __eventLog: this.eventLog,
          __journal: this.journal
        };
        localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
      } catch (err) {
        console.warn("Failed to save", err);
      }
    }

    export() {
      const data = {
        ...this.state,
        __eventLog: this.eventLog,
        __journal: this.journal
      };
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `consequence-save-${Date.now()}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      this.pushEvent("Exported save to file.", "discovery");
    }

    makeChoice(choice) {
      const scene = window.STORY_DATABASE[this.state.sceneId];
      if (!scene) return;
      if (!choice) return;

      const reqMet = meetsRequirement(this.state, choice.req);
      if (!reqMet) return;

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
      nextState.decisionTrace = [...nextState.decisionTrace, `${scene.id}::${choice.id || choice.text}`];

      this.state = nextState;
      this.random = mulberry32(this.state.rngSeed || 1337);
      this.save();

      if (shouldPopup(choice)) {
        this.showPopup(choice.popupText || "They will remember this.");
      }

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
        this.displayStory(`Missing scene: ${sceneId}`);
        return;
      }

      this.state.sceneId = sceneId;
      resolveSchedule(this.state);
      ensureStats(this.state);

      if (scene.timeDelta) {
        this.state.time = Math.max(0, this.state.time + scene.timeDelta);
      }

      if (scene.flagsSet) {
        applyEffects(this.state, { flagsSet: scene.flagsSet });
      }

      this.displayStory(scene.text, scene);
      this.displayChoices(scene);
      this.renderStats();
      this.renderInventory();
      this.renderPersona();
      this.renderRelationships();
      this.renderDebug();
      this.updateTime();
      this.autosaveJournal(scene);
    }

    autosaveJournal(scene) {
      if (!scene || !scene.tags) return;
      const headline = `${scene.tags.includes("setpiece") ? "Set Piece" : "Scene"}: ${scene.text.slice(0, 40)}…`;
      if (!this.journal.find((j) => j.headline === headline)) {
        this.journal.push({ headline, note: scene.notes || "" });
      }
      this.renderJournal();
    }

    displayStory(text, scene) {
      if (!this.dom.sceneText) return;
      this.dom.sceneText.innerHTML = "";
      const paragraphs = Array.isArray(text) ? text : [text];
      for (const line of paragraphs) {
        const p = document.createElement("p");
        p.textContent = line;
        this.dom.sceneText.appendChild(p);
      }
      if (scene && scene.personaFlavor) {
        const flavor = document.createElement("div");
        flavor.className = "persona-flavor";
        for (const [key, value] of Object.entries(scene.personaFlavor)) {
          const span = document.createElement("p");
          span.textContent = `${key.toUpperCase()}: ${value}`;
          flavor.appendChild(span);
        }
        this.dom.sceneText.appendChild(flavor);
      }
    }

    displayChoices(scene) {
      if (!this.dom.choices) return;
      this.dom.choices.innerHTML = "";
      const choices = (scene.choices || []).filter((choice) => choice && (getChoiceTarget(choice) || choice.effects));
      const enabledChoices = [];

      for (const choice of choices) {
        const button = document.createElement("button");
        button.className = "choice";
        button.type = "button";
        button.dataset.type = (choice.tags && choice.tags[0]) || choice.type || "";
        button.innerHTML = `<span class="choice-text">${choice.text}</span>`;

        const met = meetsRequirement(this.state, choice.req);
        if (!met) {
          button.classList.add("disabled");
          button.disabled = true;
          button.title = choice.blockedReason || formatRequirement(choice.req);
        } else {
          button.addEventListener("click", () => this.makeChoice(choice));
          enabledChoices.push(choice);
        }

        this.dom.choices.appendChild(button);
      }

      if (enabledChoices.length === 0) {
        const fallback = {
          id: "fail_forward",
          text: "Push through the panic (gain stress, +1h)",
          goTo: this.state.sceneId,
          effects: {
            time: 1,
            stats: { stress: 4, stamina: -1 }
          },
          tags: ["survival"],
          popupText: "You scrape forward despite the odds."
        };
        const button = document.createElement("button");
        button.className = "choice";
        button.type = "button";
        button.textContent = fallback.text;
        button.addEventListener("click", () => this.makeChoice(fallback));
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
        span.textContent = "No known contacts.";
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

    renderJournal() {
      if (!this.dom.journal) return;
      this.dom.journal.innerHTML = "";
      for (const entry of this.journal) {
        const node = document.createElement("div");
        node.className = "journal-item";
        const title = document.createElement("div");
        title.className = "journal-title";
        title.textContent = entry.headline;
        const objective = document.createElement("div");
        objective.className = "journal-objective";
        objective.textContent = entry.note || "";
        node.appendChild(title);
        node.appendChild(objective);
        this.dom.journal.appendChild(node);
      }
      if (this.dom.objectiveCount) {
        this.dom.objectiveCount.textContent = `${this.journal.length} objectives`;
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
      if (this.dom.worldTime) {
        this.dom.worldTime.textContent = `T+${this.state.time}h`;
      }
      if (this.dom.dayhour) {
        const day = Math.floor(this.state.time / 24);
        const hour = this.state.time % 24;
        this.dom.dayhour.textContent = `Day ${day} · ${hour.toString().padStart(2, "0")}:00`;
      }
      if (this.dom.traumaBar) {
        const stress = clamp(this.state.stats.stress || 0);
        const pct = Math.min(100, Math.max(0, (stress / 100) * 100));
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
  }

  window.ConsequenceGame = ConsequenceGame;

  window.STORY_DATABASE = window.STORY_DATABASE || {};

  Object.assign(window.STORY_DATABASE, {
    neutral_act1_hub_apartment: {
      id: "neutral_act1_hub_apartment",
      text: "Sirens fade beneath rain slamming broken windows. Smoke coils in the stairwell; frightened voices crowd the hall. Whatever you choose will ripple for days.",
      tags: ["hub", "act1"],
      choices: [
        {
          id: "pick_protector",
          text: "Shield the families on your floor (Protector)",
          goTo: "good_act1_setpiece_stairwell_rescue",
          effects: {
            flagsSet: ["route_protector"],
            persona: { protector: 2 },
            stats: { morality: 2, stress: 2 },
            pushEvent: "You swore to keep them safe."
          },
          tags: ["leader"]
        },
        {
          id: "pick_warlord",
          text: "Seize the blackout and demand obedience (Warlord)",
          goTo: "ant_act1_setpiece_blackout_trap",
          effects: {
            flagsSet: ["route_warlord"],
            persona: { warlord: 2 },
            stats: { morality: -2, stress: -1 },
            pushEvent: "Fear becomes your loudspeaker."
          },
          tags: ["combat"]
        },
        {
          id: "pick_fixer",
          text: "Cut deals with the stranded convoy (Fixer)",
          goTo: "man_act1_setpiece_convoy_deal",
          effects: {
            flagsSet: ["route_fixer"],
            persona: { fixer: 2 },
            relationships: { Convoy: 5 },
            pushEvent: "A handshake replaces a gun."
          },
          tags: ["social"]
        },
        {
          id: "pick_killer",
          text: "Hunt the corridor's threats in the dark (Killer)",
          goTo: "killer_act1_setpiece_corridor_hunt",
          effects: {
            flagsSet: ["route_killer"],
            persona: { killer: 2 },
            stats: { morality: -3, stress: -2 },
            pushEvent: "You melt into the shadows with a blade."
          },
          tags: ["stealth"]
        },
        {
          id: "pick_sociopath",
          text: "Exploit every panic to make them depend on you (Sociopath)",
          goTo: "socio_act1_setpiece_gaslight",
          effects: {
            flagsSet: ["route_sociopath"],
            persona: { sociopath: 2 },
            stats: { morality: -1, stress: 1 },
            pushEvent: "You spin fear into leverage."
          },
          tags: ["moral"]
        }
      ]
    },
    good_act1_setpiece_stairwell_rescue: {
      id: "good_act1_setpiece_stairwell_rescue",
      text: "The stairwell barricade bows inward. Soot-streaked kids cling to banisters while the groan of the horde builds from below.",
      tags: ["setpiece", "act1", "leader"],
      choices: [
        {
          id: "brace_wall",
          text: "Brace the door with your own body (−2 STA)",
          goTo: "good_act1_branch_hold_line",
          cost: { stats: { stamina: 2 } },
          effects: {
            stats: { stress: 3, morality: 2 },
            persona: { protector: 1 },
            pushEvent: "The barricade holds by inches."
          },
          tags: ["combat"]
        },
        {
          id: "stage_decoy",
          text: "Stage a decoy with blaring radios",
          goTo: "good_act1_branch_hold_line",
          effects: {
            inventoryRemove: ["old_radio"],
            stats: { stress: 1 },
            persona: { protector: 1 }
          },
          tags: ["survival"]
        },
        {
          id: "guide_service",
          text: "Guide families through the service corridor (STA ≥ 10)",
          goTo: "good_act1_branch_escape",
          req: { stats: { stamina: { gte: 10 } } },
          blockedReason: "Need stamina ≥ 10",
          effects: {
            stats: { stress: 2 },
            persona: { protector: 1 },
            pushEvent: "You lead them under the smoke."
          },
          tags: ["stealth"]
        },
        {
          id: "signal_roof",
          text: "Signal the roof for evac (need flare)",
          goTo: "good_act1_branch_escape",
          req: { items: ["flare"] },
          blockedReason: "Need a flare",
          effects: {
            stats: { stress: 4 },
            persona: { protector: 2 }
          },
          tags: ["leader"]
        }
      ]
    },

    good_act1_branch_hold_line: {
      id: "good_act1_branch_hold_line",
      text: "Sweat and splinters. You and the neighbors form a living shield until the pounding quiets and the youngest are ushered out.",
      tags: ["act1", "moral"],
      choices: [
        {
          id: "count_survivors",
          text: "Count every survivor and log their needs.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            flagsSet: ["held_line", "proof_protector_rescue"],
            stats: { stress: 2 },
            persona: { protector: 1 }
          },
          tags: ["leader"]
        },
        {
          id: "patch_arms",
          text: "Patch bruised arms before moving on.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            inventoryAdd: ["makeshift_splint"],
            stats: { morality: 1 }
          },
          tags: ["survival"]
        }
      ]
    },

    good_act1_branch_escape: {
      id: "good_act1_branch_escape",
      text: "You hustle families through dripping maintenance halls, marking safe corners as the roar of the stairwell fades.",
      tags: ["act1", "stealth"],
      choices: [
        {
          id: "mark_path",
          text: "Mark the tunnel as a safe route.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            flagsSet: ["proof_protector_rescue"],
            inventoryAdd: ["chalk"]
          },
          tags: ["leader"]
        },
        {
          id: "send_signal",
          text: "Send coordinates to the stadium scouts.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            relationships: { Stadium: 3 },
            stats: { stress: 1 }
          },
          tags: ["social"]
        }
      ]
    },
    ant_act1_setpiece_blackout_trap: {
      id: "ant_act1_setpiece_blackout_trap",
      text: "Flickering emergency lights paint the lobby red. Raiders slam their makeshift battering ram as tenants huddle around you, waiting for orders.",
      tags: ["setpiece", "act1", "combat"],
      choices: [
        {
          id: "kill_power",
          text: "Kill the power and speak in the dark",
          goTo: "ant_act1_branch_dominion",
          effects: {
            flagsSet: ["proof_warlord_blackout"],
            persona: { warlord: 1 },
            stats: { morality: -2, stress: -1 }
          },
          tags: ["moral"]
        },
        {
          id: "rig_exits",
          text: "Rig the exits with trip-wire mines (need charges)",
          goTo: "ant_act1_branch_dominion",
          req: { items: ["charges"] },
          blockedReason: "Need explosive charges",
          effects: {
            stats: { stress: -3 },
            persona: { warlord: 2 }
          },
          tags: ["combat"]
        },
        {
          id: "extract_tithe",
          text: "Extract a tithe from every shop",
          goTo: "ant_act1_branch_tithe",
          effects: {
            inventoryAdd: ["tribute_crate"],
            persona: { warlord: 1 },
            stats: { morality: -2 }
          },
          tags: ["social"]
        },
        {
          id: "crush_captain",
          text: "Crush the raider captain in front of everyone",
          goTo: "ant_act1_branch_dominion",
          effects: {
            relationships: { Raiders: -6 },
            stats: { morality: -3 },
            persona: { warlord: 1 }
          },
          tags: ["combat"]
        }
      ]
    },

    ant_act1_branch_dominion: {
      id: "ant_act1_branch_dominion",
      text: "Darkness swallows the block. Your voice becomes the only point of law, promising survival in exchange for allegiance.",
      tags: ["act1", "combat"],
      choices: [
        {
          id: "appoint_enforcers",
          text: "Appoint enforcers and brand your sigil.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            flagsSet: ["proof_warlord_stomp"],
            relationships: { "Enforcers": 5 },
            stats: { morality: -2 }
          },
          tags: ["moral"]
        },
        {
          id: "offer_protection",
          text: "Offer protection to those who tithe.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            flagsSet: ["proof_warlord_blackout"],
            inventoryAdd: ["favors_ledger"],
            stats: { stress: -1 }
          },
          tags: ["social"]
        }
      ]
    },

    ant_act1_branch_tithe: {
      id: "ant_act1_branch_tithe",
      text: "You count tribute by flashlight, noting who hesitates and who falls in line.",
      tags: ["act1", "social"],
      choices: [
        {
          id: "hoard_tribute",
          text: "Hoard tribute for later expansion.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            flagsSet: ["proof_warlord_tithe"],
            inventoryAdd: ["fuel_cells", "charges"],
            stats: { morality: -1 }
          },
          tags: ["survival"]
        },
        {
          id: "gift_raiders",
          text: "Gift tribute to the raiders to buy loyalty.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            inventoryRemove: ["tribute_crate"],
            relationships: { Raiders: 4 },
            stats: { stress: -2 }
          },
          tags: ["social"]
        }
      ]
    },
    man_act1_setpiece_convoy_deal: {
      id: "man_act1_setpiece_convoy_deal",
      text: "Convoy engines idle below, fuel fumes thick. Drivers argue over maps while militia spotters watch from shattered balconies.",
      tags: ["setpiece", "act1", "social"],
      choices: [
        {
          id: "broker_pass",
          text: "Broker a safe lane through the stadium lines",
          goTo: "man_act1_branch_coop",
          effects: {
            flagsSet: ["proof_fixer_conduit"],
            relationships: { Convoy: 4, Stadium: 3 },
            persona: { fixer: 1 }
          },
          tags: ["social"]
        },
        {
          id: "sell_secrets",
          text: "Sell curfew intel to both sides",
          goTo: "man_act1_branch_web",
          effects: {
            inventoryAdd: ["encoded_map"],
            stats: { morality: -1 },
            persona: { fixer: 1 }
          },
          tags: ["moral"]
        },
        {
          id: "double_cross",
          text: "Promise escort then tip the raiders",
          goTo: "man_act1_branch_betray",
          effects: {
            flagsSet: ["convoy_betrayed"],
            stats: { morality: -3 },
            persona: { fixer: 1 }
          },
          tags: ["stealth"]
        },
        {
          id: "swap_supplies",
          text: "Swap antibiotics for fuel markers (need antibiotics)",
          goTo: "man_act1_branch_coop",
          req: { items: ["antibiotics"] },
          blockedReason: "Need antibiotics",
          effects: {
            inventoryRemove: ["antibiotics"],
            inventoryAdd: ["fuel_markers"],
            flagsSet: ["proof_fixer_barter"]
          },
          tags: ["survival"]
        }
      ]
    },

    man_act1_branch_coop: {
      id: "man_act1_branch_coop",
      text: "You ink signatures on an ammo crate lid. Radios crackle with rerouted patrols while grateful drivers hand you markers.",
      tags: ["act1", "social"],
      choices: [
        {
          id: "bank_favor",
          text: "Bank the favor for the next act.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            flagsSet: ["proof_fixer_conduit"],
            relationships: { Convoy: 2 }
          },
          tags: ["social"]
        },
        {
          id: "quiet_donation",
          text: "Quietly fund the stadium medics.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            relationships: { Stadium: 3 },
            stats: { morality: 1 }
          },
          tags: ["moral"]
        }
      ]
    },

    man_act1_branch_web: {
      id: "man_act1_branch_web",
      text: "You spin curfew intel into a network. Each faction thinks you're theirs.",
      tags: ["act1", "social"],
      choices: [
        {
          id: "track_favors",
          text: "Track favors in a private ledger.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            flagsSet: ["proof_fixer_web"],
            inventoryAdd: ["favor_tokens"]
          },
          tags: ["survival"]
        },
        {
          id: "seed_discord",
          text: "Seed discord between raiders and convoy.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            relationships: { Raiders: -3, Convoy: 2 },
            stats: { morality: -1 }
          },
          tags: ["moral"]
        }
      ]
    },

    man_act1_branch_betray: {
      id: "man_act1_branch_betray",
      text: "Your whisper reaches the raiders before the convoy rolls. Screams echo under the rain, and you pocket the spoils.",
      tags: ["act1", "stealth"],
      choices: [
        {
          id: "count_profit",
          text: "Count profit and prepare a cover story.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            flagsSet: ["proof_fixer_barter"],
            inventoryAdd: ["bloodied_chits"],
            stats: { morality: -2 }
          },
          tags: ["moral"]
        },
        {
          id: "erase_traces",
          text: "Erase traces to keep trust alive.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            stats: { stress: 2 },
            persona: { fixer: 1 }
          },
          tags: ["stealth"]
        }
      ]
    },
    killer_act1_setpiece_corridor_hunt: {
      id: "killer_act1_setpiece_corridor_hunt",
      text: "The hallway reeks of bleach and fear. Predators prowl the blackout, and every scream could be silenced—by you.",
      tags: ["setpiece", "act1", "stealth"],
      choices: [
        {
          id: "mark_targets",
          text: "Mark the loudest threats for removal",
          goTo: "killer_act1_branch_mark",
          effects: {
            flagsSet: ["proof_killer_mark"],
            persona: { killer: 1 },
            stats: { stress: -3 }
          },
          tags: ["stealth"]
        },
        {
          id: "stage_accident",
          text: "Stage an accident down the stairwell",
          goTo: "killer_act1_branch_mark",
          effects: {
            stats: { morality: -2 },
            persona: { killer: 1 }
          },
          tags: ["combat"]
        },
        {
          id: "cull_stragglers",
          text: "Cull the stragglers who slow you",
          goTo: "killer_act1_branch_cull",
          effects: {
            stats: { morality: -4 },
            persona: { killer: 2 }
          },
          tags: ["moral"]
        },
        {
          id: "harvest_supplies",
          text: "Harvest supplies from the fallen",
          goTo: "killer_act1_branch_cull",
          effects: {
            inventoryAdd: ["trophy_dogtags"],
            stats: { stress: -1 }
          },
          tags: ["survival"]
        }
      ]
    },

    killer_act1_branch_mark: {
      id: "killer_act1_branch_mark",
      text: "You strike, silent and precise. The threats vanish, and whispers about the ghost on the ninth floor begin.",
      tags: ["act1", "stealth"],
      choices: [
        {
          id: "leave_warning",
          text: "Leave a warning carved in the drywall.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            flagsSet: ["proof_killer_fear"],
            stats: { stress: -2 }
          },
          tags: ["moral"]
        },
        {
          id: "stash_weapons",
          text: "Stash scavenged weapons for later.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            inventoryAdd: ["throwing_knife"],
            persona: { killer: 1 }
          },
          tags: ["survival"]
        }
      ]
    },

    killer_act1_branch_cull: {
      id: "killer_act1_branch_cull",
      text: "Blood mixes with rainwater. Survivors keep their heads down when you pass.",
      tags: ["act1", "moral"],
      choices: [
        {
          id: "catalog_prey",
          text: "Catalog the next targets.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            flagsSet: ["proof_killer_cull"],
            persona: { killer: 1 },
            stats: { morality: -2 }
          },
          tags: ["stealth"]
        },
        {
          id: "clean_blade",
          text: "Clean your blade and prepare for act two.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            stats: { stress: -1 }
          },
          tags: ["survival"]
        }
      ]
    },
    socio_act1_setpiece_gaslight: {
      id: "socio_act1_setpiece_gaslight",
      text: "Neighbors whisper your name. In a crisis, truth is malleable. You can make their terror orbit you.",
      tags: ["setpiece", "act1", "moral"],
      choices: [
        {
          id: "spread_rumor",
          text: "Spread rumors that only you know escape routes",
          goTo: "socio_act1_branch_isolate",
          effects: {
            flagsSet: ["proof_sociopath_mirror"],
            persona: { sociopath: 1 },
            stats: { stress: -1 }
          },
          tags: ["social"]
        },
        {
          id: "invent_threat",
          text: "Invent a phantom threat to keep them pliant",
          goTo: "socio_act1_branch_isolate",
          effects: {
            stats: { morality: -1 },
            persona: { sociopath: 1 }
          },
          tags: ["moral"]
        },
        {
          id: "trade_favors",
          text: "Trade safety for secrets",
          goTo: "socio_act1_branch_puppet",
          effects: {
            inventoryAdd: ["blackmail_cache"],
            persona: { sociopath: 1 }
          },
          tags: ["social"]
        },
        {
          id: "stage_crisis",
          text: "Stage a crisis only you can solve",
          goTo: "socio_act1_branch_puppet",
          effects: {
            flagsSet: ["proof_sociopath_isolate"],
            stats: { morality: -2 }
          },
          tags: ["leader"]
        }
      ]
    },

    socio_act1_branch_isolate: {
      id: "socio_act1_branch_isolate",
      text: "The building clings to your every word. You ration hope by the syllable.",
      tags: ["act1", "social"],
      choices: [
        {
          id: "demand_tithes",
          text: "Demand emotional tithes for guidance.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            flagsSet: ["proof_sociopath_isolate"],
            relationships: { Tenants: -4 }
          },
          tags: ["moral"]
        },
        {
          id: "promise_salvation",
          text: "Promise salvation later—for a price.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            flagsSet: ["proof_sociopath_mirror"],
            inventoryAdd: ["IOU_stack"]
          },
          tags: ["social"]
        }
      ]
    },

    socio_act1_branch_puppet: {
      id: "socio_act1_branch_puppet",
      text: "Secrets fill your pocket. The desperate tell you everything because you nod at the right moments.",
      tags: ["act1", "social"],
      choices: [
        {
          id: "catalog_secrets",
          text: "Catalog secrets for leverage.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            flagsSet: ["proof_sociopath_purge"],
            persona: { sociopath: 1 }
          },
          tags: ["moral"]
        },
        {
          id: "play_saviors",
          text: "Play savior to the highest bidder.",
          goTo: "neutral_act1_bridge_to_act2",
          effects: {
            relationships: { "VIP Refugees": 4 },
            stats: { morality: -1 }
          },
          tags: ["social"]
        }
      ]
    },
    neutral_act1_bridge_to_act2: {
      id: "neutral_act1_bridge_to_act2",
      text: "Dawn stains the skyline bruised purple. Sirens migrate toward downtown while your building exhales shaken breaths. Act two looms.",
      tags: ["bridge", "act1"],
      timeDelta: 2,
      choices: [
        {
          id: "act2_protector",
          text: "Mobilize a haven convoy (Protector)",
          goTo: "good_act2_setpiece_haven_shield",
          req: { flags: ["route_protector", "proof_protector_rescue"] },
          blockedReason: "Protector path only",
          effects: {
            stats: { stamina: -1 },
            pushEvent: "Volunteers form up for the streets."
          },
          tags: ["leader"]
        },
        {
          id: "act2_warlord",
          text: "Press your advantage and tax the block (Warlord)",
          goTo: "ant_act2_setpiece_tithe_march",
          req: { flags: ["route_warlord", "proof_warlord_blackout"] },
          blockedReason: "Warlord path only",
          effects: {
            stats: { stress: -2 },
            pushEvent: "Collectors pound on doors at dawn."
          },
          tags: ["combat"]
        },
        {
          id: "act2_fixer",
          text: "Broker a citywide lifeline (Fixer)",
          goTo: "man_act2_setpiece_network",
          req: { flags: ["route_fixer", "proof_fixer_conduit"] },
          blockedReason: "Fixer path only",
          effects: {
            stats: { stress: 1 },
            pushEvent: "Radios chirp with new codes."
          },
          tags: ["social"]
        },
        {
          id: "act2_killer",
          text: "Stalk the refugee routes (Killer)",
          goTo: "killer_act2_setpiece_cull",
          req: { flags: ["route_killer", "proof_killer_mark"] },
          blockedReason: "Killer path only",
          effects: {
            stats: { stress: -3 },
            pushEvent: "Fear shadows every corridor."
          },
          tags: ["stealth"]
        },
        {
          id: "act2_sociopath",
          text: "Consolidate emotional debt (Sociopath)",
          goTo: "socio_act2_setpiece_bottleneck",
          req: { flags: ["route_sociopath", "proof_sociopath_mirror"] },
          blockedReason: "Sociopath path only",
          effects: {
            stats: { stress: -1 }
          },
          tags: ["moral"]
        }
      ]
    },
    good_act2_setpiece_haven_shield: {
      id: "good_act2_setpiece_haven_shield",
      text: "A garage becomes a refugee staging ground. Weather reports warn of an inbound horde shift within hours.",
      tags: ["setpiece", "act2", "leader"],
      choices: [
        {
          id: "fortify_barricade",
          text: "Fortify the barricade with welded panels",
          goTo: "good_act2_branch_shield",
          effects: {
            stats: { stamina: -2 },
            persona: { protector: 1 }
          },
          tags: ["combat"]
        },
        {
          id: "train_civilians",
          text: "Train civilians on evacuation drills",
          goTo: "good_act2_branch_shield",
          effects: {
            relationships: { Volunteers: 4 },
            stats: { stress: 2 },
            persona: { protector: 1 }
          },
          tags: ["social"]
        },
        {
          id: "escort_medics",
          text: "Escort medics through infected blocks",
          goTo: "good_act2_branch_supply",
          effects: {
            inventoryAdd: ["medkit"],
            stats: { morality: 2 },
            persona: { protector: 1 }
          },
          tags: ["survival"]
        },
        {
          id: "sweep_rooftops",
          text: "Sweep rooftops for flare points",
          goTo: "good_act2_branch_supply",
          effects: {
            flagsSet: ["proof_protector_beacon"],
            stats: { stress: 1 }
          },
          tags: ["stealth"]
        }
      ]
    },

    good_act2_branch_shield: {
      id: "good_act2_branch_shield",
      text: "Metal shrieks as you seal the garage. Families breathe easier once the drills begin running like clockwork.",
      tags: ["act2", "leader"],
      choices: [
        {
          id: "assign_roles",
          text: "Assign roles and rotate rest shifts.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            flagsSet: ["proof_protector_stand"],
            stats: { stress: -2 },
            persona: { protector: 1 }
          },
          tags: ["leader"]
        },
        {
          id: "share_supplies",
          text: "Share supplies with the convoy escorts.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            inventoryRemove: ["fuel_markers"],
            relationships: { Convoy: 3 }
          },
          tags: ["social"]
        }
      ]
    },

    good_act2_branch_supply: {
      id: "good_act2_branch_supply",
      text: "Medics set broken bones while you chart rooftop signal chains across the district.",
      tags: ["act2", "survival"],
      choices: [
        {
          id: "cache_medkits",
          text: "Cache medkits for the next surge.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            flagsSet: ["proof_protector_stand"],
            inventoryAdd: ["medkit"],
            stats: { stress: -1 }
          },
          tags: ["survival"]
        },
        {
          id: "coordinate_rooftops",
          text: "Coordinate rooftop flares with the stadium.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            relationships: { Stadium: 4 },
            stats: { morality: 2 }
          },
          tags: ["leader"]
        }
      ]
    },
    ant_act2_setpiece_tithe_march: {
      id: "ant_act2_setpiece_tithe_march",
      text: "Your enforcers fan across the block collecting tribute. Rumors say the Raiders eye your territory enviously.",
      tags: ["setpiece", "act2", "combat"],
      choices: [
        {
          id: "raid_neighbors",
          text: "Raid neighboring blocks before they raid you",
          goTo: "ant_act2_branch_dominate",
          effects: {
            stats: { morality: -3 },
            persona: { warlord: 1 },
            pushEvent: "Your banner flies over stolen roofs."
          },
          tags: ["combat"]
        },
        {
          id: "extort_market",
          text: "Extort the market for fuel",
          goTo: "ant_act2_branch_dominate",
          effects: {
            inventoryAdd: ["fuel_cells"],
            persona: { warlord: 1 }
          },
          tags: ["social"]
        },
        {
          id: "parley_raiders",
          text: "Parley with raider lieutenants",
          goTo: "ant_act2_branch_bargain",
          effects: {
            relationships: { Raiders: 4 },
            stats: { morality: -2 }
          },
          tags: ["social"]
        },
        {
          id: "public_execution",
          text: "Hold a public execution of dissenters",
          goTo: "ant_act2_branch_dominate",
          effects: {
            flagsSet: ["proof_warlord_stomp"],
            stats: { morality: -4 }
          },
          tags: ["moral"]
        }
      ]
    },

    ant_act2_branch_dominate: {
      id: "ant_act2_branch_dominate",
      text: "Your enforcers march in lockstep, boots echoing through surrendered streets.",
      tags: ["act2", "combat"],
      choices: [
        {
          id: "carve_tax",
          text: "Carve the new tax rates into the walls.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            flagsSet: ["proof_warlord_tithe"],
            stats: { stress: -2 }
          },
          tags: ["moral"]
        },
        {
          id: "arm_recruits",
          text: "Arm new recruits with raider weapons.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            inventoryAdd: ["raider_rifle"],
            persona: { warlord: 1 }
          },
          tags: ["combat"]
        }
      ]
    },

    ant_act2_branch_bargain: {
      id: "ant_act2_branch_bargain",
      text: "Raider lieutenants meet you in a burned-out deli. Trust is a rare commodity.",
      tags: ["act2", "social"],
      choices: [
        {
          id: "demand_alliance",
          text: "Demand alliance under your flag.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            flagsSet: ["proof_warlord_blackout"],
            relationships: { Raiders: 2 },
            stats: { morality: -1 }
          },
          tags: ["social"]
        },
        {
          id: "poison_offer",
          text: "Poison their offer and seize their supplies.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            inventoryAdd: ["raider_cache"],
            stats: { morality: -3 }
          },
          tags: ["stealth"]
        }
      ]
    },
    man_act2_setpiece_network: {
      id: "man_act2_setpiece_network",
      text: "The city map glows with routes and blockades. Three factions want exclusive access to your intel.",
      tags: ["setpiece", "act2", "social"],
      choices: [
        {
          id: "triage_comms",
          text: "Triage communications for the Stadium",
          goTo: "man_act2_branch_alliance",
          effects: {
            relationships: { Stadium: 5 },
            stats: { morality: 1 },
            persona: { fixer: 1 }
          },
          tags: ["social"]
        },
        {
          id: "auction_paths",
          text: "Auction safe paths hourly",
          goTo: "man_act2_branch_alliance",
          effects: {
            inventoryAdd: ["credit_scrip"],
            stats: { morality: -1 }
          },
          tags: ["moral"]
        },
        {
          id: "ghost_signal",
          text: "Ghost signal the Raiders to trap them",
          goTo: "man_act2_branch_betrayal",
          effects: {
            relationships: { Raiders: -4 },
            persona: { fixer: 1 }
          },
          tags: ["stealth"]
        },
        {
          id: "double_promises",
          text: "Make double promises to Convoy and Stadium",
          goTo: "man_act2_branch_betrayal",
          effects: {
            flagsSet: ["proof_fixer_web"],
            stats: { morality: -2 }
          },
          tags: ["moral"]
        }
      ]
    },

    man_act2_branch_alliance: {
      id: "man_act2_branch_alliance",
      text: "Your office becomes a nerve center. Every request flows through you first.",
      tags: ["act2", "social"],
      choices: [
        {
          id: "lock_contracts",
          text: "Lock exclusive contracts for the final push.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            flagsSet: ["proof_fixer_barter"],
            relationships: { Convoy: 3 }
          },
          tags: ["social"]
        },
        {
          id: "skim_supplies",
          text: "Skim supplies for your private stash.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            inventoryAdd: ["diverted_crate"],
            stats: { morality: -1 }
          },
          tags: ["moral"]
        }
      ]
    },

    man_act2_branch_betrayal: {
      id: "man_act2_branch_betrayal",
      text: "Lies stack like sandbags. Each promise you break buys leverage elsewhere.",
      tags: ["act2", "stealth"],
      choices: [
        {
          id: "seed_conflict",
          text: "Seed conflict between rivals to inflate demand.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            flagsSet: ["proof_fixer_web"],
            persona: { fixer: 1 },
            stats: { morality: -2 }
          },
          tags: ["moral"]
        },
        {
          id: "secure_exit",
          text: "Secure a personal exit route.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            inventoryAdd: ["secret_pass"],
            stats: { stress: -2 }
          },
          tags: ["stealth"]
        }
      ]
    },
    killer_act2_setpiece_cull: {
      id: "killer_act2_setpiece_cull",
      text: "Refugee routes snake through parking garages. You stalk them from above, charting who slows the line.",
      tags: ["setpiece", "act2", "stealth"],
      choices: [
        {
          id: "pick_targets",
          text: "Pick off the loudest liabilities",
          goTo: "killer_act2_branch_shadow",
          effects: {
            stats: { morality: -3 },
            persona: { killer: 1 }
          },
          tags: ["stealth"]
        },
        {
          id: "sabotage_route",
          text: "Sabotage alternate exits to funnel prey",
          goTo: "killer_act2_branch_shadow",
          effects: {
            flagsSet: ["proof_killer_fear"],
            stats: { stress: -2 }
          },
          tags: ["moral"]
        },
        {
          id: "toy_with_raiders",
          text: "Toy with raider scouts before ending them",
          goTo: "killer_act2_branch_harvest",
          effects: {
            relationships: { Raiders: -4 },
            inventoryAdd: ["raider_tokens"]
          },
          tags: ["combat"]
        },
        {
          id: "bleed_resources",
          text: "Bleed resources from the terrified",
          goTo: "killer_act2_branch_harvest",
          effects: {
            inventoryAdd: ["loot_pouch"],
            stats: { morality: -2 }
          },
          tags: ["social"]
        }
      ]
    },

    killer_act2_branch_shadow: {
      id: "killer_act2_branch_shadow",
      text: "Screams echo once then never again. Routes bend around the legend forming in your wake.",
      tags: ["act2", "stealth"],
      choices: [
        {
          id: "etch_symbol",
          text: "Etch your symbol near the exits.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            flagsSet: ["proof_killer_mark"],
            stats: { stress: -1 }
          },
          tags: ["moral"]
        },
        {
          id: "stash_victims",
          text: "Stash victims to use as bait later.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            inventoryAdd: ["hidden_cache"],
            persona: { killer: 1 }
          },
          tags: ["stealth"]
        }
      ]
    },

    killer_act2_branch_harvest: {
      id: "killer_act2_branch_harvest",
      text: "You dismantle raider patrols and terrified refugees alike. Supplies spill like entrails.",
      tags: ["act2", "combat"],
      choices: [
        {
          id: "refine_trophies",
          text: "Refine trophies into traps.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            flagsSet: ["proof_killer_cull"],
            inventoryAdd: ["wire_garrote"]
          },
          tags: ["survival"]
        },
        {
          id: "taunt_survivors",
          text: "Taunt survivors over stolen radios.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            stats: { morality: -2 },
            persona: { killer: 1 }
          },
          tags: ["moral"]
        }
      ]
    },
    socio_act2_setpiece_bottleneck: {
      id: "socio_act2_setpiece_bottleneck",
      text: "You control access to the last intact stairwell. Survivors barter trust, secrets, and promises at your door.",
      tags: ["setpiece", "act2", "social"],
      choices: [
        {
          id: "charge_confessions",
          text: "Charge confessions for passage",
          goTo: "socio_act2_branch_ledger",
          effects: {
            flagsSet: ["proof_sociopath_isolate"],
            persona: { sociopath: 1 }
          },
          tags: ["moral"]
        },
        {
          id: "auction_loyalty",
          text: "Auction loyalty to the highest fear",
          goTo: "socio_act2_branch_ledger",
          effects: {
            inventoryAdd: ["scrip_stack"],
            stats: { morality: -2 }
          },
          tags: ["social"]
        },
        {
          id: "manufacture_cult",
          text: "Manufacture a cult of calm",
          goTo: "socio_act2_branch_cult",
          effects: {
            relationships: { "Devotees": 6 },
            persona: { sociopath: 1 }
          },
          tags: ["leader"]
        },
        {
          id: "play_both",
          text: "Play rival factions off one another",
          goTo: "socio_act2_branch_cult",
          effects: {
            flagsSet: ["proof_sociopath_purge"],
            stats: { morality: -2 }
          },
          tags: ["moral"]
        }
      ]
    },

    socio_act2_branch_ledger: {
      id: "socio_act2_branch_ledger",
      text: "Your ledger bulges with confessions and pledges. Each entry is a leash.",
      tags: ["act2", "social"],
      choices: [
        {
          id: "tighten_grip",
          text: "Tighten the grip and deny rest.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            flagsSet: ["proof_sociopath_mirror"],
            stats: { stress: -1 }
          },
          tags: ["moral"]
        },
        {
          id: "sell_entries",
          text: "Sell entries to the Fixer network.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            inventoryAdd: ["blackmail_cache"],
            relationships: { Convoy: 1 }
          },
          tags: ["social"]
        }
      ]
    },

    socio_act2_branch_cult: {
      id: "socio_act2_branch_cult",
      text: "Devotees chant softly, swearing you kept them sane. It's half truth, half myth.",
      tags: ["act2", "leader"],
      choices: [
        {
          id: "implant_trigger",
          text: "Implant emotional triggers for later.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            flagsSet: ["proof_sociopath_purge"],
            persona: { sociopath: 1 }
          },
          tags: ["moral"]
        },
        {
          id: "gift_false_hope",
          text: "Gift false hope to keep them docile.",
          goTo: "neutral_act2_bridge_to_act3",
          effects: {
            stats: { morality: -2 },
            relationships: { Tenants: -3 }
          },
          tags: ["social"]
        }
      ]
    },
    neutral_act2_bridge_to_act3: {
      id: "neutral_act2_bridge_to_act3",
      text: "Night falls again. Radio chatter reports curfew walls forming near the stadium, the docks, the refinery. The city waits for your move.",
      tags: ["bridge", "act2"],
      timeDelta: 6,
      choices: [
        {
          id: "bridge_protector",
          text: "Lead evac buses through the stadium gauntlet (Protector)",
          goTo: "good_act3_setpiece_beacon",
          req: { flags: ["route_protector", "proof_protector_stand"] },
          blockedReason: "Protector proof needed",
          effects: {
            stats: { stress: 2 },
            pushEvent: "Buses rev while families board." 
          },
          tags: ["leader"]
        },
        {
          id: "bridge_warlord",
          text: "Claim the refinery as your fortress (Warlord)",
          goTo: "ant_act3_setpiece_refinery",
          req: { flags: ["route_warlord", "proof_warlord_tithe"] },
          blockedReason: "Warlord proof needed",
          effects: {
            stats: { morality: -1 },
            pushEvent: "Your army marches on the refinery." 
          },
          tags: ["combat"]
        },
        {
          id: "bridge_fixer",
          text: "Broker the decisive alliance (Fixer)",
          goTo: "man_act3_setpiece_conclave",
          req: { flags: ["route_fixer", "proof_fixer_barter"] },
          blockedReason: "Fixer proof needed",
          effects: {
            stats: { stress: 1 },
            pushEvent: "You schedule a clandestine conclave." 
          },
          tags: ["social"]
        },
        {
          id: "bridge_killer",
          text: "Bleed the curfew wall dry (Killer)",
          goTo: "killer_act3_setpiece_slaughter",
          req: { flags: ["route_killer", "proof_killer_cull"] },
          blockedReason: "Killer proof needed",
          effects: {
            stats: { stress: -4 },
            pushEvent: "You vanish into the curfew shadows." 
          },
          tags: ["stealth"]
        },
        {
          id: "bridge_sociopath",
          text: "Turn panic into a cult uprising (Sociopath)",
          goTo: "socio_act3_setpiece_ascend",
          req: { flags: ["route_sociopath", "proof_sociopath_purge"] },
          blockedReason: "Sociopath proof needed",
          effects: {
            stats: { stress: -1 },
            pushEvent: "Candles bloom across stairwells in your name." 
          },
          tags: ["moral"]
        }
      ]
    },
    good_act3_setpiece_beacon: {
      id: "good_act3_setpiece_beacon",
      text: "Stadium floodlights sputter. The last evac convoy waits for your call sign while the horde presses the outer wall.",
      tags: ["setpiece", "act3", "leader"],
      choices: [
        {
          id: "hold_gate",
          text: "Hold the gate until the buses clear",
          goTo: "good_act3_resolution_beacon",
          req: { flags: ["proof_protector_rescue", "proof_protector_stand"] },
          blockedReason: "Need Protector proofs",
          effects: {
            flagsSet: ["proof_protector_beacon"],
            stats: { stress: 4, stamina: -2 },
            persona: { protector: 1 },
            pushEvent: "You stand as the wall."
          },
          tags: ["leader"]
        },
        {
          id: "evac_children",
          text: "Evacuate the children first",
          goTo: "good_act3_resolution_beacon",
          req: { flags: ["proof_protector_rescue", "proof_protector_stand"] },
          effects: {
            flagsSet: ["proof_protector_beacon"],
            stats: { morality: 3 }
          },
          tags: ["moral"]
        },
        {
          id: "deploy_flares",
          text: "Deploy rooftop flares as guidance",
          goTo: "good_act3_resolution_beacon",
          req: { flags: ["proof_protector_rescue", "proof_protector_stand"] },
          effects: {
            flagsSet: ["proof_protector_beacon"],
            inventoryRemove: ["flare"],
            stats: { stress: 2 }
          },
          tags: ["stealth"]
        },
        {
          id: "sacrifice_time",
          text: "Sacrifice time to rescue stragglers",
          goTo: "good_act3_resolution_beacon",
          req: { flags: ["proof_protector_rescue", "proof_protector_stand"] },
          effects: {
            flagsSet: ["proof_protector_beacon"],
            stats: { stress: 3, stamina: -1 },
            relationships: { Volunteers: 3 }
          },
          tags: ["social"]
        }
      ]
    },

    good_act3_resolution_beacon: {
      id: "good_act3_resolution_beacon",
      text: "Engines fade into the dawn while ash still drifts across the seats you defended. Families look to you for the next move.",
      tags: ["resolution", "act3", "leader"],
      choices: [
        {
          id: "debrief_crews",
          text: "Debrief the volunteers and triage the shaken",
          goTo: "neutral_act3_hub_main",
          effects: {
            stats: { stress: -2, morality: 1 },
            relationships: { Volunteers: 3 },
            pushEvent: "Evac crews steady under your calm orders."
          },
          tags: ["leader"]
        },
        {
          id: "scout_new_route",
          text: "Scout the skyline for a safer corridor",
          goTo: "neutral_act3_hub_main",
          effects: {
            stats: { stamina: -1 },
            inventoryAdd: ["flare_bundle"],
            persona: { protector: 1 }
          },
          tags: ["stealth"]
        },
        {
          id: "console_refugees",
          text: "Console the families left waiting",
          goTo: "neutral_act3_hub_main",
          effects: {
            relationships: { Haven: 4 },
            stats: { morality: 2 }
          },
          tags: ["social"]
        }
      ]
    },
    ant_act3_setpiece_refinery: {
      id: "ant_act3_setpiece_refinery",
      text: "The refinery belches flame. Taking it means fuel, power, and absolute rule over the district.",
      tags: ["setpiece", "act3", "combat"],
      choices: [
        {
          id: "storm_gates",
          text: "Storm the gates with your enforcers",
          goTo: "ant_act3_resolution_iron_rule",
          req: { flags: ["proof_warlord_blackout", "proof_warlord_tithe"] },
          effects: {
            flagsSet: ["refinery_burned"],
            stats: { morality: -4 },
            persona: { warlord: 1 }
          },
          tags: ["combat"]
        },
        {
          id: "execute_foreman",
          text: "Execute the foreman on live radio",
          goTo: "ant_act3_resolution_iron_rule",
          req: { flags: ["proof_warlord_blackout", "proof_warlord_tithe"] },
          effects: {
            flagsSet: ["refinery_burned"],
            relationships: { Raiders: 3 }
          },
          tags: ["moral"]
        },
        {
          id: "enslave_workers",
          text: "Enslave the workers and brand them",
          goTo: "ant_act3_resolution_iron_rule",
          req: { flags: ["proof_warlord_blackout", "proof_warlord_tithe"] },
          effects: {
            flagsSet: ["refinery_burned"],
            relationships: { Tenants: -8 }
          },
          tags: ["social"]
        },
        {
          id: "broadcast_rule",
          text: "Broadcast your rule to the city",
          goTo: "ant_act3_resolution_iron_rule",
          req: { flags: ["proof_warlord_blackout", "proof_warlord_tithe"] },
          effects: {
            flagsSet: ["refinery_burned"],
            stats: { stress: -2 }
          },
          tags: ["leader"]
        }
      ]
    },

    ant_act3_resolution_iron_rule: {
      id: "ant_act3_resolution_iron_rule",
      text: "Fuel drums blaze with your sigil while frightened lieutenants await orders. The refinery is yours—but holding it demands constant pressure.",
      tags: ["resolution", "act3", "combat"],
      choices: [
        {
          id: "draft_decree",
          text: "Draft a decree and tax every barrel",
          goTo: "neutral_act3_hub_main",
          effects: {
            stats: { morality: -2, stress: -2 },
            relationships: { Raiders: 3 },
            pushEvent: "Your tithe doubles overnight."
          },
          tags: ["combat"]
        },
        {
          id: "reward_loyal",
          text: "Reward loyal bruisers with spoils",
          goTo: "neutral_act3_hub_main",
          effects: {
            inventoryRemove: ["rations"],
            relationships: { Enforcers: 4 },
            persona: { warlord: 1 }
          },
          tags: ["leader"]
        },
        {
          id: "tighten_grip",
          text: "Tighten curfews and threaten dissent",
          goTo: "neutral_act3_hub_main",
          effects: {
            stats: { morality: -3 },
            flagsSet: ["wall_breached"],
            pushEvent: "The refinery speakers scream your will."
          },
          tags: ["moral"]
        }
      ]
    },
    man_act3_setpiece_conclave: {
      id: "man_act3_setpiece_conclave",
      text: "In the shadow of the docks, representatives from Stadium, Convoy, and Raiders meet at your insistence. Every eye watches you.",
      tags: ["setpiece", "act3", "social"],
      choices: [
        {
          id: "balance_power",
          text: "Balance power with a fragile truce",
          goTo: "man_act3_resolution_web",
          req: { flags: ["proof_fixer_conduit", "proof_fixer_barter"] },
          effects: {
            flagsSet: ["proof_fixer_web"],
            relationships: { Stadium: 2, Convoy: 2 },
            stats: { morality: 1 }
          },
          tags: ["social"]
        },
        {
          id: "sell_everyone",
          text: "Sell everyone out for personal gain",
          goTo: "man_act3_resolution_web",
          req: { flags: ["proof_fixer_conduit", "proof_fixer_barter"] },
          effects: {
            flagsSet: ["proof_fixer_web"],
            inventoryAdd: ["vault_key"],
            stats: { morality: -3 }
          },
          tags: ["moral"]
        },
        {
          id: "install_proxy",
          text: "Install a proxy leader loyal to you",
          goTo: "man_act3_resolution_web",
          req: { flags: ["proof_fixer_conduit", "proof_fixer_barter"] },
          effects: {
            flagsSet: ["proof_fixer_web"],
            relationships: { "Proxy Council": 6 }
          },
          tags: ["leader"]
        },
        {
          id: "vanish",
          text: "Vanish with the conclave in your debt",
          goTo: "man_act3_resolution_web",
          req: { flags: ["proof_fixer_conduit", "proof_fixer_barter"] },
          effects: {
            flagsSet: ["proof_fixer_web"],
            inventoryAdd: ["secret_pass"],
            stats: { stress: -3 }
          },
          tags: ["stealth"]
        }
      ]
    },

    man_act3_resolution_web: {
      id: "man_act3_resolution_web",
      text: "Ink dries on three competing accords. Faction envoys whisper promises you can cash in or crush at will.",
      tags: ["resolution", "act3", "social"],
      choices: [
        {
          id: "secure_ledger",
          text: "Secure the ledgers and prep contingency trades",
          goTo: "neutral_act3_hub_main",
          effects: {
            inventoryAdd: ["binding_contracts"],
            relationships: { Stadium: 2, Convoy: 2 },
            persona: { fixer: 1 }
          },
          tags: ["social"]
        },
        {
          id: "seed_rumors",
          text: "Seed rumors that keep every faction dependent",
          goTo: "neutral_act3_hub_main",
          effects: {
            stats: { morality: -1 },
            flagsSet: ["proof_fixer_web"],
            pushEvent: "Your name threads every backchannel."
          },
          tags: ["moral"]
        },
        {
          id: "bank_favors",
          text: "Bank favors for the storm ahead",
          goTo: "neutral_act3_hub_main",
          effects: {
            relationships: { Raiders: 3, Convoy: 3 }
          },
          tags: ["leader"]
        }
      ]
    },
    killer_act3_setpiece_slaughter: {
      id: "killer_act3_setpiece_slaughter",
      text: "The curfew wall's heart beats with terrified commanders. Slip inside and the city's fear becomes legend.",
      tags: ["setpiece", "act3", "stealth"],
      choices: [
        {
          id: "silence_command",
          text: "Silence the command tent",
          goTo: "killer_act3_resolution_ghost",
          req: { flags: ["proof_killer_mark", "proof_killer_cull"] },
          effects: {
            flagsSet: ["proof_killer_fear"],
            stats: { stress: -5 }
          },
          tags: ["stealth"]
        },
        {
          id: "paint_message",
          text: "Paint a message in blood",
          goTo: "killer_act3_resolution_ghost",
          req: { flags: ["proof_killer_mark", "proof_killer_cull"] },
          effects: {
            flagsSet: ["proof_killer_fear"],
            stats: { morality: -4 }
          },
          tags: ["moral"]
        },
        {
          id: "booby_trap",
          text: "Booby-trap the wall for days to come",
          goTo: "killer_act3_resolution_ghost",
          req: { flags: ["proof_killer_mark", "proof_killer_cull"] },
          effects: {
            flagsSet: ["proof_killer_fear"],
            inventoryAdd: ["detonator"],
            stats: { stress: -2 }
          },
          tags: ["survival"]
        },
        {
          id: "whisper_radio",
          text: "Whisper to survivors on stolen radio",
          goTo: "killer_act3_resolution_ghost",
          req: { flags: ["proof_killer_mark", "proof_killer_cull"] },
          effects: {
            flagsSet: ["proof_killer_fear"],
            relationships: { Survivors: -6 }
          },
          tags: ["moral"]
        }
      ]
    },

    killer_act3_resolution_ghost: {
      id: "killer_act3_resolution_ghost",
      text: "Commanders vanish, walls crumble, and whispers about the ghost of curfew spread faster than infection. Patrols now prowl for you.",
      tags: ["resolution", "act3", "stealth"],
      choices: [
        {
          id: "strip_supplies",
          text: "Strip the barracks of ammo and vanish",
          goTo: "neutral_act3_hub_main",
          effects: {
            inventoryAdd: ["suppressed_rifle"],
            stats: { stress: -2 }
          },
          tags: ["stealth"]
        },
        {
          id: "mark_targets",
          text: "Mark new targets on a stolen map",
          goTo: "neutral_act3_hub_main",
          effects: {
            flagsSet: ["proof_killer_fear"],
            persona: { killer: 1 }
          },
          tags: ["moral"]
        },
        {
          id: "stalk_commander",
          text: "Stalk the surviving commander for intel",
          goTo: "neutral_act3_hub_main",
          effects: {
            relationships: { Curfew: -5 },
            stats: { morality: -2 }
          },
          tags: ["combat"]
        }
      ]
    },
    socio_act3_setpiece_ascend: {
      id: "socio_act3_setpiece_ascend",
      text: "Candles line the stairwells. Your devotees await guidance while rival leaders plot to expose you.",
      tags: ["setpiece", "act3", "moral"],
      choices: [
        {
          id: "stage_miracle",
          text: "Stage a miracle to cement faith",
          goTo: "socio_act3_resolution_icon",
          req: { flags: ["proof_sociopath_mirror", "proof_sociopath_purge"] },
          effects: {
            flagsSet: ["proof_sociopath_isolate"],
            relationships: { "Devotees": 8 }
          },
          tags: ["leader"]
        },
        {
          id: "purge_rivals",
          text: "Purge rivals in front of the crowd",
          goTo: "socio_act3_resolution_icon",
          req: { flags: ["proof_sociopath_mirror", "proof_sociopath_purge"] },
          effects: {
            flagsSet: ["proof_sociopath_isolate"],
            stats: { morality: -4 }
          },
          tags: ["moral"]
        },
        {
          id: "sell_salvation",
          text: "Sell salvation slots for future power",
          goTo: "socio_act3_resolution_icon",
          req: { flags: ["proof_sociopath_mirror", "proof_sociopath_purge"] },
          effects: {
            flagsSet: ["proof_sociopath_isolate"],
            inventoryAdd: ["devotion_ledgers"],
            stats: { stress: -2 }
          },
          tags: ["social"]
        },
        {
          id: "fake_confession",
          text: "Fake a confession to keep them hooked",
          goTo: "socio_act3_resolution_icon",
          req: { flags: ["proof_sociopath_mirror", "proof_sociopath_purge"] },
          effects: {
            flagsSet: ["proof_sociopath_isolate"],
            relationships: { Tenants: -5 }
          },
          tags: ["moral"]
        }
      ]
    },

    socio_act3_resolution_icon: {
      id: "socio_act3_resolution_icon",
      text: "The city kneels—not out of love, but because you taught them fear. Devotees chant while rivals scatter into the rain.",
      tags: ["resolution", "act3", "moral"],
      choices: [
        {
          id: "harvest_confessions",
          text: "Harvest confessions to weaponize later",
          goTo: "neutral_act3_hub_main",
          effects: {
            inventoryAdd: ["blackmail_cache"],
            persona: { sociopath: 1 }
          },
          tags: ["social"]
        },
        {
          id: "stage_procession",
          text: "Stage a procession that cements devotion",
          goTo: "neutral_act3_hub_main",
          effects: {
            flagsSet: ["proof_sociopath_isolate"],
            relationships: { Devotees: 5 }
          },
          tags: ["leader"]
        },
        {
          id: "erase_dissent",
          text: "Erase dissenting voices quietly",
          goTo: "neutral_act3_hub_main",
          effects: {
            stats: { morality: -3 },
            relationships: { Tenants: -4 }
          },
          tags: ["moral"]
        }
      ]
    },

    neutral_act3_hub_main: {
      id: "neutral_act3_hub_main",
      text: "Rooftop floodlights buzz as volunteers argue over dwindling crates. Helicopters circle while curfew sirens edge closer.",
      tags: ["hub", "act3"],
      timeDelta: 1,
      choices: [
        {
          id: "coordinate_push",
          text: "Coordinate the next citywide push",
          goTo: "neutral_act3_bridge_to_act4",
          effects: {
            stats: { stress: 1 },
            pushEvent: "Command net synchs to your voice."
          },
          tags: ["leader"]
        },
        {
          id: "sweep_tunnels",
          text: "Sweep the maintenance tunnels for supplies",
          goTo: "neutral_act3_side_cache",
          effects: {
            stats: { stamina: -1 },
            persona: { protector: 1 }
          },
          tags: ["survival"]
        },
        {
          id: "hold_vigil",
          text: "Hold a brief vigil for the fallen",
          goTo: "neutral_act3_side_brief",
          effects: {
            stats: { stress: -2 },
            relationships: { Survivors: 2 }
          },
          tags: ["social"]
        }
      ]
    },

    neutral_act3_side_cache: {
      id: "neutral_act3_side_cache",
      text: "The maintenance tunnels stink of oil and bleach. Hidden lockers wait beneath emergency tarps.",
      tags: ["side", "act3"],
      choices: [
        {
          id: "take_supplies",
          text: "Take the medical cache for your people",
          goTo: "neutral_act3_hub_main",
          effects: {
            inventoryAdd: ["medkit"],
            stats: { morality: 1 }
          },
          tags: ["survival"]
        },
        {
          id: "share_haul",
          text: "Share the haul with another faction",
          goTo: "neutral_act3_hub_main",
          effects: {
            relationships: { Convoy: 3, Stadium: 2 }
          },
          tags: ["social"]
        }
      ]
    },

    neutral_act3_side_brief: {
      id: "neutral_act3_side_brief",
      text: "A cracked classroom becomes a quiet chapel. Survivors trade whispered stories while the storm pauses outside.",
      tags: ["side", "act3"],
      choices: [
        {
          id: "promise_return",
          text: "Promise a return with better news",
          goTo: "neutral_act3_hub_main",
          effects: {
            stats: { morality: 1 },
            relationships: { Haven: 2 }
          },
          tags: ["leader"]
        },
        {
          id: "steal_focus",
          text: "Steal focus for your own agenda",
          goTo: "neutral_act3_hub_main",
          effects: {
            stats: { morality: -2 },
            persona: { sociopath: 1 }
          },
          tags: ["moral"]
        }
      ]
    },

    neutral_act3_bridge_to_act4: {
      id: "neutral_act3_bridge_to_act4",
      text: "Maps sprawl across a cracked table. Every route north, south, and skybound demands a champion before dawn.",
      tags: ["bridge", "act3"],
      timeDelta: 4,
      choices: [
        {
          id: "act4_protector",
          text: "Escort the evac skybridge (Protector)",
          goTo: "good_act4_setpiece_skybridge",
          req: { flags: ["route_protector", "proof_protector_rescue", "proof_protector_stand", "proof_protector_beacon"] },
          blockedReason: "Protector proofs required",
          effects: {
            stats: { stress: 1 },
            pushEvent: "You chart safe passages above the streets."
          },
          tags: ["leader"]
        },
        {
          id: "act4_warlord",
          text: "Crush the convoy choke point (Warlord)",
          goTo: "ant_act4_setpiece_crucible",
          req: { flags: ["route_warlord", "proof_warlord_blackout", "proof_warlord_tithe", "proof_warlord_stomp"] },
          blockedReason: "Warlord proofs required",
          effects: {
            stats: { morality: -2 },
            pushEvent: "Your columns deploy to seize the artery."
          },
          tags: ["combat"]
        },
        {
          id: "act4_fixer",
          text: "Bind the markets with a master contract (Fixer)",
          goTo: "man_act4_setpiece_exchange",
          req: { flags: ["route_fixer", "proof_fixer_conduit", "proof_fixer_barter", "proof_fixer_web"] },
          blockedReason: "Fixer proofs required",
          effects: {
            stats: { stress: 1 },
            pushEvent: "Every broker waits for your signal."
          },
          tags: ["social"]
        },
        {
          id: "act4_killer",
          text: "Bleed the curfew command core (Killer)",
          goTo: "killer_act4_setpiece_harvest",
          req: { flags: ["route_killer", "proof_killer_mark", "proof_killer_cull", "proof_killer_fear"] },
          blockedReason: "Killer proofs required",
          effects: {
            stats: { stress: -3 },
            pushEvent: "You slip toward the armored elevators."
          },
          tags: ["stealth"]
        },
        {
          id: "act4_socio",
          text: "Orchestrate the devotion broadcast (Sociopath)",
          goTo: "socio_act4_setpiece_liturgy",
          req: { flags: ["route_sociopath", "proof_sociopath_mirror", "proof_sociopath_purge", "proof_sociopath_isolate"] },
          blockedReason: "Sociopath proofs required",
          effects: {
            stats: { stress: -1 },
            pushEvent: "Loudspeakers await your sermon."
          },
          tags: ["moral"]
        }
      ]
    },

    good_act4_setpiece_skybridge: {
      id: "good_act4_setpiece_skybridge",
      text: "A fractured skybridge sways above burning avenues. Convoy buses idle below while infected claw toward the stairs.",
      tags: ["setpiece", "act4", "leader"],
      choices: [
        {
          id: "lead_shields",
          text: "Lead the shield wall across (−2 STA)",
          goTo: "good_act4_resolution_skybridge",
          cost: { stats: { stamina: 2 } },
          effects: {
            flagsSet: ["proof_protector_safeconvoy"],
            stats: { stress: 3, morality: 2 },
            persona: { protector: 1 },
            pushEvent: "You grind forward as a moving barricade."
          },
          tags: ["leader"]
        },
        {
          id: "rig_anchor",
          text: "Rig anchors and haul survivors with cables",
          goTo: "good_act4_resolution_skybridge",
          effects: {
            flagsSet: ["proof_protector_safeconvoy"],
            inventoryRemove: ["flare_bundle"],
            stats: { stress: 2 }
          },
          tags: ["survival"]
        },
        {
          id: "guide_children",
          text: "Guide children through a vent crawl",
          goTo: "good_act4_resolution_skybridge",
          effects: {
            flagsSet: ["proof_protector_safeconvoy"],
            relationships: { Haven: 4 },
            stats: { morality: 3 }
          },
          tags: ["social"]
        }
      ]
    },

    good_act4_resolution_skybridge: {
      id: "good_act4_resolution_skybridge",
      text: "The last bus clears the skybridge. Rain washes blood from your armor as scouts report fresh choke points ahead.",
      tags: ["resolution", "act4", "leader"],
      choices: [
        {
          id: "dispatch_guides",
          text: "Dispatch guides to the next shelters",
          goTo: "neutral_act4_hub_main",
          effects: {
            relationships: { Volunteers: 4 },
            stats: { stress: -2 }
          },
          tags: ["leader"]
        },
        {
          id: "share_route",
          text: "Share the safe corridor intel",
          goTo: "neutral_act4_hub_main",
          effects: {
            relationships: { Stadium: 3, Convoy: 3 }
          },
          tags: ["social"]
        }
      ]
    },

    ant_act4_setpiece_crucible: {
      id: "ant_act4_setpiece_crucible",
      text: "Freight containers form a fortress at the convoy choke point. Your lieutenants await orders to prove total dominion.",
      tags: ["setpiece", "act4", "combat"],
      choices: [
        {
          id: "seize_fuel",
          text: "Seize every fuel rig for tribute",
          goTo: "ant_act4_resolution_crucible",
          effects: {
            flagsSet: ["proof_warlord_supremacy"],
            stats: { morality: -3, stress: -2 },
            pushEvent: "Tribute lines stretch toward your banners."
          },
          tags: ["combat"]
        },
        {
          id: "public_execution",
          text: "Stage a public execution to deter revolt",
          goTo: "ant_act4_resolution_crucible",
          effects: {
            flagsSet: ["proof_warlord_supremacy"],
            relationships: { Civilians: -6 },
            persona: { warlord: 1 }
          },
          tags: ["moral"]
        },
        {
          id: "buy_loyalty",
          text: "Buy loyalty with plundered stockpiles",
          goTo: "ant_act4_resolution_crucible",
          effects: {
            flagsSet: ["proof_warlord_supremacy"],
            inventoryRemove: ["water"],
            relationships: { Enforcers: 5 }
          },
          tags: ["leader"]
        }
      ]
    },

    ant_act4_resolution_crucible: {
      id: "ant_act4_resolution_crucible",
      text: "The choke point bends to your will. Refugees tremble at each checkpoint branded with your crest.",
      tags: ["resolution", "act4", "combat"],
      choices: [
        {
          id: "fortify_crucible",
          text: "Fortify the barricades further",
          goTo: "neutral_act4_hub_main",
          effects: {
            stats: { stress: -1 },
            relationships: { Raiders: 3 }
          },
          tags: ["combat"]
        },
        {
          id: "send_message",
          text: "Broadcast your decree across districts",
          goTo: "neutral_act4_hub_main",
          effects: {
            flagsSet: ["wall_breached"],
            stats: { morality: -1 }
          },
          tags: ["leader"]
        }
      ]
    },

    man_act4_setpiece_exchange: {
      id: "man_act4_setpiece_exchange",
      text: "Signal jammers fall silent as you step onto the exchange floor. Every faction ledger uploads through your console.",
      tags: ["setpiece", "act4", "social"],
      choices: [
        {
          id: "sync_markets",
          text: "Sync markets under a unified tariff",
          goTo: "man_act4_resolution_exchange",
          effects: {
            flagsSet: ["proof_fixer_omnimarket"],
            relationships: { Stadium: 3, Convoy: 3 }
          },
          tags: ["social"]
        },
        {
          id: "short_sell",
          text: "Short-sell Raider caches for leverage",
          goTo: "man_act4_resolution_exchange",
          effects: {
            flagsSet: ["proof_fixer_omnimarket"],
            stats: { morality: -2 },
            inventoryAdd: ["credit_chits"]
          },
          tags: ["moral"]
        },
        {
          id: "gift_relief",
          text: "Gift relief shipments to earn trust",
          goTo: "man_act4_resolution_exchange",
          effects: {
            flagsSet: ["proof_fixer_omnimarket"],
            relationships: { FreeCrews: 4 }
          },
          tags: ["leader"]
        }
      ]
    },

    man_act4_resolution_exchange: {
      id: "man_act4_resolution_exchange",
      text: "Deal trackers ping in rhythm with your heartbeat. Every crate and ration now routes through channels you control.",
      tags: ["resolution", "act4", "social"],
      choices: [
        {
          id: "spin_narrative",
          text: "Spin a narrative that paints you indispensable",
          goTo: "neutral_act4_hub_main",
          effects: {
            pushEvent: "Your voice saturates pirate radio."
          },
          tags: ["social"]
        },
        {
          id: "audit_favors",
          text: "Audit who owes you before the final act",
          goTo: "neutral_act4_hub_main",
          effects: {
            inventoryAdd: ["debt_ledger"],
            stats: { stress: -1 }
          },
          tags: ["leader"]
        }
      ]
    },

    killer_act4_setpiece_harvest: {
      id: "killer_act4_setpiece_harvest",
      text: "Armored elevators thrum toward the curfew command spire. Guards rotate in tight formations; one opening could break them.",
      tags: ["setpiece", "act4", "stealth"],
      choices: [
        {
          id: "sabotage_lift",
          text: "Sabotage the lift cables",
          goTo: "killer_act4_resolution_harvest",
          effects: {
            flagsSet: ["proof_killer_apex"],
            stats: { stress: -4 }
          },
          tags: ["stealth"]
        },
        {
          id: "poison_reserves",
          text: "Poison the command reserves",
          goTo: "killer_act4_resolution_harvest",
          effects: {
            flagsSet: ["proof_killer_apex"],
            relationships: { Curfew: -8 },
            stats: { morality: -3 }
          },
          tags: ["moral"]
        },
        {
          id: "assassinate_chief",
          text: "Assassinate the chief in the blackout",
          goTo: "killer_act4_resolution_harvest",
          effects: {
            flagsSet: ["proof_killer_apex"],
            inventoryAdd: ["command_codes"]
          },
          tags: ["combat"]
        }
      ]
    },

    killer_act4_resolution_harvest: {
      id: "killer_act4_resolution_harvest",
      text: "The command spire falls into panic. Your shadow now stalks their every transmission.",
      tags: ["resolution", "act4", "stealth"],
      choices: [
        {
          id: "bleed_patrols",
          text: "Bleed remaining patrols for intel",
          goTo: "neutral_act4_hub_main",
          effects: {
            relationships: { Curfew: -4 }
          },
          tags: ["stealth"]
        },
        {
          id: "stash_caches",
          text: "Stash captured codes for later",
          goTo: "neutral_act4_hub_main",
          effects: {
            inventoryAdd: ["encrypted_orders"]
          },
          tags: ["survival"]
        }
      ]
    },

    socio_act4_setpiece_liturgy: {
      id: "socio_act4_setpiece_liturgy",
      text: "Broadcast towers glow orange. Followers gather with candles while skeptics jam the stairwells.",
      tags: ["setpiece", "act4", "moral"],
      choices: [
        {
          id: "promise_safety",
          text: "Promise safety for eternal obedience",
          goTo: "socio_act4_resolution_liturgy",
          effects: {
            flagsSet: ["proof_sociopath_dominion"],
            relationships: { Devotees: 6 }
          },
          tags: ["leader"]
        },
        {
          id: "weaponize_fear",
          text: "Weaponize fear with staged miracles",
          goTo: "socio_act4_resolution_liturgy",
          effects: {
            flagsSet: ["proof_sociopath_dominion"],
            stats: { morality: -3 },
            pushEvent: "Your sermon echoes through empty towers."
          },
          tags: ["moral"]
        },
        {
          id: "trade_faith",
          text: "Trade faith for rare supplies",
          goTo: "socio_act4_resolution_liturgy",
          effects: {
            flagsSet: ["proof_sociopath_dominion"],
            inventoryAdd: ["ration_tithes"],
            persona: { sociopath: 1 }
          },
          tags: ["social"]
        }
      ]
    },

    socio_act4_resolution_liturgy: {
      id: "socio_act4_resolution_liturgy",
      text: "Your broadcast blankets the blocks. Devotees wait breathless for your next command.",
      tags: ["resolution", "act4", "moral"],
      choices: [
        {
          id: "catalog_devotion",
          text: "Catalog who worships and who resists",
          goTo: "neutral_act4_hub_main",
          effects: {
            inventoryAdd: ["devotion_ledgers"]
          },
          tags: ["leader"]
        },
        {
          id: "seed_sleeper",
          text: "Seed sleeper whispers for later control",
          goTo: "neutral_act4_hub_main",
          effects: {
            persona: { sociopath: 1 },
            stats: { morality: -1 }
          },
          tags: ["moral"]
        }
      ]
    },

    neutral_act4_hub_main: {
      id: "neutral_act4_hub_main",
      text: "Rain lashes the stadium mezzanine you now use as command. Allies compare scars while the horizon flashes.",
      tags: ["hub", "act4"],
      timeDelta: 2,
      choices: [
        {
          id: "share_intel",
          text: "Share intel and plan the final gambit",
          goTo: "neutral_act4_bridge_to_act5",
          effects: {
            stats: { stress: 1 }
          },
          tags: ["leader"]
        },
        {
          id: "tend_wounds",
          text: "Tend wounds and stabilize morale",
          goTo: "neutral_act4_side_signal",
          effects: {
            stats: { stress: -3 },
            relationships: { Volunteers: 2 }
          },
          tags: ["social"]
        },
        {
          id: "interrogate_spy",
          text: "Interrogate a captured spy",
          goTo: "neutral_act4_side_triad",
          effects: {
            persona: { fixer: 1 }
          },
          tags: ["moral"]
        }
      ]
    },

    neutral_act4_side_signal: {
      id: "neutral_act4_side_signal",
      text: "The broadcast booth rattles in the wind. Backup batteries hum while operators await instructions.",
      tags: ["side", "act4"],
      choices: [
        {
          id: "boost_allies",
          text: "Boost allied frequencies",
          goTo: "neutral_act4_hub_main",
          effects: {
            relationships: { Stadium: 2, Convoy: 2 }
          },
          tags: ["social"]
        },
        {
          id: "jam_raiders",
          text: "Jam the Raider networks",
          goTo: "neutral_act4_hub_main",
          effects: {
            relationships: { Raiders: -4 },
            stats: { stress: -1 }
          },
          tags: ["combat"]
        }
      ]
    },

    neutral_act4_side_triad: {
      id: "neutral_act4_side_triad",
      text: "A storage bay becomes an impromptu tribunal. The spy offers secrets in exchange for safe passage.",
      tags: ["side", "act4"],
      choices: [
        {
          id: "accept_bargain",
          text: "Accept the bargain and mark the intel",
          goTo: "neutral_act4_hub_main",
          effects: {
            inventoryAdd: ["curfew_roster"],
            stats: { morality: -1 }
          },
          tags: ["moral"]
        },
        {
          id: "refuse_deal",
          text: "Refuse and detain them",
          goTo: "neutral_act4_hub_main",
          effects: {
            stats: { morality: 1 }
          },
          tags: ["leader"]
        }
      ]
    },

    neutral_act4_bridge_to_act5: {
      id: "neutral_act4_bridge_to_act5",
      text: "Thunder rolls as scouts report the final convergences. One more push decides the city's story.",
      tags: ["bridge", "act4"],
      timeDelta: 4,
      choices: [
        {
          id: "act5_protector",
          text: "Guard the evac column to the interstate (Protector)",
          goTo: "good_act5_setpiece_final_stand",
          req: { flags: ["route_protector", "proof_protector_rescue", "proof_protector_stand", "proof_protector_beacon", "proof_protector_safeconvoy"] },
          blockedReason: "Protector capstone required",
          effects: {
            stats: { stress: 2 },
            pushEvent: "Families rally for the final dash."
          },
          tags: ["leader"]
        },
        {
          id: "act5_warlord",
          text: "Impose the final blood tithe (Warlord)",
          goTo: "ant_act5_setpiece_bloodtax",
          req: { flags: ["route_warlord", "proof_warlord_blackout", "proof_warlord_tithe", "proof_warlord_stomp", "proof_warlord_supremacy"] },
          blockedReason: "Warlord capstone required",
          effects: {
            stats: { morality: -3 }
          },
          tags: ["combat"]
        },
        {
          id: "act5_fixer",
          text: "Broker the defining accord (Fixer)",
          goTo: "man_act5_setpiece_worlddeal",
          req: { flags: ["route_fixer", "proof_fixer_conduit", "proof_fixer_barter", "proof_fixer_web", "proof_fixer_omnimarket"] },
          blockedReason: "Fixer capstone required",
          effects: {
            stats: { stress: 1 }
          },
          tags: ["social"]
        },
        {
          id: "act5_killer",
          text: "Erase the source of command (Killer)",
          goTo: "killer_act5_setpiece_lastblade",
          req: { flags: ["route_killer", "proof_killer_mark", "proof_killer_cull", "proof_killer_fear", "proof_killer_apex"] },
          blockedReason: "Killer capstone required",
          effects: {
            stats: { stress: -4 }
          },
          tags: ["stealth"]
        },
        {
          id: "act5_socio",
          text: "Seal devotion with a final lie (Sociopath)",
          goTo: "socio_act5_setpiece_lastlie",
          req: { flags: ["route_sociopath", "proof_sociopath_mirror", "proof_sociopath_purge", "proof_sociopath_isolate", "proof_sociopath_dominion"] },
          blockedReason: "Sociopath capstone required",
          effects: {
            stats: { stress: -1 }
          },
          tags: ["moral"]
        }
      ]
    },

    good_act5_setpiece_final_stand: {
      id: "good_act5_setpiece_final_stand",
      text: "The interstate ramps are jammed with fleeing buses. A final wave of infected pours from the tunnels.",
      tags: ["setpiece", "act5", "leader"],
      choices: [
        {
          id: "hold_wall",
          text: "Hold the barricade until everyone clears",
          goTo: "good_act5_ending_safekeeper",
          effects: {
            stats: { stress: 4, stamina: -3 },
            relationships: { Volunteers: 5 }
          },
          tags: ["leader"]
        },
        {
          id: "rescue_last",
          text: "Rescue the last stranded bus",
          goTo: "good_act5_ending_safekeeper",
          effects: {
            stats: { morality: 4 }
          },
          tags: ["social"]
        },
        {
          id: "guide_sky",
          text: "Guide evac craft through the smoke",
          goTo: "good_act5_ending_safekeeper",
          effects: {
            stats: { stress: 3 },
            inventoryRemove: ["flare"],
            pushEvent: "Pilots follow your flares to freedom."
          },
          tags: ["survival"]
        }
      ]
    },

    good_act5_ending_safekeeper: {
      id: "good_act5_ending_safekeeper",
      text: "Columns of survivors cross the interstate alive because you refused to abandon them. They whisper your name as guardian of the road ahead.",
      isEnding: true,
      endingType: "good"
    },

    ant_act5_setpiece_bloodtax: {
      id: "ant_act5_setpiece_bloodtax",
      text: "Your banners hang over the refinery plaza. The last strong factions await the tribute you demand.",
      tags: ["setpiece", "act5", "combat"],
      choices: [
        {
          id: "demand_kneel",
          text: "Demand every leader kneel",
          goTo: "ant_act5_ending_overlord",
          effects: {
            stats: { morality: -4 },
            relationships: { Raiders: 5 }
          },
          tags: ["leader"]
        },
        {
          id: "burn_resisters",
          text: "Burn resisters as warning",
          goTo: "ant_act5_ending_overlord",
          effects: {
            stats: { morality: -5 },
            pushEvent: "Ash drifts over the plaza."
          },
          tags: ["moral"]
        },
        {
          id: "chain_supply",
          text: "Chain supply routes to your tithe",
          goTo: "ant_act5_ending_overlord",
          effects: {
            stats: { stress: -2 },
            relationships: { Enforcers: 4 }
          },
          tags: ["combat"]
        }
      ]
    },

    ant_act5_ending_overlord: {
      id: "ant_act5_ending_overlord",
      text: "Districts bow to your decree. Fuel, medicine, and hope flow only through your iron tithe.",
      isEnding: true,
      endingType: "ruthless"
    },

    man_act5_setpiece_worlddeal: {
      id: "man_act5_setpiece_worlddeal",
      text: "The last negotiators gather in a floodlit garage. Every faction waits to hear the deal that will define tomorrow.",
      tags: ["setpiece", "act5", "social"],
      choices: [
        {
          id: "forge_union",
          text: "Forge a true union",
          goTo: "man_act5_ending_conductor",
          effects: {
            relationships: { Stadium: 4, Convoy: 4 },
            stats: { stress: -2 }
          },
          tags: ["social"]
        },
        {
          id: "double_cross",
          text: "Double-cross two sides for profit",
          goTo: "man_act5_ending_conductor",
          effects: {
            stats: { morality: -3 },
            inventoryAdd: ["vault_key"],
            pushEvent: "Fortunes shift in your favor."
          },
          tags: ["moral"]
        },
        {
          id: "crown_proxy",
          text: "Crown a proxy leader loyal to you",
          goTo: "man_act5_ending_conductor",
          effects: {
            relationships: { Proxy: 5 }
          },
          tags: ["leader"]
        }
      ]
    },

    man_act5_ending_conductor: {
      id: "man_act5_ending_conductor",
      text: "Every supply line routes through agreements you scripted. Alliances survive only because you keep them balanced.",
      isEnding: true,
      endingType: "manipulator"
    },

    killer_act5_setpiece_lastblade: {
      id: "killer_act5_setpiece_lastblade",
      text: "Deep beneath the stadium, the infection's handlers prepare their final gambit. Silence them and the city earns one more dawn.",
      tags: ["setpiece", "act5", "stealth"],
      choices: [
        {
          id: "silence_handlers",
          text: "Silence the handlers without a trace",
          goTo: "killer_act5_ending_night",
          effects: {
            stats: { stress: -5 }
          },
          tags: ["stealth"]
        },
        {
          id: "detonate_lab",
          text: "Detonate the lab and vanish",
          goTo: "killer_act5_ending_night",
          effects: {
            stats: { morality: -3 },
            inventoryRemove: ["detonator"],
            pushEvent: "A muted blast rattles the arena."
          },
          tags: ["combat"]
        },
        {
          id: "steal_samples",
          text: "Steal samples as leverage",
          goTo: "killer_act5_ending_night",
          effects: {
            inventoryAdd: ["viral_samples"],
            stats: { stress: -2 }
          },
          tags: ["moral"]
        }
      ]
    },

    killer_act5_ending_night: {
      id: "killer_act5_ending_night",
      text: "Legends say the night itself fights for you. Command falls, whispers linger, and the city survives on fear of your blade.",
      isEnding: true,
      endingType: "killer"
    },

    socio_act5_setpiece_lastlie: {
      id: "socio_act5_setpiece_lastlie",
      text: "Every remaining survivor tunes into your broadcast. One last lie will define who kneels tomorrow.",
      tags: ["setpiece", "act5", "moral"],
      choices: [
        {
          id: "promise_sanctuary",
          text: "Promise sanctuary if they surrender",
          goTo: "socio_act5_ending_void",
          effects: {
            relationships: { Devotees: 6 }
          },
          tags: ["leader"]
        },
        {
          id: "threaten_exile",
          text: "Threaten exile for disloyalty",
          goTo: "socio_act5_ending_void",
          effects: {
            stats: { morality: -4 }
          },
          tags: ["moral"]
        },
        {
          id: "sell_hearts",
          text: "Sell hearts to the highest bidder",
          goTo: "socio_act5_ending_void",
          effects: {
            inventoryAdd: ["devotion_ledgers"],
            persona: { sociopath: 1 }
          },
          tags: ["social"]
        }
      ]
    },

    socio_act5_ending_void: {
      id: "socio_act5_ending_void",
      text: "They trust no god but you. Hope, fear, and every confession now orbit your whispered promises.",
      isEnding: true,
      endingType: "sociopath"
    }
  });
  delete window.STORY_DATABASE.intro;

  function wordCount(text = "") {
    if (Array.isArray(text)) {
      return text.reduce((sum, segment) => sum + wordCount(segment), 0);
    }
    return String(text)
      .trim()
      .split(/\s+/)
      .filter(Boolean).length;
  }

  function validateStory(db) {
    const errors = [];
    const warnings = [];
    const allIds = Object.keys(db);
    const seenFlagsSet = new Map();
    const seenFlagsUnset = new Map();

    for (const id of allIds) {
      if (!/^[a-z0-9_]+$/.test(id)) {
        errors.push(`Invalid ID format: ${id}`);
      }
      const scene = db[id];
      if (!scene) continue;
      if (scene.isEnding && scene.choices && scene.choices.length) {
        errors.push(`Ending scene ${id} must not contain choices.`);
      }
      const validChoices = (scene.choices || []).filter((choice) => choice && (getChoiceTarget(choice) || choice.effects));
      if (scene.tags && scene.tags.includes("hub") && !scene.isEnding) {
        const exits = new Set();
        for (const choice of validChoices) {
          const target = getChoiceTarget(choice);
          if (target) exits.add(target);
        }
        if (exits.size < 2) {
          warnings.push(`Hub ${id} exposes fewer than two exits.`);
        }
      }
      if (wordCount(scene.text) > 140) {
        warnings.push(`Scene ${id} exceeds 140 words.`);
      }
      for (const choice of validChoices) {
        const target = getChoiceTarget(choice);
        if (!target && !choice.effects) {
          errors.push(`Choice in ${id} lacks goTo/effects.`);
        }
        if (target) {
          if (!db[target]) {
            errors.push(`Choice from ${id} targets missing scene ${target}.`);
          }
          if (target === id && !scene.allowSelfLoop) {
            errors.push(`Choice in ${id} loops to itself without allowSelfLoop.`);
          }
        }
        const flagsSet = (choice.effects && choice.effects.flagsSet) || [];
        const flagsUnset = (choice.effects && choice.effects.flagsUnset) || [];
        for (const flag of flagsSet) {
          seenFlagsSet.set(flag, (seenFlagsSet.get(flag) || 0) + 1);
        }
        for (const flag of flagsUnset) {
          seenFlagsUnset.set(flag, (seenFlagsUnset.get(flag) || 0) + 1);
        }
        if (flagsSet.length > 1) {
          for (const [group, members] of Object.entries(MUTEX)) {
            const count = flagsSet.filter((flag) => members.includes(flag)).length;
            if (count > 1) {
              errors.push(`Choice ${choice.id || choice.text} in ${id} sets multiple mutex flags (${group}).`);
            }
          }
        }
      }
    }

    const queue = [DEFAULT_STATE.sceneId];
    const reachable = new Set(queue);
    while (queue.length) {
      const current = queue.shift();
      const scene = db[current];
      if (!scene) continue;
      for (const choice of scene.choices || []) {
        const target = getChoiceTarget(choice);
        if (target && !reachable.has(target)) {
          reachable.add(target);
          queue.push(target);
        }
      }
    }

    for (const id of allIds) {
      if (!reachable.has(id) && !(db[id] && db[id].isEnding)) {
        warnings.push(`Scene ${id} is unreachable from intro.`);
      }
    }

    for (const [flag, setCount] of seenFlagsSet.entries()) {
      if (!seenFlagsUnset.has(flag)) continue;
    }

    return { errors, warnings };
  }

  function randomWalkReport(db, startId, iterations = 1000, maxSteps = 200) {
    const visited = new Set();
    const endingPaths = {};
    let endingsReached = 0;
    const rng = mulberry32(424242);

    for (let run = 0; run < iterations; run += 1) {
      const state = deepClone(DEFAULT_STATE);
      state.sceneId = startId;
      const path = [];

      for (let step = 0; step < maxSteps; step += 1) {
        visited.add(state.sceneId);
        const scene = db[state.sceneId];
        if (!scene) break;
        if (scene.isEnding) {
          endingsReached += 1;
          if (!endingPaths[scene.id] || path.length < endingPaths[scene.id].length) {
            endingPaths[scene.id] = path.slice();
          }
          break;
        }
        const candidates = (scene.choices || []).filter((choice) => choice && (getChoiceTarget(choice) || choice.effects));
        const available = candidates.filter((choice) => meetsRequirement(state, choice.req));
        if (available.length === 0) {
          break;
        }
        const pick = available[Math.floor(rng() * available.length)];
        path.push(`${scene.id}::${pick.id || pick.text}`);
        applyCost(state, pick.cost);
        applyEffects(state, pick.effects);
        resolveSchedule(state);
        ensureStats(state);
        state.sceneId = getChoiceTarget(pick) ?? state.sceneId;
      }
    }

    const coverage = Math.round((visited.size / Object.keys(db).length) * 100);
    return {
      coverage,
      visitedCount: visited.size,
      totalScenes: Object.keys(db).length,
      endingsReached,
      endingPaths
    };
  }

  function runQAReports() {
    const db = window.STORY_DATABASE;
    if (!db) return;
    const validation = validateStory(db);
    const walks = randomWalkReport(db, DEFAULT_STATE.sceneId);
    console.group("Consequence QA");
    if (validation.errors.length) {
      console.error("Validator errors:", validation.errors);
    } else {
      console.log("Validator: no blocking errors.");
    }
    if (validation.warnings.length) {
      console.warn("Validator warnings:", validation.warnings);
    }
    console.log("Random walk coverage:", `${walks.coverage}%`);
    console.log("Unique scenes visited:", walks.visitedCount, "/", walks.totalScenes);
    console.log("Endings reached during walks:", walks.endingsReached);
    console.table(
      Object.entries(walks.endingPaths).map(([ending, path]) => ({ ending, steps: path.length }))
    );
    console.groupEnd();
  }

  runQAReports();

})();

document.addEventListener("DOMContentLoaded", () => {
  if (typeof window.ConsequenceGame === "function" && window.STORY_DATABASE) {
    window.game = new window.ConsequenceGame();
  }
});
