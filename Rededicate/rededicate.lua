_addon.author = 'RolandJ'
_addon.version = '1.0.0'
_addon.commands = {'rededication', 'rededicate', 'reded', 'dedication', 'dedicate'}

-------------------------------------------------------------------------------------------------------------------
-- Setup local variables used throughout this lua.
-------------------------------------------------------------------------------------------------------------------

require('functions') --for function:schedule
local res = require('resources') --for getting buff names
local log_source = '[Rededicate] '

local active = true
local dedicated = false
local attempt_delay = 1.5
local reapply_attempts = 0
local reapply_attempts_max = 20
local debugMode = false



-------------------------------------------------------------------------------------------------------------------
-- Function for processing current buffs to determine if dedication needs to be reapplied
-------------------------------------------------------------------------------------------------------------------

local process_dedication_status = function()
	-- Get player and return if unavailable
	local player = windower.ffxi.get_player()
	if player == nil then return end
	
	-- Reset global dedication variable to false
	dedicated = false
	
	-- Determine if player has dedication
	for _, buff_id in pairs(player.buffs) do
		local buff = res.buffs[buff_id].english
		if buff == 'Dedication' then
			dedicated = true
		end
	end
	
	-- Apply dedication if missing
	if not dedicated then
		reapply_attempts = 0
		apply_dedication()
	end
end

process_dedication_status() -- self-call on load only




-------------------------------------------------------------------------------------------------------------------
-- Function for tracking dedication status as buffs change
-------------------------------------------------------------------------------------------------------------------

local buff_change = function(buff_id, gain)
	local buff = res.buffs[buff_id].english
	
	-- Only Process Dedication
	if buff == 'Dedication' then
		-- Update status & reapply if lost
		dedicated = gain
		if not gain then
			dedicated = false
			reapply_attempts = 0
			apply_dedication()
		end
	end
end




-------------------------------------------------------------------------------------------------------------------
-- Function for applying dedication to player (via !buff command)
-------------------------------------------------------------------------------------------------------------------


apply_dedication = function()
	-- Return out if plugin is off
	if not active then
		return windower.add_to_chat(123, log_source .. 'Dedication wore off but addon is off. (type "//reded on" to enable addon)')
	end

	-- Return out if dedication is active
	if dedicated then
		return windower.add_to_chat(8, log_source .. 'Dedication was reapplied... (!buff)')
	end
	
	-- Return out if out of attempts
	if reapply_attempts > reapply_attempts_max then
		return windower.add_to_chat(8, log_source .. 'Out of attempts to re-!buff... ('.. reapply_attempts .. '/' .. reapply_attempts_max .. ')')
	end
	
	-- Increment the attempts
	reapply_attempts = reapply_attempts + 1
	
	-- Execute !buff command
	if debugMode then windower.add_to_chat(8, log_source .. 'Attempting to re-apply !buff... (Attempt ' .. reapply_attempts .. '/' .. reapply_attempts_max .. ')') end
	windower.send_command('input /s !buff') --override chatmode with /s to avoid !buff failures
	
	-- Queue another !buff incase it was already active
	apply_dedication:schedule(attempt_delay)
end




-------------------------------------------------------------------------------------------------------------------
-- Processing for addon commands
-------------------------------------------------------------------------------------------------------------------

windower.register_event('addon command', function(...)
	local commandArgs = {...}
	
	-- Prepare chat color definitions
	local green = 158
	local red = 123
	local grey = 8

    if commandArgs[1] == 'toggle' or commandArgs[1] == 'switch' or commandArgs[1] == 'flip' then
        active = not active
		windower.add_to_chat(active and green or red, log_source .. (active and "Activated" or "Deactivated") .. '...')
	elseif commandArgs[1] == 'on' or commandArgs[1] == 'start' or commandArgs[1] == 'begin' or commandArgs[1] == 'activate' or commandArgs[1] == 'unpause' then
        active = true
		windower.add_to_chat(green, log_source .. "Activated...")
	elseif commandArgs[1] == 'off' or commandArgs[1] == 'stop' or commandArgs[1] == 'end' or commandArgs[1] == 'deactivate' or commandArgs[1] == 'pause' then
        active = false
		windower.add_to_chat(red, log_source .. "Deactivated...")
	elseif commandArgs[1] == 'debug' then
        debugMode = not debugMode
		windower.add_to_chat(grey, log_source .. "Debug mode " .. (debugMode and 'enabled' or 'disabled') .. '...')
    elseif commandArgs[1] == 'help' then
        windower.add_to_chat(grey, 'Rededicate  v' .. _addon.version .. ' commands:')
        windower.add_to_chat(grey, '//rededicate [command]')
        windower.add_to_chat(grey, '    toggle   - Toggles rededicate ON or OFF')
        windower.add_to_chat(grey, '    on       - Turns rededicate on')
        windower.add_to_chat(grey, '    off      - Turns rededicate off')
    else
		windower.add_to_chat(red, log_source .. '"'..commandArgs[1]..'" is not a valid command. Listing commands...')
		windower.send_command('rededicate help')
	end
end)




-------------------------------------------------------------------------------------------------------------------
-- Addon hooks for tracking dedication status
-------------------------------------------------------------------------------------------------------------------

windower.register_event('load','login','zone change','job change', process_dedication_status)
windower.register_event('gain buff', function(buff_id)
	buff_change(buff_id, true)
end)
windower.register_event('lose buff', function(buff_id)
	buff_change(buff_id, false)
end)