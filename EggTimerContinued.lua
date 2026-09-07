-- EggTimer Continued - tracks unique auto-transforming perishables (Mysterious
-- Egg, Disgusting Jar, ...) across every character on the account.
--
-- How it works:
--   * These items are BOUGHT from a vendor, so no CHAT_MSG_LOOT fires. Detection
--     is done by scanning bags on login and on BAG_UPDATE_DELAYED.
--   * The source item (e.g. Mysterious Egg) auto-transforms server-side into the
--     result item (e.g. Cracked Egg) after ~3 days, usually a second or two
--     after you log in that character. So readiness is driven by the result item
--     actually appearing in bags, NOT by our clock. The countdown shown is only
--     a cosmetic estimate from `days` below.
--   * Data is account-wide (SavedVariables: EggTimerDB), keyed "Name-Realm", so
--     an alt on another realm shows up in the tooltip on your main.

local ADDON = ...

-- Tracked items. `days` is a display-only estimate; add rows freely.
-- source: the bought item (assumed Unique / max 1)
-- result: what it auto-transforms into (may stack up if you don't open them)
local TRACKED = {
	{
		key = "egg", source = 39878, result = 39883, days = 3,
		sourceName = "Mysterious Egg", resultName = "Cracked Egg", verb = "hatched",
	},
	{
		key = "jar", source = 44717, result = 44718, days = 3,
		sourceName = "Disgusting Jar", resultName = "Ripe Disgusting Jar", verb = "ripened",
	},
	-- Other originally-tracked items (short timers, not really collectibles) --
	-- uncomment to track:
	-- { key = "corpse", source = 43494, result = 43493, days = 1/24,
	--   sourceName = "Ahn'kahar Watcher's Corpse", resultName = "Watcher's Corpse Dust", verb = "decayed" },
}

local ICON = "Interface\\AddOns\\EggTimerContinued\\Icon"
local PREFIX = "|cff33ff99EggTimer|r: "
local GRAY, GREEN, YELLOW = "|cff808080", "|cff40ff40", "|cffffd100"
local DAY = 86400

local floor, time, ipairs, pairs = math.floor, time, ipairs, pairs

local frame = CreateFrame("Frame")
local ldb, myKey
local ticker

-- session-local: last ready count we announced per tracked key. Reset every
-- login/reload, so the "ready" message repeats once per session until you open
-- the item, and the staggered login scans (+3s, +12s) don't double up.
local announced = {}

-- session-local: "<altKey>:<itemKey>" -> true once we've alerted that an alt's
-- egg is ready / past its estimate. Stops the every-30s re-check from spamming;
-- cleared for that alt once it's back to plain incubation, and wiped on reload.
local altAlerted = {}

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------

local function chat(msg)
	print(PREFIX .. msg)
end

local function shortTime(s)
	if s < 0 then s = 0 end
	local d = floor(s / DAY); s = s - d * DAY
	local h = floor(s / 3600); s = s - h * 3600
	local m = floor(s / 60)
	if d > 0 then return d .. "d " .. h .. "h" end
	if h > 0 then return h .. "h " .. m .. "m" end
	return m .. "m"
end

local function countInBags(itemID)
	local n = 0
	for bag = 0, 5 do
		local slots = C_Container.GetContainerNumSlots(bag)
		if slots and slots > 0 then
			for slot = 1, slots do
				if C_Container.GetContainerItemID(bag, slot) == itemID then
					n = n + 1
				end
			end
		end
	end
	return n
end

-- "Name-Realm" -> display string, class-colored, realm shown only for other realms
local function displayName(key, class)
	local name = key:match("^(.-)%-") or key
	local realm = key:match("%-(.+)$")
	if realm and realm ~= (GetRealmName() or "") then
		name = name .. " (" .. realm .. ")"
	end
	local c = class and C_ClassColor and C_ClassColor.GetClassColor(class)
	if c then return c:WrapTextInColorCode(name) end
	return name
end

local function myEntry()
	local chars = EggTimerDB.chars
	local e = chars[myKey]
	if not e then e = { items = {} }; chars[myKey] = e end
	e.items = e.items or {}
	local _, classFile = UnitClass("player")
	e.class = classFile
	e.faction = UnitFactionGroup("player")
	return e
end

----------------------------------------------------------------------
-- broker / tooltip
----------------------------------------------------------------------

-- returns: bestText, isReady  (the single most urgent state across all chars)
local function summarize()
	local now = time()
	local ready = false
	local soonest
	for _, c in pairs(EggTimerDB.chars) do
		for _, t in ipairs(TRACKED) do
			local rec = c.items and c.items[t.key]
			if rec then
				if (rec.ready or 0) > 0 then
					ready = true
				elseif rec.acquired then
					local left = rec.acquired + t.days * DAY - now
					if not soonest or left < soonest then soonest = left end
				end
			end
		end
	end
	if ready then return "Ready!", true end
	if soonest then return shortTime(soonest), false end
	return nil, false
end

local function updateBroker()
	if not ldb then return end
	local text, ready = summarize()
	if not text then
		ldb.text = "No timers"
	elseif ready then
		ldb.text = GREEN .. "Ready!|r"
	else
		ldb.text = text
	end
end

-- builds the line list; used by both tooltip and /eggtimer report.
-- A character can show BOTH a "ready" line and an incubation line for the same
-- tracked item (unopened result sitting in bags while a fresh source ticks down).
local function reportLines()
	local now = time()
	local lines = {}
	for key, c in pairs(EggTimerDB.chars) do
		local who = displayName(key, c.class)
		for _, t in ipairs(TRACKED) do
			local rec = c.items and c.items[t.key]
			if rec then
				if (rec.ready or 0) > 0 then
					lines[#lines + 1] = {
						sort = key .. "1" .. t.key,
						left = who .. "  " .. GRAY .. t.resultName .. "|r",
						right = GREEN .. "Ready to open!" .. (rec.ready > 1 and (" (x" .. rec.ready .. ")") or "") .. "|r",
					}
				end
				if rec.acquired then
					local left = rec.acquired + t.days * DAY - now
					local right
					if left > 0 then
						right = shortTime(left)
					elseif key == myKey then
						right = YELLOW .. "Hatching..." .. "|r"       -- server transform imminent
					else
						right = YELLOW .. "Log in to check" .. "|r"   -- estimate elapsed on an alt
					end
					lines[#lines + 1] = {
						sort = key .. "2" .. t.key,
						left = who .. "  " .. GRAY .. t.sourceName .. "|r",
						right = right,
					}
				end
			end
		end
	end
	table.sort(lines, function(a, b) return a.sort < b.sort end)
	return lines
end

local function tooltipShow(tt)
	tt:AddLine("EggTimer Continued")
	local lines = reportLines()
	if #lines == 0 then
		tt:AddLine(GRAY .. "No active timers." .. "|r")
	else
		for _, l in ipairs(lines) do tt:AddDoubleLine(l.left, l.right) end
	end
	tt:AddLine(" ")
	tt:AddLine(GRAY .. "Click: report to chat  -  /eggtimer for options" .. "|r")
end

----------------------------------------------------------------------
-- scan
----------------------------------------------------------------------

local function alarm()
	if EggTimerDB.sound then
		PlaySound(SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12889)
	end
end

-- Fires once per session per distinct ready count (see `announced`): on the
-- login scan if the item is already/just transformed, or the moment it
-- transforms while you're playing that character.
local function announce(t, count)
	local subject = count > 1 and (count .. " " .. t.resultName .. "s") or ("a " .. t.resultName)
	local be = count > 1 and "are" or "is"
	chat("You have " .. subject .. " " .. be .. " ready to open (" .. t.sourceName .. " " .. t.verb .. ").")
end

-- Check OTHER characters so you know to switch to them. Their data only updates
-- while they're logged in, so "should be ready" is our `days`-from-purchase
-- estimate (3 days for both egg and jar) and "waiting to open" is the last-saved
-- ready state.
--
-- Called from every bag scan and from the 30s tick() (which is otherwise
-- bag-free), so an alt's estimate elapsing while you're on another character
-- alerts you within ~30s, not only at next login. Pure table reads over the
-- saved DB -- no bag API. Each alt/item is announced once per session
-- (`altAlerted`) so it doesn't spam; the table wipes on reload and an alt drops
-- out of it once it's back to plain incubation, so "tell me every login until I
-- deal with it" still holds. Returns true if a new alert appeared (caller sounds
-- the alarm).
local function checkOtherChars()
	local now = time()
	local newAlert = false
	for key, c in pairs(EggTimerDB.chars) do
		if key ~= myKey and c.items then
			for _, t in ipairs(TRACKED) do
				local rec = c.items[t.key]
				local k = key .. ":" .. t.key
				local msg
				if rec and (rec.ready or 0) > 0 then
					msg = displayName(key, c.class) .. " has a " .. t.resultName
						.. " waiting -- log in to open it."
				elseif rec and rec.acquired and (rec.acquired + t.days * DAY) <= now then
					msg = displayName(key, c.class) .. "'s " .. t.sourceName
						.. " should be ready by now -- log in to collect."
				end
				if msg then
					if not altAlerted[k] then
						chat(msg)
						altAlerted[k] = true
						newAlert = true
					end
				else
					altAlerted[k] = nil -- still incubating / cleared: re-arm
				end
			end
		end
	end
	return newAlert
