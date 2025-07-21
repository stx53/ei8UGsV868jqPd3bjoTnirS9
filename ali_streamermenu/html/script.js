const container = document.querySelector('.container');

window.addEventListener('message', (event) => {
    const data = event.data;
    
    if (data.type === 'ui') {
        container.style.display = data.status ? 'flex' : 'none';
        
        if (data.status) {
            if (data.jobs) {
                displayJobs(data.jobs);
            }
            const playersGrid = document.getElementById('playersGrid');
            if (playersGrid) {
                playersGrid.innerHTML = `
                    <div class="empty-state">
                        <i class="fas fa-users"></i>
                        <h3>Keine Fraktion ausgewählt</h3>
                        <p>Klicke auf eine Fraktion, um die Spieler zu sehen</p>
                    </div>
                `;
            }
        }
    } else if (data.type === 'updatePlayers') {
        displayPlayers(data.players);
    }
});

function displayJobs(jobs) {
    const jobsList = document.getElementById('jobsList');
    if (!jobsList) return;
    
    jobsList.innerHTML = '';
    
    const sortedJobs = Object.entries(jobs)
        .sort(([jobA], [jobB]) => jobA.localeCompare(jobB));
    
    sortedJobs.forEach(([job, count]) => {
        const jobElement = document.createElement('div');
        jobElement.className = 'fraktion-item';
        jobElement.dataset.job = job;
        
        jobElement.innerHTML = `
            <div class="fraktion-header">
                <span class="fraktion-name">${formatJobName(job)}</span>
                <div class="player-count">
                    <span class="count-number">${count}</span>
                    <span class="online-indicator"></span>
                </div>
            </div>
        `;
        
        jobElement.addEventListener('click', () => {
            document.querySelectorAll('.fraktion-item').forEach(item => {
                item.classList.remove('selected');
            });
            jobElement.classList.add('selected');
            
            fetch(`https://${GetParentResourceName()}/selectJob`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ job: job })
            });
        });
        
        jobsList.appendChild(jobElement);
    });
}

function formatJobName(job) {
    const jobNames = {
        'police': 'LSPD',
        'ambulance': 'EMS',
        'mechanic': 'MECHANIC'
    };
    return jobNames[job.toLowerCase()] || job.toUpperCase();
}

function displayPlayers(players) {
    const playersGrid = document.getElementById('playersGrid');
    if (!playersGrid) return;

    playersGrid.innerHTML = '';

    if (!players || players.length === 0) {
        playersGrid.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-user-slash"></i>
                <h3>Keine Spieler Online</h3>
                <p>In dieser Fraktion sind derzeit keine Spieler online.</p>
            </div>
        `;
        return;
    }

    players.forEach(player => {
        const playerCard = document.createElement('div');
        playerCard.className = 'player-card';
        playerCard.dataset.id = player.id;

        playerCard.innerHTML = `
            <div class="player-header">
                <div class="player-info">
                    <i class="fas fa-user-circle player-avatar"></i>
                    <div>
                        <span class="player-name">${player.name}</span>
                        <span class="player-id">[ID: ${player.id}]</span>
                    </div>
                </div>
                <div class="player-actions">
                    <button class="action-btn teleport-btn" title="Zum Spieler teleportieren">
                        <i class="fas fa-map-marker-alt"></i>
                    </button>
                </div>
            </div>
            <div class="player-stats">
                <div class="stat">
                    <div class="stat-info">
                        <i class="fas fa-heartbeat stat-icon"></i>
                        <span class="stat-label">Leben</span>
                    </div>
                    <div class="stat-bar-container">
                        <div class="stat-bar health-bar" style="width: ${((player.health - 100) / 100) * 100}%;"></div>
                    </div>
                </div>
                <div class="stat">
                    <div class="stat-info">
                        <i class="fas fa-shield-alt stat-icon"></i>
                        <span class="stat-label">Rüstung</span>
                    </div>
                    <div class="stat-bar-container">
                        <div class="stat-bar armor-bar" style="width: ${player.armor}%;"></div>
                    </div>
                </div>
            </div>
        `;

        playerCard.querySelector('.teleport-btn').addEventListener('click', (e) => {
            e.stopPropagation();
            fetch(`https://${GetParentResourceName()}/teleportToPlayer`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ playerId: player.id })
            });
        });

        playersGrid.appendChild(playerCard);
    });
}

window.addEventListener('load', () => {
    document.querySelectorAll('.control-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const control = btn.dataset.control;
            if (control) {
                fetch(`https://${GetParentResourceName()}/performControlAction`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                    body: JSON.stringify({ control: control })
                });
            }
        });
    });
    
    document.addEventListener('keyup', (e) => {
        if (e.key === 'Escape') {
            fetch(`https://${GetParentResourceName()}/close`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({})
            });
        }
    });
});
