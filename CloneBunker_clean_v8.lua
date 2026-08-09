--[[
  PHONE ID VIEWER v10.1 – Full Code
  - Status bar: sinyal hitam kecil di kiri, baterai hitam kecil di kanan
  - Favorites tabs horizontal (Players & Items berdampingan)
  - Emote dihapus total, Reset dengan daftar avatar
  - Settings lengkap: Auto Lock (disabled), Clock Format, Background Music, Button Sound, dll.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()


-- ================= MAP LOCK SYSTEM (MULTI-MAP) =================
-- Taruh di bagian paling atas script

local ALLOWED_PLACE_IDS = {
    133943904733338, -- Map 1
    7041939546,       -- Map 2
    -- Tambahkan Place ID lain di sini kalau perlu
}

-- Cek apakah Place ID saat ini diizinkan
local function isAllowed(placeId)
    for _, allowedId in ipairs(ALLOWED_PLACE_IDS) do
        if placeId == allowedId then
            return true
        end
    end
    return false
end

if not isAllowed(game.PlaceId) then
    local player = game.Players.LocalPlayer
    
    -- Notifikasi Roblox (atas kanan)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Phone ID Viewer",
            Text = "Script ini hanya untuk map tertentu!",
            Icon = "rbxassetid://0",
            Duration = 5
        })
    end)
    
    -- Chat message (jika game support chat)
    pcall(function()
        local chatRemote = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
        if chatRemote then
            local sayMessage = chatRemote:FindFirstChild("SayMessageRequest")
            if sayMessage then
                sayMessage:FireServer("Phone ID Viewer: Script ini hanya untuk map tertentu!", "All")
            end
        end
    end)
    
    -- Tunggu sebentar
    task.wait(2)
    
    -- Kick player
    pcall(function()
        local allowedList = table.concat(ALLOWED_PLACE_IDS, ", ")
        player:Kick("Script ini hanya berjalan di Place ID: " .. allowedList .. "\nGunakan di map yang benar!")
    end)
    
    -- Hentikan script (jangan lanjut)
    return
end

print("[Phone ID Viewer] Map verified! Script loaded successfully.")

-- ================= CONFIG =================
local CONFIG = {
    TOOL_NAME = "Phone",
    PASSCODE = "2006",
    CLONE_BATCH_SIZE = 5,
    CLONE_DELAY = 6,
    REMOTE_PATH = "Remotes.Command.CommandEvent",
}

-- ================= THEME =================
local T = {
    BG = Color3.fromRGB(255,255,255),
    Card = Color3.fromRGB(245,245,245),
    Card2 = Color3.fromRGB(230,230,230),
    Accent = Color3.fromRGB(30,30,30),
    OnAccent = Color3.new(1,1,1),
    Green = Color3.fromRGB(0,140,0),
    Red = Color3.fromRGB(200,30,30),
    Gold = Color3.fromRGB(200,150,0),
    Text = Color3.fromRGB(30,30,30),
    Text2 = Color3.fromRGB(120,120,120),
    Border = Color3.fromRGB(200,200,200),
}

-- ================= HELPERS =================
local function corner(o,r) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 10);c.Parent=o;return c end
local function stroke(o,c,t,tr) local s=Instance.new("UIStroke");s.Color=c or T.Border;s.Thickness=t or 1;s.Transparency=tr or 0;s.Parent=o;return s end
local function gradient(o,seq,rot) local g=Instance.new("UIGradient");g.Color=seq;g.Rotation=rot or 90;g.Parent=o;return g end
local function tween(o,p,tm,st) TweenService:Create(o,TweenInfo.new(tm or 0.25,st or Enum.EasingStyle.Quart,Enum.EasingDirection.Out),p):Play() end
local function pressFX(b)
    local orig=b.Size
    b.MouseButton1Down:Connect(function()
        tween(b,{Size=UDim2.new(orig.X.Scale*0.94,orig.X.Offset*0.94,orig.Y.Scale*0.9,orig.Y.Offset*0.9)},0.06)
        if appSettings.buttonSounds and appSettings.buttonSoundUrl and appSettings.buttonSoundUrl ~= "" then
            local sound = Instance.new("Sound", b)
            sound.SoundId = appSettings.buttonSoundUrl
            sound.Volume = 0.5
            sound:Play()
            game:GetService("Debris"):AddItem(sound, 2)
        end
    end)
    b.MouseButton1Up:Connect(function()tween(b,{Size=orig},0.12,Enum.EasingStyle.Back)end)
    b.MouseLeave:Connect(function()tween(b,{Size=orig},0.12,Enum.EasingStyle.Back)end)
end
local function copyToClipboard(txt) pcall(function()setclipboard(txt)end) pcall(function()toclipboard(txt)end) end

local function buildToggle(parent,initial,onChange)
    local track=Instance.new("Frame",parent);track.Size=UDim2.new(0,46,0,26);track.BackgroundColor3=initial and T.Accent or Color3.fromRGB(180,180,180);corner(track,100)
    local knob=Instance.new("Frame",track);knob.Size=UDim2.new(0,22,0,22);knob.Position=initial and UDim2.new(1,-24,0.5,-11) or UDim2.new(0,2,0.5,-11);knob.BackgroundColor3=Color3.new(1,1,1);corner(knob,100)
    local btn=Instance.new("TextButton",track);btn.Size=UDim2.new(1,0,1,0);btn.BackgroundTransparency=1;btn.Text="";local state=initial
    btn.MouseButton1Click:Connect(function()state=not state;tween(track,{BackgroundColor3=state and T.Accent or Color3.fromRGB(180,180,180)},0.15);tween(knob,{Position=state and UDim2.new(1,-24,0.5,-11) or UDim2.new(0,2,0.5,-11)},0.18,Enum.EasingStyle.Back);onChange(state)end)
    return track
end


-- ================= STORAGE =================
local PRESET_FILE="PhoneIDViewer_Presets.json"
local FAV_FILE="PhoneIDViewer_FavPlayers.json"
local FAV_ITEMS_FILE="PhoneIDViewer_FavItems.json"
local SETTINGS_FILE="PhoneIDViewer_Settings.json"
local FAV_AVATAR_ITEMS_FILE = "PhoneIDViewer_FavAvatarItems.json"

local function saveJSON(f,d) pcall(function()if writefile then writefile(f,HttpService:JSONEncode(d))end end)end
local function loadJSON(f) local d={};pcall(function()if isfile and isfile(f)then d=HttpService:JSONDecode(readfile(f))end end);return d end

local presets=loadJSON(PRESET_FILE) or {}
local favPlayerIds=loadJSON(FAV_FILE) or {}
local favItems=loadJSON(FAV_ITEMS_FILE) or {}
if type(favItems)~="table" then favItems={} end

local favSet={}
for _,id in ipairs(favPlayerIds)do favSet[tostring(id)]=true end
local function persistFav() local a={};for k,_ in pairs(favSet)do table.insert(a,tonumber(k))end;saveJSON(FAV_FILE,a)end
local function persistFavItems() saveJSON(FAV_ITEMS_FILE,favItems) end

local appSettings=loadJSON(SETTINGS_FILE) or {}
local defaults = {
    themeIndex = 1,
    glowEnabled = true,
    toastEnabled = true,
    buttonSounds = false,
    buttonSoundUrl = "",
    backgroundMusicUrl = "",
    clockFormat = "24",
    phoneOpacity = 1,
    bgColor = Color3.fromRGB(255,255,255),
    bgGradient = true,
}
for k,v in pairs(defaults) do if appSettings[k]==nil then appSettings[k]=v end end
local function persistSettings()saveJSON(SETTINGS_FILE,appSettings)end

-- Background Music
local bgMusicSound = nil
local function updateBackgroundMusic()
    if bgMusicSound then bgMusicSound:Stop(); bgMusicSound:Destroy(); bgMusicSound = nil end
    if appSettings.backgroundMusicUrl and appSettings.backgroundMusicUrl ~= "" then
        bgMusicSound = Instance.new("Sound", game:GetService("SoundService"))
        bgMusicSound.SoundId = appSettings.backgroundMusicUrl
        bgMusicSound.Looped = true
        bgMusicSound.Volume = 0.3
        bgMusicSound:Play()
    end
end
updateBackgroundMusic()


local favAvatarItems = loadJSON(FAV_AVATAR_ITEMS_FILE) or {}
if type(favAvatarItems) ~= "table" then favAvatarItems = {} end
local function persistFavAvatarItems() saveJSON(FAV_AVATAR_ITEMS_FILE, favAvatarItems) end


-- ================= DATA AVATAR =================
local ACC_ORDER={Waist=1,Back=2,Front=3,Shoulders=4,Neck=5,FaceAccessory=6,Hair=7,Hat=8}
local function getItems(p) local c=p.Character;if not c then return{}end;local h=c:FindFirstChildOfClass("Humanoid");if not h then return{}end;local ok,d=pcall(function()return h:GetAppliedDescription()end);if not ok then return{}end;local items={}
    local bodies={{"Head",d.Head},{"Torso",d.Torso},{"LeftArm",d.LeftArm},{"RightArm",d.RightArm},{"LeftLeg",d.LeftLeg},{"RightLeg",d.RightLeg},{"Shirt",d.Shirt},{"Pants",d.Pants},{"Face",d.Face},{"GraphicTShirt",d.GraphicTShirt}}
    for _,b in ipairs(bodies)do if b[2]and b[2]~=""and b[2]~="0"then table.insert(items,{Label=b[1],Value=tostring(b[2]),Type="BODY"})end end
    local ok2,accs=pcall(function()return d:GetAccessories(true)end)if ok2 and accs then local sorted={};for _,a in ipairs(accs)do local order=ACC_ORDER[a.AccessoryType.Name]or 99;table.insert(sorted,{Accessory=a,Order=order})end;table.sort(sorted,function(a,b)return a.Order<b.Order end)for _,sa in ipairs(sorted)do table.insert(items,{Label=sa.Accessory.AccessoryType.Name,Value=tostring(sa.Accessory.AssetId),Type="ACC"})end end
    return items
end

-- ================= CLONE & HAT REMOTE =================
local function fireHat(ids) if#ids==0 then return end;local remote=ReplicatedStorage;for _,part in ipairs(CONFIG.REMOTE_PATH:split("."))do remote=remote:FindFirstChild(part);if not remote then return end end;pcall(function()remote:FireServer("hat",{"hat",unpack(ids)})end)end
local function cloneItems(target,cb) if not target then return end;local items=getItems(target);if#items==0 then return end;local ids={};for _,it in ipairs(items)do table.insert(ids,it.Value)end
    local batch,delay=CONFIG.CLONE_BATCH_SIZE,CONFIG.CLONE_DELAY;local total=math.ceil(#ids/batch);local cur=0
    local function nextBatch() cur=cur+1;if cur>total then if cb then cb(true)end return end
        local s=(cur-1)*batch+1;local e=math.min(cur*batch,#ids);local b={};for i=s,e do table.insert(b,ids[i])end;fireHat(b);if cb then cb(nil,cur,total)end;task.delay(delay,nextBatch)
    end nextBatch()
end

local function cloneFromUserId(userId, cb)
    local success, result = pcall(function()
        return HttpService:JSONDecode(HttpService:GetAsync("https://avatar.roblox.com/v1/users/"..userId.."/avatar"))
    end)
    if not success or not result or not result.assets then
        if cb then cb(false, "Web API gagal") end
        return
    end
    local ids = {}
    for _, asset in ipairs(result.assets) do
        if asset.id and type(asset.id) == "number" then
            table.insert(ids, tostring(asset.id))
        end
    end
    if #ids == 0 then
        if cb then cb(false, "Tidak ada item") end
        return
    end
    fireHat(ids)
    if cb then cb(true) end
end

local function resetCharacter() pcall(function()local remote=ReplicatedStorage;for _,part in ipairs(CONFIG.REMOTE_PATH:split("."))do remote=remote:FindFirstChild(part);if not remote then return end end;remote:FireServer("re")end)end

-- ================= STATE =================
local selectedPlayer=nil;local isCloning=false

-- ================= GUI ROOT =================
-- ==================== GUI ROOT ====================
local gui = Instance.new("ScreenGui")
gui.Name = "PhoneGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 998
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local function getGuiParent()
    local ok, r = pcall(function()
        if gethui then return gethui() end
        if syn and syn.protect_gui then
            local sg = Instance.new("ScreenGui")
            syn.protect_gui(sg)
            sg.Parent = game:GetService("CoreGui")
            return sg
        end
        return game:GetService("CoreGui")
    end)
    return ok and r or game:GetService("CoreGui")
end
gui.Parent = getGuiParent()

-- ==================== PHONE FRAME ====================
local phone = Instance.new("Frame", gui)
phone.Size = UDim2.new(0, 0, 0, 0)
phone.Position = UDim2.new(0.5, 0, 0.52, 0)
phone.AnchorPoint = Vector2.new(0.5, 0.5)
phone.BackgroundColor3 = appSettings.bgColor or T.BG
phone.BorderSizePixel = 0
phone.Visible = false
phone.ClipsDescendants = true
corner(phone, 38)
phone.BackgroundTransparency = 1 - (appSettings.phoneOpacity or 1)

local phoneStroke = stroke(phone, T.Accent, 2, appSettings.glowEnabled and 0.5 or 0.15)
if appSettings.bgGradient then
    gradient(phone, ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 250, 250)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 230, 230))
    }, 100)
end

-- ==================== ORIENTASI ====================
local PHONE_SIZE_PORTRAIT = UDim2.new(0, 320, 0, 560)
local PHONE_SIZE = PHONE_SIZE_PORTRAIT
local isLandscapeMode = false

local function applyPhoneOrientationSize()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    if vp.X <= 0 or vp.Y <= 0 then return end
    
    local landscape = vp.X > vp.Y
    
    if landscape then
        local phoneWidth = math.floor(vp.X * 0.55)
        local phoneHeight = math.floor(vp.Y * 0.75)
        if phoneWidth > phoneHeight * 1.7 then phoneWidth = math.floor(phoneHeight * 1.7) end
        if phoneWidth < 250 then phoneWidth = 250 end
        if phoneHeight < 140 then phoneHeight = 140 end
        
        PHONE_SIZE = UDim2.new(0, phoneWidth, 0, phoneHeight)
        phone.Position = UDim2.new(0.5, 0, 0.5, 0)
        isLandscapeMode = true
    else
        PHONE_SIZE = PHONE_SIZE_PORTRAIT
        phone.Position = UDim2.new(0.5, 0, 0.52, 0)
        isLandscapeMode = false
    end
    
    -- Update screen area & home screen
    updateScreenAreaForOrientation()
    updateHomeForOrientation()
    
    if phone.Visible then
        tween(phone, {Size = PHONE_SIZE, Position = phone.Position}, 0.3, Enum.EasingStyle.Quart)
    end
end

local function isPortrait()
    local cam = Workspace.CurrentCamera
    if not cam then return true end
    return cam.ViewportSize.Y >= cam.ViewportSize.X
end

local function getGridIconSize()
    if isPortrait() then
        return UDim2.new(0, 72, 0, 86)
    else
        return UDim2.new(0, 68, 0, 78)
    end
end

-- ==================== SCREEN AREA ====================
local sa = Instance.new("Frame", phone)
sa.Size = UDim2.new(1, -16, 1, -16)
sa.Position = UDim2.new(0, 8, 0, 8)
sa.BackgroundColor3 = T.BG
sa.BorderSizePixel = 0
sa.ClipsDescendants = true
corner(sa, 30)

local sb = Instance.new("Frame", sa)
sb.Size = UDim2.new(1, 0, 0, 34)
sb.BackgroundTransparency = 1
sb.ZIndex = 100

local clockLbl = Instance.new("TextLabel", sb)
clockLbl.Size = UDim2.new(0, 80, 1, 0)
clockLbl.Position = UDim2.new(0, 14, 0, 0)
clockLbl.BackgroundTransparency = 1
clockLbl.Text = os.date("%H:%M")
clockLbl.TextColor3 = T.Text
clockLbl.Font = Enum.Font.GothamBold
clockLbl.TextSize = 13
clockLbl.TextXAlignment = Enum.TextXAlignment.Left

task.spawn(function()
    while clockLbl.Parent do
        clockLbl.Text = os.date("%H:%M")
        task.wait(30)
    end
end)
-- Signal bars di status bar tablet
local sbSignal = Instance.new("Frame", sb)
sbSignal.Size = UDim2.new(0, 20, 0, 14)
sbSignal.Position = UDim2.new(1, -80, 0.5, -7)
sbSignal.BackgroundTransparency = 1
sbSignal.ZIndex = 102

for i = 1, 4 do
    local bar = Instance.new("Frame", sbSignal)
    bar.Size = UDim2.new(0, 3, 0, 3 + i * 2)
    bar.Position = UDim2.new(0, (i-1) * 5, 1, 0)
    bar.AnchorPoint = Vector2.new(0, 1)
    bar.BackgroundColor3 = T.Text
    bar.BorderSizePixel = 0
    bar.ZIndex = 103
    corner(bar, 1)
end

-- Battery di status bar tablet
local sbBatFrame = Instance.new("Frame", sb)
sbBatFrame.Size = UDim2.new(0, 26, 0, 14)
sbBatFrame.Position = UDim2.new(1, -50, 0.5, -7)
sbBatFrame.BackgroundTransparency = 1
sbBatFrame.ZIndex = 102

local sbBatBody = Instance.new("Frame", sbBatFrame)
sbBatBody.Size = UDim2.new(0, 20, 0, 12)
sbBatBody.Position = UDim2.new(0, 0, 0.5, -6)
sbBatBody.BackgroundColor3 = T.Text
sbBatBody.BackgroundTransparency = 0.85
sbBatBody.BorderSizePixel = 0
sbBatBody.ZIndex = 103
corner(sbBatBody, 3)
stroke(sbBatBody, T.Text, 1, 0.3)

local sbBatFill = Instance.new("Frame", sbBatBody)
sbBatFill.Size = UDim2.new(0.75, -2, 1, -4)
sbBatFill.Position = UDim2.new(0, 1, 0, 2)
sbBatFill.BackgroundColor3 = T.Text
sbBatFill.BorderSizePixel = 0
sbBatFill.ZIndex = 104
corner(sbBatFill, 2)

local sbBatTip = Instance.new("Frame", sbBatFrame)
sbBatTip.Size = UDim2.new(0, 3, 0, 5)
sbBatTip.Position = UDim2.new(0, 21, 0.5, -2)
sbBatTip.BackgroundColor3 = T.Text
sbBatTip.BackgroundTransparency = 0.5
sbBatTip.BorderSizePixel = 0
sbBatTip.ZIndex = 103
corner(sbBatTip, 1)

-- Dynamic Island
local di = Instance.new("Frame", sa)
di.Size = UDim2.new(0, 90, 0, 24)
di.Position = UDim2.new(0.5, -45, 0, 4)
di.BackgroundColor3 = Color3.new(0, 0, 0)
di.ZIndex = 110
corner(di, 100)

local diStroke = stroke(di, Color3.new(1, 1, 1), 1.5, 0.6)
local dil = Instance.new("TextLabel", di)
dil.Size = UDim2.new(1, -8, 1, 0)
dil.Position = UDim2.new(0, 4, 0, 0)
dil.BackgroundTransparency = 1
dil.Text = ""
dil.TextColor3 = Color3.new(1, 1, 1)
dil.Font = Enum.Font.GothamBold
dil.TextSize = 14
dil.TextXAlignment = Enum.TextXAlignment.Center
dil.ZIndex = 111

local dib = Instance.new("TextButton", di)
dib.Size = UDim2.new(1, 0, 1, 0)
dib.BackgroundTransparency = 1
dib.Text = ""
dib.ZIndex = 42

local bunkerBarLbl = Instance.new("TextLabel", sa)
bunkerBarLbl.Size = UDim2.new(1, 0, 0, 14)
bunkerBarLbl.Position = UDim2.new(0, 0, 0, 30)
bunkerBarLbl.BackgroundTransparency = 1
bunkerBarLbl.Text = "The Bunker"
bunkerBarLbl.TextColor3 = Color3.fromRGB(140, 140, 140)
bunkerBarLbl.Font = Enum.Font.Gotham
bunkerBarLbl.TextSize = 9
bunkerBarLbl.TextXAlignment = Enum.TextXAlignment.Center
bunkerBarLbl.ZIndex = 101

-- ==================== UPDATE SCREEN AREA UNTUK LANDSCAPE ====================
local function updateScreenAreaForOrientation()
    local portrait = isPortrait()
    
    if portrait then
        sa.Size = UDim2.new(1, -16, 1, -16)
        sa.Position = UDim2.new(0, 8, 0, 8)
        corner(sa, 30)
        
        sb.Size = UDim2.new(1, 0, 0, 34)
        clockLbl.Size = UDim2.new(0, 80, 1, 0)
        clockLbl.Position = UDim2.new(0, 14, 0, 0)
        clockLbl.TextSize = 13
        
        di.Size = UDim2.new(0, 90, 0, 24)
        di.Position = UDim2.new(0.5, -45, 0, 4)
        bunkerBarLbl.Position = UDim2.new(0, 0, 0, 30)
        bunkerBarLbl.TextSize = 9
    else
        local padding = math.floor(PHONE_SIZE.X.Offset * 0.025)
        sa.Size = UDim2.new(1, -padding*2, 1, -padding*2)
        sa.Position = UDim2.new(0, padding, 0, padding)
        corner(sa, math.floor(PHONE_SIZE.X.Offset * 0.05))
        
        sb.Size = UDim2.new(1, 0, 0, 24)
        clockLbl.Size = UDim2.new(0, 50, 1, 0)
        clockLbl.Position = UDim2.new(0, 8, 0, 0)
        clockLbl.TextSize = 10
        
        local diW = math.floor(PHONE_SIZE.X.Offset * 0.18)
        di.Size = UDim2.new(0, diW, 0, math.floor(PHONE_SIZE.Y.Offset * 0.045))
        di.Position = UDim2.new(0.5, -diW/2, 0, padding)
        bunkerBarLbl.Position = UDim2.new(0, 0, 0, 20)
        bunkerBarLbl.TextSize = 7
    end
end

-- ================= DYNAMIC BAR =================
local iid=0;local notifyQueue={};local isNotifying=false
local function processNotify()
    if #notifyQueue==0 then isNotifying=false;return end
    isNotifying=true;local info=table.remove(notifyQueue,1)
    local text,color=info.text,info.color
    iid=iid+1;local my=iid
    dil.Text=text;dil.TextColor3=Color3.new(1,1,1);dil.TextTransparency=0
    diStroke.Color=color or Color3.new(1,1,1)
    local textWidth=math.min(240,12*#text+40)
    tween(di,{Size=UDim2.new(0,textWidth,0,32),Position=UDim2.new(0.5,-textWidth/2,0,2)},0.25,Enum.EasingStyle.Back)
    task.delay(1.8,function()if iid~=my then return end;tween(di,{Size=UDim2.new(0,90,0,24),Position=UDim2.new(0.5,-45,0,4)},0.25);task.delay(0.3,function()if iid==my then dil.Text="";processNotify()end end)end)
end
local function showDynamicNotification(text,color) if appSettings.toastEnabled then table.insert(notifyQueue,{text=text,color=color});if not isNotifying then processNotify() end end end

-- ==================== HOME SCREEN ====================
local sh = Instance.new("Frame", sa)
sh.Size = UDim2.new(1, 0, 1, -60)
sh.Position = UDim2.new(0, 0, 0, 34)
sh.BackgroundTransparency = 1
sh.ClipsDescendants = true

local home = Instance.new("Frame", sh)
home.Size = UDim2.new(1, 0, 1, 0)
home.BackgroundTransparency = 1
home.ClipsDescendants = true

local homeWall = Instance.new("Frame", home)
homeWall.Size = UDim2.new(1, 0, 1, 0)
homeWall.BackgroundColor3 = appSettings.bgColor or Color3.fromRGB(240, 240, 250)
homeWall.ZIndex = 0
corner(homeWall, 30)
if appSettings.bgGradient then
    gradient(homeWall, ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 220, 240)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(250, 250, 255))
    }, 135)
end

-- Dock
local dockArea = Instance.new("Frame", home)
dockArea.Size = UDim2.new(0, 224, 0, 64)
dockArea.Position = UDim2.new(0.5, -112, 1, -84)
dockArea.BackgroundTransparency = 1
dockArea.ZIndex = 5

