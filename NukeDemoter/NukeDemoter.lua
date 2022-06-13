_addon.author = 'RolandJ'
_addon.version = '1.0.0'
_addon.commands = {'nukedemoter', 'ndemoter', 'demoter', 'nd'}

-- Local libraries used throughout addon
local packets = require('packets')
local res = require('resources')
local demoter_arrays = require('DemoterArrays')

-- Local vars used throughout addon
local active = true
local mixed = false
local debugMode = false
local logSource = '[NukeDemoter] '

-- Local logging function for debugMode
local logger = function(color, message)
	if debugMode then
		windower.add_to_chat(color, logSource .. message)
	end
end

-- Code to demote spells as their packet is being generated
windower.register_event('outgoing chunk', function(id, data, modified, injected, blocked)
	-- Return out if demoter is off
	if not active then return end

	-- Action Packets (See Windower/addons/libs/packets/data.lua)
	if id == 0x01A then
		local parsed = packets.parse('outgoing', data)
		--windower.add_to_chat(8, 'outgoing packet:\n' .. tostring(parsed))
		if parsed.Category == 3 then --"Magic cast" category
			local spell = res.spells[parsed.Param] --parsed.Param is the spell id
			local spell_recasts = windower.ffxi.get_spell_recasts()
			
			-- Process Spells Waiting on Recast
			if spell_recasts[spell.id] > 0 then
			
				-- Get Kind Array & Index
				local kind_array = demoter_arrays.kind_arrays[spell.english:split(' ')[1] .. (mixed and 'Mixed' or '')]
				local kind_index = table.find(kind_array and kind_array or {}, spell.english) --error handling
				
				-- Return Out if No Kind Array (These are spell kinds we are not demoting)
				if kind_index == nil then
					return logger(8, 'The spell "' .. spell.english .. '" is awaiting recast but not demotable...')
				end
				
				-- Demote Until a Plyaer-Ready-to-Cast Tier is Found
				local player_spells = windower.ffxi.get_spells() --{[id] = true/false}
				if kind_index > 1 then
					local index = kind_index - 1 --look behind (-1)
					for i = index , 1, -1 do --iterate backwards, demoting
						-- Get Potential Demoted Spell
						local new_spell = {
							['id'] = demoter_arrays.spell_ids_by_name[kind_array[i]],
							['english'] = kind_array[i],
						}
						
						if player_spells[new_spell.id] then
							if spell_recasts[new_spell.id] == 0 then
								logger(8, 'Demoted "' .. spell.english .. '" to "' .. new_spell.english .. '"...')
								parsed.Param = new_spell.id -- CREDIT: Masunasu (FFXIAH)
								return packets.build(parsed) -- CREDIT: Masunasu (FFXIAH)
							end
						else
							logger(8, 'Player does not know "' .. new_spell.english .. '".')
						end
					end
				else
					return logger(8, 'Cannot demote "' .. spell.english .. '" further...')
				end
			end
		end
	end
end)

-- Command Handler for NukeDemoter
windower.register_event('addon command', function(...)
	local cmd = T{...}
	
	-- Prepare chat color definitions
	local green = 158
	local red = 123
	local grey = 8
	
	if table.contains({'toggle', 'flip', 'switch'}, cmd[1]:lower()) then
		active = not active
		windower.add_to_chat(active and green or red, logSource .. 'Spell Demotion ' .. (active and 'Activated' or 'Deactivated'))
	elseif table.contains({'on', 'activate', 'enable', 'start', 'begin', 'unpause'}, cmd[1]:lower()) then
		active = true
		windower.add_to_chat(green, logSource .. 'Spell Demotion Activated')
	elseif table.contains({'off', 'deactivate', 'disable', 'stop', 'end', 'pause'}, cmd[1]:lower()) then
		active = false
		windower.add_to_chat(red, logSource .. 'Spell Demotion Deactivated')
	elseif table.contains({'mixed', 'mix'}, cmd[1]:lower()) then
		mixed = not mixed
		windower.add_to_chat(mixed and green or red, logSource .. 'Mixed Single/AoE Demoting ' .. (mixed and 'Activated' or 'Deactivated'))
		if mixed then windower.add_to_chat(red, 'WARNING: Only use this mode when it is safe to AoE and recast mitigation is needed.') end
	elseif table.contains({'debug', 'debugmode'}, cmd[1]:lower()) then
		debugMode = not debugMode
		windower.add_to_chat(grey, logSource.. 'Debug Mode ' .. (active and 'activated' or 'deactivated') .. '...')
	elseif table.contains({'config', 'settings'}, cmd[1]:lower()) then
        windower.add_to_chat(grey, 'NukeDemoter  settings:')
        windower.add_to_chat(grey, '    active     - '..tostring(active))
        windower.add_to_chat(grey, '    mixed      - '..tostring(mixed))
	else
        windower.add_to_chat(grey, 'NukeDemoter  v' .. _addon.version .. ' commands:')
        windower.add_to_chat(grey, '//nd [command]')
        windower.add_to_chat(grey, '    toggle   - Toggles NukeDemoter ON or OFF')
        windower.add_to_chat(grey, '    mixed    - Demotes nukes to AoE variants based on relative potency (CAUTION!)')
        windower.add_to_chat(grey, '    help     - Displays this help text')
        windower.add_to_chat(grey, ' ')
        windower.add_to_chat(grey, 'NOTE: NukeDemoter will only degrade to known spells and only while it is active.')
	end
end)