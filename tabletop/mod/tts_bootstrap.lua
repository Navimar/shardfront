-- Пути Раскола v12: native Tabletop Simulator builder.
--
-- This script intentionally creates every object through the public TTS Lua
-- API.  TTS itself assigns GUIDs and serializes the resulting save file.

-- BEGIN GENERATED PUBLIC ASSETS
local ASSET_URLS = {
    ["back_blue.jpeg"] = "https://files.catbox.moe/qjapiq.jpeg",
    ["back_red.jpeg"] = "https://files.catbox.moe/br8c2k.jpeg",
    ["barrier.jpg"] = "https://files.catbox.moe/8uf8tm.jpg",
    ["barriers_12.jpg"] = "https://files.catbox.moe/lq5jhr.jpg",
    ["base_blue.jpg"] = "https://files.catbox.moe/tkgepx.jpg",
    ["base_red.jpg"] = "https://files.catbox.moe/6pqqpm.jpg",
    ["bases.jpg"] = "https://files.catbox.moe/sdxehp.jpg",
    ["board.jpg"] = "https://files.catbox.moe/yeu2rw.jpg",
    ["cards_blue_1.jpg"] = "https://files.catbox.moe/8ox4g1.jpg",
    ["cards_blue_2.jpg"] = "https://files.catbox.moe/6ejb7m.jpg",
    ["cards_blue_3.jpg"] = "https://files.catbox.moe/0po7k4.jpg",
    ["cards_blue_4.jpg"] = "https://files.catbox.moe/0f571g.jpg",
    ["cards_blue_5.jpg"] = "https://files.catbox.moe/16rjba.jpg",
    ["cards_blue_6.jpg"] = "https://files.catbox.moe/m4j1w7.jpg",
    ["cards_red_1.jpg"] = "https://files.catbox.moe/9ex1kb.jpg",
    ["cards_red_2.jpg"] = "https://files.catbox.moe/kvjgha.jpg",
    ["cards_red_3.jpg"] = "https://files.catbox.moe/xep38h.jpg",
    ["cards_red_4.jpg"] = "https://files.catbox.moe/c4cbxm.jpg",
    ["cards_red_5.jpg"] = "https://files.catbox.moe/7z3gem.jpg",
    ["cards_red_6.jpg"] = "https://files.catbox.moe/8ppmi1.jpg",
    ["rules.jpg"] = "https://files.catbox.moe/ra3rdy.jpg",
    ["rules_book.pdf"] = "https://files.catbox.moe/r0fe49.pdf",
}
-- END GENERATED PUBLIC ASSETS
local BUILD_TAG = "puti_raskola_v12"
local busy = false
local BOARD_WIDTH = 27.2
local BOARD_HEIGHT = BOARD_WIDTH * 716 / 975
local CELL_WIDTH = BOARD_WIDTH / 7
local CELL_HEIGHT = BOARD_HEIGHT / 5
local BOARD_VISUAL_OFFSET_X = -0.12
local BOARD_VISUAL_OFFSET_Z = 0.12
local BOARD_RENDER_WIDTH = 40 * 0.85
local BOARD_RENDER_HEIGHT = BOARD_RENDER_WIDTH * 716 / 975
local BASE_CELL_FILL = 0.84
local TTS_CARD_WIDTH = 2.5
local TTS_CARD_HEIGHT = 3.5
local BASE_SCALE_X = BOARD_RENDER_WIDTH / 7 * BASE_CELL_FILL / TTS_CARD_WIDTH
local BASE_SCALE_Z = BOARD_RENDER_HEIGHT / 5 * BASE_CELL_FILL / TTS_CARD_HEIGHT
local HAND_POSITIONS = {
    Blue = {x=-6, y=4, z=-14},
    Red = {x=6, y=4, z=-14},
}

local function asset(name)
    local url = ASSET_URLS[name]
    assert(url ~= nil, "Missing public asset URL: " .. name)
    return url
end

local function vec(x, y, z)
    return {x, y, z}
end

local function ensureTable()
    if Tables.getTable() ~= "Table_RPG" then
        Tables.setTable("Rectangle")
    end
