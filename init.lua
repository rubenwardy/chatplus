-- Chat Plus
-- =========
-- Advanced chat functionality
-- =========

chatplus = {
	version = 2.2,
	_logpath = minetest.get_worldpath().."/chatplus-log.txt",
	_defsettings = {
		log = true,
		use_gui = true,
		distance = 0,
		badwords = ""
	}
}

function chatplus.init()
	chatplus.load()
	chatplus.clean_players()

	if not chatplus.players then
		chatplus.players = {}
	end
	chatplus.count = 0
	chatplus.loggedin = {}
	chatplus._handlers = {}
end

function chatplus.setting(name)
	local get = minetest.setting_get("chatplus_" .. name)
	if get then
		return get
	elseif chatplus._defsettings[name]~= nil then
		return chatplus._defsettings[name]
	else
		minetest.log("[Chatplus] Setting chatplus_" .. name .. " not found!")
		return nil
	end
end

function chatplus.log(msg)
	if chatplus._log then
		chatplus._log:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. msg .. "\r\n")
		chatplus._log:flush()
	end
end

function chatplus.load()
	-- Initialize the log
	if chatplus.setting("log") then
		chatplus._log = io.open(chatplus._logpath, "a+")
		if not chatplus._log then
			minetest.log("error", "Unable to open chat plus log file: " .. chatplus._logpath)
		else
			minetest.log("action", "Logging chat plus to: " .. chatplus._logpath)
		end
		chatplus.log("*** SERVER STARTED ***")
	end

	-- Load player data
	minetest.log("[Chatplus] Loading data")
	local file = io.open(minetest.get_worldpath() .. "/chatplus.txt", "r")
	if file then
		local table = minetest.deserialize(file:read("*all"))
		file:close()
		if type(table) == "table" then
			chatplus.players = table
			return
		end
	end
end

function chatplus.save()
	minetest.log("[Chatplus] Saving data")

	local file = io.open(minetest.get_worldpath().."/chatplus.txt", "w")
	if file then
		file:write(minetest.serialize(chatplus.players))
		file:close()
	end
end

