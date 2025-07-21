Config = {}

Config.MainBlip = {
    coords = vector3(-116.3269, -604.6104, 36.2807), 
    sprite = 119, 
    color = 1,    
    scale = 0.7,
    text = "FFA Lobby"
}

Config.QuitLocation = vector3(-116.3269, -604.6104, 37.2807)

Config.Lobbies = {
    ['Lobby1'] = {
        name = "Santa Berg", 
        image = "https://cdn.discordapp.com/attachments/1383241955718201354/1388050890229022742/New_Project_1.png?ex=685f92a0&is=685e4120&hm=8ac927b0433fac9fdfd691c6b26253c19532b042c7b4ef016a5006c6398263d6&", 
        dimension = 1, 

        boundary = {
            center = vector3(545.5117, 3364.7263, 100.0558), 
            radius = 100.0, 
            color = { r = 0, g = 0, b = 0, a = 100 } 
        },

        spawnpoints = { 
            vector3(510.5128, 3329.8462, 89.7224),
            vector3(1600.2755, 2400.8835, 45.8682),
            vector3(623.3915, 3304.3857, 69.9453),
        },

        weapons = { 
            { name = 'WEAPON_PISTOL', ammo = 100 },
            { name = 'WEAPON_CARBINERIFLE', ammo = 250 },
        }
    },

    ['Lobby2'] = {
        name = "Hafen",
        image = "http",
        dimension = 2,

        boundary = {
            center = vector3(-255.0, -1805.0, 25.0), 
            radius = 100.0, 
            color = { r = 0, g = 0, b = 0, a = 100 } 
        },

        spawnpoints = {
            vector3(-250.0, -1800.0, 25.0),
            vector3(-260.0, -1810.0, 25.5),
        },

        weapons = {
            { name = 'WEAPON_SMG', ammo = 200 },
            { name = 'WEAPON_PUMPSHOTGUN', ammo = 50 },
        }
    },
   
    ['Lobby3'] = {
        name = "Flughafen", 
        image = "https://cdn.discordapp.com/attachments/1383241955718201354/1388050890229022742/New_Project_1.png?ex=685f92a0&is=685e4120&hm=8ac927b0433fac9fdfd691c6b26253c19532b042c7b4ef016a5006c6398263d6&", 
        dimension = 1, 

        boundary = {
            center = vector3( 1253.1527, 3091.3484, 41.9557), 
            radius = 80.0, 
            color = { r = 0, g = 0, b = 0, a = 100 } 
        },

        spawnpoints = { 
            vector3( 1178.5215, 3098.6638, 40.4892),
            vector3( 1292.5405, 3145.9956, 40.4169),
            vector3( 1287.4513, 3057.3208, 40.5342),
            vector3( 1236.8850, 3091.2170, 41.0070),
            vector3( 1320.4869, 3111.8923, 40.9070),
        },

        weapons = { 
            { name = 'WEAPON_PISTOL', ammo = 999 },
            { name = 'WEAPON_PISTOL_mk2', ammo = 999 },
            { name = 'WEAPON_PISTOL50', ammo = 999 },
        }
    },
}