end

local function setCommon(object, name, tags, locked)
    object.setName(name)
    object.setTags(tags)
    object.setLock(locked == true)
    object.tooltip = true
    return object
end

local function spawnDeckSheet(face, back, width, height, count, position, name, tags, sideways)
    local deck = spawnObject({
        type = "DeckCustom",
        position = position,
        rotation = {0, 180, 180},
        sound = false,
    })
    deck.setCustomObject({
        face = asset(face),
        back = asset(back),
        width = width,
        height = height,
        number = count,
        sideways = sideways == true,
        back_is_hidden = true,
    })
    setCommon(deck, name, tags, false)
    return deck
end

local function shuffleDeckRepeatedly(deck, remaining)
    if remaining <= 0 or deck == nil or deck.isDestroyed() then
        return
    end
    deck.shuffle()
    Wait.frames(function()
        shuffleDeckRepeatedly(deck, remaining - 1)
    end, 20)
end

local function spawnPlayerDeck(color, z)
    local isBlue = color == "blue"
    local display = isBlue and "Колода — Синий игрок" or "Колода — Красный игрок"
    local prefix = isBlue and "cards_blue_" or "cards_red_"
    local back = isBlue and "back_blue.jpeg" or "back_red.jpeg"
    local tags = {BUILD_TAG, "poti_live", "poti_main", "poti_" .. color}
    local specifications = {
        {width=4, height=4, count=16},
        {width=4, height=4, count=16},
        {width=4, height=4, count=16},
        {width=4, height=4, count=16},
        {width=4, height=4, count=16},
        {width=4, height=2, count=8},
    }
    local sheets = {}
    for index, specification in ipairs(specifications) do
        sheets[index] = spawnDeckSheet(
            prefix .. tostring(index) .. ".jpg",
            back,
            specification.width,
            specification.height,
            specification.count,
            vec(-27 + (index - 1) * 3, 3, z),
            display,
            tags,
            false
        )
        sheets[index].use_hands = true
        sheets[index].setLock(true)
    end

    Wait.time(function()
        for _, sheet in ipairs(sheets) do
            if sheet ~= nil and not sheet.isDestroyed() then
                sheet.shuffle()
            end
        end

        local function finishDeck(deck)
            Wait.condition(function()
                if deck ~= nil and not deck.isDestroyed() then
                    setCommon(deck, display, tags, false)
                    deck.use_hands = true
                    deck.setPosition(vec(-20, 2, z))
                    deck.setRotation(vec(0, 180, 180))
                    Wait.frames(function()
                        shuffleDeckRepeatedly(deck, 3)
                    end, 30)
                end
            end, function()
                return deck ~= nil and not deck.isDestroyed() and deck.getQuantity() == 88
            end, 12, function()
                broadcastToAll("Не удалось собрать колоду из 88 карт: " .. display, {1, 0.3, 0.3})
            end)
        end

        local function mergeNext(deck, index, quantity)
            if index > #sheets then
                finishDeck(deck)
                return
            end
            if deck == nil or deck.isDestroyed() or sheets[index] == nil or sheets[index].isDestroyed() then
                broadcastToAll("Не удалось объединить листы колоды: " .. display, {1, 0.3, 0.3})
                return
            end
            local nextSheet = sheets[index]
            local expectedQuantity = quantity + specifications[index].count
            deck.setLock(false)
            nextSheet.setLock(false)
            local merged = deck.putObject(nextSheet)
            if merged == nil then
                broadcastToAll("Не удалось объединить листы колоды: " .. display, {1, 0.3, 0.3})
                return
            end
            merged.setLock(true)
            Wait.condition(function()
                mergeNext(merged, index + 1, expectedQuantity)
            end, function()
                return merged ~= nil and not merged.isDestroyed() and merged.getQuantity() == expectedQuantity
            end, 5, function()
                broadcastToAll("Не удалось объединить листы колоды: " .. display, {1, 0.3, 0.3})
            end)
        end

        mergeNext(sheets[1], 2, specifications[1].count)
    end, 3)
end

