
let currentAreas = [];
let currentQueueState = {};
let activeWars = {};
let playerFaction = null;
let factionLogos = {};
let warTimerInterval = null;

function updateBodyVisibility() {
    const container = document.querySelector('.container');
    const hud = document.querySelector('.war-hud');
    const isContainerVisible = container && container.style.display !== 'none';
    const isHudVisible = hud && hud.style.display !== 'none';

    if (isContainerVisible || isHudVisible) {
        document.body.style.display = 'flex';
    } else {
        document.body.style.display = 'none';
    }
}

document.addEventListener('DOMContentLoaded', () => {
    const container = document.querySelector('.container');
    if(container) container.style.display = 'none';
    updateBodyVisibility();
    const tabs = document.querySelectorAll('.tab');
    const tabContents = document.querySelectorAll('.tab-content');

    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            tabs.forEach(item => item.classList.remove('active'));
            tabContents.forEach(item => item.classList.remove('active'));

            tab.classList.add('active');
            const target = document.getElementById(tab.dataset.tab);
            if (target) {
                target.classList.add('active');
            }
        });
    });

    document.addEventListener('keyup', (e) => {
        if (e.key === 'Escape') {
            fetch(`https://ali_gw/close`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({})
            });
        }
    });
});

function displayFactionStats(factions) {
    const factionList = document.getElementById('faction-stats-list');
    factionList.innerHTML = '';

    if (!factions || factions.length === 0) {
        factionList.innerHTML = '<p>Keine Fraktionsstatistiken verfügbar.</p>';
        return;
    }

    factions.forEach((faction, index) => {
        const statRow = document.createElement('div');
        statRow.className = 'stat-row';
        statRow.innerHTML = `
            <span class="rank">#${index + 1}</span>
            <span class="name">${faction.label.toUpperCase()}</span>
            <span class="wins">WINS <strong>${faction.wins}</strong></span>
            <span class="loses">LOSES <strong>${faction.losses}</strong></span>
        `;
        factionList.appendChild(statRow);
    });
}

function displayPlayerStats(players) {
    const playerList = document.getElementById('player-stats-list');
    playerList.innerHTML = '';  

    if (!players || players.length === 0) {
        playerList.innerHTML = '<p>Keine Spielerstatistiken verfügbar.</p>';
        return;
    }

    players.forEach((player, index) => {
        const statRow = document.createElement('div');
        statRow.className = 'stat-row';
        statRow.innerHTML = `
            <span class="rank">#${index + 1}</span>
            <span class="name">${player.name ? player.name.toUpperCase() : 'UNBEKANNT'}</span>
            <span class="kills">KILLS <strong>${player.kills}</strong></span>
            <span class="tode">TODE <strong>${player.deaths}</strong></span>
            <span class="kd">K/D <strong>${player.kd}</strong></span>
        `;
        playerList.appendChild(statRow);
    });
}

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.type === 'ui' && data.status) {
        
        currentAreas = data.areas;
        currentQueueState = data.queueState;
        activeWars = data.activeWars;
        playerFaction = data.playerFaction;
        factionLogos = data.factionLogos;

        document.querySelector('.container').style.display = 'flex';
        renderFights(currentAreas, currentQueueState, activeWars, playerFaction, factionLogos);
        updateShopItems(data.shopItems);

        if (data.stats) {
            displayFactionStats(data.stats.topFactions);
            displayPlayerStats(data.stats.topPlayers);
            updateGangwarOverview(data.stats.overview);
        }

        updateBodyVisibility();

    } else if (data.type === 'ui' && !data.status) {
        document.querySelector('.container').style.display = 'none';
        updateBodyVisibility();

    } else if (data.type === 'stateUpdate') {
        currentQueueState = data.queueState;
        activeWars = data.activeWars;
        factionLogos = data.factionLogos;
        renderFights(currentAreas, currentQueueState, activeWars, playerFaction, factionLogos);
        updateWarHUD(data.activeWars);

    } else if (data.action === 'hideWarHud') {
        const hud = document.querySelector('.war-hud');
        if (hud) hud.style.display = 'none';
        if (warTimerInterval) {
            clearInterval(warTimerInterval);
            warTimerInterval = null;
        }
        updateBodyVisibility();
    }
});

