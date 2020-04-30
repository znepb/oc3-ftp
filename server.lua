-- oc3-ftp Server File (1.4)
-- This program should be ran on an OC computer.
-- For setup info, see README.md

local comp = require("component")
 
local ok, err = pcall(function()
  local fs = require("filesystem")
  local event = require("event")
  local serialization = require("serialization")
  local gpu = comp.gpu
  
  local protectedFiles = {
    "ftp-cc.lua",
    ".shrc",
    "ftp-api.lua"
  }
  
  local monthes = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
  
  local drivePath = "/mnt/2ab"
  local drive = fs.proxy("raid")
  
  local modems = comp.list("modem")
  --local drive = fs.proxy("raid")
  local modemID = ""
  local modem
  
  for i, v in pairs(modems) do
    modemID = i
    modem = v
    break
  end
  
  -- Messaging functions
  
  local function successChecker(err)
    if err then
      return {err = err, success = false}
    else
      return {success = true}
    end
  end
  
  local function reply(data, orgin)
    data.type = "reply"
    data.id = math.random(1, 10^6)
    data.orginID = orgin
    comp.invoke(modemID, "transmit", 889, 888, data)
  end
  
  -- File functions
  
  local function isProtected(file)
    for i, v in pairs(protectedFiles) do
      if fs.name(file) == v then
        return true
      end
    end
    return false
  end
  
  local function readFile(file)
    --print(drivePat, file)
    local contents = ""
    local lineNumber = 1
    for line in io.lines(fs.concat("/mnt/2ab", file)) do
      contents = contents .. line .. "\n"
      lineNumber = lineNumber + 1
      if lineNumber % 100 == 0 and lineNumber ~= 0 then
        os.sleep(0.1)
      end
    end
    return contents
  end
  
  
  -- Logging functions
  
  local function formatMessage(p, message)
    --print(os.date().day)
    print(("%s %d, %d @ %d:%d:%d [%s] %s"):format(os.date("%b"), os.date("%d"), os.date("%Y"), os.date("%H"), os.date("%M"), os.date("%S"), p, message))
  end
  
  local function info(message)
    gpu.setForeground(0x66b6ff)
    formatMessage("INFO", message)
  end
  
  local function success(message)
    gpu.setForeground(0x00ff00)
    formatMessage("SUCCESS", message)
  end
  
  local function warn(message)
    gpu.setForeground(0xff6d00)
    formatMessage("WARN", message)
  end
  
  comp.invoke(modemID, "open", 888)
  success("Server online!")
  
  while true do
    local event, _, channel, replyCh, message = event.pullMultiple("modem_message")
    os.sleep(0.2)
    if message.type == "request" then
      if message.requestType == "list" then
        info("Requestsed listing of " .. message.directory or "/")
        local listing = drive.list(message.directory or "/")
      
        success("Listed " .. #listing .. " files")
      
        reply({content = serialization.serialize(listing)}, message.requestIdentifier)
      elseif message.requestType == "listFormatted" then
        info("Requested formatted listing of " .. message.directory or "/")
        local listing = drive.list(message.directory or "/")
        local formatted_listing = {}
      
        for i, file in pairs(listing) do
          if i ~= "n" then
            local insert = {name = file, isDir = false, protected = false}
        
            if isProtected(file) then
              insert.protected = true
            end
            if string.sub(file, -1) == "/"  then
              insert.isDir = true
            end
          
            table.insert(formatted_listing, insert)
          end
        end
      
        reply({content = serialization.serialize(formatted_listing)}, message.requestIdentifier)
      elseif message.requestType == "ping" then
        reply({content = "pong"})
      elseif message.requestType == "isRestricted" then
        if isProtected(message.path) then
          reply({protected = true}, message.requestIdentifier)
        else
          reply({protected = false}, message.requestIdentifier)
        end
      elseif message.requestType == "delete" then
        if isProtected(message.path) then
          warn("User requested to delete a file that cannot be deleted, rejecting")
          reply(successChecker("File is protected"))
        else
          if not drive.exists(message.path) then
            warn("File not found")
            reply(successChecker("File not found"))
          else
            drive.remove(message.path)
            reply({success = true}, message.requestIdentifier)
          end
        end
      elseif message.requestType == "upload" then
        if isProtected(message.path) then
          warn("User requested to edit a file that cannot be edited, rejecting")
          reply(successChecker("File is protected"))
        else
          info("Requested upload of file to " .. message.path)
          local file = drive.open(message.path, "w")
          drive.write(file, message.contents)
          drive.close(file)
          success("Saved " .. #message.contents .. " bytes of text to " .. message.path)
      
          reply({success = true}, message.requestIdentifier)
        end
      elseif message.requestType == "download" then
        info("Requested download of file " .. message.path)
        if drive.exists(message.path) then
          local contents = readFile(message.path)
        
          reply({success = true, content = contents}, message.requestIdentifier)
        
          success("Sent " .. #contents .. " bytes")
        else
          warn("File not found")
          reply(successChecker("File not found"), message.requestIdentifier)
        end
      end
    end
  end
end)
 
if not ok then
  local computer = comp.computer
  print(err)
  for i = 1, 3 do
    computer.beep(1750, 1)
    os.sleep(0.7)
  end
end