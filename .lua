-- // Configuration
getgenv().Prediction = 0.109 
getgenv().AutoPrediction = true 
getgenv().Radius = 150 
getgenv().TracerColor = Color3.fromRGB(255, 0, 255) 
getgenv().TracerThickness = 1.5

-- // Prediction Table (Ping based)
local PingTable = {
    {Ping = 40, Prediction = 0.11},
    {Ping = 50, Prediction = 0.12},
    {Ping = 60, Prediction = 0.125},
    {Ping = 70, Prediction = 0.13},
    {Ping = 80, Prediction = 0.135},
    {Ping = 90, Prediction = 0.14},
    {Ping = 100, Prediction = 0.145},
    {Ping = 120, Prediction = 0.15},
    {Ping = 150, Prediction = 0.162},
    {Ping = 200, Prediction = 0.176},
    {Ping = 300, Prediction = 0.22}
}

-- // Variables
local client = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

-- // Platform Detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- // Drawing Setup
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = true
FOVCircle.Transparency = 1
FOVCircle.Thickness = 1.5
FOVCircle.Color = getgenv().TracerColor
FOVCircle.Filled = false
FOVCircle.NumSides = 64
FOVCircle.Radius = getgenv().Radius
FOVCircle.ZIndex = 999

local Tracer = Drawing.new("Line")
Tracer.Visible = false
Tracer.Color = getgenv().TracerColor
Tracer.Thickness = getgenv().TracerThickness
Tracer.Transparency = 1
Tracer.ZIndex = 999

-- // Get Pointer (Mouse or Center Screen)
local function getPointer()
    if isMobile then
        return Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    else
        return UserInputService:GetMouseLocation()
    end
end

-- // Wall Check
local function isVisible(targetPart)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {client.Character, targetPart.Parent}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = workspace:Raycast(camera.CFrame.Position, (targetPart.Position - camera.CFrame.Position), raycastParams)
    return result == nil
end

-- // Health Check
local function isAlive(player)
    if player and player.Character and player.Character:FindFirstChild("Humanoid") then
        return player.Character.Humanoid.Health > 1
    end
    return false
end

-- // Prediction Calculation (Strictly RootPart)
local function getCalculatedPos(target)
    local root = target.Character.HumanoidRootPart
    local velocity = root.Velocity
    local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    
    local currentPred = getgenv().Prediction
    for _, entry in ipairs(PingTable) do
        if ping >= entry.Ping then
            currentPred = entry.Prediction
        end
    end
    
    return root.Position + (velocity * currentPred)
end

-- // Targeting Logic
local target = nil
local function getClosestPlayer()
    local closest = nil
    local maxDist = getgenv().Radius
    local pointer = getPointer()

    for _, v in pairs(game.Players:GetPlayers()) do
        if v ~= client and isAlive(v) and v.Character:FindFirstChild("HumanoidRootPart") then
            local root = v.Character.HumanoidRootPart
            local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
            
            if onScreen then
                local dist = (pointer - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                if dist < maxDist and isVisible(root) then
                    closest = v
                    maxDist = dist
                end
            end
        end
    end
    return closest
end

-- // Loop
RunService.RenderStepped:Connect(function()
    local pointer = getPointer()
    
    FOVCircle.Visible = true
    FOVCircle.Position = pointer
    FOVCircle.Radius = getgenv().Radius
    
    target = getClosestPlayer()
    
    -- Tracer strictly to HumanoidRootPart
    if target and target.Character:FindFirstChild("HumanoidRootPart") then
        local root = target.Character.HumanoidRootPart
        local targetPos, onScreen = camera:WorldToViewportPoint(root.Position)
        
        if onScreen then
            Tracer.Visible = true
            Tracer.From = pointer
            Tracer.To = Vector2.new(targetPos.X, targetPos.Y)
        else
            Tracer.Visible = false
        end
    else
        Tracer.Visible = false
    end
end)

-- // Hit Event
local function onToolActivated()
    if target and isAlive(target) then
        local pos = getCalculatedPos(target)
        game.ReplicatedStorage.MAINEVENT:FireServer("MOUSE", pos)
    end
end

-- // Tool Detection
local function setupTool(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            child.Activated:Connect(onToolActivated)
        end
    end)
end

client.CharacterAdded:Connect(setupTool)
if client.Character then setupTool(client.Character) end
