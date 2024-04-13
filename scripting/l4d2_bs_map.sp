#include <sourcemod>

public Plugin myinfo =
{
	name		= "BS Change MAP",
	description = "管理员换图",
	author		= "那一世的悲伤",
	version		= "1.0",
	url			= "http://www.sourcemod.net/"
};

char	  officalMapPrefix[80] = "L4D2C";
ConVar	  cvarNextChapter	   = null;
ConVar	  cvarNextMission	   = null;
ConVar	  cvarCurrentMission   = null;
Menu	  gMissionMenu		   = null;
Menu	  gChapterMenu		   = null;
StringMap gMissions			   = null;
StringMap gChapters			   = null;
Database  hDatabase			   = null;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("missions.phrases");
	cvarNextMission	   = CreateConVar("bs_next_mission", "", "存储下一关任务");
	cvarNextChapter	   = CreateConVar("bs_next_chapter", "", "存储下一关章节");
	cvarCurrentMission = CreateConVar("bs_current_mission", "", "存储当前任务");
	RegAdminCmd("sm_mode", Command_ChangeMode, ADMFLAG_ROOT, "更换游戏模式");
	RegAdminCmd("sm_diff", Command_ChangeDiff, ADMFLAG_ROOT, "更换游戏难度");
	RegAdminCmd("sm_refreshmap", Command_RefreshMap, ADMFLAG_ROOT, "刷新地图");
	RegConsoleCmd("sm_chmap", Command_ChangeMap, "更换官方地图");
	RegConsoleCmd("sm_chmap2", Command_ChangeMap2, "更换三方地图");
	HookEvent("finale_win", OnFinaleWin);
}

public void OnPluginEnd()
{
	delete gMissions;
	delete gChapters;
	delete gMissionMenu;
	delete gChapterMenu;
}

void SetRandomMission(const char[] mission)
{
	StringMapSnapshot keys				 = gMissions.Snapshot();
	int				  randomMissionIndex = GetRandomInt(0, keys.Length - 1);
	LogMessage("Get Random Mission Index :%d", randomMissionIndex);
	char randomMission[128];
	keys.GetKey(randomMissionIndex, randomMission, sizeof(randomMission));
	if (strcmp(mission, randomMission, false) == 0)
	{
		LogMessage("Set Random Mission: Reset Random");
		SetRandomMission(mission);
		return;
	}
	LogMessage("Set Random Mission:%s", randomMission);
	ArrayList randomChapters;
	gMissions.GetValue(randomMission, randomChapters);
	char chapter[128];
	randomChapters.GetString(0, chapter, sizeof(chapter));
	LogMessage("Set Random Chapter:%s", chapter);
	cvarNextChapter.SetString(chapter, true);
}

public void OnMapInit(const char[] mapName)
{
	char mission[PLATFORM_MAX_PATH];
	gChapters.GetString(mapName, mission, sizeof(mission));
	cvarCurrentMission.SetString(mission);
	//检查是否是最后一关
	ArrayList chapters;
	gMissions.GetValue(mission, chapters);
	int chapterIndex = chapters.FindString(mapName);
	if (chapterIndex == chapters.Length - 1)
	{
		LogMessage("Is Finale Map>>>");
		char nextMap[PLATFORM_MAX_PATH];
		cvarNextChapter.GetString(nextMap, sizeof(nextMap));
		if (!IsMapValid(nextMap))
		{
			SetRandomMission(mission);
		}
	}
}

bool ConnectMysql()
{
	char	 error[255];
	Database db = SQL_DefConnect(error, sizeof(error), true);
	if (db == null)
	{
		LogError("mysql connect failed :%s", error);
		return false;
	}
	hDatabase = db;
	return true
}

int FindMissionId(const char[] mode, const char[] name)
{
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "select id from missions where mode='%s' and name='%s'", mode, name);
	DBResultSet res = SQL_Query(hDatabase, query);
	if (res == null)
	{
		return 0;
	}
	if (!SQL_FetchRow(res))
	{
		return 0;
	}
	return SQL_FetchInt(res, 0);
}

