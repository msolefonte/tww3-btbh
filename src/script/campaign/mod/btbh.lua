local active_wars = {};
local config = {
  time_beetween_offers = 5,
  threshold_battles = 0,
  threshold_duration = 10,
  threshold_loss_value = 3000,
  threshold_war_exhaustion = 70,
  logging_enabled = false
};

-- GENERIC --

local function persist_table(table_name, t, callback)
    cm:add_saving_game_callback(function(context) cm:save_named_value("btbh_"..table_name, t, context) end);
    cm:add_loading_game_callback(function(context)
        local loaded_table = cm:load_named_value("btbh_"..table_name, t, context);
        callback(loaded_table);
    end);
end

local function btbh_log(str)
  if get_config("logging_enabled") then
    out("[wolfy][btbh] " .. str);
  end
end

local function get_config(config_key)
  if get_mct then
    local mct = get_mct();

    if mct ~= nil then
      local mod_cfg = mct:get_mod_by_key("wolfy_bring_the_boys_home");
      return mod_cfg:get_option_by_key(config_key):get_finalized_setting();
    end
  end

  return config[config_key];
end

-- ACTIVE WARS --

local function aw_create_entry(faction_key, enemy_faction_key)
  if active_wars[faction_key] == nil then
    active_wars[faction_key] = { [enemy_faction_key] = { duration = 0, wins = 0, losses = 0, last_offer = 0 } };
  else
    active_wars[faction_key][enemy_faction_key] = { duration = 0, wins = 0, losses = 0, last_offer = 0 };
  end
end

local function aw_delete_entry(faction_key, enemy_faction_key)
  if active_wars[faction_key] ~= nil then
    active_wars[faction_key][enemy_faction_key] = nil;

    local next = next;
    if next(active_wars[faction_key]) == nil then
      active_wars[faction_key] = nil;
    end
  end
end

local function aw_add_defeat(faction_key, enemy_faction_key)
  if active_wars[faction_key] == nil then
    active_wars[faction_key] = { [enemy_faction_key] = { duration = 0, wins = 0, losses = 1, last_offer = 0 } };
  elseif active_wars[faction_key][enemy_faction_key] == nil then
    active_wars[faction_key][enemy_faction_key] = { duration = 0, wins = 0, losses = 1, last_offer = 0 };
  else
    active_wars[faction_key][enemy_faction_key][losses] = active_wars[enemy_faction_key][faction_key][losses] + 1;
  end
end

local function aw_add_victory(faction_key, enemy_faction_key)
  if active_wars[faction_key] == nil then
    active_wars[faction_key] = { [enemy_faction_key] = { duration = 0, wins = 1, losses = 0, last_offer = 0 } };
  elseif active_wars[faction_key][enemy_faction_key] == nil then
    active_wars[faction_key][enemy_faction_key] = { duration = 0, wins = 1, losses = 0, last_offer = 0 };
  else
    active_wars[faction_key][enemy_faction_key][wins] = active_wars[faction_key][enemy_faction_key][wins] + 1;
  end
end

-- BRING THE BOYS HOME --

local function update_war_stats_after_battle(winner_faction)
  local winner_faction_key = winner_faction:name();
  local defeated_faction_key, defeated_side_strength;

  if cm:pending_battle_cache_faction_is_attacker(winner_faction_key) then
    defeated_faction_key = cm:pending_battle_cache_get_defender_faction_key(1);
    defeated_side_strength = cm:pending_battle_cache_defender_value();
  elseif cm:pending_battle_cache_faction_is_defender(winner_faction_key) then
    defeated_faction_key = cm:pending_battle_cache_get_attacker_faction_key(1);
    defeated_side_strength = cm:pending_battle_cache_attacker_value();
  else
    btbh_log("Faction " .. winner_faction_key .. " won a battle, but it is not attacker nor defender");
    return;
  end

  btbh_log("Faction " .. winner_faction_key .. " won a battle against " .. defeated_faction_key);
  if defeated_side_strength >= get_config("threshold_loss_value") then
    btbh_log("Defeated side strength is over threshold (" .. defeated_side_strength .. "). Proceeding.");
    aw_add_defeat(defeated_faction_key, winner_faction_key);
    aw_add_victory(winner_faction_key, defeated_faction_key);
  else
    btbh_log("Defeated side was too weak for the battle to count (" .. defeated_side_strength .. ")");
  end
