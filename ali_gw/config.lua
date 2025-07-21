Config = {}

Config.DiscordLogs = {
    enabled = true, 
    webhooks = {
        warStart =       { enabled = true, url = "https://discord.com/api/webhooks/1390160389467279401/6ScxypAnTJKnNTtNMBYfJS6-2j9nHArcGDSgfpHXvBl01k4BOWPjxHomtzpwCIQ54B2-" }, 
        warEnd =         { enabled = true, url = "https://discord.com/api/webhooks/1390160389467279401/6ScxypAnTJKnNTtNMBYfJS6-2j9nHArcGDSgfpHXvBl01k4BOWPjxHomtzpwCIQ54B2-" }, 
        playerJoin =     { enabled = true, url = "https://discord.com/api/webhooks/1390160465744887928/v8YnmARI2zcgRwI4-qoZzLJ8GWZ7qmyOJkmMUVlWv3XpRifknZAHTqlcPMnscgBvXWLd" }, 
        playerLeave =    { enabled = true, url = "https://discord.com/api/webhooks/1390160599140532275/YROkh30_BMO59aGpa28DuoQSYgGKvHTTSPdm_d6mU1vQBklsWRznVEzwi6a3n4VBdu_a" }, 
        playerEliminated = { enabled = true, url = "https://discord.com/api/webhooks/1390160640810811455/qE8yr0PiFNNrqgCwDli5UroOffOf_MuVT1sZKarxPvXeiQKHCqAbk-jaa-ThWaeKsCsn" }, 
        queueUpdate =    { enabled = false, url = "" },  
        shopPurchase =   { enabled = true, url = "https://discord.com/api/webhooks/1390161565747249173/BH-QtEQdoSfSEi5EP0f6rbGAQchCyVVpjssqTrZuTWvUelJ9Th_1wRmkGxJVwmVLwvrk" } 
    }
}

Config.JoinTime = 15 -- nicht anpacken amk

Config.time = {
    enabled = false, 
    start_hour = 18, 
    end_hour = 23  
}


Config.interactionMarkers = {
    { name = "gitanos", coords = {x = -114.2959, y = 998.8349, z = 235.7572} },
    { name = "police", coords = {x = 472.0773, y = -1019.5769, z = 28.0788} },
}


Config.gwfraks = {
    ['police'] = 13,
    ['gitanos'] = 3
}

Config.FactionColors = {
    ['gitanos'] = {r = 105, g = 60, b = 0},
    ['police'] = {r = 0, g = 102, b = 255},
}

Config.FactionLogos = {
    ['police'] = 'https://iili.io/Hg0h0Ux.png',
    ['gitanos'] = 'https://s1.directupload.eu/images/250704/7zbpxn2h.png'
}



Config.shop = {
    { name = "TEST",   item = "visumup", points = 100,  count = 1,  icon = "https://iili.io/Hg0h0Ux.png" },
    { name = "TEST",   item = "visumup", points = 1000, count = 5,  icon = "https://iili.io/Hg0h0Ux.png" },
    { name = "TEST",  item = "visumup", points = 3000, count = 10, icon = "https://iili.io/Hg0h0Ux.png" },
    { name = "TEST",  item = "visumup", points = 6800, count = 20, icon = "https://iili.io/Hg0h0Ux.png" },
    { name = "TEST",  item = "visumup", points = 6800, count = 30, icon = "https://iili.io/Hg0h0Ux.png" },
    { name = "TEST",  item = "visumup", points = 6800, count = 40, icon = "https://iili.io/Hg0h0Ux.png" },
}


Config.GangwarLoadout = {
    weapons = {
        { name = 'weapon_pistol_mk2', ammo = 250 },
        { name = 'weapon_pistol50', ammo = 250 },
    },
    items = {
        { name = 'pulse-22', count = 3 },
    }
}



---center wird nicht used jungs braucht nichts eingeben