function updateGangwarOverview(overview) {
    if (!overview) return;
    document.querySelectorAll('.gangwar-stats').forEach(container => {
        const pElems = container.querySelectorAll('p');
        if (pElems.length >= 3) {
            pElems[0].textContent = `GANGWAR: ${overview.gangwars}`;
            pElems[1].textContent = `PUNKTE: ${overview.points}`;
            pElems[2].textContent = `PLATZIERUNG: #${overview.rank}`;
        }
    });

    const rwGw = document.getElementById('rw-gw');
    const rwPts = document.getElementById('rw-points');
    const rwRank = document.getElementById('rw-rank');
    if (rwGw) rwGw.textContent = `GANGWAR: ${overview.gangwars}`;
    if (rwPts) rwPts.textContent = `PUNKTE: ${overview.points}`;
    if (rwRank) rwRank.textContent = `PLATZIERUNG: #${overview.rank}`;
}

window.addEventListener('message', function(event) {
    const item = event.data;
    const container = document.querySelector('.container');

    switch (item.type) {
        case 'ui':
            if (item.status) {
                currentAreas = item.areas || [];
                currentQueueState = item.queueState || {};
                activeWars = item.activeWars || {};
                factionLogos = item.factionLogos || {};
                playerFaction = item.playerFaction || null;
                if(container) container.style.display = 'block';

                renderFights(currentAreas, currentQueueState, activeWars, playerFaction, factionLogos);
                updateShopItems(item.shopItems);
                updateWarHUD(activeWars);
            } else {
                if(container) container.style.display = 'none';
            }
            updateBodyVisibility();
            break;

        case 'stateUpdate':
            currentQueueState = item.queueState || {};
            activeWars = item.activeWars || {};
            factionLogos = item.factionLogos || {};
            
            renderFights(currentAreas, currentQueueState, activeWars, playerFaction, factionLogos);
            updateWarHUD(activeWars);
            break;

        case 'updateShop':
            updateShopItems(item.shopItems);
            break;

        case 'showStats':
            if (item.stats) {
                if (item.stats.overview) {
                    updateGangwarOverview(item.stats.overview);
                }
                displayFactionStats(item.stats.factions);
                displayPlayerStats(item.stats.players);
            }
            break;
    }
});

function createFightCardHTML(area, f1_display, f2_display, btnText, btnDisabled) {
    return `
        <h3>${area.name.toUpperCase()}</h3>
        <div class="waiting-queue">
            <div class="faction-slot">
                ${f1_display}
            </div>
            <span class="vs-text">VS</span>
            <div class="faction-slot">
                ${f2_display}
            </div>
        </div>
        <p>Drücke auf den Knopf um teilzunehmen.</p>
        <button class="btn-wait" data-zone-name="${area.name}" ${btnDisabled}>${btnText}</button>
    `;
}

function getFactionDisplayHTML(factionName, logos) {
    const logoUrl = logos[factionName];
    const displayCircleContent = logoUrl
        ? `<img src="${logoUrl}" alt="${factionName} Logo">`
        : factionName.charAt(0).toUpperCase();

    return `<div class="faction-circle">${displayCircleContent}</div><div class="faction-name">${factionName}</div>`;
}


function renderFights(areas, queueState, activeWars, playerFaction, logos) {
    const grid = document.querySelector('#gangwar .fights-grid');
    if (!grid) return;
    grid.innerHTML = '';

    if (!areas || areas.length === 0) {
        grid.innerHTML = '<p>Keine Gangwar-Gebiete konfiguriert.</p>';
        return;
    }

    const frei_slot = '<div class="faction-circle">-</div><div class="faction-name">FREI</div>';
    const q_slot = '<div class="faction-circle">???</div><div class="faction-name">???</div>';

    areas.forEach(area => {
        const war = activeWars[area.name];
        const waitingFactions = queueState[area.name] || [];
        const isPlayerInQueue = playerFaction && waitingFactions.includes(playerFaction);

        let f1_display, f2_display, btnText, btnDisabled;

        if (war) {
            f1_display = getFactionDisplayHTML(war.defender, logos);
            f2_display = getFactionDisplayHTML(war.attacker, logos);
            btnText = 'GW LÄUFT';
            btnDisabled = 'disabled';
        } else if (waitingFactions.length === 1) {
            const waitingFactionName = waitingFactions[0];
            if (isPlayerInQueue) {
                f1_display = '<div class="faction-circle waiting-self"><i class="fas fa-check"></i></div><div class="faction-name">' + waitingFactionName + '</div>';
                btnText = 'WARTEND';
                btnDisabled = 'disabled';
            } else {
                f1_display = q_slot;
                btnText = 'ANGREIFEN';
                btnDisabled = '';
            }
            f2_display = q_slot;
        } else {
            f1_display = frei_slot;
            f2_display = frei_slot;
            btnText = 'WARTEN';
            btnDisabled = '';
        }

        const card = document.createElement('div');
        card.className = 'fight-card';
        card.style.background = `linear-gradient(#3a523dd7, #2a3f2dce), url('${area.image}')`;
        card.style.backgroundSize = 'cover';
        card.style.backgroundPosition = 'center';
        card.innerHTML = createFightCardHTML(area, f1_display, f2_display, btnText, btnDisabled);
        grid.appendChild(card);
    });
    
    document.querySelectorAll('.btn-wait').forEach(button => {
        button.addEventListener('click', (e) => {
            if (button.disabled) return;
            e.preventDefault();
            e.stopPropagation();
            const zoneName = button.dataset.zoneName;
            if (zoneName) {
                fetch(`https://ali_gw/startGwRequest`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                    body: JSON.stringify({ zoneName: zoneName })
                });
            }
        });
    });
}


