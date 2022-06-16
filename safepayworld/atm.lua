os.loadAPI("safepay")
os.loadAPI("aeslua")
os.loadAPI("printer")
oldterm = term.current()
this = peripheral.wrap("front")
term.redirect(this)
local printhandler = fs.open("printtemplate","r")
local printtext = printhandler.readAll()
printhandler.close()
local keyhandler = fs.open(".spcreds","r")
local codes = textutils.unserialise(keyhandler.readAll())
local otac = ""

local plus = paintutils.loadImage("numbers/plus")
local minus = paintutils.loadImage("numbers/minus")
local numbers = {}
for i=0,9,1 do
  numbers[tostring(i)] = paintutils.loadImage("numbers/"..tostring(i))
end

function strsplit(str)
  local result = {}
  for letter in str:gmatch(".") do table.insert(result, letter) end
  return result
end


function printCentered(sText)
  local w, h = term.getSize()
  local x, y = term.getCursorPos()
  x = math.max(math.floor((w / 2) - (#sText / 2) + 1), 0)
  term.setCursorPos(x, y)
  print(sText)
end

while true do
  local skip = false
  this.setTextScale(1)
  term.setBackgroundColor(colors.lightBlue)
  term.clear()
  term.setTextColor(colors.white)
  local w,h = term.getSize()
  term.setCursorPos(1,h/2)
  
  local info = safepay.getOTAC(aeslua,codes.privatekey,codes.publicid,codes.server)
  if type(info) == "string" then
    term.setTextColor(colors.red)
    printCentered("Could not")
    printCentered("connect to")
    printCentered("SafePay servers.")
    printCentered("Come back later.")
    term.redirect(oldterm)
    print("ERROR GETTING OTAC: " .. info)
    term.redirect(this)
    sleep(20)
  else
    otac = info.otac
    printCentered("SafePay ATM")
    printCentered("Tap the Screen")
    os.pullEvent("monitor_touch")
    term.setBackgroundColor(colors.lightBlue)
    term.clear()
    paintutils.drawFilledBox(2,2,w-1,h/2-1,colors.white)
    term.setCursorPos(1,h/4)
    term.setTextColor(colors.black)
    printCentered(" DEPOSIT")
    
    paintutils.drawFilledBox(2,h/2+1,w-1,h-1,colors.white)
    term.setCursorPos(1,h*(3/4))
    printCentered("WITHDRAW")
    local _,_,x,y = os.pullEvent("monitor_touch")
    if y < h/2 then
      this.setTextScale(0.5)
      local w,h = term.getSize()
      term.setBackgroundColor(colors.lightBlue)
      term.clear()
      
      paintutils.drawFilledBox(2,2,w-1,h-1,colors.white)
      
      term.setCursorPos(1,3)
      
      local info = safepay.getOTAC(aeslua,codes.privatekey,codes.publicid,codes.server)
      if type(info) == "string" then
        term.setTextColor(colors.red)
        printCentered("Could not")
        printCentered("connect to")
        printCentered("SafePay servers.")
        printCentered("Come back later.")
        term.redirect(oldterm)
        print("ERROR GETTING OTAC: " .. info)
        term.redirect(this)
        sleep(5)
      else
        otac = info.otac
        printCentered("- Deposit -")  
        printCentered("Place the gold into")
        printCentered("the dispenser on the left")
        term.setCursorPos(1,8)
        printCentered("1 nugget = 1$")
        printCentered("1 ingot = 9$")
        printCentered("1 block = 81$")
        printCentered("Fee: 2% or 3$")
        term.setCursorPos(1,13)
        
        paintutils.drawFilledBox(4,16,(w/2-1),h-3,colors.green)
        term.setCursorPos(7,18)
        print("Confirm")
        term.setCursorPos(7,19)
        print("Deposit")
        
        paintutils.drawFilledBox((w/2+1),16,w-3,h-3,colors.red)
        term.setCursorPos((w/2+1) + 5, 18)
        print("Cancel")
        while true do
          local _,_,x,y = os.pullEvent("monitor_touch")
          if y > 15 then
            if x < w/2 then
              paintutils.drawFilledBox(4,16,w-3,h-3,colors.white)
              term.setCursorPos(1,17)
              printCentered("Calculating value...")
              printCentered("This may take a few moments.")
              printCentered("Please do not touch the dispenser")
              printCentered("Reduce time by crafting")
              printCentered("all gold into blocks.")
              break
            else
              skip = true
              break
            end
          end
        end
        if not skip then
          term.setCursorPos(1,1)
          
          items = {
           "minecraft:gold_nugget",
           "minecraft:gold_ingot",
           "minecraft:gold_block"
          }
          values = {
            gold_nugget = 1,
            gold_ingot = 9,
            gold_block = 81
          }
          local value = 0
          term.redirect(oldterm)
          turtle.select(1)
          turtle.turnRight()
          while true do
            
            -- Take all items from the dropper
            while true do
              local success = turtle.suck()
              if not success then break end
            end
            
            local encountered = false
            local worstitem = 9999
            
            -- Figure out what the "worst" item is
            for i = 1,16,1 do
              local item = turtle.getItemDetail(i)
              if item ~= nil then
                local itemkey = -1
                for k,v in pairs(items) do
                  if item.name == v then
                    itemkey = k
                  end
                end
                if itemkey == -1 then
                  turtle.select(i)
                  turtle.drop()
                  redstone.setOutput("front",true)
                  sleep(0.05)
                  redstone.setOutput("front",false)
                else
                  if worstitem > itemkey and item.count > 9 then worstitem = itemkey end
                end
              end
            end
            if worstitem > 2 then
              turtle.turnLeft()
              turtle.turnLeft()
              for i = 1,16,1 do
                if turtle.getItemDetail(i) then 
                  local info = turtle.getItemDetail(i)
                  local pinfo = string.reverse(info.name)
                  local name = {pinfo:match((pinfo:gsub("[^"..":".."]*"..":", "([^"..":".."]*)"..":")))}
                  value = value + (info.count * values[string.reverse(name[1])])
                  
                  turtle.select(i)
                  turtle.drop()
                  
                end
              end
              turtle.turnRight()
              print("Finished compacting")
              break
            else
              -- Drop all items that aren't the worst item
              for i = 1,16,1 do
                local item = turtle.getItemDetail(i)
                if item ~= nil and item.name ~= items[worstitem] then 
                  turtle.select(i)
                  turtle.drop()
                else
                  if item ~= nil then
                    turtle.select(i)
                    turtle.transferTo(1)
                  end
                  
                end
              end
              -- Drop all items that arent in the first slot
              for i = 2,16,1 do
                local item = turtle.getItemDetail(i)
                if item ~= nil then
                  turtle.select(i)
                  turtle.drop()
                end
              end
              
              -- Distribute the items into a square
              local item = turtle.getItemDetail(1)
              turtle.select(1)
              if item ~= nil then
                local stacksize = math.floor(item.count / 9)
                for i = 2, 11, 1 do
                  if i ~= 4 and i ~= 8 then 
                    turtle.transferTo(i,stacksize)
                  end
                end
                local worked = turtle.craft()
                turtle.select(1)
                turtle.drop()
              end
            end
          end 
          term.redirect(this)
          term.setBackgroundColor(colors.lightBlue)
          term.clear()
          
          paintutils.drawFilledBox(2,2,w-1,h-1,colors.white)
          term.setCursorPos(1,10)
          local fee = 3
          if value * (2/100) > fee then fee = value * (2/100) end
          fee = math.floor(fee)
          if value < 4 then
            term.setTextColor(colors.black)
            term.setCursorPos(1,15)
            printCentered("You must deposit at least 3$")
            printCentered("worth of gold to withdraw.")
            term.setCursorPos(1,19)
            printCentered("You will not receive any money.")
          else
            local info = safepay.createPaycode((0 - value) + fee, otac, aeslua,codes.privatekey,codes.publicid,codes.server)
            if type(info) == "string" then
              term.setTextColor(colors.red)
              code = math.random(100000,999999)
              printCentered("- ERROR CREATING PAYMENT CODE -")
              printCentered("We were unable to create a claim code for you.")
              printCentered("Error message: " .. info)
              printCentered("You will receive a receipt shortly with a number on it.")
              printCentered("Take this receipt to a SafePay branch to be compensated.")
              printCentered("The value of your items was " .. value .. "$")
              local s,e = printer.printtext("Your SafePay ATM recovery code","ATM " .. codes.atmid .. " generated error:\n " .. info .. "\n\nProcessing goods worth " .. value .. "$. One-time claim code: " .. code .. ".\nTake paper to a SafePay branch to be refunded.")
              if not s then
                printCentered("Could not print receipt. Your code is " .. code .. ". Write the code down and visit a safepay branch for assistance.")
              else
                turtle.turnRight()
                turtle.suckUp()
                turtle.drop()
                turtle.turnLeft()
              end
              term.redirect(oldterm)
              print("ERROR generating paycode. Deposit value: " .. value .. ", confirmation code " .. code)
              term.redirect(this)
            else
              term.setTextColor(colors.black)
              printCentered("Calculated value")
              printCentered("of your items was:")
              printCentered(value .. "$")
              
              term.setCursorPos(1,15)
              printCentered("The fee is " .. fee .. "$")
              printCentered("Printing your code now..")
              
              local s,e = printer.printtext("Your SafePay ATM code",printtext:gsub("SUM",value):gsub("NET",value - fee):gsub("CODE",info.code))
              if not s then
                term.setTextColor(colors.red)
                printCentered("Error while printing: " .. e)
                printCentered("Take a screenshot and contact support")
                sleep(5)
              else
                turtle.suckUp()
                turtle.turnRight()
                turtle.drop()
                redstone.setOutput("front",true)
                sleep(0.05)
                redstone.setOutput("front",false)
                turtle.turnLeft()
              end
            end
          end
        end
      end
    else
      this.setTextScale(0.5)
      local w,h = term.getSize()
      term.setBackgroundColor(colors.lightBlue)
      term.clear()
      
      paintutils.drawFilledBox(2,2,w-1,h-1,colors.white)
      
      term.setCursorPos(1,3)
      
      local info = safepay.getOTAC(aeslua,codes.privatekey,codes.publicid,codes.server)
      if type(info) == "string" then
        term.setTextColor(colors.red)
        printCentered("Could not")
        printCentered("connect to")
        printCentered("SafePay servers.")
        printCentered("Come back later.")
        term.redirect(oldterm)
        print("ERROR GETTING OTAC: " .. info)
        term.redirect(this)
        sleep(5)
      else
        otac = info.otac
        
        printCentered("- Withdraw -")  
        printCentered("Enter the amount to")
        printCentered("withdraw from your account.")
        printCentered("The amount is multiples of 9")
        printCentered("because 9$ = 1 ingot")
        
        paintutils.drawFilledBox(4,9,33,17,colors.lightGray)
        paintutils.drawImage(plus,5,11)
        paintutils.drawImage(minus,28,11)
        
        paintutils.drawFilledBox(5,20,17,22,colors.green)
        term.setCursorPos(7,21)
        print("Continue")
        
        paintutils.drawFilledBox(20,20,32,22,colors.red)
        term.setCursorPos(23,21)
        print("Cancel")
        
        local amount = 18
        while true do
          paintutils.drawFilledBox(10,9,27,17,colors.lightGray)
          term.setBackgroundColor(colors.white)
          term.setCursorPos(1,18)
          printCentered("  Fee: 9$. You'll receive: " .. (amount - 9) .. "$ ")
          local characters = strsplit(tostring(amount))
          local pos = (w / 2) - ((#characters * 5) / 2) + 2
          for _,v in pairs(characters) do
            term.redirect(oldterm)
            term.redirect(this)
            paintutils.drawImage(numbers[tostring(v)],pos,10)
            paintutils.drawLine(pos-1,16,pos+4,16,colors.gray)
            
            
            
            pos = pos + 5
          end
          local _,_,x,y = os.pullEvent("monitor_touch")
          if y > 10 and y < 18 then
            if x < 11 then
              if amount < 810 then
                amount = amount + 9
              end
            elseif x > 27 then
              if amount > 18 then
                amount = amount - 9
              end
            end
          elseif (y > 18 and y < 24) and (x > 4 and x < 18) then
            break
          elseif (y > 18 and y < 24) and (x > 19 and x < 33) then
            skip = true
            break
          end
        end
        if not skip then 
          term.setBackgroundColor(colors.lightBlue)
          term.setTextColor(colors.white)
          this.setTextScale(1.5)
          local w,h = term.getSize()
          term.clear()
          
          local info = safepay.createPaycode(amount, otac, aeslua,codes.privatekey,codes.publicid,codes.server)
          if type(info) == "string" then
            term.setCursorPos(1,1)
            term.setTextColor(colors.red)
            printCentered("ERROR")
            printCentered("Cannot contact")
            printCentered("SafePay servers.")
            printCentered("Try again later.")
            term.redirect(oldterm)
            print("ERROR generating withdrawal code: " .. info)
            term.redirect(this)
          else
            otac = info.otac
            local usecode = info.usecode
            local code = info.code
            local time = 60
            local paid = false
            while true do
              term.setCursorPos(1,2)
              printCentered("Pay paycode:")
              printCentered(code)
              term.setCursorPos(1,6)
              printCentered("  " .. time .. "s left  ")
              while true do
                local id,response = rednet.receive("SP_RESPONSE",1)
                if id == nil then break end
                if type(response) == "table" then
                  if type(response.data) == "table" then
                    if type(response.data.usecode) == "string" and response.data.usecode == usecode then
                      paid = true
                      break
                    end
                  end
                end
              end
              if not paid then time = time - 1 end
              if paid then break end
              if time == 0 then break end
            end
            term.setBackgroundColor(colors.lightBlue)
            this.setTextScale(1)
            term.clear()
            term.setTextColor(colors.black)
            if paid then
              term.setCursorPos(1,4)
              printCentered("Payment received")
              printCentered("Your gold is")
              printCentered("being measured")
              amount = amount - 9
              blocks = math.floor(amount / 81)
              ingots = (amount - (math.floor(amount / 81) * 81)) / 9
              printCentered(blocks .. " blocks")
              printCentered(ingots .. " ingots")
              turtle.turnLeft()
              turtle.suck()
              det = turtle.getItemDetail()
              if det ~= nil and det.name == "minecraft:gold_block" and det.count > blocks + 1 then
                turtle.turnRight()
                turtle.turnRight()
                turtle.drop(blocks)
                if ingots > 0 then 
                  turtle.craft(1) 
                  slot = 0
                  for i=1,16,1 do
                    if turtle.getItemDetail(i) ~= nil and turtle.getItemDetail(i).name == "minecraft:gold_ingot" then
                      slot = i
                      break
                    end
                  end
                  turtle.select(slot)
                  turtle.drop(ingots)
                end
                turtle.turnLeft()
                turtle.turnLeft()
                for i=1,16,1 do
                  if turtle.getItemDetail(i) ~= nil then
                    turtle.select(i)
                    turtle.drop()
                  end
                end
                turtle.turnRight()
                term.clear()
                term.setCursorPos(1,3)
                printCentered("Withdrawal")
                printCentered("Take your gold")
                printCentered("from dropper on")
                printCentered("the left.")
                
              else
                turtle.turnRight()
                term.clear()
                term.setCursorPos(1,3)
                term.setTextColor(colors.red)
                printCentered("ERROR")
                printCentered("Not enough gold")
                printCentered("Printing receipt")
                printCentered("Take to")
                printCentered("SafePay branch")
                local code = math.random(100000,999999)
                printer.printtext("SafePayATM recovery code","ATM " .. codes.atmid .. " \nCouldn't produce gold for withdrawal of " .. amount .. ".\nVerification code: " .. code)
                turtle.suckUp()
                turtle.turnRight()
                turtle.drop()
                turtle.turnLeft()
                term.redirect(oldterm)
                print(code .. " - failed withdrawal of " .. amount)
                term.redirect(this)
              end
            else
              term.setCursorPos(1,4)
              printCentered("You ran")
              printCentered("out of time.")
              safepay.deletePaycode(code, otac, aeslua,codes.privatekey,codes.publicid,codes.server)
            end
          end
        end
      end
    end
    if not skip then sleep(6) end
  end
end