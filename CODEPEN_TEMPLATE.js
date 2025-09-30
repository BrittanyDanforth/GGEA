// ============================================
// CONSEQUENCE GAME - CODEPEN VERSION
// ============================================
// INSTRUCTIONS:
// 1. Host FINAL_STORY.json on GitHub or a CDN
// 2. Replace 'YOUR_JSON_URL_HERE' below with the actual URL
// 3. Paste MYSTORY.CSS into the CSS panel
// 4. Create the HTML structure (see CODEPEN_SETUP_GUIDE.md)
// ============================================

// CONFIGURATION - CHANGE THIS!
const STORY_JSON_URL = 'YOUR_JSON_URL_HERE'; // <-- PUT YOUR URL HERE!

// Example URLs (replace with yours):
// 'https://raw.githubusercontent.com/username/repo/main/FINAL_STORY.json'
// 'https://cdn.jsdelivr.net/gh/username/repo@main/FINAL_STORY.json'

// ============================================
// LOADING SYSTEM
// ============================================

let STORY_DATABASE = null;
let gameInstance = null;

// Show loading message
console.log('🔄 Loading CONSEQUENCE story database...');

// Load the story database
fetch(STORY_JSON_URL)
  .then(response => {
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    console.log('📥 Download complete, parsing...');
    return response.text();
  })
  .then(text => {
    // Execute the JavaScript file (it defines STORY_DATABASE)
    console.log('⚙️ Executing story database...');
    eval(text);
    
    // Verify it loaded
    if (typeof STORY_DATABASE === 'undefined' || !STORY_DATABASE) {
      throw new Error('STORY_DATABASE not defined after loading');
    }
    
    const sceneCount = Object.keys(STORY_DATABASE).length;
    console.log(`✅ Story database loaded: ${sceneCount} scenes`);
    
    // Hide loading screen
    const loadingScreen = document.getElementById('loading-screen');
    const gameInterface = document.getElementById('game-interface');
    
    if (loadingScreen) loadingScreen.classList.add('hidden');
    if (gameInterface) gameInterface.classList.remove('hidden');
    
    // Initialize the game
    initializeGame();
  })
  .catch(error => {
    console.error('❌ Failed to load story database:', error);
    
    // Show error to user
    const loadingScreen = document.getElementById('loading-screen');
    if (loadingScreen) {
      loadingScreen.innerHTML = `
        <h2 style="color: #ff4444;">Failed to Load Story</h2>
        <p style="color: #ffaa00;">${error.message}</p>
        <p>Please check:</p>
        <ul style="text-align: left; max-width: 500px; margin: 0 auto;">
          <li>The JSON file URL is correct</li>
          <li>The file is publicly accessible</li>
          <li>Your internet connection is working</li>
          <li>The browser console for more details (F12)</li>
        </ul>
        <p style="margin-top: 20px; color: #666; font-size: 0.8em;">
          Current URL: ${STORY_JSON_URL}
        </p>
      `;
    }
  });

// ============================================
// GAME ENGINE
// ============================================

class ConsequenceGame {
  constructor() {
    this.state = {
      currentScene: 'intro',
      characterName: 'Player',
      stats: {
        strength: 5,
        agility: 5,
        willpower: 5,
        charisma: 5
      },
      morality: 0,
      trauma: 0,
      stress: 0,
      persona: 'neutral',
      inventory: [],
      relationships: {},
      flags: new Set(),
      history: [],
      day: 0,
      hour: 12
    };
    
    this.storyDatabase = null;
  }
  
  setStoryDatabase(database) {
    this.storyDatabase = database;
    console.log('📚 Story database connected to game engine');
  }
  
  renderScene(sceneId) {
    if (!this.storyDatabase) {
      console.error('❌ Story database not loaded');
      return;
    }
    
    const scene = this.storyDatabase[sceneId];
    if (!scene) {
      console.error(`❌ Scene not found: ${sceneId}`);
      return;
    }
    
    console.log(`🎬 Rendering scene: ${sceneId}`);
    this.state.currentScene = sceneId;
    this.displayStory(scene);
    this.displayChoices(scene);
    this.renderStats();
  }
  
  displayStory(scene) {
    const storyElement = document.getElementById('scene-text');
    if (storyElement && scene.text) {
      storyElement.innerHTML = scene.text;
      
      // Scroll to top of story
      storyElement.scrollTop = 0;
    }
  }
  
