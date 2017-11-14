#include <cg_core>
#include <system2>

Handle g_hDatabase;
bool testServer;

#include "updater/cfg.sp"   //自动更新cfg和翻译
#include "updater/map.sp"   //自动添加地图到服务器
#include "updater/nav.sp"   //自动更新nav
#include "updater/smx.sp"   //自动更新插件到服务器
#include "updater/add.sp"   //自动审核并添加地图到数据中心

public Plugin myinfo = 
{
    name        = "[CG] - Auto Updater",
    author      = "Kyle",
    description = "an auto update system",
    version     = "1.9",
    url         = "http://steamcommunity.com/id/_xQy_/"
};
 
void OnDatabaseAvailable()
{
    if(testServer)
        return;

    LogMessage("AutoUpdater is checking server[%d] now...", CG_GetServerId());

    switch(CG_GetServerId())
    {
        case 1 : SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'ze'", 0);
        case 2 : SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'ze'", 0);
        case 3 : SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'ze'", 0);
        case 4 : SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'ze'", 0);
        case 5 : SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'tt'", 0);
        case 6 : SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'tt'", 0);
        case 7 : SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'mg'", 0);
        case 8 : SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'jb'", 0);
        case 9 : SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'jb'", 0);
        case 11: SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'hg'", 0);
        case 12: SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'ds'", 0);
        case 15: SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'kz'", 0);
        case 16: SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'kz'", 0);
        case 19: SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'kz'", 0);
        case 20: SQL_TQuery(g_hDatabase, SQLCallback_CheckMap, "SELECT `map` FROM map_database WHERE `mod` = 'kz'", 0);
        default:
        {
            char m_szPath[128];
            BuildPath(Path_SM, m_szPath, 128, "plugins/autoupdater.smx");
            if(!FileExists(m_szPath) || !DeleteFile(m_szPath))
                LogError("Delete autoupdater.smx failed.");
            ServerCommand("sm plugins unload autoupdater.smx");
        }
    }
}

public void OnAllPluginsLoaded()
{
    char szPath[128];
    BuildPath(Path_SM, szPath, 128, "data/download");
    if(!DirExists(szPath))
        CreateDirectory(szPath, 511);

    CheckDatabase();

    CFG_OnAllPluginLoaded();
    SMX_OnAllPluginLoaded();
    NAV_OnAllPluginLoaded();
    MAP_OnAllPluginLoaded();
    ADD_OnAllPluginLoaded();
}
 
void CheckDatabase()
{
    g_hDatabase = CG_DatabaseGetGames();
    if(g_hDatabase == INVALID_HANDLE)
        CreateTimer(5.0, Timer_Reconnect);
    else
        OnDatabaseAvailable();
}

public Action Timer_Reconnect(Handle timer)
{
    CheckDatabase();
    return Plugin_Stop;
}

public void OnConfigsExecuted()
{
    char map[128];
    GetCurrentMap(map, 128);
    CFG_OnMapStart(map);
    ADD_OnMapStart(map);
}

public void OnMapVoteEnd(const char[] map)
{
    if(StrContains(map, "extend", false) != -1)
        return;
    
    if(StrContains(map, "change", false) != -1)
        return;

    strcopy(nextMap, 128, map);
    
    NAV_GetFiles(map);
    CFG_GetTrans();
    CFG_GetConfs();
    CFG_GetStrip();
    CFG_GetWatch();
}

void String_ToLower(const char[] input, char[] output, int size)
{
    size--;

    int x = 0;
    while(input[x] != '\0' && x < size)
    {
        output[x] = CharToLower(input[x]);
        x++;
    }

    output[x] = '\0';
}