Config.gwgebiete = {
   --[[ {
        name = "STADT",
        image = "https://s1.directupload.eu/images/250703/tl8a6x7o.png",
        duration = 20,
        center = {x = 752.8772, y = -27.0845, z = 81.9829},
        spawns = {
            attacker = {
                {x = 859.2169, y = -94.9679, z = 79.5596, h = 55.2350}

            },
            defender = {
                {x = 611.7250, y = 47.1292, z = 92.3545, h = 247.7998} 
            }
        },
        vehicle_spawns = {
            attacker = { 
                { model = 'schafter3', amount = 6, coords = {x = 830.5408, y = -72.3197, z = 80.6417}, heading = 57.0159 },
                { model = 'schafter3', amount = 6, coords = {x = 826.6835, y = -78.4135, z = 80.6473}, heading = 57.0159 },
                { model = 'schafter6', amount = 1, coords =  {x = 796.3931, y = -54.6944, z = 80.6346}, heading = 57.7218} 
            },
            defender = {
                { model = 'schafter3', amount = 6, coords = {x = 689.2852, y = 5.4526, z = 84.1773}, heading = 237.4312 },
                { model = 'schafter3', amount = 6, coords = {x = 692.2994, y = 10.3339, z = 84.1862}, heading = 237.4312 },
                { model = 'schafter6', amount = 1, coords = {x = 723.4446, y = -12.9121,  z = 83.3520}, heading =  238.6987 } 
            }
        },
    },]]
    {
        name = "PALETO BAY",
        image = "https://s1.directupload.eu/images/250703/cskgnzua.png",
        duration = 20,
        center = {x = 0, y = 0, z = 0},
        spawns = {
            attacker = {
                {x = -515.8329, y = 5810.7324, z = 34.7726, h = 331.1747}
            },
            defender = {
                {x = 307.4980, y = 6572.6797, z = 29.4631, h = 113.8099}
            }
        },
        vehicle_spawns = {
            attacker = { 
                { model = 'schafter3', amount = 6, coords = {x = -514.2906, y = 5819.2344, z = 34.5910}, heading = 329.1963 },
                { model = 'schafter3', amount = 6, coords = {x = -508.9569, y = 5816.3599, z = 34.5719}, heading = 329.1963 },
                { model = 'schafter6', amount = 1, coords = {x =   -492.5069, y =  5850.3462, z = 33.4445}, heading = 329.1963 },
                { model = 'frakheli12', amount = 1, coords = {x = -513.1779, y = 5840.8003, z = 34.2127}, heading = 299.8497 },
            },
            defender = {
                { model = 'schafter3', amount = 6, coords = {x =  298.4202, y =  6574.6167, z = 29.5087}, heading = 95.2851 },
                { model = 'schafter3', amount = 6, coords = {x =  298.7078, y =  6568.5757, z = 29.6825}, heading = 95.2851},
                { model = 'schafter6', amount = 1, coords = {x =  262.1148, y =  6568.0454, z = 30.3562}, heading = 95.2851 },
                { model = 'frakheli12', amount = 1, coords = {x = 287.7568, y = 6561.2598, z = 30.0051}, heading = 64.9351},

            }
        },
    },
    {
    name = "Baustelle",
    image = "https://s1.directupload.eu/images/250703/cskgnzua.png",
    duration = 20,
    center = {x = 0, y = 0, z = 0},
    spawns = {
        attacker = {
            {x = 855.6564, y = 2528.0439, z = 66.8770, h = 234.3628},
        },
        defender = {
            {x = 1171.4849, y = 2212.0044, z = 53.1904, h = 46.6199}
        }
    },
    vehicle_spawns = {
        attacker = { 
          --  { model = 'schafter3', amount = 6, coords = {x = -508.9893, y = 5827.0981, z = 34.0113}, heading = 330.1217 },
          --  { model = 'schafter3', amount = 6, coords = {x = -502.3954, y = 5830.5562, z = 33.8748}, heading = 331.0018 },
          --  { model = 'schafter6', amount = 1, coords = {x = -497.1929, y = 5842.6587, z = 33.6161}, heading = 328.7350 },
        },
        defender = {
          --  { model = 'schafter3', amount = 6, coords = {x = 290.5834, y = 6568.5312, z = 29.5158}, heading = 96.8002 },
          --  { model = 'schafter3', amount = 6, coords = {x = 289.7144, y = 6575.0005, z = 29.5508}, heading = 97.6837 },
          --  { model = 'schafter6', amount = 1, coords = {x = 281.2930, y = 6570.2212, z = 29.8055}, heading = 95.6102 },

        }
    },
},
{
    name = "Sandy Shores",
    image = "https://s1.directupload.eu/images/250704/mkrg4xiv.png",
    duration = 20,
    center = {x = 0, y = 0, z = 0},
    spawns = {
        attacker = {
            {x = 278.0250, y = 2659.7952, z = 44.6551, h = 13.3330},
        },
        defender = {
            {x = 2267.7065, y = 3839.0190, z = 34.3814, h = 117.7452}
        }
    },
    vehicle_spawns = {
        attacker = { 
            { model = 'schafter3', amount = 6, coords = {x = 272.6917, y = 2697.6707, z = 44.1241}, heading = 10.2261 },
            { model = 'schafter3', amount = 6, coords = {x = 267.5358, y = 2696.6543, z = 44.1558}, heading = 10.2261 },
            { model = 'schafter6', amount = 1, coords = {x = 262.4748, y = 2740.0972, z = 43.9466}, heading = 10.2261 },
            { model = 'frakheli12', amount = 1, coords = {x = 245.4338, y = 2703.2788, z = 42.9614}, heading = 346.0867 },
        },
        defender = {
            { model = 'schafter3', amount = 6, coords = {x = 2256.8245, y = 3836.4248, z = 34.2247}, heading = 118.5043 },
            { model = 'schafter3', amount = 6, coords = {x = 2259.6035, y = 3831.3303, z = 34.2618}, heading = 118.5043 },
            { model = 'schafter6', amount = 1, coords = {x =  2214.9353, y = 3809.4651, z = 33.8403}, heading = 118.5043 },
            { model = 'frakheli12', amount = 1, coords = {x = 2272.0627, y = 3818.1030, z = 34.8930}, heading = 82.4746 },
        }
    },
    },
}

