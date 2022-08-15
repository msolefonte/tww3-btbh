--logging
local function JADLOG(text)
  if not (__write_output_to_logfile or __enable_jadlog) then
    return;
  end
  local logText = tostring(text)
  local logTimeStamp = os.date("%d, %m %Y %X")
  local popLog = io.open("jadawin_bring_the_boys_home.txt","a")
  popLog :write("Bring the Boys Home: [".. logTimeStamp .. "]: "..logText .. " \n")
  popLog :flush()
  popLog :close()
end

local function JADSESSIONLOG()
  if not (__write_output_to_logfile or __enable_jadlog) then
    return;
  end
  local logTimeStamp = os.date("%d, %m %Y %X")
  local popLog = io.open("jadawin_bring_the_boys_home.txt","w+")
  popLog :write("NEW LOG ["..logTimeStamp.."] \n")
  popLog :flush()
  popLog :close()
end
JADSESSIONLOG()

local function jlog(text)
  JADLOG(tostring(text))
end

--general won a battle: count victories if it's either the player or an AI that defeated the player
core:add_listener(
  "JBTBH_LordWonBattle",
  "CharacterCompletedBattle",
  function(context)
    return (cm:character_is_army_commander(context:character()) and context:character():won_battle())
  end,
  function(context)
    local player_faction_key = cm:get_human_factions()[1]
    local player_faction = cm:model():world():faction_by_key(player_faction_key)
    local character = context:character()

    if character:faction():is_human() then
      jlog("JBTBH_LordWonBattle Human")
      local defeated_faction = "none"
      local defeated_side_strength = 0
      local turn_number = cm:model():turn_number()
      local loser_value_threshold = 3000 * math.ceil(turn_number / 25)
      if loser_value_threshold > 9000 then loser_value_threshold = 9000 end
      local last_battle_had_ai_garrison = false
      local last_battle = cm:model():pending_battle()
      --Was the battle at a settlement?
      if(last_battle:has_contested_garrison()) then
        local garrison_residence = last_battle:contested_garrison()
        if(not garrison_residence:faction():is_human()) then
          --jlog("Last battle included an AI garrison.")
          last_battle_had_ai_garrison = true
        end
      end

      if cm:pending_battle_cache_human_is_attacker() then
        --player was the attacker
        --jlog("Player was attacker.")
        if last_battle_had_ai_garrison and cm:pending_battle_cache_num_defenders() == 1 then
          jlog("Last battle was against only an AI garrison, does not count.")
          return
        end
        defeated_faction = jget_short(cm:pending_battle_cache_get_defender_faction_name(1))
        defeated_side_strength = cm:pending_battle_cache_defender_value()
      elseif  cm:pending_battle_cache_human_is_defender() then
        --player was the defender
        --jlog("Player was defender.")
        defeated_faction = jget_short(cm:pending_battle_cache_get_attacker_faction_name(1))
        defeated_side_strength = cm:pending_battle_cache_attacker_value()
      else
        jlog("Human was involved but neither attacker nor defender.")
      end
      if (defeated_faction ~= "none") and (defeated_side_strength >= loser_value_threshold) then
        jlog("Player lord won a battle against faction: "..(jget_long(defeated_faction)).." Value: "..(defeated_side_strength))
        if cm:get_saved_value("btbh_losses_"..(defeated_faction)) then
          local losses = cm:get_saved_value("btbh_losses_"..(defeated_faction))
          cm:set_saved_value("btbh_losses_"..(defeated_faction), (losses+1))
        else
          cm:set_saved_value("btbh_losses_"..(defeated_faction), 1)
        end
      elseif (defeated_faction ~= "none") and (defeated_side_strength < loser_value_threshold) then
        jlog("Defeated side was too weak for the battle to count. "..(defeated_side_strength))
      else
        jlog("Player lord won a battle but defeated faction is not valid")
      end
    elseif character:faction():at_war_with(player_faction) then
      --jlog("JBTBH_LordWonBattle AI at war with player")
      --battle winner is AI and at war with player
      if cm:pending_battle_cache_human_is_involved() then
        --AI that is at war with player was also actually fighting the player in the last battle
        jlog("AI lord won a battle against player.")
        local ai_faction_short = jget_short(context:character():faction():name())
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
  end,
  true
)

--Player TurnStart: Count up the war duration counter for all current wars
core:add_listener(
  "JBTBH_PlayerTurnStart",
  "FactionTurnStart",
  function(context) return (context:faction():is_human()) end,
  function(context)
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
  end,
  true
)

