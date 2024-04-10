#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR  2
#define TEAM_INFECTED  3
#define TEAM_HOLDOUT   4

#define MAX_COLOR_NUM  5

Handle	  g_hFindUseEntity;
StringMap g_smModelToName;
int		  gRandomColors[MAX_COLOR_NUM][3];
ConVar	  cvarPlayerUseRadius;

public Plugin myinfo =
{
	name		= "BS Marker",
	description = "标记物品",
	author		= "那一世的悲伤",
	version		= "1.0",
	url			= "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	Init();
	InitRandomColor();
	cvarPlayerUseRadius = FindConVar("player_use_radius");
	AddCommandListener(CmdListener_vocalize, "vocalize");
}

void InitRandomColor()
{
	for (int i = 0; i < MAX_COLOR_NUM; i++)
	{
		int colorRandom[3];
		do
		{
			colorRandom[0]	 = GetRandomInt(0, 255);
			colorRandom[1]	 = GetRandomInt(0, 255);
			colorRandom[2]	 = GetRandomInt(0, 255);
			gRandomColors[i] = colorRandom;
		}
		while (GetRGB_Brightness(colorRandom) < 0.5);
	}
}

void Init()
{
	GameData hGameData = new GameData("l4d2_bs_marker");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_bs_marker.txt\" gamedata.");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "FindUseEntity");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);			  // range
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);			  // unknown
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);			  // tolerance
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	  // unknown bool pointer
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			  // player priority
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hFindUseEntity = EndPrepSDKCall();
	if (g_hFindUseEntity == null)
		SetFailState("Failed to create SDKCall: FindUseEntity");

	delete hGameData;

	g_smModelToName = new StringMap();

	// Case-sensitive
	g_smModelToName.SetString("models/w_models/weapons/w_eq_Medkit.mdl", "急救包!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_defibrillator.mdl", "电击!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_painpills.mdl", "止痛药!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_adrenaline.mdl", "止痛药 !");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_bile_flask.mdl", "胆汁!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_molotov.mdl", "火瓶!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_pipebomb.mdl", "土质炸弹!");
	g_smModelToName.SetString("models/w_models/Weapons/w_laser_sights.mdl", "激光!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_incendiary_ammopack.mdl", "燃烧弹包!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_explosive_ammopack.mdl", "高爆弹包!");
	g_smModelToName.SetString("models/props/terror/ammo_stack.mdl", "子弹!");
	g_smModelToName.SetString("models/props_unique/spawn_apartment/coffeeammo.mdl", "子弹!");
	g_smModelToName.SetString("models/props/de_prodigy/ammo_can_02.mdl", "子弹!");
	g_smModelToName.SetString("models/weapons/melee/w_chainsaw.mdl", "电锯!");
	g_smModelToName.SetString("models/w_models/weapons/w_pistol_B.mdl", "小手枪!");
	g_smModelToName.SetString("models/w_models/weapons/w_desert_eagle.mdl", "马格南!");
	g_smModelToName.SetString("models/w_models/weapons/w_shotgun.mdl", "木喷!");
	g_smModelToName.SetString("models/w_models/weapons/w_pumpshotgun_A.mdl", "铁喷!");
	g_smModelToName.SetString("models/w_models/weapons/w_smg_uzi.mdl", "Uzi!");
	g_smModelToName.SetString("models/w_models/weapons/w_smg_a.mdl", "Smg!");
	g_smModelToName.SetString("models/w_models/weapons/w_smg_mp5.mdl", "MP5!");
	g_smModelToName.SetString("models/w_models/weapons/w_rifle_m16a2.mdl", "M16!");
	g_smModelToName.SetString("models/w_models/weapons/w_rifle_sg552.mdl", "SG552!");
	g_smModelToName.SetString("models/w_models/weapons/w_rifle_ak47.mdl", "AK47!");
	g_smModelToName.SetString("models/w_models/weapons/w_desert_rifle.mdl", "SCAR!");
	g_smModelToName.SetString("models/w_models/weapons/w_shotgun_spas.mdl", "二代连喷!");
	g_smModelToName.SetString("models/w_models/weapons/w_autoshot_m4super.mdl", "一代连喷!");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_mini14.mdl", "木狙(15发猎枪)!");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_military.mdl", "30发连狙!");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_scout.mdl", "15发鸟狙!");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_awp.mdl", "AWP!");
	g_smModelToName.SetString("models/w_models/weapons/w_grenade_launcher.mdl", "榴弹发射器!");
	g_smModelToName.SetString("models/w_models/weapons/w_m60.mdl", "M60!");
	g_smModelToName.SetString("models/props_junk/gascan001a.mdl", "汽油桶!");
	g_smModelToName.SetString("models/props_junk/explosive_box001.mdl", "烟花!");
	g_smModelToName.SetString("models/props_junk/propanecanister001a.mdl", "煤气罐!");
	g_smModelToName.SetString("models/props_equipment/oxygentank01.mdl", "氧气罐!");
	g_smModelToName.SetString("models/props_junk/gnome.mdl", "侏儒!");
	g_smModelToName.SetString("models/w_models/weapons/w_cola.mdl", "可乐!");
	g_smModelToName.SetString("models/w_models/weapons/50cal.mdl", ".50 Cal Machine Gun here!");
	g_smModelToName.SetString("models/w_models/weapons/w_minigun.mdl", "机枪!");
	g_smModelToName.SetString("models/w_models/weapons/w_knife_t.mdl", "小刀!");
	g_smModelToName.SetString("models/weapons/melee/w_bat.mdl", "棒球棒!");
	g_smModelToName.SetString("models/weapons/melee/w_cricket_bat.mdl", "板球棒!");
	g_smModelToName.SetString("models/weapons/melee/w_crowbar.mdl", "撬棍!");
	g_smModelToName.SetString("models/weapons/melee/w_electric_guitar.mdl", "吉他!");
	g_smModelToName.SetString("models/weapons/melee/w_fireaxe.mdl", "消防斧!");
	g_smModelToName.SetString("models/weapons/melee/w_frying_pan.mdl", "平底锅!");
	g_smModelToName.SetString("models/weapons/melee/w_katana.mdl", "武士刀!");
	g_smModelToName.SetString("models/weapons/melee/w_machete.mdl", "砍刀!");
	g_smModelToName.SetString("models/weapons/melee/w_tonfa.mdl", "警棍!");
	g_smModelToName.SetString("models/weapons/melee/w_golfclub.mdl", "高尔夫!");
	g_smModelToName.SetString("models/weapons/melee/w_pitchfork.mdl", "草叉!");
	g_smModelToName.SetString("models/weapons/melee/w_shovel.mdl", "铁铲!");
	g_smModelToName.SetString("models/props/terror/exploding_ammo.mdl", "高爆弹!");
	g_smModelToName.SetString("models/props/terror/incendiary_ammo.mdl", "燃烧弹!");
}

