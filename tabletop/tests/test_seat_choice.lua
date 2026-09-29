-- Run from the repository root: lua tests/test_seat_choice.lua
-- Exercise the actual Global script with simulated TTS players and delayed events.
local script = arg[1] or "source/templates/tts_bootstrap.lua"

local function world()
    local w = {players={}, timers={}, now=0}
    Player = {
        Blue = {seated=false, getHandCount=function() return 1 end},
        Red = {seated=false, getHandCount=function() return 1 end},
        getPlayers = function() return w.players end,
    }
    Hands = {getHands=function() return {} end}
    Tables = {getTable=function() return "Table_RPG" end}
    Global = {setSnapPoints=function() end}
    destroyObject = function() end
    getAllObjects = function() return {} end
    Wait = {time=function(fn, delay)
        table.insert(w.timers, {fn=fn, at=w.now+delay})
    end}
    getObjectsWithTag = function(tag)
        if tag == "poti_board" or tag == "poti_layout" then return {{}} end
        if tag == "poti_rules" then return {{Book={}}} end
        return {}
    end
    function w.advance(seconds)
        local finish = w.now + seconds
        while true do
            local earliest
            for i, timer in ipairs(w.timers) do
                if timer.at <= finish and (earliest == nil or timer.at < w.timers[earliest].at) then
                    earliest = i
                end
            end
            if earliest == nil then break end
            local timer = table.remove(w.timers, earliest)
            w.now = timer.at
            timer.fn()
        end
        w.now = finish
    end
    function w.add(id, color)
        local p = {steam_id=id, color=color or "Grey", dialogs={}, messages={}}
        p.getHandCount = function() return 1 end
        p.print = function(message) table.insert(p.messages, message) end
        p.changeColor = function(target)
            assert(not Player[target].seated, "Must not take an occupied seat")
            if Player[p.color] == p then
                Player[p.color] = {seated=false, getHandCount=function() return 1 end}
            end
            p.color = target
            p.seated = true
            Player[target] = p
        end
        p.showOptionsDialog = function(description, options, default, callback)
            assert(description == "Выбери цвет игрока" and default == 1)
            table.insert(p.dialogs, {options=options, callback=callback})
        end
        p.choose = function(index, dialog)
            local d = p.dialogs[dialog or #p.dialogs]
            d.callback(d.options[index], index, p.color)
        end
        table.insert(w.players, p)
        if p.color == "Blue" or p.color == "Red" then
            p.seated = true
            Player[p.color] = p
        end
        return p
    end
    function w.remove(p)
        onPlayerDisconnect(p)
        for i, current in ipairs(w.players) do
            if current == p then table.remove(w.players, i) break end
        end
        if Player[p.color] == p then
            Player[p.color] = {seated=false, getHandCount=function() return 1 end}
        end
    end
    assert(loadfile(script))()
    return w
end

local tests = {}

function tests.load_and_connect_offer_only_one_dialog()
    local w = world()
    local p = w.add("host", "White")
    onLoad()
    onPlayerConnect(p)
    w.advance(2)
    assert(#p.dialogs == 0, "Wait until the table is ready")
    w.advance(1)
    assert(#p.dialogs == 1)
    assert(p.dialogs[1].options[1] == "Синий" and p.dialogs[1].options[2] == "Красный")
    p.choose(2)
    assert(p.color == "Red")
end

function tests.new_player_gets_a_choice_after_connecting()
    local w = world()
    onLoad()
    w.advance(3)
    local p = w.add("late")
    onPlayerConnect(p)
    w.advance(3)
    assert(#p.dialogs == 1)
    p.choose(1)
    assert(p.color == "Blue")
end

function tests.seated_players_are_not_prompted()
    local w = world()
    local blue, red = w.add("blue", "Blue"), w.add("red", "Red")
    onLoad()
    onPlayerConnect(blue)
    onPlayerConnect(red)
    w.advance(3)
    assert(#blue.dialogs == 0 and #red.dialogs == 0)
end

function tests.only_free_seats_are_offered()
    local w = world()
    w.add("blue", "Blue")
    local p = w.add("spectator")
    onLoad()
    w.advance(3)
    assert(#p.dialogs[1].options == 1 and p.dialogs[1].options[1] == "Красный")
    p.choose(1)
    local extra = w.add("extra")
    onPlayerConnect(extra)
    w.advance(3)
    assert(#extra.dialogs == 0)
end

function tests.simultaneous_grey_players_cannot_take_the_same_seat()
    local w = world()
    local a, b = w.add("a"), w.add("b")
    onLoad()
    w.advance(3)
    assert(#a.dialogs == 1 and #b.dialogs == 1)
    a.choose(1)
    b.choose(1)
    assert(a.color == "Blue" and b.color == "Grey")
    assert(#b.dialogs == 2 and #b.messages == 1)
    assert(#b.dialogs[2].options == 1 and b.dialogs[2].options[1] == "Красный")
    b.choose(1)
    assert(b.color == "Red")
end

function tests.manual_seating_while_dialog_is_open_is_preserved()
    local w = world()
    local p = w.add("manual")
    onPlayerConnect(p)
    w.advance(3)
    p.changeColor("Red")
    p.choose(1)
    assert(p.color == "Red")
end

function tests.disconnected_players_and_stale_callbacks_are_ignored()
    local w = world()
    local early = w.add("early")
    onPlayerConnect(early)
    w.remove(early)
    w.advance(3)
    assert(#early.dialogs == 0)
    local old = w.add("same-id")
    onPlayerConnect(old)
    w.advance(3)
    w.remove(old)
    local fresh = w.add("same-id")
    onPlayerConnect(fresh)
    w.advance(3)
    old.choose(1)
    assert(fresh.color == "Grey")
    fresh.choose(2)
    assert(fresh.color == "Red")
end

function tests.cancel_does_not_reopen_until_reconnecting()
    local w = world()
    local p = w.add("cancelled")
    onPlayerConnect(p)
    w.advance(3)
    -- TTS calls no callback on Cancel.
    onPlayerConnect(p)
    w.advance(3)
    assert(#p.dialogs == 1 and p.color == "Grey")
    w.remove(p)
    local fresh = w.add("cancelled")
    onPlayerConnect(fresh)
    w.advance(3)
    assert(#fresh.dialogs == 1)
end

local count = 0
for name, test in pairs(tests) do
    test()
    print("PASS " .. name)
    count = count + 1
end
print("Passed " .. count .. " seat-choice scenarios")
