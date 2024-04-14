#include <sourcemod>

public Plugin myinfo =
{
	name		= "BS Change MAP",
	description = "换图",
	author		= "那一世的悲伤",
	version		= "1.0",
	url			= "http://www.sourcemod.net/"
};

ConVar	  cvarNextChapter  = null;
Menu	  gMissionMenu	   = null;
Menu	  gChapterMenu	   = null;
ArrayList gMissionIds	   = null;
ArrayList gMissionNames	   = null;
ArrayList gMissionChapters = null;
ArrayList gChapters		   = null;
Database  hDatabase		   = null;
char	  gMapMode[MAX_NAME_LENGTH];
//当前任务信息
int		  gMissionId = 0;
char	  gMissionName[MAX_NAME_LENGTH];

public void OnPluginStart()
{
	cvarNextChapter = CreateConVar("bs_next_chapter", "", "存储下一关章节");
	RegAdminCmd("sm_read_missions", Command_ReadMissions, ADMFLAG_ROOT, "读取地图信息");
	RegConsoleCmd("sm_chmap", Command_ChangeMission, "更换任务");
	RegConsoleCmd("sm_chmap2", Command_ChangeChapter, "更换章节");
	HookEvent("finale_win", OnFinaleWin);
	OpenDatabase();
}

public void OnPluginEnd()
{
	delete gMissionIds;
	delete gMissionNames;
	delete gMissionChapters;
	delete gChapters;
	delete gMissionMenu;
	delete gChapterMenu;
	CloseDatabase();
}
void InitMapMode()
{
	char gameMode[50];
	FindConVar("mp_gamemode").GetString(gameMode, sizeof(gameMode));
	FindMapMode(gameMode, gMapMode, sizeof(gMapMode));
}

void InitMissionInfo(const char[] map)
{
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "select m.id,m.display_title from chapters c left join missions m on c.mission_id=m.id where c.map='%s' and mode ='%s'", map, gMapMode);
	DBResultSet rs = SQL_Query(hDatabase, query);
	SQL_FetchRow(rs);
	gMissionId = SQL_FetchInt(rs, 0);
	SQL_FetchString(rs, 1, gMissionName, sizeof(gMissionName));
}

void FindMapMode(const char[] gamemode, char[] buffer, int maxlength)
{
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "select mapmode from modes where gamemode='%s'", gamemode);
	DBResultSet rs = SQL_Query(hDatabase, query);
	SQL_FetchRow(rs);
	SQL_FetchString(rs, 0, buffer, maxlength);
}

public void OnMapInit(const char[] mapName)
{
	InitMapMode();
	InitMissionInfo(mapName);
	InitChapters();
	int chapterIndex = gChapters.FindString(mapName);
	if (chapterIndex == gChapters.Length - 1)
	{
		LogMessage("Is Finale Map>>>");
		char nextMap[PLATFORM_MAX_PATH];
		cvarNextChapter.GetString(nextMap, sizeof(nextMap));
		if (!IsMapValid(nextMap))
		{
			int missionIndex	 = gMissionIds.FindValue(gMissionId);
			int nextMissionIndex = missionIndex + 1;
			nextMissionIndex	 = nextMissionIndex % gMissionIds.Length;
			gMissionChapters.GetString(nextMissionIndex, nextMap, sizeof(nextMap));
			cvarNextChapter.SetString(nextMap, true);
		}
	}
}

bool OpenDatabase()
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

void CloseDatabase()
{
	if (hDatabase != null)
	{
		delete hDatabase;
	}
}

int FindMissionId(const char[] mode, const char[] name)
{
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "select id from missions where mode='%s' and name='%s'", mode, name);
	DBResultSet rs = SQL_Query(hDatabase, query);
	if (rs == null)
	{
		return 0;
	}
	if (!SQL_FetchRow(rs))
	{
		return 0;
	}
	return SQL_FetchInt(rs, 0);
}

