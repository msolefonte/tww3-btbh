local active_wars = {};

-- GENERIC --

local function persist_table(table_name, t, callback)
    cm:add_saving_game_callback(function(context) cm:save_named_value("btbh_"..table_name, t, context) end);
    cm:add_loading_game_callback(function(context)
        local loaded_table = cm:load_named_value("btbh_"..table_name, t, context);
        callback(loaded_table);
    end);
end

local function log(str)
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

local function get_shorter_name(faction_name)
  local shortened_name = "";

  local separator_found = false;
  local separator_count, char_count = 0, 0;
  faction_name:gsub(".", function(chr)
    if chr == "_"  or chr == "-" then
      separator_found = true;
      separator_count = separator_count + 1;
      char_count = 0;
    elseif separator_found and separator_count >= 2 then
      shortened_name = shortened_name .. chr;
      if char_count >= 3 then
        separator_found = false;
      else
        char_count = char_count + 1;
      end
    end
  end);

  return shortened_name;
end

-- WAR STATS --

-- local function update_war_stats(faction_key, duration, wins, losses)
--   local war_stats = { duration = duration, wins = wins, losses = losses };
--   cm:set_saved_value("btbh_" .. get_shorter_name(faction_key)), war_stats);
-- end
--
-- local function reset_war_stats(faction_key)
--   cm:set_saved_value("btbh_" .. get_shorter_name(faction_key)), false);
-- end

-- BRING THE BOYS HOME --

local function update_stats_after_battle(winner_character)
  local player_faction_key = cm:get_human_factions()[1];  -- TODO What if MP
  local player_faction = cm:model():world():faction_by_key(player_faction_key);

  if winner_character:faction():is_human() then
    local turn_number = cm:model():turn_number();
    local loser_value_threshold = 3000 * math.ceil(turn_number / 25);
    if loser_value_threshold > 9000 then loser_value_threshold = 9000 end

    local defeated_faction = "none";
    local defeated_side_strength = 0;

    local last_battle_had_ai_garrison = false;
    local last_battle = cm:model():pending_battle();
    --Was the battle at a settlement?
    if(last_battle:has_contested_garrison()) then
      local garrison_residence = last_battle:contested_garrison()
      if not garrison_residence:faction():is_human() then
        --log("Last battle included an AI garrison.")
        last_battle_had_ai_garrison = true
      end
    end

    if cm:pending_battle_cache_human_is_attacker() then
      --player was the attacker
      --log("Player was attacker.")
      if last_battle_had_ai_garrison and cm:pending_battle_cache_num_defenders() == 1 then
        log("Last battle was against an AI garrison alone. It does not count.");
        return;
      end
      defeated_faction = jget_short(cm:pending_battle_cache_get_defender_faction_name(1))
      defeated_side_strength = cm:pending_battle_cache_defender_value()
    elseif  cm:pending_battle_cache_human_is_defender() then
      --player was the defender
      --log("Player was defender.")
      defeated_faction = jget_short(cm:pending_battle_cache_get_attacker_faction_name(1))
      defeated_side_strength = cm:pending_battle_cache_attacker_value()
    else
      log("Human was involved but neither attacker nor defender.")
    end

    if (defeated_faction ~= "none") and (defeated_side_strength >= loser_value_threshold) then
      log("Player lord won a battle against faction: "..defeated_faction.." Value: "..(defeated_side_strength))
      if cm:get_saved_value("btbh_losses_"..(defeated_faction)) then
        local losses = cm:get_saved_value("btbh_losses_"..(defeated_faction))
        cm:set_saved_value("btbh_losses_"..(defeated_faction), (losses+1))
      else
        cm:set_saved_value("btbh_losses_"..(defeated_faction), 1)
      end
    elseif (defeated_faction ~= "none") and (defeated_side_strength < loser_value_threshold) then
      log("Defeated side was too weak for the battle to count. "..(defeated_side_strength))
    else
      log("Player lord won a battle but defeated faction is not valid")
    end
  -- elseif winner_character:faction():at_war_with(player_faction) then -- TODO Remove so it works for MP
  --   --log("BTBH_LordWonBattle AI at war with player")
  --   --battle winner is AI and at war with player
  --   if cm:pending_battle_cache_human_is_involved() then
  --     --AI that is at war with player was also actually fighting the player in the last battle
  --     log("AI lord won a battle against player")
  --     local ai_faction_short = jget_short(chracter:faction():name())
  --     if (ai_faction_short ~= "none") then
  --       if cm:get_saved_value("btbh_wins_"..ai_faction_short) then
  --         local wins = cm:get_saved_value("btbh_wins_"..ai_faction_short)
  --         cm:set_saved_value("btbh_wins_"..ai_faction_short, (wins+1))
  --       else
  --         cm:set_saved_value("btbh_wins_"..ai_faction_short, 1)
  --       end
  --     end
  --   end
  else
    log("AI lord won a battle")
    local ai_faction_short = get_shorter_name(winner_character:faction():name())
    if (ai_faction_short ~= "none") then
      if cm:get_saved_value("btbh_wins_"..ai_faction_short) then
        local wins = cm:get_saved_value("btbh_wins_"..ai_faction_short)
        cm:set_saved_value("btbh_wins_"..ai_faction_short, (wins+1))
      else
        cm:set_saved_value("btbh_wins_"..ai_faction_short, 1)
      end
    end
  end
end