--PeaceTreatySigned: Reset war duration counters
core:add_listener(
  "JBTBH_PeaceTreatySigned",
  "PositiveDiplomaticEvent",
  function(context) return ((context:is_peace_treaty()) and (context:proposer():is_human() or context:recipient():is_human())) end,
  function(context)
    --jlog("JBTBH_PeaceTreatySigned")
    local ai_faction_key = "none"
    if not context:proposer():is_human() then
      ai_faction_key = context:proposer():name()
    elseif not context:recipient():is_human() then
      ai_faction_key = context:recipient():name()
    end
    if (jget_short(ai_faction_key) ~= "none") then
      --reset war duration
      jlog("Peace treaty signed. Reset war duration, wins and losses for "..ai_faction_key)
      cm:set_saved_value("btbh_dur_"..(jget_short(ai_faction_key)), false)
      cm:set_saved_value("btbh_wins_"..(jget_short(ai_faction_key)), false)
      cm:set_saved_value("btbh_losses_"..(jget_short(ai_faction_key)), false)
    else
      jlog("Cannot reset war duration because AI faction "..ai_faction_key.." is not valid.")
    end
  end,
  true
)

--WarDeclared: Reset war duration counters (in case a faction was destroyed but later comes back to life, so no peace treaty was ever signed)
core:add_listener(
  "JBTBH_WarDeclared",
  "NegativeDiplomaticEvent",
  function(context) return ((context:is_war()) and (context:proposer():is_human() or context:recipient():is_human())) end,
  function(context)
    --jlog("JBTBH_WarDeclared")
    local ai_faction_key = "none"
    if not context:proposer():is_human() then
      ai_faction_key = context:proposer():name()
    elseif not context:recipient():is_human() then
      ai_faction_key = context:recipient():name()
    end
    if (jget_short(ai_faction_key) ~= "none") then
      --reset war duration
      jlog("War declared. Reset war duration, wins and losses for "..ai_faction_key)
      cm:set_saved_value("btbh_dur_"..(jget_short(ai_faction_key)), false)
      cm:set_saved_value("btbh_wins_"..(jget_short(ai_faction_key)), false)
      cm:set_saved_value("btbh_losses_"..(jget_short(ai_faction_key)), false)
    else
      jlog("Cannot reset war duration because AI faction "..ai_faction_key.." is not valid.")
    end
  end,
  true
)


--AI TurnStart: Offer peace if conditions are met
core:add_listener(
  "JBTBH_AITurnStart",
  "FactionTurnStart",
  function(context) return not(context:faction():is_human()) end,
  function(context)
    local player_faction_key = cm:get_human_factions()[1]
    local player_faction = cm:model():world():faction_by_key(player_faction_key)
    local ai_faction = context:faction()
    local turn_number = cm:model():turn_number()
    if ai_faction:at_war_with(player_faction) then
      --jlog("JBTBH_AITurnStart At war with player")
      local war_duration = cm:get_saved_value("btbh_dur_"..(jget_short(ai_faction:name())))
      local wins_against_player = cm:get_saved_value("btbh_wins_"..(jget_short(ai_faction:name())))
      local losses_against_player = cm:get_saved_value("btbh_losses_"..(jget_short(ai_faction:name())))
      if not wins_against_player then wins_against_player = 0 end
      if not losses_against_player then losses_against_player = 0 end
      if war_duration then
        jlog((ai_faction:name()).." war data: Duration "..(war_duration).."| Wins "..(wins_against_player).."| Losses "..(losses_against_player).."|")
        if war_duration > 10 and ((wins_against_player + losses_against_player) >= 3) then
          local win_ratio = 1
          if losses_against_player > 0 then
            win_ratio = (wins_against_player / (wins_against_player + losses_against_player))
            jlog("Win ratio against player: "..(win_ratio).." in battles: "..(wins_against_player + losses_against_player))
            local turn_next_peace_offer = turn_number
            if cm:get_saved_value("btbh_wait_"..(jget_short(ai_faction:name()))) then
              turn_next_peace_offer = (cm:get_saved_value("btbh_wait_"..(jget_short(ai_faction:name()))) + 5)
            end
            if win_ratio < 0.3 and (turn_next_peace_offer <= turn_number) then
              cm:faction_offers_peace_to_other_faction(ai_faction:name(), player_faction_key)
              --set wait counter (current turn number) so AI does not sue for peace every turn
              cm:set_saved_value("btbh_wait_"..(jget_short(ai_faction:name())), turn_number)
            elseif win_ratio < 0.3 then
              jlog("AI would sue for peace but wait counter has not expired yet.")
            end
          end
        else
          --jlog("War duration ("..(war_duration)..") or number of wins/losses ("..(wins_against_player + losses_against_player)..") too low to consider suing for peace.")
        end
      else
        --jlog("No war duration stored for faction ["..(ai_faction:name()).."]. Either first turn of war or not an eligible faction.")
      end
    end
  end,
  true
)
