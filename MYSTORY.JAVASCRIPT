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
    "proof_protector_holdline",
    "proof_protector_convoy",
    "proof_protector_beacons",
    "proof_warlord_blackout",
    "proof_warlord_tithe",
    "proof_warlord_supremacy",
    "proof_fixer_network",
    "proof_fixer_markets",
    "proof_fixer_ledgers",
    "proof_killer_hunt",
    "proof_killer_fear",
    "proof_killer_cull",
    "proof_sociopath_mask",
    "proof_sociopath_trial",
    "proof_sociopath_requiem",
    "protector_final_bastion",
    "warlord_final_tribute",
    "fixer_final_network",
    "killer_final_reign",
    "sociopath_final_stage",
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

  const BACKGROUND_LABELS = {
    medic: "Field Medic",
    fighter: "Union Brawler",
    hacker: "Network Tech",
    thief: "Street Thief"
  };

  const MAX_STAT = 100;
  const MIN_STAT = -100;

  const DEFAULT_STATE = {
    sceneId: "neutral_act0_intro_apartment",
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
      let nameEvent = null;
      let backgroundEvent = null;
      if (choice.assignName) {
        const current = this.state.playerName || "Survivor";
        let name = "";
        if (typeof window.prompt === "function") {
          name = window.prompt("What should Alex call you?", current) || "";
        }
        name = name.trim().slice(0, 40);
        if (!name) name = current;
        nextState.playerName = name;
        nameEvent = `You tell Alex to call you ${name}.`;
      }
      if (choice.setBackground) {
        nextState.background = choice.setBackground;
        const label = BACKGROUND_LABELS[choice.setBackground] || choice.setBackground;
        backgroundEvent = `You lean into your ${label.toLowerCase()} instincts.`;
      }

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

      if (nameEvent) {
        this.pushEvent(nameEvent, "world_event");
      }
      if (backgroundEvent) {
        this.pushEvent(backgroundEvent, "world_event");
      }

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

      const storyText = Array.isArray(scene.text)
        ? scene.text.map((line) => this.interpolateText(line))
        : this.interpolateText(scene.text || "");

      this.displayStory(storyText, scene);
      this.displayChoices(scene);
      this.renderStats();
      this.renderInventory();
      this.renderCharacter();
      this.renderPersona();
      this.renderRelationships();
      this.renderDebug();
      this.updateTime();
      this.autosaveJournal(scene);
    }

    interpolateText(text) {
      if (typeof text !== "string") return text;
      const name = this.state.playerName || "Survivor";
      const backgroundKey = this.state.background;
      const backgroundLabel = BACKGROUND_LABELS[backgroundKey] || (backgroundKey ? backgroundKey : "survivor");
      return text
        .replace(/\{\{name\}\}/gi, name)
        .replace(/\{\{background\}\}/gi, backgroundLabel);
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
        const choiceLabel = this.interpolateText(choice.text || "");
        button.innerHTML = `<span class="choice-text">${choiceLabel}</span>`;

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

    renderCharacter() {
      if (this.dom.charName) {
        this.dom.charName.textContent = this.state.playerName || "—";
      }
      if (this.dom.charBackground) {
        const key = this.state.background;
        this.dom.charBackground.textContent = key ? BACKGROUND_LABELS[key] || key : "—";
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

  const ROUTE_PROOFS = {
    protector: ["proof_protector_holdline", "proof_protector_convoy", "proof_protector_beacons"],
    warlord: ["proof_warlord_blackout", "proof_warlord_tithe", "proof_warlord_supremacy"],
    fixer: ["proof_fixer_network", "proof_fixer_markets", "proof_fixer_ledgers"],
    killer: ["proof_killer_hunt", "proof_killer_fear", "proof_killer_cull"],
    sociopath: ["proof_sociopath_mask", "proof_sociopath_trial", "proof_sociopath_requiem"]
  };

  const ROUTE_BLUEPRINTS = {
    protector: {
      label: "Protector",
      routeFlag: "route_protector",
      personaKey: "protector",
      relationship: "Volunteers",
      relationshipDelta: 6,
      moralityTilt: [3, 1, -3],
      stressTilt: [2, 3, 4],
      tags: ["leader", "moral"],
      verbs: ["Reinforce", "Shield", "Escort", "Anchor", "Guide"],
      narrative: {
        actions: [
          "brace splintered doorframes with scavenged rebar",
          "stage exhausted volunteers into rotating shifts",
          "steady trembling shoulders with crisp directives",
          "chain rooftop beacons into a steady glow",
          "shepherd families through smoke-choked hallways"
        ],
        environments: [
          "rain needles against blown-out windows",
          "generator fumes crawl along the tile",
          "distant sirens pulse like a heart gone feral",
          "ash drifts down the stairwell like gray snow",
          "floodlights flicker against slick concrete"
        ],
        pressures: [
          "every scream from below sharpens the panic",
          "the barricade bows beneath relentless fists",
          "civilians beg for space beside the barricade",
          "the power grid threatens another blackout",
          "Alex's voice shakes as they take roll call"
        ],
        reflections: [
          "You promised Alex this floor would hold.",
          "Compassion is the only weapon left sharpened.",
          "If you falter, the block's children vanish.",
          "Protecting them means rewriting what mercy costs.",
          "Alex watches to see if hope still matters."
        ]
      },
      acts: [
        {
          act: 1,
          slug: "floor_watch",
          title: "Steady the floor watch",
          entryPrompt: "Guide Alex as they steady the seventh-floor watch (Protector)",
          summary: "Alex begs you to keep the seventh-floor barricade intact while frightened families crowd the hall.",
          focus: ["seventh-floor barricade", "makeshift infirmary", "families huddled behind doors"],
          stakes: [
            "If the door splinters, every child on this level screams into the dark.",
            "Volunteers will fracture unless someone sets the rhythm."],
          loot: "ration_brick",
          proofFlag: ROUTE_PROOFS.protector[0],
          returnHub: "neutral_act1_hub_main",
          exitForward: "neutral_act1_bridge_rooftop",
          personaShift: 2
        },
        {
          act: 2,
          slug: "convoy_shield",
          title: "Guard the convoy corridor",
          entryPrompt: "Send Alex to reinforce the stadium gate (Protector)",
          summary: "Curfew sirens blare as the stadium gate buckles under survivors desperate for convoy seats.",
          focus: ["stadium perimeter", "convoy lane", "curfew checkpoints"],
          stakes: [
            "Families will be trampled unless you choreograph the extraction.",
            "The convoy captain only trusts promises kept in blood and fuel."],
          loot: "flare",
          proofFlag: ROUTE_PROOFS.protector[1],
          returnHub: "neutral_act2_hub_main",
          exitForward: "neutral_act2_bridge_curfew",
          personaShift: 2
        },
        {
          act: 3,
          slug: "beacon_chain",
          title: "Ignite the beacon chain",
          entryPrompt: "Have Alex ignite the rooftop beacon chain (Protector)",
          summary: "Dawn smoke chokes the skyline as you race to keep rooftop beacons aligned for evac guidance.",
          focus: ["signal tower", "wind-scoured catwalk", "ash-clogged antenna"],
          stakes: [
            "Without your lights the evac columns crash blind into raider nests.",
            "The district holds its breath for your signal."],
          loot: "antibiotics",
          proofFlag: ROUTE_PROOFS.protector[2],
          returnHub: "neutral_act3_hub_main",
          exitForward: "neutral_act3_bridge_signal",
          personaShift: 2
        },
        {
          act: 4,
          slug: "siege_command",
          title: "Command the siege volunteers",
          entryPrompt: "Direct Alex to coordinate siege drills (Protector)",
          summary: "Raiders mass outside the stadium while exhausted civilians wait for your final orders.",
          focus: ["sandbag wall", "triage amphitheater", "command dais"],
          stakes: [
            "If morale snaps now, every prior rescue unravels.",
            "Alex needs proof that compassion can still roar."],
          loot: "signal_flares",
          finalFlag: "protector_final_bastion",
          returnHub: "neutral_act4_hub_main",
          exitForward: "neutral_act4_bridge_finale",
          personaShift: 3
        },
        {
          act: 5,
          slug: "legacy_watch",
          title: "Hold the last beacon",
          entryPrompt: "Lead Alex through the final evacuation (Protector)",
          summary: "The Long Siren keens one last time as you decide which convoys leave and who stays to defend.",
          focus: ["evac roof", "signal console", "crowded muster line"],
          stakes: [
            "Every promise from earlier acts comes due under the floodlights.",
            "Alex stands beside you, waiting to see what safety costs now."],
          loot: "relief_cache",
          returnHub: "neutral_act5_hub_main",
          exitForward: "neutral_act5_hub_main",
          personaShift: 3,
          endings: [
            {
              slug: "long_watch",
              endingType: "good",
              text: "You and Alex choreograph beacon codes until dawn. Convoys thread the ruins guided by steady pulses that carry your name in whispered gratitude."
            },
            {
              slug: "ashen_vigil",
              endingType: "good",
              text: "You stay behind with a skeleton crew, holding the barricade while Alex leads the last evac column. Hope survives because you decided the Long Siren would not fade."
            }
          ]
        }
      ]
    },
    warlord: {
      label: "Warlord",
      routeFlag: "route_warlord",
      personaKey: "warlord",
      relationship: "Raiders",
      relationshipDelta: 6,
      moralityTilt: [-3, -1, -4],
      stressTilt: [3, 2, 5],
      tags: ["combat", "leader"],
      verbs: ["Dominate", "Extort", "Threaten", "Coerce", "Exploit"],
      narrative: {
        actions: [
          "reroute ration lines at knifepoint",
          "pit rival crews against each other",
          "broadcast ultimatums over the emergency band",
          "burn warning sigils into barricade walls",
          "force tribute collectors to march through the rain"
        ],
        environments: [
          "sirens warp into a slow hunting howl",
          "floodlights smear blood across concrete",
          "smoke drifts from looted storefronts",
          "the convoy horns tremble at your checkpoints",
          "drones buzz above, relaying your threats"
        ],
        pressures: [
          "refugees cower as you count their offerings",
          "rival captains test your patience with smug silence",
          "the militia scrambles to answer your blockade",
          "Alex flinches at the cruelty you orchestrate",
          "power shifts with every scream behind closed doors"
        ],
        reflections: [
          "Fear is the only currency people still respect.",
          "Alex learns what rule by dread truly costs.",
          "Mercy would dissolve the grip you've earned.",
          "You tell yourself tyranny is the fastest path to order.",
          "When the siren stops, your shadow must linger."
        ]
      },
      acts: [
        {
          act: 1,
          slug: "blackout_tithe",
          title: "Seize the blackout",
          entryPrompt: "Force Alex to lock down the blackout stairwell (Warlord)",
          summary: "Power dies across the block, letting you tax anyone who needs your generators to survive.",
          focus: ["darkened stairwell", "raider checkpoint", "ration queue"],
          stakes: [
            "If you hesitate, rival crews seize the tribute.",
            "Alex has to learn fear is leverage."],
          loot: "ammo_cache",
          proofFlag: ROUTE_PROOFS.warlord[0],
          returnHub: "neutral_act1_hub_main",
          exitForward: "neutral_act1_bridge_rooftop",
          personaShift: 3
        },
        {
          act: 2,
          slug: "tithe_march",
          title: "March the tithe",
          entryPrompt: "Send Alex to collect the convoy tithe (Warlord)",
          summary: "Convoy haulers roll into your territory, demanding passage—if you can pry enough tribute first.",
          focus: ["tribute square", "fuel depot", "armored blockade"],
          stakes: [
            "Squeeze too hard and the convoy guns open fire.",
            "Let them through free and your crews riot."],
          loot: "ration_brick",
          proofFlag: ROUTE_PROOFS.warlord[1],
          returnHub: "neutral_act2_hub_main",
          exitForward: "neutral_act2_bridge_curfew",
          personaShift: 3
        },
        {
          act: 3,
          slug: "iron_rule",
          title: "Crush rival captains",
          entryPrompt: "Make Alex broker your iron rule (Warlord)",
          summary: "Three raider captains contest your rule; you must break them or bind them in iron contracts.",
          focus: ["captured overpass", "execution stage", "loot hangar"],
          stakes: [
            "Lose focus and a coup flares behind your back.",
            "Alex fears who you become with this much power."],
          loot: "skull_ring",
          proofFlag: ROUTE_PROOFS.warlord[2],
          returnHub: "neutral_act3_hub_main",
          exitForward: "neutral_act3_bridge_signal",
          personaShift: 3
        },
        {
          act: 4,
          slug: "supremacy_edict",
          title: "Publish the supremacy edict",
          entryPrompt: "Order Alex to broadcast your supremacy edict (Warlord)",
          summary: "You hold the stadium hostage, threatening to vent the stands unless every faction kneels.",
          focus: ["hijacked broadcast booth", "spotlighted gallows", "looted command truck"],
          stakes: [
            "Back down now and every lieutenant deserts.",
            "Alex wonders if there's a way back from this."],
          loot: "shock_baton",
          finalFlag: "warlord_final_tribute",
          returnHub: "neutral_act4_hub_main",
          exitForward: "neutral_act4_bridge_finale",
          personaShift: 4
        },
        {
          act: 5,
          slug: "iron_reign",
          title: "Seal the city under iron",
          entryPrompt: "Command Alex to seal the city under iron (Warlord)",
          summary: "The Long Siren drops into a growl as you decide which districts burn and which are tithed.",
          focus: ["floodlit courtyard", "tribute vault", "armored dais"],
          stakes: [
            "Every scream tonight will echo your name.",
            "Alex must either kneel or run."],
          loot: "gold_tithe",
          returnHub: "neutral_act5_hub_main",
          exitForward: "neutral_act5_hub_main",
          personaShift: 4,
          endings: [
            {
              slug: "iron_reign",
              endingType: "ruthless",
              text: "You crown yourself atop the stadium floodlights while Alex enforces your tribute lines. The Long Siren re-tunes to your heartbeat—relentless and merciless."
            },
            {
              slug: "shattered_throne",
              endingType: "bad",
              text: "Alex slips a blade between your plans, spiriting refugees away as your lieutenants splinter. You sit alone amid the burning tithe vault, ruler of ash."
            }
          ]
        }
      ]
    },
    fixer: {
      label: "Fixer",
      routeFlag: "route_fixer",
      personaKey: "fixer",
      relationship: "Convoy",
      relationshipDelta: 6,
      moralityTilt: [1, 0, -2],
      stressTilt: [2, 2, 3],
      tags: ["social", "stealth"],
      verbs: ["Broker", "Leverage", "Promise", "Trade", "Spin"],
      narrative: {
        actions: [
          "slide IOUs across rain-slick tables",
          "splice hijacked frequencies into the radio mesh",
          "trade secrets between desperate faction envoys",
          "catalog debts in a ledger only you can read",
          "bury favors inside coded convoy manifests"
        ],
        environments: [
          "neon flickers through cracked office glass",
          "convoy engines idle like patient beasts",
          "raider spotlights sweep for signs of betrayal",
          "hacked drones relay whispers along the skyline",
          "Alex juggles handheld radios until their voice goes hoarse"
        ],
        pressures: [
          "every deal threatens to collapse the others",
          "one wrong promise and a faction turns hostile",
          "rumors of your double-cross ripple through the docks",
          "Alex wonders if any truth remains in your voice",
          "the convoy dispatcher times your answers with suspicion"
        ],
        reflections: [
          "Influence is fragile glass; you balance it in both hands.",
          "Alex studies your lies, unsure whether to admire or fear you.",
          "Leverage tastes sweeter than honesty tonight.",
          "The Long Siren becomes a metronome for your bargains.",
          "Someone has to weave the factions together, even if it frays your soul."
        ]
      },
      acts: [
        {
          act: 1,
          slug: "hallway_contract",
          title: "Weave hallway contracts",
          entryPrompt: "Coach Alex through hallway deals (Fixer)",
          summary: "Panicked tenants offer anything for safety. You can bundle their promises into leverage for later acts.",
          focus: ["rainy hallway", "makeshift desk", "ledger pile"],
          stakes: [
            "Overcommit and you'll owe more than you can pay.",
            "Let Alex see the angles so they learn how influence flows."],
          loot: "signed_marker",
          proofFlag: ROUTE_PROOFS.fixer[0],
          returnHub: "neutral_act1_hub_main",
          exitForward: "neutral_act1_bridge_rooftop",
          personaShift: 2
        },
        {
          act: 2,
          slug: "conduit_exchange",
          title: "Control the conduit",
          entryPrompt: "Send Alex to mediate the conduit exchange (Fixer)",
          summary: "A fuel conduit between the convoy and stadium is failing; whoever controls the repair controls the lifeline.",
          focus: ["refuel bay", "storm-drenched catwalk", "control console"],
          stakes: [
            "Promise protection and the convoy owes you forever.",
            "Sell access to raiders and the stadium cuts you off."],
          loot: "fuel_chip",
          proofFlag: ROUTE_PROOFS.fixer[1],
          returnHub: "neutral_act2_hub_main",
          exitForward: "neutral_act2_bridge_curfew",
          personaShift: 2
        },
        {
          act: 3,
          slug: "ledger_web",
          title: "Complete the ledger web",
          entryPrompt: "Have Alex finalize the ledger web (Fixer)",
          summary: "Your secret ledger now binds three factions. One misstep, and you lose every favor you've stacked.",
          focus: ["abandoned bank", "encrypted terminal", "sealed vault"],
          stakes: [
            "Reveal too much and they'll burn you.",
            "Hide everything and the alliances collapse."],
          loot: "encrypted_drive",
          proofFlag: ROUTE_PROOFS.fixer[2],
          returnHub: "neutral_act3_hub_main",
          exitForward: "neutral_act3_bridge_signal",
          personaShift: 2
        },
        {
          act: 4,
          slug: "triple_cross",
          title: "Pull the triple-cross",
          entryPrompt: "Coach Alex through a triple-cross (Fixer)",
          summary: "Raiders, convoy, and stadium all expect you to betray the others tonight. You'll try to let them all believe they won.",
          focus: ["signal tower", "sealed lounge", "encrypted earpiece"],
          stakes: [
            "Slip once and the city feeds you to the mobs.",
            "Alex keeps track of who you really saved."],
          loot: "bribe_chits",
          finalFlag: "fixer_final_network",
          returnHub: "neutral_act4_hub_main",
          exitForward: "neutral_act4_bridge_finale",
          personaShift: 3
        },
        {
          act: 5,
          slug: "whisper_market",
          title: "Broker the whisper market",
          entryPrompt: "Lead Alex into the whisper market (Fixer)",
          summary: "The Long Siren falls quiet enough that every whisper counts. Finalize which debts get erased and which consume the city.",
          focus: ["shadow bazaar", "promise vault", "crowded radio loft"],
          stakes: [
            "Pay the wrong debt and a faction burns you in effigy.",
            "Alex weighs whether trust survives your bargains."],
          loot: "sealed_contract",
          returnHub: "neutral_act5_hub_main",
          exitForward: "neutral_act5_hub_main",
          personaShift: 3,
          endings: [
            {
              slug: "whispered_ledger",
              endingType: "manipulator",
              text: "You balance every favor owed and ensure each faction depends on Alex to reach you. The siren becomes the pulse of your quiet economy."
            },
            {
              slug: "burned_accounts",
              endingType: "bad",
              text: "The ledger catches fire when two factions compare notes. Alex drags you out as the whisper market riots, debts collapsing into smoke." 
            }
          ]
        }
      ]
    },
    killer: {
      label: "Killer",
      routeFlag: "route_killer",
      personaKey: "killer",
      relationship: "Raiders",
      relationshipDelta: 5,
      moralityTilt: [-4, -2, -5],
      stressTilt: [1, 2, 3],
      tags: ["combat", "stealth"],
      verbs: ["Hunt", "Cull", "Stalk", "Ambush", "Silence"],
      narrative: {
        actions: [
          "map corpse trails to predict the next swarm",
          "plant piano wire along choke points",
          "collect trophies to warn rival predators",
          "stalk rooftops with scavenged rifle scopes",
          "wipe blades clean in the rain to reset your focus"
        ],
        environments: [
          "emergency strobes paint everything scarlet",
          "the stairwell smells of copper and bleach",
          "thunder rolls over gutted high-rises",
          "Alex's breath fogs in the cold night air",
          "shadows bend like teeth along the alley walls"
        ],
        pressures: [
          "the infected learn your patterns and evolve",
          "raider rivals set traps just for you",
          "Alex fears the grin you wear after every kill",
          "each body you drop buys another hour for the floor",
          "silence becomes addictive and dangerous"
        ],
        reflections: [
          "Killing keeps the survivors breathing tonight.",
          "Alex studies the monster you wield like a knife.",
          "Mercy rots faster than corpses in this rain.",
          "Predators fall to the hungrier predator.",
          "You hope someone remembers why you started hunting."
        ]
      },
      acts: [
        {
          act: 1,
          slug: "stairwell_hunt",
          title: "Hunt the stairwell pack",
          entryPrompt: "Let Alex bait the stairwell pack (Killer)",
          summary: "A feral pack claws up the stairwell; you can lure them into a kill zone or risk them hitting the barricade.",
          focus: ["narrow landing", "tripped wires", "blood-slick steps"],
          stakes: [
            "Miss the timing and families die.",
            "Teach Alex how to bait monsters without breaking."],
          loot: "bone_charm",
          proofFlag: ROUTE_PROOFS.killer[0],
          returnHub: "neutral_act1_hub_main",
          exitForward: "neutral_act1_bridge_rooftop",
          personaShift: 3
        },
        {
          act: 2,
          slug: "ghost_migration",
          title: "Track the ghost migration",
          entryPrompt: "Send Alex to map the ghost migration (Killer)",
          summary: "The infected migrate along the riverfront. Culling them quietly keeps the convoy route open.",
          focus: ["fogged riverwalk", "collapsed pier", "dripping tunnel"],
          stakes: [
            "Spill too much blood and raiders hunt you next.",
            "Alex must move like a shadow or die."],
          loot: "silent_boots",
          proofFlag: ROUTE_PROOFS.killer[1],
          returnHub: "neutral_act2_hub_main",
          exitForward: "neutral_act2_bridge_curfew",
          personaShift: 3
        },
        {
          act: 3,
          slug: "fear_tithe",
          title: "Collect the fear tithe",
          entryPrompt: "Have Alex collect the fear tithe (Killer)",
          summary: "Rival killers demand tribute. You'll either erase them or force them into your pattern.",
          focus: ["graffiti-tagged alley", "rooftop perch", "abandoned theatre"],
          stakes: [
            "Spare them and they undermine your terror.",
            "Kill them and Alex wonders if you're still human."],
          loot: "nightblade",
          proofFlag: ROUTE_PROOFS.killer[2],
          returnHub: "neutral_act3_hub_main",
          exitForward: "neutral_act3_bridge_signal",
          personaShift: 3
        },
        {
          act: 4,
          slug: "apex_creed",
          title: "Write the apex creed",
          entryPrompt: "Teach Alex the apex creed (Killer)",
          summary: "Your legend terrifies every corridor. Decide who lives under your protection and who feeds the dark.",
          focus: ["sealed killroom", "trophy rack", "observation deck"],
          stakes: [
            "Choose wrong and fear turns against you.",
            "Alex needs to know whether you hunt for them or for yourself."],
          loot: "scarred_mask",
          finalFlag: "killer_final_reign",
          returnHub: "neutral_act4_hub_main",
          exitForward: "neutral_act4_bridge_finale",
          personaShift: 4
        },
        {
          act: 5,
          slug: "midnight_creed",
          title: "Seal the midnight creed",
          entryPrompt: "Bring Alex into the midnight creed (Killer)",
          summary: "Only one hunter walks away tonight. Decide whether you become the myth or bury it.",
          focus: ["floodlit rooftop", "silent stairwell", "pool of rain"],
          stakes: [
            "Let the killings stop and the infected return.",
            "Continue and Alex might never look at you again."],
          loot: "blood_token",
          returnHub: "neutral_act5_hub_main",
          exitForward: "neutral_act5_hub_main",
          personaShift: 4,
          endings: [
            {
              slug: "midnight_creed",
              endingType: "ruthless",
              text: "You leave trophies on every threshold. Alex covers for you, believing the killings keep the district alive, even as their eyes darken."
            },
            {
              slug: "quiet_grave",
              endingType: "bad",
              text: "Alex shatters your knives and walks into the dawn. You bury the creed beside the river, wondering if silence can forgive you."
            }
          ]
        }
      ]
    },
    sociopath: {
      label: "Sociopath",
      routeFlag: "route_sociopath",
      personaKey: "sociopath",
      relationship: "Free Crews",
      relationshipDelta: 6,
      moralityTilt: [-1, -3, -2],
      stressTilt: [1, 2, 2],
      tags: ["social", "leader"],
      verbs: ["Stage", "Manipulate", "Confide", "Gaslight", "Perform"],
      narrative: {
        actions: [
          "script tears for the audience you gather",
          "mirror back fears until people cling to you",
          "plant rumors that knot factions around your voice",
          "turn Alex into a prop in your carefully staged empathy",
          "invent confessions that bind strangers together"
        ],
        environments: [
          "emergency lanterns warm the improvised stage",
          "rain taps a beat on the stadium tarp",
          "hushed spectators hang on every dramatic pause",
          "the Long Siren becomes a low violin beneath your words",
          "Alex watches from the wings, unsure who you really are"
        ],
        pressures: [
          "lie too well and even you forget the truth",
          "show weakness and the crowd moves on",
          "each emotional reveal must pay off later",
          "Alex wonders whether any comfort you give is real",
          "factions crave the script only you can deliver"
        ],
        reflections: [
          "Influence is theatre and the apocalypse your stage.",
          "Alex doesn't know which version of you to trust.",
          "Empathy can be weaponized into obedience.",
          "You choreograph grief so no one sees your own.",
          "If the siren stops, will anyone remember who you are?"
        ]
      },
      acts: [
        {
          act: 1,
          slug: "mirror_act",
          title: "Run the mirror act",
          entryPrompt: "Pull Alex into your mirror act (Sociopath)",
          summary: "You can redirect panic by reflecting people's worst fears back at them until they follow your lead.",
          focus: ["makeshift stage", "crowded hallway", "broken mirror"],
          stakes: [
            "Overplay it and they turn on you.",
            "Alex may learn to fake feelings better than you do."],
          loot: "mirror_shard",
          proofFlag: ROUTE_PROOFS.sociopath[0],
          returnHub: "neutral_act1_hub_main",
          exitForward: "neutral_act1_bridge_rooftop",
          personaShift: 2
        },
        {
          act: 2,
          slug: "mask_market",
          title: "Curate the mask market",
          entryPrompt: "Send Alex to curate the mask market (Sociopath)",
          summary: "A night market trades favors for curated emotions. You can set the tone everyone copies tomorrow.",
          focus: ["candlelit tunnel", "mask stall", "whisper dome"],
          stakes: [
            "Lose control and rumor-mongers hijack the scene.",
            "Alex wonders whether authenticity survived the outbreak."],
          loot: "silk_mask",
          proofFlag: ROUTE_PROOFS.sociopath[1],
          returnHub: "neutral_act2_hub_main",
          exitForward: "neutral_act2_bridge_curfew",
          personaShift: 2
        },
        {
          act: 3,
          slug: "trial_stage",
          title: "Host the whisper trials",
          entryPrompt: "Have Alex host the whisper trials (Sociopath)",
          summary: "You orchestrate confessions in a gutted theatre, deciding who earns forgiveness and who becomes an example.",
          focus: ["spotlit chair", "hanging mic", "row of candles"],
          stakes: [
            "If forgiveness feels fake, the mob drags you out.",
            "If punishment feels real, Alex recoils."],
          loot: "confession_tape",
          proofFlag: ROUTE_PROOFS.sociopath[2],
          returnHub: "neutral_act3_hub_main",
          exitForward: "neutral_act3_bridge_signal",
          personaShift: 2
        },
        {
          act: 4,
          slug: "empathy_purge",
          title: "Conduct the empathy purge",
          entryPrompt: "Rehearse Alex for the empathy purge (Sociopath)",
          summary: "You promise to purge despair with choreographed catharsis; secretly, you decide whose emotions get erased.",
          focus: ["ritual circle", "projected montage", "standing ovation"],
          stakes: [
            "Pick the wrong target and your audience revolts.",
            "Alex must perform the hurt you hand them."],
          loot: "stage_lights",
          finalFlag: "sociopath_final_stage",
          returnHub: "neutral_act4_hub_main",
          exitForward: "neutral_act4_bridge_finale",
          personaShift: 3
        },
        {
          act: 5,
          slug: "cold_requiem",
          title: "Debut the cold requiem",
          entryPrompt: "Stage the cold requiem with Alex (Sociopath)",
          summary: "Your final performance will decide whether the city believes in hope, fear, or nothing at all.",
          focus: ["collapsed theatre", "torchlit balcony", "silent crowd"],
          stakes: [
            "If the show flops, chaos returns instantly.",
            "If it succeeds, Alex may never know you meant any of it."],
          loot: "marble_mask",
          returnHub: "neutral_act5_hub_main",
          exitForward: "neutral_act5_hub_main",
          personaShift: 3,
          endings: [
            {
              slug: "cold_reckoning",
              endingType: "secret",
              text: "The city moves to the rhythm you script. Alex smiles through staged tears, unsure whether the salvation you sell is real."
            },
            {
              slug: "empty_stage",
              endingType: "bad",
              text: "Your performance collapses into awkward silence. Alex drops the mask and walks into the rain while the crowd turns feral." 
            }
          ]
        }
      ]
    }
  };
  const HUB_BLUEPRINTS = [
    {
      act: 1,
      id: "neutral_act1_hub_main",
      text: "Rain needles shattered windows as Alex paces the mezzanine, asking whether you will save these families, exploit them, or weaponize their fear.",
      timeDelta: 1,
      tags: ["hub", "act1"],
      bridgeEntryText: "Climb with Alex to the roof and survey the district",
      bridge: {
        id: "neutral_act1_bridge_rooftop",
        text: "From the rooftop, sirens blur into the rainfall. Stadium flares, convoy headlights, and raider bonfires paint competing futures across the skyline.",
        tags: ["bridge", "act1"],
        choices: [
          {
            id: "bridge1_signal_stadium",
            text: "Signal the stadium wardens for aid",
            goTo: "neutral_act2_hub_main",
            effects: { time: 1, flagsSet: ["plan_stadium"], relationships: { Stadium: 4 } },
            tags: ["leader", "social"]
          },
          {
            id: "bridge1_call_convoy",
            text: "Patch into the convoy dispatcher",
            goTo: "neutral_act2_hub_main",
            effects: { time: 1, flagsSet: ["plan_convoy"], relationships: { Convoy: 4 } },
            tags: ["social", "stealth"]
          },
          {
            id: "bridge1_hold",
            text: "Grant Alex one more hour on the floor",
            goTo: "neutral_act1_hub_main",
            effects: { stats: { stress: 3 }, relationships: { Alex: 2 } },
            tags: ["leader", "survival"]
          }
        ]
      },
      sideScenes: [
        {
          id: "neutral_act1_side_generator",
          entryText: "Check the flickering generator with Alex",
          text: "The maintenance closet hums with ozone as the generator coughs smoke. Alex begs for a fix before the lights die.",
          tags: ["side", "act1"],
          choices: [
            {
              id: "act1_fix_generator",
              text: "Rip open the casing and reroute power (−1 STA)",
              goTo: "neutral_act1_hub_main",
              cost: { stats: { stamina: 1 }, time: 1 },
              effects: { stats: { stress: -2 }, inventoryAdd: ["spare_parts"], relationships: { Volunteers: 4 } },
              tags: ["survival", "leader"]
            },
            {
              id: "act1_divert_power",
              text: "Divert power to your apartment only",
              goTo: "neutral_act1_hub_main",
              effects: { stats: { morality: -2, stress: -1 }, relationships: { Volunteers: -5 }, flagsSet: ["wall_breached"] },
              tags: ["stealth", "moral"]
            }
          ]
        },
        {
          id: "neutral_act1_side_rations",
          entryText: "Inspect the ration queue",
          text: "Families barter heirlooms for stale crackers in the hallway. Alex looks to you for fairness.",
          tags: ["side", "act1"],
          choices: [
            {
              id: "act1_share_rations",
              text: "Donate your hidden snacks",
              goTo: "neutral_act1_hub_main",
              effects: { stats: { morality: 2, stress: -1 }, relationships: { Volunteers: 5 }, flagsSet: ["shared_rations"] },
              tags: ["moral", "leader"]
            },
            {
              id: "act1_sell_rations",
              text: "Sell portions for favors",
              goTo: "neutral_act1_hub_main",
              effects: { stats: { morality: -3, stress: -2 }, relationships: { FreeCrews: 3, Volunteers: -4 } },
              tags: ["social", "stealth"]
            }
          ]
        }
      ]
    },
    {
      act: 2,
      id: "neutral_act2_hub_main",
      text: "Curfew drones sweep the interstate. Alex clutches maps and asks whether you will reinforce the stadium, exploit convoys, or sell safety to raiders.",
      timeDelta: 1,
      tags: ["hub", "act2"],
      bridgeEntryText: "Slip through the curfew lines toward dawn",
      bridge: {
        id: "neutral_act2_bridge_curfew",
        text: "Checkpoint sirens and floodlights dance along the overpass. Every faction watches to see who you protect next.",
        tags: ["bridge", "act2"],
        choices: [
          {
            id: "bridge2_stage_stadium",
            text: "Escort medics toward the stadium",
            goTo: "neutral_act3_hub_main",
            effects: { time: 1, relationships: { Stadium: 5 }, stats: { stress: 2 } },
            tags: ["leader", "survival"]
          },
          {
            id: "bridge2_feed_convoy",
            text: "Load Alex onto a convoy run",
            goTo: "neutral_act3_hub_main",
            effects: { time: 1, relationships: { Convoy: 5 }, flagsSet: ["rescued_convoy"] },
            tags: ["social", "leader"]
          },
          {
            id: "bridge2_stall",
            text: "Delay and gather more intel",
            goTo: "neutral_act2_hub_main",
            effects: { stats: { stress: 1 }, inventoryAdd: ["cipher_codes"] },
            tags: ["stealth", "survival"]
          }
        ]
      },
      sideScenes: [
        {
          id: "neutral_act2_side_checkpoint",
          entryText: "Sneak beneath the checkpoint",
          text: "Floodlights search the rain as militia shout over the curfew loudspeakers.",
          tags: ["side", "act2"],
          choices: [
            {
              id: "act2_bribe_guard",
              text: "Bribe the guard with convoy gossip",
              goTo: "neutral_act2_hub_main",
              effects: { stats: { stress: -2 }, relationships: { Convoy: 3, Raiders: -2 } },
              tags: ["social", "stealth"]
            },
            {
              id: "act2_cut_power",
              text: "Cut the checkpoint power",
              goTo: "neutral_act2_hub_main",
              effects: { stats: { morality: -2 }, flagsSet: ["convoy_betrayed"], relationships: { Raiders: 4 } },
              tags: ["combat", "stealth"]
            }
          ]
        },
        {
          id: "neutral_act2_side_infirmary",
          entryText: "Check the shattered infirmary",
          text: "Stretchers line the loading bay. Alex wants to know if you heal or prioritize leverage.",
          tags: ["side", "act2"],
          choices: [
            {
              id: "act2_treat_wounded",
              text: "Treat the worst wounds",
              goTo: "neutral_act2_hub_main",
              effects: { stats: { morality: 3, stress: 2 }, relationships: { Volunteers: 4 }, inventoryRemove: ["antibiotics"] },
              tags: ["moral", "leader"]
            },
            {
              id: "act2_skimp_supplies",
              text: "Pocket the best meds",
              goTo: "neutral_act2_hub_main",
              effects: { stats: { morality: -3 }, inventoryAdd: ["antibiotics"], relationships: { Volunteers: -4 } },
              tags: ["stealth", "survival"]
            }
          ]
        }
      ]
    },
    {
      act: 3,
      id: "neutral_act3_hub_main",
      text: "Dawn ash smears the skyline purple. Alex balances flare codes and asks whether you guide convoys, weaponize raiders, or sell secrets.",
      timeDelta: 1,
      tags: ["hub", "act3"],
      bridgeEntryText: "Cross the shattered skybridge with Alex",
      bridge: {
        id: "neutral_act3_bridge_signal",
        text: "A fractured skybridge sways above burning streets. The next choices decide who reaches the finale.",
        tags: ["bridge", "act3"],
        choices: [
          {
            id: "bridge3_evacuate",
            text: "Evacuate families toward the stadium",
            goTo: "neutral_act4_hub_main",
            effects: { time: 1, relationships: { Volunteers: 4 }, stats: { stress: 3 } },
            tags: ["leader", "survival"]
          },
          {
            id: "bridge3_cutdeal",
            text: "Broker safe passage with raider scouts",
            goTo: "neutral_act4_hub_main",
            effects: { flagsSet: ["joined_raiders"], relationships: { Raiders: 5 }, stats: { morality: -2 } },
            tags: ["social", "stealth"]
          },
          {
            id: "bridge3_delay",
            text: "Delay to gather more proof",
            goTo: "neutral_act3_hub_main",
            effects: { stats: { stress: 2 }, inventoryAdd: ["evidence_case"] },
            tags: ["stealth", "survival"]
          }
        ]
      },
      sideScenes: [
        {
          id: "neutral_act3_side_beacon",
          entryText: "Repair a failing beacon",
          text: "One rooftop beacon sputters. Alex grips the ladder waiting for your call.",
          tags: ["side", "act3"],
          choices: [
            {
              id: "act3_fix_beacon",
              text: "Risk the climb with Alex",
              goTo: "neutral_act3_hub_main",
              effects: { stats: { stress: 2 }, relationships: { Convoy: 4 }, inventoryAdd: ["signal_core"] },
              tags: ["survival", "leader"]
            },
            {
              id: "act3_remote_shutdown",
              text: "Shut it down to save time",
              goTo: "neutral_act3_hub_main",
              effects: { stats: { morality: -1 }, relationships: { Convoy: -3, Raiders: 3 } },
              tags: ["stealth", "combat"]
            }
          ]
        },
        {
          id: "neutral_act3_side_rescue",
          entryText: "Respond to a trapped signal",
          text: "A trapped convoy driver begs for extraction over a cracked radio.",
          tags: ["side", "act3"],
          choices: [
            {
              id: "act3_pull_driver",
              text: "Pull the driver out yourself",
              goTo: "neutral_act3_hub_main",
              effects: { stats: { stress: 3, morality: 2 }, relationships: { Convoy: 5 } },
              tags: ["leader", "moral"]
            },
            {
              id: "act3_use_driver",
              text: "Leverage them for intel",
              goTo: "neutral_act3_hub_main",
              effects: { stats: { morality: -3 }, relationships: { Convoy: -4, Raiders: 4 }, inventoryAdd: ["raider_codes"] },
              tags: ["social", "stealth"]
            }
          ]
        }
      ]
    },
    {
      act: 4,
      id: "neutral_act4_hub_main",
      text: "Night sirens spool up again. Alex studies faction leaders waiting for your final gambit and wonders whose future you cash in.",
      timeDelta: 1,
      tags: ["hub", "act4"],
      bridgeEntryText: "Face the final council with Alex",
      bridge: {
        id: "neutral_act4_bridge_finale",
        text: "All factions crowd the stadium floor. Proofs you gathered decide who follows you into the finale.",
        tags: ["bridge", "act4"],
        choices: [
          {
            id: "bridge4_to_finale",
            text: "Announce the final plan",
            goTo: "neutral_act5_hub_main",
            effects: { time: 1, stats: { stress: 4 }, relationships: { Alex: 3 } },
            tags: ["leader", "social"]
          },
          {
            id: "bridge4_delay",
            text: "Delay and reconsider alliances",
            goTo: "neutral_act4_hub_main",
            effects: { stats: { stress: 2 }, inventoryAdd: ["council_notes"] },
            tags: ["stealth", "survival"]
          }
        ]
      },
      sideScenes: [
        {
          id: "neutral_act4_side_command",
          entryText: "Review siege drills",
          text: "Volunteers rehearse breach drills in the rain. Alex needs your verdict.",
          tags: ["side", "act4"],
          choices: [
            {
              id: "act4_tighten_drills",
              text: "Tighten the drills",
              goTo: "neutral_act4_hub_main",
              effects: { stats: { stress: 2 }, relationships: { Volunteers: 4 } },
              tags: ["leader", "combat"]
            },
            {
              id: "act4_relax_drills",
              text: "Give them rest",
              goTo: "neutral_act4_hub_main",
              effects: { stats: { stress: -3 }, relationships: { Volunteers: 2, Raiders: 2 } },
              tags: ["moral", "survival"]
            }
          ]
        },
        {
          id: "neutral_act4_side_spy",
          entryText: "Interrogate the captured spy",
          text: "A captured raider messenger refuses to talk until you involve Alex.",
          tags: ["side", "act4"],
          choices: [
            {
              id: "act4_show_mercy",
              text: "Offer mercy for intel",
              goTo: "neutral_act4_hub_main",
              effects: { stats: { morality: 2 }, relationships: { Raiders: 2, Volunteers: -2 }, inventoryAdd: ["spy_report"] },
              tags: ["social", "moral"]
            },
            {
              id: "act4_break_spy",
              text: "Break them in front of Alex",
              goTo: "neutral_act4_hub_main",
              effects: { stats: { morality: -4, stress: -1 }, relationships: { Raiders: -3, Alex: -2 } },
              tags: ["combat", "stealth"]
            }
          ]
        }
      ]
    },
    {
      act: 5,
      id: "neutral_act5_hub_main",
      text: "The siren fades to a heartbeat thrum. Alex stands beside you while convoys idle, raiders sharpen blades, and exhausted families beg for verdicts.",
      timeDelta: 1,
      tags: ["hub", "act5"],
      bridgeEntryText: "Take a breath before the epilogue",
      bridge: {
        id: "neutral_act5_bridge_reflection",
        text: "In a quiet broadcast booth, you and Alex replay every promise you made.",
        tags: ["bridge", "act5"],
        choices: [
          {
            id: "bridge5_reflect",
            text: "Reflect on the cost",
            goTo: "neutral_act5_hub_main",
            effects: { stats: { stress: -3 }, relationships: { Alex: 4 } },
            tags: ["moral", "leader"]
          },
          {
            id: "bridge5_press",
            text: "Press forward without pause",
            goTo: "neutral_act5_hub_main",
            effects: { stats: { stress: 3 }, relationships: { Alex: -2 } },
            tags: ["survival", "stealth"]
          }
        ]
      },
      sideScenes: [
        {
          id: "neutral_act5_side_breathe",
          entryText: "Share a rare quiet moment with Alex",
          text: "In a darkened radio booth, Alex asks what kind of ending you deserve.",
          tags: ["side", "act5"],
          choices: [
            {
              id: "act5_confide",
              text: "Confide the truth",
              goTo: "neutral_act5_hub_main",
              effects: { stats: { stress: -4 }, relationships: { Alex: 5 } },
              tags: ["moral", "social"]
            },
            {
              id: "act5_deflect",
              text: "Deflect with gallows humor",
              goTo: "neutral_act5_hub_main",
              effects: { stats: { stress: -1 }, relationships: { Alex: -2, Raiders: 2 } },
              tags: ["social", "stealth"]
            }
          ]
        }
      ]
    }
  ];
  function buildStoryWorld() {
    const scenes = {};
    Object.assign(scenes, createActZeroScenes());
    const { scenes: routeScenes, endings, entryMap } = generateRouteScenes();
    Object.assign(scenes, routeScenes);
    Object.assign(scenes, endings);
    Object.assign(scenes, createHubAndSideScenes(entryMap));
    return scenes;
  }

  function createActZeroScenes() {
    return {
      neutral_act0_intro_apartment: {
        id: "neutral_act0_intro_apartment",
        text: "Sirens fade into rain hammering the apartment windows. Alex pounds on your door and whispers that the neighbor turned.",
        tags: ["intro", "act0"],
        choices: [
          {
            id: "act0_peek",
            text: "Slide the dresser enough to check on Alex",
            goTo: "neutral_act0_contact_alex",
            effects: { stats: { stress: -1 }, relationships: { Alex: 2 } },
            tags: ["survival", "leader"]
          },
          {
            id: "act0_brace",
            text: "Grip your knife and brace the door",
            goTo: "neutral_act0_contact_alex",
            effects: { stats: { stamina: -1, stress: 1 } },
            tags: ["combat", "survival"]
          },
          {
            id: "act0_call",
            text: "Call out through the door to calm Alex",
            goTo: "neutral_act0_contact_alex",
            effects: { relationships: { Alex: 3 }, stats: { stress: -2 } },
            tags: ["social", "leader"]
          }
        ]
      },
      neutral_act0_contact_alex: {
        id: "neutral_act0_contact_alex",
        text: "Alex presses their forehead to the chain and begs you to open up. You can set the tone of who {{name}} will be tonight.",
        tags: ["intro", "act0"],
        choices: [
          {
            id: "act0_open",
            text: "Open the door and let Alex in",
            goTo: "neutral_act0_background_select",
            assignName: true,
            effects: { relationships: { Alex: 3 }, stats: { stress: -1 } },
            tags: ["social", "leader"]
          },
          {
            id: "act0_chain",
            text: "Keep the chain and talk",
            goTo: "neutral_act0_background_select",
            effects: { relationships: { Alex: 1 }, stats: { stress: -1 } },
            tags: ["social", "survival"]
          },
          {
            id: "act0_direct",
            text: "Order Alex to gather the floor while you gear up",
            goTo: "neutral_act0_background_select",
            effects: { relationships: { Alex: 2 }, persona: { leader: 1 } },
            tags: ["leader", "combat"]
          }
        ]
      },
      neutral_act0_background_select: {
        id: "neutral_act0_background_select",
        text: "Alex studies {{name}} and asks what history you bring to this building.",
        tags: ["intro", "act0"],
        choices: [
          {
            id: "background_medic",
            text: "Confess you're a field medic",
            goTo: "neutral_act0_pact",
            setBackground: "medic",
            effects: { persona: { protector: 1 }, relationships: { Alex: 1 }, flagsSet: ["background_medic"] },
            tags: ["moral", "leader"]
          },
          {
            id: "background_fighter",
            text: "Admit you were a union brawler",
            goTo: "neutral_act0_pact",
            setBackground: "fighter",
            effects: { persona: { warlord: 1 }, flagsSet: ["background_fighter"] },
            tags: ["combat", "leader"]
          },
          {
            id: "background_hacker",
            text: "Explain your network skills",
            goTo: "neutral_act0_pact",
            setBackground: "hacker",
            effects: { persona: { fixer: 1 }, flagsSet: ["background_hacker"] },
            tags: ["social", "stealth"]
          },
          {
            id: "background_thief",
            text: "Smirk about your thief past",
            goTo: "neutral_act0_pact",
            setBackground: "thief",
            effects: { persona: { sociopath: 1 }, flagsSet: ["background_thief"] },
            tags: ["stealth", "survival"]
          }
        ]
      },
      neutral_act0_pact: {
        id: "neutral_act0_pact",
        text: "Sirens fade beneath rain slamming broken windows. Alex paces between sobbing neighbors while smoke coils in the stairwell. {{name}}—the {{background}} of this block—must decide whether to steady Alex, weaponize their fear, or drag everyone into your plan.",
        tags: ["intro", "act0"],
        choices: [
          {
            id: "act0_reassure",
            text: "Promise Alex you'll protect the floor",
            goTo: "neutral_act1_hub_main",
            effects: { persona: { protector: 1 }, relationships: { Alex: 4 }, stats: { morality: 2 } },
            tags: ["moral", "leader"]
          },
          {
            id: "act0_pragmatic",
            text: "Tell Alex survival means hard bargains",
            goTo: "neutral_act1_hub_main",
            effects: { persona: { fixer: 1 }, relationships: { Alex: 1 }, stats: { stress: 1 } },
            tags: ["social", "survival"]
          },
          {
            id: "act0_ruthless",
            text: "Warn Alex that fear will keep people obedient",
            goTo: "neutral_act1_hub_main",
            effects: { persona: { warlord: 1, sociopath: 1 }, relationships: { Alex: -1 }, stats: { morality: -2 } },
            tags: ["combat", "stealth"]
          }
        ]
      }
    };
  }

  function createHubAndSideScenes(entryMap) {
    const scenes = {};
    for (const blueprint of HUB_BLUEPRINTS) {
      const hub = {
        id: blueprint.id,
        text: blueprint.text,
        timeDelta: blueprint.timeDelta,
        tags: blueprint.tags.slice(),
        choices: []
      };
      const actEntries = entryMap[blueprint.act] || {};
      for (const [routeKey, rootId] of Object.entries(actEntries)) {
        const routeDef = ROUTE_BLUEPRINTS[routeKey];
        const theme = routeDef ? routeDef.acts.find((t) => t.act === blueprint.act) : null;
        if (!routeDef || !theme) continue;
        hub.choices.push(buildEntryChoice(routeKey, routeDef, theme, rootId));
      }
      for (const side of blueprint.sideScenes) {
        const entryChoice = {
          id: `${side.id}_entry`,
          text: side.entryText,
          goTo: side.id,
          tags: side.tags.slice(),
          effects: { stats: { stress: -1 } }
        };
        hub.choices.push(entryChoice);
        const sideScene = {
          id: side.id,
          text: side.text,
          tags: side.tags.slice(),
          choices: side.choices.map((choice) => {
            const copy = deepClone(choice);
            if (!copy.goTo) copy.goTo = blueprint.id;
            if (!copy.tags) copy.tags = side.tags.slice();
            return copy;
          })
        };
        scenes[side.id] = sideScene;
      }
      const bridgeEntry = {
        id: `${blueprint.bridge.id}_entry`,
        text: blueprint.bridgeEntryText,
        goTo: blueprint.bridge.id,
        tags: ["leader", "social"],
        effects: { stats: { stress: 2 } }
      };
      hub.choices.push(bridgeEntry);
      scenes[blueprint.id] = hub;
      scenes[blueprint.bridge.id] = {
        id: blueprint.bridge.id,
        text: blueprint.bridge.text,
        tags: blueprint.bridge.tags.slice(),
        choices: blueprint.bridge.choices.map((choice) => deepClone(choice))
      };
    }
    return scenes;
  }

  function buildEntryChoice(routeKey, routeDef, theme, goTo) {
    const choice = {
      id: `${routeKey}_act${theme.act}_entry`,
      text: theme.entryPrompt,
      goTo,
      tags: routeDef.tags.slice(),
      effects: {
        flagsSet: [routeDef.routeFlag],
        persona: { [routeDef.personaKey]: 1 },
        relationships: { Alex: 3, [routeDef.relationship]: routeDef.relationshipDelta }
      },
      popupText: `${routeDef.label} route engaged.`
    };
    if (theme.act === 5) {
      choice.req = { flags: ROUTE_PROOFS[routeKey] };
      choice.effects.stats = { stress: 2 };
    }
    return choice;
  }

  function generateRouteScenes() {
    const scenes = {};
    const endings = {};
    const entryMap = {};
    const maxDepth = 3;
    for (const [routeKey, routeDef] of Object.entries(ROUTE_BLUEPRINTS)) {
      for (const theme of routeDef.acts) {
        const exitTargets = [];
        if (Array.isArray(theme.endings) && theme.endings.length) {
          const generatedEndings = [];
          for (const endingDef of theme.endings) {
            const endingId = `${routeKey}_act${theme.act}_ending_${endingDef.slug}`;
            endings[endingId] = {
              id: endingId,
              text: endingDef.text,
              isEnding: true,
              endingType: endingDef.endingType,
              tags: ["ending", routeKey, `act${theme.act}`]
            };
            generatedEndings.push(endingId);
          }
          exitTargets.push(...generatedEndings);
        } else {
          exitTargets.push(theme.exitForward, theme.returnHub);
        }
        const rootId = createSetpieceTree(routeKey, routeDef, theme, scenes, exitTargets, maxDepth);
        entryMap[theme.act] = entryMap[theme.act] || {};
        entryMap[theme.act][routeKey] = rootId;
      }
    }
    return { scenes, endings, entryMap };
  }

  function createSetpieceTree(routeKey, routeDef, theme, scenes, exitTargets, maxDepth, depth = 0, path = []) {
    const suffix = path.length ? path.join("_") : "root";
    const id = `${routeKey}_act${theme.act}_setpiece_${theme.slug}_d${depth}_${suffix}`;
    if (scenes[id]) return id;
    const scene = {
      id,
      text: composeSetpieceText(routeKey, routeDef, theme, depth, path),
      tags: ["setpiece", routeKey, `act${theme.act}`],
      choices: []
    };
    scenes[id] = scene;
    for (let branch = 0; branch < 3; branch += 1) {
      const choice = buildSetpieceChoice(routeKey, routeDef, theme, depth, path, branch, exitTargets, maxDepth, scenes);
      scene.choices.push(choice);
    }
    return id;
  }

  function buildSetpieceChoice(routeKey, routeDef, theme, depth, path, branch, exitTargets, maxDepth, scenes) {
    const nextPath = path.concat(branch);
    const choice = {
      id: `choice_${depth}_${path.length ? path.join("_") : "root"}_${branch}`,
      text: createChoiceLabel(routeDef, theme, depth, branch, path),
      tags: routeDef.tags.slice()
    };
    const effects = computeChoiceEffects(routeDef, theme, depth, branch);
    let goTo;
    if (depth >= maxDepth - 1) {
      const index = (branch + sumPath(path)) % exitTargets.length;
      goTo = exitTargets[index];
      if (theme.proofFlag) {
        effects.flagsSet = effects.flagsSet || [];
        if (!effects.flagsSet.includes(theme.proofFlag)) effects.flagsSet.push(theme.proofFlag);
      }
      if (theme.finalFlag) {
        effects.flagsSet = effects.flagsSet || [];
        if (!effects.flagsSet.includes(theme.finalFlag)) effects.flagsSet.push(theme.finalFlag);
      }
      if (theme.loot && branch === 0) {
        effects.inventoryAdd = effects.inventoryAdd || [];
        if (!effects.inventoryAdd.includes(theme.loot)) effects.inventoryAdd.push(theme.loot);
      }
    } else {
      goTo = createSetpieceTree(routeKey, routeDef, theme, scenes, exitTargets, maxDepth, depth + 1, nextPath);
    }
    choice.goTo = goTo;
    choice.effects = effects;
    choice.popupText = `${routeDef.label} consequence recorded.`;
    return choice;
  }

  function composeSetpieceText(routeKey, routeDef, theme, depth, path) {
    const sum = sumPath(path);
    const narrative = routeDef.narrative;
    const action = narrative.actions[(depth + sum) % narrative.actions.length];
    const environment = narrative.environments[(depth * 2 + sum) % narrative.environments.length];
    const focus = theme.focus[(depth + sum) % theme.focus.length];
    const pressure = narrative.pressures[(depth + path.length) % narrative.pressures.length];
    const reflection = narrative.reflections[(depth + sum) % narrative.reflections.length];
    const intro = depth === 0 ? theme.summary : theme.stakes[(depth + sum) % theme.stakes.length];
    const closing = "Alex studies {{name}} to see which promise survives.";
    return `${intro} You ${action} while ${environment}. The ${focus} becomes the hinge as ${pressure}. ${reflection} ${closing}`;
  }

  function createChoiceLabel(routeDef, theme, depth, branch, path) {
    const verb = routeDef.verbs[(depth + branch) % routeDef.verbs.length];
    const focus = theme.focus[(branch + sumPath(path)) % theme.focus.length];
    if (branch === 0) return `${verb} the ${focus} alongside Alex (+Morality)`;
    if (branch === 1) return `${verb} the ${focus} with calculated poise (+Stress)`;
    return `${verb} the ${focus} without mercy (−Morality)`;
  }

  function computeChoiceEffects(routeDef, theme, depth, branch) {
    const effects = { time: 1 };
    const stats = {};
    const stress = (routeDef.stressTilt[branch] || 0) + depth;
    if (stress) stats.stress = stress;
    const morality = (routeDef.moralityTilt[branch] || 0) - Math.floor(depth / 2);
    if (morality) stats.morality = morality;
    if (Object.keys(stats).length) effects.stats = stats;

    if (routeDef.personaKey) {
      const personaValue = Math.max(1, (theme.personaShift || 1) - depth);
      effects.persona = { [routeDef.personaKey]: personaValue };
    }

    const relationships = {};
    const relDelta = branch === 2 ? -routeDef.relationshipDelta : routeDef.relationshipDelta;
    if (relDelta) relationships[routeDef.relationship] = relDelta;
    if (branch === 0) {
      relationships.Alex = 3;
    } else if (branch === 2) {
      relationships.Alex = -3;
    }
    if (Object.keys(relationships).length) effects.relationships = relationships;

    effects.pushEvent = branch === 2
      ? "Fear ripples through the corridor."
      : branch === 0
      ? "Hope swells among the survivors."
      : "Tension hums as you balance the line.";

    return effects;
  }

  function sumPath(path = []) {
    return path.reduce((sum, value) => sum + value, 0);
  }

  const STORY_WORLD = buildStoryWorld();
  Object.assign(window.STORY_DATABASE, STORY_WORLD);

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
