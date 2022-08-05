_addon.author = 'RolandJ'
_addon.version = '0.0.2'
_addon.commands = {'autows', 'aws'}



-------------------------------------------------------------------------------------------------------------------
-- Setup local variables used throughout this lua.
-------------------------------------------------------------------------------------------------------------------
require('functions')
res = require('resources')
fsDelay = 3
fsTries = 0
fsTriesMax = 30
debugMode = false
local range_mult = {
	[2] = 1.55,
	[3] = 1.490909,
	[4] = 1.44,
	[5] = 1.377778,
	[6] = 1.30,
	[7] = 1.15,
	[8] = 1.25,
	[9] = 1.377778,
	[10] = 1.45,
	[11] = 1.454545454545455,
	[12] = 1.666666666666667,
}

-------------------------------------------------------------------------------------------------------------------
-- Setup local config
-------------------------------------------------------------------------------------------------------------------
config = require('config')
defaults = T{
	ui = T{
		visible = true,
		pos = T{x = 20, y = 20}
	}
}
settings = config.load(defaults)
config.save(settings)



-------------------------------------------------------------------------------------------------------------------
-- Setup local UI
-------------------------------------------------------------------------------------------------------------------
texts = require('texts')
display = texts.new()

function load_settings()
	job_defaults = T{
		active = false,
		tpLimit = 1000,
		wsName = '',
		wsRange = 5,
		minHpp = 10,
	}
	job_settings = config.load('data\\'..windower.ffxi.get_player().main_job..'.xml', job_defaults)
	config.save(job_settings)
	
	display:text(updateDisplayLine())
	display:size(10)
	display:bold(true)
	display:bg_visible(false)
	display:stroke_width(3)
	display:pos(settings.ui.pos.x, settings.ui.pos.y)
	display:show()
	
	self = windower.ffxi.get_mob_by_target('me')
end

local colors = T{
	red    = '255,   0, 0',
	white  = '255, 255, 255',
	green  = '  0, 255, 0',
	yellow = '240, 240, 0'
}

function colorInText(text, color)
	if colors[color] == nil then return print('colorInText issue: color not found') end
	return '\\cs(' .. colors[color] .. ')' .. text .. '\\cr'
end

function updateDisplayLine()
	return display:text(T{
		'Status: ' .. colorInText(job_settings.active and 'on' or 'off', job_settings.active and 'green' or 'red'),
		'WS: ' .. colorInText(job_settings.wsName, 'yellow'),
		'Min TP: ' .. colorInText(job_settings.tpLimit, 'yellow'),
		'Min Mob HP: ' .. colorInText(job_settings.minHpp .. '%', 'red'),
		'Max WS Range: ' .. colorInText(job_settings.wsRange, 'red'),
	}:concat('    '))
end



-------------------------------------------------------------------------------------------------------------------
-- Check current scenario for AWS triggers
-------------------------------------------------------------------------------------------------------------------
checkAwsTriggers = function()
	local player = windower.ffxi.get_player()
	local playerIsEngaged = player and player.status == 1 or false
	local target = windower.ffxi.get_mob_by_target('t')
	
	--print(windower.ffxi.get_mob_by_target('me').model_size + (res.weapon_skills[35].range * range_mult[res.weapon_skills[35].range]) + target.model_size)
	--t.model_size + ability_distance * range_mult[ability_distance] + s.model_size
	
	-- Skip AWS inactive OR no target OR player is disengaged
	if target == nil then return end
	if not job_settings.active then return end
	if not playerIsEngaged then return end
	
	if debugMode then windower.add_to_chat(8, "[AutoWS] checkAwsTriggers executing...") end
	
	-- Standard Auto WS (NOTE: player.status: 0 = disengaged, 1 = engaged)
	if player.vitals.tp >= job_settings.tpLimit then
		if math.sqrt(target.distance) <= job_settings.wsRange then
			if target.hpp >= job_settings.minHpp then
				if debugMode then windower.add_to_chat(8, "[AutoWS] Attempting to perform "..job_settings.wsName.." at "..player.vitals.tp.." TP") end
				windower.send_command('input /ws "' .. job_settings.wsName .. '" <t>')
			else
				if debugMode then windower.add_to_chat(8, "[AutoWS] Holding TP, Target HPP < "..target.hpp) end
			end
		else
			if debugMode then windower.add_to_chat(8, "[AutoWS] Target is too far away... (distance: "..target.distance..")") end
		end
	end
	
	-- 3000 TP Failsafe (tp change event stops firing @ 3000 TP, status change only fires once)
	if player.vitals.tp == 3000 then
		fsTries = fsTries + 1
		if debugMode then windower.add_to_chat(8, "[AutoWS] Queueing the 3000TP aws failsafe (Try "..fsTries.."/"..fsTriesMax..")") end
		awsFailsafe:schedule(fsDelay) -- Failsafe: tp change event stops firing @ 3000 TP
	end
end