  displayChoices(scene) {
    const choicesElement = document.getElementById('choices');
    if (!choicesElement) return;
    
    choicesElement.innerHTML = '';
    
    if (!scene.choices || scene.choices.length === 0) {
      choicesElement.innerHTML = '<div class="choice disabled">End of story</div>';
      return;
    }
    
    scene.choices.forEach((choice, index) => {
      const div = document.createElement('div');
      div.className = 'choice';
      div.textContent = choice.text || `Choice ${index + 1}`;
      div.onclick = () => this.makeChoice(choice);
      div.tabIndex = 0;
      
      // Add keyboard support
      div.onkeypress = (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          this.makeChoice(choice);
        }
      };
      
      choicesElement.appendChild(div);
    });
  }
  
  makeChoice(choice) {
    if (!choice.goTo) {
      console.error('❌ Choice has no destination');
      return;
    }
    
    console.log(`➡️ Player chose: ${choice.text}`);
    
    // Apply any effects from the choice
    if (choice.effects) {
      this.applyEffects(choice.effects);
    }
    
    // Record in history
    this.state.history.push({
      scene: this.state.currentScene,
      choice: choice.text,
      timestamp: Date.now()
    });
    
    // Navigate to next scene
    this.renderScene(choice.goTo);
  }
  
  applyEffects(effects) {
    // Apply stat changes
    if (effects.stats) {
      Object.assign(this.state.stats, effects.stats);
    }
    
    // Apply morality changes
    if (effects.morality !== undefined) {
      this.state.morality += effects.morality;
    }
    
    // Apply trauma changes
    if (effects.trauma !== undefined) {
      this.state.trauma += effects.trauma;
    }
    
    // Apply stress changes
    if (effects.stress !== undefined) {
      this.state.stress += effects.stress;
    }
    
    // Apply inventory changes
    if (effects.addItem) {
      this.state.inventory.push(effects.addItem);
    }
    
    // Update display
    this.renderStats();
  }
  
  renderStats() {
    const statsElement = document.getElementById('stats');
    if (!statsElement) return;
    
    const { stats, morality, trauma, stress, characterName, day, hour } = this.state;
    
    statsElement.innerHTML = `
      <div class="stats-group">
        <div class="stat-pill">Name: ${characterName}</div>
        <div class="stat-pill strength">STR: ${stats.strength}</div>
        <div class="stat-pill agility">AGI: ${stats.agility}</div>
        <div class="stat-pill willpower">WIL: ${stats.willpower}</div>
        <div class="stat-pill charisma">CHA: ${stats.charisma}</div>
      </div>
      <div class="status-indicators">
        <div class="status-pill ${morality > 10 ? 'morality-good' : morality < -10 ? 'morality-bad' : 'morality-neutral'}">
          Morality: ${morality}
        </div>
        <div class="status-pill ${trauma > 50 ? 'trauma-high' : trauma > 25 ? 'trauma-medium' : 'trauma-low'}">
          Trauma: ${trauma}
        </div>
        <div class="status-pill ${stress > 50 ? 'stress-high' : stress > 25 ? 'stress-medium' : 'stress-low'}">
          Stress: ${stress}
        </div>
      </div>
    `;
  }
  
  // Save game state to localStorage
  saveGame() {
    try {
      localStorage.setItem('consequence_save', JSON.stringify(this.state));
      console.log('💾 Game saved');
      return true;
    } catch (e) {
      console.error('❌ Failed to save game:', e);
      return false;
    }
  }
  
  // Load game state from localStorage
  loadGame() {
    try {
      const saved = localStorage.getItem('consequence_save');
      if (saved) {
        this.state = JSON.parse(saved);
        this.renderScene(this.state.currentScene);
        console.log('📂 Game loaded');
        return true;
      }
    } catch (e) {
      console.error('❌ Failed to load game:', e);
    }
    return false;
  }
}

// ============================================
// INITIALIZATION
// ============================================

function initializeGame() {
  if (typeof STORY_DATABASE === 'undefined' || !STORY_DATABASE) {
    console.error('❌ Cannot initialize - STORY_DATABASE not loaded');
    return;
  }
  
  console.log('🎮 Initializing game...');
  
  // Create game instance
  gameInstance = new ConsequenceGame();
  gameInstance.setStoryDatabase(STORY_DATABASE);
  
  // Start the game
  gameInstance.renderScene('intro');
  
  console.log('✅ Game ready! Have fun!');
  
  // Make game instance globally accessible for debugging
  window.game = gameInstance;
}

// ============================================
// UTILITY FUNCTIONS
// ============================================

// Debug function - call from console
window.debugGame = function() {
  if (!gameInstance) {
    console.log('❌ Game not initialized');
    return;
  }
  
  console.log('🔍 Game State:', {
    currentScene: gameInstance.state.currentScene,
    stats: gameInstance.state.stats,
    morality: gameInstance.state.morality,
    trauma: gameInstance.state.trauma,
    stress: gameInstance.state.stress,
    inventory: gameInstance.state.inventory,
    choicesMade: gameInstance.state.history.length
  });
};

// Jump to scene - call from console: jumpToScene('scene_id')
window.jumpToScene = function(sceneId) {
  if (!gameInstance) {
    console.log('❌ Game not initialized');
    return;
  }
  
  gameInstance.renderScene(sceneId);
};

console.log('💡 Debug commands available:');
console.log('  - debugGame() - Show current game state');
console.log('  - jumpToScene("scene_id") - Jump to a specific scene');
console.log('  - game.saveGame() - Save current progress');
console.log('  - game.loadGame() - Load saved progress');