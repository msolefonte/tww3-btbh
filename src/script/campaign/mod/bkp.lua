local active_wars = {};
local config = {
  time_beetween_offers = 5;
  treshold_battles = 3,
  treshold_duration = 10,
  treshold_win_ratio = 30,
  logging_enabled = true
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

-- BRING THE BOYS HOME --

-- local function update_war_stats_after_battle(winner_character)
--   local player_faction_key = cm:get_human_factions()[1];  -- TODO What if MP
--   local player_faction = cm:model():world():faction_by_key(player_faction_key);
--
--   if winner_character:faction():is_human() then
--     local turn_number = cm:model():turn_number();
--     local loser_value_threshold = 3000 * math.ceil(turn_number / 25);
--     if loser_value_threshold > 9000 then loser_value_threshold = 9000 end
--
--     local defeated_faction = "none";
--     local defeated_side_strength = 0;
--
--     local last_battle_had_ai_garrison = false;
--     local last_battle = cm:model():pending_battle();
--     --Was the battle at a settlement?
--     if(last_battle:has_contested_garrison()) then
--       local garrison_residence = last_battle:contested_garrison()
--       if not garrison_residence:faction():is_human() then
--         --btbh_log("Last battle included an AI garrison.")
--         last_battle_had_ai_garrison = true
--       end
--     end
--
--     if cm:pending_battle_cache_human_is_attacker() then
--       --player was the attacker
--       --btbh_log("Player was attacker.")
--       if last_battle_had_ai_garrison and cm:pending_battle_cache_num_defenders() == 1 then
--         btbh_log("Last battle was against an AI garrison alone. It does not count.");
--         return;
--       end
--       defeated_faction = jget_short(cm:pending_battle_cache_get_defender_faction_name(1))
--       defeated_side_strength = cm:pending_battle_cache_defender_value()
--     elseif  cm:pending_battle_cache_human_is_defender() then
--       --player was the defender
--       --btbh_log("Player was defender.")
--       defeated_faction = jget_short(cm:pending_battle_cache_get_attacker_faction_name(1))
--       defeated_side_strength = cm:pending_battle_cache_attacker_value()
--     else
--       btbh_log("Human was involved but neither attacker nor defender.")
--     end
--
--     if (defeated_faction ~= "none") and (defeated_side_strength >= loser_value_threshold) then
--       btbh_log("Player lord won a battle against faction: "..defeated_faction.." Value: "..(defeated_side_strength))
--       if cm:get_saved_value("btbh_losses_"..(defeated_faction)) then
--         local losses = cm:get_saved_value("btbh_losses_"..(defeated_faction))
--         cm:set_saved_value("btbh_losses_"..(defeated_faction), (losses+1))
--       else
--         cm:set_saved_value("btbh_losses_"..(defeated_faction), 1)
--       end
--     elseif (defeated_faction ~= "none") and (defeated_side_strength < loser_value_threshold) then
--       btbh_log("Defeated side was too weak for the battle to count. "..(defeated_side_strength))
--     else
--       btbh_log("Player lord won a battle but defeated faction is not valid")
--     end
--   -- elseif winner_character:faction():at_war_with(player_faction) then -- TODO Remove so it works for MP
--   --   --btbh_log("BTBH_LordWonBattle AI at war with player")
--   --   --battle winner is AI and at war with player
--   --   if cm:pending_battle_cache_human_is_involved() then
--   --     --AI that is at war with player was also actually fighting the player in the last battle
--   --     btbh_log("AI lord won a battle against player")
--   --     local ai_faction_short = jget_short(chracter:faction():name())
--   --     if (ai_faction_short ~= "none") then
--   --       if cm:get_saved_value("btbh_wins_"..ai_faction_short) then
--   --         local wins = cm:get_saved_value("btbh_wins_"..ai_faction_short)
--   --         cm:set_saved_value("btbh_wins_"..ai_faction_short, (wins+1))
--   --       else
--   --         cm:set_saved_value("btbh_wins_"..ai_faction_short, 1)
--   --       end
--   --     end
--   --   end
--   else
--     btbh_log("AI lord won a battle")
--     local winner = get_shorter_name(winner_character:faction():name())
--     local loser = cm:pending_battle_cache_get_defender_faction_name(1)
--     if (ai_faction_short ~= "none") then
--       if cm:get_saved_value("btbh_wins_"..ai_faction_short) then
--         local wins = cm:get_saved_value("btbh_wins_"..ai_faction_short)
--         cm:set_saved_value("btbh_wins_"..ai_faction_short, (wins+1))
--       else
--         cm:set_saved_value("btbh_wins_"..ai_faction_short, 1)
--       end
--     end
--   end
-- end

local function update_all_active_wars_duration()
  btbh_log("Updating war duration for all active wars");
  for _, enemy_factions in pairs(active_wars) do
    for _, war_stats in pairs(enemy_factions) do
      war_stats["duration"] = war_stats["duration"] + 1;
    end
  end
end

local function _delete_active_war(faction_a, faction_b)
  if active_wars[faction_a] ~= nil then
    active_wars[faction_a][faction_b] = nil;

    local next = next;
    if next(active_wars[faction_a]) == nil then
      active_wars[faction_a] = nil;
    end
  end
end

local function clean_war_stats(faction_a, faction_b, reason)
  btbh_log("Reseting stats for " .. faction_a .. " vs " .. faction_b .. " (reason: " .. reason .. ")");
  _delete_active_war(faction_a, faction_b);
  _delete_active_war(faction_b, faction_a);
end

local function send_required_peace_treaty_requests(faction_name)
  if active_wars[faction_name] ~= nil then
    for enemy_faction_name, war_stats in pairs(active_wars[faction_name]) do
      local duration, wins, losses = war_stats["duration"], war_stats["wins"], war_stats["losses"];
      btbh_log(faction_name .. " vs " .. enemy_faction_name .. " war stats");
      btbh_log("Duration: " ..duration ..  " | Wins: " .. wins  .. " | Losses: " .. losses)
      if duration > get_config("treshold_duration") and wins + losses >= get_config("treshold_battles") then
        local win_ratio =  wins / (wins * losses) * 100;
        local turn_number = cm:model():turn_number();

        if win_ratio < get_config("treshold_win_ratio") and
           war_stats["last_offer"] <= turn_number - get_config("time_beetween_offers") then
          btbh_log("Faction " .. faction_name .. " will sue " .. enemy_faction_name .. " for peace");
          cm:faction_offers_peace_to_other_faction(faction_name, enemy_faction_name);
          war_stats["last_offer"] = turn_number;
        end
      end
    end
  end
end

-- LISTENERS --

local function add_listeners()
  --general won a battle: count victories if it's either the player or an AI that defeated the player
  core:add_listener(
    "BTBH_LordWonBattle",
    "CharacterCompletedBattle",
    function(context)
      return cm:character_is_army_commander(context:character()) and context:character():won_battle();
    end,
    function(context)
      update_war_stats_after_battle(context:character());
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
      clean_war_stats(context:proposer():name(), context:recipient():name(), "Peace treaty signed");
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
      clean_war_stats(context:proposer():name(), context:recipient():name(), "War declared");
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