local function spawnCard(face, back, position, rotation, name, tags, sideways)
    local card = spawnObject({
        type = "CardCustom",
        position = position,
        rotation = rotation or {0, 180, 0},
        sound = false,
    })
    card.setCustomObject({
        face = asset(face),
        back = asset(back or face),
        sideways = sideways == true,
    })
    setCommon(card, name, tags, false)
    return card
end

local function spawnBarriers()
    local tags = {BUILD_TAG, "poti_live", "poti_barrier"}
    local barriers = spawnDeckSheet(
        "barriers_12.jpg",
        "barrier.jpg",
        4,
        3,
        12,
        vec(20, 2, 9.5),
        "Барьеры",
        tags,
        false
    )
    barriers.setRotation(vec(0, 180, 0))
    barriers.setScale(vec(0.2, 1, 0.2))
end

local function fitBaseToBoard(base)
    local boards = getObjectsWithTag("poti_board")
    if base == nil or base.isDestroyed() or #boards == 0 then
        return
    end
    local boardSize = boards[1].getVisualBoundsNormalized().size
    local baseSize = base.getVisualBoundsNormalized().size
    if boardSize.x <= 0 or boardSize.z <= 0 or baseSize.x <= 0 or baseSize.z <= 0 then
        return
    end
    local scale = base.getScale()
    base.setScale(vec(
        scale.x * (boardSize.x / 7 * BASE_CELL_FILL) / baseSize.x,
        scale.y,
        scale.z * (boardSize.z / 5 * BASE_CELL_FILL) / baseSize.z
    ))
end

local function spawnBases()
    local redBase = spawnCard(
        "base_red.jpg",
        "base_red.jpg",
        vec(BOARD_VISUAL_OFFSET_X - BOARD_WIDTH / 2 + 1.5 * CELL_WIDTH, 2,
            BOARD_VISUAL_OFFSET_Z + BOARD_HEIGHT / 2 - 1.5 * CELL_HEIGHT),
        vec(0, 180, 0),
        "База — Красный игрок",
        {BUILD_TAG, "poti_live", "poti_base", "poti_red"},
        false
    )
    redBase.setScale(vec(BASE_SCALE_X, 1, BASE_SCALE_Z))

    local blueBase = spawnCard(
        "base_blue.jpg",
        "base_blue.jpg",
        vec(BOARD_VISUAL_OFFSET_X - BOARD_WIDTH / 2 + 5.5 * CELL_WIDTH, 2,
            BOARD_VISUAL_OFFSET_Z + BOARD_HEIGHT / 2 - 3.5 * CELL_HEIGHT),
        vec(0, 180, 0),
        "База — Синий игрок",
        {BUILD_TAG, "poti_live", "poti_base", "poti_blue"},
        false
    )
    blueBase.setScale(vec(BASE_SCALE_X, 1, BASE_SCALE_Z))
    Wait.frames(resizeBases, 5)
end

function resizeBases()
    for _, base in ipairs(getObjectsWithTag("poti_base")) do
        fitBaseToBoard(base)
    end
end

local function spawnLiveObjects()
    spawnPlayerDeck("blue", -6)
    spawnPlayerDeck("red", 6)
    spawnBarriers()
    spawnBases()
end

local function createBoard()
    local board = spawnObject({
        type = "Custom_Board",
        position = vec(BOARD_VISUAL_OFFSET_X, 1, BOARD_VISUAL_OFFSET_Z),
        rotation = vec(0, 180, 0),
        scale = vec(0.85, 0.85, 0.85),
        sound = false,
    })
    board.setCustomObject({image = asset("board.jpg")})
    setCommon(board, "Пути Раскола — поле 7×5", {BUILD_TAG, "poti_static", "poti_board"}, true)
end

