getgenv().Prediction = 0.109
getgenv().ResolveKey = "C" 
getgenv().Smoothing = 0.05 
getgenv().JumpSmoothness = 1 
getgenv().Diameter = -0.2 
getgenv().Radius = 150 
getgenv().TracerColor = Color3.fromRGB(255, 0, 255)
getgenv().TracerThickness = 1.5
getgenv().TracerTransparency = 1

local resolver = false
local silentAim = true
local client = game.Players.LocalPlayer
local camera = game.Workspace.CurrentCamera
local Resolvedvelocity
local target, aiming
local UserInputService = game:GetService("UserInputService")

local Tracer = Drawing.new("Line")
Tracer.Visible = false
Tracer.Color = getgenv().TracerColor
Tracer.Thickness = getgenv().TracerThickness
Tracer.Transparency = getgenv().TracerTransparency

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed then
        if input.KeyCode == Enum.KeyCode[getgenv().ResolveKey:upper()] then
            resolver = not resolver
            game.StarterGui:SetCore("SendNotification", {
                Title = tostring(resolver),
                Text = "Resolve",
                Duration = 0.5
            })
            if not resolver then
                aiming = false
                target = nil
            end
        end
    end
end)

local Smoothness = 5
local Stored = {}
local Value = 1

local recalculatedVelocity = function(player)
    local Tick = tick()
    Stored[Value] = {
        pos = player.Position,
        time = Tick,
    }
    Value = Value + 1
    if Value > Smoothness then
        Value = 1
    end
    local Pos = Vector3.new()
    local Time = 0
    for i = 1, Smoothness do
        local Data = Stored[i]
        if Data then
            Pos = Pos + Data.pos
            Time = Time + Data.time
        end
    end
    if Stored[Value] then
        local velocity = (player.Position - Stored[Value].pos) / (Tick - Stored[Value].time)
        return velocity
    end
end

function wallCheck(targetPosition, ignoreList)
    ignoreList = ignoreList or {}
    table.insert(ignoreList, game.Players.LocalPlayer.Character)
    local HitPoint, hitPosition = workspace:FindPartOnRayWithIgnoreList(
        Ray.new(camera.CFrame.p, (targetPosition - camera.CFrame.p).Unit * 1000),
        ignoreList
    )
    return HitPoint == nil and true or (hitPosition - camera.CFrame.p).Magnitude >= (targetPosition - camera.CFrame.p).Magnitude
end

local function isPlayerKoed(player)
    if player and player.Character and player.Character:FindFirstChild("Humanoid") then
        local humanoid = player.Character:FindFirstChild("Humanoid")
        if humanoid.Health <= 1 then
            return true
        end
    end
    return false
end

local function lockOnToNearestPlayer()
    local closestPlayer = nil
    local closestDistance = getgenv().Radius
    for _, v in pairs(game.Players:GetPlayers()) do
        if v ~= client and v.Character and v.Character:FindFirstChild("Humanoid") and not isPlayerKoed(v) then
            local rootPart = v.Character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local screenPos, Visible = camera:WorldToViewportPoint(rootPart.Position)
                if Visible then
                    local distToCenter = (Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2) - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                    if distToCenter < closestDistance and wallCheck(rootPart.Position, {client, v.Character}) then
                        closestPlayer = v
                        closestDistance = distToCenter
                    end
                end
            end
        end
    end
    target = closestPlayer
end

local aimingMethod = function(player)
    if not player or not player.Character then return end
    local velocity = Resolvedvelocity or player.Character.HumanoidRootPart.Velocity
    local isJumping = player.Character.HumanoidRootPart.Velocity.Y > 0 and
                        (player.Character.Humanoid:GetState() == Enum.HumanoidStateType.Freefall or
                        player.Character.Humanoid:GetState() == Enum.HumanoidStateType.Jumping)
    local Position = isJumping and (player.Character.LowerTorso.Position + Vector3.new(0, getgenv().Diameter, 0)) or player.Character.HumanoidRootPart.Position
    local current = player.Character.HumanoidRootPart.Position
    local result = current:Lerp(Position, getgenv().JumpSmoothness)
    return result + velocity * getgenv().Prediction
end

game:GetService("RunService").RenderStepped:Connect(function()
    if silentAim then
        lockOnToNearestPlayer()
    end
    if resolver and target ~= nil then
        Resolvedvelocity = recalculatedVelocity(target.Character.HumanoidRootPart)
    else
        Resolvedvelocity = nil
    end
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local rootPart = target.Character.HumanoidRootPart
        local screenPos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
        if onScreen then
            Tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
            Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
            Tracer.Visible = true
        else
            Tracer.Visible = false
        end
    else
        Tracer.Visible = false
    end
end)

local function onToolActivated()
    if target then
        local position = aimingMethod(target)
        game.ReplicatedStorage.MAINEVENT:FireServer("MOUSE", position)
    end
end

local function onCharacterAdded(character)
    character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Tool") then
            descendant.Activated:Connect(onToolActivated)
        end
    end)
end

game.Players.LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if game.Players.LocalPlayer.Character then
    onCharacterAdded(game.Players.LocalPlayer.Character)
end

local function easing(t)
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

game:GetService("RunService").Heartbeat:Connect(function()
    if aiming and target ~= nil then
        local position = aimingMethod(target)
        local lookAt = CFrame.new(camera.CFrame.Position, position)
        local new = camera.CFrame:Lerp(lookAt, easing(getgenv().Smoothing))
        camera.CFrame = new
    end
end)
