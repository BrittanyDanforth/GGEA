/* CONSEQUENCE — Offline Story Game Engine + Sample Story */
(function () {
  "use strict";

  /**
   * Deterministic stable stringify (sorted keys) for hashing and export.
   */
  function stableStringify(value) {
    const seen = new WeakSet();
    const recurse = (val) => {
      if (val === null || typeof val !== "object") return JSON.stringify(val);
      if (seen.has(val)) return '"[Circular]"';
      seen.add(val);
      if (Array.isArray(val)) return '[' + val.map(recurse).join(',') + ']';
      const keys = Object.keys(val).sort();
      return '{' + keys.map((k) => JSON.stringify(k) + ':' + recurse(val[k])).join(',') + '}';
    };
    return recurse(value);
  }

  /**
   * Lightweight FNV-1a 32-bit hash to display a short state fingerprint.
   */
  function hashFNV1a(str) {
    let hash = 0x811c9dc5;
    for (let i = 0; i < str.length; i++) {
      hash ^= str.charCodeAt(i);
      hash = (hash >>> 0) * 0x01000193;
    }
    return (hash >>> 0).toString(16).padStart(8, "0");
  }

  function clamp(value, min, max) { return Math.max(min, Math.min(max, value)); }

  function formatDayHour(totalHours) {
    const day = Math.floor(totalHours / 24);
    const hour = totalHours % 24;
    const hh = String(hour).padStart(2, "0");
    return `Day ${day} · ${hh}:00`;
  }

  function downloadJson(filename, dataObj) {
    const blob = new Blob([JSON.stringify(dataObj, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  }

  function createFromTemplate(templateId) {
    const template = document.getElementById(templateId);
    if (!template) return null;
    return template.content.firstElementChild.cloneNode(true);
  }

  const STORAGE_KEY = "CONSEQUENCE_SAVE_V1";

  /**
   * Story format:
   * sceneId: {
   *   text: string | function(state) => string,
   *   choices: [
   *     {
   *       text: string | function(state) => string,
   *       if?: function(state) => boolean,
   *       effect?: function(state) => void | {
   *         time?: number (hours),
   *         setFlag?: string | string[],
   *         clearFlag?: string | string[],
   *         addInventory?: string | string[],
   *         removeInventory?: string | string[],
   *         personaDelta?: { protector?: number, warlord?: number, fixer?: number, killer?: number, sociopath?: number },
   *         traumaDelta?: number,
   *         creditDelta?: number,
   *         heatDelta?: number,
   *         relationshipDelta?: { [name: string]: number },
   *         journalAdd?: { title: string, objective: string },
   *         event?: string,
   *         consequence?: string
   *       },
   *       goTo: string
   *     }
   *   ]
   * }
   */

  // Sample offline story with light consequence logic
  const SAMPLE_STORY = {
    start: {
      text: (s) => `Sirens carve the night. You stand at the edge of Ashgate, a city choking on its own smoke. Who are you, really?`,
      choices: [
        { text: "I protect the weak.", effect: { personaDelta: { protector: 1 }, event: "Chose Protector persona." }, goTo: "bg_set" },
        { text: "I seize control.", effect: { personaDelta: { warlord: 1 }, event: "Chose Warlord persona." }, goTo: "bg_set" },
        { text: "I fix what others break.", effect: { personaDelta: { fixer: 1 }, event: "Chose Fixer persona." }, goTo: "bg_set" },
        { text: "I do what's necessary.", effect: { personaDelta: { killer: 1 }, event: "Chose Killer persona." }, goTo: "bg_set" },
        { text: "I don't feel much anymore.", effect: { personaDelta: { sociopath: 1 }, event: "Chose Sociopath persona." }, goTo: "bg_set" }
      ]
    },
    bg_set: {
      text: (s) => `A courier stumbles into the alley, bleeding. A sealed drive glints in the streetlight.`,
      choices: [
        {
          text: "Help them, bind their wound.",
          effect: { time: 1, traumaDelta: -2, addInventory: "Sealed Drive", relationshipDelta: { Courier: 10 }, event: "You stabilized the courier.", consequence: "People in Ashgate talk. Mercy echoes." },
          goTo: "alley_split"
        },
        {
          text: "Take the drive and vanish.",
          effect: { time: 0, addInventory: "Sealed Drive", setFlag: "stole_drive", relationshipDelta: { Courier: -20 }, heatDelta: 2, event: "You took the drive and left.", consequence: "Trust burns faster than bridges." },
          goTo: "alley_split"
        }
      ]
    },
    alley_split: {
      text: (s) => `The city offers two doors: a clinic's green cross to the east, and a warehouse with private guards to the west.`,
      choices: [
        { text: "Head to the clinic.", effect: { time: 1, event: "You went to the clinic." }, goTo: "clinic" },
        { text: "Visit the warehouse.", effect: { time: 1, event: "You approached the warehouse." }, goTo: "warehouse" }
      ]
    },
    clinic: {
      text: (s) => s.flags.stole_drive
        ? `The clinic locks click shut as you approach. Word spreads: someone robbed a courier.`
        : `Nurses wave you in. The courier rests inside.`,
      choices: [
        {
          text: (s) => s.flags.stole_drive ? "Leave quietly." : "Return the drive to the courier.",
          effect: (s) => {
            if (!s.flags.stole_drive) {
              return { removeInventory: "Sealed Drive", relationshipDelta: { Courier: 15 }, event: "You returned the drive.", consequence: "The clinic owes you one." };
            }
            return { event: "You left the clinic alone." };
          },
          goTo: "alley_split"
        }
      ]
    },
    warehouse: {
      text: (s) => `Guards eye you. A foreman whispers: that drive unlocks a payroll.`,
      choices: [
        {
          text: "Sell the drive for credits.",
          if: (s) => s.inventory.includes("Sealed Drive"),
          effect: { removeInventory: "Sealed Drive", creditDelta: 25, setFlag: "sold_drive", event: "You sold the drive to the foreman.", consequence: "Money is a choice with memory." },
          goTo: "finale"
        },
        {
          text: "Walk away.",
          effect: { event: "You left the warehouse." },
          goTo: "alley_split"
        }
      ]
    },
    finale: {
      text: (s) => {
        const parts = [];
        if (s.flags.sold_drive) parts.push("You cashed out. Heat rises.");
        if (s.relationships.Courier >= 10) parts.push("The courier vouches for you.");
        if (s.persona.protector > 0) parts.push("Protector's path glimmers.");
        if (s.persona.warlord > 0) parts.push("Warlord's shadow lengthens.");
        if (s.persona.fixer > 0) parts.push("Fixer lines up favors.");
        if (s.persona.killer > 0) parts.push("Killer's edge stays close.");
        if (s.persona.sociopath > 0) parts.push("Sociopath sleeps well.");
        if (!parts.length) parts.push("Ashgate forgets no-one, not even ghosts.");
        return parts.join(" ");
      },
      choices: [
        { text: "Stand in the smoke and breathe.", effect: { time: 1, event: "You faced Ashgate.", consequence: "This city will remember you." }, goTo: "finale" }
      ]
    }
  };

  function createNewState() {
    return {
      version: 1,
      player: { name: "Rook", background: "Drifter" },
      stats: { credit: 0, heat: 0 },
      trauma: 0, // 0-100
      persona: { protector: 0, warlord: 0, fixer: 0, killer: 0, sociopath: 0 },
      flags: {},
      inventory: [],
      journal: [], // { title, objective }
      relationships: { Courier: 0 },
      timeHours: 0, // world time in hours
      currentSceneId: "start",
      decisionTrace: [], // { sceneId, choiceText }
      eventLog: [] // { t, text }
    };
  }

  const dom = {
    sceneText: document.getElementById("scene-text"),
    choices: document.getElementById("choices"),
    stats: document.getElementById("stats"),
    dayHour: document.getElementById("dayhour-indicator"),
    worldTime: document.getElementById("world-time"),
    charName: document.getElementById("char-name"),
    charBackground: document.getElementById("char-background"),
    inventoryList: document.getElementById("inventory-list"),
    traumaBar: document.getElementById("trauma-bar"),
    traumaWarning: document.getElementById("trauma-warning"),
    personaGrid: document.getElementById("persona-grid"),
    journalList: document.getElementById("journal-list"),
    objectiveCount: document.getElementById("objective-count"),
    relationshipsList: document.getElementById("relationships-list"),
    relationshipCount: document.getElementById("relationship-count"),
    eventLog: document.getElementById("event-log"),
    flagDisplay: document.getElementById("flag-display"),
    decisionTree: document.getElementById("decision-tree"),
    stateHash: document.getElementById("state-hash"),
    // Controls
    btnNew: document.getElementById("new-game"),
    btnContinue: document.getElementById("continue-game"),
    btnSave: document.getElementById("save-game"),
    btnLoad: document.getElementById("load-game"),
    btnExport: document.getElementById("export-game"),
    inputFile: document.getElementById("file-loader"),
    // Backend toggle
    btnToggleBackend: document.getElementById("toggle-backend"),
    backendContent: document.getElementById("backend-content"),
    // Consequence popup
    consequencePopup: document.getElementById("consequence-popup"),
    consequenceText: document.getElementById("consequence-text"),
    consequenceOk: document.getElementById("consequence-ok")
  };

  const engine = {
    story: window.STORY_DATABASE && Object.keys(window.STORY_DATABASE).length ? window.STORY_DATABASE : SAMPLE_STORY,
    state: createNewState(),

    startNewGame() {
      this.state = createNewState();
      this.pushEvent("New game started.");
      this.renderAll();
      this.persistContinueHint();
    },

    canContinue() {
      try {
        const data = localStorage.getItem(STORAGE_KEY);
        return Boolean(data);
      } catch (e) {
        return false;
      }
    },

    persistContinueHint() {
      dom.btnContinue.disabled = !this.canContinue();
    },

    saveToLocal() {
      try {
        localStorage.setItem(STORAGE_KEY, stableStringify({ state: this.state, story: this.story }));
        this.pushEvent("Game saved.");
        this.persistContinueHint();
      } catch (e) {
        this.pushEvent("Save failed (storage).");
      }
      this.renderBackend();
    },

    loadFromLocal() {
      try {
        const raw = localStorage.getItem(STORAGE_KEY);
        if (!raw) return false;
        const payload = JSON.parse(raw);
        if (payload.story && typeof payload.story === "object") {
          this.story = payload.story;
        }
        if (payload.state && typeof payload.state === "object") {
          this.state = payload.state;
        }
        this.pushEvent("Game loaded from local storage.");
        this.renderAll();
        this.persistContinueHint();
        return true;
      } catch (e) {
        this.pushEvent("Load failed (corrupt). ");
        return false;
      }
    },

    exportToFile() {
      const payload = { version: 1, exportedAt: new Date().toISOString(), state: this.state, story: this.story };
      downloadJson("consequence-save.json", payload);
      this.pushEvent("Exported save to file.");
    },

    importFromFile(file) {
      const reader = new FileReader();
      reader.onload = () => {
        try {
          const payload = JSON.parse(String(reader.result || "{}"));
          if (payload.story && typeof payload.story === "object") {
            this.story = payload.story;
          }
          if (payload.state && typeof payload.state === "object") {
            this.state = payload.state;
          }
          this.pushEvent("Imported save from file.");
          this.renderAll();
          this.persistContinueHint();
        } catch (e) {
          this.pushEvent("Import failed (invalid JSON). ");
        }
      };
      reader.readAsText(file);
    },

    getCurrentScene() {
      return this.story[this.state.currentSceneId];
    },

    pushEvent(text) {
      this.state.eventLog.push({ t: this.state.timeHours, text });
      if (this.state.eventLog.length > 200) this.state.eventLog.shift();
    },

    applyEffect(effect) {
      if (!effect) return;
      const s = this.state;
      if (typeof effect === "function") {
        const obj = effect(s);
        if (obj) return this.applyEffect(obj);
        return;
      }
      if (effect.time) s.timeHours += effect.time;
      if (typeof effect.traumaDelta === "number") s.trauma = clamp(s.trauma + effect.traumaDelta, 0, 100);
      if (typeof effect.creditDelta === "number") s.stats.credit = Math.max(0, s.stats.credit + effect.creditDelta);
      if (typeof effect.heatDelta === "number") s.stats.heat = Math.max(0, s.stats.heat + effect.heatDelta);
      if (effect.personaDelta) {
        for (const key of Object.keys(effect.personaDelta)) {
          s.persona[key] = (s.persona[key] || 0) + (effect.personaDelta[key] || 0);
        }
      }
      const toArray = (v) => (Array.isArray(v) ? v : v ? [v] : []);
      for (const f of toArray(effect.setFlag)) s.flags[f] = true;
      for (const f of toArray(effect.clearFlag)) delete s.flags[f];
      for (const it of toArray(effect.addInventory)) {
        if (!s.inventory.includes(it)) s.inventory.push(it);
      }
      for (const it of toArray(effect.removeInventory)) {
        const idx = s.inventory.indexOf(it);
        if (idx >= 0) s.inventory.splice(idx, 1);
      }
      if (effect.relationshipDelta) {
        for (const name of Object.keys(effect.relationshipDelta)) {
          const delta = effect.relationshipDelta[name];
          s.relationships[name] = (s.relationships[name] || 0) + delta;
        }
      }
      if (effect.journalAdd) {
        s.journal.push({ title: effect.journalAdd.title, objective: effect.journalAdd.objective });
      }
      if (effect.event) this.pushEvent(effect.event);
      if (effect.consequence) this.showConsequence(effect.consequence);
    },

    showConsequence(text) {
      dom.consequenceText.textContent = text;
      dom.consequencePopup.classList.remove("hidden");
      dom.consequenceOk.focus();
    },

    dismissConsequence() {
      dom.consequencePopup.classList.add("hidden");
    },

    choose(choice) {
      const sceneId = this.state.currentSceneId;
      const choiceText = typeof choice.text === "function" ? String(choice.text(this.state)) : String(choice.text);
      this.applyEffect(choice.effect);
      this.state.decisionTrace.push({ sceneId, choiceText });
      this.state.currentSceneId = choice.goTo;
      this.renderAll();
      this.saveToLocal();
    },

    renderAll() {
      this.renderStats();
      this.renderCharacterPanel();
      this.renderJournal();
      this.renderRelationships();
      this.renderEventLog();
      this.renderBackend();
      this.renderScene();
      this.persistContinueHint();
    },

    renderStats() {
      dom.stats.innerHTML = "";
      const pills = [
        { label: "Credit", value: this.state.stats.credit },
        { label: "Heat", value: this.state.stats.heat },
        { label: "Trauma", value: `${this.state.trauma}%` },
        { label: "Time", value: formatDayHour(this.state.timeHours) }
      ];
      for (const pill of pills) {
        const el = document.createElement("div");
        el.className = "status-pill";
        const l = document.createElement("span");
        l.className = "pill-label";
        l.textContent = pill.label;
        const v = document.createElement("span");
        v.className = "pill-value";
        v.textContent = String(pill.value);
        el.appendChild(l); el.appendChild(v);
        dom.stats.appendChild(el);
      }
    },

    renderCharacterPanel() {
      dom.dayHour.textContent = formatDayHour(this.state.timeHours);
      dom.worldTime.textContent = `T+${this.state.timeHours}h`;
      dom.charName.textContent = this.state.player.name || "—";
      dom.charBackground.textContent = this.state.player.background || "—";

      // Inventory
      dom.inventoryList.innerHTML = "";
      if (this.state.inventory.length === 0) {
        const span = document.createElement("span");
        span.className = "empty-inventory";
        span.textContent = "(empty)";
        dom.inventoryList.appendChild(span);
      } else {
        for (const item of this.state.inventory) {
          const chip = document.createElement("span");
          chip.className = "inventory-item";
          chip.textContent = item;
          dom.inventoryList.appendChild(chip);
        }
      }

      // Trauma
      dom.traumaBar.style.width = `${clamp(this.state.trauma, 0, 100)}%`;
      const t = this.state.trauma;
      let label = "Stable"; let cls = "good";
      if (t >= 66) { label = "Breaking"; cls = "severe"; }
      else if (t >= 33) { label = "Strained"; cls = "moderate"; }
      dom.traumaWarning.textContent = label;
      dom.traumaWarning.className = `trauma-warning ${cls}`;

      // Persona
      dom.personaGrid.innerHTML = "";
      const personaOrder = ["protector", "warlord", "fixer", "killer", "sociopath"];
      for (const key of personaOrder) {
        const row = document.createElement("div");
        row.className = "persona-row";
        const labelEl = document.createElement("div");
        labelEl.className = "persona-label";
        labelEl.textContent = key[0].toUpperCase() + key.slice(1);
        const meter = document.createElement("div");
        meter.className = "persona-meter";
        const fill = document.createElement("div");
        fill.className = "persona-fill";
        const val = clamp((this.state.persona[key] + 5) / 10, 0, 1); // map -5..+5 → 0..1
        fill.style.width = `${Math.round(val * 100)}%`;
        meter.appendChild(fill);
        row.appendChild(labelEl);
        row.appendChild(meter);
        dom.personaGrid.appendChild(row);
      }
    },

    renderJournal() {
      dom.journalList.innerHTML = "";
      for (const entry of this.state.journal) {
        const el = createFromTemplate("tpl-journal-item");
        if (!el) continue;
        el.querySelector(".journal-title").textContent = entry.title || "—";
        el.querySelector(".journal-objective").textContent = entry.objective || "";
        dom.journalList.appendChild(el);
      }
      dom.objectiveCount.textContent = `${this.state.journal.length} ${this.state.journal.length === 1 ? "objective" : "objectives"}`;
    },

    renderRelationships() {
      dom.relationshipsList.innerHTML = "";
      const names = Object.keys(this.state.relationships);
      for (const name of names) {
        const el = createFromTemplate("tpl-relationship-item");
        if (!el) continue;
        const trust = this.state.relationships[name] || 0;
        el.querySelector(".relationship-name").textContent = name;
        const status = el.querySelector(".relationship-status");
        status.textContent = String(trust);
        status.className = `relationship-status ${trust > 5 ? "relationship-trust-good" : trust < -5 ? "relationship-trust-bad" : "relationship-trust-neutral"}`;
        dom.relationshipsList.appendChild(el);
      }
      dom.relationshipCount.textContent = `${names.length} ${names.length === 1 ? "contact" : "contacts"}`;
    },

    renderEventLog() {
      dom.eventLog.innerHTML = "";
      const recent = this.state.eventLog.slice(-50);
      for (const ev of recent) {
        const line = document.createElement("div");
        line.className = "event-item";
        line.textContent = `[T+${ev.t}h] ${ev.text}`;
        dom.eventLog.appendChild(line);
      }
      dom.eventLog.scrollTop = dom.eventLog.scrollHeight;
    },

    renderBackend() {
      // Flags
      dom.flagDisplay.innerHTML = "";
      const flagKeys = Object.keys(this.state.flags).sort();
      if (flagKeys.length === 0) {
        const d = document.createElement("div");
        d.textContent = "(no flags)";
        dom.flagDisplay.appendChild(d);
      } else {
        for (const k of flagKeys) {
          const keyEl = document.createElement("div"); keyEl.textContent = k;
          const valEl = document.createElement("div"); valEl.textContent = String(this.state.flags[k]);
          dom.flagDisplay.appendChild(keyEl);
          dom.flagDisplay.appendChild(valEl);
        }
      }

      // Decision Trace
      dom.decisionTree.innerHTML = "";
      if (this.state.decisionTrace.length === 0) {
        const d = document.createElement("div");
        d.textContent = "(no decisions yet)";
        dom.decisionTree.appendChild(d);
      } else {
        for (const step of this.state.decisionTrace.slice(-50)) {
          const d = document.createElement("div");
          d.textContent = `${step.sceneId} → ${step.choiceText}`;
          dom.decisionTree.appendChild(d);
        }
      }

      // State hash
      const hash = hashFNV1a(stableStringify(this.state));
      dom.stateHash.textContent = hash;
    },

    renderScene() {
      const scene = this.getCurrentScene();
      if (!scene) {
        dom.sceneText.textContent = `Missing scene: ${this.state.currentSceneId}`;
        dom.choices.textContent = "";
        return;
      }
      const text = typeof scene.text === "function" ? scene.text(this.state) : scene.text;
      dom.sceneText.textContent = text;

      dom.choices.innerHTML = "";
      for (const c of scene.choices) {
        const choiceEl = createFromTemplate("tpl-choice") || document.createElement("button");
        choiceEl.className = choiceEl.className || "choice";
        const label = typeof c.text === "function" ? c.text(this.state) : c.text;
        const span = choiceEl.querySelector(".choice-text");
        if (span) span.textContent = label; else choiceEl.textContent = label;
        const allowed = typeof c.if === "function" ? !!c.if(this.state) : true;
        if (!allowed) {
          choiceEl.disabled = true;
        } else {
          choiceEl.addEventListener("click", () => this.choose(c));
        }
        dom.choices.appendChild(choiceEl);
      }
    }
  };

  // Wire controls
  dom.btnNew.addEventListener("click", () => engine.startNewGame());
  dom.btnContinue.addEventListener("click", () => engine.loadFromLocal());
  dom.btnSave.addEventListener("click", () => engine.saveToLocal());
  dom.btnExport.addEventListener("click", () => engine.exportToFile());
  dom.btnLoad.addEventListener("click", () => dom.inputFile.click());
  dom.inputFile.addEventListener("change", (e) => {
    const file = e.target && e.target.files && e.target.files[0];
    if (file) engine.importFromFile(file);
    e.target.value = "";
  });

  dom.btnToggleBackend.addEventListener("click", () => {
    const hidden = dom.backendContent.classList.toggle("hidden");
    dom.btnToggleBackend.setAttribute("aria-expanded", hidden ? "false" : "true");
  });

  dom.consequenceOk.addEventListener("click", () => engine.dismissConsequence());
  dom.consequencePopup.addEventListener("click", (e) => {
    if (e.target === dom.consequencePopup) engine.dismissConsequence();
  });
  window.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !dom.consequencePopup.classList.contains("hidden")) engine.dismissConsequence();
  });

  // Boot
  engine.startNewGame();
})();

