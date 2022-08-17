if not get_mct then return end
local mct = get_mct();

if not mct then return end
local mct_mod = mct:register_mod("wolfy_bring_the_boys_home");

mct_mod:set_title("Bring the Boys Home", false);
mct_mod:set_author("Wolfy & Jadawin");
mct_mod:set_description("No Endless Wars", false);

mct_mod:add_new_section("1-btbh-base", "Base Options", false);

local option_th_duration = mct_mod:add_new_option("threshold_duration", "slider");
option_th_duration:set_text("Minimum War Duration");
option_th_duration:set_tooltip_text("How many turns of war until start considering peace?");
option_th_duration:slider_set_min_max(1, 50);
option_th_duration:slider_set_step_size(1);
option_th_duration:set_default_value(10);

local option_th_battles = mct_mod:add_new_option("threshold_battles", "slider");
option_th_battles:set_text("Minimum War Battles");
option_th_battles:set_tooltip_text("How many battles completed until start considering peace?");
option_th_battles:slider_set_min_max(0, 20);
option_th_battles:slider_set_step_size(1);
option_th_battles:set_default_value(0);

local option_th_exhaustion = mct_mod:add_new_option("threshold_war_exhaustion", "slider");
option_th_exhaustion:set_text("Minimum War Exhaustion");
option_th_exhaustion:set_tooltip_text("How much war exhaustion should force a peace request?\n\n[[col:yellow]]" ..
                                      "War exhaustion formula: losses / (wins + losses) * 100 + duration - 5[[/col]]");
option_th_exhaustion:slider_set_min_max(0, 150);
option_th_exhaustion:slider_set_step_size(5);
option_th_exhaustion:set_default_value(70);

local option_th_value = mct_mod:add_new_option("threshold_loss_value", "slider");
option_th_value:set_text("Minimum Army Cost");
option_th_value:set_tooltip_text("How much should an army cost to be considered for a victory?");
option_th_value:slider_set_min_max(0, 20000);
option_th_value:slider_set_step_size(500);
option_th_value:set_default_value(3000);

local option_btbh_tbo = mct_mod:add_new_option("time_beetween_offers", "slider");
option_btbh_tbo:set_text("Time Between Offers");
option_btbh_tbo:set_tooltip_text("How many turns should AI wait before asking for peace again after a reject?");
option_btbh_tbo:slider_set_min_max(1, 100);
option_btbh_tbo:slider_set_step_size(1);
option_btbh_tbo:set_default_value(5);

mct_mod:add_new_section("2-btbh-ao", "Advanced Options", false);

local option_btbh_logging_enabled = mct_mod:add_new_option("logging_enabled", "checkbox");
option_btbh_logging_enabled:set_text("Enable logging");
option_btbh_logging_enabled:set_tooltip_text("If enabled, a log will be populated as you play. Use it to report bugs!");
option_btbh_logging_enabled:set_default_value(false);
