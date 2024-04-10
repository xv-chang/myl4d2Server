#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =
{
	name		= "BS DROP",
	description = "扔掉手上的物品",
	author		= "那一世的悲伤",
	version		= "1.0",
	url			= "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_g", OnDropItem, "扔掉手上的物品", 0);
}


public Action OnDropItem(int client, int args)
{
	char weaponName[32];
	GetClientWeapon(client, weaponName, sizeof(weaponName));
	char classname[32];
	for (int slot = 0; slot < 5; slot++)
	{
		int weapon = GetPlayerWeaponSlot(client, slot);
		if (weapon > -1)
		{
			GetEntityClassname(weapon, classname, sizeof(classname));
			if (strcmp(classname, weaponName, true) == 0)
			{
				SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
				float vel[3];
				vel[0] = GetRandomFloat(-80.0, 80.0);
				vel[1] = GetRandomFloat(-80.0, 80.0);
				vel[2] = GetRandomFloat(40.0, 80.0);
				TeleportEntity(weapon, NULL_VECTOR, NULL_VECTOR, vel);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Handled;
}
