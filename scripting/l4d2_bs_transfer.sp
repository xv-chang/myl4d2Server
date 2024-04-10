
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <entity_prop_stocks>

#define MAX_TYPES		   9
#define TOP_INDEX_MEDS	   TYPE_PILLS
#define TOP_INDEX_NADE	   TYPE_VOMIT
#define TOP_INDEX_PACK	   TYPE_DEFIB
#define TRANSFER_TIMEOUT   5.0
#define DIST_GIVE		   150
#define SOUND_BIGREWARD	   "UI/BigReward.wav"						  // 给别人物品的声音
#define SOUND_LITTLEREWARD "UI/LittleReward.wav"					  // 接收物品的声音
#define SOUND_MOLOTOV_IDLE ")weapons/molotov/fire_idle_loop_1.wav"	  // ")" intentional.

int	  gButtons[MAXPLAYERS + 1];				//存储玩家按键状态


public Plugin myinfo =
{
	name		= "BS Transfer",
	description = "传递物品",
	author		= "那一世的悲伤",
	version		= "1.0",
	url			= "http://www.sourcemod.net/"
};

static const char pickUpItems[9][] = {
	"weapon_adrenaline",
	"weapon_pain_pills",
	"weapon_molotov",
	"weapon_pipe_bomb",
	"weapon_vomitjar",
	"weapon_first_aid_kit",
	"weapon_upgradepack_explosive",
	"weapon_upgradepack_incendiary",
	"weapon_defibrillator"
};

enum
{
	SLOT_NADE = 2,
	SLOT_PACK = 3,
	SLOT_MEDS = 4
};

enum
{
	EMPTY_NADE = (1 << 0),
	EMPTY_PACK = (1 << 1),
	EMPTY_MEDS = (1 << 2)
};

enum
{
	METHOD_NONE = 0,
	METHOD_GIVE = (1 << 0),
	METHOD_GRAB = (1 << 1),
	METHOD_SWAP = (1 << 2)
};

enum
{
	NOTIFY_GIVE	  = (1 << 0),
	NOTIFY_GRAB	  = (1 << 1),
	NOTIFY_SWITCH = (1 << 2)
};

enum
{
	TYPE_ADREN,
	TYPE_PILLS,
	TYPE_MOLO,
	TYPE_PIPE,
	TYPE_VOMIT,
	TYPE_FIRST,
	TYPE_EXPLO,
	TYPE_INCEN,
	TYPE_DEFIB
};

public void OnPluginStart()
{


}

public void OnPlayerRunCmdPost(int client, int buttons)
{
	if ((buttons & IN_RELOAD) && !(gButtons[client] & IN_RELOAD))
	{
		if (IsFakeClient(client))
		{
			return;
		}

		if (IsReviving(client) || IsIncapped(client))
		{
			return;
		}
		int target = GetClientAimTarget(client);

		if (!IsValidEntity(target) || GetClientTeam(target) != 2 || !IsPlayerAlive(target))
		{
			return;
		}

		int	 slot = -1;
		int	 type = -1;
		char weaponName[32];
		int	 item = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (item != -1)
		{
			item = EntIndexToEntRef(item);
			//查询除当前slot 和  物品类型
			GetClientWeapon(client, weaponName, sizeof(weaponName));
			type = GetItemType(weaponName);
		}
		if (type == -1)
		{
			return;
		}
		slot = GetItemSlot(type);
		if (slot == 0)
		{
			return;
		}
		// 验证目标背包是否空着
		if (GetPlayerWeaponSlot(target, slot) != -1)
		{
			return;
		}
		// 验证距离够不够
		static float vPos[3], vEnd[3], dist;
		GetClientEyePosition(client, vPos);
		GetClientEyePosition(target, vEnd);
		dist = GetVectorDistance(vPos, vEnd);
		if (dist > DIST_GIVE)
		{
			return;
		}
		GiveItem(client, target, item, type);
	}

	gButtons[client] = buttons;
}



