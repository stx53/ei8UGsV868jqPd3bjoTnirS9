// Global state variables
let menuVisible = false;
let currentLobbies = {};
let selectedLobbyForJoin = null;
let playerIdentifier = null;
let selectedMapForCreation = null;
let currentLobbyId = null; // Track current lobby ID

/**
 * Sends a POST request to a FiveM NUI callback.
 * @param {string} eventName - The name of the NUI callback event.
 * @param {object} data - The data to send in the request body.
 * @returns {Promise<any>} - The JSON response from the callback.
 */
async function post(eventName, data = {}) {
    try {
        const response = await fetch(`https://ali_ffa/${eventName}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        });
        return await response.json();
    } catch (error) {
        // console.error(`NUI Post Error for ${eventName}:`, error);
        return null;
    }
}

/**
 * Renders all available lobbies, distinguishing between public and private.
 * @param {Array<object>} lobbies - The list of lobby objects.
 * @param {string} localPlayerIdentifier - The identifier of the local player.
 */
function renderAllLobbies(lobbies, localPlayerIdentifier) {
    if (localPlayerIdentifier) {
        playerIdentifier = localPlayerIdentifier;
    }
    
    // Update current lobby ID if in a lobby
    const inLobby = document.body.classList.contains('in-lobby');
    const lobbyActions = document.getElementById('lobby-actions');
    lobbyActions.classList.toggle('hidden', !inLobby);

    const publicGrid = document.getElementById('public-lobby-grid');
    const privateGrid = document.getElementById('private-lobby-grid');
    const privateHeader = document.getElementById('private-lobbies-header');

    publicGrid.innerHTML = '';
    privateGrid.innerHTML = '';
    let privateLobbiesExist = false;
    currentLobbies = {};

    if (!lobbies) return;

    lobbies.forEach(lobby => {
        currentLobbies[lobby.id] = lobby;
        const grid = lobby.isPrivate ? privateGrid : publicGrid;
        if (lobby.isPrivate) privateLobbiesExist = true;

        const lobbyCard = document.createElement('div');
        lobbyCard.className = 'lobby-card';

        let closeButtonHTML = '';
        if (lobby.isPrivate && lobby.owner === playerIdentifier) {
            closeButtonHTML = `<button class="close-lobby-btn">LOBBY SCHLIESSEN</button>`;
        }

        lobbyCard.innerHTML = `
            <div class="card-image" style="background-image: url('${lobby.image}');"></div>
            <div class="card-title">${lobby.name.toUpperCase()}</div>
            ${closeButtonHTML}
        `;

        lobbyCard.addEventListener('click', (e) => {
            if (e.target.classList.contains('close-lobby-btn')) return;
            handleLobbyClick(lobby.id);
        });

        if (closeButtonHTML) {
            lobbyCard.querySelector('.close-lobby-btn').addEventListener('click', (e) => {
                e.stopPropagation();
                post('closeLobby', { id: lobby.id });
            });
        }

        grid.appendChild(lobbyCard);
    });

    privateHeader.classList.toggle('hidden', !privateLobbiesExist);
}

/**
 * Renders the selection of base maps for creating a new private lobby.
 * @param {Array<object>} baseMaps - The list of public lobbies to use as templates.
 */
function renderMapSelection(baseMaps) {
    const mapGrid = document.getElementById('map-selection-grid');
    mapGrid.innerHTML = '';
    if (!baseMaps) return;

    baseMaps.forEach(map => {
        const card = document.createElement('div');
        card.className = 'lobby-card';
        card.innerHTML = `
            <div class="card-image" style="background-image: url('${map.image}');"></div>
            <div class="card-title">${map.name.toUpperCase()}</div>
        `;
        card.addEventListener('click', () => {
            selectedMapForCreation = map.id;
            document.getElementById('map-selection').classList.add('hidden');
            document.getElementById('lobby-creation').classList.remove('hidden');
        });
        mapGrid.appendChild(card);
    });
}

/**
 * Handles a click on a lobby card to initiate joining.
 * @param {string} lobbyId - The ID of the clicked lobby.
 */
function showPasswordModal(lobbyId, hasPassword) {
    const modal = document.getElementById('password-modal');
    const passwordInput = document.getElementById('modal-password-input');
    const submitBtn = document.getElementById('modal-submit-btn');
    const cancelBtn = document.getElementById('modal-cancel-btn');
    
    // Reset modal state
    passwordInput.value = '';
    passwordInput.placeholder = hasPassword ? 'PASSWORT EINGEBEN' : 'KEIN PASSWORT ERFORDERLICH';
    passwordInput.disabled = !hasPassword;
    
    // Show modal
    modal.classList.remove('hidden');
    
    // Handle submit
    const handleSubmit = () => {
        const password = passwordInput.value;
        modal.classList.add('hidden');
        post('joinLobby', { lobbyId, password });
        
        // Cleanup
        submitBtn.removeEventListener('click', handleSubmit);
        cancelBtn.removeEventListener('click', handleCancel);
    };
    
    // Handle cancel
    const handleCancel = () => {
        modal.classList.add('hidden');
        
        // Cleanup
        submitBtn.removeEventListener('click', handleSubmit);
        cancelBtn.removeEventListener('click', handleCancel);
    };
    
    // Add event listeners
    submitBtn.addEventListener('click', handleSubmit);
    cancelBtn.addEventListener('click', handleCancel);
    
    // Handle Enter key
    const handleKeyPress = (e) => {
        if (e.key === 'Enter') {
            handleSubmit();
        } else if (e.key === 'Escape') {
            handleCancel();
        }
    };
    
    passwordInput.addEventListener('keydown', handleKeyPress);
    
    // Focus the input
    setTimeout(() => {
        if (hasPassword) {
            passwordInput.focus();
        } else {
            submitBtn.focus();
        }
    }, 100);
}

function handleLobbyClick(lobbyId) {
    const lobby = currentLobbies[lobbyId];
    if (!lobby) return;

    if (lobby.isPrivate) {
        showPasswordModal(lobbyId, lobby.password);
    } else {
        post('joinLobby', { lobbyId, password: '' });
    }
    
    // Update current lobby state
    currentLobbyId = lobbyId;
    document.body.classList.toggle('in-lobby', true);
    
    // Show close button if player is the owner
    const lobbyActions = document.getElementById('lobby-actions');
    lobbyActions.classList.toggle('hidden', lobby.owner !== playerIdentifier);
}

/**
 * Updates the scoreboard with the latest player stats.
 * @param {Array<object>} players - The list of player objects with stats.
 */
function updateScoreboard(players) {
    const container = document.querySelector('.scoreboard-container');
    container.innerHTML = '';

    if (!players || players.length === 0) {
        container.innerHTML = '<p>Noch keine Statistiken vorhanden.</p>';
        return;
    }

    players.forEach(player => {
        const kd = player.deaths === 0 ? player.kills.toFixed(1) : (player.kills / player.deaths).toFixed(1);
        const card = document.createElement('div');
        card.className = 'player-stat-card';
        card.innerHTML = `
            <div class="player-name">${player.name}</div>
            <div class="player-stats">
                <div class="stat-line"><span>Kills:</span><span class="stat-value">${player.kills}</span></div>
                <div class="stat-line"><span>Tode:</span><span class="stat-value">${player.deaths}</span></div>
                <div class="stat-line"><span>KD:</span><span class="stat-value">${kd}</span></div>
            </div>
        `;
        container.appendChild(card);
    });
}

// HUD Functions
let playerStats = {
    kills: 0,
    deaths: 0
};

function updateHUD() {
    try {
        const kills = playerStats.kills || 0;
        const deaths = Math.max(1, playerStats.deaths || 0); // Avoid division by zero
        const kd = (kills / deaths).toFixed(2);
        
        const killsEl = document.getElementById('kills');
        const deathsEl = document.getElementById('deaths');
        const kdEl = document.getElementById('kd-ratio');
        
        if (killsEl) killsEl.textContent = kills;
        if (deathsEl) deathsEl.textContent = deaths;
        if (kdEl) kdEl.textContent = kd;
    } catch (e) {
        console.error('Error updating HUD:', e);
    }
}

function toggleHUD(show) {
    const hud = document.getElementById('ffa-hud');
    if (hud) {
        if (show) {
            hud.classList.remove('hidden');
            updateHUD();
        } else {
            hud.classList.add('hidden');
        }
    }
}

// Initialize HUD when the script loads
document.addEventListener('DOMContentLoaded', () => {
    // Notify game that UI is ready
    fetch(`https://${GetParentResourceName()}/hudReady`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    });
});

// Main event listener for messages from client.lua
window.addEventListener('message', (event) => {
    const { action, ...data } = event.data;
    
    // Verstecke den Lobby-Button standardmäßig
    const lobbyActions = document.getElementById('lobby-actions');
    if (action !== 'enterLobby') {
        lobbyActions.classList.add('hidden');
    }

    switch (action) {
        case 'setVisible':
            menuVisible = data.status;
            document.querySelector('.main-container').style.display = data.status ? 'flex' : 'none';
            break;

        case 'updateLobbies':
            renderAllLobbies(data.lobbies, data.playerIdentifier);
            const baseMaps = data.lobbies ? data.lobbies.filter(l => !l.isPrivate) : [];
            renderMapSelection(baseMaps);
            break;

        case 'showRespawnTimer': {
            const respawnContainer = document.querySelector('.respawn-container');
            respawnContainer.classList.remove('hidden');
            const timerElement = document.getElementById('respawn-timer');
            timerElement.textContent = data.duration;

            let timeLeft = data.duration;
            const timer = setInterval(() => {
                timeLeft--;
                if (timeLeft >= 0) {
                    timerElement.textContent = timeLeft;
                } else {
                    clearInterval(timer);
                }
            }, 1000);
            break;
        }

        case 'hideRespawnTimer':
            document.querySelector('.respawn-container').classList.add('hidden');
            break;

        case 'updateScoreboard':
            updateScoreboard(data.players);
            break;

        case 'updatePlayerStats':
            if (data.kills !== undefined) playerStats.kills = data.kills;
            if (data.deaths !== undefined) playerStats.deaths = data.deaths;
            updateHUD();
            break;

        case 'toggleHUD':
            toggleHUD(data.show);
            break;

        case 'initHUD':
            playerStats = {
                kills: data.kills || 0,
                deaths: data.deaths || 0
            };
            updateHUD();
            if (data.show) {
                toggleHUD(true);
            }
            break;

        case 'lobbyJoined':
            document.body.classList.add('in-lobby');
            currentLobbyId = data.lobbyId;
            updateLobbyUI(true);
            
            // Show lobby actions for the host
            const lobbyActions = document.getElementById('lobby-actions');
            if (lobbyActions) {
                lobbyActions.classList.toggle('hidden', !data.isHost);
            }
            
            // Show HUD when joining a lobby
            toggleHUD(true);
            break;
    }
});

// Setup UI elements and listeners once the DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    const navButtons = document.querySelectorAll('.nav-btn');
    const sections = {
        LOBBYS: document.querySelector('.lobby-section'),
        PRIVATE: document.getElementById('private-section'),
        STATS: document.getElementById('stats-section'),
    };
    const lobbyCreationView = document.getElementById('lobby-creation');
    const mapSelectionView = document.getElementById('map-selection');
    const createLobbyBtn = document.getElementById('create-lobby-btn');
    const passwordModal = document.getElementById('password-modal');

    function switchView(view) {
        Object.values(sections).forEach(section => section.classList.add('hidden'));
        navButtons.forEach(btn => btn.classList.remove('active'));

        sections[view].classList.remove('hidden');
        document.querySelector(`.nav-btn[data-view='${view}']`).classList.add('active');

        if (view === 'PRIVATE') {
            lobbyCreationView.classList.add('hidden');
            mapSelectionView.classList.remove('hidden');
        }
    }

    navButtons.forEach(button => {
        button.addEventListener('click', () => switchView(button.dataset.view));
    });

    createLobbyBtn.addEventListener('click', () => {
        const lobbyNameInput = document.getElementById('lobby-name');
        const passwordInput = document.getElementById('lobby-password');
        const lobbyName = lobbyNameInput.value.trim();

        if (lobbyName && selectedMapForCreation) {
            post('createPrivateLobby', {
                lobbyName: lobbyName,
                password: passwordInput.value,
                mapName: selectedMapForCreation
            });
            lobbyNameInput.value = '';
            passwordInput.value = '';
            switchView('LOBBYS');
        }
    });

    document.getElementById('modal-submit-btn').addEventListener('click', () => {
        const password = document.getElementById('modal-password-input').value;
        if (selectedLobbyForJoin) {
            post('joinLobby', { lobbyId: selectedLobbyForJoin.id, password: password });
            passwordModal.classList.add('hidden');
            document.getElementById('modal-password-input').value = '';
        }
    });

    document.getElementById('modal-cancel-btn').addEventListener('click', () => {
        passwordModal.classList.add('hidden');
        document.getElementById('modal-password-input').value = '';
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && menuVisible) {
            post('closeMenu');
        }
    });

    // Event-Listener für den Lobby-Schließen-Button
    const closeLobbyBtn = document.getElementById('close-lobby-btn');
    if (closeLobbyBtn) {
        closeLobbyBtn.addEventListener('click', () => {
            if (currentLobbyId) {
                post('leaveLobby', { lobbyId: currentLobbyId });
                // UI zurücksetzen
                document.body.classList.remove('in-lobby');
                const lobbyActions = document.getElementById('lobby-actions');
                if (lobbyActions) lobbyActions.classList.add('hidden');
                currentLobbyId = null;
            }
        });
    }

    switchView('LOBBYS'); // Set initial view
});
