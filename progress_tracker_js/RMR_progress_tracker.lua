-- load this script after loading RMR boot.lua

-- Copied from RMR AutoTracker.lua
local cpu = ew.cpu
local cWaitFrames = 120
local prevTitle = -1
local waitFrames = cWaitFrames

local function getTitle()
    local tmp = cpu[0x80FFC9] - 0x30
    if tmp < 0 then tmp = 1 end
    return tmp
end
-- Copied from RMR AutoTracker.lua end

-- Copied from RMR boot.lua
local addrItems = 0x7FFF00
local addrChecks = 0x7FFF60
local addrIFG = 0x7FFFAE
local cChecksPerTitle = 0x20
local cItems = 0x60
local addrClear = {0x7FFFCF,0x7FFFCF,0x7FFFCF,}
local addrTiwns = {0x7E1F80,0x7E1FB3,0x7E1FB4}
local addrMultiworldInfo = {0xBFFDD0,0xBFFDD0,0xCFFDD0}
-- Copied from RMR boot.lua end

local reportOnBoot = true;

local prevProgress = {
    ["items"] = {},
    ["checks"] = {},
    ["currentTitle"] = nil,
    ["ifg"] = nil,
    ["clear"] = {},
    ["death"] = nil,
    ["multiWorldInfo"] = nil,
}

local function writeProgress(progress)
    local output = "window.RMRPTJS.progress={\n"

    -- items
    output = output .. '  "items": ['
    for i=1, #progress["items"] do
        output = output .. progress["items"][i]
        if (i ~= #progress["items"]) then
            output = output .. ","
        end
    end
    output = output .. "],\n"

    -- checks
    output = output .. '  "checks": ['
    for i=1, #progress["checks"] do
        output = output .. progress["checks"][i]
        if (i ~= #progress["checks"]) then
            output = output .. ","
        end
    end
    output = output .. "],\n"

    -- clear
    output = output .. '  "clear": ['
    for i=1, #progress["clear"] do
        output = output .. progress["clear"][i]
        if (i ~= #progress["clear"]) then
            output = output .. ","
        end
    end
    output = output .. "],\n"

    -- ifg
    output = output .. '  "ifg": ' .. progress["ifg"] .. ',\n'

    -- currentTitle
    output = output .. '  "currentTitle": ' .. progress["currentTitle"] .. ',\n'

    -- death count
    output = output .. '  "death": ' .. progress["death"] .. ',\n'

    -- multiworld info
    output = output .. '  "multiWorldInfo": ' .. progress["multiWorldInfo"] .. ',\n'

    -- reportOnBoot
    -- output = output .. '  "reportOnBoot": ' .. tostring(reportOnBoot) .. ',\n'

    output = output .. "}\n"

    local fh = io.open("RMR_progress_tracker_report.js","w")
    if fh then
        fh:write(output)
        fh:close()
    end
end

local function parseProgress(curTitle)
    progress = {
        ["items"] = {},
        ["checks"] = {},
        ["currentTitle"] = {},
        ["ifg"] = {},
        ["clear"] = {},
        ["death"] = nil,
        ["multiWorldInfo"] = nil,
    }

    local updated = False

    -- items
    for i=0, cItems-1, 1 do
        table.insert(progress["items"], cpu[addrItems + i])
        if progress["items"][i] ~= prevProgress["items"][i] then
            updated = true
        end
    end

    -- checks
    -- check flag is only presented in memory for the current game, hence, reading
    -- sessionSave["checks"] from boot.lua is required, which is caching checks for all games.
    for game=1, 3 do
        for i=0, cChecksPerTitle-1, 1 do
            local offset = (game - 1) * cChecksPerTitle
            table.insert(progress["checks"], sessionSave["checks"][offset + i])
            if progress["checks"][offset + i] ~= prevProgress["checks"][offset + i] then
                updated = true
            end
        end

        -- clear flag
        table.insert(progress["clear"], sessionSave.titleValue[game][addrClear[game]] or 0)
        if progress["clear"][game] ~= prevProgress["clear"][game] then
            updated = true
        end
    end

    progress["ifg"] = cpu[addrIFG]

    progress["death"] = cpu[addrTiwns[curTitle]]

    progress["currentTitle"] = curTitle

    progress["multiWorldInfo"] = cpu[addrMultiworldInfo[curTitle]]
    
    updated = updated or (progress["ifg"] ~= prevProgress["ifg"])
        or (progress["currentTitle"] ~= prevProgress["currentTitle"])
        or (progress["death"] ~= prevProgress["death"])
        or (progress["multiWorldInfo"] ~= prevProgress["multiWorldInfo"])

    if reportOnBoot or updated then
        writeProgress(progress)
        reportOnBoot = false
    end
    prevProgress = progress
end

-- modified from AutoTracker
function getCurrentScreen(curTitle)
    local addrMap = {[1] = 0x7E00D1, [2] = 0x7E00D0, [3] = 0x7E00D0}
    return cpu[addrMap[curTitle]]
end


-- curTitle & some main loop logic is modified from RMR AutoTracker.lua
while true do
    ew.frameadvance()

    local curTitle = getTitle()
    local screen = getCurrentScreen(curTitle)
    if prevTitle ~= curTitle then
        prevTitle = curTitle
        waitFrames = cWaitFrames
    end
    waitFrames = waitFrames - 1

    if waitFrames <= 0 then
        waitFrames = 10
        -- wait another cWaitFrames sec when still in title screen
        if screen == 0 then
            waitFrames = cWaitFrames
        -- don't process until entering stage select screen
        elseif screen == 2 then
            parseProgress(curTitle)
        end
    end
end