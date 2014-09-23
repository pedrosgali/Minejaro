local term = require("term")
local comp = require("component")
local keyboard = require("keyboard")
local sh = require("shell")
local fs = require("filesystem")
local computer = require("computer")
local serial = require("serialization")
local gpu = comp.gpu
local event = require("event")
term.clear()

local file = 1
local white = 0xFFFFFF
local black = 0x000000
local path = "/"..string.sub(sh.getWorkingDirectory(), 2, #sh.getWorkingDirectory() - 1)

local screen = {}

function screen:newPane(object, w, h)
    object = object or {}
    setmetatable(object, self)
    self.__index = self
    object.width = w
    object.height = h
    object.colour = black
    object.renderBool = true
    object.isMoveable = true
    object.textInputs = {}
    object.textInputCount = 0
    return object
end

function screen:resize(w, h)
    self.oldW = self.width
    self.oldH = self.height
    self.width = w
    self.height = h
    if self.boxTab ~= nil then
        for i = 1, #self.boxTab do
            if self.boxTab[i]["scaleable"] then
                self.boxTab[i]["width"] = self.width - (self.oldW - self.boxTab[i]["width"])
                if self.boxTab[i]["height"] ~= 1 then
                    if self.boxTab[i]["height"] == self.oldH then
                        self.boxTab[i]["height"] = self.height
                    elseif self.boxTab[i]["height"] == self.oldH - 3 then
                        self.boxTab[i]["height"] = self.height - 3
                    else
                        self.boxTab[i]["height"] = self.height - (self.oldH - self.boxTab[i]["height"])
                    end
                end
            end
        end
    end
    if self.textInputs ~= nil then
        for i = 1, #self.textInputs do
            if self.textInputs[i]["scaleable"] then
                self.textInputs[i]["width"] = self.width - (self.oldW - self.textInputs[i]["width"])
                if self.textInputs[i]["height"] ~= 1 then
                    if self.textInputs[i]["height"] == self.oldH then
                        self.textInputs[i]["height"] = self.height
                    elseif self.textInputs[i]["height"] == self.oldH - 3 then
                        self.textInputs[i]["height"] = self.height - 3
                    else
                        self.textInputs[i]["height"] = self.height - (self.oldH - self.textInputs[i]["height"])
                    end
                end
            end
        end
    end
    if self.buttonTab ~= nil then
        for i = 1, #self.buttonTab do
            if self.buttonTab[i]["label"] == "X" then
                self.buttonTab[i]["xPos"]  = self.width - 1
            elseif self.buttonTab[i]["label"] == "^" then
                self.buttonTab[i]["xPos"]  = self.width - 2
            elseif self.buttonTab[i]["label"] == "_" then
                self.buttonTab[i]["xPos"]  = self.width - 3
            end
        end
    end
end

function screen:move(newx, newy)
    if self.isMoveable then
        self.xPos = newx
        self.yPos = newy
    end
end

function screen:center()
    w, h = gpu.getResolution()
    xOffset = math.floor((w - self.width) / 2)
    yOffset = math.floor((h - self.height) / 2)
    self:move(xOffset, yOffset)
end

--TEXT FUNCTIONS

function screen:text(xText, yText, bgCol, tCol, newText, cent)
    if newText == nil then return end
    xText = xText - 1
    yText = yText - 1
    if self.printTab == nil then
        self.printTab = {}
        self.printCount = 0
    end
    self.printCount = self.printCount + 1
    self.printTab[self.printCount] = {
        xPos = xText,
        yPos = yText,
        bgCol = bgCol,
        tCol = tCol,
        text = newText,
        }
    if cent ~= nil then
        self.printTab[self.printCount]["centre"] = true
    else
        self.printTab[self.printCount]["centre"] = false
    end
end

function screen:centerText(xStart, yLine, xEnd, bgCol, tCol, newText)
    offset = math.floor((xEnd - #newText) / 2)
    self:text(xStart + offset, yLine, bgCol, tCol, newText, "centre")
end

--DRAW FUNCTIONS--

function screen:box(stx, sty, w, h, col, scale)
    stx = stx - 1
    sty = sty - 1
    if self.boxTab == nil then
        self.boxTab = {}
        self.boxCount = 0
    end
    self.boxCount = self.boxCount + 1
    self.boxTab[self.boxCount] = {
        xPos = stx,
        yPos = sty,
        width = w,
        height = h,
        colour = col,
        scaleable = false,
        }
    if scale ~= nil then
        self.boxTab[self.boxCount]["scaleable"] = true
    end
end

--DATA READOUT FUNCTIONS--

function screen:addTextBox(identifier, xPos, yPos, width, height, bgCol, tCol)
    if self.textBox == nil then
        self.textBox = {}
        self.textBoxCount = 0
    end
    self.textBoxCount = self.textBoxCount + 1
    self:box(xPos, yPos, width, height, bgCol, "scale")
    self.textBox[self.textBoxCount] = {
        label = identifier,
        xPos = xPos,
        yPos = yPos,
        width = width,
        height = height,
        bgCol = bgCol,
        tCol = tCol,
        selected = false,
        lineCount = 0
        }
    self.textBox[self.textBoxCount]["line"] = {}
end

function screen:printText(id, newText)
    for i = 1, #self.textBox do
        if id == self.textBox[i]["label"] then
            self.textBox[i]["lineCount"] = self.textBox[i]["lineCount"] + 1
            self.textBox[i]["line"][self.textBox[i]["lineCount"]] = newText
            self.needRender = true
            return true
        end
    end
end

--BUTTON FUNCTIONS--

function screen:button(label, stx, sty, w, h, col, returnVal, tCol)
    stx = stx - 1
    sty = sty - 1
    if self.buttonTab == nil then
        self.buttonTab = {}
        self.buttonCount = 0
    end
    self.buttonCount = self.buttonCount + 1
    self.buttonTab[self.buttonCount] = {
        label = label,
        xPos = stx,
        yPos = sty,
        width = w,
        height = h,
        colour = col,
        tCol = tCol,
        returnVal = returnVal,
        }
end

--SUBMENU FUNCTIONS--

function screen:addSubMenu(label)
    if self.subTab == nil then
        self.subTab = {}
        self.subCount = 0
    end
    self.subCount = self.subCount + 1
    self.subTab[self.subCount] = {
        label = label,
        open = false,
        }
end

function screen:addSubMenuItem(subMenuLabel, newEntry, retVal)
    for i = 1, #self.subTab do
        if self.subTab[i]["label"] == subMenuLabel then
            if self.subTab[i]["entries"] == nil then
                self.subTab[i]["entries"] = {}
                self.subTab[i]["entryCount"] = 0
            end
            self.subTab[i]["entryCount"] = self.subTab[i]["entryCount"] + 1
            self.subTab[i]["entries"][self.subTab[i]["entryCount"]] = {
                label = newEntry,
                returnVal = retVal,
                }
            return true
        end
    end
end

--TEXT INPUT FUNCTIONS--

function screen:inputBox(identifier, xPos, yPos, width, height, scale, bgCol, fgCol)
    if fgCol == nil then fgCol = 0x000000 end
    if bgCol == nil then bgCol = 0xFFFFFF end
    xPos = xPos - 1
    yPos = yPos - 1
    self.textInputCount = self.textInputCount + 1
    self.textInputs[self.textInputCount] = {
        label = identifier,
        xPos = xPos,
        yPos = yPos,
        width = width,
        height = height,
        scaleable = false,
        bgCol = bgCol,
        fgCol = fgCol,
        selected = false,
        cursorX = 1,
        cursorY = 1,
        }
    self.textInputs[self.textInputCount]["text"] = {}
    if scale ~= nil then
        self.textInputs[self.textInputCount]["scaleable"] = true
        self:box(xPos + 1, yPos + 1, width, height, bgCol, "scale")
    else
        self:box(xPos + 1, yPos + 1, width, height, bgCol)
    end
end

function screen:addText(char)
    for i = 1, #self.textInputs do
        gpu.setBackground(self.textInputs[i]["bgCol"])
        gpu.setForeground(self.textInputs[i]["fgCol"])
        if self.textInputs[i]["selected"] then
            if char == "enter" then
                local pLine = self.textInputs[i]["text"][self.textInputs[i]["cursorY"]]
                if self.textInputs[i]["height"] > 1 then
                    if self.textInputs[i]["cursorX"] < #pLine then
                        local oldLine = string.sub(pLine, 1, self.textInputs[i]["cursorX"] - 1)
                        local newLine = string.sub(pLine, self.textInputs[i]["cursorX"], #pLine)
                        self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = oldLine
                        for j = #self.textInputs[i]["text"] + 1, self.textInputs[i]["cursorY"] + 1, -1 do
                            self.textInputs[i]["text"][j] = self.textInputs[i]["text"][j - 1]
                        end
                        self.textInputs[i]["cursorY"] = self.textInputs[i]["cursorY"] + 1
                        self.textInputs[i]["cursorX"] = 1
                        self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = newLine
                        self.needRender = true
                    else
                        if self.textInputs[i]["cursorY"] < #self.textInputs[i]["text"] then
                            for j = #self.textInputs[i]["text"] + 1, self.textInputs[i]["cursorY"] + 1, -1 do
                                self.textInputs[i]["text"][j] = self.textInputs[i]["text"][j - 1]
                            end
                        end
                        self.textInputs[i]["cursorY"] = self.textInputs[i]["cursorY"] + 1
                        self.textInputs[i]["cursorX"] = 1
                        self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = " "
                        self.needRender = true
                    end
                end
                return true
            elseif char == "back" then
                if self.textInputs[i]["cursorX"] > 1 then
                    if self.textInputs[i]["cursorX"] <= #self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] then
                        local pLine = self.textInputs[i]["text"][self.textInputs[i]["cursorY"]]
                        local preLine = string.sub(pLine, 1, self.textInputs[i]["cursorX"] - 2)
                        local postLine = string.sub(pLine, self.textInputs[i]["cursorX"], #pLine)
                        self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = preLine..postLine
                        self.textInputs[i]["cursorX"] = self.textInputs[i]["cursorX"] - 1
                        self.needRender = true
                    else
                        self.textInputs[i]["cursorX"] = self.textInputs[i]["cursorX"] - 1
                        self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = string.sub(self.textInputs[i]["text"][self.textInputs[i]["cursorY"]], 1, #self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] - 1)
                        self.needRender = true
                    end
                else
                    if self.textInputs[i]["cursorY"] > 1 then
                        self.textInputs[i]["cursorX"] = #self.textInputs[i]["text"][self.textInputs[i]["cursorY"] - 1] + 1
                        self.textInputs[i]["text"][self.textInputs[i]["cursorY"] - 1] = self.textInputs[i]["text"][self.textInputs[i]["cursorY"] - 1]..self.textInputs[i]["text"][self.textInputs[i]["cursorY"]]
                        self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = nil
                        for j = self.textInputs[i]["cursorY"] + 1, #self.textInputs[i]["text"] do
                            self.textInputs[i]["text"][j - 1] = self.textInputs[i]["text"][j]
                            self.textInputs[i]["text"][j] = nil
                        end
                        self.textInputs[i]["cursorY"] = self.textInputs[i]["cursorY"] - 1
                        self.needRender = true
                    end
                end
                return true
            elseif char == "delete" then
                if self.textInputs[i]["cursorX"] < #self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] then
                    local pLine = self.textInputs[i]["text"][self.textInputs[i]["cursorY"]]
                    local preLine = string.sub(pLine, 1, self.textInputs[i]["cursorX"] - 1)
                    local postLine = string.sub(pLine, self.textInputs[i]["cursorX"] + 1, #pLine)
                    self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = preLine..postLine
                    self.needRender = true
                else
                    local pLine = self.textInputs[i]["text"][self.textInputs[i]["cursorY"]]
                    local preLine = string.sub(pLine, 1, self.textInputs[i]["cursorX"] - 1)
                    local postLine = self.textInputs[i]["text"][self.textInputs[i]["cursorY"] + 1]
                    self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = preLine..postLine
                    for i = self.textInputs[i]["cursorY"] + 1, #self.textInputs[i]["text"] + 1 do
                        self.textInputs[i]["text"][i] = nil
                        if self.textInputs[i]["text"][i + 1] ~= nil then
                            self.textInputs[i]["text"][i] = self.textInputs[i]["text"][i + 1]
                        end
                    end
                    self.needRender = true
                end
                return true
            elseif char == "up" then
                if self.textInputs[i]["cursorY"] > 1 then
                    self.textInputs[i]["cursorY"] = self.textInputs[i]["cursorY"] - 1
                end
                self.needRender = true
                return true
            elseif char == "down" then
                if self.textInputs[i]["cursorY"] < #self.textInputs[i]["text"] then
                    self.textInputs[i]["cursorY"] = self.textInputs[i]["cursorY"] + 1
                end
                self.needRender = true
                return true
            elseif char == "left" then
                if self.textInputs[i]["cursorX"] > 1 then
                    self.textInputs[i]["cursorX"] = self.textInputs[i]["cursorX"] - 1
                else
                    if self.textInputs[i]["cursorY"] > 1 then
                        self.textInputs[i]["cursorY"] = self.textInputs[i]["cursorY"] - 1
                        self.textInputs[i]["cursorX"] = #self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] + 1
                    else
                        self.textInputs[i]["cursorX"] = 1
                    end
                end
                self.needRender = true
                return true
            elseif char == "right" then
                if self.textInputs[i]["cursorX"] < #self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] + 1 then
                    self.textInputs[i]["cursorX"] = self.textInputs[i]["cursorX"] + 1
                else
                    if self.textInputs[i]["cursorY"] < #self.textInputs[i]["text"] then
                        self.textInputs[i]["cursorY"] = self.textInputs[i]["cursorY"] + 1
                        self.textInputs[i]["cursorX"] = 1
                    else
                        self.textInputs[i]["cursorX"] = #self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] + 1
                    end
                end
                self.needRender = true
                return true
            elseif char == "home" then
                self.textInputs[i]["cursorX"] = 1
                self.needRender = true
                return true
            elseif char == "end" then
                self.textInputs[i]["cursorX"] = #self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] + 1
                self.needRender = true
                return true
            end
            if char == "space" or char == "SPACE" then char = " " end
            if char == "1" and keyboard.isShiftDown() == true then char = "!" end
            if char == "2" and keyboard.isShiftDown() == true then char = "\"" end
            if char == "3" and keyboard.isShiftDown() == true then char = "#" end
            if char == "4" and keyboard.isShiftDown() == true then char = "~" end
            if char == "5" and keyboard.isShiftDown() == true then char = "%" end
            if char == "6" and keyboard.isShiftDown() == true then char = "^" end
            if char == "7" and keyboard.isShiftDown() == true then char = "&" end
            if char == "8" and keyboard.isShiftDown() == true then char = "*" end
            if char == "9" and keyboard.isShiftDown() == true then char = "(" end
            if char == "0" and keyboard.isShiftDown() == true then char = ")" end
            if char == "period" then char = "." end
            if char == "numpaddecimal" then char = "." end
            if char == "PERIOD" then char = ">" end
            if char == "comma" then char = "," end
            if char == "COMMA" then char = "<" end
            if char == "apostrophe" then char = "'" end
            if char == "AT" then char = "@" end
            if char == "semicolon" then char = ";" end
            if char == "COLON" then char = ":" end
            if char == "slash" then char = "/" end
            if char == "SLASH" then char = "?" end
            if char == "lbracket" then char = "[" end
            if char == "LBRACKET" then char = "{" end
            if char == "rbracket" then char = "]" end
            if char == "RBRACKET" then char = "}" end
            if char == "UNDERLINE" then char = "_" end
            if char == "equals" then char = "=" end
            if char == "EQUALS" then char = "+" end
            if char == "numpadadd" then char = "+" end
            if char == "minus" or char == "numpadminus" then char = "-" end
            if char == "numpadmul" then char = "*" end
            if char == "CIRCUMFLEX" then char = "^" end
            if char == nil then char = " " end
            if char == "lshift" or char == "rshift" or char == "LSHIFT" or char == "RSHIFT" then
                return true
            end
            if #char > 1 then char = string.sub(char, 1, 1) end
            if keyboard.isShiftDown() then
                char = string.upper(char)
            end
            if self.textInputs[i]["cursorX"] <= #self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] then
                local pLine = self.textInputs[i]["text"][self.textInputs[i]["cursorY"]]
                local preLine = string.sub(pLine, 1, self.textInputs[i]["cursorX"] - 1)
                local postLine = char..string.sub(pLine, self.textInputs[i]["cursorX"], #pLine)
                self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = preLine..postLine
                self.needRender = true
            elseif #self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] >= 1 then
                self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = self.textInputs[i]["text"][self.textInputs[i]["cursorY"]]..char
                self.needRender = true
            else
                self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] = char
                self.needRender = true
            end
            self.textInputs[i]["cursorX"] = self.textInputs[i]["cursorX"] + 1
            self:renderTextInputs()
            return true
        end
    end
    gpu.setBackground(black)
    gpu.setForeground(white)
    return false
end

function screen:loadText(identifier, path)
    local data = io.open(path, "r")
    local count = 0
    for i = 1, #self.textInputs do
        if self.textInputs[i]["label"] == identifier then
            while true do
                local dataLine = data:read("*line")
                if dataLine ~= nil then
                    count = count + 1
                    self.textInputs[i]["text"][count] = dataLine
                else
                    data:close()
                    break
                end
            end
            self.textInputs[i]["cursorX"] = 1
            self.textInputs[i]["cursorY"] = 1
            if self.textInputs[i]["text"][1] == nil then self.textInputs[i]["text"][1] = " " end
            return true
        end
    end
end

function screen:saveText(identifier, path)
    local data = io.open(path, "w")
    for i = 1, #self.textInputs do
        if self.textInputs[i]["label"] == identifier then
            local count = 1
            while true do
                if self.textInputs[i]["text"][count] ~= nil then
                    data:write(self.textInputs[i]["text"][count].."\n")
                else
                    data:close()
                    return true
                end
                count = count + 1
            end
        end
    end
    return false
end

--FILE SYSTEM FUNCTIONS--

function screen:addFileViewer(xPos, yPos, w, h, col, path)
    self:box(xPos, yPos, w, h, col, "scale")
    xPos = xPos - 1
    yPos = yPos - 1
    if self.fileViewer == nil then
        self.fileViewer = {}
        self.fvCount = 0
    end
    self.fvCount = self.fvCount + 1
    self.fileViewer[self.fvCount] = {
        xPos = xPos,
        yPos = yPos,
        width = w,
        height = h,
        colour = col,
        path = path,
        scrollPos = 1,
        }
    self.fileViewer[self.fvCount]["list"] = {}
    self.fileViewer[self.fvCount]["list"] = self:assembleFileTable(path)
end

function screen:assembleFileTable(path)
    local alphaString = "0123456789AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz"
    local pathList, error = fs.list(path)
    local dataTab = {}
    i = 0
    for key in pathList do
        i = i + 1
        if string.sub(key, #key, #key) == "/" then
            key = string.sub(key, 1, #key - 1)
        end
        dataTab[i] = key
    end
    local returnTab = {}
    local rtCount = 0
    for l = 1, #alphaString do
        for i = 1, #dataTab do
            if dataTab[i] ~= nil then
                if fs.isDirectory(path..dataTab[i]) then
                    if string.sub(dataTab[i], 1, 1) == string.sub(alphaString, l, l) then
                        rtCount = rtCount + 1
                        returnTab[rtCount] = dataTab[i]
                        --dataTab[i] = nil
                        --break
                    end
                end
            end
        end
    end
    for l = 1, #alphaString do
        for i = 1, #dataTab do
            if dataTab[i] ~= nil then
                if not fs.isDirectory(path..dataTab[i]) then
                    if string.sub(dataTab[i], 1, 1) == string.sub(alphaString, l, l) then
                        rtCount = rtCount + 1
                        returnTab[rtCount] = dataTab[i]
                        --dataTab[i] = nil
                        --break
                    end
                end
            end
        end
    end
    return returnTab
end
    
--IMAGE FUNCTIONS--

function screen:newImage(label, xPos, yPos, sizeX, sizeY)
    if self.imTab == nil then
        self.imTab = {}
        self.imCount = 0
    end
    self.imCount = self.imCount + 1
    self.imTab[self.imCount] = {
        label = label,
        xPos = xPos,
        yPos = yPos,
        width = sizeX,
        height = sizeY,
        hidden = false,
        layers = 1,
        pages = 1,
    }
    self.imTab[self.imCount]["layerData"] = {}
    self.imTab[self.imCount]["layerData"][1] = {}
    self.imTab[self.imCount]["layerData"][1]["hidden"] = false
    for i = sizeY, 1, -1 do
        self.imTab[self.imCount]["layerData"][1][i] = {}
        for j = 1, sizeX do
            self.imTab[self.imCount]["layerData"][1][i][j] = {
                fg = black,
                bg = white,
                char = " ",
            }
        end
    end
end

function screen:newImageLayer(label)
    local id = 0
    for i = 1, #self.imTab do
        if self.imTab[i]["label"] == label then
            id = i
            break
        end
    end
    if id == 0 then return false end
    self.imTab[id]["layers"] = self.imTab[id]["layers"] + 1
    self.imTab[id]["layerData"][self.imTab[id]["layers"]] = {}
    self.imTab[id]["layerData"][self.imTab[id]["layers"]]["hidden"] = false
    for y = self.imTab[id]["height"], 1, -1 do
        self.imTab[id]["layerData"][self.imTab[id]["layers"]][y] = {}
        for x = 1, self.imTab[id]["width"] do
            self.imTab[id]["layerData"][self.imTab[id]["layers"]][y][x] = {
                bg = "trans",
                fg = 0xFFFFFF,
                char = " ",
                }
        end
    end
    if self.imTab[id]["layers"] % 10 == 0 then
        self.imTab[id]["pages"] = self.imTab[id]["pages"] + 1
    end
end

function screen:saveImage(label, path)
    if self.imTab ~= nil then
        local imId = 0
        for i = 1, #self.imTab do
            if self.imTab[i]["label"] == label then
                file = io.open(path, "w")
                file:write(serial.serialize(self.imTab[i]))
                file:close()
                return true
            end
        end
    end
    return false
end

function screen:loadImage(label, path, x, y)
    x = x - 1
    y = y - 1
    if fs.exists(path) then
        if self.imTab == nil then
            self.imTab = {}
            self.imCount = 0
        end
        self.imCount = self.imCount + 1
        file = io.open(path, "r")
        self.imTab[self.imCount] = serial.unserialize(file:read("*all"))
        file:close()
        self.imTab[self.imCount]["xPos"] = x
        self.imTab[self.imCount]["yPos"] = y
        return true
    end
    return false
end

function screen:loadSmImage(label, path, x, y)
    x = x - 1
    y = y - 1
    if fs.exists(path) then
        if self.smImTab == nil then
            self.smImTab = {}
            self.smImCount = 0
        end
        self.smImCount = self.smImCount + 1
        file = io.open(path, "r")
        self.smImTab[self.smImCount] = serial.unserialize(file:read("*all"))
        file:close()
        self.smImTab[self.smImCount]["xPos"] = x
        self.smImTab[self.smImCount]["yPos"] = y
        return true
    end
    return false
end

function screen:compressImage(id)
    local pTab = {}
    for i = 1, #self.imTab[id]["layerData"] do
        pTab[i] = {}
        if self.imTab[id]["layerData"][i]["hidden"] then
            pTab[i]["hidden"] = true
        else
            pTab[i]["hidden"] = false
        end
        for line = #self.imTab[id]["layerData"][i], 1, -1 do
            --print("Compressing layer "..i.." line "..line)
            local colCount = 0
            local curBg = self.imTab[id]["layerData"][i][line][1]["bg"]
            local curFg = self.imTab[id]["layerData"][i][line][1]["fg"]
            local curSt = self.imTab[id]["layerData"][i][line][1]["char"]
            local stx = self.imTab[id]["xPos"]
            local sty = self.imTab[id]["yPos"] + (line - 1)
            pTab[i][line] = {}
            for pix = 1, #self.imTab[id]["layerData"][i][line] do
                curBg = self.imTab[id]["layerData"][i][line][pix]["bg"]
                curFg = self.imTab[id]["layerData"][i][line][pix]["fg"]
                curSt = self.imTab[id]["layerData"][i][line][pix]["char"]
                if curBg == "trans" then
                    for x = i, 1, -1 do
                        if not self.imTab[id]["layerData"][x]["hidden"] then
                            if self.imTab[id]["layerData"][x][line][pix]["bg"] ~= "trans" then
                                curBg = self.imTab[id]["layerData"][x][line][pix]["bg"]
                            end
                        elseif x == 1 then
                            curBg = self.imTab[id]["layerData"][x][line][pix]["bg"]
                        end
                    end
                end
                if pix == 1 or curBg ~= pTab[i][line][colCount]["bg"] or curFg ~= pTab[i][line][colCount]["fg"] then
                    colCount = colCount + 1
                    pTab[i][line][colCount] = {
                        bg = curBg,
                        fg = curFg,
                        st = curSt,
                        yp = sty,
                        xp = stx,
                        }
                else
                    pTab[i][line][colCount]["st"] = pTab[i][line][colCount]["st"]..curSt
                end
                stx = stx + 1
            end
        end
    end
    return(pTab)
end

--CLICK CHECK FUNCTIONS

function screen:clicked(x, y)
    local minx = self.xPos
    local miny = self.yPos
    local maxx = minx + self.width
    local maxy = miny + self.height
    if x >= minx and x <= maxx then
        if y >= miny and y <= maxy then
            self.selected = true
            self.priority = 9
            return true
        end
    end
    self.selected = false
    self.grabbed = false
    return false
end

function screen:buttonClicked(x, y)
    if self.buttonTab ~= nil then
        for i = 1, #self.buttonTab do
            local minx = self.xPos + (self.buttonTab[i]["xPos"] - 1)
            local miny = self.yPos + (self.buttonTab[i]["yPos"] - 1)
            local maxx = minx + self.buttonTab[i]["width"]
            local maxy = miny + self.buttonTab[i]["height"]
            if x >= minx and x <= maxx then
                if y >= miny and y <= maxy then
                    self.grabbed = false
                    return(self.buttonTab[i]["returnVal"])
                end
            end
        end
    end
    return false
end

function screen:textInputClicked(x, y)
    local tiFound = false
    if self.textInputs ~= nil then
        for i = 1, #self.textInputs do
            local minx = self.xPos + self.textInputs[i]["xPos"]
            local miny = self.yPos + self.textInputs[i]["yPos"]
            local maxx = minx + self.textInputs[i]["width"]
            local maxy = miny + self.textInputs[i]["height"]
            if x >= minx and x <= maxx then
                if y >= miny and y <= maxy then
                    self.textInputs[i]["selected"] = true
                    self.textInputs[i]["cursorX"] = #self.textInputs[i]["text"][self.textInputs[i]["cursorY"]] + 1
                    self.grabbed = false
                    tiFound = true
                else
                    self.textInputs[i]["selected"] = false
                end
            else
                self.textInputs[i]["selected"] = false
            end
        end
    end
    if tiFound then return true end
    return false
end

function screen:subMenuClicked(x, y)
    local retVal = ""
    if self.subTab ~= nil then
        local xOff = 3
        for i = 1, #self.subTab do
            if self.subTab[i]["open"] then
                local yOff = self.yPos + 1
                for j = 1, #self.subTab[i]["entries"] do
                    local maxLength = 0
                    for k = 1, #self.subTab[i]["entries"] do
                        if #self.subTab[i]["entries"][k]["label"] > maxLength then
                            maxLength = #self.subTab[i]["entries"][k]["label"]
                        end
                    end
                    local minx = self.xPos + xOff
                    local maxx = minx + (maxLength + 1)
                    if x >= minx and x <= maxx then
                        if y == yOff + j then
                            retVal = self.subTab[i]["entries"][j]["returnVal"]
                            self.grabbed = true
                        end
                    end
                end
                xOff = xOff + (#self.subTab[i]["label"] + 1)
            end
        end
        if retVal == "" then
            local newOffset = 3
            for i = 1, #self.subTab do
                local minx = self.xPos + newOffset
                local maxx = minx + #self.subTab[i]["label"]
                if y == self.yPos + 1 then
                    if x >= minx and x <= maxx then
                        self.subTab[i]["open"] = not self.subTab[i]["open"]
                        retVal = true
                        self.grabbed = true
                    else
                        self.subTab[i]["open"] = false
                        if not retVal then retVal = false end
                    end
                end
                newOffset = newOffset + (#self.subTab[i]["label"] + 1)
            end
        else
            for i = 1, #self.subTab do
                self.subTab[i]["open"] = false
            end
        end
        return(retVal)
    end
    return false
end

--RENDER FUNCTIONS--

function screen:renderBoxes()
    if self.boxTab ~= nil then
        for i = 1, #self.boxTab do
            gpu.setBackground(self.boxTab[i]["colour"])
            gpu.fill(self.xPos + self.boxTab[i]["xPos"], self.yPos + self.boxTab[i]["yPos"], self.boxTab[i]["width"], self.boxTab[i]["height"], " ")
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderText()
    if self.printTab ~= nil then
        for i = 1, #self.printTab do
            gpu.setBackground(self.printTab[i]["bgCol"])
            gpu.setForeground(self.printTab[i]["tCol"])
            gpu.set(self.xPos + self.printTab[i]["xPos"], self.yPos + self.printTab[i]["yPos"], self.printTab[i]["text"])
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderTextBoxes()
    if self.textBox ~= nil then
        local startLine = 0
        for i = 1, #self.textBox do
            gpu.setBackground(self.textBox[i]["bgCol"])
            gpu.setForeground(self.textBox[i]["tCol"])
            if self.textBox[i]["lineCount"] >= self.textBox[i]["height"] then
                startLine = #self.textBox[i]["line"] - (self.textBox[i]["height"] - 2)
            else
                startLine = 1
            end
            curLine = 0
            for j = startLine, #self.textBox[i]["line"] do
                local printLine = self.textBox[i]["line"][j]
                if #printLine > self.textBox[i]["width"] then
                    printLine = string.sub(printLine, #printLine - self.textInputs[i]["width"], #printLine)
                end
                gpu.set(self.xPos + self.textBox[i]["xPos"], self.yPos + (self.textBox[i]["yPos"] + (curLine)), printLine)
                curLine = curLine + 1
            end
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderButtons()
    if self.buttonTab ~= nil then
        for i = 1, #self.buttonTab do
            if self.buttonTab[i]["colour"] ~= "trans" then
                if self.buttonTab[i]["tCol"] ~= nil then
                    gpu.setForeground(self.buttonTab[i]["tCol"])
                else
                    gpu.setForeground(black)
                end
                gpu.setBackground(self.buttonTab[i]["colour"])
                gpu.fill(self.xPos + self.buttonTab[i]["xPos"], self.yPos + self.buttonTab[i]["yPos"], self.buttonTab[i]["width"], self.buttonTab[i]["height"], " ")
                local midLine = math.floor(self.buttonTab[i]["height"] / 2)
                local printLine = self.buttonTab[i]["label"]
                if #printLine > self.buttonTab[i]["width"] then
                    printLine = string.sub(printLine, 1, self.buttonTab[i]["width"])
                end
                offset = math.floor((self.buttonTab[i]["width"] - #printLine) / 2)
                gpu.set(self.xPos + (self.buttonTab[i]["xPos"] + offset), self.yPos + (self.buttonTab[i]["yPos"] + midLine), printLine)
            end
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderTextInputs()
    local printLine = ""
    if self.textInputs ~= nil then
        for i = 1, #self.textInputs do
            if self.textInputs[i]["text"] ~= nil then
                gpu.setBackground(self.textInputs[i]["bgCol"])
                gpu.setForeground(self.textInputs[i]["fgCol"])
                local startLine = 1
                if #self.textInputs[i]["text"] > self.textInputs[i]["height"] then
                    if self.textInputs[i]["cursorY"] > self.textInputs[i]["height"] then
                        startLine = (self.textInputs[i]["cursorY"] - self.textInputs[i]["height"]) + 1 
                    end
                end
                endLine = (startLine + self.textInputs[i]["height"]) - 1
                for j = startLine, endLine do
                    local yOffset = j - startLine
                    if self.textInputs[i]["text"][j] ~= nil then
                        printLine = self.textInputs[i]["text"][j]
                        if self.textInputs[i]["cursorY"] == j then
                            if self.textInputs[i]["cursorX"] > 1 then
                                local lSplit = string.sub(self.textInputs[i]["text"][j], 1, self.textInputs[i]["cursorX"] - 1)
                                local rSplit = string.sub(printLine, self.textInputs[i]["cursorX"], #printLine)
                                printLine = lSplit.."_"..rSplit
                            else
                                printLine = "_"..printLine
                            end
                        end
                        if #printLine > self.textInputs[i]["width"] then
                            printLine = string.sub(printLine, #printLine - (self.textInputs[i]["width"] - 2), #printLine)
                        end
                        if self.textInputs[i]["label"] ~= "password" then
                            gpu.set(self.xPos + self.textInputs[i]["xPos"], self.yPos + (self.textInputs[i]["yPos"] + yOffset), printLine)
                        else
                            for k = 1, #printLine do
                                gpu.set(self.xPos + (self.textInputs[i]["xPos"] + (k - 1)), self.yPos + self.textInputs[i]["yPos"], "*")
                            end
                        end
                    end
                end
            end
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderSubMenus()
    if self.subTab ~= nil then
        local w, h = gpu.getResolution()
        local newOffset = 2
        for i = 1, #self.subTab do
            if self.subTab[i]["open"] then
                gpu.setBackground(0x666666)
                gpu.setForeground(0x000000)
                gpu.set(self.xPos + newOffset, self.yPos + 1, self.subTab[i]["label"])
                gpu.setBackground(0x999999)
                gpu.setForeground(0x000000)
                local maxLength = 0
                for j = 1, #self.subTab[i]["entries"] do
                    if #self.subTab[i]["entries"][j]["label"] > maxLength then
                        maxLength = #self.subTab[i]["entries"][j]["label"]
                    end
                end
                gpu.fill(self.xPos + newOffset, self.yPos + 2, maxLength + 1, #self.subTab[i]["entries"], " ")
                for j = 1, #self.subTab[i]["entries"] do
                    if self.yPos > h / 2 then
                        gpu.set(self.xPos + newOffset, self.yPos - (j + 1), self.subTab[i]["entries"][j]["label"])
                    else
                        gpu.set(self.xPos + newOffset, self.yPos + (j + 1), self.subTab[i]["entries"][j]["label"])
                    end
                end
            else
                gpu.setBackground(0x999999)
                gpu.setForeground(0x000000)
                gpu.set(self.xPos + newOffset, self.yPos + 1, self.subTab[i]["label"])
            end
            newOffset = newOffset + (#self.subTab[i]["label"] + 1)
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderFileLists()
    if self.fileViewer ~= nil then
        for i = 1, #self.fileViewer do
            local startPos = 1
            if #self.fileViewer[i]["list"] > self.fileViewer[i]["height"] then
                startPos = self.fileViewer[i]["scrollPos"]
            end
            gpu.setForeground(0x000000)
            gpu.setBackground(self.fileViewer[i]["colour"])
            for j = startPos, startPos + (self.fileViewer[i]["height"] - 2) do
                if self.fileViewer[i]["list"][j] ~= nil then
                    if fs.isDirectory(self.fileViewer[i]["path"]..self.fileViewer[i]["list"][j]) then
                        gpu.setBackground(0xFF9900)
                        gpu.set(self.xPos + self.fileViewer[i]["xPos"], self.yPos + (self.fileViewer[i]["yPos"] + (j - (startPos - 1))), "¬")
                    else
                        gpu.setBackground(0xCCCCCC)
                        gpu.set(self.xPos + self.fileViewer[i]["xPos"], self.yPos + (self.fileViewer[i]["yPos"] + (j - (startPos - 1))), "=")
                    end
                    gpu.setBackground(self.fileViewer[i]["colour"])
                    gpu.set(self.xPos + (self.fileViewer[i]["xPos"] + 1), self.yPos + (self.fileViewer[i]["yPos"] + (j - (startPos - 1))), self.fileViewer[i]["list"][j])
                end
            end
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:compileLineTable(id, layer, line)
    local curBg = self.imTab[id]["layerData"][layer][line][1]["bg"]
    local curFg = self.imTab[id]["layerData"][layer][line][1]["fg"]
    local curSt = self.imTab[id]["layerData"][layer][line][1]["char"]
    local stx = self.xPos + self.imTab[id]["xPos"]
    local sty = self.yPos + (self.imTab[id]["yPos"] + (line - 1))
    local colCount = 0
    local pTab = {}
    for i = 1, #self.imTab[id]["layerData"][layer][line] do
        curBg = self.imTab[id]["layerData"][layer][line][i]["bg"]
        curFg = self.imTab[id]["layerData"][layer][line][i]["fg"]
        curSt = self.imTab[id]["layerData"][layer][line][i]["char"]
        if curBg == "trans" then
            for x = layer, 1, -1 do
                if not self.imTab[id]["layerData"][x]["hidden"] then
                    if self.imTab[id]["layerData"][x][line][i]["bg"] ~= "trans" then
                        curBg = self.imTab[id]["layerData"][x][line][i]["bg"]
                    end
                elseif self.running then
                    if x == 1 then
                        curBg = self.imTab[id]["layerData"][x][line][i]["bg"]
                    end
                end
            end
        end
        if i == 1 or curBg ~= pTab[colCount]["bg"] or curFg ~= pTab[colCount]["fg"] then
            colCount = colCount + 1
            pTab[colCount] = {
                bg = curBg,
                fg = curFg,
                st = curSt,
                yp = sty,
                xp = stx,
            }
        else
            pTab[colCount]["st"] = pTab[colCount]["st"]..curSt
        end
        stx = stx + 1
    end
    return(pTab)
end

function screen:renderImages()
    local prTab = 0
    if self.imTab ~= nil then
        for i = 1, #self.imTab do
            for l = 1, #self.imTab[i]["layerData"] do
                if not self.imTab[i]["layerData"][l]["hidden"] then
                    for r = #self.imTab[i]["layerData"][l], 1, -1 do
                        prTab = self:compileLineTable(i, l, r)
                        for p = 1, #prTab do
                            if prTab[p]["bg"] ~= "trans" then
                                gpu.setBackground(prTab[p]["bg"])
                                gpu.setForeground(prTab[p]["fg"])
                                gpu.set(prTab[p]["xp"], prTab[p]["yp"], prTab[p]["st"])
                            end
                        end
                    end
                end
            end
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderSmImages()
    if self.smImTab ~= nil then
        for i = 1, #self.smImTab do
            for layer = 1, #self.smImTab[i] do
                for line = 1, #self.smImTab[i][layer] do
                    if not self.smImTab[i][layer]["hidden"] then
                        for col = 1, #self.smImTab[i][layer][line] do
                            local xPos = self.xPos + (self.smImTab[i]["xPos"] + self.smImTab[i][layer][line][col]["xp"])
                            local yPos = self.yPos + (self.smImTab[i]["yPos"] + self.smImTab[i][layer][line][col]["yp"])
                            if self.smImTab[i][layer][line][col]["bg"] ~= "trans" then
                                gpu.setBackground(self.smImTab[i][layer][line][col]["bg"])
                                gpu.setForeground(self.smImTab[i][layer][line][col]["fg"])
                                gpu.set(xPos, yPos, self.smImTab[i][layer][line][col]["st"])
                            end
                        end
                    end
                end
            end
        end
    end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:renderOutline()
    gpu.setBackground(0xFFFFFF)
    gpu.fill(self.xPos, self.yPos, self.width, self.height, " ")
    gpu.setBackground(0x000000)
    gpu.fill(self.xPos + 2, self.yPos + 1, self.width - 4, self.height - 2, " ")
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
end

function screen:render()
    if not self.renderBool then return end
    if self.grabbed then
        self:renderOutline()
        return
    end
    self:renderBoxes()
    self:renderTextBoxes()
    self:renderTextInputs()
    self:renderSubMenus()
    self:renderFileLists()
    self:renderImages()
    self:renderSmImages()
    self:renderButtons()
    self:renderText()
end

--OTHER FUNCTIONS--

return(screen)