function chatplus.clean_players()
	if not chatplus.players then
		chatplus.players = {}
		return
	end

	minetest.log("[Chatplus] Cleaning player lists")
	for key,value in pairs(chatplus.players) do
		if value.messages then
			value.inbox = value.messages
			value.messages = nil
		end

		if (
			(not value.inbox or #value.inbox==0) and
			(not value.ignore or #value.ignore==0)
		) then
			value[key] = nil
		end
	end
	chatplus.save()
end

function cp_tick()
	chatplus.clean_players()
	minetest.after(30*60, cp_tick)
end
minetest.after(30*60, cp_tick)

function chatplus.poke(name,player)
	local function check(name,value)
		if not chatplus.players[name][value] then
			chatplus.players[name][value] = {}
		end
	end
	if not chatplus.players[name] then
		chatplus.players[name] = {}
	end
	check(name,"ignore")
	check(name,"inbox")

	chatplus.players[name].enabled = true

	if player then
		if player=="end" then
			chatplus.players[name].enabled = false
			chatplus.loggedin[name] = nil
		else
			if not chatplus.loggedin[name] then
				chatplus.loggedin[name] = {}
			end
			chatplus.loggedin[name].player = player
		end
	end

	chatplus.save()

	return chatplus.players[name]
end

function chatplus.register_handler(func,place)
	if not place then
		table.insert(chatplus._handlers,func)
	else
		table.insert(chatplus._handlers,place,func)
	end
end

function chatplus.send(from, msg)
	if msg:sub(1, 1) == "/" then
		return false
	end

	-- Log chat message
	local tname = ctf.player(from).team or ""
	chatplus.log(tname .. "<" .. from .. "> " .. msg)

	-- Loop through senders
	for key,value in pairs(chatplus.loggedin) do
		local res = nil
		if key ~= from then
			for i=1, #chatplus._handlers do
				if chatplus._handlers[i] then
					res = chatplus._handlers[i](from,key,msg)

					if res ~= nil then
						break
					end
				end
			end
			if res == nil or res == true then
				minetest.chat_send_player(key, "<"..from.."> "..msg,false)
			end
		end
	end

	return true
end

-- Minetest callbacks
minetest.register_on_chat_message(chatplus.send)
minetest.register_on_joinplayer(function(player)
	local _player = chatplus.poke(player:get_player_name(),player)
	chatplus.log(player:get_player_name() .. " joined")

	-- inbox stuff!
	if _player.inbox and #_player.inbox>0 then
		minetest.after(10, minetest.chat_send_player,
			player:get_player_name(),
			"(" ..  #_player.inbox .. ") You have mail! Type /inbox to recieve")
	end
end)
minetest.register_on_leaveplayer(function(player)
	chatplus.poke(player:get_player_name(),"end")
	chatplus.log(player:get_player_name() .. " disconnected")
end)

-- Init
chatplus.init()

-- Ignoring
chatplus.register_handler(function(from,to,msg)
	if chatplus.players[to] and chatplus.players[to].ignore and chatplus.players[to].ignore[from]==true then
		return false
	end
	return nil
end)

minetest.register_chatcommand("ignore", {
	params = "name",
	description = "ignore: Ignore a player",
	func = function(name, param)
		chatplus.poke(name)
		if not chatplus.players[name].ignore[param] then
			chatplus.players[name].ignore[param] = true
			minetest.chat_send_player(name, param .. " has been ignored")
			chatplus.save()
		else
			minetest.chat_send_player(name, "Player " .. param .. " is already ignored.")
		end
	end
})

minetest.register_chatcommand("unignore", {
	params = "name",
	description = "unignore: Unignore a player",
	func = function(name, param)
		chatplus.poke(name)
		if chatplus.players[name].ignore[param] then
			chatplus.players[name].ignore[param] = false
			minetest.chat_send_player(name, param .. " has been unignored")
			chatplus.save()
		else
			minetest.chat_send_player(name, "Player " .. param .. " is already unignored.")
		end
	end
})

-- inbox
function chatplus.showInbox(name, text_mode)
	-- Get player info
	local player = chatplus.players[name]
	if not player or not player.inbox or #player.inbox == 0 then
		minetest.chat_send_player(name, "Your inbox is empty!")
		return false
	end

	-- Show
	if text_mode then
		minetest.chat_send_player(name, "(" .. #player.inbox .. ") You have mail:")
		for i = 1, #player.inbox do
			minetest.chat_send_player(name, player.inbox[i])
		end
		minetest.chat_send_player(name, "(" .. #player.inbox .. ")")
	else
		minetest.chat_send_player(name, "Showing your inbox to you.")
		local fs = "size[10,8]textarea[0.25,0.25;10.15,8;inbox;You have " ..
			#player.inbox .. " messages in your inbox:;"

		for i = 1, #player.inbox do
			fs = fs .. minetest.formspec_escape(player.inbox[i])
			fs = fs .. "\n"
		end

		fs = fs .. "]"
		fs = fs .. "button[0,7.25;2,1;clear;Clear Inbox]"
		fs = fs .. "button_exit[8.1,7.25;2,1;close;Close]"
		minetest.show_formspec(name, "chatplus:inbox", fs)
	end

	return true
end

minetest.register_on_player_receive_fields(function(player,formname,fields)
	if fields.clear then
		local name = player:get_player_name()
		chatplus.poke(name).inbox = {}
		chatplus.save()
		minetest.chat_send_player(name,"Inbox cleared!")
		chatplus.showInbox(name)
	end
end)

minetest.register_chatcommand("inbox", {
	params = "clear?",
	description = "inbox: print the items in your inbox",
	func = function(name, param)
		if param == "clear" then
			local player = chatplus.poke(name)
			player.inbox = {}
			chatplus.save()
			minetest.chat_send_player(name,"Inbox cleared")
		elseif param == "text" or param == "txt" or param == "t" then
			chatplus.showInbox(name,true)
		else
			chatplus.showInbox(name,false)
		end
	end
})

function chatplus.send_mail(name, to, msg)
	minetest.log("C+Mail - To: "..to..", From: "..name..", MSG: "..msg)
	chatplus.log("C+Mail - To: "..to..", From: "..name..", MSG: "..msg)
	if chatplus.players[to] then
		table.insert(chatplus.players[to].inbox, os.date("%d/%m").." <"..name..">: "..msg)
		minetest.chat_send_player(name, "Message sent to " .. to)
		chatplus.save()
	else
		minetest.chat_send_player(name,"Player '" .. to .. "' does not exist")
	end
end

minetest.register_chatcommand("mail", {
	params = "name msg",
	description = "mail: add a message to a player's inbox",
	func = function(name, param)
		chatplus.poke(name)
		local to, msg = string.match(param, "^([%a%d_-]+) (.+)")

		if not to or not msg then
			minetest.chat_send_player(name,"mail: <playername> <msg>",false)
			return
		end

		chatplus.send_mail(name, to, msg)
	end
})

minetest.register_globalstep(function(dtime)
	chatplus.count = chatplus.count + dtime
	if chatplus.count > 5 then
		chatplus.count = 0
		-- loop through player list
		for key,value in pairs(chatplus.players) do
			if (
				chatplus.loggedin and
				chatplus.loggedin[key] and
				chatplus.loggedin[key].player and
				value and
				value.inbox and
				chatplus.loggedin[key].player.hud_add and
				chatplus.loggedin[key].lastcount ~= #value.inbox
			) then
				if chatplus.loggedin[key].msgicon then
					chatplus.loggedin[key].player:hud_remove(chatplus.loggedin[key].msgicon)
				end

				if chatplus.loggedin[key].msgicon2 then
					chatplus.loggedin[key].player:hud_remove(chatplus.loggedin[key].msgicon2)
				end

				if #value.inbox>0 then
					chatplus.loggedin[key].msgicon = chatplus.loggedin[key].player:hud_add({
						hud_elem_type = "image",
						name = "MailIcon",
						position = {x=0.52, y=0.52},
						text="chatplus_mail.png",
						scale = {x=1,y=1},
						alignment = {x=0.5, y=0.5},
					})
					chatplus.loggedin[key].msgicon2 = chatplus.loggedin[key].player:hud_add({
						hud_elem_type = "text",
						name = "MailText",
						position = {x=0.55, y=0.52},
						text=#value.inbox .. " /inbox",
						scale = {x=1,y=1},
						alignment = {x=0.5, y=0.5},
					})
				end
				chatplus.loggedin[key].lastcount = #value.inbox
			end
		end
	end
end)

chatplus.register_handler(function(from,to,msg)
	if chatplus.setting("distance") <= 0 then
		return nil
	end

	local from_o = minetest.get_player_by_name(from)
	local to_o = minetest.get_player_by_name(to)

	if not from_o or not to_o then
		return nil
	end

	if (
		chatplus.setting("distance") ~= 0 and
		chatplus.setting("distance") ~= nil and
		(vector.distance(from_o:getpos(),to_o:getpos()) > tonumber(chatplus.setting("distance")))
	)then
		return false
	end
	return nil
end)

chatplus.register_handler(function(from,to,msg)
	local words = chatplus.setting("badwords"):split(",")
	for _,v in pairs(words) do
		if (v:trim()~="") and ( msg:find(v:trim(), 1, true) ~= nil ) then
			minetest.chat_send_player(from, "Swearing is banned")
			return false
		end
	end
	return nil
end)
