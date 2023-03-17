local pixels = {
  [ "010100" ] = "",
  [ "110100" ] = "",
  [ "010010" ] = "",
  [ "110010" ] = "",
  [ "100010" ] = "",
  [ "100100" ] = "",
  [ "000100" ] = "",
  [ "011110" ] = "",
  [ "110110" ] = "",
  [ "010110" ] = "",
  [ "111100" ] = "",
  [ "011100" ] = "",
  [ "100110" ] = "",
  [ "101000" ] = "",
  [ "101100" ] = "",
  [ "000110" ] = "",
  [ "101110" ] = "",
  [ "001110" ] = "",
  [ "001000" ] = "",
  [ "111110" ] = "",
  [ "011000" ] = "",
  [ "111000" ] = "",
  [ "100000" ] = "",
  [ "011010" ] = "",
  [ "111010" ] = "",
  [ "000000" ] = "",
  [ "001010" ] = "",
  [ "101010" ] = "",
  [ "000010" ] = "",
  [ "001100" ] = "",
  [ "110000" ] = "",
  [ "010000" ] = "",
  [ "111111" ] = " ",
}

local function pad(t)
  local longest = 0
  for k,v in pairs(t) do
    if #v > longest then longest = #v end
  end
  for k,v in pairs(t) do
    local tl = #v
    while tl < longest do
      table.insert(v, 0)
      tl = tl + 1
    end
  end
  return t
end

function pixelate(image)
  local imagespace = ""
  local currentpx = ""
  exn = true
  row = 1
  item = 1
  justnewlined = false
  empties = 0
  text_color = -1 -- the color of the "1" value bits
  bg_color = -2 -- the color of the "0" value bits
  image = pad(image)
  while exn do
    local num = nil
    if image[row] ~= nil then 
      num = image[row][item]
    end
    if num == nil then 
      num = 0
      empties = empties + 1
    else
      justnewlined = false
    end
    
    -- if no text color is set and the current pixel color is not the background color
    if text_color == -1 and bg_color ~= num and num ~= 0 then
      text_color = num
    elseif bg_color == -2 and text_color ~= num and num ~= 0 then
      bg_color = num
    end
    
    if num == text_color then 
      num = 1
    elseif num == bg_color then 
      num = 0 
    end
    if num ~= 1 and num ~= 0 then 
      error("Pixel must only contain 2 colours, but found '" .. num .. "'. TC " .. text_color .. " BG " .. bg_color .. " PX " .. currentpx) 
    end
    -- COLOR INTERPRETATION COMPLETE
    
    currentpx = currentpx .. num
    -- are we at the end of the current pixel's line
    if math.mod(item,2) == 0 then
      -- are we at the end of the current pixel
      if math.mod(row, 3) == 0 then
        item = item + 1
        row = row - 2
        -- is the current pixel dataless
        if empties ~= 6 then
          
          -- We have finished drawing a (big) pixel which has content.
          if string.sub(currentpx,6,6) ~= "0" then
            -- The pixel has the final subpixel colored in, which means we need to flip everything.
            -- Flip the background and foreground layers
            imagespace = imagespace .. " S "  .. bg_color .. " / " .. text_color .. " / "
            -- Flip the subpixels
            imagespace = imagespace .. "F" .. pixels[string.gsub(string.gsub(string.gsub(currentpx,"1","2"),"0","1"),"2","0")]
          else
            -- Don't flip anything
            imagespace = imagespace .. " S "  .. text_color .. " / " .. bg_color .. " / "
            imagespace = imagespace .. "D" .. pixels[currentpx]
          end
          imagespace = imagespace .. " P"
          currentpx = ""
          
        else
          if not justnewlined then
            item = 1
            row = row + 3
            justnewlined = true
            imagespace = imagespace .. " S 0 / 0 / NN P"
            currentpx = ""
          else
            exn = false
          end
        end
        empties = 0
        text_color = -1
        bg_color = -2
      else
        row = row + 1
        item = item - 1
      end
    else
      item = item + 1
    end
  end
  --print(imagespace)
  return imagespace
end

function draw(pixelart, px, py)
  stc = term.getTextColor()
  sbc = term.getBackgroundColor()
  sx,sy = term.getCursorPos()
  cx, cy = px, py
  cpos = 1
  --print(pixelart)
  while true do
    term.setCursorPos(1,5)
    nstart = string.find(pixelart, " S ")
    nend = string.find(pixelart, "P")
    if nstart == nil or nend == nil then break end
    segment = string.sub(pixelart, nstart, nend)
    if segment == nil then break end
    
    textcolor,bgcolor,operand,char = string.match(segment, "S (.+) / (.+) / (.)(.) P")
    if operand == "N" then -- newline
      cy = cy + 1
      cx = px - 1
    else -- draw a pixel
      if textcolor ~= nil and tonumber(textcolor) > 0 then 
        term.setTextColor(tonumber(textcolor))
      else
        if textcolor == "-1" or textcolor == "0" then term.setTextColor(stc) end
        if textcolor == "-2" then term.setTextColor(sbc) end
      end
      
      if bgcolor ~= nil and tonumber(bgcolor) > 0 then 
        term.setBackgroundColor(tonumber(bgcolor))
      else
        if bgcolor == "-1" then term.setBackgroundColor(stc) end
        if bgcolor == "-2"  or bgcolor == "0" then term.setBackgroundColor(sbc) end
      end
      term.setCursorPos(cx, cy)
      term.write(char)
    end
    cx = cx + 1
    pixelart = string.sub(pixelart,nend + 1)
    
  end
  term.setTextColor(stc)
  term.setBackgroundColor(sbc)
  term.setCursorPos(sx,sy)
end

