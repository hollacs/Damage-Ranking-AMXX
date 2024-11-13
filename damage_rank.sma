#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#define IS_PLAYER(%0) (1 <= %0 <= MaxClients)
#define GET_PLAYER_TEAM(%0) get_ent_data(%0, "CBasePlayer", "m_iTeam")

const MAX_RANKS = 10;
const MAX_MESSAGE_LENGTH = 256;
const DMGRANK_NO_PLACE = -1;

new g_rankPlayer[MAX_RANKS],
	g_rankStringPos[MAX_RANKS],
	g_message[MAX_MESSAGE_LENGTH],
	bool:g_requestedToBuildMsg = true;

new bool:g_isBot[MAX_PLAYERS + 1],
	bool:g_isConnected[MAX_PLAYERS + 1],
	bool:g_display[MAX_PLAYERS + 1],
	g_displayCount[MAX_PLAYERS + 1],
	g_place[MAX_PLAYERS + 1] = {DMGRANK_NO_PLACE, ...},
	Float:g_damage[MAX_PLAYERS + 1],
	Float:g_lastUpdate[MAX_PLAYERS + 1];

new Float:g_cvarHudPos[2], 
	g_cvarHudColor[3], 
	g_cvarHudChannel,
	Float:g_cvarInterval,
	g_cvarRankCount[3],
	g_cvarAliveOnly,
	g_cvarTeam,
	g_cvarBot,
	g_cvarResetOnNewRound,
	g_cvarResetOnDeath,
	g_cvarCSBot,
	g_cvarMenu;

new pcvar_RankCount[3], g_hudSyncObj;

new g_fwPlayerPreThink, g_fwRankUpdate;

public plugin_init()
{
	register_plugin("Damage Ranking", "0.1", "holla");

	register_event("HLTV", "onEventNewRound", "a", "1=0", "2=0");

	register_clcmd("say /dmgrank", "cmdSayDamage");

	bind_pcvar_float(create_cvar("dmgrank_hud_x", "0.12"), g_cvarHudPos[0]);
	bind_pcvar_float(create_cvar("dmgrank_hud_y", "0.1"), g_cvarHudPos[1]);

	bind_pcvar_num(create_cvar("dmgrank_hud_r", "100"), g_cvarHudColor[0]);
	bind_pcvar_num(create_cvar("dmgrank_hud_g", "100"), g_cvarHudColor[1]);
	bind_pcvar_num(create_cvar("dmgrank_hud_b", "255"), g_cvarHudColor[2]);

	bind_pcvar_num(create_cvar("dmgrank_hud_chan", "4"), g_cvarHudChannel);

	bind_pcvar_float(create_cvar("dmgrank_update", "0.25"), g_cvarInterval);

	bind_pcvar_num(create_cvar("dmgrank_alive_only", "1"), g_cvarAliveOnly);

	bind_pcvar_num(create_cvar("dmgrank_newround", "1"), g_cvarResetOnNewRound);

	bind_pcvar_num(create_cvar("dmgrank_death_reset", "0"), g_cvarResetOnDeath);

	bind_pcvar_num(create_cvar("dmgrank_team", "0"), g_cvarTeam);

	bind_pcvar_num(create_cvar("dmgrank_bot", "1"), g_cvarBot);

	new pcvar;
	bind_pcvar_num((pcvar = create_cvar("dmgrank_count_min", "1", .has_min=true, .min_val=1.0)), 
		g_cvarRankCount[0]);

	pcvar_RankCount[0] = pcvar;
	hook_cvar_change(pcvar, "onRankCountMinChange");

	bind_pcvar_num((pcvar = create_cvar("dmgrank_count_max", "5", .has_max=true, .max_val=float(MAX_RANKS))), 
		g_cvarRankCount[1]);

	pcvar_RankCount[1] = pcvar
	hook_cvar_change(pcvar, "onRankCountMaxChange");

	bind_pcvar_num((pcvar = create_cvar("dmgrank_count_def", "3", 
		.has_min=true, .min_val=1.0, 
		.has_max=true, .max_val=float(MAX_RANKS))), 
		g_cvarRankCount[2]);

	pcvar_RankCount[2] = pcvar;
	hook_cvar_change(pcvar, "onRankCountChange");

	bind_pcvar_num(create_cvar("dmgrank_csbot_support", "0"), g_cvarCSBot);

	bind_pcvar_num(create_cvar("dmgrank_menu", "1"), g_cvarMenu);

	new bool:bot = g_cvarCSBot ? true : false;
	RegisterHam(Ham_TakeDamage, "player", "onPlayerTakeDamage_Post", 1, bot);
	RegisterHam(Ham_Killed, "player", "onPlayerKilled_Post", 1, bot);

	g_fwRankUpdate = CreateMultiForward("dmgrank_on_update", ET_IGNORE);

	g_hudSyncObj = CreateHudSyncObj();
}

