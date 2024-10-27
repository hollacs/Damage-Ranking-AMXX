#if defined _damage_rank_included
	#endinput
#endif
#define _damage_rank_included

/*
 * 在排名更新時會被呼叫
 */
forward dmgrank_on_update();

/**
 * 獲取玩家的傷害排名位置
 * @param id    	玩家id
 * @return          位置
 */
native dmgrank_get_rank(id);

/**
 * 獲取玩家的累積傷害
 * @param id    	玩家id
 * @return          位置
 */
native Float:dmgrank_get_damage(id);

/**
 * 增加玩家的累積傷害
 * @param index    	位置
 * @param damage 	增加的傷害
 * @return          玩家id
 */
native dmgrank_add_damage(id, Float:damage);

/**
 * 獲取指定一個傷害排名位置中的玩家
 * @param index    	位置
 * @return          玩家id
 */
native dmgrank_at(index);

/**
 * 獲取傷害排名最大顯示數量
 * @return          數量
 */
native dmgrank_count()

/**
 * 顯示個人設定選單
 * @param id		玩家id
 * @noreturn     
 */
native dmgrank_show_menu(id);
