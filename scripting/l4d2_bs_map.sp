#include <sourcemod>
#include <l4d2_nativevote>

#define DISPLAY_MAX_LEN	  1024
#define SQL_QUERY_MAX_LEN 1024
#define SQL_ERROR_MAX_LEN 1024
#define MENU_WAIT_TIME	  20

public Plugin myinfo =
{
	name		= "BS Change MAP",
	description = "换图",
	author		= "那一世的悲伤",
	version		= "1.0",
	url			= "http://www.sourcemod.net/"
};

ConVar	  cvarNextChapter  = null;
ArrayList gMissionIds	   = null;
ArrayList gMissionNames	   = null;
ArrayList gMissionChapters = null;
ArrayList gChapters		   = null;
Database  gDb			   = null;

char	  gChapter[MAX_NAME_LENGTH];
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
	InitDataBase();
	InitMapMode();
	InitMissions();
	InitMissionInfo();
	InitChapters();
}

public void OnPluginEnd()
{
	delete gMissionIds;
	delete gMissionNames;
	delete gMissionChapters;
	delete gChapters;
	delete gDb;
}

void InitMapMode()
{
	char gameMode[50];
	FindConVar("mp_gamemode").GetString(gameMode, sizeof(gameMode));
	LogMessage("mp_gamemode :%s", gameMode);
	FindMapMode(gameMode, gMapMode, sizeof(gMapMode));
}

void InitMissionInfo()
{
	GetCurrentMap(gChapter, sizeof(gChapter));
	char query[DISPLAY_MAX_LEN];
	Format(query, sizeof(query), "select m.id,m.display_title from chapters c left join missions m on c.mission_id=m.id where c.map='%s' and mode ='%s'", gChapter, gMapMode);
	DBResultSet rs = SQL_Query(gDb, query);
	SQL_FetchRow(rs);
	gMissionId = SQL_FetchInt(rs, 0);
	SQL_FetchString(rs, 1, gMissionName, sizeof(gMissionName));
}

void FindMapMode(const char[] gamemode, char[] buffer, int maxlength)
{
	char query[DISPLAY_MAX_LEN];
	Format(query, sizeof(query), "select mapmode from modes where gamemode='%s'", gamemode);
	DBResultSet rs = SQL_Query(gDb, query);
	SQL_FetchRow(rs);
	SQL_FetchString(rs, 0, buffer, maxlength);
}

public void OnMapStart()
{
	InitMapMode();
	InitMissionInfo();
	InitChapters();
	int chapterIndex = gChapters.FindString(gChapter);
	if (chapterIndex == gChapters.Length - 1)
	{
		LogMessage("Is Finale Map>>>");
		char nextMap[DISPLAY_MAX_LEN];
		cvarNextChapter.GetString(nextMap, sizeof(nextMap));
		if (!IsMapValid(nextMap))
		{
			int missionIndex	 = gMissionIds.FindValue(gMissionId);
			int nextMissionIndex = missionIndex + 1;
			LogMessage("nextMissionIndex:%d", nextMissionIndex);
			if (nextMissionIndex > gMissionIds.Length)
			{
				nextMissionIndex = 0;
				LogMessage("nextMissionIndex>maxLen reset:%d", nextMissionIndex);
			}

			gMissionChapters.GetString(nextMissionIndex, nextMap, sizeof(nextMap));
			LogMessage("set next map:%s", nextMap);
			cvarNextChapter.SetString(nextMap, true);
		}
	}
}

void InitDataBase()
{
	char error[SQL_ERROR_MAX_LEN];
	gDb = SQL_DefConnect(error, sizeof(error), true);
	if (gDb == null)
	{
		LogError("mysql connect failed :%s", error);
		return;
	}
	gDb.SetCharset("utf8");
}

int FindMissionId(const char[] mode, const char[] name)
{
	char query[SQL_QUERY_MAX_LEN];
	Format(query, sizeof(query), "select id from missions where mode='%s' and name='%s'", mode, name);
	DBResultSet rs = SQL_Query(gDb, query);
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
	char err[SQL_ERROR_MAX_LEN];
	char query[SQL_QUERY_MAX_LEN];
	Format(query, sizeof(query), "insert into missions(mode,name,display_title,version,author,sort_num)values('%s','%s','%s','%s','%s',0)", mode, name, display_title, version, author);
	if (!SQL_FastQuery(gDb, query))
	{
		SQL_GetError(gDb, err, sizeof(err));
		LogError("exec sql err:%s,sql:%s", err, query);
		return 0;
	}
	DBResultSet res = SQL_Query(gDb, "select @@IDENTITY;");
	SQL_FetchRow(res);
	return SQL_FetchInt(res, 0);
}

void SaveChapter(int mission_id, const char[] map, const char[] display_name)
{
	char err[SQL_ERROR_MAX_LEN];
	char query[SQL_QUERY_MAX_LEN];
	Format(query, sizeof(query), "insert into chapters(mission_id,map,display_name)values(%d,'%s','%s')", mission_id, map, display_name);
	if (!SQL_FastQuery(gDb, query))
	{
		SQL_GetError(gDb, err, sizeof(err));
		LogError("exec sql err:%s,sql:%s", err, query);
	}
}