end

local function update_all_active_wars_duration()
  btbh_log("Updating war duration for all active wars");
  for _, enemy_factions in pairs(active_wars) do
    for _, war_stats in pairs(enemy_factions) do
      war_stats["duration"] = war_stats["duration"] + 1;
    end
  end
end

local function clean_war_stats(faction_a, faction_b, reason)
  btbh_log("Reseting empty stats for " .. faction_a .. " vs " .. faction_b .. ")");
  aw_delete_entry(faction_a, faction_b);
  aw_delete_entry(faction_b, faction_a);
end

local function reset_war_stats(faction_a, faction_b, reason)
  btbh_log("Creating empty stats for " .. faction_a .. " vs " .. faction_b .. ")");
  aw_create_entry(faction_a, faction_b);
  aw_create_entry(faction_b, faction_a);
end

local function send_required_peace_treaty_requests(faction_key)
  if active_wars[faction_key] ~= nil then
    for enemy_faction_key, war_stats in pairs(active_wars[faction_key]) do
      local duration, wins, losses = war_stats["duration"], war_stats["wins"], war_stats["losses"];
      btbh_log(faction_key .. " vs " .. enemy_faction_key .. " war stats");
      btbh_log("Duration: " .. duration ..  " | Wins: " .. wins  .. " | Losses: " .. losses)
      if duration > get_config("threshold_duration") and wins + losses > get_config("threshold_battles") then
        local war_exhaustion =  losses / (wins + losses) * 100 + duration - 5;
        btbh_log("War Exhaustion: " .. war_exhaustion);

        if war_exhaustion > get_config("threshold_war_exhaustion") then
          local turn_number = cm:model():turn_number();
          if war_stats["last_offer"] <= turn_number - get_config("time_beetween_offers") then
            btbh_log("Faction " .. faction_key .. " will sue " .. enemy_faction_key .. " for peace");
            cm:faction_offers_peace_to_other_faction(faction_key, enemy_faction_key);
            war_stats["last_offer"] = turn_number;
          end
        end
      end
    end
  end
end

-- LISTENERS --

local function add_listeners()
  core:add_listener(
    "BTBH_LordWonBattle",
    "CharacterCompletedBattle",
    function(context)
      return cm:character_is_army_commander(context:character()) and context:character():won_battle();
    end,
    function(context)
      update_war_stats_after_battle(context:character():faction());
    end,
    true
  )

  core:add_listener(
    "BTBH_PeaceTreatySigned",
    "PositiveDiplomaticEvent",
    function(context)
      return context:is_peace_treaty();
    end,
    function(context)
      clean_war_stats(context:proposer():name(), context:recipient():name());
    end,
    true
  )

  core:add_listener(
    "BTBH_WarDeclared",
    "NegativeDiplomaticEvent",
    function(context)
      return context:is_war();
    end,
    function(context)
      reset_war_stats(context:proposer():name(), context:recipient():name());
    end,
    true
  )

  core:add_listener(
    "BTBH_PlayerTurnStart",
    "FactionTurnStart",
    function(context) return (context:faction():is_human()) end,
    update_all_active_wars_duration,
    true
  )

  core:add_listener(
    "BTBH_AITurnStart",
    "FactionTurnStart",
    function(context)
      return not context:faction():is_human();
    end,
    function(context)
      send_required_peace_treaty_requests(context:faction():name());
    end,
    true
  )
end

-- MAIN --

local function main()
  persist_table("active_wars", active_wars, function(t) active_wars = t end);
  add_listeners();
end

main();
