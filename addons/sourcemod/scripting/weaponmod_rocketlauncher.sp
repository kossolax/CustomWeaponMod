#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <emitsoundany>
#include <smlib>

#include <custom_weapon_mod.inc>

char g_szFullName[PLATFORM_MAX_PATH] =	"Lance-roquettes";
char g_szName[PLATFORM_MAX_PATH] 	 =	"rocketlauncher";
char g_szReplace[PLATFORM_MAX_PATH]  =	"weapon_negev";

char g_szVModel[PLATFORM_MAX_PATH] =	"models/weapons/tsx/rocket_launcher/v_rocket_launcher.mdl";
char g_szWModel[PLATFORM_MAX_PATH] =	"models/weapons/tsx/rocket_launcher/w_rocket_launcher.mdl";
char g_szTModel1[PLATFORM_MAX_PATH] =	"models/shells/shell_57.mdl";
char g_szTModel2[PLATFORM_MAX_PATH] =	"models/weapons/w_eq_fraggrenade_thrown.mdl";

int g_cModel; 
char g_szMaterials[][PLATFORM_MAX_PATH] = {
	"materials/models/weapons/tsx/rocket_launcher/RocketTex0.vtf",
	"materials/models/weapons/tsx/rocket_launcher/RocketTex0.vmt"
};
char g_szSounds[][PLATFORM_MAX_PATH] = {
	"physics/metal/metal_box_scrape_rough_loop2.wav",
	"physics/concrete/boulder_impact_hard1.wav",
	"physics/concrete/boulder_impact_hard2.wav",
	"physics/concrete/boulder_impact_hard3.wav",
	"physics/concrete/boulder_impact_hard4.wav",
	"physics/glass/glass_sheet_impact_hard1.wav",
	"physics/glass/glass_sheet_impact_hard2.wav",
	"physics/glass/glass_sheet_impact_hard3.wav",
	"weapons/nova/nova_insertshell_01.wav",
	"weapons/nova/nova_insertshell_02.wav",
	"weapons/nova/nova_insertshell_03.wav"
};

#define MAX_PROJECTILES	8
#define REMOVE_AFTER	60.0
int g_iStack[MAX_ENTITIES][MAX_PROJECTILES];
public void OnPluginStart() {
	RegServerCmd("sm_cwm_reload", Cmd_PluginReloadSelf);
}
public void OnAllPluginsLoaded() {
	int id = CWM_Create(g_szFullName, g_szName, g_szReplace, g_szVModel, g_szWModel);
	
	CWM_SetInt(id, WSI_AttackType,		view_as<int>(WSA_SemiAutomatic));
	CWM_SetInt(id, WSI_ReloadType,		view_as<int>(WSR_OneByOne));
	CWM_SetInt(id, WSI_AttackDamage, 	500);
	CWM_SetInt(id, WSI_AttackBullet, 	1);
	CWM_SetInt(id, WSI_MaxBullet, 		3);
	CWM_SetInt(id, WSI_MaxAmmunition, 	30);
	CWM_SetInt(id, WSI_ShotFired,		3);
	
	CWM_SetFloat(id, WSF_Speed,			240.0);
	CWM_SetFloat(id, WSF_ReloadSpeed,	10/15.0);
	CWM_SetFloat(id, WSF_AttackSpeed,	10/15.0);
	CWM_SetFloat(id, WSF_AttackRange,	RANGE_MELEE * 4.0);
	CWM_SetFloat(id, WSF_Spread, 		0.0);
	CWM_SetFloat(id, WSF_Recoil, 		45.0);
	
	CWM_AddAnimation(id, WAA_Idle, 		0,	12,	15);
	CWM_AddAnimation(id, WAA_Draw, 		1,	7,	15);
	CWM_AddAnimation(id, WAA_Attack, 	4,  10,	15);
	CWM_AddAnimation(id, WAA_Attack2, 	3,  9,	15);
	CWM_AddAnimation(id, WAA_Reload, 	9,  10,	15);
	
	CWM_RegHook(id, WSH_Draw,			OnDraw);
	CWM_RegHook(id, WSH_Attack,			OnAttack);
	CWM_RegHook(id, WSH_Attack2,		OnAttack2);
	CWM_RegHook(id, WSH_Idle,			OnIdle);
	CWM_RegHook(id, WSH_Reload,			OnReload);
	CWM_RegHook(id, WSH_Empty,			OnEmpty);
}
public void OnReload(int client, int entity) {
	CWM_RunAnimation(entity, WAA_Reload);
	EmitSoundToAllAny(g_szSounds[GetRandomInt(8, 10)], entity, SNDCHAN_WEAPON);
}
public void OnDraw(int client, int entity) {
	CWM_RunAnimation(entity, WAA_Draw);
}
public void OnIdle(int client, int entity) {
	CWM_RunAnimation(entity, WAA_Idle);
}
public void OnEmpty(int client, int entity) {
	OnExplode(client, entity);
}
public Action OnAttack(int client, int entity) {
	
	if( !_IsStackEmpty(entity) )
		return OnExplode(client, entity);
	
	CWM_RunAnimation(entity, WAA_Attack);
	int ent = CWM_ShootProjectile(client, entity, g_szTModel1, "rocket", 0.0, 2000.0, OnProjectileHit);
	SetEntPropFloat(ent,  Prop_Send, "m_flModelScale", 10.0);
	SetEntityGravity(ent, 0.25);
	EmitSoundToAllAny(g_szSounds[0], ent, SNDCHAN_WEAPON);
	EmitSoundToAllAny(g_szSounds[GetRandomInt(1, 4)], entity, SNDCHAN_WEAPON);
	TE_SetupBeamFollow(ent, g_cModel, 0, 1.0, 1.0, 0.0, 1, {255, 255, 255, 100});
	TE_SendToAll();
	return Plugin_Continue;
}
public Action OnAttack2(int client, int entity) {
	
	if( _IsStackFull(entity) )
		return Plugin_Stop;
	
	CWM_RunAnimation(entity, WAA_Attack2);
	int ent = CWM_ShootProjectile(client, entity, g_szTModel2, "grenade", 2.5, 1200.0, INVALID_FUNCTION);
	EmitSoundToAllAny(g_szSounds[GetRandomInt(5, 7)], entity, SNDCHAN_WEAPON);
	_pushStack(entity, ent);
	
	TE_SetupBeamFollow(ent, g_cModel, 0, 1.0, 1.0, 0.0, 1, {255, 0, 0, 100});
	TE_SendToAll();
	return Plugin_Continue;
}