local function BTBH_PlayerTurnStart(context)
  local turn_number = cm:model():turn_number()
  jlog("----------JBTBH_PlayerTurnStart ["..(turn_number).."] ----------")
  local player_faction = context:faction()
  local war_factions = player_faction:factions_at_war_with()
  local current_faction_key = ""
  local duration = false
  for i=0, war_factions:num_items()-1 do
    current_faction_key = war_factions:item_at(i):name()
    duration = false
    --jlog("Checking faction: "..(current_faction_key))
    if jget_short(current_faction_key) ~= "none" then
      duration = cm:get_saved_value("btbh_dur_"..(jget_short(current_faction_key)))
      if duration then
        duration = duration + 1
        cm:set_saved_value("btbh_dur_"..(jget_short(current_faction_key)), duration)
      else
        duration = 1
        cm:set_saved_value("btbh_dur_"..(jget_short(current_faction_key)), duration)
      end
      jlog("["..current_faction_key.."] War duration: "..duration)
    end
  end
end

local function BTBH_PeaceTreatySigned(context)
  --log("BTBH_PeaceTreatySigned")
  local ai_faction_key = "none"
  if not context:proposer():is_human() then
    ai_faction_key = context:proposer():name()
  elseif not context:recipient():is_human() then
    ai_faction_key = context:recipient():name()
  end
  if (jget_short(ai_faction_key) ~= "none") then
    --reset war duration
    log("Peace treaty signed. Reset war duration, wins and losses for "..ai_faction_key)
    reset_war_stats(ai_faction_key);
  else
    log("Cannot reset war duration because AI faction "..ai_faction_key.." is not valid.")
  end
end

local function BTBH_WarDeclared(context)
  --log("BTBH_WarDeclared")
  local ai_faction_key = "none"
  if not context:proposer():is_human() then
    ai_faction_key = context:proposer():name()
  elseif not context:recipient():is_human() then
    ai_faction_key = context:recipient():name()
  end
  if (jget_short(ai_faction_key) ~= "none") then
    --reset war duration
    log("War declared. Reset war duration, wins and losses for "..ai_faction_key)
    reset_war_stats(ai_faction_key);
  else
    log("Cannot reset war duration because AI faction "..ai_faction_key.." is not valid.")
  end
end

local function BTBH_AITurnStart(ai_faction)
  local player_faction_key = cm:get_human_factions()[1]
  local player_faction = cm:model():world():faction_by_key(player_faction_key)
  local turn_number = cm:model():turn_number()
  if ai_faction:at_war_with(player_faction) then
    --log("BTBH_AITurnStart At war with player")
    local war_duration = cm:get_saved_value("btbh_dur_"..(jget_short(ai_faction:name())))
    local wins_against_player = cm:get_saved_value("btbh_wins_"..(jget_short(ai_faction:name())))
    local losses_against_player = cm:get_saved_value("btbh_losses_"..(jget_short(ai_faction:name())))
    if not wins_against_player then wins_against_player = 0 end
    if not losses_against_player then losses_against_player = 0 end
    if war_duration then
      log((ai_faction:name()).." war data: Duration "..(war_duration).."| Wins "..(wins_against_player).."| Losses "..(losses_against_player).."|")
      if war_duration > 10 and ((wins_against_player + losses_against_player) >= 3) then
        local win_ratio = 1
        if losses_against_player > 0 then
          win_ratio = (wins_against_player / (wins_against_player + losses_against_player))
          log("Win ratio against player: "..(win_ratio).." in battles: "..(wins_against_player + losses_against_player))
          local turn_next_peace_offer = turn_number
          if cm:get_saved_value("btbh_wait_"..(jget_short(ai_faction:name()))) then
            turn_next_peace_offer = (cm:get_saved_value("btbh_wait_"..(jget_short(ai_faction:name()))) + 5)
          end
          if win_ratio < 0.3 and (turn_next_peace_offer <= turn_number) then
            cm:faction_offers_peace_to_other_faction(ai_faction:name(), player_faction_key)
            --set wait counter (current turn number) so AI does not sue for peace every turn
            cm:set_saved_value("btbh_wait_"..(jget_short(ai_faction:name())), turn_number)
          elseif win_ratio < 0.3 then
            log("AI would sue for peace but wait counter has not expired yet.")
          end
        end
      else
        --log("War duration ("..(war_duration)..") or number of wins/losses ("..(wins_against_player + losses_against_player)..") too low to consider suing for peace.")
      end
    else
      --log("No war duration stored for faction ["..(ai_faction:name()).."]. Either first turn of war or not an eligible faction.")
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
      update_stats_after_battle(context:character());
    end,
    true
  )

  --PeaceTreatySigned: Reset war duration counters
  core:add_listener(
    "BTBH_PeaceTreatySigned",
    "PositiveDiplomaticEvent",
    function(context)
      return context:is_peace_treaty() and (context:proposer():is_human() or context:recipient():is_human());
    end,
    function(context)
        BTBH_PeaceTreatySigned(context)
    end,
    true
  )

  --Player TurnStart: Count up the war duration counter for all current wars
  core:add_listener(
    "BTBH_PlayerTurnStart",
    "FactionTurnStart",
    function(context) return (context:faction():is_human()) end,
    function(context)
      BTBH_PlayerTurnStart(context);
    end,
    true
  )

  --WarDeclared: Reset war duration counters (in case a faction was destroyed but later comes back to life, so no peace treaty was ever signed)
  core:add_listener(
    "BTBH_WarDeclared",
    "NegativeDiplomaticEvent",
    function(context)
      return context:is_war() and (context:proposer():is_human() or context:recipient():is_human());
    end,
    function(context)
      BTBH_WarDeclared(context)
    end,
    true
  )

  --AI TurnStart: Offer peace if conditions are met
  core:add_listener(
    "BTBH_AITurnStart",
    "FactionTurnStart",
    function(context)
      return not context:faction():is_human();
    end,
    function(context)
      BTBH_AITurnStart(context:faction());
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