end

local function scan()
	local me = myEntry()
	local now = time()
	local ring = false

	for _, t in ipairs(TRACKED) do
		local haveSource = countInBags(t.source) > 0
		local readyCount = countInBags(t.result)
		local rec = me.items[t.key]

		if (haveSource or readyCount > 0) and not rec then
			rec = {}
			me.items[t.key] = rec
		end

		if rec then
			-- incubation state
			if haveSource then
				if not rec.acquired then rec.acquired = now end -- newly acquired
			else
				rec.acquired = nil
			end
			-- ready state
			rec.ready = readyCount

			-- prune once nothing is left (you opened the result item)
			if not rec.acquired and readyCount == 0 then
				me.items[t.key] = nil
				rec = nil
			end
		end

		-- notify: once per session per distinct ready count. Covers both login
		-- scans and a mid-session transform; a second egg transforming later
		-- bumps the count and re-announces.
		if rec and (rec.ready or 0) > 0 then
			if announced[t.key] ~= rec.ready then
				announce(t, rec.ready)
				announced[t.key] = rec.ready
				ring = true
			end
		else
			announced[t.key] = nil
		end
	end

	-- Alert about other characters too (see checkOtherChars). Sound the alarm if
	-- anything anywhere needs attention -- the point of the sound is "go deal
	-- with an egg", including one due on an alt you're not logged into.
	if checkOtherChars() then ring = true end
	if ring then alarm() end
	updateBroker()
