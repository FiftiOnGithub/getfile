os.loadAPI("safepay")
os.loadAPI("aeslua")

term.setBackgroundColor(colors.blue)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1,1)
if not fs.exists(".spcreds") then
  print("The SafePay credentials file does not exist on this device. It cannot be used to log into safepay.")
  return
end
local encryptedinfohandler = fs.open(".spcreds","r")
local encryptedinfo = encryptedinfohandler.readAll()
local serverid = ""
local publicid = ""
local privatekey = ""
encryptedinfohandler.close()


while publicid == "" do
  sleep(0.3)
  term.clear()
  term.setCursorPos(1,1)
  print("Enter SafePay password:")
  write("> ")
  local code = read();
  local decrypted = aeslua.ext_decrypt(code,encryptedinfo)
  if decrypted ~= nil then
    local decrypteddata = textutils.unserialise(decrypted)
    if type(decrypteddata) == "table" then
      serverid = decrypteddata.server
      publicid = decrypteddata.publicid
      privatekey = decrypteddata.privatekey
      print("Authenticated")
    else
      print("Incorrect password")
    end
  else
    print("Incorrect password")
  end
end
while true do
  local otac = safepay.getOTAC(aeslua,privatekey,publicid,serverid)
  if type(otac) == "string" then
    print("Error connecting to SafePay servers! Could not get one-time-access code. Details: " .. otac)
    error("Cannot continue with program")
  end
  otac = otac.otac
  term.clear()
  term.setCursorPos(1,1)
  print("Actions:")
  print("1: View account balance")
  print("2: Transfer money to another account")
  print("3: Use a payment code")
  print("4: Create paycode")
  print("5: Delete paycode")
  print("6: Create new account")
  print("Enter number of action to be taken")
  write("> ")
  action = read()
  
  if action == "1" then
    local info = safepay.getAccountInformation(otac,aeslua,privatekey,publicid,serverid)
    
    if type(info) == "string" then
      error("Error connecting to SafePay servers. More details: " .. info)
    end
    term.clear()
    term.setCursorPos(1,1)
    print("Account ID: " .. publicid)
    print("The balance of your account is " .. info.balance)
    sleep(1)
  end
  if action == "2" then
    term.clear()
    term.setCursorPos(1,1)
    print("Enter target SafePay ID:")
    write("> ")
    local targetid = read()
    print("Enter amount to send:")
    write("> ")
    local amount = read()
    if tonumber(amount) == nil then
      print("Invalid number")
    else
      local info = safepay.transferMoney(targetid,tonumber(amount),otac,aeslua,privatekey,publicid,serverid)
      if type(info) == "string" then
        print("Unsuccessful transfer, more information: " .. info)
        sleep(2)
      else
        print("Success.")
      end
    end
    sleep(1)
  end
  if action == "3" then
    term.clear()
    term.setCursorPos(1,1)
    print("Enter PayCode:")
    write("> ")
    local paycode = read()
    local info = safepay.checkPaycode(paycode,otac,aeslua,privatekey,publicid,serverid)
    if type(info) == "string" then
      print("Paycode check unsuccessful, more information: " .. info)
      sleep(2)
    else
      local otac = safepay.getOTAC(aeslua,privatekey,publicid,serverid)
      if type(otac) == "string" then
        print("Error connecting to SafePay servers! Could not get one-time-access code. Details: " .. otac)
        error("Cannot continue with program")
      end
      otac = otac.otac
      print("This PayCode will charge you " .. info.amount)
      print("If the sum is negative, you will receive money.")
      print("Type 'confirm' to send payment now.")
      write("> ")
      local conf = read()
      if conf == "confirm" then
        local info = safepay.doPaycode(paycode,otac,aeslua,privatekey,publicid,serverid)
        if type(info) == "string" then
          print("Couldn't use paycode. More information: " .. info)
        else
          print("Payment successful.")
        end
      else
        print("Didn't type confirm, payment cancelled.")
        sleep(1)
      end
    end
  end
  if action == "4" then
    print("Enter paycode amount (the amount you will receive when someone uses the code)")
    write("> ")
    local amount = read();
    if tonumber(amount) ~= nil then
      local info = safepay.createPaycode(tonumber(amount),otac,aeslua,privatekey,publicid,serverid)
      if type(info) == "string" then
        print("Couldn't make paycode, more details: " .. info)
      else
        print("Created successfully. Paycode: " .. info.code)
      end
      sleep(5)
    else
      print("invalid number")
      sleep(1)
    end
  end
  
  if action == "5" then
    print("Enter code: ")
    write("> ")
    local code = read()
    local info = safepay.deletePaycode(code,otac,aeslua,privatekey,publicid,serverid)
    if type(info) == "string" then
      print("Error occurred, more details: " .. info)
    else
      print("success")
      sleep(3)
    end
  end
  
  if action == "6" then
    print("Enter owner username: ")
    write("> ")
    local owner = read()
    print("Enter account type (consumer / business / admin)")
    write("> ")
    local kind = read()
    local info = safepay.createAccount(owner,kind,otac,aeslua,privatekey,publicid,serverid)
    if type(info) == "string" then
      print("Error occurred, more details: " .. info)
    else
      local handler = fs.open("spcreds2","w")
      local towrite = {
        privatekey = info.privkey,
        publicid = info.id,
        server = serverid
      }
      local encrypter = tostring(math.random(10000,99999))
      handler.write(aeslua.ext_encrypt(encrypter, textutils.serialise(towrite)))
      handler.close()
      print("Created successfully. Account credentials saved in spcreds2. \n\nPassword is " .. encrypter .. ". Write this code down IRL.")
      sleep(10)
    end
  end
end