local function createRuleBook()
    local book = spawnObjectData({
        data = {
            Name = "Custom_PDF",
            Transform = {
                posX = 20, posY = 2, posZ = 0,
                rotX = 0, rotY = 180, rotZ = 0,
                scaleX = 3, scaleY = 1, scaleZ = 3,
            },
            Nickname = "Пути Раскола — правила",
            Description = "Листайте страницы кнопками PDF; Alt — увеличить.",
            CustomPDF = {
                PDFUrl = asset("rules_book.pdf"),
                PDFPassword = "",
                PDFPage = 0,
                PDFPageOffset = 0,
            },
            Tags = {BUILD_TAG, "poti_static", "poti_rules"},
            Locked = true,
            Grid = false,
            Snap = false,
            Hands = false,
        },
    })
    setCommon(book, "Пути Раскола — правила", {BUILD_TAG, "poti_static", "poti_rules"}, true)
end

local function createHand(color)
    local hand = spawnObject({
        type = "HandTrigger",
        position = HAND_POSITIONS[color],
        rotation = vec(0, 0, 0),
        scale = vec(11, 4, 3),
        sound = false,
    })
    hand.setValue(color)
    hand.setLock(true)
end

function arrangeHands()
    for _, hand in ipairs(Hands.getHands()) do
        local color = hand.getValue()
        if HAND_POSITIONS[color] ~= nil then
            hand.setPosition(HAND_POSITIONS[color])
            hand.setRotation(vec(0, 0, 0))
            hand.setScale(vec(11, 4, 3))
        end
    end
end

local function ensurePlayerHands()
    Hands.enable = true
    Hands.disable_unused = false
    if Player.Blue.getHandCount() == 0 then
        createHand("Blue")
    end
    if Player.Red.getHandCount() == 0 then
        createHand("Red")
    end
    arrangeHands()
end

local function makeSnapPoints()
    local points = {}
    for row = 0, 4 do
        local z = BOARD_VISUAL_OFFSET_Z + BOARD_HEIGHT / 2 - (row + 0.5) * CELL_HEIGHT
        for column = 0, 6 do
            table.insert(points, {
                position = vec(BOARD_VISUAL_OFFSET_X - BOARD_WIDTH / 2 + (column + 0.5) * CELL_WIDTH, 1.25, z),
                rotation = vec(0, 180, 0),
                rotation_snap = true,
            })
        end
    end
    for _, position in ipairs({
        vec(-20, 1.25, -6),
        vec(-20, 1.25, 6),
        vec(20, 1.25, -6),
        vec(20, 1.25, 6),
        vec(20, 1.25, 9.5),
    }) do
        table.insert(points, {
            position = position,
            rotation = vec(0, 180, 0),
            rotation_snap = true,
        })
    end
    return points
end

local function createLayoutZones()
    for row = 0, 4 do
        local z = BOARD_VISUAL_OFFSET_Z + BOARD_HEIGHT / 2 - (row + 0.5) * CELL_HEIGHT
        for column = 0, 6 do
            local x = BOARD_VISUAL_OFFSET_X - BOARD_WIDTH / 2 + (column + 0.5) * CELL_WIDTH
            local zone = spawnObject({
                type = "Layout",
                position = vec(x, 3, z),
                rotation = vec(0, 0, 0),
                scale = vec(CELL_WIDTH * 0.96, 5, CELL_HEIGHT * 0.96),
                sound = false,
            })
            setCommon(
                zone,
                "Раскладка " .. tostring(column + 1) .. "×" .. tostring(row + 1),
                {BUILD_TAG, "poti_layout", "poti_main"},
                true
            )
            zone.LayoutZone.setOptions({
                direction = 0,
                meld_direction = 2,
                new_object_facing = 1,
                trigger_for_face_up = true,
                trigger_for_face_down = false,
                trigger_for_non_cards = false,
                allow_swapping = true,
                max_objects_per_new_group = 2,
                max_objects_per_group = 2,
                meld_sort = 0,
                meld_reverse_sort = false,
                meld_sort_existing = false,
                sticky_cards = true,
                horizontal_spread = 0,
                vertical_spread = 0.4,
                horizontal_group_padding = 0,
                vertical_group_padding = 0,
                split_added_decks = true,
                combine_into_decks = false,
                cards_per_deck = 0,
                alternate_direction = false,
                randomize = false,
                instant_refill = false,
                manual_only = false,
            })
        end
    end
end

