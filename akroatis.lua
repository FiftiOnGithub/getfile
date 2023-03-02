-- 27th Feb 2023
-- Akroatis Snooper by Fifti
-- do not distribute


-- relayid is the id of this pc on the akroatis listening swarm. relayid 0 is the hub pc.
local relayid = 0;
local relaylocations = {}
local debug = false

relaylocations[0] = {x = 0, y = 0, z = -0}
relaylocations[1] = {x = 0, y = 0, z = -0}
relaylocations[2] = {x = 0, y = 0, z = -0}

local channelLower = 65535 - 127
local channelUpper = 65535

local wirelessSide = nil
local wiredSide = nil

local w,h = term.getSize()
if w ~= 51 or h ~= 19 then
  if relayid == 0 then
    error("Host Akroatis Snooper can only be run on a normal monitor, size 51x19.")
  end
end

for _,k in pairs(peripheral.getNames()) do
  if peripheral.getType(k) == "modem" then
    if peripheral.call(k,"isWireless") then
      wirelessSide = k
    else
      wiredSide = k
    end
  end
end

local function distance(dst)
  local org = relaylocations[relayid]
  return math.floor(math.sqrt( (dst.x - org.x)^2 + (dst.y - org.y)^2 + (dst.z - org.z)^2))
end

function split(self,delimiter)
  local result = { }
  local from  = 1
  local delim_from, delim_to = string.find( self, delimiter, from  )
  while delim_from do
    table.insert( result, string.sub( self, from , delim_from-1 ) )
    from  = delim_to + 1
    delim_from, delim_to = string.find( self, delimiter, from  )
  end
  table.insert( result, string.sub( self, from  ) )
  return result
end

-- this is straight from the GPS rom API.
local function trilaterate( A, B, C )
	local a2b = B.vPosition - A.vPosition
	local a2c = C.vPosition - A.vPosition
		
	if math.abs( a2b:normalize():dot( a2c:normalize() ) ) > 0.999 then
		return nil
	end
	
	local d = a2b:length()
	local ex = a2b:normalize( )
	local i = ex:dot( a2c )
	local ey = (a2c - (ex * i)):normalize()
	local j = ey:dot( a2c )
	local ez = ex:cross( ey )

	local r1 = A.nDistance
	local r2 = B.nDistance
	local r3 = C.nDistance
		
	local x = (r1*r1 - r2*r2 + d*d) / (2*d)
	local y = (r1*r1 - r3*r3 - x*x + (x-i)*(x-i) + j*j) / (2*j)
		
	local result = A.vPosition + (ex * x) + (ey * y)

	local zSquared = r1*r1 - x*x - y*y
	if zSquared > 0 then
		local z = math.sqrt( zSquared )
		local result1 = result + (ez * z)
		local result2 = result - (ez * z)
		
		local rounded1, rounded2 = result1:round( 0.01 ), result2:round( 0.01 )
		if rounded1.x ~= rounded2.x or rounded1.y ~= rounded2.y or rounded1.z ~= rounded2.z then
			return rounded1, rounded2
		else
			return rounded1
		end
	end
	return result:round( 0.01 )
	
end

local function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end
local function isRednet(message)
  if type(message) ~= "table" then return false end
  if type(message["nRecipient"]) ~= "number" then return false end
  if type(message["nMessageID"]) ~= "number" then return false end
  if type(message["message"]) == "nil" then return false end
  local protocol = message["sProtocol"]
  if type(protocol) ~= "nil" and type(protocol) ~= "string" then return false end
  return true, message["message"], message["nRecipient"], message["nMessageID"], protocol
