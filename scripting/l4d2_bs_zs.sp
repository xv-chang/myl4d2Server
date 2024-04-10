#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name		= "BS ZS",
	description = "幸存者自杀指令",
	author		= "那一世的悲伤",
	version		= "1.0",
	url			= "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_zs", OnSuicide, "幸存者自杀指令", 0);
}

public Action OnSuicide(client, args)
{
	if (IsPlayerAlive(client) && GetClientTeam(client) == 2)
	{
		ForcePlayerSuicide(client);
		PrintToChatAll("\x04[提示]\x03%N\x05突然失去了梦想,自杀身亡.", client);
	}
	return Plugin_Handled;
}