local function wireResetButton()
    local buttons = getObjectsWithTag("poti_reset")
    if #buttons == 0 then
        return
    end
    local button = buttons[1]
    button.clearButtons()
    button.createButton({
        click_function = "resetGame",
        function_owner = Global,
        label = "ЗАНОВО",
        position = {0, 0.55, 0},
        rotation = {0, 0, 0},
        width = 1500,
        height = 620,
        font_size = 285,
        color = {0.76, 0.19, 0.15},
        font_color = {1, 1, 1},
        tooltip = "Вернуть комплект в исходное состояние и перемешать колоды",
    })
end

local function createResetButton()
    local button = spawnObject({
        type = "BlockSquare",
        position = vec(20, 2.2, -9.5),
        rotation = vec(0, 180, 0),
        scale = vec(3.2, 0.5, 1.5),
        sound = false,
    })
    setCommon(button, "Заново", {BUILD_TAG, "poti_static", "poti_reset"}, true)
    button.setColorTint({0.76, 0.19, 0.15})
    Wait.frames(wireResetButton, 2)
end

local function destroyLiveObjects()
    for _, object in ipairs(getAllObjects()) do
        if object.hasTag("poti_live") then
            destroyObject(object)
        else
            local custom = object.getCustomObject()
            local face = custom and (custom.face or custom.image) or ""
            if object.type ~= "Board" and string.find(face, "PutiRaskola", 1, true) then
                destroyObject(object)
            end
        end
    end
end

function resetGame(_, playerColor, _)
    if busy then
        broadcastToColor("Перезагрузка уже выполняется", playerColor, {1, 0.8, 0.2})
        return
    end
    busy = true
    broadcastToAll("Новая партия: возвращаю и перемешиваю комплект…", {0.75, 0.9, 1})
    destroyLiveObjects()
    Wait.time(function()
        spawnLiveObjects()
        Wait.time(function()
            busy = false
            broadcastToAll("Пути Раскола готовы к новой партии", {0.45, 1, 0.55})
        end, 8)
    end, 1)
end

local function buildAll()
    ensureTable()
    for _, object in ipairs(getAllObjects()) do
        destroyObject(object)
    end
    for _, hand in ipairs(Hands.getHands()) do
        destroyObject(hand)
    end
    Global.setSnapPoints({})
    Wait.time(function()
        createBoard()
        createRuleBook()
        createLayoutZones()
        createHand("Blue")
        createHand("Red")
        createResetButton()
        Global.setSnapPoints(makeSnapPoints())
        spawnLiveObjects()
        broadcastToAll("Пути Раскола собраны средствами Tabletop Simulator", {0.45, 1, 0.55})
    end, 1)
end

function rebuildModule()
    buildAll()
end

function onObjectLeaveContainer(container, object)
    if container == nil or object == nil or not container.hasTag("poti_main") then
        return
    end
    object.setTags(container.getTags())
    object.use_hands = true
end

function onObjectNumberTyped(object, player_color, number)
    if object == nil or number <= 0 or object.type ~= "Deck" then
        return false
    end
    local name = object.getName()
    if name ~= "Колода — Синий игрок" and name ~= "Колода — Красный игрок" then
        return false
    end
    if Player[player_color].getHandCount() == 0 then
        broadcastToColor("Сначала сядьте на место Blue или Red", player_color, {1, 0.6, 0.2})
        return true
    end
    object.use_hands = true
    object.deal(math.min(number, object.getQuantity()), player_color)
    return true
end

function onLoad()
    ensureTable()
    Wait.time(function()
        ensurePlayerHands()
        if #getObjectsWithTag("poti_board") == 0 then
            buildAll()
        else
            local hasRuleBook = false
            for _, rules in ipairs(getObjectsWithTag("poti_rules")) do
                if rules.Book ~= nil then
                    hasRuleBook = true
                else
                    destroyObject(rules)
                end
            end
            if not hasRuleBook then
                createRuleBook()
            end
            if #getObjectsWithTag("poti_layout") == 0 then
                createLayoutZones()
            end
            resizeBases()
            wireResetButton()
        end
    end, 1)
end