local dockBg = Instance.new("Frame", dockArea)
dockBg.Size = UDim2.new(1, 0, 0, 56)
dockBg.Position = UDim2.new(0, 0, 0, 4)
dockBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
dockBg.BackgroundTransparency = 0.1
corner(dockBg, 20)

local dockGrid = Instance.new("UIGridLayout", dockBg)
dockGrid.CellSize = UDim2.new(0, 70, 0, 50)
dockGrid.CellPadding = UDim2.new(0, 2, 0, 0)
dockGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
dockGrid.VerticalAlignment = Enum.VerticalAlignment.Center
dockGrid.FillDirection = Enum.FillDirection.Horizontal

-- App Grid
local appGrid = Instance.new("ScrollingFrame", home)
appGrid.Size = UDim2.new(1, -16, 1, -156)
appGrid.Position = UDim2.new(0, 8, 0, 70)
appGrid.BackgroundTransparency = 1
appGrid.ScrollBarThickness = 3
appGrid.ScrollBarImageColor3 = T.Accent
appGrid.CanvasSize = UDim2.new(0, 0, 0, 0)
appGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
appGrid.BorderSizePixel = 0

local gridLayout = Instance.new("UIGridLayout", appGrid)
gridLayout.CellSize = getGridIconSize()
gridLayout.CellPadding = UDim2.new(0, 10, 0, 12)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top

-- Bunker text
local bunkerHome = Instance.new("TextLabel", home)
bunkerHome.Size = UDim2.new(0, 200, 0, 14)
bunkerHome.Position = UDim2.new(0.5, -100, 1, -20)
bunkerHome.BackgroundTransparency = 1
bunkerHome.Text = "The Bunker"
bunkerHome.TextColor3 = Color3.fromRGB(180, 180, 200)
bunkerHome.Font = Enum.Font.Gotham
bunkerHome.TextSize = 10
bunkerHome.TextXAlignment = Enum.TextXAlignment.Center
bunkerHome.ZIndex = 10

-- ==================== UPDATE HOME UNTUK LANDSCAPE ====================
local function updateHomeForOrientation()
    local portrait = isPortrait()
    
    if portrait then
        sh.Size = UDim2.new(1, 0, 1, -60)
        sh.Position = UDim2.new(0, 0, 0, 34)
        
        appGrid.Size = UDim2.new(1, -16, 1, -156)
        appGrid.Position = UDim2.new(0, 8, 0, 70)
        gridLayout.CellPadding = UDim2.new(0, 8, 0, 16)
        
        dockArea.Size = UDim2.new(0, 224, 0, 64)
        dockArea.Position = UDim2.new(0.5, -112, 1, -84)
        dockBg.Size = UDim2.new(1, 0, 0, 56)
        dockBg.Position = UDim2.new(0, 0, 0, 4)
        dockGrid.CellSize = UDim2.new(0, 70, 0, 50)
        
        bunkerHome.Size = UDim2.new(0, 200, 0, 14)
        bunkerHome.Position = UDim2.new(0.5, -100, 1, -20)
        bunkerHome.TextSize = 10
    else
        sh.Size = UDim2.new(1, 0, 1, -44)
        sh.Position = UDim2.new(0, 0, 0, 24)
        
        appGrid.Size = UDim2.new(1, -12, 1, -110)
        appGrid.Position = UDim2.new(0, 6, 0, 46)
        gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
        
        local dockW = math.floor(PHONE_SIZE.X.Offset * 0.55)
        dockArea.Size = UDim2.new(0, dockW, 0, 46)
        dockArea.Position = UDim2.new(0.5, -dockW/2, 1, -54)
        dockBg.Size = UDim2.new(1, 0, 0, 40)
        dockBg.Position = UDim2.new(0, 0, 0, 3)
        dockGrid.CellSize = UDim2.new(0, math.floor(dockW/3.5), 0, 36)
        
        bunkerHome.Size = UDim2.new(0, 150, 0, 10)
        bunkerHome.Position = UDim2.new(0.5, -75, 1, -12)
        bunkerHome.TextSize = 7
    end
end

-- Monitor orientasi
task.spawn(function()
    local lastPortrait = nil
    while true do
        task.wait(0.3)
        local curPortrait = isPortrait()
        if curPortrait ~= lastPortrait then
            lastPortrait = curPortrait
            gridLayout.CellSize = getGridIconSize()
            updateHomeForOrientation()
        end
    end
end)

-- Monitor orientasi untuk phone size
task.spawn(function()
    local lastLandscape = nil
    while true do
        task.wait(0.3)
        local cam = Workspace.CurrentCamera
        if not cam then continue end
        local isLand = cam.ViewportSize.X > cam.ViewportSize.Y
        if isLand ~= lastLandscape then
            lastLandscape = isLand
            if phone.Visible then
                applyPhoneOrientationSize()
            end
        end
    end
end)

-- ================= ICON BUILDERS =================
local iconBuilders = {
    -- PLAYERS: Two people silhouette
    Players = function(p, c)
        local size = 0.85
        
        local p1Head = Instance.new("Frame", p)
        p1Head.Size = UDim2.new(0, 11 * size, 0, 11 * size)
        p1Head.Position = UDim2.new(0.5, -13 * size, 0.32, 0)
        p1Head.BackgroundColor3 = c
        p1Head.BackgroundTransparency = 0.35
        corner(p1Head, 100)
        
        local p1Body = Instance.new("Frame", p)
        p1Body.Size = UDim2.new(0, 20 * size, 0, 15 * size)
        p1Body.Position = UDim2.new(0.5, -18 * size, 0.55, 0)
        p1Body.BackgroundColor3 = c
        p1Body.BackgroundTransparency = 0.35
        corner(p1Body, 9)
        
        local p2Head = Instance.new("Frame", p)
        p2Head.Size = UDim2.new(0, 12 * size, 0, 12 * size)
        p2Head.Position = UDim2.new(0.5, 3 * size, 0.27, 0)
        p2Head.BackgroundColor3 = c
        corner(p2Head, 100)
        
        local p2Body = Instance.new("Frame", p)
        p2Body.Size = UDim2.new(0, 22 * size, 0, 16 * size)
        p2Body.Position = UDim2.new(0.5, 1 * size, 0.52, 0)
        p2Body.BackgroundColor3 = c
        corner(p2Body, 10)
    end,
    
    -- CLONE: Dual layer cards
    Clone = function(p, c)
        local backCard = Instance.new("Frame", p)
        backCard.Size = UDim2.new(0, 30, 0, 30)
        backCard.Position = UDim2.new(0.5, -22, 0.3, 0)
        backCard.BackgroundColor3 = c
        backCard.BackgroundTransparency = 0.6
        corner(backCard, 8)
        stroke(backCard, c, 1.5, 0.5)
        
        local frontCard = Instance.new("Frame", p)
        frontCard.Size = UDim2.new(0, 30, 0, 30)
        frontCard.Position = UDim2.new(0.5, -10, 0.4, 0)
        frontCard.BackgroundColor3 = c
        corner(frontCard, 8)
        stroke(frontCard, Color3.new(0, 0, 0), 1, 0.4)
        
        local highlight = Instance.new("Frame", frontCard)
        highlight.Size = UDim2.new(0, 8, 0, 2)
        highlight.Position = UDim2.new(0, 6, 0, 5)
        highlight.BackgroundColor3 = Color3.new(1, 1, 1)
        highlight.BackgroundTransparency = 0.6
        corner(highlight, 1)
    end,

    -- BODY: Human figure
    Body = function(p, c)
        local head = Instance.new("Frame", p)
        head.Size = UDim2.new(0, 13, 0, 13)
        head.Position = UDim2.new(0.5, -6, 0.17, 0)
        head.BackgroundColor3 = c
        corner(head, 100)
        
        local neck = Instance.new("Frame", p)
        neck.Size = UDim2.new(0, 5, 0, 4)
        neck.Position = UDim2.new(0.5, -2, 0.33, 0)
        neck.BackgroundColor3 = c
        corner(neck, 2)
        
        local torso = Instance.new("Frame", p)
        torso.Size = UDim2.new(0, 20, 0, 22)
        torso.Position = UDim2.new(0.5, -10, 0.4, 0)
        torso.BackgroundColor3 = c
        corner(torso, 8)
        
        local leftArm = Instance.new("Frame", p)
        leftArm.Size = UDim2.new(0, 4, 0, 15)
        leftArm.Position = UDim2.new(0.5, -13, 0.42, 0)
        leftArm.BackgroundColor3 = c
        corner(leftArm, 2)
        
        local rightArm = Instance.new("Frame", p)
        rightArm.Size = UDim2.new(0, 4, 0, 15)
        rightArm.Position = UDim2.new(0.5, 9, 0.42, 0)
        rightArm.BackgroundColor3 = c
        corner(rightArm, 2)
        
        local leftLeg = Instance.new("Frame", p)
        leftLeg.Size = UDim2.new(0, 7, 0, 13)
        leftLeg.Position = UDim2.new(0.5, -9, 0.68, 0)
        leftLeg.BackgroundColor3 = c
        corner(leftLeg, 3)
        
        local rightLeg = Instance.new("Frame", p)
        rightLeg.Size = UDim2.new(0, 7, 0, 13)
        rightLeg.Position = UDim2.new(0.5, 2, 0.68, 0)
        rightLeg.BackgroundColor3 = c
        corner(rightLeg, 3)
    end,
    
    -- ACCS: Glasses
    Accs = function(p, c)
        local leftLens = Instance.new("Frame", p)
        leftLens.Size = UDim2.new(0, 16, 0, 16)
        leftLens.Position = UDim2.new(0.5, -20, 0.37, 0)
        leftLens.BackgroundColor3 = Color3.new(1, 1, 1)
        leftLens.BackgroundTransparency = 0.15
        corner(leftLens, 8)
        stroke(leftLens, c, 2.5, 0)
        
        local rightLens = Instance.new("Frame", p)
        rightLens.Size = UDim2.new(0, 16, 0, 16)
        rightLens.Position = UDim2.new(0.5, 4, 0.37, 0)
        rightLens.BackgroundColor3 = Color3.new(1, 1, 1)
        rightLens.BackgroundTransparency = 0.15
        corner(rightLens, 8)
        stroke(rightLens, c, 2.5, 0)
        
        local bridge = Instance.new("Frame", p)
        bridge.Size = UDim2.new(0, 8, 0, 3)
        bridge.Position = UDim2.new(0.5, -4, 0.43, 0)
        bridge.BackgroundColor3 = c
        corner(bridge, 2)
        
        local shineL = Instance.new("Frame", leftLens)
        shineL.Size = UDim2.new(0, 4, 0, 2)
        shineL.Position = UDim2.new(0, 3, 0, 3)
        shineL.BackgroundColor3 = c
        shineL.BackgroundTransparency = 0.5
        shineL.Rotation = -20
        corner(shineL, 1)
        
        local shineR = Instance.new("Frame", rightLens)
        shineR.Size = UDim2.new(0, 4, 0, 2)
        shineR.Position = UDim2.new(0, 3, 0, 3)
        shineR.BackgroundColor3 = c
        shineR.BackgroundTransparency = 0.5
        shineR.Rotation = -20
        corner(shineR, 1)
    end,
    
    -- PRESET: Box with lid
    Preset = function(p, c)
        local box = Instance.new("Frame", p)
        box.Size = UDim2.new(0, 30, 0, 22)
        box.Position = UDim2.new(0.5, -15, 0.5, 0)
        box.BackgroundColor3 = c
        corner(box, 6)
        
        local lid = Instance.new("Frame", p)
        lid.Size = UDim2.new(0, 34, 0, 9)
        lid.Position = UDim2.new(0.5, -17, 0.36, 0)
        lid.BackgroundColor3 = c
        corner(lid, 4)
        
        local handle = Instance.new("Frame", p)
        handle.Size = UDim2.new(0, 14, 0, 3)
        handle.Position = UDim2.new(0.5, -7, 0.31, 0)
        handle.BackgroundColor3 = c
        corner(handle, 2)
        
        local label = Instance.new("Frame", box)
        label.Size = UDim2.new(0, 14, 0, 7)
        label.Position = UDim2.new(0.5, -7, 0.55, 0)
        label.BackgroundColor3 = Color3.new(1, 1, 1)
        label.BackgroundTransparency = 0.5
        corner(label, 3)
    end,
    
    -- FAVS: Star shape
    Favs = function(p, c)
        local hBar = Instance.new("Frame", p)
        hBar.Size = UDim2.new(0, 32, 0, 7)
        hBar.Position = UDim2.new(0.5, -16, 0.5, -3)
        hBar.BackgroundColor3 = c
        corner(hBar, 3)
        
        local vBar = Instance.new("Frame", p)
        vBar.Size = UDim2.new(0, 7, 0, 32)
        vBar.Position = UDim2.new(0.5, -3, 0.5, -16)
        vBar.BackgroundColor3 = c
        corner(vBar, 3)
        
        local diag1 = Instance.new("Frame", p)
        diag1.Size = UDim2.new(0, 24, 0, 5)
        diag1.Position = UDim2.new(0.5, -12, 0.5, -2)
        diag1.BackgroundColor3 = c
        diag1.Rotation = 45
        corner(diag1, 2)
        
        local diag2 = Instance.new("Frame", p)
        diag2.Size = UDim2.new(0, 24, 0, 5)
        diag2.Position = UDim2.new(0.5, -12, 0.5, -2)
        diag2.BackgroundColor3 = c
        diag2.Rotation = -45
        corner(diag2, 2)
        
        local gem = Instance.new("Frame", p)
        gem.Size = UDim2.new(0, 10, 0, 10)
        gem.Position = UDim2.new(0.5, -5, 0.5, -5)
        gem.BackgroundColor3 = c
        corner(gem, 100)
        
        local gemInner = Instance.new("Frame", gem)
        gemInner.Size = UDim2.new(0, 5, 0, 5)
        gemInner.Position = UDim2.new(0.5, -2, 0.5, -2)
        gemInner.BackgroundColor3 = Color3.new(1, 1, 1)
        corner(gemInner, 100)
    end,
    
    
    -- ITEMS: Backpack
    Items = function(p, c)
        local bag = Instance.new("Frame", p)
        bag.Size = UDim2.new(0, 26, 0, 26)
        bag.Position = UDim2.new(0.5, -13, 0.3, 0)
        bag.BackgroundColor3 = c
        corner(bag, 7)
        
        local flap = Instance.new("Frame", p)
        flap.Size = UDim2.new(0, 22, 0, 9)
        flap.Position = UDim2.new(0.5, -11, 0.24, 0)
        flap.BackgroundColor3 = c
        corner(flap, 4)
        
        local pocket = Instance.new("Frame", bag)
        pocket.Size = UDim2.new(0, 12, 0, 10)
        pocket.Position = UDim2.new(0.5, -6, 0.45, 0)
        pocket.BackgroundColor3 = Color3.new(1, 1, 1)
        pocket.BackgroundTransparency = 0.5
        corner(pocket, 3)
        
        local handle = Instance.new("Frame", p)
        handle.Size = UDim2.new(0, 10, 0, 3)
        handle.Position = UDim2.new(0.5, -5, 0.2, 0)
        handle.BackgroundColor3 = c
        corner(handle, 2)
    end,
    
    -- PROFILE: ID card with photo
    Profile = function(p, c)
        local head = Instance.new("Frame", p)
        head.Size = UDim2.new(0, 18, 0, 18)
        head.Position = UDim2.new(0.5, -9, 0.24, 0)
        head.BackgroundColor3 = c
        corner(head, 100)
        
        local card = Instance.new("Frame", p)
        card.Size = UDim2.new(0, 30, 0, 20)
        card.Position = UDim2.new(0.5, -15, 0.56, 0)
        card.BackgroundColor3 = c
        corner(card, 5)
        
        local photo = Instance.new("Frame", card)
        photo.Size = UDim2.new(0, 14, 0, 12)
        photo.Position = UDim2.new(0, 3, 0.5, -6)
        photo.BackgroundColor3 = Color3.new(1, 1, 1)
        photo.BackgroundTransparency = 0.35
        corner(photo, 3)
        
        for i = 1, 2 do
            local line = Instance.new("Frame", card)
            line.Size = UDim2.new(0, 8, 0, 2)
            line.Position = UDim2.new(0, 20, 0.2 + i * 0.2, 0)
            line.BackgroundColor3 = Color3.new(1, 1, 1)
            line.BackgroundTransparency = 0.5
            corner(line, 1)
        end
    end,
    
    
    
    -- SERVER: Rack with lights
    Server = function(p, c)
        local rack = Instance.new("Frame", p)
        rack.Size = UDim2.new(0, 28, 0, 22)
        rack.Position = UDim2.new(0.5, -14, 0.36, 0)
        rack.BackgroundColor3 = c
        corner(rack, 5)
        
        local panel = Instance.new("Frame", rack)
        panel.Size = UDim2.new(0, 18, 0, 12)
        panel.Position = UDim2.new(0.5, -9, 0.5, -6)
        panel.BackgroundColor3 = Color3.new(1, 1, 1)
        panel.BackgroundTransparency = 0.6
        corner(panel, 3)
        
        for i = 1, 3 do
            local led = Instance.new("Frame", panel)
            led.Size = UDim2.new(0, 4, 0, 4)
            led.Position = UDim2.new(0, 3 + i * 4, 0.5, -2)
            led.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
            corner(led, 100)
        end
        
        for i = 1, 3 do
            local vent = Instance.new("Frame", p)
            vent.Size = UDim2.new(0, 24, 0, 1)
            vent.Position = UDim2.new(0.5, -12, 0.3 + i * 0.07, 0)
            vent.BackgroundColor3 = c
            vent.BackgroundTransparency = 0.7
            corner(vent, 1)
        end
    end,
    
    
    
    -- SETTINGS: GEAR SHAPE (FIXED - PROPER GEAR)
    Settings = function(p, c)
        -- Center circle
        local centerCircle = Instance.new("Frame", p)
        centerCircle.Size = UDim2.new(0, 14, 0, 14)
        centerCircle.Position = UDim2.new(0.5, -7, 0.5, -7)
        centerCircle.Position = UDim2.new(0.5, -7, 0.38, 0)
        centerCircle.BackgroundColor3 = c
        corner(centerCircle, 100)
        
        -- Inner hole
        local innerHole = Instance.new("Frame", p)
        innerHole.Size = UDim2.new(0, 6, 0, 6)
        innerHole.Position = UDim2.new(0.5, -3, 0.5, -3)
        innerHole.Position = UDim2.new(0.5, -3, 0.46, 0)
        innerHole.BackgroundColor3 = Color3.new(1, 1, 1)
        corner(innerHole, 100)
        
        -- 8 Gear teeth arranged in a circle
        for i = 1, 8 do
            local angle = math.rad(i * 45) -- 360/8 = 45 degrees apart
            local radius = 11 -- Distance from center
            
            local toothX = math.cos(angle) * radius
            local toothY = math.sin(angle) * radius
            
            local tooth = Instance.new("Frame", p)
            tooth.Size = UDim2.new(0, 5, 0, 5)
            tooth.Position = UDim2.new(0.5, toothX - 2.5, 0.5, toothY - 2.5)
            tooth.Position = UDim2.new(0.5, toothX - 2, 0.38 + toothY * 0.018, 0)
            tooth.BackgroundColor3 = c
            tooth.Rotation = i * 45
            corner(tooth, 1)
        end
        
        -- Outer ring (connecting teeth)
        local outerRing = Instance.new("Frame", p)
        outerRing.Size = UDim2.new(0, 24, 0, 24)
        outerRing.Position = UDim2.new(0.5, -12, 0.5, -12)
        outerRing.Position = UDim2.new(0.5, -12, 0.3, 0)
        outerRing.BackgroundTransparency = 1
        stroke(outerRing, c, 2, 0.3)
        corner(outerRing, 100)
    end,
    
   -- Di iconBuilders, tambahkan:
AvatarItems = function(p, c)
    local head = Instance.new("Frame", p)
    head.Size = UDim2.new(0, 14, 0, 14)
    head.Position = UDim2.new(0.5, -7, 0.2, 0)
    head.BackgroundColor3 = c
    corner(head, 100)
    
    local body = Instance.new("Frame", p)
    body.Size = UDim2.new(0, 24, 0, 18)
    body.Position = UDim2.new(0.5, -12, 0.52, 0)
    body.BackgroundColor3 = c
    corner(body, 8)
    
    local tag = Instance.new("Frame", p)
    tag.Size = UDim2.new(0, 12, 0, 8)
    tag.Position = UDim2.new(0.5, 10, 0.38, 0)
    tag.BackgroundColor3 = c
    tag.BackgroundTransparency = 0.4
    corner(tag, 3)
end,

-- Di iconBuilders:
Lookup = function(p, c)
    -- Magnifying glass
    local circle = Instance.new("Frame", p)
    circle.Size = UDim2.new(0, 22, 0, 22)
    circle.Position = UDim2.new(0.5, -14, 0.25, 0)
    circle.BackgroundTransparency = 1
    stroke(circle, c, 3, 0)
    corner(circle, 100)
    
    local handle = Instance.new("Frame", p)
    handle.Size = UDim2.new(0, 3, 0, 12)
    handle.Position = UDim2.new(0.5, 6, 0.5, 2)
    handle.BackgroundColor3 = c
    handle.Rotation = 45
    corner(handle, 2)
end,


WhoOnline = function(p, c)
    -- Globe/earth (lingkaran)
    local globe = Instance.new("Frame", p)
    globe.Size = UDim2.new(0, 24, 0, 24)
    globe.Position = UDim2.new(0.5, -12, 0.22, 0)
    globe.BackgroundColor3 = c
    globe.BackgroundTransparency = 0.85
    corner(globe, 100)
    stroke(globe, c, 2.5, 0)
    
    -- Garis horizontal (equator)
    local equator = Instance.new("Frame", globe)
    equator.Size = UDim2.new(0, 18, 0, 1.5)
    equator.Position = UDim2.new(0.5, -9, 0.5, -0.75)
    equator.BackgroundColor3 = c
    equator.BackgroundTransparency = 0.5
    corner(equator, 1)
    
    -- Garis vertikal (meridian)
    local meridian = Instance.new("Frame", globe)
    meridian.Size = UDim2.new(0, 1.5, 0, 18)
    meridian.Position = UDim2.new(0.5, -0.75, 0.5, -9)
    meridian.BackgroundColor3 = c
    meridian.BackgroundTransparency = 0.5
    corner(meridian, 1)
    
    -- Garis diagonal
    local diag1 = Instance.new("Frame", globe)
    diag1.Size = UDim2.new(0, 12, 0, 1.5)
    diag1.Position = UDim2.new(0.5, -6, 0.5, -0.75)
    diag1.BackgroundColor3 = c
    diag1.BackgroundTransparency = 0.6
    diag1.Rotation = 45
    corner(diag1, 1)
    
    local diag2 = Instance.new("Frame", globe)
    diag2.Size = UDim2.new(0, 12, 0, 1.5)
    diag2.Position = UDim2.new(0.5, -6, 0.5, -0.75)
    diag2.BackgroundColor3 = c
    diag2.BackgroundTransparency = 0.6
    diag2.Rotation = -45
    corner(diag2, 1)
    
    -- 3 titik (mewakili user online)
    local dotColors = {
        Color3.fromRGB(0, 255, 100),
        Color3.fromRGB(0, 255, 100),
        Color3.fromRGB(0, 255, 100)
    }
    
    for i = 1, 3 do
        local dot = Instance.new("Frame", p)
        dot.Size = UDim2.new(0, 5, 0, 5)
        dot.Position = UDim2.new(0, 4 + (i-1)*9, 0, 65 + (i-1)*3)
        dot.Position = UDim2.new(0.5 - 8 + (i-1)*8, 0, 1, -10)
        dot.BackgroundColor3 = dotColors[i]
        dot.BackgroundTransparency = (i == 3) and 0.4 or 0
        corner(dot, 100)
    end
    
    -- Sinyal waves (seperti WiFi)
    for i = 1, 2 do
        local wave = Instance.new("Frame", p)
        wave.Size = UDim2.new(0, 5, 0, 5)
        wave.Position = UDim2.new(0, 2 + (i-1)*7, 0, 50 + (i-1)*8)
        wave.BackgroundTransparency = 1
        stroke(wave, c, 1.5, 0.3)
        corner(wave, 100)
    end
end,

}


