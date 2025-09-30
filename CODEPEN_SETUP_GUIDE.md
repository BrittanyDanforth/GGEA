# 🎨 CodePen Setup Guide - CONSEQUENCE Game

## ⚠️ The Problem

CodePen doesn't support:
- Loading local files with `<script src="FINAL_STORY.json">`
- Multiple separate JavaScript files
- File system access

**Your error:** `STORY_DATABASE is not defined` at line 436

This happens because CodePen can't load your `FINAL_STORY.json` file.

---

## ✅ Solution: Host the JSON File

You have 3 options:

### **Option 1: Use GitHub (Recommended)**

1. **Upload `FINAL_STORY.json` to GitHub:**
   - Create a new repository
   - Upload `FINAL_STORY.json`
   - Get the raw file URL

2. **Load it in CodePen:**
   ```javascript
   // In your JS panel, at the very top:
   fetch('https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/FINAL_STORY.json')
     .then(response => response.text())
     .then(text => {
       // Execute the JavaScript (it defines STORY_DATABASE)
       eval(text);
       
       // Now initialize your game
       if (typeof initializeGame === 'function') {
         initializeGame();
       }
     })
     .catch(error => {
       console.error('Failed to load story database:', error);
     });
   ```

### **Option 2: Use jsDelivr CDN**

Same as Option 1, but use jsDelivr's CDN:
```javascript
fetch('https://cdn.jsdelivr.net/gh/YOUR_USERNAME/YOUR_REPO@main/FINAL_STORY.json')
  .then(response => response.text())
  .then(text => {
    eval(text);
    if (typeof initializeGame === 'function') {
      initializeGame();
    }
  });
```

### **Option 3: Embed Inline (Not Recommended - File Too Large)**

Your file is 5.4 MB - CodePen has limits. This won't work well.

---

## 🔧 Quick Fix for CodePen

Here's what to put in each CodePen panel:

### **HTML Panel:**
```html
<div id="game-container">
  <header class="game-header">
    <h1>CONSEQUENCE</h1>
    <p class="game-subtitle">Every choice has consequences</p>
  </header>
  
  <div id="loading-screen">
    <h2>Loading story database...</h2>
    <p>Please wait while we load 2159 scenes...</p>
  </div>
  
  <div id="game-interface" class="hidden">
    <div class="status-bar" id="stats"></div>
    <div class="game-content">
      <div class="story-section">
        <div class="story-display" id="scene-text"></div>
        <div class="choices-display" id="choices"></div>
      </div>
    </div>
  </div>
</div>
```

### **CSS Panel:**
```css
/* Copy the entire contents of MYSTORY.CSS here */
/* Or link to it if hosted online */
```

### **JS Panel:**
```javascript
// STEP 1: Load the story database from external URL
let STORY_DATABASE = null;

fetch('YOUR_HOSTED_URL_HERE/FINAL_STORY.json')
  .then(response => {
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.text();
  })
  .then(text => {
    // Execute the JavaScript (defines STORY_DATABASE)
    eval(text);
    
    console.log('✓ Story database loaded:', Object.keys(STORY_DATABASE).length, 'scenes');
    
    // Hide loading screen
    document.getElementById('loading-screen').classList.add('hidden');
    document.getElementById('game-interface').classList.remove('hidden');
    
    // Initialize game
    initializeGame();
  })
  .catch(error => {
    console.error('Error loading story database:', error);
    document.getElementById('loading-screen').innerHTML = `
      <h2 style="color: red;">Error Loading Story</h2>
      <p>${error.message}</p>
      <p>Please check the console for details.</p>
    `;
  });

// STEP 2: Game Engine (from MYSTORY.JAVASCRIPT)
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
      history: []
    };
    
    this.storyDatabase = null;
  }
  
  setStoryDatabase(database) {
    this.storyDatabase = database;
  }
  
  renderScene(sceneId) {
    if (!this.storyDatabase) {
      console.error('Story database not loaded');
      return;
    }
    
    const scene = this.storyDatabase[sceneId];
    if (!scene) {
      console.error(`Scene not found: ${sceneId}`);
      return;
    }
    
    this.state.currentScene = sceneId;
    this.displayStory(scene);
    this.displayChoices(scene);
  }
  
  displayStory(scene) {
    const storyElement = document.getElementById('scene-text');
    if (storyElement && scene.text) {
      storyElement.innerHTML = scene.text;
    }
  }
  
  displayChoices(scene) {
    const choicesElement = document.getElementById('choices');
    if (!choicesElement) return;
    
    choicesElement.innerHTML = '';
    
    if (!scene.choices || scene.choices.length === 0) {
      choicesElement.innerHTML = '<p>End of story</p>';
      return;
    }
    
    scene.choices.forEach((choice, index) => {
      const button = document.createElement('button');
      button.className = 'choice';
      button.textContent = choice.text || `Choice ${index + 1}`;
      button.onclick = () => this.makeChoice(choice);
      choicesElement.appendChild(button);
    });
  }
  
  makeChoice(choice) {
    if (!choice.goTo) {
      console.error('Choice has no destination');
      return;
    }
    
    if (choice.effects) {
      this.applyEffects(choice.effects);
    }
    
    this.state.history.push({
      scene: this.state.currentScene,
      choice: choice.text
    });
    
    this.renderScene(choice.goTo);
  }
  
  applyEffects(effects) {
    if (effects.stats) {
      Object.assign(this.state.stats, effects.stats);
    }
    if (effects.morality !== undefined) {
      this.state.morality += effects.morality;
    }
    if (effects.trauma !== undefined) {
      this.state.trauma += effects.trauma;
    }
    this.renderStats();
  }
  
  renderStats() {
    const statsElement = document.getElementById('stats');
    if (!statsElement) return;
    
    statsElement.innerHTML = `
      <div>Name: ${this.state.characterName}</div>
      <div>STR: ${this.state.stats.strength} | AGI: ${this.state.stats.agility} | WIL: ${this.state.stats.willpower} | CHA: ${this.state.stats.charisma}</div>
      <div>Morality: ${this.state.morality} | Trauma: ${this.state.trauma}</div>
    `;
  }
}

// STEP 3: Initialize game when database is loaded
let gameInstance = null;

function initializeGame() {
  if (typeof STORY_DATABASE !== 'undefined' && STORY_DATABASE !== null) {
    gameInstance = new ConsequenceGame();
    gameInstance.setStoryDatabase(STORY_DATABASE);
    gameInstance.renderStats();
    gameInstance.renderScene('intro');
    console.log('✓ Game initialized!');
  } else {
    console.error('Cannot initialize - STORY_DATABASE not loaded');
  }
}
```

