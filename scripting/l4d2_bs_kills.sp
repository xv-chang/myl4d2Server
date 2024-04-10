#include <sourcemod>
#include <sdkhooks>

public Plugin myinfo =
{
	name		= "BS Kills",
	description = "击杀统计",
	author		= "那一世的悲伤",
	version		= "1.0",
	url			= "http://www.sourcemod.net/"
};

int killSpecial[MAXPLAYERS];
int shotFriend[MAXPLAYERS];
int zombieKills[MAXPLAYERS];

public void OnPluginStart()
{
	RegConsoleCmd("sm_kills", OnDisplayKills, "显示击杀统计");
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("infected_death", OnInfectedDeath, EventHookMode_Post);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
	HookEvent("round_start", OnRoundStart, EventHookMode_Post);
	HookEvent("round_end", OnRoundEnd, EventHookMode_Post);
}

public void ResetAllCounter()
{
	for (int i = 0; i <= MaxClients; i++)
	{
		ResetCounter(i);
	}
}

public void ResetCounter(int client)
{
	zombieKills[client] = 0;
	killSpecial[client] = 0;
	shotFriend[client]	= 0;
}

void ShowMessage(int client, char[] format, any...)
{
	char buffer[254];
	if (client > 0 && IsClientInGame(client))
	{
		SetGlobalTransTarget(client);
		VFormat(buffer, sizeof(buffer), format, 3);
		PrintToChat(client, "%s", buffer);
	}
	else
	{
		int i = 1;
		while (i <= MaxClients)
		{
			if (IsClientInGame(i))
			{
				SetGlobalTransTarget(i);
				VFormat(buffer, sizeof(buffer), format, 3);
				PrintToChat(i, "%s", buffer);
			}
			i++;
		}
	}
}

public void DisplayKills(int clientId)
{
	ShowMessage(clientId, "\x04-----------击杀统计-----------");
	int j = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsPlayer(i))
		{
			j++;
			char line[512];
			Format(line, sizeof(line), "\x04☆%d \x05特感:\x04%d\x03 僵尸:\x04%d\x03 黑枪:\x05%d\x03 \x04-%N", j, killSpecial[i], zombieKills[i], shotFriend[i], i);
			ShowMessage(clientId, line);
		}
	}
}

public void OnClientConnected(int client)
{
	if (IsPlayer(client))
	{
		ResetCounter(client);
	}
}

public void OnClientDisconnect(int client)
{
	if (IsPlayer(client))
	{
		ResetCounter(client);
	}
}

public int SortByDamageDesc(int client1, int client2, int[] array, Handle hndl)
{
	int flag = killSpecial[client2] - killSpecial[client1];
	if (flag == 0)
	{
		flag = zombieKills[client2] - zombieKills[client1];
	}
	return flag;
}

public bool IsPlayer(client)
{
	return client > 0 && client < MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

public bool IsSpeical(client)
{
	return client > 0 && client < MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

public Action OnPlayerDeath(Event e, char[] name, bool dontBroadcast)
{
	int client	 = GetClientOfUserId(e.GetInt("userid", 0));
	int attacker = GetClientOfUserId(e.GetInt("attacker", 0));
	if (IsSpeical(client) && IsPlayer(attacker))
	{
		killSpecial[attacker] += 1;
	}
	return Plugin_Continue;
}

public Action OnInfectedDeath(Event e, char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(e.GetInt("attacker", 0));
	if (IsPlayer(attacker))
	{
		zombieKills[attacker] += 1;
	}
	return Plugin_Continue;
}

public Action OnPlayerHurt(Event e, char[] name, bool dontBroadcast)
{
	int client	 = GetClientOfUserId(e.GetInt("userid", 0));
	int attacker = GetClientOfUserId(e.GetInt("attacker", 0));
	if (IsPlayer(client) && IsPlayer(attacker))
	{
		if (GetClientTeam(client) == GetClientTeam(attacker) && GetClientTeam(client) != 3 && client != attacker)
		{
			int friendDmg		 = shotFriend[attacker];
			shotFriend[attacker] = friendDmg + e.GetInt("dmg_health", 0);
		}
	}
	return Plugin_Continue;
}

public Action OnRoundEnd(Event e, char[] name, bool dontBroadcast)
{
	DisplayKills(0);
	return Plugin_Continue;
}

public Action OnRoundStart(Event e, char[] name, bool dontBroadcast)
{
	ResetAllCounter();
	return Plugin_Continue;
}

public Action OnDisplayKills(int client, int args)
{
	DisplayKills(client);
	return Plugin_Continue;
}

public void OnMapStart()
{
	ResetAllCounter();
}