function updateShopItems(shopItems) {
    const grid = document.querySelector('#rewards .rewards-grid');
    if (!grid) return;
    grid.innerHTML = ''; 

    if (!shopItems || shopItems.length === 0) {
        grid.innerHTML = '<p>Der Shop ist derzeit leer.</p>';
        return;
    }

    shopItems.forEach(item => {
        const card = document.createElement('div');
        card.className = 'reward-card';
        card.innerHTML = `
            <img src="${item.icon}" alt="${item.name}" class="reward-icon">
            <h3>${item.name.toUpperCase()}</h3>
            <p>${item.points} POINTS</p>
            <button class="btn-buy" data-item-name="${item.item}">KAUFEN</button>
        `;
        grid.appendChild(card);
    });

    document.querySelectorAll('.btn-buy').forEach(button => {
        button.addEventListener('click', (e) => {
            const itemName = e.target.dataset.itemName;
            fetch(`https://ali_gw/buyShopItem`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ item: itemName })
            });
        });
    });
}


function updateWarHUD(activeWars) {
    const hud = document.querySelector('.war-hud');
    if (!hud) { 
        updateBodyVisibility(); 
        return; 
    }

    if (warTimerInterval) {
        clearInterval(warTimerInterval);
        warTimerInterval = null;
    }
    const war = Object.keys(activeWars).length > 0 ? Object.values(activeWars)[0] : null;

    if (war && war.defender && war.attacker) {
        document.getElementById('hud-f1-name').textContent = war.defender.toUpperCase();
        document.getElementById('hud-f1-count').textContent = war.defenderCount;
        document.getElementById('hud-f2-name').textContent = war.attacker.toUpperCase();
        document.getElementById('hud-f2-count').textContent = war.attackerCount;

        const f1_logo_elem = document.getElementById('hud-f1-logo');
        const f2_logo_elem = document.getElementById('hud-f2-logo');

        if (f1_logo_elem && factionLogos && factionLogos[war.defender]) {
            f1_logo_elem.src = factionLogos[war.defender];
            f1_logo_elem.style.display = 'block';
        } else if (f1_logo_elem) {
            f1_logo_elem.style.display = 'none';
        }

        if (f2_logo_elem && factionLogos && factionLogos[war.attacker]) {
            f2_logo_elem.src = factionLogos[war.attacker];
            f2_logo_elem.style.display = 'block';
        } else if (f2_logo_elem) {
            f2_logo_elem.style.display = 'none';
        }

        const f1_progress = document.getElementById('hud-f1-progress');
        const f2_progress = document.getElementById('hud-f2-progress');

        if (f1_progress && f2_progress) {
            const initialDefenderCount = war.initialDefenderCount || war.defenderCount;
            const initialAttackerCount = war.initialAttackerCount || war.attackerCount;

            const defenderHealthPercent = initialDefenderCount > 0 ? (war.defenderCount / initialDefenderCount) * 100 : 0;
            const attackerHealthPercent = initialAttackerCount > 0 ? (war.attackerCount / initialAttackerCount) * 100 : 0;
            
            f1_progress.style.width = `${defenderHealthPercent}%`;
            f2_progress.style.width = `${attackerHealthPercent}%`;
        }

        let remainingTime = war.remainingTime; 
        const timerElement = document.getElementById('hud-timer');

        const formatTime = (seconds) => {
            const minutes = Math.floor(seconds / 60);
            const secs = seconds % 60;
            return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
        };

        timerElement.textContent = formatTime(remainingTime);
        warTimerInterval = setInterval(() => {
            remainingTime--;
            if (remainingTime >= 0) {
                timerElement.textContent = formatTime(remainingTime);
            } else {
                clearInterval(warTimerInterval);
                warTimerInterval = null;
            }
        }, 1000);

        hud.style.display = 'flex'; 
    } else {
        hud.style.display = 'none'; 
    }
    updateBodyVisibility(); 
}