-- ================= BUILD APP ICON =================
local function buildAppIcon(name, order, parent, onOpen)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(0, 74, 0, 96)
    container.BackgroundTransparency = 1
    container.LayoutOrder = order
    
    local btn = Instance.new("TextButton", container)
    btn.Size = UDim2.new(0, 58, 0, 58)
    btn.Position = UDim2.new(0.5, -29, 0, 2)
    btn.BackgroundColor3 = Color3.fromRGB(248, 248, 252)
    btn.Text = ""
    btn.AutoButtonColor = false
    corner(btn, 16)
    stroke(btn, Color3.fromRGB(215, 215, 220), 1, 0.4)
    
    local btnGradient = Instance.new("UIGradient", btn)
    btnGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(252, 252, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 240, 245))
    })
    btnGradient.Rotation = 135
    
    local iconFrame = Instance.new("Frame", btn)
    iconFrame.Size = UDim2.new(0, 40, 0, 40)
    iconFrame.Position = UDim2.new(0.5, -20, 0.5, -20)
    iconFrame.BackgroundTransparency = 1
    
    local builder = iconBuilders[name]
    if builder then
        builder(iconFrame, T.Text)
    else
        local fallbackCircle = Instance.new("Frame", iconFrame)
        fallbackCircle.Size = UDim2.new(0, 34, 0, 34)
        fallbackCircle.Position = UDim2.new(0.5, -17, 0.5, -17)
        fallbackCircle.BackgroundColor3 = T.Text
        fallbackCircle.BackgroundTransparency = 0.85
        corner(fallbackCircle, 100)
        
        local letter = Instance.new("TextLabel", iconFrame)
        letter.Size = UDim2.new(1, 0, 1, 0)
        letter.BackgroundTransparency = 1
        letter.Text = string.sub(name, 1, 1):upper()
        letter.TextColor3 = T.Text
        letter.Font = Enum.Font.GothamBlack
        letter.TextSize = 22
    end

    pressFX(btn)
    
    local label = Instance.new("TextLabel", container)
    label.Size = UDim2.new(1, 0, 0, 28)
    label.Position = UDim2.new(0, 0, 0, 63)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = T.Text
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 10
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.LineHeight = 1.1
    
    btn.MouseButton1Click:Connect(onOpen)
    
    return container
end


-- ================= APP SCREEN =================
local appScr=Instance.new("Frame",sh);appScr.Size=UDim2.new(1,0,1,0);appScr.Position=UDim2.new(1,0,0,0);appScr.BackgroundTransparency=1;appScr.BackgroundColor3=T.BG;appScr.ClipsDescendants=true
local appHdr=Instance.new("Frame",appScr);appHdr.Size=UDim2.new(1,-12,0,36);appHdr.Position=UDim2.new(0,6,0,0);appHdr.BackgroundTransparency=1
local backBtn=Instance.new("TextButton",appHdr);backBtn.Size=UDim2.new(0,50,0,28);backBtn.Position=UDim2.new(0,0,0,4);backBtn.BackgroundColor3=T.Card;backBtn.Text="< Back";backBtn.TextColor3=T.Text;backBtn.Font=Enum.Font.GothamBold;backBtn.TextSize=11;backBtn.AutoButtonColor=false;corner(backBtn,8);stroke(backBtn,T.Border,1,0.3);pressFX(backBtn)
local appTitle=Instance.new("TextLabel",appHdr);appTitle.Size=UDim2.new(1,-120,0,28);appTitle.Position=UDim2.new(0,56,0,4);appTitle.BackgroundTransparency=1;appTitle.Text="";appTitle.TextColor3=T.Text;appTitle.Font=Enum.Font.GothamBlack;appTitle.TextSize=14;appTitle.TextXAlignment=Enum.TextXAlignment.Left
local appContent=Instance.new("ScrollingFrame",appScr);appContent.Size=UDim2.new(1,-12,1,-44);appContent.Position=UDim2.new(0,6,0,42);appContent.BackgroundTransparency=1;appContent.BorderSizePixel=0;appContent.ScrollBarThickness=3;appContent.ScrollBarImageColor3=T.Accent;appContent.CanvasSize=UDim2.new(0,0,0,0);appContent.AutomaticCanvasSize=Enum.AutomaticSize.Y
local acl=Instance.new("UIListLayout",appContent);acl.Padding=UDim.new(0,8);acl.SortOrder=Enum.SortOrder.LayoutOrder
local function clearAppContent() for _,c in ipairs(appContent:GetChildren())do if not c:IsA("UIListLayout")then c:Destroy()end end end
local currOpener=nil
local function goHome() home.Visible=true;appScr.BackgroundTransparency=1;tween(appScr,{Position=UDim2.new(1,0,0,0)},0.28,Enum.EasingStyle.Quart);tween(home,{Position=UDim2.new(0,0,0,0)},0.28,Enum.EasingStyle.Quart) end
dib.MouseButton1Click:Connect(function()if appScr.Position.X.Scale==0 then goHome()end end)
local function openApp(title,fn) home.Visible=false;appScr.BackgroundTransparency=0;appScr.BackgroundColor3=T.BG;appTitle.Text=title;clearAppContent();currOpener=fn;fn();appScr.Position=UDim2.new(1,0,0,0);tween(appScr,{Position=UDim2.new(0,0,0,0)},0.28,Enum.EasingStyle.Quart);tween(home,{Position=UDim2.new(0,0,0,0)},0.28,Enum.EasingStyle.Quart);showDynamicNotification(title,T.Accent) end
local function refreshCurr() if currOpener then clearAppContent();currOpener()end end
backBtn.MouseButton1Click:Connect(goHome)

-- ================= SHARED HELPERS =================
local function buildItemRow(parent,item,order)
    local row=Instance.new("Frame",parent);row.Size=UDim2.new(1,0,0,52);row.BackgroundColor3=T.Card2;row.LayoutOrder=order;corner(row,10);stroke(row,T.Border,1,0.3)
    local thumb=Instance.new("ImageLabel",row);thumb.Size=UDim2.new(0,42,0,42);thumb.Position=UDim2.new(0,5,0.5,-21);thumb.BackgroundColor3=T.BG;thumb.Image="https://www.roblox.com/asset-thumbnail/image?assetId="..item.Value.."&width=100&height=100&format=png";thumb.ScaleType=Enum.ScaleType.Fit;corner(thumb,8);stroke(thumb,T.Border,1,0.3)
    local nameLbl=Instance.new("TextLabel",row);nameLbl.Size=UDim2.new(1,-130,0,18);nameLbl.Position=UDim2.new(0,52,0,6);nameLbl.BackgroundTransparency=1;nameLbl.Text=item.Label;nameLbl.TextColor3=T.Text;nameLbl.Font=Enum.Font.GothamBold;nameLbl.TextSize=12;nameLbl.TextXAlignment=Enum.TextXAlignment.Left
    local idLbl=Instance.new("TextLabel",row);idLbl.Size=UDim2.new(1,-130,0,16);idLbl.Position=UDim2.new(0,52,0,24);idLbl.BackgroundTransparency=1;idLbl.Text=item.Value;idLbl.TextColor3=T.Green;idLbl.Font=Enum.Font.Code;idLbl.TextSize=10;idLbl.TextXAlignment=Enum.TextXAlignment.Left
    local copyBtn=Instance.new("TextButton",row);copyBtn.Size=UDim2.new(0,60,0,28);copyBtn.Position=UDim2.new(1,-66,0.5,-14);copyBtn.BackgroundColor3=T.Accent;copyBtn.Text="Copy";copyBtn.TextColor3=T.OnAccent;copyBtn.Font=Enum.Font.GothamBold;copyBtn.TextSize=10;copyBtn.AutoButtonColor=false;corner(copyBtn,6);pressFX(copyBtn)
    copyBtn.MouseButton1Click:Connect(function()copyToClipboard(item.Value);showDynamicNotification("Copied: "..item.Value,T.Green)end)
end

-- ================= APPS =================

-- PLAYERS
local function openPlayersApp()
    local searchBox=Instance.new("Frame",appContent);searchBox.Size=UDim2.new(1,0,0,36);searchBox.BackgroundColor3=T.Card2;searchBox.LayoutOrder=0;corner(searchBox,9);stroke(searchBox,T.Border,1,0.3)
    local searchInput=Instance.new("TextBox",searchBox);searchInput.Size=UDim2.new(1,-16,1,0);searchInput.Position=UDim2.new(0,8,0,0);searchInput.BackgroundTransparency=1;searchInput.PlaceholderText="Search player...";searchInput.Text="";searchInput.TextColor3=T.Text;searchInput.Font=Enum.Font.Gotham;searchInput.TextSize=13;searchInput.ClearTextOnFocus=false
    local listHolder=Instance.new("Frame",appContent);listHolder.Size=UDim2.new(1,0,0,0);listHolder.AutomaticSize=Enum.AutomaticSize.Y;listHolder.BackgroundTransparency=1;listHolder.LayoutOrder=1
    local listLayout=Instance.new("UIListLayout",listHolder);listLayout.Padding=UDim.new(0,8);listLayout.SortOrder=Enum.SortOrder.LayoutOrder
    local function renderList(filter)
        for _,c in ipairs(listHolder:GetChildren())do if not c:IsA("UIListLayout")then c:Destroy()end end
        filter=(filter or""):lower()
        local list=Players:GetPlayers()
        table.sort(list,function(a,b)if a==LocalPlayer then return true end;if b==LocalPlayer then return false end;local af=favSet[tostring(a.UserId)]and 1 or 0;local bf=favSet[tostring(b.UserId)]and 1 or 0;if af~=bf then return af>bf end;return a.DisplayName<b.DisplayName end)
        for i,p in ipairs(list)do if filter==""or p.Name:lower():find(filter,1,true)or p.DisplayName:lower():find(filter,1,true)then
            local isMe=p==LocalPlayer;local isFav=favSet[tostring(p.UserId)]==true;local isSel=selectedPlayer==p
            local row=Instance.new("Frame",listHolder);row.Size=UDim2.new(1,0,0,60);row.BackgroundColor3=isSel and Color3.fromRGB(220,220,220)or T.Card2;row.LayoutOrder=i;corner(row,10);stroke(row,isSel and T.Accent or T.Border,isSel and 2 or 1,isSel and 0 or 0.3)
            local av=Instance.new("ImageLabel",row);av.Size=UDim2.new(0,44,0,44);av.Position=UDim2.new(0,8,0.5,-22);av.BackgroundColor3=T.BG;av.Image="https://www.roblox.com/headshot-thumbnail/image?userId="..p.UserId.."&width=100&height=100&format=png";corner(av,100)
            local nameLbl=Instance.new("TextLabel",row);nameLbl.Size=UDim2.new(1,-170,0,20);nameLbl.Position=UDim2.new(0,60,0,10);nameLbl.BackgroundTransparency=1;nameLbl.Text=(isMe and"(You) "or"")..p.DisplayName;nameLbl.TextColor3=isMe and T.Accent or T.Text;nameLbl.Font=Enum.Font.GothamBold;nameLbl.TextSize=13;nameLbl.TextXAlignment=Enum.TextXAlignment.Left;nameLbl.TextTruncate=Enum.TextTruncate.AtEnd
            local userLbl=Instance.new("TextLabel",row);userLbl.Size=UDim2.new(1,-170,0,16);userLbl.Position=UDim2.new(0,60,0,32);userLbl.BackgroundTransparency=1;userLbl.Text="@"..p.Name;userLbl.TextColor3=T.Text2;userLbl.Font=Enum.Font.Gotham;userLbl.TextSize=10;userLbl.TextXAlignment=Enum.TextXAlignment.Left
            if not isMe then
                local starBtn=Instance.new("TextButton",row);starBtn.Size=UDim2.new(0,34,0,30);starBtn.Position=UDim2.new(1,-108,0.5,-15);starBtn.BackgroundColor3=isFav and T.Gold or T.Card;starBtn.Text="Fav";starBtn.TextColor3=isFav and T.OnAccent or T.Text2;starBtn.Font=Enum.Font.GothamBold;starBtn.TextSize=10;starBtn.AutoButtonColor=false;corner(starBtn,7);stroke(starBtn,T.Border,1,0.3);pressFX(starBtn)
                starBtn.MouseButton1Click:Connect(function()local k=tostring(p.UserId);if favSet[k]then favSet[k]=nil;showDynamicNotification("Removed from fav",T.Text2)else favSet[k]=true;showDynamicNotification("Added to fav",T.Gold)end;persistFav();renderList(searchInput.Text)end)
            end
            local selBtn=Instance.new("TextButton",row);selBtn.Size=UDim2.new(0,66,0,30);selBtn.Position=UDim2.new(1,-72,0.5,-15);selBtn.BackgroundColor3=T.Accent;selBtn.Text=isSel and"Selected"or"Select";selBtn.TextColor3=T.OnAccent;selBtn.Font=Enum.Font.GothamBold;selBtn.TextSize=10;selBtn.AutoButtonColor=false;corner(selBtn,7);pressFX(selBtn)
            selBtn.MouseButton1Click:Connect(function()selectedPlayer=p;showDynamicNotification("Target: "..p.DisplayName,T.Green);renderList(searchInput.Text)end)
        end end
    end
    renderList("");searchInput:GetPropertyChangedSignal("Text"):Connect(function()renderList(searchInput.Text)end)
end

-- BODY
local function openBodyApp()
    if not selectedPlayer then local h=Instance.new("TextLabel",appContent);h.Size=UDim2.new(1,0,0,60);h.BackgroundTransparency=1;h.Text="Select a player first.";h.TextColor3=T.Text2;h.Font=Enum.Font.Gotham;h.TextSize=12;h.TextWrapped=true;return end
    local items=getItems(selectedPlayer);local shown=0;for _,it in ipairs(items)do if it.Type=="BODY"then shown=shown+1;buildItemRow(appContent,it,shown)end end
    if shown==0 then local n=Instance.new("TextLabel",appContent);n.Size=UDim2.new(1,0,0,40);n.BackgroundTransparency=1;n.Text="No body items.";n.TextColor3=T.Text2;n.Font=Enum.Font.Gotham;n.TextSize=12 end
end

-- ACCESSORY
local function openAccessoryApp()
    if not selectedPlayer then local h=Instance.new("TextLabel",appContent);h.Size=UDim2.new(1,0,0,60);h.BackgroundTransparency=1;h.Text="Select a player first.";h.TextColor3=T.Text2;h.Font=Enum.Font.Gotham;h.TextSize=12;h.TextWrapped=true;return end
    local items=getItems(selectedPlayer);local shown=0;for _,it in ipairs(items)do if it.Type=="ACC"then shown=shown+1;buildItemRow(appContent,it,shown)end end
    if shown==0 then local n=Instance.new("TextLabel",appContent);n.Size=UDim2.new(1,0,0,40);n.BackgroundTransparency=1;n.Text="No accessories.";n.TextColor3=T.Text2;n.Font=Enum.Font.Gotham;n.TextSize=12 end
end

-- CLONE
local function openCloneApp()
    if not selectedPlayer then local h=Instance.new("TextLabel",appContent);h.Size=UDim2.new(1,0,0,60);h.BackgroundTransparency=1;h.Text="Select a player first.";h.TextColor3=T.Text2;h.Font=Enum.Font.Gotham;h.TextSize=12;h.TextWrapped=true;return end
    if isCloning then local w=Instance.new("TextLabel",appContent);w.Size=UDim2.new(1,0,0,40);w.BackgroundTransparency=1;w.Text="Cloning in progress...";w.TextColor3=T.Text2;w.Font=Enum.Font.Gotham;w.TextSize=12;return end
    local items=getItems(selectedPlayer);if#items==0 then local n=Instance.new("TextLabel",appContent);n.Size=UDim2.new(1,0,0,40);n.BackgroundTransparency=1;n.Text="No items to clone.";n.TextColor3=T.Text2;n.Font=Enum.Font.Gotham;n.TextSize=12;return end
    local pf=Instance.new("Frame",appContent);pf.Size=UDim2.new(1,0,0,60);pf.BackgroundColor3=T.Card2;corner(pf,10);stroke(pf,T.Accent,1.5,0.3)
    local av=Instance.new("ImageLabel",pf);av.Size=UDim2.new(0,44,0,44);av.Position=UDim2.new(0,8,0.5,-22);av.BackgroundColor3=T.BG;av.Image="https://www.roblox.com/headshot-thumbnail/image?userId="..selectedPlayer.UserId.."&width=100&height=100&format=png";corner(av,100)
    local nl=Instance.new("TextLabel",pf);nl.Size=UDim2.new(1,-100,0,30);nl.Position=UDim2.new(0,56,0,14);nl.BackgroundTransparency=1;nl.Text=selectedPlayer.DisplayName;nl.TextColor3=T.Text;nl.Font=Enum.Font.GothamBold;nl.TextSize=14;nl.TextXAlignment=Enum.TextXAlignment.Left
    local ic=Instance.new("TextLabel",pf);ic.Size=UDim2.new(1,-100,0,20);ic.Position=UDim2.new(0,56,0,36);ic.BackgroundTransparency=1;ic.Text=#items.." items";ic.TextColor3=T.Green;ic.Font=Enum.Font.Gotham;ic.TextSize=11;ic.TextXAlignment=Enum.TextXAlignment.Left
    local cloneBtn=Instance.new("TextButton",appContent);cloneBtn.Size=UDim2.new(1,0,0,46);cloneBtn.BackgroundColor3=T.Accent;cloneBtn.Text="Clone Hat (5 IDs / 6s)";cloneBtn.TextColor3=T.OnAccent;cloneBtn.Font=Enum.Font.GothamBlack;cloneBtn.TextSize=14;cloneBtn.AutoButtonColor=false;corner(cloneBtn,10);pressFX(cloneBtn)
    cloneBtn.MouseButton1Click:Connect(function()
        if isCloning then return end
        isCloning=true
        cloneBtn.Text="Cloning..."
        cloneBtn.BackgroundColor3=T.Gold
        -- Close the Phone window, but keep the floating/open button visible.
        if phoneFrame then
            phoneFrame.Visible = false
        end
        local bar=Instance.new("Frame",appContent);bar.Size=UDim2.new(1,0,0,8);bar.BackgroundColor3=T.Card2;corner(bar,4)
        local fill=Instance.new("Frame",bar);fill.Size=UDim2.new(0,0,1,0);fill.BackgroundColor3=T.Green;corner(fill,4)
        cloneItems(selectedPlayer,function(done,batch,total)if done then isCloning=false;cloneBtn.Text="Clone Done";tween(cloneBtn,{BackgroundColor3=T.Green},0.3);fill:Destroy();showDynamicNotification("Clone complete!",T.Green)else local r=batch/total;tween(fill,{Size=UDim2.new(r,0,1,0)},0.3);cloneBtn.Text=("Cloning %d/%d"):format(batch,total)end end)
    end)
    for i,it in ipairs(items)do buildItemRow(appContent,it,i+10)end
end

