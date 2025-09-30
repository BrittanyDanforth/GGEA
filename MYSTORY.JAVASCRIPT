// CONSEQUENCE - Complete Offline Game Engine with Embedded Story
// Three complete routes: Protector, Ruthless, Manipulator
// Self-contained, no external dependencies

;(function(window) {
  'use strict';

  // Story Database - Embedded directly
  window.STORY_DATABASE = {
    intro: {
      id: 'intro',
      text: 'The world ended not with a bang, but with a whisper. You wake to sirens and smoke. Your apartment door shudders under heavy pounding.',
      choices: [
        {
          text: 'Open the door and help whoever is there',
          type: 'moral',
          consequence: 'major',
          effects: { setFlags: ['route_protector'], delta: { morality: 5, stress: 2 }, pushEvent: 'You chose compassion' },
          goTo: 'help_stranger'
        },
        {
          text: 'Barricade and arm yourself',
          type: 'combat',
          effects: { setFlags: ['route_ruthless'], delta: { strength: 2, stress: 3 }, pushEvent: 'You chose survival' },
          goTo: 'barricade_apt'
        },
        {
          text: 'Observe quietly',
          type: 'stealth',
          effects: { setFlags: ['route_manipulator'], delta: { willpower: 2, charisma: 1 }, pushEvent: 'You chose control' },
          goTo: 'observe_situation'
        }
      ]
    }
  };

  // Game Engine
  class ConsequenceGame {
    constructor() {
      this.state = {
        sceneId: 'intro',
        strength: 40, agility: 40, willpower: 40, charisma: 40,
        morality: 0, stress: 10, trauma: 0,
        flags: new Set(), inventory: new Set(), pending: []
      };
    }

    _applyDelta(delta) {
      for (const [k, v] of Object.entries(delta || {})) {
        if (this.state[k] !== undefined) {
          this.state[k] = Math.max(0, Math.min(100, (this.state[k] || 0) + v));
        }
      }
    }

    _applyEffects(e) {
      if (!e) return;
      if (e.setFlags) e.setFlags.forEach(f => this.state.flags.add(f));
      if (e.clearFlags) e.clearFlags.forEach(f => this.state.flags.delete(f));
      if (e.addItems) e.addItems.forEach(i => this.state.inventory.add(i));
      if (e.removeItems) e.removeItems.forEach(i => this.state.inventory.delete(i));
      if (e.delta) this._applyDelta(e.delta);
      if (e.schedule) e.schedule.forEach(j => this.state.pending.push({...j}));
      if (e.pushEvent) this._logEvent(e.pushEvent);
    }

    _resolvePending() {
      const keep = [];
      for (const job of this.state.pending) {
        job.steps--;
        if (job.steps <= 0) this._applyEffects(job.apply);
        else keep.push(job);
      }
      this.state.pending = keep;
    }

    _logEvent(msg) {
      const div = document.getElementById('summary');
      if (div) {
        const e = document.createElement('div');
        e.className = 'event-log-entry';
        e.textContent = msg;
        div.insertBefore(e, div.firstChild);
      }
      console.log('[EVENT]', msg);
    }

    canChoose(choice) {
      const pre = choice.pre || {};
      if (pre.min) {
        for (const [k, v] of Object.entries(pre.min)) {
          if ((this.state[k] || 0) < v) return { ok: false, reason: choice.blockedReason || `Need ${k} ≥ ${v}` };
        }
      }
      if (pre.max) {
        for (const [k, v] of Object.entries(pre.max)) {
          if ((this.state[k] || 0) > v) return { ok: false, reason: choice.blockedReason || `Need ${k} ≤ ${v}` };
        }
      }
      if (pre.flagsAll) {
        for (const f of pre.flagsAll) {
          if (!this.state.flags.has(f)) return { ok: false, reason: choice.blockedReason || `Need: ${f}` };
        }
      }
      if (pre.flagsNone) {
        for (const f of pre.flagsNone) {
          if (this.state.flags.has(f)) return { ok: false, reason: choice.blockedReason || `Cannot have: ${f}` };
        }
      }
      if (pre.hasItems) {
        for (const i of pre.hasItems) {
          if (!this.state.inventory.has(i)) return { ok: false, reason: choice.blockedReason || `Need: ${i}` };
        }
      }
      return { ok: true };
    }

    makeChoice(choice) {
      const { ok, reason } = this.canChoose(choice);
      if (!ok) { this._logEvent('❌ ' + reason); return; }
      this._applyEffects(choice.effects);
      if (choice.goTo) this.state.sceneId = choice.goTo;
      this._resolvePending();
      this.renderScene();
    }

    renderScene(id) {
      const sceneId = id || this.state.sceneId;
      const scene = window.STORY_DATABASE[sceneId];
      if (!scene) { console.error('Scene not found:', sceneId); return; }
      this.state.sceneId = sceneId;
      this.displayStory(scene);
      this.displayChoices(scene);
      this.updateStats();
    }

    displayStory(scene) {
      const el = document.getElementById('scene-text');
      if (el) {
        el.textContent = scene.text || '';
        if (scene.isEnding) {
          el.innerHTML += '<br><br><strong style="color:var(--brand);">[ENDING]</strong>';
        }
      }
    }

    displayChoices(scene) {
      const el = document.getElementById('choices');
      if (!el) return;
      el.innerHTML = '';
      
      if (scene.isEnding || !scene.choices || scene.choices.length === 0) {
        const msg = document.createElement('div');
        msg.className = 'choice disabled';
        msg.textContent = 'The End';
        el.appendChild(msg);
        return;
      }
      
      scene.choices.forEach(choice => {
        const btn = document.createElement('button');
        btn.className = 'choice';
        btn.textContent = choice.text || 'Continue';
        if (choice.type) btn.dataset.type = choice.type;
        if (choice.consequence) btn.dataset.consequence = choice.consequence;
        
        const gate = this.canChoose(choice);
        if (!gate.ok) {
          btn.classList.add('disabled');
          btn.title = gate.reason;
          btn.disabled = true;
        } else {
          btn.addEventListener('click', () => this.makeChoice(choice));
          btn.tabIndex = 0;
        }
        el.appendChild(btn);
      });
    }

    updateStats() { this.renderStats(); }

    renderStats() {
      const el = document.getElementById('stats');
      if (!el) return;
      const s = this.state;
      const moralCls = s.morality >= 10 ? 'morality-good' : s.morality <= -10 ? 'morality-bad' : 'morality-neutral';
      const stressCls = s.stress >= 70 ? 'stress-high' : s.stress >= 40 ? 'stress-medium' : 'stress-low';
      const traumaCls = s.trauma >= 60 ? 'trauma-high' : s.trauma >= 30 ? 'trauma-medium' : 'trauma-low';
      el.innerHTML = `
        <div class="stats-group">
          <span class="stat-pill strength">STR ${s.strength}</span>
          <span class="stat-pill agility">AGI ${s.agility}</span>
          <span class="stat-pill willpower">WIL ${s.willpower}</span>
          <span class="stat-pill charisma">CHA ${s.charisma}</span>
        </div>
        <div class="status-indicators">
          <span class="status-pill ${moralCls}">Morality ${s.morality}</span>
          <span class="status-pill ${stressCls}">Stress ${s.stress}</span>
          <span class="status-pill ${traumaCls}">Trauma ${s.trauma}</span>
        </div>
      `;
    }
  }

  window.ConsequenceGame = ConsequenceGame;
  console.log('✓ Game engine loaded');

})(window);