int GetItemType(const char[] classname)
{
	for (int i = 0; i < MAX_TYPES; i++)
	{
		if (strncmp(classname[7], pickUpItems[i][7], 13) == 0)
		{
			return i;
		}
	}
	return -1;
}
int GetItemSlot(int type)
{
	if (type <= TOP_INDEX_MEDS) return SLOT_MEDS;
	if (type <= TOP_INDEX_NADE) return SLOT_NADE;
	if (type <= TOP_INDEX_PACK) return SLOT_PACK;
	return 0;
}

//复活救起
bool IsReviving(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_reviveOwner") > 0
}
//倒地
bool IsIncapped(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) > 0
}




void PlaySound(int client, const char sound[32])
{
	EmitSoundToClient(client, sound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

void GiveItem(int client, int target, int item, int type)
{

	PlaySound(target, SOUND_LITTLEREWARD);
	PlaySound(client, SOUND_BIGREWARD);

	if (type == TYPE_MOLO) StopSound(item, SNDCHAN_STATIC, SOUND_MOLOTOV_IDLE);

	RemovePlayerItem(client, item);

	if (IsFakeClient(target))
	{
		EquipPlayerWeapon(target, item);
		item = EntRefToEntIndex(item);
	}
	else {
		RemoveEdict(item);
		item = CreateAndEquip(target, type);
	}

	FireEventsGeneral(client, target, item, type);
}

int CreateAndEquip(int client, int type)
{
	static char classname[32];

	switch (type)
	{
		case TYPE_ADREN: classname = "weapon_adrenaline";
		case TYPE_PILLS: classname = "weapon_pain_pills";
		case TYPE_MOLO: classname = "weapon_molotov";
		case TYPE_PIPE: classname = "weapon_pipe_bomb";
		case TYPE_VOMIT: classname = "weapon_vomitjar";
		case TYPE_FIRST: classname = "weapon_first_aid_kit";
		case TYPE_EXPLO: classname = "weapon_upgradepack_explosive";
		case TYPE_INCEN: classname = "weapon_upgradepack_incendiary";
		case TYPE_DEFIB: classname = "weapon_defibrillator";
		default:
		{
			LogError("Type wrong: %d", type);
			return 0;
		}
	}

	int entity = GivePlayerItem(client, classname);
	if (entity != INVALID_ENT_REFERENCE)
	{
		RemovePlayerItem(client, entity);
		EquipPlayerWeapon(client, entity);
		return entity;
	}

	return 0;
}

//触发原有的事件
void FireEventsGeneral(int client, int target, int weapon, int type)
{
	int weaponid;
	switch (type)
	{
		case TYPE_ADREN: weaponid = 23;	   // weapon_adrenaline
		case TYPE_PILLS: weaponid = 15;	   // weapon_pain_pills
		case TYPE_MOLO: weaponid = 13;	   // weapon_molotov
		case TYPE_PIPE: weaponid = 14;	   // weapon_pipe_bomb
		case TYPE_VOMIT: weaponid = 25;	   // weapon_vomitjar
		case TYPE_FIRST: weaponid = 12;	   // weapon_first_aid_kit
		case TYPE_EXPLO: weaponid = 31;	   // weapon_upgradepack_explosive
		case TYPE_INCEN: weaponid = 30;	   // weapon_upgradepack_incendiary
		case TYPE_DEFIB: weaponid = 24;	   // weapon_defibrillator
	}
	Event hEvent = CreateEvent("weapon_given");
	if (hEvent)
	{
		hEvent.SetInt("userid", GetClientUserId(target));
		hEvent.SetInt("giver", GetClientUserId(client));
		hEvent.SetInt("weapon", weaponid);
		hEvent.SetInt("weaponentid", weapon);
		hEvent.Fire();
	}

	hEvent = CreateEvent("give_weapon");
	if (hEvent)
	{
		hEvent.SetInt("userid", GetClientUserId(client));
		hEvent.SetInt("recipient", GetClientUserId(target));
		hEvent.SetInt("weapon", weaponid);
		hEvent.Fire();
	}
}