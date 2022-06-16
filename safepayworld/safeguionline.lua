local handle = http.get("https://raw.githubusercontent.com/FiftiOnGithub/computercraft-cloud/main/loadResource")
pcall(load(handle.readAll()))
handle.close()

term.setCursorPos(1,1)
term.clear()
print("Loading remote files...")

loadResource("aeslua","https://raw.githubusercontent.com/FiftiOnGithub/computercraft-cloud/main/getfile/aeslua")
loadResource("safepay","https://raw.githubusercontent.com/FiftiOnGithub/computercraft-cloud/main/safepayworld/safepay")
loadResource("safegui","https://raw.githubusercontent.com/FiftiOnGithub/computercraft-cloud/main/safepayworld/safegui-no-require.lua",true)