---

## 🌐 How to Host Your JSON File

### **GitHub (Free & Easy):**

1. Go to https://github.com
2. Create account (if needed)
3. Click "New repository"
4. Upload `FINAL_STORY.json`
5. Click on the file
6. Click "Raw" button
7. Copy the URL

**Example URL:**
```
https://raw.githubusercontent.com/username/repo/main/FINAL_STORY.json
```

### **Alternative Hosts:**

- **Gist:** https://gist.github.com (for single files)
- **Netlify Drop:** https://app.netlify.com/drop (drag & drop)
- **Cloudflare Pages:** https://pages.cloudflare.com
- **Your own server:** If you have hosting

---

## ⚡ Quick Test URL

For testing, you can use this temporary approach:

```javascript
// This won't work for 5.4MB file, but shows the concept:
const STORY_DATABASE_URL = 'YOUR_URL_HERE';

fetch(STORY_DATABASE_URL)
  .then(r => r.text())
  .then(text => {
    eval(text);
    initializeGame();
  });
```

---

## 🐛 Troubleshooting CodePen

### Error: "STORY_DATABASE is not defined"
- ✅ Make sure fetch completes before running other code
- ✅ Check the URL is correct
- ✅ Check browser console for CORS errors
- ✅ Verify the file loaded: `console.log(STORY_DATABASE)`

### CORS Errors
- ✅ Use GitHub raw URL or jsDelivr
- ✅ Don't use Dropbox/Google Drive direct links (they have CORS issues)

### File Too Large
- ✅ CodePen has limits on external resources
- ✅ Consider splitting your story into smaller chunks
- ✅ Or use a CDN like jsDelivr (no size limits)

---

## 📋 CodePen Settings

In CodePen settings, add:

**JS External Libraries:**
- None needed (everything is self-contained)

**Behavior:**
- Auto-save: ON
- Auto-update preview: OFF (your file is large)

---

## 🎯 Step-by-Step Checklist

- [ ] Upload `FINAL_STORY.json` to GitHub
- [ ] Get the raw file URL
- [ ] Paste entire `MYSTORY.CSS` into CSS panel
- [ ] Paste game HTML into HTML panel
- [ ] Paste game engine into JS panel
- [ ] Replace `YOUR_HOSTED_URL_HERE` with actual URL
- [ ] Save and test
- [ ] Check console for "Story database loaded" message

---

## 💡 Alternative: Use CodePen Assets (Pro)

If you have CodePen Pro:
1. Go to Settings → Assets
2. Upload `FINAL_STORY.json`
3. CodePen will give you a URL
4. Use that URL in your fetch

---

**The key issue: CodePen can't access local files. You MUST host `FINAL_STORY.json` somewhere accessible via HTTP.**
