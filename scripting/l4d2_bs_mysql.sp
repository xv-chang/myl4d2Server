#include <sourcemod>

public Plugin myinfo =
{
	name		= "BS Mysql Demo",
	description = "Mysql Demo",
	author		= "那一世的悲伤",
	version		= "1.0",
	url			= "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	char	 error[255];
	Database db = SQL_DefConnect(error, sizeof(error));
	db.SetCharset("utf8mb4");

	if (db == null)
	{
		LogMessage("Could not connect: %s", error);
		return;
	}

	LogMessage("mysql is already!");
	delete db;
}

public void OnClientConnected(int client)
{

    
}