void InitMissions()
{
	gMissionIds		 = new ArrayList(MAX_NAME_LENGTH);
	gMissionNames	 = new ArrayList(MAX_NAME_LENGTH);
	gMissionChapters = new ArrayList(MAX_NAME_LENGTH);

	char gamemode[20];
	FindConVar("mp_gamemode").GetString(gamemode, sizeof(gamemode));
	char err[SQL_ERROR_MAX_LEN];
	char query[1024];
	Format(query, sizeof(query), "select m.id,m.display_title,c.map from chapters c left join missions m on c.mission_id=m.id where c.id in (select min(id) from chapters GROUP BY mission_id) and  mode = (select mapmode from modes where gamemode='%s') order by m.sort_num asc, m.display_title asc", gamemode);
	DBResultSet rs = SQL_Query(gDb, query);
	if (rs == null)
	{
		SQL_GetError(gDb, err, sizeof(err));
		LogError("exec sql err:%s,sql:%s", err, query);
		return;
	}
	while (SQL_FetchRow(rs))
	{
		char missionName[DISPLAY_MAX_LEN];
		char chapter[DISPLAY_MAX_LEN];

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
	gChapters = new ArrayList(DISPLAY_MAX_LEN);
	char query[SQL_QUERY_MAX_LEN];
	Format(query, sizeof(query), "select map from chapters where mission_id=%d", gMissionId);
	DBResultSet rs = SQL_Query(gDb, query);
	while (SQL_FetchRow(rs))
	{
		char chapter[DISPLAY_MAX_LEN];
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
		char	 fileName[DISPLAY_MAX_LEN];
		char	 name[DISPLAY_MAX_LEN];
		char	 displayTitle[DISPLAY_MAX_LEN];
		char	 version[DISPLAY_MAX_LEN];
		char	 author[DISPLAY_MAX_LEN];

		FileType fileType;
		while (dirList.GetNext(fileName, sizeof(fileName), fileType))
		{
			char missionPath[DISPLAY_MAX_LEN];
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

					char map[DISPLAY_MAX_LEN];
					char displayName[DISPLAY_MAX_LEN];

					if (kv.JumpToKey("modes", false))
					{
						if (!(kv.GotoFirstSubKey(false)))
						{
							return;
						}
						char mode[DISPLAY_MAX_LEN];
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
	}
	else
	{
		SetFailState("Could not locate mission folder");
	}
}

int ChangeMissionMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		char chapter[MAX_NAME_LENGTH];
		char missionName[MAX_NAME_LENGTH];
		menu.GetItem(param2, chapter, sizeof(chapter), _, missionName, sizeof(missionName));
		Menu actionMenu = new Menu(ChangeActionMenuHandler);
		actionMenu.SetTitle(missionName);
		char actionMenuInfo1[DISPLAY_MAX_LEN];
		Format(actionMenuInfo1, sizeof(actionMenuInfo1), "%s,%s,%s", missionName, chapter, "0");
		char actionMenuInfo2[DISPLAY_MAX_LEN];
		Format(actionMenuInfo2, sizeof(actionMenuInfo2), "%s,%s,%s", missionName, chapter, "1");
		actionMenu.AddItem(actionMenuInfo1, "强制更换");
		actionMenu.AddItem(actionMenuInfo2, "预定");
		actionMenu.ExitButton = true;
		actionMenu.Display(param1, MENU_WAIT_TIME);
	}
	return 0;
}

int ChangeChapterMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		char chapter[DISPLAY_MAX_LEN];
		menu.GetItem(param2, chapter, sizeof(chapter));
		char menuInfo[DISPLAY_MAX_LEN];
		Format(menuInfo, sizeof(menuInfo), "%s,%s,0", gMissionName, chapter);
		CheckPermissionAndChangeChapter(param1, menuInfo);
	}
	return 0;
}

void DoVoteMenu(int client, const char[] menuInfo)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		PrintToChat(client, "投票正在进行中, 暂不能发起新的投票");
		return;
	}

	L4D2NativeVote vote = L4D2NativeVote(Handle_VoteMenu);
	vote.Initiator		= client;
	vote.SetInfo(menuInfo);

	char buffers[3][DISPLAY_MAX_LEN];
	ExplodeString(menuInfo, ",", buffers, 3, DISPLAY_MAX_LEN);
	int	 changeMode = StringToInt(buffers[2]);
	char voteTitle[DISPLAY_MAX_LEN];
	if (changeMode == 0)
	{
		Format(voteTitle, sizeof(voteTitle), "更换地图[%s]-[%s]", buffers[0], buffers[1]);
	}
	else
	{
		Format(voteTitle, sizeof(voteTitle), "预定地图[%s]-[%s]", buffers[0], buffers[1]);
	}

	int team;
	int clients[1];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || (team = GetClientTeam(i)) < 2 || team > 3)
		{
			continue;
		}
		vote.SetTitle(voteTitle);
		clients[0] = i;
		vote.DisplayVote(clients, 1, 20);
	}
}