public plugin_natives()
{
	register_library("damage_rank");

	register_native("dmgrank_get_rank", "native_get_rank");
	register_native("dmgrank_get_damage", "native_get_damage");
	register_native("dmgrank_add_damage", "native_add_damage");
	register_native("dmgrank_at", "native_at");
	register_native("dmgrank_count", "native_count");
	register_native("dmgrank_show_menu", "native_show_menu");
}

public native_at()
{
	new index = get_param(1);
	if (index < 1 || index > MAX_RANKS)
	{
		log_error(AMX_ERR_NATIVE, "rank index (%d) out of bounds", index);
		return 0;
	}

	return g_rankPlayer[index-1];
}

public Float:native_get_damage()
{
	new player = get_param(1);
	if (!IS_PLAYER(player) || !g_isConnected[player])
	{
		log_error(AMX_ERR_NATIVE, "player (%d) not connected", player);
		return 0.0;
	}

	return g_damage[player];
}

public native_add_damage()
{
	new player = get_param(1);
	if (!IS_PLAYER(player) || !g_isConnected[player])
	{
		log_error(AMX_ERR_NATIVE, "player (%d) not connected", player);
		return;
	}

	g_damage[player] += get_param_f(2);
	checkUpdate(player);
}

public native_get_rank()
{
	new player = get_param(1);
	if (!IS_PLAYER(player) || !g_isConnected[player])
	{
		log_error(AMX_ERR_NATIVE, "player (%d) not connected", player);
		return 0;
	}

	return g_place[player] + 1;
}

public native_count()
{
	return g_cvarRankCount[1];
}

public native_show_menu()
{
	new player = get_param(1);
	if (!IS_PLAYER(player) || !g_isConnected[player])
	{
		log_error(AMX_ERR_NATIVE, "player (%d) not connected", player);
		return;
	}

	showDamageSettings(player);
}

public onRankCountMinChange(pcvar, const oldValue[], const newValue[])
{
	new value = str_to_num(newValue);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (g_isConnected[i] && g_displayCount[i] < value)
			g_displayCount[i] = value;
	}

	if (value > g_cvarRankCount[1])
		set_pcvar_num(pcvar_RankCount[1], value);
	if (g_cvarRankCount[2] < value)
		set_pcvar_num(pcvar_RankCount[2], value);
}

public onRankCountMaxChange(pcvar, const oldValue[], const newValue[])
{
	new value = str_to_num(newValue);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (g_isConnected[i] && g_displayCount[i] > value)
			g_displayCount[i] = value;
	}

	if (value < g_cvarRankCount[0])
		set_pcvar_num(pcvar_RankCount[0], value);
	if (g_cvarRankCount[2] > value)
		set_pcvar_num(pcvar_RankCount[2], value);

	sortRanking();
}

// Changing the cvar value from within this forward can lead to infinite recursion
public onRankCountChange(pcvar, const oldValue[], const newValue[])
{
	new value = str_to_num(newValue);
	if (value < g_cvarRankCount[0] || value > g_cvarRankCount[1])
		RequestFrame("setNewCvarValue", clamp(value, g_cvarRankCount[0], g_cvarRankCount[1]));
}

public setNewCvarValue(value)
{
	set_pcvar_num(pcvar_RankCount[2], value);
}

public client_putinserver(id)
{
	g_isBot[id] = bool:is_user_bot(id);
	g_isConnected[id] = true;
	g_display[id] = true;
	g_displayCount[id] = g_cvarRankCount[2];

	// a human player just joined the server
	if (!g_isBot[id] && !g_fwPlayerPreThink)
	{
		g_fwPlayerPreThink = register_forward(FM_PlayerPreThink, "onPlayerPreThink");
	}
}

public client_disconnected(id)
{
	if (g_isConnected[id])
	{
		checkUpdate(id);

		if (!g_isBot[id])
			RequestFrame("humanPlayerDropped");

		g_isConnected[id] = false;
		g_isBot[id] = false;
		g_damage[id] = 0.0;
		g_place[id] = DMGRANK_NO_PLACE;
	}
}

public humanPlayerDropped()
{
	// no human player exists anymore
	if (g_fwPlayerPreThink && get_playersnum_ex(GetPlayers_ExcludeBots) < 1)
	{
		unregister_forward(FM_PlayerPreThink, g_fwPlayerPreThink);
		g_fwPlayerPreThink = 0;
	}
}

public onEventNewRound()
{
	if (g_cvarResetOnNewRound)
	{
		for (new i = 0; i < MAX_RANKS; i++)
		{
			g_rankPlayer[i] = 0;
		}

		for (new i = 1; i <= MaxClients; i++)
		{
			g_damage[i] = 0.0;
			g_place[i] = DMGRANK_NO_PLACE;
		}

		sortRanking();
	}
}

public onPlayerTakeDamage_Post(victim, inflictor, attacker, Float:damage, damagebits)
{
	if (!IS_PLAYER(attacker) || damage <= 0.0)
		return;

	if (!g_cvarBot && g_isBot[attacker])
		return;

	new attackerTeam = GET_PLAYER_TEAM(attacker);
	if (g_cvarTeam && attackerTeam != g_cvarTeam)
		return;

	if (attackerTeam == GET_PLAYER_TEAM(victim))
		return;

	g_damage[attacker] += damage;
	checkUpdate(attacker);
}

