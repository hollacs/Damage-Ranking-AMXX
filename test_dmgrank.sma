#include <amxmodx>
#include <damage_rank>

public plugin_init()
{
	register_clcmd("test", "cmdTest");
}

public dmgrank_on_update() server_print("dmgrank updated");

public cmdTest(id)
{
	dmgrank_add_damage(id, 999.0);
	
	client_print(id, print_console, "rank:%d | dmg:%.f", 
		dmgrank_get_rank(id), dmgrank_get_damage(id));

	new player, count = dmgrank_count();

	for (new i = 1; i <= count; i++)
	{
		player = dmgrank_at(i);
		client_print(id, print_console, "#%d | %s (%f)", 
			i, 
			player ? fmt("%n", player) : "---",
			player ? dmgrank_get_damage(player) : 0.0);
	}

	dmgrank_show_menu(id);
}