-- PRESET (FIXED - Custom Name, Edit Name, Clone Working)
local function openPresetApp()
    -- ==================== SAVE SECTION ====================
    local saveCard = Instance.new("Frame", appContent)
    saveCard.Size = UDim2.new(1, 0, 0, 130)
    saveCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    saveCard.LayoutOrder = 0
    corner(saveCard, 14)
    stroke(saveCard, Color3.fromRGB(225, 225, 230), 1, 0.3)
    
    -- Shadow
    local saveShadow = Instance.new("Frame", saveCard)
    saveShadow.Size = UDim2.new(1, 6, 1, 6)
    saveShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    saveShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    saveShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    saveShadow.BackgroundTransparency = 0.94
    saveShadow.ZIndex = -1
    corner(saveShadow, 16)
    
    local saveTitle = Instance.new("TextLabel", saveCard)
    saveTitle.Size = UDim2.new(1, -24, 0, 22)
    saveTitle.Position = UDim2.new(0, 12, 0, 10)
    saveTitle.BackgroundTransparency = 1
    saveTitle.Text = "Save Current Player as Preset"
    saveTitle.TextColor3 = T.Text
    saveTitle.Font = Enum.Font.GothamBlack
    saveTitle.TextSize = 13
    saveTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local saveDesc = Instance.new("TextLabel", saveCard)
    saveDesc.Size = UDim2.new(1, -24, 0, 14)
    saveDesc.Position = UDim2.new(0, 12, 0, 32)
    saveDesc.BackgroundTransparency = 1
    saveDesc.Text = "Select a player first, then customize the preset name"
    saveDesc.TextColor3 = T.Text2
    saveDesc.Font = Enum.Font.Gotham
    saveDesc.TextSize = 9
    saveDesc.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Input nama preset
    local nameInput = Instance.new("TextBox", saveCard)
    nameInput.Size = UDim2.new(1, -24, 0, 32)
    nameInput.Position = UDim2.new(0, 12, 0, 50)
    nameInput.PlaceholderText = "Enter preset name..."
    nameInput.Text = selectedPlayer and (selectedPlayer.DisplayName .. " - " .. os.date("%d/%m %H:%M")) or ""
    nameInput.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
    nameInput.TextColor3 = T.Text
    nameInput.Font = Enum.Font.Gotham
    nameInput.TextSize = 12
    nameInput.ClearTextOnFocus = false
    corner(nameInput, 8)
    stroke(nameInput, Color3.fromRGB(220, 220, 225), 1, 0.3)
    
    -- Update nama otomatis saat player berubah
    if selectedPlayer then
        nameInput.Text = selectedPlayer.DisplayName .. " - " .. os.date("%d/%m %H:%M")
    end
    
    -- Tombol Save
    local saveBtn = Instance.new("TextButton", saveCard)
    saveBtn.Size = UDim2.new(1, -24, 0, 34)
    saveBtn.Position = UDim2.new(0, 12, 0, 88)
    saveBtn.BackgroundColor3 = T.Accent
    saveBtn.Text = "Save Preset"
    saveBtn.TextColor3 = T.OnAccent
    saveBtn.Font = Enum.Font.GothamBlack
    saveBtn.TextSize = 12
    saveBtn.AutoButtonColor = false
    corner(saveBtn, 8)
    pressFX(saveBtn)
    saveBtn.MouseButton1Click:Connect(function()
        if not selectedPlayer then
            showDynamicNotification("Select a player first!", T.Red)
            return
        end
        
        local items = getItems(selectedPlayer)
        if #items == 0 then
            showDynamicNotification("Player has no items!", T.Red)
            return
        end
        
        -- Ambil nama dari input, jika kosong gunakan default
        local presetName = nameInput.Text
        if presetName == "" or presetName:match("^%s*$") then
            presetName = selectedPlayer.DisplayName .. " - " .. os.date("%d/%m %H:%M")
        end
        
        local ids = {}
        for _, it in ipairs(items) do
            table.insert(ids, it.Value)
        end
        
        table.insert(presets, {
            name = presetName,
            ids = ids,
            date = os.date("%d/%m/%Y %H:%M"),
            favorite = false,
            playerName = selectedPlayer.DisplayName,
            playerId = selectedPlayer.UserId,
            itemCount = #ids
        })
        
        saveJSON(PRESET_FILE, presets)
        showDynamicNotification("Preset saved! (" .. #ids .. " items)", T.Green)
        nameInput.Text = ""
        refreshCurr()
    end)
    
    -- ==================== PRESETS LIST ====================
    if #presets == 0 then
        local emptyFrame = Instance.new("Frame", appContent)
        emptyFrame.Size = UDim2.new(1, 0, 0, 120)
        emptyFrame.BackgroundColor3 = Color3.fromRGB(248, 248, 250)
        emptyFrame.LayoutOrder = 1
        corner(emptyFrame, 14)
        stroke(emptyFrame, Color3.fromRGB(220, 220, 225), 1, 0.4)
        
        local emptyIcon = Instance.new("Frame", emptyFrame)
        emptyIcon.Size = UDim2.new(0, 40, 0, 40)
        emptyIcon.Position = UDim2.new(0.5, -20, 0, 25)
        emptyIcon.BackgroundTransparency = 1
        
        -- Box icon
        local boxIcon = Instance.new("Frame", emptyIcon)
        boxIcon.Size = UDim2.new(0, 34, 0, 24)
        boxIcon.Position = UDim2.new(0.5, -17, 0.48, 0)
        boxIcon.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
        corner(boxIcon, 7)
        
        local lidIcon = Instance.new("Frame", emptyIcon)
        lidIcon.Size = UDim2.new(0, 38, 0, 10)
        lidIcon.Position = UDim2.new(0.5, -19, 0.34, 0)
        lidIcon.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
        corner(lidIcon, 5)
        
        local emptyText = Instance.new("TextLabel", emptyFrame)
        emptyText.Size = UDim2.new(1, -20, 0, 30)
        emptyText.Position = UDim2.new(0, 10, 0, 72)
        emptyText.BackgroundTransparency = 1
        emptyText.Text = "No presets saved yet"
        emptyText.TextColor3 = Color3.fromRGB(140, 140, 150)
        emptyText.Font = Enum.Font.GothamBold
        emptyText.TextSize = 13
        emptyText.TextXAlignment = Enum.TextXAlignment.Center
        
        return
    end
    
    -- Sort presets: favorites first, then by date
    local sorted = {}
    for _, p in ipairs(presets) do
        table.insert(sorted, p)
    end
    table.sort(sorted, function(a, b)
        if a.favorite ~= b.favorite then return a.favorite end
        return (a.date or "") > (b.date or "")
    end)
    
    -- Preset counter
    local counterFrame = Instance.new("Frame", appContent)
    counterFrame.Size = UDim2.new(1, 0, 0, 22)
    counterFrame.BackgroundTransparency = 1
    counterFrame.LayoutOrder = 1
    
    local counterText = Instance.new("TextLabel", counterFrame)
    counterText.Size = UDim2.new(0, 120, 1, 0)
    counterText.BackgroundTransparency = 1
    counterText.Text = #sorted .. " preset" .. (#sorted ~= 1 and "s" or "")
    counterText.TextColor3 = T.Text2
    counterText.Font = Enum.Font.GothamBold
    counterText.TextSize = 10
    counterText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Render presets
    for i, p in ipairs(sorted) do
        local row = Instance.new("Frame", appContent)
        row.Size = UDim2.new(1, 0, 0, 100)
        row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        row.LayoutOrder = i + 1
        corner(row, 12)
        stroke(row, p.favorite and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(225, 225, 230), p.favorite and 1.5 or 1, p.favorite and 0.2 or 0.3)
        
        -- Shadow
        local rowShadow = Instance.new("Frame", row)
        rowShadow.Size = UDim2.new(1, 6, 1, 6)
        rowShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
        rowShadow.AnchorPoint = Vector2.new(0.5, 0.5)
        rowShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        rowShadow.BackgroundTransparency = 0.94
        rowShadow.ZIndex = -1
        corner(rowShadow, 14)
        
        -- Gold accent for favorites
        if p.favorite then
            local accent = Instance.new("Frame", row)
            accent.Size = UDim2.new(0, 3, 1, -16)
            accent.Position = UDim2.new(0, 8, 0, 8)
            accent.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
            corner(accent, 2)
        end
        
        -- Preset name
        local nameLbl = Instance.new("TextLabel", row)
        nameLbl.Size = UDim2.new(1, -24, 0, 24)
        nameLbl.Position = UDim2.new(0, 12, 0, 8)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = p.name
        nameLbl.TextColor3 = T.Text
        nameLbl.Font = Enum.Font.GothamBlack
        nameLbl.TextSize = 13
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        
        -- Info: item count + date + player name
        local infoLbl = Instance.new("TextLabel", row)
        infoLbl.Size = UDim2.new(1, -24, 0, 16)
        infoLbl.Position = UDim2.new(0, 12, 0, 32)
        infoLbl.BackgroundTransparency = 1
        infoLbl.Text = (p.itemCount or #p.ids) .. " items | " .. (p.date or "") .. (p.playerName and (" | " .. p.playerName) or "")
        infoLbl.TextColor3 = T.Text2
        infoLbl.Font = Enum.Font.Gotham
        infoLbl.TextSize = 9
        infoLbl.TextXAlignment = Enum.TextXAlignment.Left
        infoLbl.TextTruncate = Enum.TextTruncate.AtEnd
        
-- ============== ACTION BUTTONS ROW 1 ==============
        local btnRow1 = Instance.new("Frame", row)
        btnRow1.Size = UDim2.new(1, -24, 0, 26)
        btnRow1.Position = UDim2.new(0, 12, 0, 52)
        btnRow1.BackgroundTransparency = 1
        
        -- Clone button (FIXED)
        local cloneBtn = Instance.new("TextButton", btnRow1)
        cloneBtn.Size = UDim2.new(0, 75, 1, 0)
        cloneBtn.BackgroundColor3 = T.Green
        cloneBtn.Text = "Clone"
        cloneBtn.TextColor3 = T.OnAccent
        cloneBtn.Font = Enum.Font.GothamBold
        cloneBtn.TextSize = 9
        cloneBtn.AutoButtonColor = false
        corner(cloneBtn, 6)
        pressFX(cloneBtn)
        cloneBtn.MouseButton1Click:Connect(function()
            if #p.ids == 0 then
                showDynamicNotification("Preset has no items!", T.Red)
                return
            end
            
            -- Clone dengan progress tracking
            cloneBtn.Text = "Cloning..."
            cloneBtn.BackgroundColor3 = T.Gold
            
            -- Gunakan cloneItems dengan callback untuk tracking
            local totalBatches = math.ceil(#p.ids / CONFIG.CLONE_BATCH_SIZE)
            local currentBatch = 0
            
            -- Buat fungsi clone batch manual
            local function cloneBatch(batchIndex)
                if batchIndex > totalBatches then
                    -- Selesai
                    cloneBtn.Text = "Done!"
                    cloneBtn.BackgroundColor3 = T.Green
                    showDynamicNotification("Clone complete! (" .. #p.ids .. " items)", T.Green)
                    task.wait(1.5)
                    cloneBtn.Text = "Clone"
                    return
                end
                
                local startIdx = (batchIndex - 1) * CONFIG.CLONE_BATCH_SIZE + 1
                local endIdx = math.min(batchIndex * CONFIG.CLONE_BATCH_SIZE, #p.ids)
                local batchIds = {}
                
                for j = startIdx, endIdx do
                    table.insert(batchIds, p.ids[j])
                end
                
                fireHat(batchIds)
                cloneBtn.Text = "Clone " .. batchIndex .. "/" .. totalBatches
                
                task.delay(CONFIG.CLONE_DELAY, function()
                    cloneBatch(batchIndex + 1)
                end)
            end
            
            cloneBatch(1)
        end)
        
        -- Wear button (clone single batch)
        local wearBtn = Instance.new("TextButton", btnRow1)
        wearBtn.Size = UDim2.new(0, 75, 1, 0)
        wearBtn.Position = UDim2.new(0, 80, 0, 0)
        wearBtn.BackgroundColor3 = T.Accent
        wearBtn.Text = "Wear All"
        wearBtn.TextColor3 = T.OnAccent
        wearBtn.Font = Enum.Font.GothamBold
        wearBtn.TextSize = 9
        wearBtn.AutoButtonColor = false
        corner(wearBtn, 6)
        pressFX(wearBtn)
        wearBtn.MouseButton1Click:Connect(function()
            if #p.ids == 0 then
                showDynamicNotification("Preset has no items!", T.Red)
                return
            end
            fireHat(p.ids)
            showDynamicNotification("Wearing " .. #p.ids .. " items!", T.Green)
        end)
        
        -- ==================== ACTION BUTTONS ROW 2 ====================
        local btnRow2 = Instance.new("Frame", row)
        btnRow2.Size = UDim2.new(1, -24, 0, 24)
        btnRow2.Position = UDim2.new(0, 12, 0, 80)
        btnRow2.BackgroundTransparency = 1
        
        -- Favorite button
        local favBtn = Instance.new("TextButton", btnRow2)
        favBtn.Size = UDim2.new(0, 50, 1, 0)
        favBtn.BackgroundColor3 = p.favorite and T.Gold or Color3.fromRGB(245, 245, 248)
        favBtn.Text = p.favorite and "Unfav" or "Fav"
        favBtn.TextColor3 = p.favorite and T.OnAccent or T.Text2
        favBtn.Font = Enum.Font.GothamBold
        favBtn.TextSize = 8
        favBtn.AutoButtonColor = false
        corner(favBtn, 5)
        stroke(favBtn, T.Border, 1, 0.3)
        pressFX(favBtn)
        favBtn.MouseButton1Click:Connect(function()
            p.favorite = not p.favorite
            saveJSON(PRESET_FILE, presets)
            refreshCurr()
        end)
        
        -- Edit name button
        local editBtn = Instance.new("TextButton", btnRow2)
        editBtn.Size = UDim2.new(0, 50, 1, 0)
        editBtn.Position = UDim2.new(0, 55, 0, 0)
        editBtn.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
        editBtn.Text = "Rename"
        editBtn.TextColor3 = T.Text
        editBtn.Font = Enum.Font.GothamBold
        editBtn.TextSize = 8
        editBtn.AutoButtonColor = false
        corner(editBtn, 5)
        stroke(editBtn, T.Border, 1, 0.3)
        pressFX(editBtn)
        editBtn.MouseButton1Click:Connect(function()
            -- Tampilkan input dialog sederhana
            nameLbl.Visible = false
            
            local editInput = Instance.new("TextBox", row)
            editInput.Size = UDim2.new(1, -24, 0, 24)
            editInput.Position = UDim2.new(0, 12, 0, 8)
            editInput.Text = p.name
            editInput.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
            editInput.TextColor3 = T.Text
            editInput.Font = Enum.Font.GothamBold
            editInput.TextSize = 12
            editInput.ZIndex = 10
            corner(editInput, 6)
            stroke(editInput, T.Accent, 1.5, 0)
            
            editInput.FocusLost:Connect(function(enterPressed)
                local newName = editInput.Text
                if newName ~= "" and newName:match("%S") then
                    p.name = newName
                    saveJSON(PRESET_FILE, presets)
                    showDynamicNotification("Preset renamed!", T.Green)
                end
                editInput:Destroy()
                nameLbl.Visible = true
                nameLbl.Text = p.name
            end)
            
            editInput:CaptureFocus()
        end)
        
        -- Copy IDs button
        local copyBtn = Instance.new("TextButton", btnRow2)
        copyBtn.Size = UDim2.new(0, 50, 1, 0)
        copyBtn.Position = UDim2.new(0, 110, 0, 0)
        copyBtn.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
        copyBtn.Text = "Copy IDs"
        copyBtn.TextColor3 = T.Text
        copyBtn.Font = Enum.Font.GothamBold
        copyBtn.TextSize = 8
        copyBtn.AutoButtonColor = false
        corner(copyBtn, 5)
        stroke(copyBtn, T.Border, 1, 0.3)
        pressFX(copyBtn)
        copyBtn.MouseButton1Click:Connect(function()
            copyToClipboard(table.concat(p.ids, " "))
            showDynamicNotification("Copied " .. #p.ids .. " IDs!", T.Green)
        end)
        
        -- Delete button
        local delBtn = Instance.new("TextButton", btnRow2)
        delBtn.Size = UDim2.new(0, 50, 1, 0)
        delBtn.Position = UDim2.new(0, 165, 0, 0)
        delBtn.BackgroundColor3 = Color3.fromRGB(255, 230, 230)
        delBtn.Text = "Delete"
        delBtn.TextColor3 = T.Red
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 8
        delBtn.AutoButtonColor = false
        corner(delBtn, 5)
        stroke(delBtn, Color3.fromRGB(255, 200, 200), 1, 0.3)
        pressFX(delBtn)
        delBtn.MouseButton1Click:Connect(function()
            -- Konfirmasi delete
            delBtn.Text = "Sure?"
            task.wait(1)
            if delBtn.Text == "Sure?" then
                local idx = table.find(presets, p)
                if idx then
                    table.remove(presets, idx)
                end
                saveJSON(PRESET_FILE, presets)
                showDynamicNotification("Preset deleted!", T.Red)
                refreshCurr()
            end
        end)
    end
end

-- ITEMS
local function openItemsApp()
    if not selectedPlayer then local h=Instance.new("TextLabel",appContent);h.Size=UDim2.new(1,0,0,60);h.BackgroundTransparency=1;h.Text="Select a player first.";h.TextColor3=T.Text2;h.Font=Enum.Font.Gotham;h.TextSize=12;h.TextWrapped=true;return end
    local items=getItems(selectedPlayer)
    if #items==0 then local n=Instance.new("TextLabel",appContent);n.Size=UDim2.new(1,0,0,40);n.BackgroundTransparency=1;n.Text="No items.";n.TextColor3=T.Text2;n.Font=Enum.Font.Gotham;n.TextSize=12;return end
    for i,it in ipairs(items)do
        local row=Instance.new("Frame",appContent);row.Size=UDim2.new(1,0,0,52);row.BackgroundColor3=T.Card2;row.LayoutOrder=i;corner(row,10);stroke(row,T.Border,1,0.3)
        local thumb=Instance.new("ImageLabel",row);thumb.Size=UDim2.new(0,42,0,42);thumb.Position=UDim2.new(0,5,0.5,-21);thumb.BackgroundColor3=T.BG;thumb.Image="https://www.roblox.com/asset-thumbnail/image?assetId="..it.Value.."&width=100&height=100&format=png";thumb.ScaleType=Enum.ScaleType.Fit;corner(thumb,8);stroke(thumb,T.Border,1,0.3)
        local nameLbl=Instance.new("TextLabel",row);nameLbl.Size=UDim2.new(1,-180,0,18);nameLbl.Position=UDim2.new(0,52,0,6);nameLbl.BackgroundTransparency=1;nameLbl.Text=it.Label;nameLbl.TextColor3=T.Text;nameLbl.Font=Enum.Font.GothamBold;nameLbl.TextSize=12;nameLbl.TextXAlignment=Enum.TextXAlignment.Left
        local idLbl=Instance.new("TextLabel",row);idLbl.Size=UDim2.new(1,-180,0,16);idLbl.Position=UDim2.new(0,52,0,24);idLbl.BackgroundTransparency=1;idLbl.Text=it.Value;idLbl.TextColor3=T.Green;idLbl.Font=Enum.Font.Code;idLbl.TextSize=10;idLbl.TextXAlignment=Enum.TextXAlignment.Left
        local favBtn=Instance.new("TextButton",row);favBtn.Size=UDim2.new(0,60,0,28);favBtn.Position=UDim2.new(1,-66,0.5,-14);favBtn.BackgroundColor3=T.Accent;favBtn.Text="Fav";favBtn.TextColor3=T.OnAccent;favBtn.Font=Enum.Font.GothamBold;favBtn.TextSize=10;favBtn.AutoButtonColor=false;corner(favBtn,6);pressFX(favBtn)
        favBtn.MouseButton1Click:Connect(function()for _,fav in ipairs(favItems)do if tostring(fav.id)==it.Value then showDynamicNotification("Already in favorites",T.Red);return end end;table.insert(favItems,{id=it.Value,label=it.Label,date=os.date("%d/%m/%Y %H:%M")});persistFavItems();showDynamicNotification("Added to fav items",T.Green)end)
        local wearBtn=Instance.new("TextButton",row);wearBtn.Size=UDim2.new(0,60,0,28);wearBtn.Position=UDim2.new(1,-130,0.5,-14);wearBtn.BackgroundColor3=T.Green;wearBtn.Text="Wear";wearBtn.TextColor3=T.OnAccent;wearBtn.Font=Enum.Font.GothamBold;wearBtn.TextSize=10;wearBtn.AutoButtonColor=false;corner(wearBtn,6);pressFX(wearBtn)
        wearBtn.MouseButton1Click:Connect(function()fireHat({it.Value});showDynamicNotification("Wearing "..it.Value,T.Green)end)
    end
end

-- PROFILE
local function openProfileApp()
    if not selectedPlayer then local h=Instance.new("TextLabel",appContent);h.Size=UDim2.new(1,0,0,60);h.BackgroundTransparency=1;h.Text="Select a player first.";h.TextColor3=T.Text2;h.Font=Enum.Font.Gotham;h.TextSize=12;h.TextWrapped=true;return end
    local p=selectedPlayer
    local card=Instance.new("Frame",appContent);card.Size=UDim2.new(1,0,0,100);card.BackgroundColor3=T.Card2;corner(card,12);stroke(card,T.Accent,1.5,0.3)
    local av=Instance.new("ImageLabel",card);av.Size=UDim2.new(0,70,0,70);av.Position=UDim2.new(0,12,0.5,-35);av.BackgroundColor3=T.BG;av.Image="https://www.roblox.com/headshot-thumbnail/image?userId="..p.UserId.."&width=150&height=150&format=png";corner(av,100);stroke(av,T.Accent,2,0.2)
    local nameLbl=Instance.new("TextLabel",card);nameLbl.Size=UDim2.new(1,-94,0,24);nameLbl.Position=UDim2.new(0,90,0,10);nameLbl.BackgroundTransparency=1;nameLbl.Text=p.DisplayName;nameLbl.TextColor3=T.Text;nameLbl.Font=Enum.Font.GothamBlack;nameLbl.TextSize=16;nameLbl.TextXAlignment=Enum.TextXAlignment.Left
    local userLbl=Instance.new("TextLabel",card);userLbl.Size=UDim2.new(1,-94,0,18);userLbl.Position=UDim2.new(0,90,0,34);userLbl.BackgroundTransparency=1;userLbl.Text="@"..p.Name;userLbl.TextColor3=T.Text2;userLbl.Font=Enum.Font.Gotham;userLbl.TextSize=12;userLbl.TextXAlignment=Enum.TextXAlignment.Left
    local idLbl=Instance.new("TextLabel",card);idLbl.Size=UDim2.new(1,-94,0,16);idLbl.Position=UDim2.new(0,90,0,52);idLbl.BackgroundTransparency=1;idLbl.Text="ID: "..p.UserId;idLbl.TextColor3=Color3.fromRGB(100,100,120);idLbl.Font=Enum.Font.Code;idLbl.TextSize=10;idLbl.TextXAlignment=Enum.TextXAlignment.Left
    local items=getItems(p)
    local bodyCount,accCount=0,0;for _,it in ipairs(items)do if it.Type=="BODY"then bodyCount=bodyCount+1 else accCount=accCount+1 end end
    local statsLbl=Instance.new("TextLabel",card);statsLbl.Size=UDim2.new(1,-94,0,18);statsLbl.Position=UDim2.new(0,90,0,68);statsLbl.BackgroundTransparency=1;statsLbl.Text=bodyCount.." body, "..accCount.." accessories";statsLbl.TextColor3=T.Green;statsLbl.Font=Enum.Font.Gotham;statsLbl.TextSize=11;statsLbl.TextXAlignment=Enum.TextXAlignment.Left
    local cloneBtn=Instance.new("TextButton",appContent);cloneBtn.Size=UDim2.new(1,0,0,46);cloneBtn.BackgroundColor3=T.Accent;cloneBtn.Text="Clone Avatar";cloneBtn.TextColor3=T.OnAccent;cloneBtn.Font=Enum.Font.GothamBlack;cloneBtn.TextSize=14;cloneBtn.AutoButtonColor=false;corner(cloneBtn,10);pressFX(cloneBtn)
    cloneBtn.MouseButton1Click:Connect(function()if isCloning then return end;cloneItems(p,function(done)if done then showDynamicNotification("Clone complete!",T.Green)end end)end)
    local itemLbl=Instance.new("TextLabel",appContent);itemLbl.Size=UDim2.new(1,0,0,20);itemLbl.BackgroundTransparency=1;itemLbl.Text="Items ("..#items..")";itemLbl.TextColor3=T.Text2;itemLbl.Font=Enum.Font.GothamBold;itemLbl.TextSize=11;itemLbl.TextXAlignment=Enum.TextXAlignment.Left
    for i,it in ipairs(items)do buildItemRow(appContent,it,i)end
end

-- ==================== SETTINGS APP (UPGRADED + ESP TOGGLE) ====================
local function openSettingsApp()

    -- ── Helper: buat section header elegan ────────────────────────────────────
    local function makeSection(parent, order, icon, title, desc)
        local header = Instance.new("Frame", parent)
        header.Size = UDim2.new(1, 0, 0, 48)
        header.BackgroundTransparency = 1
        header.LayoutOrder = order

        local iconLbl = Instance.new("TextLabel", header)
        iconLbl.Size = UDim2.new(0, 28, 0, 28)
        iconLbl.Position = UDim2.new(0, 0, 0.5, -14)
        iconLbl.BackgroundColor3 = T.Accent
        iconLbl.BackgroundTransparency = 0.88
        iconLbl.Text = icon
        iconLbl.TextColor3 = T.Accent
        iconLbl.Font = Enum.Font.GothamBold
        iconLbl.TextSize = 14
        iconLbl.ZIndex = 2
        corner(iconLbl, 8)

        local titleLbl = Instance.new("TextLabel", header)
        titleLbl.Size = UDim2.new(1, -40, 0, 18)
        titleLbl.Position = UDim2.new(0, 36, 0, 8)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = title
        titleLbl.TextColor3 = T.Text
        titleLbl.Font = Enum.Font.GothamBlack
        titleLbl.TextSize = 13
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        local descLbl = Instance.new("TextLabel", header)
        descLbl.Size = UDim2.new(1, -40, 0, 14)
        descLbl.Position = UDim2.new(0, 36, 0, 28)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = desc
        descLbl.TextColor3 = T.Text2
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 9
        descLbl.TextXAlignment = Enum.TextXAlignment.Left

        return header
    end

    -- ── Helper: card kontainer elegan ─────────────────────────────────────────
    local function makeCard(parent, order, height)
        local card = Instance.new("Frame", parent)
        card.Size = UDim2.new(1, 0, 0, height)
        card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        card.BackgroundTransparency = 0.03
        card.LayoutOrder = order
        corner(card, 14)
        stroke(card, Color3.fromRGB(230, 230, 238), 1, 0.2)
        return card
    end

    -- ── Helper: row toggle di dalam card ──────────────────────────────────────
    local function makeToggleRow(card, yPos, icon, title, subtitle, currentVal, callback)
        local row = Instance.new("Frame", card)
        row.Size = UDim2.new(1, -24, 0, 48)
        row.Position = UDim2.new(0, 12, 0, yPos)
        row.BackgroundTransparency = 1

        local iconBg = Instance.new("Frame", row)
        iconBg.Size = UDim2.new(0, 36, 0, 36)
        iconBg.Position = UDim2.new(0, 0, 0.5, -18)
        iconBg.BackgroundColor3 = T.Accent
        iconBg.BackgroundTransparency = 0.85
        corner(iconBg, 10)

        local iconLbl = Instance.new("TextLabel", iconBg)
        iconLbl.Size = UDim2.new(1, 0, 1, 0)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text = icon
        iconLbl.TextColor3 = T.Accent
        iconLbl.Font = Enum.Font.GothamBold
        iconLbl.TextSize = 16

        local titleLbl = Instance.new("TextLabel", row)
        titleLbl.Size = UDim2.new(1, -100, 0, 18)
        titleLbl.Position = UDim2.new(0, 44, 0, 6)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = title
        titleLbl.TextColor3 = T.Text
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 12
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        local subLbl = Instance.new("TextLabel", row)
        subLbl.Size = UDim2.new(1, -100, 0, 14)
        subLbl.Position = UDim2.new(0, 44, 0, 26)
        subLbl.BackgroundTransparency = 1
        subLbl.Text = subtitle
        subLbl.TextColor3 = T.Text2
        subLbl.Font = Enum.Font.Gotham
        subLbl.TextSize = 9
        subLbl.TextXAlignment = Enum.TextXAlignment.Left

        local toggle = buildToggle(row, currentVal, callback)
        toggle.Position = UDim2.new(1, -52, 0.5, -13)

        return row
    end

    -- ── Helper: divider tipis antar row ───────────────────────────────────────
    local function makeDivider(parent, yPos)
        local div = Instance.new("Frame", parent)
        div.Size = UDim2.new(1, -56, 0, 1)
        div.Position = UDim2.new(0, 44, 0, yPos)
        div.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
        div.BackgroundTransparency = 0.5
        div.BorderSizePixel = 0
        return div
    end

    -- ================================================================
    -- ① DEVELOPER PROFILE CARD (upgraded)
    -- ================================================================
    local devFrame = makeCard(appContent, 0, 220)
    devFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    devFrame.BackgroundTransparency = 0

    local devGradient = Instance.new("UIGradient", devFrame)
    devGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 48)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 22))
    })
    devGradient.Rotation = 145

    -- Glow line atas
    local glowLine = Instance.new("Frame", devFrame)
    glowLine.Size = UDim2.new(1, 0, 0, 2)
    glowLine.BackgroundColor3 = T.Accent
    glowLine.BorderSizePixel = 0
    glowLine.ZIndex = 5

    local glowLineGrad = Instance.new("UIGradient", glowLine)
    glowLineGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 48)),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(80, 140, 255)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(120, 80, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 48))
    })

    -- Badge DEV
    local badgeFrame = Instance.new("Frame", devFrame)
    badgeFrame.Size = UDim2.new(0, 80, 0, 20)
    badgeFrame.Position = UDim2.new(0, 14, 0, 14)
    badgeFrame.BackgroundColor3 = T.Accent
    badgeFrame.BackgroundTransparency = 0.8
    badgeFrame.ZIndex = 5
    corner(badgeFrame, 10)
    stroke(badgeFrame, T.Accent, 1, 0.5)

    local badgeText = Instance.new("TextLabel", badgeFrame)
    badgeText.Size = UDim2.new(1, 0, 1, 0)
    badgeText.BackgroundTransparency = 1
    badgeText.Text = "✦ DEVELOPER"
    badgeText.TextColor3 = Color3.fromRGB(160, 200, 255)
    badgeText.Font = Enum.Font.GothamBold
    badgeText.TextSize = 8
    badgeText.ZIndex = 6

    -- Avatar ring
    local avatarRing = Instance.new("Frame", devFrame)
    avatarRing.Size = UDim2.new(0, 80, 0, 80)
    avatarRing.Position = UDim2.new(0, 16, 0, 46)
    avatarRing.BackgroundColor3 = T.Accent
    avatarRing.BackgroundTransparency = 0.6
    avatarRing.ZIndex = 5
    corner(avatarRing, 100)

    local av = Instance.new("ImageLabel", avatarRing)
    av.Size = UDim2.new(0, 68, 0, 68)
    av.Position = UDim2.new(0.5, -34, 0.5, -34)
    av.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    av.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    av.ZIndex = 6
    corner(av, 100)

    local onlineDot = Instance.new("Frame", avatarRing)
    onlineDot.Size = UDim2.new(0, 14, 0, 14)
    onlineDot.Position = UDim2.new(1, -10, 1, -10)
    onlineDot.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
    onlineDot.ZIndex = 10
    corner(onlineDot, 100)
    stroke(onlineDot, Color3.fromRGB(18, 18, 28), 2.5, 0)

    -- Nama & info
    local nameLbl = Instance.new("TextLabel", devFrame)
    nameLbl.Size = UDim2.new(1, -110, 0, 26)
    nameLbl.Position = UDim2.new(0, 106, 0, 48)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = "SHEEN"
    nameLbl.TextColor3 = Color3.new(1, 1, 1)
    nameLbl.Font = Enum.Font.GothamBlack
    nameLbl.TextSize = 19
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 5

    local verifiedBadge = Instance.new("Frame", devFrame)
    verifiedBadge.Size = UDim2.new(0, 90, 0, 16)
    verifiedBadge.Position = UDim2.new(0, 106, 0, 78)
    verifiedBadge.BackgroundTransparency = 1
    verifiedBadge.ZIndex = 5

    local checkIcon = Instance.new("TextLabel", verifiedBadge)
    checkIcon.Size = UDim2.new(0, 16, 1, 0)
    checkIcon.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
    checkIcon.Text = "✓"
    checkIcon.TextColor3 = Color3.new(1, 1, 1)
    checkIcon.Font = Enum.Font.GothamBlack
    checkIcon.TextSize = 9
    checkIcon.ZIndex = 6
    corner(checkIcon, 100)

    local verText = Instance.new("TextLabel", verifiedBadge)
    verText.Size = UDim2.new(1, -20, 1, 0)
    verText.Position = UDim2.new(0, 20, 0, 0)
    verText.BackgroundTransparency = 1
    verText.Text = "Verified Creator"
    verText.TextColor3 = Color3.fromRGB(140, 190, 255)
    verText.Font = Enum.Font.Gotham
    verText.TextSize = 9
    verText.TextXAlignment = Enum.TextXAlignment.Left
    verText.ZIndex = 5

    local descLbl = Instance.new("TextLabel", devFrame)
    descLbl.Size = UDim2.new(1, -110, 0, 36)
    descLbl.Position = UDim2.new(0, 106, 0, 100)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = "Creator of Phone ID Viewer\nAdvanced Roblox Scripting"
    descLbl.TextColor3 = Color3.fromRGB(160, 160, 185)
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextSize = 10
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.TextWrapped = true
    descLbl.ZIndex = 5

    -- Stats bar
    local statsBar = Instance.new("Frame", devFrame)
    statsBar.Size = UDim2.new(1, -20, 0, 38)
    statsBar.Position = UDim2.new(0, 10, 0, 174)
    statsBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    statsBar.BackgroundTransparency = 0.93
    statsBar.ZIndex = 5
    corner(statsBar, 10)

    for i, stat in ipairs({{value="v.0.5",label="Version"},{value="10/08/2026",label="Released"},{value="FE",label="Secure"}}) do
        local sf = Instance.new("Frame", statsBar)
        sf.Size = UDim2.new(1/3, 0, 1, 0)
        sf.Position = UDim2.new((i-1)/3, 0, 0, 0)
        sf.BackgroundTransparency = 1
        sf.ZIndex = 6

        if i > 1 then
            local sep = Instance.new("Frame", sf)
            sep.Size = UDim2.new(0, 1, 0.5, 0)
            sep.Position = UDim2.new(0, 0, 0.25, 0)
            sep.BackgroundColor3 = Color3.fromRGB(255,255,255)
            sep.BackgroundTransparency = 0.85
            sep.ZIndex = 6
        end

        local sv = Instance.new("TextLabel", sf)
        sv.Size = UDim2.new(1, 0, 0, 18); sv.Position = UDim2.new(0,0,0,4)
        sv.BackgroundTransparency=1; sv.Text=stat.value
        sv.TextColor3=Color3.new(1,1,1); sv.Font=Enum.Font.GothamBold; sv.TextSize=11
        sv.ZIndex=7

        local sl = Instance.new("TextLabel", sf)
        sl.Size = UDim2.new(1, 0, 0, 12); sl.Position = UDim2.new(0,0,0,22)
        sl.BackgroundTransparency=1; sl.Text=stat.label
        sl.TextColor3=Color3.fromRGB(130,130,155); sl.Font=Enum.Font.Gotham; sl.TextSize=8
        sl.ZIndex=7
    end

    local profileBtn = Instance.new("TextButton", devFrame)
    profileBtn.Size = UDim2.new(0, 80, 0, 26)
    profileBtn.Position = UDim2.new(1, -90, 0, 184)
    profileBtn.BackgroundColor3 = T.Accent
    profileBtn.Text = "Profile ↗"
    profileBtn.TextColor3 = Color3.new(1,1,1)
    profileBtn.Font = Enum.Font.GothamBold
    profileBtn.TextSize = 10
    profileBtn.AutoButtonColor = false
    profileBtn.ZIndex = 6
    corner(profileBtn, 8)
    pressFX(profileBtn)
    profileBtn.MouseButton1Click:Connect(function()
        copyToClipboard("https://www.roblox.com/users/9179272580/profile")
        showDynamicNotification("Profile link copied!", T.Green)
    end)

    -- Fixed profile thumbnail (public Roblox User ID)
    task.spawn(function()
        pcall(function()
            local uid = "9179272580"
            local info = HttpService:JSONDecode(HttpService:GetAsync("https://users.roblox.com/v1/users/" .. uid))
            nameLbl.Text = "SHEEN"
            descLbl.Text = info.description or "Creator of Phone ID Viewer\nAdvanced Roblox Scripting"
            av.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..uid.."&width=150&height=150&format=png"
        end)
    end)

    -- ================================================================
    -- ① SECTION: APPEARANCE
    -- ================================================================
    makeSection(appContent, 1, "🎨", "Appearance", "Customize how your phone looks")

    -- Theme card
    local themeFrame = makeCard(appContent, 2, 130)

    local thTitle = Instance.new("TextLabel", themeFrame)
    thTitle.Size=UDim2.new(1,-24,0,20); thTitle.Position=UDim2.new(0,12,0,10)
    thTitle.BackgroundTransparency=1; thTitle.Text="Background Theme"
    thTitle.TextColor3=T.Text; thTitle.Font=Enum.Font.GothamBold; thTitle.TextSize=13
    thTitle.TextXAlignment=Enum.TextXAlignment.Left

    local colors = {
        {color=Color3.fromRGB(255,255,255), name="Light"},
        {color=Color3.fromRGB(30,30,42),    name="Dark"},
        {color=Color3.fromRGB(200,220,255), name="Blue"},
        {color=Color3.fromRGB(255,235,210), name="Warm"}
    }
    for i, td in ipairs(colors) do
        local btn = Instance.new("TextButton", themeFrame)
        btn.Size=UDim2.new(0,62,0,52); btn.Position=UDim2.new(0, 12+(i-1)*68, 0, 64)
        btn.BackgroundColor3=td.color
        btn.Text=td.name
        btn.TextColor3=(td.name=="Dark") and Color3.new(1,1,1) or T.Text
        btn.Font=Enum.Font.GothamBold; btn.TextSize=9
        btn.AutoButtonColor=false
        corner(btn, 10); stroke(btn, T.Border, 1, 0.2); pressFX(btn)
        btn.MouseButton1Click:Connect(function()
            appSettings.bgColor=td.color; appSettings.bgGradient=(td.name=="Light")
            persistSettings()
            homeWall.BackgroundColor3=td.color
            local existGrad = homeWall:FindFirstChildOfClass("UIGradient")
            if existGrad then existGrad:Destroy() end
            if appSettings.bgGradient then
                gradient(homeWall, ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(220,220,240)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(250,250,255))
                }), 135)
            end
            phone.BackgroundColor3=td.color
            showDynamicNotification("Theme: "..td.name, T.Green)
        end)
    end

    -- Toggles card: Glow + Opacity dalam satu card
    local appearCard = makeCard(appContent, 3, 160)

    makeToggleRow(appearCard, 4, "✦", "Phone Glow Effect", "Colored border around phone frame",
        appSettings.glowEnabled,
        function(val)
            appSettings.glowEnabled = val; persistSettings()
            phoneStroke.Transparency = val and 0.5 or 0.15
        end
    )

    makeDivider(appearCard, 58)

    -- Opacity slider dalam card yang sama
    local opTitle2 = Instance.new("TextLabel", appearCard)
    opTitle2.Size=UDim2.new(1,-24,0,16); opTitle2.Position=UDim2.new(0,12,0,66)
    opTitle2.BackgroundTransparency=1; opTitle2.Text="Phone Opacity"
    opTitle2.TextColor3=T.Text; opTitle2.Font=Enum.Font.GothamBold; opTitle2.TextSize=12
    opTitle2.TextXAlignment=Enum.TextXAlignment.Left

    local opVal2 = Instance.new("TextLabel", appearCard)
    opVal2.Size=UDim2.new(0,60,0,16); opVal2.Position=UDim2.new(1,-72,0,66)
    opVal2.BackgroundTransparency=1
    opVal2.Text=math.floor((appSettings.phoneOpacity or 1)*100).."%"
    opVal2.TextColor3=T.Accent; opVal2.Font=Enum.Font.GothamBold; opVal2.TextSize=12
    opVal2.TextXAlignment=Enum.TextXAlignment.Right

    local opTrack = Instance.new("TextButton", appearCard)
    opTrack.Size=UDim2.new(1,-24,0,24); opTrack.Position=UDim2.new(0,12,0,90)
    opTrack.BackgroundColor3=Color3.fromRGB(235,235,242); opTrack.Text=""
    opTrack.AutoButtonColor=false; corner(opTrack, 12)

    local opFill2 = Instance.new("Frame", opTrack)
    opFill2.Size=UDim2.new(appSettings.phoneOpacity or 1,0,1,0)
    opFill2.BackgroundColor3=T.Accent; corner(opFill2, 12)

    local opKnob = Instance.new("Frame", opTrack)
    opKnob.Size=UDim2.new(0,20,0,20); opKnob.AnchorPoint=Vector2.new(0.5,0.5)
    local kx = (appSettings.phoneOpacity or 1)
    opKnob.Position=UDim2.new(kx,0,0.5,0)
    opKnob.BackgroundColor3=Color3.new(1,1,1); corner(opKnob,100)
    stroke(opKnob, T.Accent, 2, 0)

    local function setOp(val)
        val=math.clamp(val,0.3,1)
        appSettings.phoneOpacity=val; persistSettings()
        opFill2.Size=UDim2.new(val,0,1,0)
        opKnob.Position=UDim2.new(val,0,0.5,0)
        opVal2.Text=math.floor(val*100).."%"
        phone.BackgroundTransparency=1-val
    end

    opTrack.MouseButton1Down:Connect(function()
        local con
        con=RunService.RenderStepped:Connect(function()
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                con:Disconnect(); return
            end
            local mx=UserInputService:GetMouseLocation().X
            local ax=opTrack.AbsolutePosition.X; local aw=opTrack.AbsoluteSize.X
            if aw<=0 then aw=1 end
            setOp(0.3+(mx-ax)/aw*0.7)
        end)
    end)

    local opReminder = Instance.new("TextLabel", appearCard)
    opReminder.Size=UDim2.new(1,-24,0,14); opReminder.Position=UDim2.new(0,12,0,120)
    opReminder.BackgroundTransparency=1; opReminder.Text="Drag slider to adjust (30%–100%)"
    opReminder.TextColor3=T.Text2; opReminder.Font=Enum.Font.Gotham; opReminder.TextSize=8
    opReminder.TextXAlignment=Enum.TextXAlignment.Left


    -- ================================================================
    -- ② SECTION: PREFERENCES
    -- ================================================================
    makeSection(appContent, 4, "⚙", "Preferences", "General app settings")

    local prefCard = makeCard(appContent, 5, 166)

    makeToggleRow(prefCard, 4,  "🔔", "Toast Notifications", "Show popup notifications",
        appSettings.toastEnabled,
        function(val) appSettings.toastEnabled=val; persistSettings() end
    )
    makeDivider(prefCard, 58)
    makeToggleRow(prefCard, 62, "🕐", "12H Clock Format",   "Toggle 12h / 24h time display",
        appSettings.clockFormat=="12",
        function(val) appSettings.clockFormat=val and"12"or"24"; persistSettings() end
    )
    makeDivider(prefCard, 116)
    makeToggleRow(prefCard, 120, "🔉", "Button Sounds",      "Play sound on button press",
        appSettings.buttonSounds,
        function(val) appSettings.buttonSounds=val; persistSettings() end
    )

    -- ================================================================
    -- ③ RESET BUTTON
    -- ================================================================
    local resetBtn = Instance.new("TextButton", appContent)
    resetBtn.Size=UDim2.new(1,0,0,46)
    resetBtn.BackgroundColor3=Color3.fromRGB(255,240,240)
    resetBtn.Text="↺  Reset All Settings"
    resetBtn.TextColor3=T.Red
    resetBtn.Font=Enum.Font.GothamBold; resetBtn.TextSize=12
    resetBtn.AutoButtonColor=false; resetBtn.LayoutOrder=6
    corner(resetBtn, 12); stroke(resetBtn, Color3.fromRGB(255,200,200), 1, 0.3)
    pressFX(resetBtn)
    resetBtn.MouseButton1Click:Connect(function()
        for k,v in pairs(defaults) do appSettings[k]=v end
        persistSettings(); updateBackgroundMusic()
        phoneStroke.Transparency=0.5; phone.BackgroundTransparency=0
        homeWall.BackgroundColor3=Color3.fromRGB(240,240,250)
        local g=homeWall:FindFirstChildOfClass("UIGradient")
        if not g then
            gradient(homeWall, ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(220,220,240)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(250,250,255))
            }), 135)
        end
        showDynamicNotification("Settings reset to default!", T.Gold)
        refreshCurr()
    end)

