#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =
{
	name		= "BS Kick Bots",
	description = "踢人机",
	author		= "那一世的悲伤",
	version		= "1.0",
	url			= "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_kb", OnKickBots, "踢人机");
}

public Action OnKickBots(int client, int args)
{
	int kickCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsClientIdle(i) == 0)
		{
			StripWeapons(i);	//踢出前清理生还者全部物品.
			KickClient(i, "踢出全部电脑生还者.");
			kickCount++;
		}
	}

	if (kickCount == 0)
	{
		PrintToChatAll("没有电脑生还者")
	}
	else {
        PrintToChatAll("已踢出全部电脑生还者")
	}

	return Plugin_Handled;
}

int IsClientIdle(int client)
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

void StripWeapons(int client)
{
	int itemIdx;
	for (int x = 0; x <= 4; x++)
	{
		if ((itemIdx = GetPlayerWeaponSlot(client, x)) != -1)
		{
			RemovePlayerItem(client, itemIdx);
			RemoveEdict(itemIdx);
		}
	}
}