void Handle_VoteMenu(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	switch (action)
	{
		case VoteAction_Start:
		{
			char menuInfo[DISPLAY_MAX_LEN];
			char buffers[3][DISPLAY_MAX_LEN];
			vote.GetInfo(menuInfo, sizeof(menuInfo));
			ExplodeString(menuInfo, ",", buffers, 3, DISPLAY_MAX_LEN);

			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsFakeClient(i))
				{
					PrintToChat(i, "{blue}%N {default}发起投票 {olive}更换地图: %s (%s)", param1, buffers[0], buffers[1]);
				}
			}
		}

		case VoteAction_PlayerVoted:
			PrintToChatAll("{blue}%N {default}已投票", param1);

		case VoteAction_End:
		{
			if (vote.YesCount > vote.PlayerCount / 2)
			{
				vote.SetPass("加载中...");
				char menuInfo[DISPLAY_MAX_LEN];
				vote.GetInfo(menuInfo, sizeof(menuInfo));
				ChangeChapter(menuInfo);
			}
			else
				vote.SetFail();
		}
	}
}

void ChangeChapter(const char[] menuInfo)
{
	char buffers[3][DISPLAY_MAX_LEN];
	ExplodeString(menuInfo, ",", buffers, 3, DISPLAY_MAX_LEN);
	LogMessage("DoChangeMission mission :%s, chapter:%s ,changeMode:%s", buffers[0], buffers[1], buffers[2]);
	int changeMode = StringToInt(buffers[2]);
	if (changeMode == 0)
	{
		if (IsMapValid(buffers[1]))
		{
			PrintToChatAll("\x04☆\x01正在更换地图[%s]-[%s]...", buffers[0], buffers[1]);
			DataPack dp;
			CreateDataTimer(3.0, Timer_ChangeMap, dp);
			dp.WriteString(buffers[1]);
		}
		else
		{
			PrintToChatAll("\x04☆\x01无效的地图[%s]-[%s]", buffers[0], buffers[1]);
		}
	}
	else
	{
		cvarNextChapter.SetString(buffers[1]);
		PrintToChatAll("\x04☆\x01下一张地图已预定为[%s]-[%s]", buffers[0], buffers[1]);
	}
}

void CheckPermissionAndChangeChapter(int client, const char[] menuInfo)
{
	// if (GetUserFlagBits(client) & ADMFLAG_ROOT == ADMFLAG_ROOT)
	// {
	// 	ChangeChapter(menuInfo);
	// }
	// else
	// {
		DoVoteMenu(client, menuInfo)
	// }
}

int ChangeActionMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	char menuInfo[DISPLAY_MAX_LEN];
	if (action == MenuAction_Select)
	{
		menu.GetItem(param2, menuInfo, sizeof(menuInfo));
		CheckPermissionAndChangeChapter(param1, menuInfo);
	}
	return 0;
}

Action Command_ChangeMission(int client, int args)
{
	Menu missionMenu = new Menu(ChangeMissionMenuHandler);
	missionMenu.SetTitle("请选择任务");
	for (int i = 0; i < gMissionNames.Length; i++)
	{
		char missionName[DISPLAY_MAX_LEN];
		char chapter[DISPLAY_MAX_LEN];
		gMissionNames.GetString(i, missionName, sizeof(missionName));
		gMissionChapters.GetString(i, chapter, sizeof(chapter));
		missionMenu.AddItem(chapter, missionName);
	}
	missionMenu.ExitButton = true;
	missionMenu.Display(client, MENU_WAIT_TIME);
	return Plugin_Handled;
}

Action Command_ChangeChapter(int client, int args)
{
	Menu chapterMenu = new Menu(ChangeChapterMenuHandler);
	chapterMenu.SetTitle("选择章节");
	for (int i = 0; i < gChapters.Length; i++)
	{
		char buffer[DISPLAY_MAX_LEN];
		gChapters.GetString(i, buffer, sizeof(buffer));
		chapterMenu.AddItem(buffer, buffer);
	}
	chapterMenu.ExitButton = true;
	chapterMenu.Display(client, MENU_WAIT_TIME);
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
	char nextChapter[DISPLAY_MAX_LEN];
	cvarNextChapter.GetString(nextChapter, sizeof(nextChapter));
	if (IsMapValid(nextChapter))
	{
		ForceChangeLevel(nextChapter, "Admin Change Map");
		cvarNextChapter.SetString("");
	}
}

public Action Timer_ChangeMap(Handle timer, DataPack dp)
{
	char map[DISPLAY_MAX_LEN];
	dp.Reset();
	dp.ReadString(map, sizeof(map));
	ForceChangeLevel(map, "chmap command");
	return Plugin_Stop;
}