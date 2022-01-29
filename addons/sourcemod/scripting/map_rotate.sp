/*
 * =============================================================================
 * File:		  map_rotate.sp
 * Type:		  Base map_rotate.sp
 * Description:   Plugin's base file.
 *
 * Copyright (C)   Anubis Edition. 2022-01-28 All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 */

#include <sourcemod>
#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

Handle g_cPluginEnabled = INVALID_HANDLE;
Handle g_cPluginTime = INVALID_HANDLE;
Handle g_cPluginQuota = INVALID_HANDLE;
Handle g_cPluginManaged = INVALID_HANDLE;
Handle g_cPluginMaps = INVALID_HANDLE;
Handle g_cPluginMapsOrder = INVALID_HANDLE;
Handle c_cSmNextmap = INVALID_HANDLE;
Handle g_cSv_hibernate_when_empty = INVALID_HANDLE;

bool g_bPluginEnabled;
int g_iPluginTime;
int g_iPluginQuota;
bool g_bPluginManaged;
char g_sPluginMaps[PLATFORM_MAX_PATH];
bool g_bPluginMapsOrder;

Handle g_hTimerGameEnd = INVALID_HANDLE;
int g_iMapListIndex = 0;

ArrayList g_aMapList;

public Plugin myinfo =
{
	name = "Map Rotation",
	author = "Anubis",
	description = "This plugin will change the map if there is not enough real players on the server.",
	version = "1.0",
	url = "https://github.com/Stewart-Anubis"
};

public void OnPluginStart()
{
	int iArraySize = ByteCountToCells(64);
	g_aMapList = new ArrayList(iArraySize);

	c_cSmNextmap = FindConVar("sm_nextmap");
	g_cSv_hibernate_when_empty = FindConVar("sv_hibernate_when_empty"); SetConVarInt(g_cSv_hibernate_when_empty, 0);

	g_cPluginEnabled = CreateConVar("sm_mr_enable", "1", "(1)Enable or (0)Disable Map Rotation. Default: 1");
	g_cPluginTime = CreateConVar("sm_mr_timelimit", "20", "Time in minutes before changing map when no one is on the server. Default: 20");
	g_cPluginQuota = CreateConVar("sm_mr_player_quota", "1", "Number of players needed to cancel anticipated change map. Default: 1");
	g_cPluginManaged = CreateConVar("sm_mr_mapcycle_enabled", "1", "(1)Enable or (0)Disable managed mapcycle on empty server. Default: 1");
	g_cPluginMaps = CreateConVar("sm_mr_mapcycle", "maplist.txt", ".txt file, map list.");
	g_cPluginMapsOrder = CreateConVar("sm_mr_mapcycle_order", "1", "Order of changing maps. 1 = Random , 0 = Linear .. Default: 1");

	HookConVarChange(g_cPluginEnabled, OnCvarChange);
	HookConVarChange(g_cPluginTime, OnCvarChange);
	HookConVarChange(g_cPluginQuota, OnCvarChange);
	HookConVarChange(g_cPluginManaged, OnCvarChange);
	HookConVarChange(g_cPluginMaps, OnCvarChange);
	HookConVarChange(g_cPluginMapsOrder, OnCvarChange);
	HookConVarChange(g_cSv_hibernate_when_empty, OnCvarChange);

	AutoExecConfig(true, "Map_Rotation");
	//MapListLoad();
}

public void OnCvarChange(Handle cvar, const char[] oldvalue, const char[] newValue)
{
	if (cvar == g_cPluginEnabled)
	{
		g_bPluginEnabled = view_as<bool>(StringToInt(newValue));
	}
	else if (cvar == g_cPluginTime)
	{
		g_iPluginTime = StringToInt(newValue);
		if(g_hTimerGameEnd != INVALID_HANDLE)
		{
			KillTimer(g_hTimerGameEnd);
			g_hTimerGameEnd = INVALID_HANDLE;
		}
		CheckPlayerQuota();
	}
	else if (cvar == g_cPluginQuota)
	{
		g_iPluginQuota = StringToInt(newValue);
	}
	else if (cvar == g_cPluginManaged)
	{
		g_bPluginManaged = view_as<bool>(StringToInt(newValue));
	}
	else if (cvar == g_cPluginMaps)
	{
		strcopy(g_sPluginMaps, sizeof(g_sPluginMaps), newValue);
		g_iMapListIndex = 0;
		MapListLoad();
	}
	else if (cvar == g_cPluginMapsOrder)
	{
		g_bPluginMapsOrder = view_as<bool>(StringToInt(newValue));
		g_iMapListIndex = 0;
	}
	else if (cvar == g_cSv_hibernate_when_empty)
	{
		if (StringToInt(newValue) == 0)
		{
			return;
		}
		else
		{
			SetConVarInt(g_cSv_hibernate_when_empty, 0);
		}
	}
}

public void OnConfigsExecuted()
{
	g_bPluginEnabled = GetConVarBool(g_cPluginEnabled);
	g_iPluginTime = GetConVarInt(g_cPluginTime);
	g_iPluginQuota = GetConVarInt(g_cPluginQuota);
	g_bPluginManaged = GetConVarBool(g_cPluginManaged);
	GetConVarString(g_cPluginMaps, g_sPluginMaps, sizeof(g_sPluginMaps));
	g_bPluginMapsOrder = GetConVarBool(g_cPluginMapsOrder);
}