end
local function sameTable(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k,v in pairs(a) do
    if type(v) == "table" then
      if not sameTable(v,b[k]) then return false end
    else
      if v ~= b[k] then return false end
    end
  end
  return true
end

if wirelessSide == nil or wiredSide == nil then error("Must have a wired and wireless connection") end

function printCentered(sText)
  local w, h = term.getSize()
  local x, y = term.getCursorPos()
  x = math.max(math.floor((w / 2) - (#sText / 2) + 1), 0)
  term.setCursorPos(x, y)
  print(sText)
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1,1)


print("------------------")
print(" AKROATIS SNOOPER ")
print("------------------")
print("")
print("Session started day " .. os.day())
if relayid == 0 then print("This is the HUB computer") end
if relayid ~= 0 then print("This is a RELAY computer. ID: " .. relayid) end

wireless = peripheral.wrap(wirelessSide)
wired = peripheral.wrap(wiredSide)
wireless.closeAll()
wired.closeAll()
for i = channelLower, channelUpper do
  wireless.open(i)
end
wired.open(channelUpper)

local CLEARING = {}
local INTERCEPTS = {}
function resolvePing(content, seenById, seenByDistance, senderRepChannel)
  for k,v in pairs(CLEARING) do
    if os.clock() > v.firstSeen + 3 then
      if debug then print("removing entry due to timeout") end
      CLEARING[k] = nil
      break
    end
    if not sameTable(v.content, content) then
      print(textutils.serialise(v.content))
      print(textutils.serialise(content))
    end
    if sameTable(v.content, content) then
      
      CLEARING[k]["distances"][seenById] = seenByDistance
      if debug then print("adding to distances array, seenbyID: " .. seenById) end
      if senderRepChannel ~= nil then CLEARING[k]["replychannel"] = senderRepChannel end
      if debug then print(tablelength(CLEARING[k]["distances"])) end
      if tablelength(CLEARING[k]["distances"]) == 3 then
        local tLocs = {}
        for k,v in pairs(CLEARING[k]["distances"]) do
          table.insert(tLocs,{
            vPosition = vector.new(relaylocations[k].x, relaylocations[k].y, relaylocations[k].z),
            nDistance = v
          })
        end
        local location = trilaterate(tLocs[1],tLocs[2],tLocs[3])
        table.insert(INTERCEPTS, {
            bRednet = false,
            rawContent = textutils.serialise(content),
            replyChannel = CLEARING[k]["replychannel"],
            location = location,
            time = os.clock(),
            viewed = false
        })
        local rednet, text, recipient, msgid, protocol = isRednet(content)
        if rednet then
          INTERCEPTS[#INTERCEPTS]["bRednet"] = true 
          INTERCEPTS[#INTERCEPTS]["rednetData"] = {
            recipient = recipient,
            messageid = msgid,
            content = textutils.serialise(text),
            protocol = protocol
          }
        end
      end
      return
    end
  end
  local clearingID = "X"
  if debug then print("new clearing entry") end
  while true do
    clearingID = math.random(10000)
    if CLEARING[clearingID] == nil then break end
  end
  CLEARING[clearingID] = {
      firstSeen = os.clock(),
      content = content,
      distances = {}
  }
  
  if senderRepChannel ~= nil then CLEARING[clearingID]["replychannel"] = senderRepChannel end
  if debug then print("2: adding to distances, seenbyID: " .. seenById) end
  CLEARING[clearingID]["distances"][seenById] = seenByDistance
end


if relayid == 0 then os.loadAPI("editlight") end
local view = 0 -- cleared element id that we are looking at
local frame = 0
function draw()
  frame = frame + 1
  if view == 0 then
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1,1)
    w,h = term.getSize()
    printCentered("------------------")
    printCentered(" AKROATIS SNOOPER ")
    printCentered("------------------")
    printCentered("")
    printCentered("Session started day " .. os.day() .. ", running for " .. frame .. " seconds")
    if relayid == 0 then printCentered("This is the HUB computer") end
    
    term.setBackgroundColor(colors.blue)
    term.setCursorPos(w-1,1)
    term.write("C")
    term.setBackgroundColor(colors.red)
    term.write("X")
    local current = term.current()
    local win = window.create(current, 1,8,w,h-7)
    
    term.redirect(win)
    
    term.setBackgroundColor(colors.gray)
    term.clear()
    if #INTERCEPTS == 0 then
      term.setCursorPos(1,h/2)
      printCentered("No intercepted messages yet...")
    else
      term.setCursorPos(1,math.min(#INTERCEPTS,h))
      for i = #INTERCEPTS, 1, -1 do
        if i - h > 0 then break end
        local text = ""
        if INTERCEPTS[i].bRednet then
          term.setBackgroundColor(colors.pink)
          
          text = "+ REDNET | SENDER: " .. INTERCEPTS[i].replyChannel .. " LEN: " .. #INTERCEPTS[i].rednetData.content
        
        else
          term.setBackgroundColor(colors.lightGray)
          text = "+ MODEM  | LEN: " .. #INTERCEPTS[i].rawContent
        end
        text = text .. " DST: " .. distance(INTERCEPTS[i].location)
        agetext =  " " .. math.min(math.floor(os.clock() - INTERCEPTS[i].time),999) .. "s Ago"
        term.clearLine()
        if INTERCEPTS[i].viewed then
          if INTERCEPTS[i].bRednet then term.setTextColor(colors.lightGray) else term.setTextColor(colors.gray) end
        else
          term.setTextColor(colors.white)
        end
        print(text)
        x,y = term.getCursorPos()
        term.setCursorPos(w - #agetext + 1, y-1)
        term.write(agetext)
        term.setCursorPos(x,y-2)
      end
    end
    term.redirect(current)
    return
  end
  
  INTERCEPTS[view].viewed = true
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(3,1)
  print("------------------")
  term.setCursorPos(3,2)
  print(" MESSAGE ANALYSIS")
  term.setCursorPos(3,3)
  print("------------------")
  print("Intercepted " .. math.floor(os.clock() - INTERCEPTS[view].time) .. "s ago.")
  print("")
  if INTERCEPTS[view].bRednet then
    print("- Rednet Data:")
    print("Claimed sender " .. INTERCEPTS[view].replyChannel)
    if INTERCEPTS[view].rednetData.recipient ~= 65535 then
      print("Intended recipient: " .. INTERCEPTS[view].rednetData.recipient)
    else
      print("Broadcast message")
    end
    if INTERCEPTS[view].rednetData.protocol ~= nil then
      print("Protocol: " .. INTERCEPTS[view].rednetData.protocol)
    end
  else
    print("Raw modem transmission")
    print("Req. reply channel: " .. INTERCEPTS[view].replyChannel)
  end
  print("")
  print("")
  print("- Location data:")
  print("X: " .. INTERCEPTS[view].location.x .. " Y: " .. INTERCEPTS[view].location.y .. " Z: " .. INTERCEPTS[view].location.z)
  print("Distance: " .. distance(INTERCEPTS[view].location))
  
  
  local current = term.current()
  local win = window.create(current, w/2,1,w/2+2,h)
  
  term.redirect(win)
  
  term.setBackgroundColor(colors.gray)
  term.clear()
  term.setCursorPos(1,1)
  local sContent = ""
  if INTERCEPTS[view].bRednet then
    sContent = (INTERCEPTS[view].rednetData.content)
  else
    sContent = (INTERCEPTS[view].rawContent)
  end
  --[[
  tContent = split(sContent, "\n")
  local cpos = 1
  w,h = term.getSize()
  local linelen = w / 2 - 1
  -- loop through each line
  for k,v in pairs(tContent) do
    
    for i=cpos, #v+1 do
      if v:sub(i,i) == " " or v:sub(i,i) == "" or (i-cpos + 1) > linelen then
        
      end
    end
    
  end
  --]]
  editlight.run(sContent, win)
  view = 0
  term.redirect(current)
end

os.startTimer(0.05)
while true do
  eventtype, arg1, arg2, arg3, arg4, arg5 = os.pullEvent()
  if eventtype == "modem_message" then
    message_side, replychannel, message, message_distance = arg1, arg3, arg4, arg5
    --print("(DEBUG) received message on side " .. message_side)
    if relayid == 0 and message_side == wiredSide then
      if debug then print("do hub stuff") end
      
      if type(message) == "table" and type(message["relayID"]) ~= "nil" then
        resolvePing(message["content"], message["relayID"], message["nDistance"], nil)
      end
      
    end
    if relayid ~= 0 and message_side == wirelessSide then
      local message = {
        relayID = relayid,
        nDistance = message_distance,
        content = message
      }
      wired.transmit(65535, 65535, message)
      print("-- Relayed message from a distance of " .. message_distance)
    elseif relayid == 0 and message_side == wirelessSide then 
      local result = resolvePing(message, relayid, message_distance, replychannel)
    end
  end
  if eventtype == "timer" and relayid == 0 then
    draw()
    os.startTimer(1)
  end
  if eventtype == "mouse_click" and relayid == 0 then
    cx, cy = arg2, arg3
    w,h = term.getSize()
    if view == 0 then
      if cy > 7 then
        clickindex = math.min(#INTERCEPTS, h - 8) - (cy - 7)
        if clickindex >= 0 then view = #INTERCEPTS - clickindex end
        
      elseif cy == 1 and cx == w then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        term.setCursorPos(1,1)
        wired.closeAll()
        wireless.closeAll()
        break
      elseif cy == 1 and cx == w - 1 then
        INTERCEPTS = {}
      end
    else view = 0 end
  end
end

