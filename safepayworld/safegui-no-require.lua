os.pullEvent = os.pullEventRaw

colordict = {
  primary = colors.white,
  background = colors.blue,
  text = colors.black,
  warning = colors.red,
  button = colors.green
}

function printCentered(sText)
  local w, h = term.getSize()
  local x, y = term.getCursorPos()
  x = math.max(math.floor((w / 2) - (#sText / 2) + 1), 0)
  term.setCursorPos(x, y)
  print(sText)
end

if not fs.exists(".spcreds") then
  while true do
    term.clear()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1,1)
    print("The SafePay credentials file does not exist on this device. It cannot be used to log into safepay.")
  end
  return
end
local encryptedinfohandler = fs.open(".spcreds","r")
local encryptedinfo = encryptedinfohandler.readAll()
local serverid = ""
local publicid = ""
local privatekey = ""
encryptedinfohandler.close()

function showError(message)
  term.setBackgroundColor(colordict.background)
  term.clear()
  paintutils.drawFilledBox(4,8,23,14,colordict.warning)
  term.setCursorPos(1,9)  
  term.setTextColor(colordict.text)
  printCentered("- ERROR -")
  local y = 10
  local x = 0
  local line = ""
  for i=1,#message,1 do
    line = line .. message:sub(i,i)
    x = x + 1
    
    if (x >= 17) or (message:sub(i+1,i+1) ~= " " and message:sub(i,i) == " " and x == 16) then
      
      if message:sub(i+1,i+1) ~= " " and message:sub(i+1,i+1) ~= "" and message:sub(i,i) ~= " " then
        line = line .. "-"
      end
      
      term.setCursorPos(1,y)
      term.setTextColor(colordict.text)
      printCentered(line)
      y = y + 1
      x = 0
      line = ""
    end
  end
  term.setCursorPos(1,y)
  term.setTextColor(colordict.text)
  printCentered(line)
  sleep(3)
end

frame = 1;
while true do
  term.setBackgroundColor(colordict.background)
  term.clear()
  term.setCursorPos(1,1)
  local otac = ""
  local passcode = ""
  while publicid == "" do
    frame = frame + 1;

    paintutils.drawFilledBox(4,4,23,10,colordict.primary)
    term.setCursorPos(1,5)
    term.setTextColor(colordict.text)
    printCentered("Login")
    printCentered("Enter SafePay Key")
    term.setCursorPos(term.getSize() / 2 - 2, 8)
    print(passcode .. "_")
    event,key = os.pullEvent("char")
    if key ~= nil then
      passcode = passcode .. string.upper(key)
      term.setCursorPos(term.getSize() / 2 - 2, 8)
      print("       ")

      if #passcode == 6 then
        term.setCursorPos(term.getSize() / 2 - 2, 8)
        print(passcode)
        local decrypted = aeslua.ext_decrypt(passcode,encryptedinfo)
        if decrypted ~= nil then
          local decrypteddata = textutils.unserialise(decrypted)
          if type(decrypteddata) == "table" then
            serverid = decrypteddata.server
            publicid = decrypteddata.publicid
            privatekey = decrypteddata.privatekey
            term.setCursorPos(1,9)
            printCentered("Authenticated")
            sleep(1)
          else
            passcode = ""
            term.setCursorPos(1,9)
            printCentered("Incorrect password")
            sleep(1)
          end
        else
          passcode = ""
          term.setCursorPos(1,9)
          printCentered("Incorrect password")
          sleep(1)
        end
      else
        term.setCursorPos(term.getSize() / 2 - 2, 8)
        print(passcode .. "_")
      end
    end
  end

  while true do
    local info = safepay.getOTAC(aeslua,privatekey,publicid,serverid)
    if type(info) == "string" then
      showError(info)
      publicid = ""
      passcode = ""
      break
    end
    otac = info.otac
    sleep(1)
    term.setBackgroundColor(colordict.background)
    term.clear()
    term.setCursorPos(1,1)
    paintutils.drawFilledBox(2,3,25,7,colordict.primary)
    paintutils.drawFilledBox(2,9,25,11,colordict.primary)
    paintutils.drawFilledBox(2,13,25,15,colordict.primary)

    term.setTextColor(colordict.text)
    term.setCursorPos(1,5)
    printCentered("Transfer to a friend")
    term.setCursorPos(1,10)
    printCentered("Use a PayCode")
    term.setCursorPos(1,14)
    printCentered("Security instructions")

    local w,h = term.getSize()

    term.setCursorPos(1,1)
    term.clearLine()
    term.setCursorPos(1,1)
    print("SafePay v5")

    term.setCursorPos(1,h)
    term.clearLine()
    term.setCursorPos(1,h)
    term.write(publicid)
    local message = info.balance .. "$"
    term.setCursorPos(w - #message + 1, h)
    term.write(message)

    local event,button,x,y = os.pullEvent("mouse_click")
    if y ~= nil and (y >= 3 and y <= 7) then
      while true do
        term.setBackgroundColor(colordict.background)
        term.clear()
        term.setCursorPos(1,1)
        paintutils.drawFilledBox(3,4,24,15,colordict.primary)
        term.setCursorPos(1,1)
        term.clearLine()
        term.setCursorPos(1,1)
        print("SafePay v5")

        term.setCursorPos(3,5)
        print("Receiver SafePay ID:")
        term.setCursorPos(3,6)
        local targetid = read()
        term.setCursorPos(3,8)
        print("Amount to send:")
        term.setCursorPos(3,9)
        local amount = read()
        if tonumber(amount) == nil then
          showError("Invalid number!")
          break
        else
          info = safepay.transferMoney(targetid,tonumber(amount),otac,aeslua,privatekey,publicid,serverid)
          if type(info) == "string" then
            showError(info)
            break
          else
            term.setCursorPos(3,11)
            print("Success. ")
            break
          end
        end

        sleep(1)
      end
    end
    if y >= 9 and y <= 11 then
      local paycode = ""
      local info = ""
      local pcinfo = ""
      local confirmed = 0
      while true do
        term.setBackgroundColor(colordict.background)
        term.clear()
        term.setCursorPos(1,1)
        paintutils.drawFilledBox(3,4,24,16,colordict.primary)
        term.setCursorPos(1,1)
        term.clearLine()
        term.setCursorPos(1,1)
        print("SafePay v5")

        term.setCursorPos(4,5)
        print("PayCode:")
        term.setCursorPos(4,6)
        if paycode == "" then
          paycode = read()
          term.setBackgroundColor(colordict.background)
          term.clear()
          paintutils.drawFilledBox(4,8,23,14,colordict.primary)
          term.setCursorPos(1,11)
          term.setTextColor(colordict.text)
          printCentered("Loading...")
          pcinfo = safepay.checkPaycode(paycode,otac,aeslua,privatekey,publicid,serverid)
          if type(pcinfo) == "string" then
            showError("(A) " .. pcinfo)
            break
          else
            otac = pcinfo.otac
          end
        else
          print(paycode)
          
          term.setCursorPos(4,8)
          print("Paycode amount: ")
          term.setCursorPos(4,9)
          print(pcinfo.amount .. "$")
          if pcinfo.amount < 0 then
            term.setCursorPos(4,10)
            print("Negative amounts")
            term.setCursorPos(4,11)
            print("give you money.")
          end
          if confirmed == 0 then
            paintutils.drawFilledBox(4,13,12,15,colordict.button)
          
            term.setCursorPos(5,14)
            term.setTextColor(colordict.text)
            print("Confirm")
        
            paintutils.drawFilledBox(16,13,23,15,colordict.warning)
            term.setCursorPos(17,14)
            term.setTextColor(colordict.text)
            print("Cancel")
            local event,button,x,y = os.pullEvent("mouse_click")
            if y >= 12 and y <= 16 then
              if x <= 13 then
                confirmed = 1
              else
                confirmed = 3
              end
            end
          elseif confirmed == 1 then
            
            term.setCursorPos(5,12)
            printCentered("Loading...")
            
            local info = safepay.doPaycode(paycode,otac,aeslua,privatekey,publicid,serverid)
            if type(info) == "string" then
              showError(info)
              break
            else
              confirmed = 2
            end
            
          elseif confirmed == 2 then
            term.setCursorPos(5,14)
            printCentered("- Success -")
            sleep(1)
            break;
          else
            term.setCursorPos(5,14)
            printCentered("Cancelled")
            sleep(1)
            break
          end
        end
      end
    end
    if y >= 13 and y <= 15 then
      term.setBackgroundColor(colors.lightGray)
      term.clear()
      w,h = term.getSize()
      paintutils.drawFilledBox(2,2,w-1,h-1,colors.white)
      
      term.setCursorPos(1,3)
      printCentered("- Security Guidance -")
      term.setCursorPos(2,5)
      print("1. Disk Drives")
      term.setCursorPos(2,6)
      print("Never insert SafePay")
      term.setCursorPos(2,7)
      print("device in a disk drive.")
      
      term.setCursorPos(2,9)
      print("2. Login code")
      term.setCursorPos(2,10)
      print("Never tell anyone your")
      term.setCursorPos(2,11)
      print("code or enter it into")
      term.setCursorPos(2,12)
      print("another device.")
      
      term.setCursorPos(2,14)
      print("3. Lost device")
      term.setCursorPos(2,15)
      print("If you lose your device,")
      term.setCursorPos(2,16)
      print("contact support ASAP.")
      
      term.setCursorPos(2,h-2)
      printCentered("Press any key")
      os.pullEvent("key")
      
    end
  end
end