public onPlayerKilled_Post(id)
{
	if (g_cvarResetOnDeath)
	{
		checkUpdate(id);
		g_damage[id] = 0.0;
		g_place[id] = DMGRANK_NO_PLACE;
	}
}

public onPlayerPreThink(id)
{
	if (!g_isConnected[id] || g_isBot[id] || !g_display[id])
		return;

	if (g_cvarAliveOnly && !is_user_alive(id))
		return;

	new Float:currentTime = get_gametime();
	if (currentTime - g_lastUpdate[id] < g_cvarInterval)
		return;

	if (g_requestedToBuildMsg)
	{
		buildRankingMessage();
		g_requestedToBuildMsg = false;
	}

	showHud(id, currentTime - g_lastUpdate[id]);
	g_lastUpdate[id] = currentTime;
}

public cmdSayDamage(id)
{
	showDamageSettings(id);
	return PLUGIN_CONTINUE;
}

public showDamageSettings(id)
{
	if (!g_cvarMenu)
		return;

	new menu = menu_create("傷害排名個人設定", "handleDamageSettings", true);

	menu_additem(menu, fmt("排名: %s", g_display[id] ? "\y顯示" : "\r關閉"));
	menu_additem(menu, fmt("數量: \y%d", g_displayCount[id]));
	menu_additem(menu, "重設所有設定");

	menu_display(id, menu);
}

public handleDamageSettings(id, menu, item)
{
	menu_destroy(menu);

	switch (item+1)
	{
		case 1:
		{
			g_display[id] = !g_display[id];
		}
		case 2:
		{
			g_displayCount[id] = max(g_cvarRankCount[0], (g_displayCount[id] + 1) % (g_cvarRankCount[1] + 1));
		}
		case 3:
		{
			g_display[id] = true;
			g_displayCount[id] = g_cvarRankCount[2];
		}
		default:
		{
			return;
		}
	}

	showDamageSettings(id);
}

showHud(id, Float:holdTime)
{
	set_hudmessage(g_cvarHudColor[0], g_cvarHudColor[1], g_cvarHudColor[2], 
		g_cvarHudPos[0], g_cvarHudPos[1], .fxtime=0.0,
		.holdtime=holdTime, .fadeintime=0.0, .fadeouttime=0.1,
		.channel=g_cvarHudChannel);

	static message[MAX_MESSAGE_LENGTH];
	message = g_message; // direct copy (should be fast?
	message[g_rankStringPos[g_displayCount[id]-1]] = EOS;

	if (g_cvarHudChannel)
		show_hudmessage(id, message);
	else
		ShowSyncHudMsg(id, g_hudSyncObj, message);
}

checkUpdate(id)
{
	new player;

	// check if updated is needed
	for (new i = 0; i < g_cvarRankCount[1]; i++)
	{
		player = g_rankPlayer[i];

		if (g_damage[id] >= g_damage[player])
		{
			sortRanking();
			break;
		}
	}
}

sortRanking()
{
	new playerBits = 0, highestPlayer;

	for (new i = 0, j; i < g_cvarRankCount[1]; i++)
	{
		// reset highest player
		highestPlayer = 0;

		// find the player who has the highest damage
		for (j = 1; j <= MaxClients; j++)
		{
			if (!g_isConnected[j] || g_damage[j] <= 0.0)
				continue;

			// filter if player is already on the list
			if (playerBits & (1 << (j-1)))
				continue;

			if (!highestPlayer || g_damage[j] > g_damage[highestPlayer])
				highestPlayer = j;
		}

		// no highest player found
		if (!highestPlayer)
		{
			// clean up remaining places
			for (j = i; j < MAX_RANKS; j++)
			{
				g_rankPlayer[j] = 0;
			}

			break;
		}

		// set place
		g_rankPlayer[i] = highestPlayer;
		g_place[highestPlayer] = i;
		playerBits |= (1 << (highestPlayer-1)); // add to bits
	}

	for (new i = g_cvarRankCount[1]; i < MAX_RANKS; i++)
	{
		g_rankPlayer[i] = 0;
	}

	for (new i = 1; i <= MaxClients; i++)
	{
		if (~playerBits & (1 << (i-1)))
			g_place[i] = DMGRANK_NO_PLACE;
	}

	g_requestedToBuildMsg = true;

	new ret;
	ExecuteForward(g_fwRankUpdate, ret);
}

buildRankingMessage()
{
	new player;
	new len = formatex(g_message, charsmax(g_message), "[傷害排名]^n^n");

	for (new i = 0; i < g_cvarRankCount[1]; i++)
	{
		player = g_rankPlayer[i];

		len += formatex(g_message[len], charsmax(g_message)-len,
			"#%d %s | %.f 傷害^n", i+1, 
			(player == 0) ? "---" : fmt("%n", player), 
			g_damage[player]);

		g_rankStringPos[i] = len;
	}
}