int SaveMission(const char[] mode, const char[] name, const char[] display_title, const char[] version, const char[] author)
{
	char err[PLATFORM_MAX_PATH];
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "insert into missions(mode,name,display_title,version,author,sort_num)values('%s','%s','%s','%s','%s',0)", mode, name, display_title, version, author);
	if (!SQL_FastQuery(hDatabase, query))
	{
		SQL_GetError(hDatabase, err, sizeof(err));
		LogError("exec sql err:%s,sql:%s", err, query);
		return 0;
	}
	DBResultSet res = SQL_Query(hDatabase, "select @@IDENTITY;");
	SQL_FetchRow(res);
	return SQL_FetchInt(res, 0);
}

void SaveChapter(int mission_id, const char[] map, const char[] display_name)
{
	char err[PLATFORM_MAX_PATH];
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "insert into chapters(mission_id,map,display_name)values(%d,'%s','%s')", mission_id, map, display_name);
	if (!SQL_FastQuery(hDatabase, query))
	{
		SQL_GetError(hDatabase, err, sizeof(err));
		LogError("exec sql err:%s,sql:%s", err, query);
	}
}

void InitMissions()
{
	gMissionIds		 = new ArrayList();
	gMissionNames	 = new ArrayList();
	gMissionChapters = new ArrayList();

	char gamemode[20];
	FindConVar("mp_gamemode").GetString(gamemode, sizeof(gamemode));
	char err[PLATFORM_MAX_PATH];
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "select m.id,m.display_title,c.map from chapters c left join missions m on c.mission_id=m.id where c.id in (select min(id) from chapters GROUP BY mission_id) and  mode = (select mapmode from modes where gamemode='%s') order by m.sort_num asc, m.display_title asc", gamemode);
	DBResultSet rs = SQL_Query(hDatabase, query);
	if (rs == null)
	{
		SQL_GetError(hDatabase, err, sizeof(err));
		LogError("exec sql err:%s,sql:%s", err, query);
		return;
	}
	while (SQL_FetchRow(rs))
	{
		char missionName[MAX_NAME_LENGTH];
		char chapter[MAX_NAME_LENGTH];

		int	 missionId = SQL_FetchInt(rs, 0);
		SQL_FetchString(rs, 1, missionName, sizeof(missionName));
		SQL_FetchString(rs, 2, chapter, sizeof(chapter));

		gMissionIds.Push(missionId);
		gMissionNames.PushString(missionName);
		gMissionChapters.PushString(chapter);
	}
}

void InitChapters()
{
	gChapters = new ArrayList();
	char query[PLATFORM_MAX_PATH];
	Format(query, sizeof(query), "select map from chapters where mission_id=%d", gMissionId);
	DBResultSet rs = SQL_Query(hDatabase, query);
	while (SQL_FetchRow(rs))
	{
		char chapter[PLATFORM_MAX_PATH];
		SQL_FetchString(rs, 0, chapter, sizeof(chapter));
		gChapters.PushString(chapter);
	}
}

void ReadMissions()
{
	LogMessage("ReadMissions>>>");
	DirectoryListing dirList = OpenDirectory("missions", true, NULL_STRING);
	KeyValues		 kv		 = CreateKeyValues("mission", "", "");
	if (dirList)
	{
		char fileName[PLATFORM_MAX_PATH];
		char name[PLATFORM_MAX_PATH];
		char displayTitle[PLATFORM_MAX_PATH];
		char version[PLATFORM_MAX_PATH];
		char author[PLATFORM_MAX_PATH];

		OpenDatabase();

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
		CloseDatabase();
	}
	else
	{
		SetFailState("Could not locate mission folder");
	}
}


int ChangeMissionMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	char chapter[MAX_NAME_LENGTH];
	char missionName[MAX_NAME_LENGTH];
	if (action == MenuAction_Select)
	{
		menu.GetItem(param2, chapter, sizeof(chapter), _, missionName, sizeof(missionName));
		Menu actionMenu = new Menu(ChangeActionMenuHandler);
		actionMenu.SetTitle(missionName);
		char actionMenuInfo1[PLATFORM_MAX_PATH];
		Format(actionMenuInfo1, sizeof(actionMenuInfo1), "%s,%s,%s", missionName, chapter, "0");
		char actionMenuInfo2[PLATFORM_MAX_PATH];
		Format(actionMenuInfo2, sizeof(actionMenuInfo2), "%s,%s,%s", missionName, chapter, "1");
		actionMenu.AddItem(actionMenuInfo1, "强制更换");
		actionMenu.AddItem(actionMenuInfo2, "预定");
		actionMenu.ExitButton = true;
		actionMenu.Display(param1, MENU_TIME_FOREVER);
	}
	return 0;
}

int ChangeChapterMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char chapter[MAX_NAME_LENGTH];
		char missionName[MAX_NAME_LENGTH];
		menu.GetItem(param2, chapter, sizeof(chapter), _, missionName, sizeof(missionName));
		char menuInfo[PLATFORM_MAX_PATH];
		Format(menuInfo, sizeof(menuInfo), "%s,%s,0", missionName, chapter);
		ChangeChapter(menuInfo);
	}
	return 0;
}

void DoVoteMenu(const char[] menuInfo)
{
	if (IsVoteInProgress())
	{
		return;
	}
	char buffers[3][PLATFORM_MAX_PATH];
	ExplodeString(menuInfo, ",", buffers, 3, PLATFORM_MAX_PATH);
	Menu menu = new Menu(Handle_VoteMenu, MenuAction_Display);
	menu.SetTitle("change map?");
	menu.AddItem(menuInfo, "Yes");
	menu.AddItem(menuInfo, "No");
	menu.ExitButton = false;
	menu.DisplayVoteToAll(20);
}

void ChangeChapter(const char[] menuInfo)
{
	char buffers[3][PLATFORM_MAX_PATH];
	ExplodeString(menuInfo, ",", buffers, 3, PLATFORM_MAX_PATH);
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
			ChangeChapter(menuInfo);
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
		if (changeMode == 0)
		{
			Format(voteTitle, sizeof(voteTitle), "更换地图[%s]-[%s]", buffers[0], buffers[1]);
		}
		else
		{
			Format(voteTitle, sizeof(voteTitle), "预定地图[%s]-[%s]", buffers[0], buffers[1]);
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
	if (action == MenuAction_Select)
	{
		menu.GetItem(param2, menuInfo, sizeof(menuInfo));
		if (GetUserFlagBits(param1) & ADMFLAG_ROOT == ADMFLAG_ROOT)
		{
			ChangeChapter(menuInfo);
		}
		else
		{
			DoVoteMenu(menuInfo)
		}
	}
	return 0;
}

Action Command_ChangeMission(int client, int args)
{
	gMissionMenu = new Menu(ChangeMissionMenuHandler);
	gMissionMenu.SetTitle("请选择任务");

	for (int i = 0; i < gMissionNames.Length; i++)
	{
		char missionName[MAX_NAME_LENGTH];
		char chapter[MAX_NAME_LENGTH];
		gMissionNames.GetString(i, missionName, sizeof(missionName));
		gMissionChapters.GetString(i, chapter, sizeof(chapter));
		gMissionMenu.AddItem(chapter, missionName);
	}
	gMissionMenu.ExitButton = true;
	gMissionMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

Action Command_ChangeChapter(int client, int args)
{
	gChapterMenu = new Menu(ChangeChapterMenuHandler);
	gChapterMenu.SetTitle("选择章节");
	for (int i = 0; i < gChapters.Length; i++)
	{
		char buffer[128];
		gChapters.GetString(i, buffer, sizeof(buffer));
		gMissionMenu.AddItem(buffer, buffer);
	}
	gChapterMenu.ExitButton = true;
	gChapterMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

Action Command_ReadMissions(int client, args)
{
	ReadMissions();
	InitMissions();
	return Plugin_Handled;
}

public void OnFinaleWin(Event event, char[] name, bool dontBroadcast)
{
	char nextChapter[PLATFORM_MAX_PATH];
	cvarNextChapter.GetString(nextChapter, sizeof(nextChapter));
	if (IsMapValid(nextChapter))
	{
		ForceChangeLevel(nextChapter, "Admin Change Map");
		cvarNextChapter.SetString("");
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