int SaveMission(const char[] mode, const char[] name, const char[] display_title, const char[] version, const char[] author)
{
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "insert into missions(mode,name,display_title,version,author)('%s','%s','%s','%s','%s') RETURNING id", mode, name, display_title, version, author);
	DBResultSet res = SQL_Query(hDatabase, query);
	if (res == null)
	{
		return 0;
	}
	SQL_FetchRow(res);
	return SQL_FetchInt(res, 0);
}

void SaveChapter(int mission_id, const char[] map, const char[] display_name)
{
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "insert into chapters(mission_id,map,display_name)(%d,'%s','%s')", mission_id, map, display_name);
	SQL_FastQuery(hDatabase, query)
}

void LoadMapList()
{
	LogMessage("LoadMapList>>>");

	DirectoryListing dirList = OpenDirectory("missions", true, NULL_STRING);
	KeyValues		 kv		 = CreateKeyValues("mission", "", "");
	if (dirList)
	{
		char fileName[PLATFORM_MAX_PATH];
		char name[PLATFORM_MAX_PATH];
		char displayTitle[PLATFORM_MAX_PATH];
		char version[PLATFORM_MAX_PATH];
		char author[PLATFORM_MAX_PATH];

		ConnectMysql();

		FileType fileType;
		while (dirList.GetNext(fileName, sizeof(fileName), fileType))
		{
			char missionPath[PLATFORM_MAX_PATH];
			Format(missionPath, sizeof(missionPath), "missions/%s", fileName);
			if (fileType == FileType_File)
			{
				if (strcmp("credits.txt", fileName, false))
				{
					kv.ImportFromFile(missionPath);
					kv.GetString("Name", name, sizeof(name));
					kv.GetString("DisplayTitle", displayTitle, sizeof(displayTitle));
					kv.GetString("Version", version, sizeof(version));
					kv.GetString("Author", author, sizeof(author));

					char map[PLATFORM_MAX_PATH];
					char displayName[PLATFORM_MAX_PATH];

					if (kv.JumpToKey("modes", false))
					{
						if (!(kv.GotoFirstSubKey(false)))
						{
							return;
						}
						char mode[PLATFORM_MAX_PATH];
						do
						{
							kv.GetSectionName(mode, sizeof(mode));
							int missionId = FindMissionId(mode, name);
							if (missionId == 0)
							{
								missionId = SaveMission(mode, name, displayTitle, version, author);
							}
							if (missionId == 0)
							{
								LogMessage("create mission failed");
								return;
							}

							if (!(kv.GotoFirstSubKey(false)))
							{
								return;
							}
							do
							{
								kv.GetString("Map", map, sizeof(map));
								kv.GetString("DisplayName", displayName, sizeof(displayName));
								SaveChapter(missionId, map, displayName)
							}
							while (kv.GotoNextKey(true));
						}
						while (kv.GotoNextKey(true));
					}
				}
			}
		}
		delete dirList;
		delete kv;
		delete hDatabase;
	}
	else
	{
		SetFailState("Could not locate mission folder");
	}
}

int MissionMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	char menuInfo[80];
	char menuName[80];
	char chapter[80];
	if (action == MenuAction_Select)
	{
		menu.GetItem(param2, menuInfo, sizeof(menuInfo), _, menuName, sizeof(menuName));
		gChapterMenu = new Menu(ChapterMenuHandler);
		gChapterMenu.SetTitle("请选择章节");
		ArrayList chapters;
		gMissions.GetValue(menuInfo, chapters);
		for (int i = 0; i < chapters.Length; i++)
		{
			char chapterMenuInfo[PLATFORM_MAX_PATH];
			chapters.GetString(i, chapter, sizeof(chapter));
			Format(chapterMenuInfo, sizeof(chapterMenuInfo), "%s,%s", menuInfo, chapter);
			gChapterMenu.AddItem(chapterMenuInfo, chapter);
		}
		gChapterMenu.ExitButton		= true;
		gChapterMenu.ExitBackButton = true;
		gChapterMenu.Display(param1, MENU_TIME_FOREVER);
	}

	return 0;
}

int ChapterMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	char menuInfo[80];
	if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && gMissionMenu)
		{
			menu.GetItem(0, menuInfo, sizeof(menuInfo));
			int lastPage = StringToInt(menuInfo, 10);
			gMissionMenu.DisplayAt(param1, lastPage, MENU_TIME_FOREVER)
		}
	}
	else
	{
		if (action == MenuAction_Select)
		{
			char menuName[80];
			menu.GetItem(param2, menuInfo, sizeof(menuInfo), _, menuName, sizeof(menuName));
			Menu actionMenu = new Menu(ChangeActionMenuHandler);
			actionMenu.SetTitle(menuName);
			char actionMenuInfo1[PLATFORM_MAX_PATH];
			Format(actionMenuInfo1, sizeof(actionMenuInfo1), "%s,%s", menuInfo, "0");
			char actionMenuInfo2[PLATFORM_MAX_PATH];
			Format(actionMenuInfo2, sizeof(actionMenuInfo2), "%s,%s", menuInfo, "1");
			actionMenu.AddItem(actionMenuInfo1, "强制更换");
			actionMenu.AddItem(actionMenuInfo2, "预定");
			actionMenu.ExitButton	  = true;
			actionMenu.ExitBackButton = true;
			actionMenu.Display(param1, MENU_TIME_FOREVER);
		}
	}
	return 0;
}

void DoVoteMenu(const char[] menuInfo)
{
	if (IsVoteInProgress())
	{
		return;
	}
	Menu menu = new Menu(Handle_VoteMenu, MenuAction_Display);
	menu.SetTitle("change map to?");
	menu.AddItem(menuInfo, "Yes");
	menu.AddItem(menuInfo, "No");
	menu.ExitButton = false;
	menu.DisplayVoteToAll(20);
}

void DoChangeMission(const char[] menuInfo)
{
	char buffers[3][PLATFORM_MAX_PATH];
	if (ExplodeString(menuInfo, ",", buffers, 3, PLATFORM_MAX_PATH) != 3)
	{
		LogMessage("DoChangeMission error menuInfo :%s", menuInfo);
		return;
	}
	LogMessage("DoChangeMission mission :%s, chapter:%s ,changeMode:%s", buffers[0], buffers[1], buffers[2]);
	int changeMode = StringToInt(buffers[2]);
	if (changeMode == 0)
	{
		if (IsMapValid(buffers[1]))
		{
			PrintToChatAll("[BS]正在更换地图[%t]-[%s]...", buffers[0], buffers[1]);
			DataPack dp;
			CreateDataTimer(3.0, Timer_ChangeMap, dp);
			dp.WriteString(buffers[1]);
		}
		else
		{
			PrintToChatAll("[BS]无效的地图[%t]-[%s]", buffers[0], buffers[1]);
		}
	}
	else
	{
		cvarNextMission.SetString(buffers[0]);
		cvarNextChapter.SetString(buffers[1]);
		PrintToChatAll("[BS]下一张地图已预定为[%t]-[%s]", buffers[0], buffers[1]);
	}
}

public int Handle_VoteMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_VoteEnd)
	{
		if (param1 == 0)
		{
			char menuInfo[PLATFORM_MAX_PATH];
			menu.GetItem(param1, menuInfo, sizeof(menuInfo));
			DoChangeMission(menuInfo);
		}
	}
	else if (action == MenuAction_Display)
	{
		char menuInfo[PLATFORM_MAX_PATH];
		menu.GetItem(0, menuInfo, sizeof(menuInfo));
		LogMessage("MenuAction_Display ：%s", menuInfo);
		char buffers[3][PLATFORM_MAX_PATH];
		ExplodeString(menuInfo, ",", buffers, 3, PLATFORM_MAX_PATH);
		int	  changeMode = StringToInt(buffers[2]);
		Panel panel		 = view_as<Panel>(param2);
		char  voteTitle[PLATFORM_MAX_PATH];
		char  localizeMission[PLATFORM_MAX_PATH];
		Format(localizeMission, sizeof(localizeMission), "%T", buffers[0], param1);
		if (changeMode == 0)
		{
			Format(voteTitle, sizeof(voteTitle), "更换地图[%s]-[%s]", localizeMission, buffers[1]);
		}
		else
		{
			Format(voteTitle, sizeof(voteTitle), "预定地图[%s]-[%s]", localizeMission, buffers[1]);
		}
		panel.SetTitle(voteTitle);
	}

	return 0;
}

int ChangeActionMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	char menuInfo[PLATFORM_MAX_PATH];
	if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && gChapterMenu)
		{
			menu.GetItem(0, menuInfo, sizeof(menuInfo));
			int lastPage = StringToInt(menuInfo, 10);
			gChapterMenu.DisplayAt(param1, lastPage, MENU_TIME_FOREVER)
		}
	}
	else if (action == MenuAction_Select)
	{
		menu.GetItem(param2, menuInfo, sizeof(menuInfo));
		if (GetUserFlagBits(param1) & ADMFLAG_ROOT == ADMFLAG_ROOT)
		{
			DoChangeMission(menuInfo);
		}
		else
		{
			DoVoteMenu(menuInfo)
		}
	}
	return 0;
}

Action Command_ChangeDiff(int client, int args)
{
	if (args < 1)
	{
		PrintToChat(client, "\x04[BS]\x05!diff空格+难度(Easy|Normal|Hard|Impossible)");
		return Plugin_Handled;
	}
	char difficulty[256];
	GetCmdArgString(difficulty, 64);
	SetConVarString(FindConVar("z_difficulty"), difficulty, false, false);
	PrintToChatAll("\x04[BS]\x05当前难度已更换成\x04[\x03%s\x04]", difficulty);
	return Plugin_Handled;
}

Action Command_ChangeMap(int client, int args)
{
	gMissionMenu = new Menu(MissionMenuHandler);
	gMissionMenu.SetTitle("官方地图");
	StringMapSnapshot keys = gMissions.Snapshot();
	for (int i = 0; i < keys.Length; i++)
	{
		char buffer[128];
		keys.GetKey(i, buffer, sizeof(buffer));
		if (StrContains(buffer, officalMapPrefix, false) != -1)
		{
			char title[128];
			Format(title, sizeof(title), "%T", buffer, client);
			gMissionMenu.AddItem(buffer, title);
		}
	}
	gMissionMenu.ExitButton = true;
	gMissionMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

Action Command_ChangeMap2(int client, int args)
{
	gMissionMenu = new Menu(MissionMenuHandler);
	gMissionMenu.SetTitle("三方地图");
	StringMapSnapshot keys = gMissions.Snapshot();
	for (int i = 0; i < keys.Length; i++)
	{
		char buffer[128];
		keys.GetKey(i, buffer, sizeof(buffer));
		if (StrContains(buffer, officalMapPrefix, false) == -1)
		{
			char title[128];
			Format(title, sizeof(title), "%T", buffer, client);
			gMissionMenu.AddItem(buffer, title);
		}
	}
	gMissionMenu.ExitButton = true;
	gMissionMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

Action Command_ChangeMode(int client, int args)
{
	if (args < 1)
	{
		PrintToChat(client, "\x04[BS]\x05!mode空格+模式(coop|realism|community1|community5|mutation4)");
		return Plugin_Handled;
	}
	char mode[256];
	GetCmdArgString(mode, 64);
	SetConVarString(FindConVar("mp_gamemode"), mode);
	PrintToChatAll("\x04[BS]\x05当前模式已更换成\x04[\x03%s\x04]", mode);
	return Plugin_Handled;
}

Action Command_RefreshMap(int client, args)
{

	LoadMapList();
	return Plugin_Handled;
}

public void OnFinaleWin(Event event, char[] name, bool dontBroadcast)
{
	char nextChapter[PLATFORM_MAX_PATH];
	cvarNextChapter.GetString(nextChapter, sizeof(nextChapter));
	if (IsMapValid(nextChapter))
	{
		ForceChangeLevel(nextChapter, "admin Change Map");
		cvarNextChapter.SetString("");
		cvarNextMission.SetString("");
	}
}

public Action Timer_ChangeMap(Handle timer, DataPack dp)
{
	char map[PLATFORM_MAX_PATH];
	dp.Reset();
	dp.ReadString(map, sizeof(map));
	ForceChangeLevel(map, "chmap command");
	return Plugin_Stop;
}