end

-- 30s heartbeat. Deliberately does NOT scan bags -- it only re-checks other
-- characters' saved estimates (pure table reads, no API calls into the bag
-- system) and refreshes the broker text so the countdown ticks down. The bag
-- scan that actually detects a transform runs on login and on every
-- BAG_UPDATE_DELAYED, which is plenty.
local function tick()
	if checkOtherChars() then alarm() end
	updateBroker()
end

-- debounce rapid BAG_UPDATE_DELAYED bursts
local pending
local function scanSoon()
	if pending then return end
	pending = true
	C_Timer.After(0.5, function()
		pending = false
		scan()
	end)
end

----------------------------------------------------------------------
-- slash
----------------------------------------------------------------------

local function report()
	local lines = reportLines()
	if #lines == 0 then
		chat(GRAY .. "no active timers." .. "|r")
		return
	end
	chat("timers:")
	for _, l in ipairs(lines) do
		print("  " .. l.left .. " - " .. l.right)
	end
end

SLASH_EGGTIMER1 = "/eggtimer"
SLASH_EGGTIMER2 = "/egg"
SlashCmdList.EGGTIMER = function(msg)
	msg = (msg or ""):lower():match("^%s*(%S*)")
	if msg == "minimap" then
		EggTimerDB.minimap.hide = not EggTimerDB.minimap.hide
		local dbi = LibStub("LibDBIcon-1.0", true)
		if EggTimerDB.minimap.hide then dbi:Hide(ADDON) else dbi:Show(ADDON) end
		chat("minimap button " .. (EggTimerDB.minimap.hide and "hidden" or "shown") .. ".")
	elseif msg == "sound" then
		EggTimerDB.sound = not EggTimerDB.sound
		chat("ready sound " .. (EggTimerDB.sound and "on" or "off") .. ".")
	elseif msg == "reset" then
		wipe(EggTimerDB.chars)
		scan()
		chat("all stored data cleared.")
	elseif msg == "scan" then
		scan()
		report()
	else
		report()
		chat(GRAY .. "/eggtimer minimap | sound | scan | reset" .. "|r")
	end
end

----------------------------------------------------------------------
-- init
----------------------------------------------------------------------

local function initDB()
	if type(EggTimerDB) ~= "table" or not EggTimerDB.chars then
		EggTimerDB = {}
	end
	EggTimerDB.chars = EggTimerDB.chars or {}
	EggTimerDB.minimap = EggTimerDB.minimap or { hide = false }
	if EggTimerDB.sound == nil then EggTimerDB.sound = true end
end

local firstEnterWorld = true

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		initDB()
		myKey = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
		myEntry()

		ldb = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON, {
			type = "data source",
			text = "EggTimer Continued",
			icon = ICON,
			OnClick = function(_, button) report() end,
			OnTooltipShow = tooltipShow,
		})
		LibStub("LibDBIcon-1.0"):Register(ADDON, ldb, EggTimerDB.minimap)
		updateBroker()

		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("BAG_UPDATE_DELAYED")

		ticker = C_Timer.NewTicker(30, tick)

	elseif event == "PLAYER_ENTERING_WORLD" then
		if firstEnterWorld then
			firstEnterWorld = false
			-- the login auto-transform lands a beat after entering the world;
			-- scan early for the UI, then again once it has settled. The "ready"
			-- message + sound are deduped (`announced` / `altAlerted`), so the two
			-- scans don't double up.
			C_Timer.After(3, function() scan() end)
			C_Timer.After(12, function() scan() end)
		else
			C_Timer.After(2, function() scan() end)
		end

	elseif event == "BAG_UPDATE_DELAYED" then
		scanSoon()
	end
end)
