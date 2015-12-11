-- Chat Plus
--    by rubenwardy
---------------------
-- mail.lua
-- Adds C+'s email.
---------------------

minetest.register_on_joinplayer(function(player)
	local _player = chatplus.poke(player:get_player_name(),player)
	-- inbox stuff!
	if _player.inbox and #_player.inbox>0 then
		minetest.after(10, minetest.chat_send_player,
			player:get_player_name(),
			"(" ..  #_player.inbox .. ") You have mail! Type /inbox to recieve")
	end
end)

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
