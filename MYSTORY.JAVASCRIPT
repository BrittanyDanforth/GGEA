// CONSEQUENCE - Game Engine
// This file provides the ConsequenceGame class for the story database

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
        
        // Apply any effects from the choice
        if (choice.effects) {
            this.applyEffects(choice.effects);
        }
        
        // Record in history
        this.state.history.push({
            scene: this.state.currentScene,
            choice: choice.text
        });
        
        // Navigate to next scene
        this.renderScene(choice.goTo);
    }
    
    applyEffects(effects) {
        // Apply stat changes, morality changes, etc.
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
    
    updateStats() {
        this.renderStats();
    }
}

// Global game instance
let gameInstance = null;

// Initialize game when STORY_DATABASE is loaded
function initializeGame() {
    if (typeof STORY_DATABASE !== 'undefined' && !gameInstance) {
        gameInstance = new ConsequenceGame();
        gameInstance.setStoryDatabase(STORY_DATABASE);
        console.log('✓ Game initialized with story database');
        return gameInstance;
    }
    return null;
}

// Auto-initialize if database is already loaded
if (typeof STORY_DATABASE !== 'undefined') {
    initializeGame();
}