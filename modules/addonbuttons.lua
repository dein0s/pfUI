pfUI:RegisterModule("addonbuttons", function ()
  if not pfUI.panel.minimap then return end

  local default_border = C.appearance.border.default
  if C.appearance.border.panels ~= "-1" then
    default_border = C.appearance.border.panels
  end

  -- if pfUI.addonbuttons.buttons == nil or type(pfUI.addonbuttons.buttons) ~= "table" then
  --   pfUI.addonbuttons.buttons = {}
  -- end
  if C.addonbuttons.buttons_add == nil or type(C.addonbuttons.buttons_add) ~= "table" then
    C.addonbuttons.buttons_add = {}
  end
  if C.addonbuttons.buttons_del == nil or type(C.addonbuttons.buttons_del) ~= "table" then
    C.addonbuttons.buttons_del = {}
  end

  local ignored_icons = {
    "Note",
    "JQuest",
    "Naut_",
    "MinimapIcon",
    "GatherMatePin",
    "WestPointer",
    "Chinchilla_",
    "SmartMinimapZoom",
    "QuestieNote",
    "smm",
    "pfMiniMapPin"
  }

  pfUI.addonbuttons = CreateFrame("Frame", "pfMinimapButtons", UIParent)
  CreateBackdrop(pfUI.addonbuttons)
  pfUI.addonbuttons:SetPoint("CENTER", UIParent, 0, 0)
  pfUI.addonbuttons:SetWidth(pfUI.panel.minimap:GetWidth())

  pfUI.addonbuttons.buttons = {}
  pfUI.addonbuttons.last_updated = 0
  pfUI.addonbuttons.loaded = false
  pfUI.addonbuttons.rows = 1
  pfUI.addonbuttons.effective_scale = Minimap:GetEffectiveScale()
  pfUI.addonbuttons.max_button_size = 40

  pfUI.addonbuttons:SetPoint("TOP", pfUI.panel.minimap, "BOTTOM", 0 , -default_border * 3)
  pfUI.addonbuttons:SetFrameStrata("BACKGROUND")
  pfUI.addonbuttons:Hide()

  pfUI.addonbuttons:RegisterEvent("PLAYER_ENTERING_WORLD")
  pfUI.addonbuttons:RegisterEvent("PLAYER_REGEN_DISABLED")


  local function GetButtonSize()
    return (pfUI.addonbuttons:GetWidth() - (tonumber(C.addonbuttons.spacing) * (tonumber(C.addonbuttons.rowsize) + 1))) / tonumber(C.addonbuttons.rowsize)
  end

  local function GetNumButtons()
    local total_buttons = 0
    for i, v in ipairs(pfUI.addonbuttons.buttons) do
      total_buttons = total_buttons + 1
    end
    return total_buttons
  end

  local function GetRowHeight()
    return (GetButtonSize() + tonumber(C.addonbuttons.spacing))
  end

  local function TableMatch(table, needle)
    for i,v in ipairs(table) do
      if (strlower(v) == strlower(needle)) then 
        return i 
      end
    end
    return false
  end

  local function TablePartialMatch(table, needle)
    for i,v in ipairs(table) do
      pos_start, pos_end = strfind(strlower(needle), strlower(v))
      if pos_start == 1 then
        return i
      end
    end
    return false
  end

  local function IsButtonValid(frame)
    if frame:GetName() ~= nil then
      if frame:IsVisible() then
        if frame:IsFrameType("Button") then
          if frame:GetScript("OnClick") ~= nil or frame:GetScript("OnMouseDown") ~= nil or frame:GetScript("OnMouseUp") ~= nil then
            if frame:GetHeight() < pfUI.addonbuttons.max_button_size and frame:GetWidth() < pfUI.addonbuttons.max_button_size then
              if not TablePartialMatch(ignored_icons, frame:GetName()) then
                return true
              end
            end
          end
        end
      end
    end
    return false
  end

  local function FindButtons(frame)
    for i, frame_child in ipairs({frame:GetChildren()}) do
      -- check first level children
      if IsButtonValid(frame_child) and not TableMatch(pfUI.addonbuttons.buttons, frame_child:GetName()) then
        table.insert(pfUI.addonbuttons.buttons, frame_child:GetName())
      else
        if frame_child:GetNumChildren() > 0 then
          for j, child_child in ipairs({frame_child:GetChildren()}) do
            if IsButtonValid(child_child) and not TableMatch(pfUI.addonbuttons.buttons, child_child:GetName()) then
              table.insert(pfUI.addonbuttons.buttons, child_child:GetName())
            end
          end
        end
      end
    end
  end

  local function GetScale()
    local sum_size, buttons_count, calculated_scale
    sum_size = 0
    buttons_count = GetNumButtons()
    for i, button_name in ipairs(pfUI.addonbuttons.buttons) do
      if getglobal(button_name) ~= nil then
        sum_size = sum_size + getglobal(button_name):GetHeight()
      end
    end
    calculated_scale = GetButtonSize() / (sum_size / buttons_count)
    return calculated_scale > 1 and 1 or calculated_scale
  end

  local function Scan()
    FindButtons(Minimap)
    FindButtons(MinimapBackdrop)
  end

  local function Update()
    Scan()
    for i, button_name in ipairs(C.addonbuttons.buttons_add) do
      if not TableMatch(pfUI.addonbuttons.buttons, button_name) then
        if getglobal(button_name) ~= nil then
          table.insert(pfUI.addonbuttons.buttons, button_name)
        end
      end
    end
    for i, button_name in ipairs(C.addonbuttons.buttons_del) do
      if TableMatch(pfUI.addonbuttons.buttons, button_name) then
        table.remove(pfUI.addonbuttons.buttons, TableMatch(pfUI.addonbuttons.buttons, button_name))
      end
    end
    for i, button_name in ipairs(pfUI.addonbuttons.buttons) do
      if getglobal(button_name) == nil then
        table.remove(pfUI.addonbuttons.buttons, TableMatch(pfUI.addonbuttons.buttons, button_name))
      end
    end
    pfUI.addonbuttons:SetHeight(ceil(GetNumButtons() / tonumber(C.addonbuttons.rowsize)) * GetRowHeight() + tonumber(C.addonbuttons.spacing))
  end

  local function GetTopFrame(frame)
    if frame:GetParent() == Minimap or frame:GetParent() == UIParent then
      return frame
    else
      return GetTopFrame(frame:GetParent())
    end
  end

  local function BackupButton(frame)
    if frame.backup == nil then
      frame.backup = {}
      frame.backup.top_frame_name = GetTopFrame(frame):GetName()
      frame.backup.parent_name = GetTopFrame(frame):GetParent():GetName()
      frame.backup.is_clamped_to_screen = frame:IsClampedToScreen()
      frame.backup.is_movable = frame:IsMovable()
      frame.backup.point = {frame:GetPoint()}
      frame.backup.size = {frame:GetHeight(), frame:GetWidth()}
      frame.backup.scale = frame:GetScale()
      if frame:HasScript("OnDragStart") then
        frame.backup.on_drag_start = frame:GetScript("OnDragStart")
      end
      if frame:HasScript("OnDragStop") then
        frame.backup.on_drag_stop = frame:GetScript("OnDragStop")
      end
    end
  end

  local function RestoreButton(frame)
    if frame.backup ~= nil then
      getglobal(frame.backup.top_frame_name):SetParent(frame.backup.parent_name)
      frame:SetClampedToScreen(frame.backup.is_clamped_to_screen)
      frame:SetMovable(frame.backup.is_movable)
      frame:SetScale(frame.backup.scale)
      frame:SetHeight(frame.backup.size[1])
      frame:SetWidth(frame.backup.size[2])
      frame:ClearAllPoints()
      frame:SetPoint(frame.backup.point[1], frame.backup.point[2], frame.backup.point[3], frame.backup.point[4], frame.backup.point[5])
      if frame.backup.on_drag_start ~= nil then
        frame:SetScript("OnDragStart", frame.backup.on_drag_start)
      end
      if frame.backup.on_drag_stop ~= nil then
        frame:SetScript("OnDragStop", frame.backup.on_drag_stop)
      end
    end
  end

  local function MoveButton(index, frame)
    local top_frame, row_index, offsetX, offsetY, final_scale
    top_frame = GetTopFrame(frame)
    if top_frame ~= pfUI.addonbuttons then
      top_frame:SetParent(pfUI.addonbuttons)
    end
    final_scale = GetScale() / pfUI.addonbuttons.effective_scale
    row_index = floor((index-1)/tonumber(C.addonbuttons.rowsize))
    offsetX = ((index - row_index * tonumber(C.addonbuttons.rowsize)) * (tonumber(C.addonbuttons.spacing))) + (((index - row_index * tonumber(C.addonbuttons.rowsize)) - 1) * GetButtonSize()) + (GetButtonSize() / 2)
    offsetY = -(((row_index + 1) * tonumber(C.addonbuttons.spacing)) + (row_index * GetButtonSize()) + (GetButtonSize() / 2))
    frame:SetClampedToScreen(true)
    frame:SetMovable(false)
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    frame:SetClampedToScreen(true)
    frame:SetMovable(false)
    frame:SetScale(final_scale)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", pfUI.addonbuttons, "TOPLEFT", offsetX/final_scale, offsetY/final_scale)
  end

  local function ManualAddOrRemove(action)
    local button = GetMouseFocus()
    if IsButtonValid(button) then
      if action == "add" then
        if TableMatch(C.addonbuttons.buttons_del, button:GetName()) then
          table.remove(C.addonbuttons.buttons_del, TableMatch(C.addonbuttons.buttons_del, button:GetName()))
        end
        if not TableMatch(pfUI.addonbuttons.buttons, button:GetName()) and not TableMatch(C.addonbuttons.buttons_add, button:GetName()) then
          table.insert(C.addonbuttons.buttons_add, button:GetName())
          message("Added button: " .. button:GetName())
        else
          message("Button already exists in pfMinimapButtons frame")
          return
        end
      elseif action == "del" then
        if TableMatch(C.addonbuttons.buttons_add, button:GetName()) then
          table.remove(C.addonbuttons.buttons_add, TableMatch(C.addonbuttons.buttons_add, button:GetName()))
        end
        if TableMatch(pfUI.addonbuttons.buttons, button:GetName()) then
          table.remove(pfUI.addonbuttons.buttons, TableMatch(pfUI.addonbuttons.buttons, button:GetName()))
        else
          message("Button not found in pfMinimapButtons frame")
          return
        end
        if not TableMatch(C.addonbuttons.buttons_del, button:GetName()) then
          table.insert(C.addonbuttons.buttons_del, button:GetName())
          RestoreButton(button)
          message("Removed button: " .. button:GetName())
        end
      else
        message("/mbb add - to add button to the frame")
        message("/mbb del - to remove button from the frame")
        return
      end
      pfUI.addonbuttons:ProcessButtons()
      return
    end
    message("Not a valid button!")
  end


  function pfUI.addonbuttons:ProcessButtons()
    Update()
    for i, button_name in ipairs(pfUI.addonbuttons.buttons) do
      if getglobal(button_name) ~= nil then
        BackupButton(getglobal(button_name))
        MoveButton(i, getglobal(button_name))
      end
    end
  end

  function pfUI.addonbuttons:UpdateConfig()
    pfUI.addonbuttons:ProcessButtons()
    pfUI.addonbuttons:GetScript("OnEvent")()
  end

  pfUI.addonbuttons:SetScript("OnUpdate", function()
    pfUI.addonbuttons.last_updated = pfUI.addonbuttons.last_updated + arg1  
    while (pfUI.addonbuttons.last_updated > tonumber(C.addonbuttons.updateinterval)) do
      pfUI.addonbuttons:ProcessButtons()
      pfUI.addonbuttons.last_updated = pfUI.addonbuttons.last_updated - tonumber(C.addonbuttons.updateinterval)
    end
  end)

  pfUI.addonbuttons:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_DISABLED" then
      if C.addonbuttons.hideincombat == "1" and pfUI.addonbuttons:IsShown() then
        pfUI.addonbuttons:Hide()
      end
    else
      pfUI.addonbuttons:ProcessButtons()
      if not pfUI.addonbuttons.loaded and not pfUI.addonbuttons:IsShown() then
        pfUI.addonbuttons:Show()
        pfUI.addonbuttons.loaded = true
      end
    end
  end)

  pfUI.panel.minimap:SetScript("OnMouseDown", function()
    if arg1 == "RightButton" then
      if pfUI.addonbuttons:IsShown() then
        pfUI.addonbuttons:Hide()
      else
        pfUI.addonbuttons:Show()
      end
    end
  end)

  pfUI.addonbuttons:UpdateConfig()
  
  _G.SLASH_PFABP1 = "/abp"
  _G.SlashCmdList.PFABP = ManualAddOrRemove

end)