stock void CheckPlayerQuota()
{
	int i_Players;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			i_Players ++;
		}
	}
	
	if (i_Players < g_iPluginQuota && g_hTimerGameEnd == INVALID_HANDLE)
	{
		float f_TimerDelay = g_iPluginTime*60.0;
		g_hTimerGameEnd = CreateTimer(f_TimerDelay, GameEnd, _, TIMER_FLAG_NO_MAPCHANGE);
		PrintToServer("[SM] Not enough players, map will change in %d minutes.", g_iPluginTime);
	}
	else if (i_Players >= g_iPluginQuota && g_hTimerGameEnd != INVALID_HANDLE)
	{
		KillTimer(g_hTimerGameEnd);
		g_hTimerGameEnd = INVALID_HANDLE;
		PrintToServer("[SM] Player quota reached, map change cancelled.", g_iPluginTime);
	}
}

void MapListLoad()
{
	g_aMapList.Clear();

	if(!FileExists(g_sPluginMaps))
	{
		SetFailState("%s not parsed... file doesn't exist!", g_sPluginMaps);
	}

	Handle h_MapList = OpenFile(g_sPluginMaps, "r");

	if (h_MapList  == INVALID_HANDLE)
	{
		SetFailState("%s not parsed... file doesn't exist!", g_sPluginMaps);
	}
	
	PrintToServer("[SM] Load Map List - %s !", g_sPluginMaps);
	char s_line[64];
	
	while(!IsEndOfFile(h_MapList))
	{
		ReadFileLine(h_MapList,s_line,sizeof(s_line));
		TrimString(s_line);
		if(strlen(s_line) == 0)
		{
			continue;
		}
		g_aMapList.PushString(s_line);
	}
	CloseHandle(h_MapList);
}

public void OnMapStart()
{
	g_hTimerGameEnd = INVALID_HANDLE;
	if (g_bPluginEnabled)
	{
		CheckPlayerQuota();
	}
}

public void OnClientConnected(int client)
{
	if (g_bPluginEnabled)
	{
		CheckPlayerQuota();
	}
}

public void OnClientDisconnect_Post(int client)
{
	if (g_bPluginEnabled)
	{
		CheckPlayerQuota();
	}
}

public void OnPluginEnd()
{
	g_aMapList.Clear();
}

public Action GameEnd(Handle timer)
{
	CheckPlayerQuota();

	if (g_aMapList.Length <= 0) MapListLoad();

	if (g_hTimerGameEnd != INVALID_HANDLE)
	{
		char s_NextMap[64];
		int i_Randoverlay;

		if (g_bPluginManaged)
		{
			if(g_bPluginMapsOrder)
			{
				i_Randoverlay = GetRandomInt(0, (g_aMapList.Length - 1));
				g_aMapList.GetString(i_Randoverlay, s_NextMap, sizeof(s_NextMap));
			}
			else
			{
				if(g_iMapListIndex >= g_aMapList.Length - 1)
				{
					g_iMapListIndex = g_aMapList.Length - 1;
					g_aMapList.GetString(g_iMapListIndex, s_NextMap, sizeof(s_NextMap));
					g_iMapListIndex = 0;
				}
				else
				{
					g_aMapList.GetString(g_iMapListIndex, s_NextMap, sizeof(s_NextMap));
					g_iMapListIndex++;
				}
			}
			
			if (!IsMapValid(s_NextMap))
			{
				i_Randoverlay = GetRandomInt(0, (g_aMapList.Length - 1));
				g_aMapList.GetString(i_Randoverlay, s_NextMap, sizeof(s_NextMap));
				
				if (!IsMapValid(s_NextMap))
				{
					PrintToServer("[SM] %s not parsed... file doesn't exist!", s_NextMap);
					SetFailState("%s not parsed... file doesn't exist!", s_NextMap);
				}
				else
				{
					SetConVarString(c_cSmNextmap, s_NextMap, false, false);
					PrintToServer("[SM] Not enough players, change map to %s...", s_NextMap);
				}
			}
			else
			{
				SetConVarString(c_cSmNextmap, s_NextMap, false, false);
				PrintToServer("[SM] Not enough players, change map to %s...", s_NextMap);
			}
		}
		else
		{
			GetNextMap(s_NextMap, sizeof(s_NextMap));
			PrintToServer("[SM] Not enough players, change map to %s...", s_NextMap);
		}

		//Routine by Tsunami to end the map
		int iGameEnd  = FindEntityByClassname(-1, "game_end");
		if (iGameEnd == -1 && (iGameEnd = CreateEntityByName("game_end")) == -1) 
		{     
			LogError("Unable to create entity \"game_end\"!");
		} 
		else 
		{     
			AcceptEntityInput(iGameEnd, "EndGame");
		}

		int i_Players;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && !IsFakeClient(i))
			{
				i_Players ++;
			}
		}
		if (i_Players == 0) {
			//empty server, hardswitch
			PrintToServer("[SM] Empty server, call ForceChangeLevel to %s...", s_NextMap);
			ForceChangeLevel(s_NextMap, "MR NextMap");
		}
	}
	else
	{
		PrintToServer("[SM] Player quota reached, map change cancelled.");
	}
}