float GetRGB_Brightness(int[] rgb)
{
	int r	 = rgb[0];
	int g	 = rgb[1];
	int b	 = rgb[2];

	int cmax = (r > g) ? r : g;
	if (b > cmax) cmax = b;
	return cmax / 255.0;
}

Action CmdListener_vocalize(int client, const char[] command, int argc)
{
	static char sArg[32], sModel[PLATFORM_MAX_PATH], sName[64];

	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsFakeClient(client))
	{
		if (GetCmdArgString(sArg, sizeof(sArg)) > 1 && !strncmp(sArg, "smartlook #", 11))
		{
			int entity = SDKCall(g_hFindUseEntity, client, cvarPlayerUseRadius.FloatValue, 0.0, 0.0, 0, false);
			if (entity > MaxClients && IsValidEntity(entity))
			{
				if (GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel)) > 1)
				{
					if (g_smModelToName.GetString(sModel, sName, sizeof(sName)))
					{
						PrintToChatAll("\x01(语音) \x05%N\x01: %s", client, sName);

						int randomIndex = GetRandomInt(0, 4);

						int r			= gRandomColors[randomIndex][0];
						int g			= gRandomColors[randomIndex][1];
						int b			= gRandomColors[randomIndex][2];

						SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
						SetEntProp(entity, Prop_Send, "m_glowColorOverride", r + (g * 256) + (b * 65536));
						SetEntProp(entity, Prop_Send, "m_bFlashing", 0);
						SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", 0);
						SetEntProp(entity, Prop_Send, "m_nGlowRange", 510);
					}
				}
			}
		}
	}

	return Plugin_Continue;
}