public Action OnExplode(int client, int entity) {
	int ent;
	for (int i = 0; i < MAX_PROJECTILES; i++) {
		ent = EntRefToEntIndex(g_iStack[entity][i]);
		if( ent > 0 && IsValidEdict(ent) && IsValidEntity(ent) ) {
			OnProjectileHit(client, entity, ent, 0);
			g_iStack[entity][i] = INVALID_ENT_REFERENCE;
			AcceptEntityInput(ent, "Kill");
		}
	}
	
	return Plugin_Stop;
}

public Action OnProjectileHit(int client, int wpnid, int entity, int target) {
	CWM_ShootExplode(client, wpnid, entity, 300.0);
	float pos[3];
	Entity_GetAbsOrigin(entity, pos);
	TE_SetupExplosion(pos, 0, 1.0, 0, 0, 200, 50);
	TE_SendToAll();
	StopSoundAny(entity, SNDCHAN_WEAPON, g_szSounds[0]);
	return Plugin_Handled;
}
public void OnMapStart() {

	AddModelToDownloadsTable(g_szVModel);
	AddModelToDownloadsTable(g_szWModel);
	AddModelToDownloadsTable(g_szTModel1);
	AddModelToDownloadsTable(g_szTModel2);
	
	for (int i = 0; i < sizeof(g_szSounds); i++) {
		AddSoundToDownloadsTable(g_szSounds[i]);
		PrecacheSoundAny(g_szSounds[i]);
	}
	for (int i = 0; i < sizeof(g_szMaterials); i++) {
		AddFileToDownloadsTable(g_szMaterials[i]);
	}
	
	g_cModel = PrecacheModel("materials/sprites/laserbeam.vmt");

}


bool _IsStackFull(int entity) {
	int ent;
	for (int i = 0; i < MAX_PROJECTILES; i++) {
		ent = EntRefToEntIndex(g_iStack[entity][i]);
		if( ent <= 0 || !IsValidEdict(ent) || !IsValidEntity(ent) )
			return false;
	}
	
	return true;
}
bool _IsStackEmpty(int entity) {
	int ent;
	for (int i = 0; i < MAX_PROJECTILES; i++) {
		ent = EntRefToEntIndex(g_iStack[entity][i]);
		if( ent > 0 && IsValidEdict(ent) && IsValidEntity(ent) )
			return false;
	}
	
	return true;
}
void _pushStack(int entity, int projectile) {
	int ent;
	for (int i = 0; i < MAX_PROJECTILES; i++) {
		ent = EntRefToEntIndex(g_iStack[entity][i]);
		if( ent <= 0 || !IsValidEdict(ent) || !IsValidEntity(ent) ) {
			g_iStack[entity][i] = EntIndexToEntRef(projectile);
			
			Handle dp;
			CreateDataTimer(REMOVE_AFTER, _popStack, dp, TIMER_DATA_HNDL_CLOSE);
			WritePackCell(dp, entity);
			WritePackCell(dp, g_iStack[entity][i]);
			WritePackCell(dp, i);
			return;
		}
	}
}
public Action _popStack(Handle timer, Handle dp) {
	ResetPack(dp);
	int entity = ReadPackCell(dp);
	int ent = EntRefToEntIndex(ReadPackCell(dp));
	int i = ReadPackCell(dp);
	
	if( ent > 0 && IsValidEdict(ent) && IsValidEntity(ent) ) {
		g_iStack[entity][i] = INVALID_ENT_REFERENCE;
		AcceptEntityInput(ent, "Kill");
	}
	
	return Plugin_Stop;
}