-------------------------------------------------------------------------------------------------------------------
-- 3000 TP Failsafe for terminated tp change event
-------------------------------------------------------------------------------------------------------------------
awsFailsafe = function()
	local player = windower.ffxi.get_player()
	local playerIsEngaged = player.status == 1
	
	if fsTries < fsTriesMax and playerIsEngaged then
		if player.vitals.tp == 3000 then
			-- Tries Remain: Re-check Scenario for AWS Trigger
			checkAwsTriggers()
		else
			-- TP Event Restarted: Reset/Terminate Failsafe
			if debugMode then windower.add_to_chat(8, "[AutoWS] 3000 TP Failsafe Ended on Try " .. fsTries .. " of " .. fsTriesMax .. " (TP: " .. player.vitals.tp .. ")") end
			fsTries = 0
		end
	else
		-- Out of Tries: Reset/Terminate Failsafe
		if debugMode then windower.add_to_chat(8, "[AutoWS] 3000 TP Failsafe Ended on Try " .. fsTries .. " of " .. fsTriesMax .. (playerIsEngaged and "" or " (Player Disengaged)")) end
		fsTries = 0
	end
end



-------------------------------------------------------------------------------------------------------------------
-- Processing for addon commands (type //aws ingame)
-------------------------------------------------------------------------------------------------------------------
windower.register_event('addon command', function(...)
	-- Detect command vs value
	local commandArgs = T{...}
	local command = commandArgs[1] and string.lower(table.remove(commandArgs, 1)) or 'help'
	local value = table.concat(commandArgs, " ")
	
	-- Prepare chat color definitions
	local green = 158
	local red = 123
	local grey = 207

	if command:wmatch('toggle|switch|flip') then
		windower.send_command('aws ' .. (job_settings.active and 'off' or 'on'))
	elseif command:wmatch('on|start|begin|activate|off|stop|end|deactivate') then
		local activating = command:wmatch('on|start|begin|activate')
		if (activating and job_settings.active) or (not activating and not job_settings.active) then
			return windower.add_to_chat(red, '[AutoWS] Already ' .. (job_settings.active and 'activated' or 'deactivated'))
		end
		job_settings.active = activating
		config.save(job_settings)
		updateDisplayLine()
		windower.add_to_chat(activating and green or red, '[AutoWS] ' .. (activating and 'Activated' or 'Deactivated'))
	elseif command == 'tp' then
		if value ~= '' then
			if tonumber(value) >= 1000 and tonumber(value) <= 3000 then
				job_settings.tpLimit = tonumber(value)
				config.save(job_settings)
				updateDisplayLine()
				windower.add_to_chat(grey, "[AutoWS] Set TP threshold to ["..value.."]")
			else
				windower.add_to_chat(red, "[AutoWS] Error: Please specify a TP value between 1000 and 3000 [command: "..command..", value:"..value.."]")
			end
		else
			windower.add_to_chat(red, "[AutoWS] Error: Please specify a TP value [command: "..command..", value:"..value.."]")
		end
	elseif command == 'ws' then
		if value ~= '' then
			value = windower.convert_auto_trans(value)
			local matches = 0
			local ws
			for _, res in pairs(res.weapon_skills) do
				local fuzzyname = res.en:lower():gsub("%s", ""):gsub("%p", "") -- CREDIT: SuperWarp
				if fuzzyname:startswith(value) or fuzzyname:startswith(commandArgs:concat('')) or res.en:lower() == value:lower() then
					matches = matches + 1
					ws = res
				end
			end
			if matches > 0 then
				if matches == 1 then
					-- SAVE WS
					job_settings.wsName = ws.en
					config.save(job_settings)
					updateDisplayLine()
					windower.add_to_chat(grey, "[AutoWS] Set WS name to ["..ws.en.."]")
					
					-- HANDLE Range
					local skill = res.skills[ws.skill]
					local range = (function()
						if S{'Archery','Marksmanship'}[skill.en] then
							local far = S{'Blast Arrow','Empyreal Arrow','Blast Shot','Detonator'}[ws.name]
							return ws.en == 'Numbing Shot' and 7 or (far and 18 or 16)
						else
							return 5
						end
					end)()
					if job_settings.wsRange ~= range then
						windower.send_command('aws range ' .. range)
					end
				else
					windower.add_to_chat(red, '[AutoWS] Too many results. (' .. matches .. ')')
				end
			else
				windower.add_to_chat(red, '[AutoWS] Unable to find ws "' .. value .. '".')
			end
		else
			windower.add_to_chat(red, "[AutoWS] Error: Please specify a WS name [command: "..command..", value:"..value.."]")
		end
	elseif command == 'range' then
		if value ~= '' then
			if tonumber(value) >= 0 and tonumber(value) <= 21 then
				job_settings.wsRange = tonumber(value)
				config.save(job_settings)
				updateDisplayLine()
				windower.add_to_chat(grey, "[AutoWS] Set WS range to ["..value.."]")
			else
				windower.add_to_chat(red, "[AutoWS] Error: Please specify a range value between 0 and 21 [command: "..command..", value:"..value.."]")
			end
		else
			windower.add_to_chat(red, "[AutoWS] Error: Please specify a WS range [command: "..command..", value:"..value.."]")
		end
	elseif S{'hp','hpp'}[command] then
		if value ~= '' then
			if tonumber(value) >= 0 and tonumber(value) <= 100 then
				job_settings.minHpp = tonumber(value)
				config.save(job_settings)
				updateDisplayLine()
				windower.add_to_chat(grey, "[AutoWS] Set mob HPP threshold to ["..value.."]")
			else
				windower.add_to_chat(red, "[AutoWS] Error: Please specify a hp value between 0 and 100 [command: "..command..", value:"..value.."]")
			end
		else
			windower.add_to_chat(red, "[AutoWS] Error: Please specify a mob HPP value [command: "..command..", value:"..value.."]")
		end
	elseif command == 'uipos' then
		if value ~= '' then
			local coords = value:split(' ')
			if #coords < 2 then
				return windower.add_to_chat(red, '[AutoWS] Please provide both a X and Y coordinate')
			end
			for i, pos in ipairs(value:split(' ')) do
				local coord = tonumber(pos)
				if coord == nil or coord < 0 then
					return windower.add_to_chat(red, '[AutoWS] Please provide only positive X and Y coordinates')
				end
				settings.ui.pos[i == 1 and 'x' or 'y'] = coord
			end
			config.save(settings)
			display:pos(settings.ui.pos.x, settings.ui.pos.y)
			windower.add_to_chat(grey, "[AutoWS] Set UI position to [".. settings.ui.pos.x .. '/' .. settings.ui.pos.y .."]")
		else
			windower.add_to_chat(red, "[AutoWS] Error: Please specify UI position [command: "..command..", value:"..value.."]")
		end
	elseif S{'uishow','uihide'}[command] then
		windower.send_command('aws uivisible ' .. (command == 'uishow' and 'true' or 'false'))
	elseif 'uivisible' == command then
		local showing = S{'true','show','on'}[value] and true or false
		settings.ui.visible = showing
		config.save(settings)
		display:visible(showing)
	elseif command == 'debug' then
		debugMode = not debugMode
		windower.add_to_chat(grey, "[AutoWS] debugMode set to ["..tostring(debugMode).."]")
	elseif S{'config','settings'}[command] then
		windower.add_to_chat(grey, 'AutoWS  settings: (' .. windower.ffxi.get_player().main_job .. ')')
		windower.add_to_chat(grey, '    active     - '..tostring(job_settings.active))
		windower.add_to_chat(grey, '    tpLimit    - '..job_settings.tpLimit)
		windower.add_to_chat(grey, '    wsName   - '..job_settings.wsName)
		windower.add_to_chat(grey, '    wsRange   - '..job_settings.wsRange)
		windower.add_to_chat(grey, '    minHpp    - '..job_settings.minHpp)
	elseif command == 'help' then
		windower.add_to_chat(grey, 'AutoWS  v' .. _addon.version .. ' commands:')
		windower.add_to_chat(grey, '//aws [options]')
		windower.add_to_chat(grey, '    toggle   - Toggles auto weaponskill ON or OFF')
		windower.add_to_chat(grey, '    tp       - Sets TP threshold at which to weaponskill')
		windower.add_to_chat(grey, '    ws       - Sets the weaponskill to use')
		windower.add_to_chat(grey, '    range    - Sets the max range to weaponskill at')
		windower.add_to_chat(grey, '    hp       - Sets HPP threshold at which to halt AWS (set to 0 to disable this feature)')
		windower.add_to_chat(grey, '    config   - Displays the curent AWS settings')
		windower.add_to_chat(grey, '    help     - Displays this help text')
		windower.add_to_chat(grey, ' ')
		windower.add_to_chat(grey, 'NOTE: AutoWS will only automate weaponskills if your status is "Engaged".')
	else
		windower.add_to_chat(red, '[AutoWs] "'..command..'" is not a valid command. Listing commands...')
		windower.send_command('aws help')
	end
end)



-------------------------------------------------------------------------------------------------------------------
-- Addon hooks for TP and status change events
-------------------------------------------------------------------------------------------------------------------
windower.register_event('tp change', checkAwsTriggers)
windower.register_event('status change', checkAwsTriggers)
windower.register_event('load', 'login', 'job change', load_settings)
windower.register_event('logout', function() display:hide() end)

windower.register_event('action', function(act)
	if act.actor_id ~= self.id or not S{1,2,3}[act.category] then
		return
	else
		local target = windower.ffxi.get_mob_by_target('t')
		checkAwsTriggers()
		
		if act.category == 3 then
			print('distance:',target.distance,'max distance:',windower.ffxi.get_mob_by_target('me').model_size + (res.weapon_skills[act.param].range * range_mult[res.weapon_skills[act.param].range]) + target.model_size)
		else
			print('distance', target.distance:sqrt())
		end
	end
end)

windower.register_event('mouse', function(type, x, y, delta, blocked)
	if type == 2 and display:hover(x, y) then
		settings.ui.pos.x, settings.ui.pos.y = display:pos()
		config.save(settings)
	end
end)