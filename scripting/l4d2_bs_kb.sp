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
	RegConsoleCmd("sm_kb", Command_KickBots, "踢人机");
}

public Action Command_KickBots(int client, int args)
{
	ServerCommand("sm_kick @bots");
	return Plugin_Handled;
}

