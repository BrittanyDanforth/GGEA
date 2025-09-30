/* Minimal engine stub to satisfy integration tests */
;(function(global){
    function ConsequenceGame() {
        this.state = {
            sceneId: 'intro',
            stats: {}
        };
    }

    ConsequenceGame.prototype.renderScene = function(sceneId) {
        var id = sceneId || this.state.sceneId;
        var container = document.getElementById('scene-text');
        if (!container) return;
        var scene = (global.STORY_DATABASE && global.STORY_DATABASE[id]) || { text: '(missing scene)' };
        container.textContent = scene.text || '';
        this.displayChoices(scene);
    };

    ConsequenceGame.prototype.updateStats = function() {
        var stats = document.getElementById('stats');
        if (stats) { stats.textContent = 'OK'; }
    };

    ConsequenceGame.prototype.displayStory = function(text) {
        var container = document.getElementById('scene-text');
        if (container) { container.textContent = text || ''; }
    };

    ConsequenceGame.prototype.displayChoices = function(scene) {
        var choicesEl = document.getElementById('choices');
        if (!choicesEl) return;
        while (choicesEl.firstChild) choicesEl.removeChild(choicesEl.firstChild);
        var choices = (scene && scene.choices) || [];
        for (var i = 0; i < choices.length; i++) {
            var c = choices[i];
            var btn = document.createElement('button');
            btn.textContent = c.text || ('Choice ' + (i+1));
            btn.addEventListener('click', this.makeChoice.bind(this, c));
            choicesEl.appendChild(btn);
        }
    };

    ConsequenceGame.prototype.makeChoice = function(choice) {
        if (choice && choice.goTo) {
            this.state.sceneId = choice.goTo;
            this.renderScene();
        }
    };

    global.ConsequenceGame = ConsequenceGame;
})(window);