end

-- ================= AVATAR & ITEMS APP (FINAL FIXED - OUTFITS & AVATARS WORKING) =================-- ================= AVATAR & ITEMS APP (FINAL FIXED - OUTFITS & AVATARS WORKING) =================
local avatarItemsSelectedTab = "Favorites"

local function openAvatarItemsApp()
    -- ==================== HEADER ====================
    local headerCard = Instance.new("Frame", appContent)
    headerCard.Size = UDim2.new(1, 0, 0, 44)
    headerCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    headerCard.LayoutOrder = 0
    corner(headerCard, 14)
    stroke(headerCard, Color3.fromRGB(225, 225, 230), 1, 0.3)
    
    local headerTitle = Instance.new("TextLabel", headerCard)
    headerTitle.Size = UDim2.new(1, -24, 0, 20)
    headerTitle.Position = UDim2.new(0, 12, 0, 4)
    headerTitle.BackgroundTransparency = 1
    headerTitle.Text = "Player Assets"
    headerTitle.TextColor3 = T.Text
    headerTitle.Font = Enum.Font.GothamBlack
    headerTitle.TextSize = 14
    headerTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local headerSub = Instance.new("TextLabel", headerCard)
    headerSub.Size = UDim2.new(1, -24, 0, 14)
    headerSub.Position = UDim2.new(0, 12, 0, 24)
    headerSub.BackgroundTransparency = 1
    headerSub.Text = selectedPlayer and ("Target: " .. selectedPlayer.DisplayName .. " | @" .. selectedPlayer.Name) or "No player selected"
    headerSub.TextColor3 = T.Text2
    headerSub.Font = Enum.Font.Gotham
    headerSub.TextSize = 8
    headerSub.TextXAlignment = Enum.TextXAlignment.Left
    
    -- ==================== TABS ====================
    local tabFrame = Instance.new("Frame", appContent)
    tabFrame.Size = UDim2.new(1, 0, 0, 34)
    tabFrame.BackgroundColor3 = Color3.fromRGB(242, 242, 247)
    tabFrame.LayoutOrder = 1
    corner(tabFrame, 17)
    stroke(tabFrame, Color3.fromRGB(200, 200, 210), 1, 0.3)
    
    local tabPadding = Instance.new("UIPadding", tabFrame)
    tabPadding.PaddingLeft = UDim.new(0, 3)
    tabPadding.PaddingRight = UDim.new(0, 3)
    tabPadding.PaddingTop = UDim.new(0, 3)
    tabPadding.PaddingBottom = UDim.new(0, 3)
    
    local tabs = {"Favorites", "Worn", "Outfits", "Avatars"}
    
    for i, t in ipairs(tabs) do
        local btn = Instance.new("TextButton", tabFrame)
        btn.Size = UDim2.new(1/4, -4, 1, 0)
        btn.Position = UDim2.new((i-1)/4, 2, 0, 0)
        btn.Text = t
        btn.AutoButtonColor = false
        btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        btn.BackgroundTransparency = 1
        btn.TextColor3 = Color3.fromRGB(100, 100, 100)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 7
        corner(btn, 14)
        
        if t == avatarItemsSelectedTab then
            btn.BackgroundColor3 = T.Accent
            btn.BackgroundTransparency = 0
            btn.TextColor3 = Color3.new(1, 1, 1)
        end
        
        btn.MouseButton1Click:Connect(function()
            avatarItemsSelectedTab = t
            refreshCurr()
        end)
    end
    
    -- ==================== CONTENT ====================
    local contentFrame = Instance.new("Frame", appContent)
    contentFrame.Size = UDim2.new(1, 0, 0, 0)
    contentFrame.AutomaticSize = Enum.AutomaticSize.Y
    contentFrame.BackgroundTransparency = 1
    contentFrame.LayoutOrder = 2
    
    if not selectedPlayer then
        local emptyCard = Instance.new("Frame", contentFrame)
        emptyCard.Size = UDim2.new(1, 0, 0, 90)
        emptyCard.BackgroundColor3 = Color3.fromRGB(248, 248, 250)
        corner(emptyCard, 14)
        stroke(emptyCard, Color3.fromRGB(220, 220, 225), 1, 0.3)
        
        local emptyText = Instance.new("TextLabel", emptyCard)
        emptyText.Size = UDim2.new(1, 0, 1, 0)
        emptyText.BackgroundTransparency = 1
        emptyText.Text = "Select a player first!\nGo to Players > Select player"
        emptyText.TextColor3 = Color3.fromRGB(140, 140, 150)
        emptyText.Font = Enum.Font.GothamBold
        emptyText.TextSize = 12
        emptyText.TextWrapped = true
        return
    end
    
    -- Loading minimal
    local loadingFrame = Instance.new("Frame", contentFrame)
    loadingFrame.Size = UDim2.new(1, 0, 0, 35)
    loadingFrame.BackgroundColor3 = Color3.fromRGB(248, 248, 250)
    corner(loadingFrame, 10)
    stroke(loadingFrame, Color3.fromRGB(220, 220, 225), 1, 0.3)
    
    local loadingText = Instance.new("TextLabel", loadingFrame)
    loadingText.Size = UDim2.new(1, 0, 1, 0)
    loadingText.BackgroundTransparency = 1
    loadingText.Text = "Loading..."
    loadingText.TextColor3 = T.Text2
    loadingText.Font = Enum.Font.Gotham
    loadingText.TextSize = 10
    
    -- HTTP helper - coba semua method
    local function httpGet(url)
        -- Method 1: syn.request
        local ok, result = pcall(function()
            if syn and syn.request then
                local resp = syn.request({Url = url, Method = "GET", Headers = {["Content-Type"] = "application/json"}})
                if resp and resp.Body and resp.Body ~= "" and resp.Body ~= "null" then
                    return resp.Body
                end
            end
            error("no syn")
        end)
        if ok and result then return result end
        
        -- Method 2: game:HttpGet
        ok, result = pcall(function()
            local data = game:HttpGet(url)
            if data and data ~= "" and data ~= "null" then return data end
            error("empty")
        end)
        if ok and result then return result end
        
        -- Method 3: http_request
        ok, result = pcall(function()
            if http_request then
                local resp = http_request({Url = url, Method = "GET"})
                if resp and resp.Body and resp.Body ~= "" then return resp.Body end
            end
            error("no http_request")
        end)
        if ok and result then return result end
        
        -- Method 4: request
        ok, result = pcall(function()
            if request then
                local resp = request({Url = url, Method = "GET"})
                if resp and resp.Body and resp.Body ~= "" then return resp.Body end
            end
            error("no request")
        end)
        if ok and result then return result end
        
        return nil
    end
    
    -- Clone batch
    local function cloneWithBatch(ids, callback)
        local batchSize = CONFIG.CLONE_BATCH_SIZE or 5
        local delayTime = CONFIG.CLONE_DELAY or 6
        local totalBatches = math.ceil(#ids / batchSize)
        local currentBatch = 0
        
        local function processNextBatch()
            currentBatch = currentBatch + 1
            if currentBatch > totalBatches then
                if callback then callback(true) end
                return
            end
            
            local startIdx = (currentBatch - 1) * batchSize + 1
            local endIdx = math.min(currentBatch * batchSize, #ids)
            local batchIds = {}
            
            for j = startIdx, endIdx do
                table.insert(batchIds, ids[j])
            end
            
            fireHat(batchIds)
            
            if callback then
                callback(nil, currentBatch, totalBatches)
            end
            
            task.delay(delayTime, processNextBatch)
        end
        
        processNextBatch()
    end
    
    -- Check if item is fav
    local function isItemFaved(itemType, itemId)
        for _, fav in ipairs(favAvatarItems) do
            if fav.itemType == itemType and fav.itemId == itemId then
                return true
            end
        end
        return false
    end
    
    -- Toggle fav
    local function toggleFav(itemType, itemId, itemName, itemValue, extraData)
        for i, fav in ipairs(favAvatarItems) do
            if fav.itemType == itemType and fav.itemId == itemId then
                table.remove(favAvatarItems, i)
                persistFavAvatarItems()
                return false
            end
        end
        
        table.insert(favAvatarItems, {
            itemType = itemType,
            itemId = itemId,
            name = itemName,
            value = itemValue,
            extraData = extraData or {},
            date = os.date("%d/%m/%Y %H:%M")
        })
        persistFavAvatarItems()
        return true
    end
    
    -- Fetch data (coroutine = no lag)
    coroutine.wrap(function()
        local userId = selectedPlayer.UserId
        local displayItems = {}
        
        -- ============ TAB: FAVORITES ============
        if avatarItemsSelectedTab == "Favorites" then
            for _, fav in ipairs(favAvatarItems) do
                local item = {
                    Label = fav.name or fav.value,
                    Value = fav.value,
                    Type = fav.itemType,
                    IsFav = true
                }
                
                if fav.itemType == "OUTFIT" then
                    item.OutfitId = fav.itemId
                    item.OutfitAssets = fav.extraData.assets or {}
                elseif fav.itemType == "AVATAR" then
                    item.AvatarId = fav.itemId
                    item.AvatarAssets = fav.extraData.assets or {}
                end
                
                table.insert(displayItems, item)
            end
        end
        
        -- ============ TAB: WORN ============
        if avatarItemsSelectedTab == "Worn" then
            local items = getItems(selectedPlayer)
            displayItems = items
        end
        
        -- ============ TAB: OUTFITS ============
        if avatarItemsSelectedTab == "Outfits" then
            local raw = httpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/outfits?page=1&itemsPerPage=30")
            
            if raw then
                local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
                if ok and data and data.data and #data.data > 0 then
                    for _, outfit in ipairs(data.data) do
                        if outfit.name and outfit.id then
                            table.insert(displayItems, {
                                Label = outfit.name,
                                Value = "OUTFIT:" .. outfit.id,
                                Type = "OUTFIT",
                                OutfitId = outfit.id,
                                OutfitAssets = {},
                                IsFav = isItemFaved("OUTFIT", outfit.id)
                            })
                        end
                    end
                end
            end
            
            -- Fallback: current outfit untuk diri sendiri
            if #displayItems == 0 and selectedPlayer == LocalPlayer then
                local charItems = getItems(selectedPlayer)
                if #charItems > 0 then
                    local ids = {}
                    for _, it in ipairs(charItems) do
                        table.insert(ids, it.Value)
                    end
                    table.insert(displayItems, {
                        Label = "Current Outfit",
                        Value = "OUTFIT:current",
                        Type = "OUTFIT",
                        OutfitId = "current",
                        OutfitAssets = ids,
                        IsFav = isItemFaved("OUTFIT", "current")
                    })
                end
            end
        end
        
        -- ============ TAB: AVATARS ============
        if avatarItemsSelectedTab == "Avatars" then
            local raw = httpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/avatars")
            
            if raw then
                local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
                if ok and data and data.data and #data.data > 0 then
                    for _, av in ipairs(data.data) do
                        if av.name and av.id then
                            table.insert(displayItems, {
                                Label = av.name,
                                Value = "AVATAR:" .. av.id,
                                Type = "AVATAR",
                                AvatarId = av.id,
                                IsFav = isItemFaved("AVATAR", av.id)
                            })
                        end
                    end
                end
            end
            
            -- Fallback: current avatar
            if #displayItems == 0 and selectedPlayer == LocalPlayer then
                table.insert(displayItems, {
                    Label = "Current Avatar",
                    Value = "AVATAR:current",
                    Type = "AVATAR",
                    AvatarId = "current",
                    AvatarAssets = {},
                    IsFav = isItemFaved("AVATAR", "current")
                })
            end
        end
        
        -- Hapus loading
        loadingFrame:Destroy()
        
        -- ============ EMPTY STATE ============
        if #displayItems == 0 then
            local emptyCard = Instance.new("Frame", contentFrame)
            emptyCard.Size = UDim2.new(1, 0, 0, 100)
            emptyCard.BackgroundColor3 = Color3.fromRGB(248, 248, 250)
            corner(emptyCard, 14)
            stroke(emptyCard, Color3.fromRGB(220, 220, 225), 1, 0.3)
            
            local emptyMessages = {
                Favorites = "No favorites yet\nAdd outfits/avatars using the star button!",
                Worn = "Player is not wearing any items",
                Outfits = "No outfits found for this player\n(API may be restricted)",
                Avatars = "No avatars found for this player\n(API may be restricted)"
            }
            
            local emptyText = Instance.new("TextLabel", emptyCard)
            emptyText.Size = UDim2.new(1, 0, 1, 0)
            emptyText.BackgroundTransparency = 1
            emptyText.Text = emptyMessages[avatarItemsSelectedTab] or "No items found"
            emptyText.TextColor3 = Color3.fromRGB(140, 140, 150)
            emptyText.Font = Enum.Font.GothamBold
            emptyText.TextSize = 12
            emptyText.TextWrapped = true
            emptyText.TextXAlignment = Enum.TextXAlignment.Center
            return
        end
        
        -- ============ COUNTER ============
        local counterFrame = Instance.new("Frame", contentFrame)
        counterFrame.Size = UDim2.new(1, 0, 0, 14)
        counterFrame.BackgroundTransparency = 1
        
        local counterText = Instance.new("TextLabel", counterFrame)
        counterText.Size = UDim2.new(0, 150, 1, 0)
        counterText.BackgroundTransparency = 1
        counterText.Text = #displayItems .. " items"
        counterText.TextColor3 = T.Text2
        counterText.Font = Enum.Font.GothamBold
        counterText.TextSize = 8
        counterText.TextXAlignment = Enum.TextXAlignment.Left
        
        -- ============ GRID 2 KOLOM ============
        local grid = Instance.new("UIGridLayout", contentFrame)
        grid.CellSize = UDim2.new(0.5, -5, 0, 155)
        grid.CellPadding = UDim2.new(0, 8, 0, 8)
        grid.FillDirection = Enum.FillDirection.Horizontal
        grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
        grid.SortOrder = Enum.SortOrder.LayoutOrder
        
        local typeColors = {
            OUTFIT = Color3.fromRGB(180, 130, 255),
            AVATAR = Color3.fromRGB(100, 150, 255),
            BODY = Color3.fromRGB(255, 130, 80),
            ACC = Color3.fromRGB(80, 200, 80),
            FAVORITE = Color3.fromRGB(255, 180, 50)
        }
        
        local typeLabels = {
            OUTFIT = "OUTFIT",
            AVATAR = "AVATAR",
            BODY = "BODY",
            ACC = "ACC",
            FAVORITE = "FAV"
        }
        
        -- ============ RENDER ============
        for i, item in ipairs(displayItems) do
            local card = Instance.new("Frame", contentFrame)
            card.Size = UDim2.new(0, 0, 0, 155)
            card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            card.LayoutOrder = i
            corner(card, 12)
            
            if item.IsFav then
                stroke(card, Color3.fromRGB(255, 200, 50), 2, 0)
            else
                stroke(card, Color3.fromRGB(225, 225, 230), 1, 0.3)
            end
            
            -- Type badge
            local badgeColor = typeColors[item.Type] or T.Accent
            local typeBadge = Instance.new("Frame", card)
            typeBadge.Size = UDim2.new(0, 40, 0, 12)
            typeBadge.Position = UDim2.new(0, 4, 0, 4)
            typeBadge.BackgroundColor3 = badgeColor
            typeBadge.BackgroundTransparency = 0.8
            corner(typeBadge, 6)
            
            local typeText = Instance.new("TextLabel", typeBadge)
            typeText.Size = UDim2.new(1, 0, 1, 0)
            typeText.BackgroundTransparency = 1
            typeText.Text = typeLabels[item.Type] or item.Type
            typeText.TextColor3 = badgeColor
            typeText.Font = Enum.Font.GothamBold
            typeText.TextSize = 7
            
            -- Star button (untuk Outfit & Avatar)
            if item.Type == "OUTFIT" or item.Type == "AVATAR" then
                local starBtn = Instance.new("TextButton", card)
                starBtn.Size = UDim2.new(0, 20, 0, 20)
                starBtn.Position = UDim2.new(1, -24, 0, 2)
                starBtn.BackgroundColor3 = item.IsFav and T.Gold or Color3.fromRGB(240, 240, 240)
                starBtn.Text = item.IsFav and "★" or "☆"
                starBtn.TextColor3 = item.IsFav and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 150)
                starBtn.Font = Enum.Font.GothamBlack
                starBtn.TextSize = 12
                starBtn.AutoButtonColor = false
                corner(starBtn, 10)
                pressFX(starBtn)
                
                starBtn.MouseButton1Click:Connect(function()
                    local itemId = item.Type == "OUTFIT" and item.OutfitId or item.AvatarId
                    local extraData = {}
                    
                    if item.Type == "OUTFIT" then
                        extraData.assets = item.OutfitAssets or {}
                    else
                        extraData.assets = item.AvatarAssets or {}
                    end
                    
                    local isNowFav = toggleFav(item.Type, itemId, item.Label, item.Value, extraData)
                    
                    if isNowFav then
                        starBtn.Text = "★"
                        starBtn.BackgroundColor3 = T.Gold
                        starBtn.TextColor3 = Color3.new(1, 1, 1)
                        item.IsFav = true
                        stroke(card, Color3.fromRGB(255, 200, 50), 2, 0)
                        showDynamicNotification("Added to favorites!", T.Gold)
                    else
                        starBtn.Text = "☆"
                        starBtn.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
                        starBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
                        item.IsFav = false
                        stroke(card, Color3.fromRGB(225, 225, 230), 1, 0.3)
                        showDynamicNotification("Removed from favorites!", T.Text2)
                    end
                end)
            end
            
            -- Image
            local imgBox = Instance.new("Frame", card)
            imgBox.Size = UDim2.new(0, 60, 0, 60)
            imgBox.Position = UDim2.new(0.5, -30, 0, 20)
            imgBox.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
            corner(imgBox, 10)
            stroke(imgBox, Color3.fromRGB(215, 215, 220), 1, 0.3)
            
            local img = Instance.new("ImageLabel", imgBox)
            img.Size = UDim2.new(1, -4, 1, -4)
            img.Position = UDim2.new(0.5, 0, 0.5, 0)
            img.AnchorPoint = Vector2.new(0.5, 0.5)
            img.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
            
            -- Thumbnail
            if item.Type == "AVATAR" then
                if item.AvatarId == "current" then
                    img.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. userId .. "&width=150&height=150&format=png"
                else
                    img.Image = "https://www.roblox.com/outfit-thumbnail/image?userOutfitId=" .. item.AvatarId .. "&width=150&height=150&format=png"
                end
            elseif item.Type == "OUTFIT" then
                if item.OutfitId == "current" then
                    img.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. userId .. "&width=150&height=150&format=png"
                else
                    img.Image = "https://www.roblox.com/outfit-thumbnail/image?userOutfitId=" .. item.OutfitId .. "&width=150&height=150&format=png"
                end
            else
                img.Image = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. item.Value .. "&width=150&height=150&format=png"
            end
            img.ScaleType = Enum.ScaleType.Fit
            corner(img, 7)
            
            -- Name
            local nameLbl = Instance.new("TextLabel", card)
            nameLbl.Size = UDim2.new(1, -10, 0, 20)
            nameLbl.Position = UDim2.new(0, 5, 0, 84)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = item.Label or item.Value
            nameLbl.TextColor3 = T.Text
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextSize = 8
            nameLbl.TextXAlignment = Enum.TextXAlignment.Center
            nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            nameLbl.TextWrapped = true
            
            -- ID
            local idText = item.Value
            if item.Type == "AVATAR" then idText = "AV:" .. item.AvatarId
            elseif item.Type == "OUTFIT" then idText = "OUT:" .. item.OutfitId end
            
            local idLbl = Instance.new("TextLabel", card)
            idLbl.Size = UDim2.new(1, -10, 0, 10)
            idLbl.Position = UDim2.new(0, 5, 0, 104)
            idLbl.BackgroundTransparency = 1
            idLbl.Text = idText
            idLbl.TextColor3 = T.Text2
            idLbl.Font = Enum.Font.Code
            idLbl.TextSize = 7
            idLbl.TextXAlignment = Enum.TextXAlignment.Center
            idLbl.TextTruncate = Enum.TextTruncate.AtEnd
            
            -- Buttons
            local btnRow = Instance.new("Frame", card)
            btnRow.Size = UDim2.new(1, -10, 0, 26)
            btnRow.Position = UDim2.new(0, 5, 0, 118)
            btnRow.BackgroundTransparency = 1
            
            if item.Type == "OUTFIT" then
                -- CLONE
                local cloneBtn = Instance.new("TextButton", btnRow)
                cloneBtn.Size = UDim2.new(0, 62, 1, 0)
                cloneBtn.BackgroundColor3 = T.Green
                cloneBtn.Text = "Clone"
                cloneBtn.TextColor3 = T.OnAccent
                cloneBtn.Font = Enum.Font.GothamBold
                cloneBtn.TextSize = 8
                cloneBtn.AutoButtonColor = false
                corner(cloneBtn, 5)
                pressFX(cloneBtn)
                
                cloneBtn.MouseButton1Click:Connect(function()
                    cloneBtn.Text = "..."
                    cloneBtn.BackgroundColor3 = T.Gold
                    
                    local idsToClone = item.OutfitAssets or {}
                    
                    if #idsToClone == 0 and item.OutfitId ~= "current" then
                        local detailRaw = httpGet("https://avatar.roblox.com/v1/outfits/" .. item.OutfitId .. "/details")
                        if detailRaw then
                            local ok, detail = pcall(function() return HttpService:JSONDecode(detailRaw) end)
                            if ok and detail and detail.assets then
                                for _, asset in ipairs(detail.assets) do
                                    if asset.id and type(asset.id) == "number" then
                                        table.insert(idsToClone, tostring(asset.id))
                                    end
                                end
                                item.OutfitAssets = idsToClone
                            end
                        end
                    elseif #idsToClone == 0 and item.OutfitId == "current" then
                        local charItems = getItems(selectedPlayer)
                        for _, it in ipairs(charItems) do
                            table.insert(idsToClone, it.Value)
                        end
                        item.OutfitAssets = idsToClone
                    end
                    
                    if #idsToClone > 0 then
                        cloneWithBatch(idsToClone, function(done, batch, total)
                            if done then
                                cloneBtn.Text = "Done!"
                                cloneBtn.BackgroundColor3 = T.Green
                                showDynamicNotification("Clone complete! (" .. #idsToClone .. " items)", T.Green)
                                task.wait(1.5)
                                cloneBtn.Text = "Clone"
                                cloneBtn.BackgroundColor3 = T.Green
                            else
                                cloneBtn.Text = batch .. "/" .. total
                            end
                        end)
                    else
                        cloneBtn.Text = "Empty!"
                        cloneBtn.BackgroundColor3 = T.Red
                        task.wait(1.5)
                        cloneBtn.Text = "Clone"
                        cloneBtn.BackgroundColor3 = T.Green
                    end
                end)
                
                -- Copy
                local copyBtn = Instance.new("TextButton", btnRow)
                copyBtn.Size = UDim2.new(0, 48, 1, 0)
                copyBtn.Position = UDim2.new(0, 66, 0, 0)
                copyBtn.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
                copyBtn.Text = "Copy"
                copyBtn.TextColor3 = T.Text
                copyBtn.Font = Enum.Font.GothamBold
                copyBtn.TextSize = 8
                copyBtn.AutoButtonColor = false
                corner(copyBtn, 5)
                stroke(copyBtn, T.Border, 1, 0.3)
                pressFX(copyBtn)
                copyBtn.MouseButton1Click:Connect(function()
                    copyToClipboard(tostring(item.OutfitId))
                    showDynamicNotification("Copied!", T.Green)
                end)
                
            elseif item.Type == "AVATAR" then
                -- WEAR ALL
                local wearBtn = Instance.new("TextButton", btnRow)
                wearBtn.Size = UDim2.new(0, 62, 1, 0)
                wearBtn.BackgroundColor3 = T.Accent
                wearBtn.Text = "Wear All"
                wearBtn.TextColor3 = T.OnAccent
                wearBtn.Font = Enum.Font.GothamBold
                wearBtn.TextSize = 8
                wearBtn.AutoButtonColor = false
                corner(wearBtn, 5)
                pressFX(wearBtn)
                
                wearBtn.MouseButton1Click:Connect(function()
                    wearBtn.Text = "..."
                    wearBtn.BackgroundColor3 = T.Gold
                    
                    local idsToWear = item.AvatarAssets or {}
                    
                    if #idsToWear == 0 and item.AvatarId ~= "current" then
                        local detailRaw = httpGet("https://avatar.roblox.com/v1/avatars/" .. item.AvatarId .. "/details")
                        if detailRaw then
                            local ok, detail = pcall(function() return HttpService:JSONDecode(detailRaw) end)
                            if ok and detail and detail.assets then
                                for _, asset in ipairs(detail.assets) do
                                    if asset.id and type(asset.id) == "number" then
                                        table.insert(idsToWear, tostring(asset.id))
                                    end
                                end
                                item.AvatarAssets = idsToWear
                            end
                        end
                    elseif #idsToWear == 0 and item.AvatarId == "current" then
                        local charItems = getItems(selectedPlayer)
                        for _, it in ipairs(charItems) do
                            table.insert(idsToWear, it.Value)
                        end
                        item.AvatarAssets = idsToWear
                    end
                    
                    if #idsToWear > 0 then
                        fireHat(idsToWear)
                        task.wait(0.3)
                        resetCharacter()
                        wearBtn.Text = "Done!"
                        wearBtn.BackgroundColor3 = T.Green
                        showDynamicNotification("Avatar applied!", T.Green)
                        task.wait(1.5)
                        wearBtn.Text = "Wear All"
                        wearBtn.BackgroundColor3 = T.Accent
                    else
                        wearBtn.Text = "Fail!"
                        wearBtn.BackgroundColor3 = T.Red
                        task.wait(1.5)
                        wearBtn.Text = "Wear All"
                        wearBtn.BackgroundColor3 = T.Accent
                    end
                end)
                
                -- Copy
                local copyBtn = Instance.new("TextButton", btnRow)
                copyBtn.Size = UDim2.new(0, 48, 1, 0)
                copyBtn.Position = UDim2.new(0, 66, 0, 0)
                copyBtn.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
                copyBtn.Text = "Copy"
                copyBtn.TextColor3 = T.Text
                copyBtn.Font = Enum.Font.GothamBold
                copyBtn.TextSize = 8
                copyBtn.AutoButtonColor = false
                corner(copyBtn, 5)
                stroke(copyBtn, T.Border, 1, 0.3)
                pressFX(copyBtn)
                copyBtn.MouseButton1Click:Connect(function()
                    copyToClipboard(tostring(item.AvatarId))
                    showDynamicNotification("Copied!", T.Green)
                end)
                
            else
                -- WEAR single
                local wearBtn = Instance.new("TextButton", btnRow)
                wearBtn.Size = UDim2.new(0, 50, 1, 0)
                wearBtn.BackgroundColor3 = T.Accent
                wearBtn.Text = "Wear"
                wearBtn.TextColor3 = T.OnAccent
                wearBtn.Font = Enum.Font.GothamBold
                wearBtn.TextSize = 8
                wearBtn.AutoButtonColor = false
                corner(wearBtn, 5)
                pressFX(wearBtn)
                wearBtn.MouseButton1Click:Connect(function()
                    fireHat({item.Value})
                    wearBtn.Text = "OK"
                    wearBtn.BackgroundColor3 = T.Green
                    task.wait(1)
                    wearBtn.Text = "Wear"
                    wearBtn.BackgroundColor3 = T.Accent
                end)
                
                -- Copy
                local copyBtn = Instance.new("TextButton", btnRow)
                copyBtn.Size = UDim2.new(0, 48, 1, 0)
                copyBtn.Position = UDim2.new(0, 54, 0, 0)
                copyBtn.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
                copyBtn.Text = "Copy"
                copyBtn.TextColor3 = T.Text
                copyBtn.Font = Enum.Font.GothamBold
                copyBtn.TextSize = 8
                copyBtn.AutoButtonColor = false
                corner(copyBtn, 5)
                stroke(copyBtn, T.Border, 1, 0.3)
                pressFX(copyBtn)
                copyBtn.MouseButton1Click:Connect(function()
                    copyToClipboard(item.Value)
                    showDynamicNotification("Copied!", T.Green)
                end)
                
                -- Remove from fav (tab Favorites)
                if item.Type == "FAVORITE" then
                    local delBtn = Instance.new("TextButton", card)
                    delBtn.Size = UDim2.new(0, 16, 0, 26)
                    delBtn.Position = UDim2.new(0, 2, 0, 118)
                    delBtn.BackgroundColor3 = Color3.fromRGB(255, 220, 220)
                    delBtn.Text = "X"
                    delBtn.TextColor3 = T.Red
                    delBtn.Font = Enum.Font.GothamBlack
                    delBtn.TextSize = 9
                    delBtn.AutoButtonColor = false
                    corner(delBtn, 5)
                    pressFX(delBtn)
                    delBtn.MouseButton1Click:Connect(function()
                        for j, fav in ipairs(favAvatarItems) do
                            if fav.itemId == item.OutfitId or fav.itemId == item.AvatarId or fav.value == item.Value then
                                table.remove(favAvatarItems, j)
                                persistFavAvatarItems()
                                showDynamicNotification("Removed!", T.Red)
                                refreshCurr()
                                break
                            end
                        end
                    end)
                end
            end
        end
    end)()
end

-- ================= PLAYER LOOKUP APP (FULL - WITH TABS) =================
local playerLookupData = {} -- Simpan data player yang dicari

local function openPlayerLookupApp()
    -- ==================== HEADER ====================
    local headerCard = Instance.new("Frame", appContent)
    headerCard.Size = UDim2.new(1, 0, 0, 46)
    headerCard.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
    headerCard.LayoutOrder = 0
    corner(headerCard, 14)
    
    local headerAccent = Instance.new("Frame", headerCard)
    headerAccent.Size = UDim2.new(1, 0, 0, 2)
    headerAccent.BackgroundColor3 = Color3.fromRGB(80, 150, 255)
    corner(headerAccent, 1)
    
    local headerTitle = Instance.new("TextLabel", headerCard)
    headerTitle.Size = UDim2.new(1, -24, 0, 22)
    headerTitle.Position = UDim2.new(0, 12, 0, 4)
    headerTitle.BackgroundTransparency = 1
    headerTitle.Text = "Player Lookup"
    headerTitle.TextColor3 = Color3.new(1, 1, 1)
    headerTitle.Font = Enum.Font.GothamBlack
    headerTitle.TextSize = 14
    headerTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local headerSub = Instance.new("TextLabel", headerCard)
    headerSub.Size = UDim2.new(1, -24, 0, 14)
    headerSub.Position = UDim2.new(0, 12, 0, 26)
    headerSub.BackgroundTransparency = 1
    headerSub.Text = playerLookupData.username and ("Viewing: @" .. (playerLookupData.username or "")) or "Search any player"
    headerSub.TextColor3 = Color3.fromRGB(160, 160, 180)
    headerSub.Font = Enum.Font.Gotham
    headerSub.TextSize = 8
    headerSub.TextXAlignment = Enum.TextXAlignment.Left
    
    -- ==================== SEARCH BAR ====================
    local searchCard = Instance.new("Frame", appContent)
    searchCard.Size = UDim2.new(1, 0, 0, 52)
    searchCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    searchCard.LayoutOrder = 1
    corner(searchCard, 14)
    stroke(searchCard, Color3.fromRGB(225, 225, 230), 1, 0.3)
    
    local searchInput = Instance.new("TextBox", searchCard)
    searchInput.Size = UDim2.new(1, -100, 0, 32)
    searchInput.Position = UDim2.new(0, 10, 0, 10)
    searchInput.PlaceholderText = "Enter Roblox username..."
    searchInput.Text = playerLookupData.username or ""
    searchInput.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
    searchInput.TextColor3 = T.Text
    searchInput.Font = Enum.Font.Gotham
    searchInput.TextSize = 13
    searchInput.ClearTextOnFocus = false
    corner(searchInput, 8)
    stroke(searchInput, Color3.fromRGB(220, 220, 225), 1, 0.3)
    
    local searchBtn = Instance.new("TextButton", searchCard)
    searchBtn.Size = UDim2.new(0, 80, 0, 32)
    searchBtn.Position = UDim2.new(1, -90, 0, 10)
    searchBtn.BackgroundColor3 = Color3.fromRGB(80, 150, 255)
    searchBtn.Text = "Search"
    searchBtn.TextColor3 = Color3.new(1, 1, 1)
    searchBtn.Font = Enum.Font.GothamBlack
    searchBtn.TextSize = 12
    searchBtn.AutoButtonColor = false
    corner(searchBtn, 8)
    pressFX(searchBtn)
    
    -- ==================== TABS ====================
    local tabFrame = Instance.new("Frame", appContent)
    tabFrame.Size = UDim2.new(1, 0, 0, 36)
    tabFrame.BackgroundColor3 = Color3.fromRGB(242, 242, 247)
    tabFrame.LayoutOrder = 2
    corner(tabFrame, 18)
    stroke(tabFrame, Color3.fromRGB(200, 200, 210), 1, 0.3)
    
    local tabPadding = Instance.new("UIPadding", tabFrame)
    tabPadding.PaddingLeft = UDim.new(0, 3)
    tabPadding.PaddingRight = UDim.new(0, 3)
    tabPadding.PaddingTop = UDim.new(0, 3)
    tabPadding.PaddingBottom = UDim.new(0, 3)
    
    local lookupSelectedTab = playerLookupData.selectedTab or "Items"
    local tabs = {"Profile", "Items", "Outfits"}
    
    for i, t in ipairs(tabs) do
        local btn = Instance.new("TextButton", tabFrame)
        btn.Size = UDim2.new(1/3, -4, 1, 0)
        btn.Position = UDim2.new((i-1)/3, 2, 0, 0)
        btn.Text = t
        btn.AutoButtonColor = false
        btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        btn.BackgroundTransparency = 1
        btn.TextColor3 = Color3.fromRGB(100, 100, 100)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 8
        corner(btn, 14)
        
        if t == lookupSelectedTab then
            btn.BackgroundColor3 = T.Accent
            btn.BackgroundTransparency = 0
            btn.TextColor3 = Color3.new(1, 1, 1)
        end
        
        btn.MouseButton1Click:Connect(function()
            lookupSelectedTab = t
            playerLookupData.selectedTab = t
            refreshCurr()
        end)
    end
    
    -- ==================== CONTENT ====================
    local contentFrame = Instance.new("Frame", appContent)
    contentFrame.Size = UDim2.new(1, 0, 0, 0)
    contentFrame.AutomaticSize = Enum.AutomaticSize.Y
    contentFrame.BackgroundTransparency = 1
    contentFrame.LayoutOrder = 3
    
    -- ==================== HTTP HELPER ====================
    local function httpGet(url)
        local ok, result = pcall(function()
            if syn and syn.request then
                local resp = syn.request({Url = url, Method = "GET"})
                if resp and resp.Body and resp.Body ~= "" and resp.Body ~= "null" then return resp.Body end
            end
            error("no syn")
        end)
        if ok and result then return result end
        
        ok, result = pcall(function()
            local data = game:HttpGet(url)
            if data and data ~= "" and data ~= "null" then return data end
            error("empty")
        end)
        if ok and result then return result end
        
        return nil
    end
    
    -- ==================== SEARCH FUNCTION ====================
    local function searchPlayer(username)
        playerLookupData = {username = username, selectedTab = "Items"}
        
        -- Clear content
        for _, child in ipairs(contentFrame:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") then
                child:Destroy()
            end
        end
        
        if username == "" or not username:match("%S") then
            showDynamicNotification("Enter a username!", T.Red)
            return
        end
        
        local loadingCard = Instance.new("Frame", contentFrame)
        loadingCard.Size = UDim2.new(1, 0, 0, 40)
        loadingCard.BackgroundColor3 = Color3.fromRGB(248, 248, 250)
        corner(loadingCard, 10)
        stroke(loadingCard, Color3.fromRGB(220, 220, 225), 1, 0.3)
        
        local loadingText = Instance.new("TextLabel", loadingCard)
        loadingText.Size = UDim2.new(1, 0, 1, 0)
        loadingText.BackgroundTransparency = 1
        loadingText.Text = "Searching..."
        loadingText.TextColor3 = T.Text2
        loadingText.Font = Enum.Font.Gotham
        loadingText.TextSize = 10
        
        task.spawn(function()
            local userId = nil
            local displayName = username
            
            -- Method 1: Search API
            local searchRaw = httpGet("https://users.roblox.com/v1/users/search?keyword=" .. HttpService:UrlEncode(username) .. "&limit=10")
            if searchRaw then
                local ok, data = pcall(function() return HttpService:JSONDecode(searchRaw) end)
                if ok and data and data.data and #data.data > 0 then
                    for _, user in ipairs(data.data) do
                        if user.name:lower() == username:lower() or (user.displayName and user.displayName:lower() == username:lower()) then
                            userId = user.id
                            displayName = user.displayName or user.name
                            break
                        end
                    end
                    if not userId then
                        userId = data.data[1].id
                        displayName = data.data[1].displayName or data.data[1].name
                    end
                end
            end
            
            -- Method 2: Direct API
            if not userId then
                local userRaw = httpGet("https://api.roblox.com/users/get-by-username?username=" .. HttpService:UrlEncode(username))
                if userRaw then
                    local ok, data = pcall(function() return HttpService:JSONDecode(userRaw) end)
                    if ok and data and data.Id and data.Id > 0 then
                        userId = data.Id
                        displayName = data.Username or username
                    end
                end
            end
            
            -- Method 3: POST API
            if not userId then
                local postRaw = nil
                pcall(function()
                    if syn and syn.request then
                        local resp = syn.request({
                            Url = "https://users.roblox.com/v1/usernames/users",
                            Method = "POST",
                            Headers = {["Content-Type"] = "application/json"},
                            Body = HttpService:JSONEncode({usernames = {username}})
                        })
                        if resp and resp.Body then postRaw = resp.Body end
                    end
                end)
                if postRaw then
                    local ok, data = pcall(function() return HttpService:JSONDecode(postRaw) end)
                    if ok and data and data.data and #data.data > 0 then
                        userId = data.data[1].id
                        displayName = data.data[1].displayName or data.data[1].name or username
                    end
                end
            end
            
            loadingCard:Destroy()
            
            if not userId then
                local notFoundCard = Instance.new("Frame", contentFrame)
                notFoundCard.Size = UDim2.new(1, 0, 0, 90)
                notFoundCard.BackgroundColor3 = Color3.fromRGB(248, 248, 250)
                corner(notFoundCard, 14)
                stroke(notFoundCard, Color3.fromRGB(220, 220, 225), 1, 0.3)
                
                local notFoundText = Instance.new("TextLabel", notFoundCard)
                notFoundText.Size = UDim2.new(1, 0, 1, 0)
                notFoundText.BackgroundTransparency = 1
                notFoundText.Text = "Player not found!\n@" .. username
                notFoundText.TextColor3 = Color3.fromRGB(140, 140, 150)
                notFoundText.Font = Enum.Font.GothamBlack
                notFoundText.TextSize = 13
                notFoundText.TextWrapped = true
                notFoundText.TextXAlignment = Enum.TextXAlignment.Center
                return
            end
            
            -- Simpan data
            playerLookupData.userId = userId
            playerLookupData.displayName = displayName
            playerLookupData.username = username
            
            showDynamicNotification("Found: " .. displayName, T.Green)
            refreshCurr()
        end)
    end
    
    -- ==================== RENDER PROFILE TAB ====================
    if lookupSelectedTab == "Profile" and playerLookupData.userId then
        local userId = playerLookupData.userId
        local displayName = playerLookupData.displayName
        
        -- Profile Card
        local profileCard = Instance.new("Frame", contentFrame)
        profileCard.Size = UDim2.new(1, 0, 0, 90)
        profileCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        corner(profileCard, 14)
        stroke(profileCard, Color3.fromRGB(80, 150, 255), 2, 0.3)
        
        local avatarImg = Instance.new("ImageLabel", profileCard)
        avatarImg.Size = UDim2.new(0, 64, 0, 64)
        avatarImg.Position = UDim2.new(0, 12, 0.5, -32)
        avatarImg.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
        avatarImg.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. userId .. "&width=150&height=150&format=png"
        corner(avatarImg, 100)
        stroke(avatarImg, Color3.fromRGB(80, 150, 255), 2, 0)
        
        local nameLbl = Instance.new("TextLabel", profileCard)
        nameLbl.Size = UDim2.new(1, -100, 0, 24)
        nameLbl.Position = UDim2.new(0, 84, 0, 10)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = displayName
        nameLbl.TextColor3 = T.Text
        nameLbl.Font = Enum.Font.GothamBlack
        nameLbl.TextSize = 17
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        
        local idLbl = Instance.new("TextLabel", profileCard)
        idLbl.Size = UDim2.new(1, -100, 0, 16)
        idLbl.Position = UDim2.new(0, 84, 0, 34)
        idLbl.BackgroundTransparency = 1
        idLbl.Text = "ID: " .. userId
        idLbl.TextColor3 = T.Text2
        idLbl.Font = Enum.Font.Code
        idLbl.TextSize = 10
        idLbl.TextXAlignment = Enum.TextXAlignment.Left
        
        local isOnline = Players:GetPlayerByUserId(userId) ~= nil
        local onlineDot = Instance.new("Frame", profileCard)
        onlineDot.Size = UDim2.new(0, 10, 0, 10)
        onlineDot.Position = UDim2.new(0, 84, 0, 54)
        onlineDot.BackgroundColor3 = isOnline and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(150, 150, 150)
        corner(onlineDot, 100)
        
        local onlineText = Instance.new("TextLabel", profileCard)
        onlineText.Size = UDim2.new(0, 60, 0, 14)
        onlineText.Position = UDim2.new(0, 98, 0, 52)
        onlineText.BackgroundTransparency = 1
        onlineText.Text = isOnline and "IN GAME" or "OFFLINE"
        onlineText.TextColor3 = isOnline and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(150, 150, 150)
        onlineText.Font = Enum.Font.GothamBold
        onlineText.TextSize = 9
        onlineText.TextXAlignment = Enum.TextXAlignment.Left
        
        -- Quick buttons
        local quickRow = Instance.new("Frame", contentFrame)
        quickRow.Size = UDim2.new(1, 0, 0, 36)
        quickRow.BackgroundTransparency = 1
        
        local targetBtn = Instance.new("TextButton", quickRow)
        targetBtn.Size = UDim2.new(0, 85, 1, 0)
        targetBtn.BackgroundColor3 = Color3.fromRGB(80, 150, 255)
        targetBtn.Text = "Set Target"
        targetBtn.TextColor3 = T.OnAccent
        targetBtn.Font = Enum.Font.GothamBold
        targetBtn.TextSize = 10
        targetBtn.AutoButtonColor = false
        corner(targetBtn, 8)
        pressFX(targetBtn)
        targetBtn.MouseButton1Click:Connect(function()
            if isOnline then
                selectedPlayer = Players:GetPlayerByUserId(userId)
                showDynamicNotification("Target: " .. displayName, T.Green)
            else
                showDynamicNotification("Not in server!", T.Red)
            end
        end)
        
        local cloneBtn = Instance.new("TextButton", quickRow)
        cloneBtn.Size = UDim2.new(0, 85, 1, 0)
        cloneBtn.Position = UDim2.new(0, 93, 0, 0)
        cloneBtn.BackgroundColor3 = T.Green
        cloneBtn.Text = "Clone"
        cloneBtn.TextColor3 = T.OnAccent
        cloneBtn.Font = Enum.Font.GothamBold
        cloneBtn.TextSize = 10
        cloneBtn.AutoButtonColor = false
        corner(cloneBtn, 8)
        pressFX(cloneBtn)
        cloneBtn.MouseButton1Click:Connect(function()
            cloneBtn.Text = "..."
            cloneFromUserId(userId, function(done)
                if done then
                    cloneBtn.Text = "Done!"
                    showDynamicNotification("Clone complete!", T.Green)
                else
                    cloneBtn.Text = "Fail!"
                end
                task.wait(1.5)
                cloneBtn.Text = "Clone"
            end)
        end)
        
        local copyBtn = Instance.new("TextButton", quickRow)
        copyBtn.Size = UDim2.new(0, 85, 1, 0)
        copyBtn.Position = UDim2.new(0, 186, 0, 0)
        copyBtn.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
        copyBtn.Text = "Copy ID"
        copyBtn.TextColor3 = T.Text
        copyBtn.Font = Enum.Font.GothamBold
        copyBtn.TextSize = 10
        copyBtn.AutoButtonColor = false
        corner(copyBtn, 8)
        stroke(copyBtn, T.Border, 1, 0.3)
        pressFX(copyBtn)
        copyBtn.MouseButton1Click:Connect(function()
            copyToClipboard(tostring(userId))
            showDynamicNotification("ID copied!", T.Green)
        end)
    end
    
    -- ==================== RENDER ITEMS TAB ====================
    if lookupSelectedTab == "Items" and playerLookupData.userId then
        local userId = playerLookupData.userId
        
        local loadingText = Instance.new("TextLabel", contentFrame)
        loadingText.Size = UDim2.new(1, 0, 0, 24)
        loadingText.BackgroundTransparency = 1
        loadingText.Text = "Loading items..."
        loadingText.TextColor3 = T.Text2
        loadingText.Font = Enum.Font.Gotham
        loadingText.TextSize = 10
        
        task.spawn(function()
            local allItems = {}
            
            -- Fetch avatar items
            local avatarRaw = httpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/avatar")
            if avatarRaw then
                local ok, data = pcall(function() return HttpService:JSONDecode(avatarRaw) end)
                if ok and data and data.assets then
                    for _, asset in ipairs(data.assets) do
                        table.insert(allItems, {
                            id = asset.id,
                            name = asset.name or "Unknown",
                            itemType = "BODY",
                            typeColor = Color3.fromRGB(255, 130, 80)
                        })
                    end
                end
            end
            
            -- Fetch currently wearing
            local wearRaw = httpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/currently-wearing")
            if wearRaw then
                local ok, data = pcall(function() return HttpService:JSONDecode(wearRaw) end)
                if ok and data and data.assetIds then
                    for _, assetId in ipairs(data.assetIds) do
                        local isDup = false
                        for _, existing in ipairs(allItems) do
                            if tonumber(existing.id) == assetId then
                                existing.itemType = "BODY/ACC"
                                existing.typeColor = Color3.fromRGB(80, 200, 80)
                                isDup = true
                                break
                            end
                        end
                        if not isDup then
                            table.insert(allItems, {
                                id = assetId,
                                name = "Acc " .. assetId,
                                itemType = "ACC",
                                typeColor = Color3.fromRGB(80, 200, 80)
                            })
                        end
                    end
                end
            end
            
            loadingText:Destroy()
            
            if #allItems == 0 then
                local emptyText = Instance.new("TextLabel", contentFrame)
                emptyText.Size = UDim2.new(1, 0, 0, 40)
                emptyText.BackgroundTransparency = 1
                emptyText.Text = "No items found"
                emptyText.TextColor3 = Color3.fromRGB(140, 140, 150)
                emptyText.Font = Enum.Font.GothamBold
                emptyText.TextSize = 12
                emptyText.TextXAlignment = Enum.TextXAlignment.Center
            else
                -- Counter
                local counter = Instance.new("TextLabel", contentFrame)
                counter.Size = UDim2.new(1, 0, 0, 18)
                counter.BackgroundTransparency = 1
                counter.Text = #allItems .. " items found | Click Wear to equip"
                counter.TextColor3 = T.Text2
                counter.Font = Enum.Font.GothamBold
                counter.TextSize = 9
                counter.TextXAlignment = Enum.TextXAlignment.Left
                
                -- List layout
                local listLayout = Instance.new("UIListLayout", contentFrame)
                listLayout.Padding = UDim.new(0, 6)
                listLayout.SortOrder = Enum.SortOrder.LayoutOrder
                
                -- Render items
                local maxShow = math.min(20, #allItems)
                for i = 1, maxShow do
                    local card = Instance.new("Frame", contentFrame)
                    card.Size = UDim2.new(1, 0, 0, 56)
                    card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    card.LayoutOrder = i
                    corner(card, 10)
                    stroke(card, Color3.fromRGB(225, 225, 230), 1, 0.3)
                    
                    local imgBox = Instance.new("Frame", card)
                    imgBox.Size = UDim2.new(0, 40, 0, 40)
                    imgBox.Position = UDim2.new(0, 8, 0.5, -20)
                    imgBox.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
                    corner(imgBox, 8)
                    stroke(imgBox, Color3.fromRGB(215, 215, 220), 1, 0.3)
                    
                    local img = Instance.new("ImageLabel", imgBox)
                    img.Size = UDim2.new(1, -4, 1, -4)
                    img.Position = UDim2.new(0.5, 0, 0.5, 0)
                    img.AnchorPoint = Vector2.new(0.5, 0.5)
                    img.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
                    img.Image = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. allItems[i].id .. "&width=100&height=100&format=png"
                    img.ScaleType = Enum.ScaleType.Fit
                    corner(img, 6)
                    
                    local nameLbl = Instance.new("TextLabel", card)
                    nameLbl.Size = UDim2.new(1, -120, 0, 20)
                    nameLbl.Position = UDim2.new(0, 54, 0, 6)
                    nameLbl.BackgroundTransparency = 1
                    nameLbl.Text = allItems[i].name
                    nameLbl.TextColor3 = T.Text
                    nameLbl.Font = Enum.Font.GothamBlack
                    nameLbl.TextSize = 11
                    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
                    
                    local idLbl = Instance.new("TextLabel", card)
                    idLbl.Size = UDim2.new(1, -120, 0, 14)
                    idLbl.Position = UDim2.new(0, 54, 0, 26)
                    idLbl.BackgroundTransparency = 1
                    idLbl.Text = "ID: " .. allItems[i].id
                    idLbl.TextColor3 = T.Text2
                    idLbl.Font = Enum.Font.Code
                    idLbl.TextSize = 8
                    idLbl.TextXAlignment = Enum.TextXAlignment.Left
                    
                    local typeBadge = Instance.new("Frame", card)
                    typeBadge.Size = UDim2.new(0, 45, 0, 14)
                    typeBadge.Position = UDim2.new(0, 54, 0, 40)
                    typeBadge.BackgroundColor3 = allItems[i].typeColor
                    typeBadge.BackgroundTransparency = 0.82
                    corner(typeBadge, 7)
                    
                    local typeText = Instance.new("TextLabel", typeBadge)
                    typeText.Size = UDim2.new(1, 0, 1, 0)
                    typeText.BackgroundTransparency = 1
                    typeText.Text = allItems[i].itemType
                    typeText.TextColor3 = allItems[i].typeColor
                    typeText.Font = Enum.Font.GothamBold
                    typeText.TextSize = 7
                    
                    local wearBtn = Instance.new("TextButton", card)
                    wearBtn.Size = UDim2.new(0, 50, 0, 22)
                    wearBtn.Position = UDim2.new(1, -58, 0.5, -11)
                    wearBtn.BackgroundColor3 = T.Accent
                    wearBtn.Text = "Wear"
                    wearBtn.TextColor3 = T.OnAccent
                    wearBtn.Font = Enum.Font.GothamBold
                    wearBtn.TextSize = 8
                    wearBtn.AutoButtonColor = false
                    corner(wearBtn, 6)
                    pressFX(wearBtn)
                    wearBtn.MouseButton1Click:Connect(function()
                        fireHat({tostring(allItems[i].id)})
                        wearBtn.Text = "OK"
                        wearBtn.BackgroundColor3 = T.Green
                        task.wait(1)
                        wearBtn.Text = "Wear"
                        wearBtn.BackgroundColor3 = T.Accent
                    end)
                    
                    local copyBtn = Instance.new("TextButton", card)
                    copyBtn.Size = UDim2.new(0, 50, 0, 22)
                    copyBtn.Position = UDim2.new(1, -114, 0.5, -11)
                    copyBtn.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
                    copyBtn.Text = "Copy"
                    copyBtn.TextColor3 = T.Text
                    copyBtn.Font = Enum.Font.GothamBold
                    copyBtn.TextSize = 8
                    copyBtn.AutoButtonColor = false
                    corner(copyBtn, 6)
                    stroke(copyBtn, T.Border, 1, 0.3)
                    pressFX(copyBtn)
                    copyBtn.MouseButton1Click:Connect(function()
                        copyToClipboard(tostring(allItems[i].id))
                        showDynamicNotification("Copied!", T.Green)
                    end)
                end
                
                -- Clone All button
                local cloneAllBtn = Instance.new("TextButton", contentFrame)
                cloneAllBtn.Size = UDim2.new(1, 0, 0, 34)
                cloneAllBtn.BackgroundColor3 = T.Green
                cloneAllBtn.Text = "CLONE ALL ITEMS (" .. #allItems .. ")"
                cloneAllBtn.TextColor3 = T.OnAccent
                cloneAllBtn.Font = Enum.Font.GothamBlack
                cloneAllBtn.TextSize = 11
                cloneAllBtn.AutoButtonColor = false
                cloneAllBtn.LayoutOrder = 999
                corner(cloneAllBtn, 8)
                pressFX(cloneAllBtn)
                cloneAllBtn.MouseButton1Click:Connect(function()
                    local ids = {}
                    for _, item in ipairs(allItems) do
                        table.insert(ids, tostring(item.id))
                    end
                    cloneAllBtn.Text = "Cloning..."
                    cloneAllBtn.BackgroundColor3 = T.Gold
                    
                    local batchSize = CONFIG.CLONE_BATCH_SIZE or 5
                    local delayTime = CONFIG.CLONE_DELAY or 6
                    local total = math.ceil(#ids / batchSize)
                    local cur = 0
                    
                    local function nextBatch()
                        cur = cur + 1
                        if cur > total then
                            cloneAllBtn.Text = "Done!"
                            cloneAllBtn.BackgroundColor3 = T.Green
                            task.wait(2)
                            cloneAllBtn.Text = "CLONE ALL ITEMS (" .. #allItems .. ")"
                            cloneAllBtn.BackgroundColor3 = T.Green
                            return
                        end
                        local s = (cur - 1) * batchSize + 1
                        local e = math.min(cur * batchSize, #ids)
                        local b = {}
                        for j = s, e do table.insert(b, ids[j]) end
                        fireHat(b)
                        cloneAllBtn.Text = "Clone " .. cur .. "/" .. total
                        task.delay(delayTime, nextBatch)
                    end
                    nextBatch()
                end)
            end
        end)
    end
    
-- ==================== RENDER OUTFITS TAB (FIXED - SAME API AS AVATARITEM) ====================
if lookupSelectedTab == "Outfits" and playerLookupData.userId then
    local userId = playerLookupData.userId
    local displayName = playerLookupData.displayName
    
    local loadingText = Instance.new("TextLabel", contentFrame)
    loadingText.Size = UDim2.new(1, 0, 0, 24)
    loadingText.BackgroundTransparency = 1
    loadingText.Text = "Loading outfits..."
    loadingText.TextColor3 = T.Text2
    loadingText.Font = Enum.Font.Gotham
    loadingText.TextSize = 10
    
    task.spawn(function()
        local allOutfits = {}
        
        -- ===== METHOD 1: Outfits API (sama seperti AvatarItem) =====
        local raw = httpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/outfits?page=1&itemsPerPage=30")
        
        if raw then
            local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and data and data.data and #data.data > 0 then
                for _, outfit in ipairs(data.data) do
                    if outfit.name and outfit.id then
                        table.insert(allOutfits, {
                            id = outfit.id,
                            name = outfit.name,
                            assets = {}
                        })
                    end
                end
            end
        end
        
        -- ===== METHOD 2: Currently Wearing (fallback) =====
        if #allOutfits == 0 then
            local wearRaw = httpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/currently-wearing")
            
            if wearRaw then
                local ok, data = pcall(function() return HttpService:JSONDecode(wearRaw) end)
                if ok and data and data.assetIds and #data.assetIds > 0 then
                    table.insert(allOutfits, {
                        id = "current",
                        name = "Current Outfit",
                        assets = data.assetIds
                    })
                end
            end
        end
        
        -- ===== METHOD 3: Avatar API (last resort) =====
        if #allOutfits == 0 then
            local avatarRaw = httpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/avatar")
            
            if avatarRaw then
                local ok, data = pcall(function() return HttpService:JSONDecode(avatarRaw) end)
                if ok and data and data.assets and #data.assets > 0 then
                    local ids = {}
                    for _, asset in ipairs(data.assets) do
                        if asset.id then table.insert(ids, tostring(asset.id)) end
                    end
                    if #ids > 0 then
                        table.insert(allOutfits, {
                            id = "current",
                            name = "Current Avatar",
                            assets = ids
                        })
                    end
                end
            end
        end
        
        loadingText:Destroy()
        
        if #allOutfits == 0 then
            local emptyCard = Instance.new("Frame", contentFrame)
            emptyCard.Size = UDim2.new(1, 0, 0, 120)
            emptyCard.BackgroundColor3 = Color3.fromRGB(248, 248, 250)
            corner(emptyCard, 14)
            stroke(emptyCard, Color3.fromRGB(220, 220, 225), 1, 0.3)
            
            local emptyText = Instance.new("TextLabel", emptyCard)
            emptyText.Size = UDim2.new(1, 0, 0, 50)
            emptyText.Position = UDim2.new(0, 0, 0, 20)
            emptyText.BackgroundTransparency = 1
            emptyText.Text = "No outfits found"
            emptyText.TextColor3 = Color3.fromRGB(140, 140, 150)
            emptyText.Font = Enum.Font.GothamBlack
            emptyText.TextSize = 13
            emptyText.TextXAlignment = Enum.TextXAlignment.Center
            
            local emptyMsg = Instance.new("TextLabel", emptyCard)
            emptyMsg.Size = UDim2.new(1, -20, 0, 30)
            emptyMsg.Position = UDim2.new(0, 10, 0, 72)
            emptyMsg.BackgroundTransparency = 1
            emptyMsg.Text = "This player may not have public outfits\nor API is restricted for this player"
            emptyMsg.TextColor3 = Color3.fromRGB(160, 160, 170)
            emptyMsg.Font = Enum.Font.Gotham
            emptyMsg.TextSize = 10
            emptyMsg.TextWrapped = true
            emptyMsg.TextXAlignment = Enum.TextXAlignment.Center
            return
        end
        
        -- Counter
        local counter = Instance.new("TextLabel", contentFrame)
        counter.Size = UDim2.new(1, 0, 0, 18)
        counter.BackgroundTransparency = 1
        counter.Text = #allOutfits .. " outfits found"
        counter.TextColor3 = T.Text2
        counter.Font = Enum.Font.GothamBold
        counter.TextSize = 9
        counter.TextXAlignment = Enum.TextXAlignment.Left
        
        -- Grid 2 kolom
        local grid = Instance.new("UIGridLayout", contentFrame)
        grid.CellSize = UDim2.new(0.5, -5, 0, 170)
        grid.CellPadding = UDim2.new(0, 8, 0, 8)
        grid.FillDirection = Enum.FillDirection.Horizontal
        grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
        grid.SortOrder = Enum.SortOrder.LayoutOrder
        
        for i, outfit in ipairs(allOutfits) do
            local card = Instance.new("Frame", contentFrame)
            card.Size = UDim2.new(0, 0, 0, 170)
            card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            card.LayoutOrder = i
            corner(card, 12)
            stroke(card, Color3.fromRGB(225, 225, 230), 1, 0.3)
            
            -- Thumbnail
            local imgBox = Instance.new("Frame", card)
            imgBox.Size = UDim2.new(0, 75, 0, 75)
            imgBox.Position = UDim2.new(0.5, -37, 0, 8)
            imgBox.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
            corner(imgBox, 10)
            stroke(imgBox, Color3.fromRGB(215, 215, 220), 1, 0.3)
            
            local img = Instance.new("ImageLabel", imgBox)
            img.Size = UDim2.new(1, -4, 1, -4)
            img.Position = UDim2.new(0.5, 0, 0.5, 0)
            img.AnchorPoint = Vector2.new(0.5, 0.5)
            img.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
            
            -- Thumbnail based on type
            if outfit.id == "current" then
                img.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. userId .. "&width=150&height=150&format=png"
            else
                img.Image = "https://www.roblox.com/outfit-thumbnail/image?userOutfitId=" .. outfit.id .. "&width=150&height=150&format=png"
            end
            img.ScaleType = Enum.ScaleType.Fit
            corner(img, 7)
            
            -- Name
            local nameLbl = Instance.new("TextLabel", card)
            nameLbl.Size = UDim2.new(1, -14, 0, 28)
            nameLbl.Position = UDim2.new(0, 7, 0, 86)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = outfit.name
            nameLbl.TextColor3 = T.Text
            nameLbl.Font = Enum.Font.GothamBlack
            nameLbl.TextSize = 10
            nameLbl.TextXAlignment = Enum.TextXAlignment.Center
            nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            nameLbl.TextWrapped = true
            
            -- ID
            local idText = outfit.id == "current" and "CURRENT" or "ID: " .. outfit.id
            local idLbl = Instance.new("TextLabel", card)
            idLbl.Size = UDim2.new(1, -14, 0, 14)
            idLbl.Position = UDim2.new(0, 7, 0, 114)
            idLbl.BackgroundTransparency = 1
            idLbl.Text = idText
            idLbl.TextColor3 = T.Text2
            idLbl.Font = Enum.Font.Code
            idLbl.TextSize = 8
            idLbl.TextXAlignment = Enum.TextXAlignment.Center
            
            -- Type badge
            if outfit.id == "current" then
                local badge = Instance.new("Frame", card)
                badge.Size = UDim2.new(0, 50, 0, 15)
                badge.Position = UDim2.new(0.5, -25, 0, 130)
                badge.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
                badge.BackgroundTransparency = 0.8
                corner(badge, 7)
                
                local badgeText = Instance.new("TextLabel", badge)
                badgeText.Size = UDim2.new(1, 0, 1, 0)
                badgeText.BackgroundTransparency = 1
                badgeText.Text = "CURRENT"
                badgeText.TextColor3 = Color3.fromRGB(80, 200, 80)
                badgeText.Font = Enum.Font.GothamBold
                badgeText.TextSize = 7
            end
            
            -- Buttons
            local btnRow = Instance.new("Frame", card)
            btnRow.Size = UDim2.new(1, -14, 0, 26)
            btnRow.Position = UDim2.new(0, 7, 0, 140)
            btnRow.BackgroundTransparency = 1
            
            -- Wear button
            local wearBtn = Instance.new("TextButton", btnRow)
            wearBtn.Size = UDim2.new(0, 65, 1, 0)
            wearBtn.BackgroundColor3 = Color3.fromRGB(180, 130, 255)
            wearBtn.Text = "Wear"
            wearBtn.TextColor3 = T.OnAccent
            wearBtn.Font = Enum.Font.GothamBold
            wearBtn.TextSize = 9
            wearBtn.AutoButtonColor = false
            corner(wearBtn, 6)
            pressFX(wearBtn)
            wearBtn.MouseButton1Click:Connect(function()
                wearBtn.Text = "..."
                wearBtn.BackgroundColor3 = T.Gold
                
                local idsToWear = {}
                
                -- Cek apakah outfit punya assets tersimpan
                if outfit.assets and #outfit.assets > 0 then
                    -- Konversi ke string jika perlu
                    for _, id in ipairs(outfit.assets) do
                        table.insert(idsToWear, tostring(id))
                    end
                elseif outfit.id == "current" then
                    -- Fallback: ambil dari currently-wearing
                    local wearRaw = httpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/currently-wearing")
                    if wearRaw then
                        local ok, data = pcall(function() return HttpService:JSONDecode(wearRaw) end)
                        if ok and data and data.assetIds then
                            for _, id in ipairs(data.assetIds) do
                                table.insert(idsToWear, tostring(id))
                            end
                        end
                    end
                else
                    -- Fetch detail outfit
                    local detailRaw = httpGet("https://avatar.roblox.com/v1/outfits/" .. outfit.id .. "/details")
                    if detailRaw then
                        local ok, detail = pcall(function() return HttpService:JSONDecode(detailRaw) end)
                        if ok and detail and detail.assets then
                            for _, asset in ipairs(detail.assets) do
                                if asset.id then
                                    table.insert(idsToWear, tostring(asset.id))
                                end
                            end
                        end
                    end
                end
                
                if #idsToWear > 0 then
                    fireHat(idsToWear)
                    task.wait(0.3)
                    resetCharacter()
                    wearBtn.Text = "Done!"
                    wearBtn.BackgroundColor3 = T.Green
                    showDynamicNotification("Outfit applied!", T.Green)
                else
                    wearBtn.Text = "Empty!"
                    wearBtn.BackgroundColor3 = T.Red
                    showDynamicNotification("No items in outfit!", T.Red)
                end
                
                task.wait(1.5)
                wearBtn.Text = "Wear"
                wearBtn.BackgroundColor3 = Color3.fromRGB(180, 130, 255)
            end)
            
            -- Copy button
            local copyBtn = Instance.new("TextButton", btnRow)
            copyBtn.Size = UDim2.new(0, 55, 1, 0)
            copyBtn.Position = UDim2.new(0, 69, 0, 0)
            copyBtn.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
            copyBtn.Text = "Copy"
            copyBtn.TextColor3 = T.Text
            copyBtn.Font = Enum.Font.GothamBold
            copyBtn.TextSize = 9
            copyBtn.AutoButtonColor = false
            corner(copyBtn, 6)
            stroke(copyBtn, T.Border, 1, 0.3)
            pressFX(copyBtn)
            copyBtn.MouseButton1Click:Connect(function()
                local copyId = outfit.id == "current" and tostring(userId) or tostring(outfit.id)
                copyToClipboard(copyId)
                showDynamicNotification("Copied!", T.Green)
            end)
        end
    end)
end
    
    -- ==================== NO DATA STATE ====================
    if not playerLookupData.userId then
        local emptyCard = Instance.new("Frame", contentFrame)
        emptyCard.Size = UDim2.new(1, 0, 0, 100)
        emptyCard.BackgroundColor3 = Color3.fromRGB(248, 248, 250)
        corner(emptyCard, 14)
        stroke(emptyCard, Color3.fromRGB(220, 220, 225), 1, 0.3)
        
        local emptyText = Instance.new("TextLabel", emptyCard)
        emptyText.Size = UDim2.new(1, 0, 1, 0)
        emptyText.BackgroundTransparency = 1
        emptyText.Text = "Search a player to get started!\n\nType a Roblox username above"
        emptyText.TextColor3 = Color3.fromRGB(140, 140, 150)
        emptyText.Font = Enum.Font.GothamBold
        emptyText.TextSize = 12
        emptyText.TextWrapped = true
    end
    
    -- ==================== EVENTS ====================
    searchBtn.MouseButton1Click:Connect(function()
        searchPlayer(searchInput.Text)
    end)
    
    searchInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            searchPlayer(searchInput.Text)
        end
    end)
end

-- ================= BUILD HOME ICONS =================
buildAppIcon("Profile",1,dockBg,function() openApp("Profile",openProfileApp) end)
buildAppIcon("Settings",3,dockBg,function() openApp("Settings",openSettingsApp) end)
buildAppIcon("Players",1,appGrid,function() openApp("Players",openPlayersApp) end)
buildAppIcon("Clone",2,appGrid,function() openApp("Clone",openCloneApp) end)
buildAppIcon("Body",3,appGrid,function() openApp("Body",openBodyApp) end)
buildAppIcon("Accs",4,appGrid,function() openApp("Accessory",openAccessoryApp) end)
buildAppIcon("Preset",5,appGrid,function() openApp("Preset",openPresetApp) end)
buildAppIcon("Favs",6,appGrid,function() openApp("Favorites",openFavoritesApp) end)
buildAppIcon("Items",7,appGrid,function() openApp("Items",openItemsApp) end)
buildAppIcon("Server",12,appGrid,function() openApp("Server",openServerApp) end)
buildAppIcon("AvatarItems",14, appGrid, function() openApp("Avatar & Items", openAvatarItemsApp) end)
buildAppIcon("Lookup",15,appGrid, function() openApp("Player Lookup", openPlayerLookupApp) end)

-- ==================== FLOATING IPHONE ICON + TABLET MODE (FINAL FIXED) ====================
-- GANTI seluruh bagian TOOL & EQUIP dan DRAG PHONE dengan ini

-- ==================== VARIABLES ====================
local phoneIcon = nil
local mouseDown = false
local mouseMoved = false
local dragStart = nil
local iconStartPos = nil
local toolEquipped = true

-- ==================== ORIENTASI ====================
local PHONE_SIZE_PORTRAIT = UDim2.new(0, 320, 0, 560)
local PHONE_SIZE = PHONE_SIZE_PORTRAIT
local isLandscapeMode = false

local function isPortrait()
    local cam = Workspace.CurrentCamera
    if not cam then return true end
    return cam.ViewportSize.Y >= cam.ViewportSize.X
end

local function getGridIconSize()
    if isPortrait() then
        return UDim2.new(0, 72, 0, 86)
    else
        return UDim2.new(0, 68, 0, 78)
    end
end

local function applyPhoneOrientationSize()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    if vp.X <= 0 or vp.Y <= 0 then return end
    
    local landscape = vp.X > vp.Y
    
    if landscape then
        local phoneW = math.min(vp.X - 10, 520)
        local phoneH = math.min(vp.Y - 10, 320)
        PHONE_SIZE = UDim2.new(0, phoneW, 0, phoneH)
        phone.Position = UDim2.new(0.5, 0, 0.5, 0)
        isLandscapeMode = true
    else
        PHONE_SIZE = PHONE_SIZE_PORTRAIT
        phone.Position = UDim2.new(0.5, 0, 0.52, 0)
        isLandscapeMode = false
    end
    
    if phone.Visible then
        tween(phone, {Size = PHONE_SIZE, Position = phone.Position}, 0.3, Enum.EasingStyle.Quart)
    end
end

-- ==================== CREATE FLOATING ICON ====================
local function createFloatingIcon()
    if phoneIcon then
        pcall(function() phoneIcon:Destroy() end)
        phoneIcon = nil
    end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "PhoneIcon"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.IgnoreGuiInset = true
    
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then
        pcall(function() gui.Parent = getGuiParent() end)
    end
    if not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    local iconContainer = Instance.new("Frame", gui)
    iconContainer.Size = UDim2.new(0, 65, 0, 105)
    iconContainer.Position = UDim2.new(0, 15, 0.5, -52)
    iconContainer.BackgroundTransparency = 1
    iconContainer.ZIndex = 1000
    iconContainer.AnchorPoint = Vector2.new(0, 0)
    
    -- Body iPhone
    local phoneBody = Instance.new("Frame", iconContainer)
    phoneBody.Size = UDim2.new(0, 50, 0, 88)
    phoneBody.Position = UDim2.new(0.5, -25, 0.5, -44)
    phoneBody.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    phoneBody.ZIndex = 1001
    corner(phoneBody, 12)
    stroke(phoneBody, Color3.fromRGB(45, 45, 50), 2, 0)
    
    local bodyGrad = Instance.new("UIGradient", phoneBody)
    bodyGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 28, 32)),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(18, 18, 22)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(22, 22, 26)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 16))
    })
    bodyGrad.Rotation = 135
    
    -- Screen
    local screen = Instance.new("Frame", phoneBody)
    screen.Size = UDim2.new(1, -6, 1, -30)
    screen.Position = UDim2.new(0, 3, 0, 20)
    screen.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    screen.ZIndex = 1002
    corner(screen, 8)
    
    -- Status Bar
    local statusBar = Instance.new("Frame", screen)
    statusBar.Size = UDim2.new(1, 0, 0, 12)
    statusBar.Position = UDim2.new(0, 0, 0, 2)
    statusBar.BackgroundTransparency = 1
    statusBar.ZIndex = 1010
    
    -- Signal
    local signalFrame = Instance.new("Frame", statusBar)
    signalFrame.Size = UDim2.new(0, 15, 0, 10)
    signalFrame.Position = UDim2.new(0, 3, 0.5, -5)
    signalFrame.BackgroundTransparency = 1
    signalFrame.ZIndex = 1011
    
    for i = 1, 4 do
        local bar = Instance.new("Frame", signalFrame)
        bar.Size = UDim2.new(0, 2.5, 0, 2 + i * 1.5)
        bar.Position = UDim2.new(0, (i-1) * 4, 1, 0)
        bar.AnchorPoint = Vector2.new(0, 1)
        bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        bar.BorderSizePixel = 0
        bar.ZIndex = 1011
        corner(bar, 1)
    end
    
    -- Time
    local timeLabel = Instance.new("TextLabel", statusBar)
    timeLabel.Size = UDim2.new(0, 24, 0, 12)
    timeLabel.Position = UDim2.new(0.5, -12, 0, 0)
    timeLabel.BackgroundTransparency = 1
    timeLabel.Text = "9:41"
    timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timeLabel.Font = Enum.Font.GothamBold
    timeLabel.TextSize = 7
    timeLabel.TextXAlignment = Enum.TextXAlignment.Center
    timeLabel.TextYAlignment = Enum.TextYAlignment.Center
    timeLabel.ZIndex = 1011
    
    -- Battery
    local batteryFrame = Instance.new("Frame", statusBar)
    batteryFrame.Size = UDim2.new(0, 18, 0, 10)
    batteryFrame.Position = UDim2.new(1, -20, 0.5, -5)
    batteryFrame.BackgroundTransparency = 1
    batteryFrame.ZIndex = 1011
    
    local batteryBody = Instance.new("Frame", batteryFrame)
    batteryBody.Size = UDim2.new(0, 14, 0, 8)
    batteryBody.Position = UDim2.new(0, 0, 0.5, -4)
    batteryBody.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    batteryBody.BackgroundTransparency = 0.9
    batteryBody.BorderSizePixel = 0
    batteryBody.ZIndex = 1011
    corner(batteryBody, 3)
    stroke(batteryBody, Color3.fromRGB(255, 255, 255), 1, 0.3)
    
    local batteryFill = Instance.new("Frame", batteryBody)
    batteryFill.Size = UDim2.new(0.7, -2, 1, -4)
    batteryFill.Position = UDim2.new(0, 1, 0, 2)
    batteryFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    batteryFill.BorderSizePixel = 0
    batteryFill.ZIndex = 1012
    corner(batteryFill, 2)
    
    local batteryTip = Instance.new("Frame", batteryFrame)
    batteryTip.Size = UDim2.new(0, 2.5, 0, 4)
    batteryTip.Position = UDim2.new(1, -1, 0.5, -2)
    batteryTip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    batteryTip.BackgroundTransparency = 0.5
    batteryTip.BorderSizePixel = 0
    batteryTip.ZIndex = 1011
    corner(batteryTip, 1)
    
    -- Wallpaper
    local wallpaper = Instance.new("Frame", screen)
    wallpaper.Size = UDim2.new(1, -4, 1, -14)
    wallpaper.Position = UDim2.new(0.5, 0, 0, 13)
    wallpaper.AnchorPoint = Vector2.new(0.5, 0)
    wallpaper.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    wallpaper.ZIndex = 1003
    corner(wallpaper, 6)
    
    -- App Icons
    local iconPositions = {
        {x = 3, y = 6}, {x = 14, y = 6}, {x = 25, y = 6},
        {x = 3, y = 17}, {x = 14, y = 17}, {x = 25, y = 17},
    }
    local iconColors = {
        Color3.fromRGB(100, 160, 255), Color3.fromRGB(255, 120, 120),
        Color3.fromRGB(80, 210, 80), Color3.fromRGB(255, 200, 50),
        Color3.fromRGB(180, 100, 255), Color3.fromRGB(255, 160, 60),
    }
    
    for i, pos in ipairs(iconPositions) do
        local appIcon = Instance.new("Frame", wallpaper)
        appIcon.Size = UDim2.new(0, 8, 0, 8)
        appIcon.Position = UDim2.new(0, pos.x, 0, pos.y)
        appIcon.BackgroundColor3 = iconColors[i]
        appIcon.BackgroundTransparency = 0.1
        appIcon.BorderSizePixel = 0
        appIcon.ZIndex = 1004
        corner(appIcon, 2.5)
    end
    
    -- Dock
    local dock = Instance.new("Frame", wallpaper)
    dock.Size = UDim2.new(0, 32, 0, 12)
    dock.Position = UDim2.new(0.5, -16, 1, -13)
    dock.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dock.BackgroundTransparency = 0.9
    dock.BorderSizePixel = 0
    dock.ZIndex = 1004
    corner(dock, 6)
    
    for i = 1, 4 do
        local d = Instance.new("Frame", dock)
        d.Size = UDim2.new(0, 5, 0, 5)
        d.Position = UDim2.new(0, 3 + (i-1) * 7, 0.5, -2.5)
        d.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        d.BackgroundTransparency = 0.3
        d.BorderSizePixel = 0
        d.ZIndex = 1005
        corner(d, 1.5)
    end
    
    -- Dynamic Island
    local di2 = Instance.new("Frame", phoneBody)
    di2.Size = UDim2.new(0, 24, 0, 5)
    di2.Position = UDim2.new(0.5, -12, 0, 6)
    di2.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    di2.ZIndex = 1020
    corner(di2, 3)
    
    -- Home Bar
    local hb = Instance.new("Frame", phoneBody)
    hb.Size = UDim2.new(0, 22, 0, 3)
    hb.Position = UDim2.new(0.5, -11, 1, -5)
    hb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hb.BackgroundTransparency = 0.6
    hb.BorderSizePixel = 0
    hb.ZIndex = 1020
    corner(hb, 2)
    
    -- Camera
    local camBump = Instance.new("Frame", phoneBody)
    camBump.Size = UDim2.new(0, 14, 0, 14)
    camBump.Position = UDim2.new(0.5, 8, 1, -14)
    camBump.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    camBump.ZIndex = 1020
    corner(camBump, 100)
    
    local mainLens = Instance.new("Frame", camBump)
    mainLens.Size = UDim2.new(0, 7, 0, 7)
    mainLens.Position = UDim2.new(0.5, -3, 0.5, -3)
    mainLens.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    mainLens.ZIndex = 1021
    corner(mainLens, 100)
    stroke(mainLens, Color3.fromRGB(40, 40, 44), 1, 0)
    
    -- ==================== CLICK BUTTON (FIXED) ====================
    local clickBtn = Instance.new("TextButton", iconContainer)
    clickBtn.Size = UDim2.new(0, 55, 0, 95)
    clickBtn.Position = UDim2.new(0.5, -27, 0.5, -47)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ""
    clickBtn.ZIndex = 1030
    clickBtn.AutoButtonColor = false
    
    clickBtn.MouseEnter:Connect(function()
        tween(phoneBody, {Size = UDim2.new(0, 54, 0, 94)}, 0.15)
    end)
    clickBtn.MouseLeave:Connect(function()
        if not mouseDown then
            tween(phoneBody, {Size = UDim2.new(0, 50, 0, 88)}, 0.15)
        end
    end)
    
    -- KLIK BUKA/TUTUP (LANGSUNG - TANPA FUNGSI LAIN)
    clickBtn.MouseButton1Click:Connect(function()
        if mouseMoved then return end -- Jangan proses kalau lagi drag
        
        if not phone or not phone.Parent then return end
        
        if phone.Visible then
            -- TUTUP
            tween(phone, {Size = UDim2.new(0, 0, 0, 0)}, 0.25)
            task.delay(0.25, function()
                if phone and phone.Parent then
                    phone.Visible = false
                end
            end)
        else
            -- BUKA
            applyPhoneOrientationSize()
            phone.Visible = true
            phone.Size = UDim2.new(0, 0, 0, 0)
            tween(phone, {Size = PHONE_SIZE}, 0.3, Enum.EasingStyle.Back)
            
            goHome()
        end
    end)
    
    -- DRAG
    clickBtn.MouseButton1Down:Connect(function()
        mouseDown = true
        mouseMoved = false
        dragStart = UserInputService:GetMouseLocation()
        iconStartPos = iconContainer.Position
    end)
    
    clickBtn.MouseButton1Up:Connect(function()
        mouseDown = false
        task.wait(0.1)
        mouseMoved = false -- Reset setelah selesai
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if not mouseDown then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local mousePos = UserInputService:GetMouseLocation()
            if not dragStart then return end
            local delta = mousePos - dragStart
            if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
                mouseMoved = true
            end
            if mouseMoved then
                local newX = iconStartPos.X.Offset + delta.X
                local newY = iconStartPos.Y.Offset + delta.Y
                local screenSize = Workspace.CurrentCamera.ViewportSize
                newX = math.clamp(newX, 5, screenSize.X - 70)
                newY = math.clamp(newY, 5, screenSize.Y - 110)
                iconContainer.Position = UDim2.new(0, newX, 0, newY)
            end
        end
    end)
    
    phoneIcon = gui
    return gui
end

-- ==================== INIT ====================
task.spawn(function()
    task.wait(1)
    createFloatingIcon()
    task.wait(0.5)
    openPhone()
end)

-- ==================== RESPAWN ====================
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if not phoneIcon or not phoneIcon.Parent then
        createFloatingIcon()
    end
end)

-- ==================== MONITOR ====================
task.spawn(function()
    while true do
        task.wait(5)
        if not phoneIcon or not phoneIcon.Parent then
            createFloatingIcon()
        end
    end
end)

-- ==================== ORIENTATION MONITOR ====================
task.spawn(function()
    local lastLandscape = nil
    while true do
        task.wait(0.3)
        local cam = Workspace.CurrentCamera
        if not cam then continue end
        local isLand = cam.ViewportSize.X > cam.ViewportSize.Y
        if isLand ~= lastLandscape then
            lastLandscape = isLand
            applyPhoneOrientationSize()
        end
    end
end)

print("[Phone] System ready! Click icon to open/close.")


print("[Phone v10.1] Full code loaded – Favorites horizontal, status bar refined.")