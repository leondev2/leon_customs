local ESX = exports['es_extended']:getSharedObject()
local isOpen = false
local savedVehicleProps = nil
local currentVehicle = 0
local isPointerOverUi = false
local tuningCam = nil
local tuningCamPos = nil

local function normalizeHeading(h)
    while h < 0.0 do h = h + 360.0 end
    while h >= 360.0 do h = h - 360.0 end
    return h
end

local function showNotification(msg)
    ESX.ShowNotification(msg)
end

local function destroyCamera()
    if not tuningCam then
        tuningCamPos = nil
        return
    end
    
    local ms = math.floor(Config.TuningCam and Config.TuningCam.easeOutMs or 360)
    SetCamActive(tuningCam, false)
    RenderScriptCams(false, true, ms, true, false)
    DestroyCam(tuningCam, false)
    tuningCam = nil
    tuningCamPos = nil
end

local function updateCamera(veh)
    if not tuningCam or not tuningCamPos or veh == 0 or not DoesEntityExist(veh) then return end
    
    local cfg = Config.TuningCam or {}
    local fov = cfg.fov or 40.0
    local lookZ = cfg.lookOffset and cfg.lookOffset.z or 0.45
    SetCamCoord(tuningCam, tuningCamPos.x, tuningCamPos.y, tuningCamPos.z)
    
    local vehCoords = GetEntityCoords(veh)
    PointCamAtCoord(tuningCam, vehCoords.x, vehCoords.y, vehCoords.z + lookZ)
    SetCamFov(tuningCam, fov)
end

local function createCamera(veh)
    destroyCamera()
    if veh == 0 or not DoesEntityExist(veh) then return end
    
    local cfg = Config.TuningCam or {}
    local coords = GetEntityCoords(veh)
    local heading = GetEntityHeading(veh)
    local rad = math.rad(heading)
    local fwd = cfg.forwardOffset or 7.15
    local camZ = cfg.camZ or 1.52
    
    tuningCamPos = vector3(
        coords.x - math.sin(rad) * fwd,
        coords.y + math.cos(rad) * fwd,
        coords.z + camZ
    )
    
    tuningCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    updateCamera(veh)
    SetCamActive(tuningCam, true)
    
    local easeIn = math.floor(cfg.easeInMs or 420)
    RenderScriptCams(true, true, easeIn, true, false)
end

local function getModPrice(modType)
    return Config.ModPrice[modType] or Config.DefaultModPrice
end

local function getVehicleClassName(classId)
    local classes = {
        'Compacts', 'Sedans', 'SUVs', 'Coupes', 'Muscle', 'Sports Classics',
        'Sports', 'Super', 'Motorcycles', 'Off-road', 'Industrial', 'Utility',
        'Vans', 'Cycles', 'Boats', 'Helicopters', 'Planes', 'Service',
        'Emergency', 'Military', 'Commercial', 'Trains'
    }
    return classes[classId + 1] or 'Unknown'
end

local function getVehicleName(veh)
    local model = GetEntityModel(veh)
    local label = GetDisplayNameFromVehicleModel(model)
    if label and label ~= 'CARNOTFOUND' then
        local text = GetLabelText(label)
        if text and text ~= 'NULL' then return text end
        return label
    end
    return 'Vehicle'
end

local function buildModCategory(veh, modType, tab)
    local count = GetNumVehicleMods(veh, modType)
    if count <= 0 then return nil end
    
    local title = Config.ModTypeLabels[modType] or ('MOD ' .. modType)
    local items = {}
    local price = getModPrice(modType)
    
    items[#items + 1] = {
        id = ('m%d_-1'):format(modType),
        label = 'Stock',
        price = 0,
        tab = tab,
        kind = 'mod',
        modType = modType,
        modIndex = -1
    }
    
    for i = 0, count - 1 do
        local raw = GetModTextLabel(veh, modType, i)
        local lbl = 'Option ' .. (i + 1)
        if raw and raw ~= '' then
            local gt = GetLabelText(raw)
            if gt and gt ~= 'NULL' and gt ~= '' then lbl = gt end
        end
        items[#items + 1] = {
            id = ('m%d_%d'):format(modType, i),
            label = lbl,
            price = price,
            tab = tab,
            kind = 'mod',
            modType = modType,
            modIndex = i
        }
    end
    
    return { title = title, items = items }
end

local function buildWheelTypeCategory(veh)
    SetVehicleModKit(veh, 0)
    local origType = GetVehicleWheelType(veh)
    local origMod = GetVehicleMod(veh, 23)
    local items = {}
    
    for wt = 0, 7 do
        SetVehicleWheelType(veh, wt)
        local count = GetNumVehicleMods(veh, 23)
        if count > 0 then
            local label = (Config.WheelTypeLabels[wt + 1] or ('Type ' .. wt)) .. (' (%d opts)'):format(count)
            items[#items + 1] = {
                id = 'wt_' .. wt,
                label = label,
                price = Config.WheelTypePrice,
                tab = 'visual',
                kind = 'wheelType',
                wheelType = wt
            }
        end
    end
    
    SetVehicleWheelType(veh, origType)
    SetVehicleMod(veh, 23, origMod, false)
    if #items == 0 then return nil end
    return { title = 'WHEEL TYPE', items = items }
end

local function buildLiveryCategory(veh)
    local items = {}
    local count = GetVehicleLiveryCount(veh)
    
    if count and count > 0 then
        items[#items + 1] = {
            id = 'livn_-1',
            label = 'Stock',
            price = 0,
            tab = 'visual',
            kind = 'liveryNative',
            index = -1
        }
        for i = 0, count - 1 do
            items[#items + 1] = {
                id = 'livn_' .. i,
                label = 'Livery ' .. (i + 1),
                price = Config.LiveryPrice,
                tab = 'visual',
                kind = 'liveryNative',
                index = i
            }
        end
        return { title = 'LIVERY', items = items }
    end
    
    return buildModCategory(veh, 48, 'visual')
end

local function buildExtrasCategories(veh)
    local out = {}
    for i = 1, 14 do
        if DoesExtraExist(veh, i) then
            out[#out + 1] = {
                title = 'EXTRA ' .. i,
                items = {
                    {
                        id = 'ex_' .. i .. '_0',
                        label = 'Off',
                        price = 0,
                        tab = 'visual',
                        kind = 'extra',
                        extraIndex = i,
                        extraOn = false
                    },
                    {
                        id = 'ex_' .. i .. '_1',
                        label = 'On',
                        price = Config.ExtraPrice,
                        tab = 'visual',
                        kind = 'extra',
                        extraIndex = i,
                        extraOn = true
                    }
                }
            }
        end
    end
    return out
end

local function buildPerformanceCategories(veh)
    local out = {}
    for _, modType in ipairs({ 11, 12, 13, 14, 15, 16 }) do
        local cat = buildModCategory(veh, modType, 'performance')
        if cat then out[#out + 1] = cat end
    end
    
    out[#out + 1] = {
        title = 'TURBO',
        items = {
            { id = 'tb_0', label = 'Off', price = 0, tab = 'performance', kind = 'turbo', on = false },
            { id = 'tb_1', label = 'On', price = Config.TurboPrice, tab = 'performance', kind = 'turbo', on = true }
        }
    }
    
    out[#out + 1] = {
        title = 'XENON',
        items = {
            { id = 'xn_0', label = 'Off', price = 0, tab = 'performance', kind = 'xenon', on = false },
            { id = 'xn_1', label = 'On', price = Config.XenonPrice, tab = 'performance', kind = 'xenon', on = true }
        }
    }
    
    local wheelCat = buildModCategory(veh, 23, 'performance')
    if wheelCat then
        wheelCat.title = 'WHEEL RIM'
        out[#out + 1] = wheelCat
    end
    
    return out
end

local function buildVisualCategories(veh)
    local out = {}
    local visualTypes = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 49, 53 }
    
    for _, modType in ipairs(visualTypes) do
        local cat = buildModCategory(veh, modType, 'visual')
        if cat then out[#out + 1] = cat end
    end
    
    local livery = buildLiveryCategory(veh)
    if livery then out[#out + 1] = livery end
    
    local wheelType = buildWheelTypeCategory(veh)
    if wheelType then out[#out + 1] = wheelType end
    
    for _, extra in ipairs(buildExtrasCategories(veh)) do
        out[#out + 1] = extra
    end
    
    return out
end

local function buildColorData(veh)
    local pR, pG, pB = GetVehicleCustomPrimaryColour(veh)
    local sR, sG, sB = GetVehicleCustomSecondaryColour(veh)
    local pearl, wheelColor = GetVehicleExtraColours(veh)
    
    local primaryColors = {}
    local secondaryColors = {}
    
    for i, c in ipairs(Config.ColorPalette) do
        primaryColors[#primaryColors + 1] = {
            id = 'pc_' .. i,
            rgb = { c.r, c.g, c.b },
            price = Config.ColorPrice,
            kind = 'primaryRgb',
            tab = 'colors'
        }
        secondaryColors[#secondaryColors + 1] = {
            id = 'sc_' .. i,
            rgb = { c.r, c.g, c.b },
            price = Config.ColorPrice,
            kind = 'secondaryRgb',
            tab = 'colors'
        }
    end
    
    local pearlItems = {}
    for i = 0, 159 do
        pearlItems[#pearlItems + 1] = {
            id = 'pearl_' .. i,
            index = i,
            price = Config.PearlPrice,
            kind = 'pearl',
            tab = 'colors'
        }
    end
    
    local wheelColors = {}
    for i = 0, 159 do
        wheelColors[#wheelColors + 1] = {
            id = 'wc_' .. i,
            index = i,
            price = Config.WheelColorPrice,
            kind = 'wheelColor',
            tab = 'colors'
        }
    end
    
    local interiorColors = {}
    for i = 0, 159 do
        interiorColors[#interiorColors + 1] = {
            id = 'ic_' .. i,
            index = i,
            price = Config.InteriorColorPrice,
            kind = 'interior',
            tab = 'colors'
        }
    end
    
    local dashboardColors = {}
    for i = 0, 159 do
        dashboardColors[#dashboardColors + 1] = {
            id = 'dc_' .. i,
            index = i,
            price = Config.DashboardColorPrice,
            kind = 'dashboard',
            tab = 'colors'
        }
    end
    
    local neon = {
        { id = 'neon_off', label = 'Neon Off', price = 0, kind = 'neonToggle', tab = 'colors', on = false },
        { id = 'neon_on', label = 'Neon On', price = Config.NeonPrice, kind = 'neonToggle', tab = 'colors', on = true }
    }
    
    local neonColors = {}
    for i, c in ipairs(Config.NeonPalette) do
        neonColors[#neonColors + 1] = {
            id = 'nc_' .. i,
            rgb = { c.r, c.g, c.b },
            price = Config.NeonColorPrice,
            kind = 'neonRgb',
            tab = 'colors'
        }
    end
    
    local tints = {}
    for i = 0, 5 do
        tints[#tints + 1] = {
            id = 'tint_' .. i,
            index = i,
            label = Config.TintLabels[i + 1] or ('Tint ' .. i),
            price = Config.TintPrice,
            kind = 'windowTint',
            tab = 'colors'
        }
    end
    
    local plates = {}
    for i = 0, 7 do
        plates[#plates + 1] = {
            id = 'plate_' .. i,
            index = i,
            label = 'Plate Style ' .. (i + 1),
            price = Config.PlateIndexPrice,
            kind = 'plateIndex',
            tab = 'colors'
        }
    end
    
    local xenonColors = {}
    for i = 0, Config.XenonColorCount - 1 do
        xenonColors[#xenonColors + 1] = {
            id = 'xenc_' .. i,
            index = i,
            label = 'Xenon Color ' .. (i + 1),
            price = 200,
            kind = 'xenonColor',
            tab = 'colors'
        }
    end
    
    local smokeColors = {}
    for i, c in ipairs(Config.TyreSmokePalette) do
        smokeColors[#smokeColors + 1] = {
            id = 'smk_' .. i,
            rgb = { c.r, c.g, c.b },
            price = Config.TyreSmokePrice,
            kind = 'tyreSmoke',
            tab = 'colors'
        }
    end
    
    return {
        primary = primaryColors,
        secondary = secondaryColors,
        pearl = pearlItems,
        wheelColor = wheelColors,
        interior = interiorColors,
        dashboard = dashboardColors,
        neon = neon,
        neonColors = neonColors,
        tints = tints,
        plates = plates,
        xenonColors = xenonColors,
        tyreSmoke = smokeColors,
        currentPrimary = { pR, pG, pB },
        currentSecondary = { sR, sG, sB }
    }
end

local function getVehicleStats(veh)
    local model = GetEntityModel(veh)
    local speed = math.floor((GetVehicleModelEstimatedMaxSpeed(model) or 0) * 3.6 * 0.85)
    local accel = math.floor(((GetVehicleModelAcceleration(model) or 0) * 100))
    local brake = math.floor(((GetVehicleModelMaxBraking(model) or 0) * 100))
    local traction = math.floor(((GetVehicleModelMaxTraction(model) or 0) * 100))
    return { power = traction, topSpeed = speed, acceleration = accel, brakes = brake }
end

local function openTuning(veh)
    if isOpen or veh == 0 then return end
    
    currentVehicle = veh
    savedVehicleProps = ESX.Game.GetVehicleProperties(veh)
    isOpen = true
    isPointerOverUi = false
    
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    FreezeEntityPosition(veh, true)
    SetVehicleEngineOn(veh, true, true, false)
    createCamera(veh)
    
    local model = GetEntityModel(veh)
    local classId = GetVehicleClass(veh)
    local stats = getVehicleStats(veh)
    local powerScore = math.min(100, math.floor((stats.acceleration + stats.brakes + stats.power) / 3))
    local make = GetMakeNameFromVehicleModel(model)
    local brand = ''
    
    if make and make ~= '' and make ~= 'CARNOTFOUND' then
        brand = GetLabelText(make)
        if brand == 'NULL' then brand = make end
    end
    
    SendNUIMessage({
        type = 'leon_open',
        vehicle = {
            classLabel = getVehicleClassName(classId),
            brand = brand,
            modelName = getVehicleName(veh),
            powerScore = powerScore,
            stats = stats
        },
        visual = buildVisualCategories(veh),
        performance = buildPerformanceCategories(veh),
        colors = buildColorData(veh)
    })
end

local function closeTuning(restore)
    if not isOpen then return end
    
    isOpen = false
    isPointerOverUi = false
    destroyCamera()
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'leon_hide' })
    
    if restore and currentVehicle ~= 0 and savedVehicleProps then
        ESX.Game.SetVehicleProperties(currentVehicle, savedVehicleProps)
    end
    
    if currentVehicle ~= 0 then
        FreezeEntityPosition(currentVehicle, false)
    end
    
    currentVehicle = 0
    savedVehicleProps = nil
end

local function applyModPreview(data)
    local veh = currentVehicle
    if veh == 0 then return end
    
    SetVehicleModKit(veh, 0)
    
    if data.kind == 'mod' then
        SetVehicleMod(veh, data.modType, data.modIndex, false)
    elseif data.kind == 'turbo' then
        ToggleVehicleMod(veh, 18, data.on)
    elseif data.kind == 'xenon' then
        ToggleVehicleMod(veh, 22, data.on)
    elseif data.kind == 'wheelType' then
        SetVehicleWheelType(veh, data.wheelType)
        local cur = GetVehicleMod(veh, 23)
        local cnt = GetNumVehicleMods(veh, 23)
        if cnt > 0 then
            if cur < 0 then
                SetVehicleMod(veh, 23, 0, false)
            else
                SetVehicleMod(veh, 23, math.min(cur, cnt - 1), false)
            end
        end
    elseif data.kind == 'liveryNative' then
        if data.index < 0 then
            local ok = pcall(function() ClearVehicleLivery(veh) end)
            if not ok then SetVehicleLivery(veh, 0) end
        else
            SetVehicleLivery(veh, data.index)
        end
    elseif data.kind == 'extra' then
        SetVehicleExtra(veh, data.extraIndex, data.extraOn and 0 or 1)
    elseif data.kind == 'primaryRgb' then
        local r, g, b = table.unpack(data.rgb)
        SetVehicleCustomPrimaryColour(veh, r, g, b)
    elseif data.kind == 'secondaryRgb' then
        local r, g, b = table.unpack(data.rgb)
        SetVehicleCustomSecondaryColour(veh, r, g, b)
    elseif data.kind == 'pearl' then
        local _, wheel = GetVehicleExtraColours(veh)
        SetVehicleExtraColours(veh, data.index, wheel)
    elseif data.kind == 'wheelColor' then
        local pearl, _ = GetVehicleExtraColours(veh)
        SetVehicleExtraColours(veh, pearl, data.index)
    elseif data.kind == 'interior' then
        SetVehicleInteriorColour(veh, data.index)
    elseif data.kind == 'dashboard' then
        SetVehicleDashboardColour(veh, data.index)
    elseif data.kind == 'neonToggle' then
        for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, data.on) end
    elseif data.kind == 'neonRgb' then
        local r, g, b = table.unpack(data.rgb)
        SetVehicleNeonLightsColour(veh, r, g, b)
    elseif data.kind == 'windowTint' then
        SetVehicleWindowTint(veh, data.index)
    elseif data.kind == 'plateIndex' then
        SetVehicleNumberPlateTextIndex(veh, data.index)
    elseif data.kind == 'xenonColor' then
        SetVehicleXenonLightsColorIndex(veh, data.index)
    elseif data.kind == 'tyreSmoke' then
        ToggleVehicleMod(veh, 20, true)
        local r, g, b = table.unpack(data.rgb)
        SetVehicleTyreSmokeColor(veh, r, g, b)
    end
end

RegisterNUICallback('leon_preview', function(body)
    if body and body.item then
        applyModPreview(body.item)
    end
end)

RegisterNUICallback('leon_cart', function()
end)

RegisterNUICallback('leon_pointer', function(body)
    isPointerOverUi = body and body.overUi == true
end)

RegisterNUICallback('leon_close', function()
    closeTuning(true)
end)

RegisterNUICallback('leon_install', function(body, cb)
    local total = math.floor(tonumber(body and body.total) or 0)
    ESX.TriggerServerCallback('leon:tuning:pay', function(success)
        if success then
            showNotification('Tuning paid: $' .. total)
            closeTuning(false)
            cb({ ok = true })
        else
            if currentVehicle ~= 0 and savedVehicleProps then
                ESX.Game.SetVehicleProperties(currentVehicle, savedVehicleProps)
            end
            showNotification('Not enough money')
            cb({ ok = false })
        end
    end, total)
end)

CreateThread(function()
    while true do
        if not isOpen then
            Wait(200)
        else
            Wait(0)
            
            DisableControlAction(0, 0, true)
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 3, true)
            DisableControlAction(0, 4, true)
            DisableControlAction(0, 5, true)
            DisableControlAction(0, 6, true)
            DisableControlAction(0, 66, true)
            DisableControlAction(0, 67, true)
            DisableControlAction(0, 95, true)
            DisableControlAction(0, 98, true)
            DisableControlAction(0, 106, true)
            DisableControlAction(0, 282, true)
            DisableControlAction(0, 283, true)
            DisableControlAction(0, 284, true)
            DisableControlAction(0, 285, true)
            DisableControlAction(0, 286, true)
            DisableControlAction(0, 287, true)
            DisableControlAction(0, 220, true)
            DisableControlAction(0, 221, true)
            DisableControlAction(0, 290, true)
            DisableControlAction(0, 291, true)
            DisableControlAction(0, 329, true)
            DisableControlAction(0, 330, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 63, true)
            DisableControlAction(0, 64, true)
            
            if currentVehicle ~= 0 and DoesEntityExist(currentVehicle) then
                updateCamera(currentVehicle)
            end
            
            if currentVehicle ~= 0 and DoesEntityExist(currentVehicle) and not isPointerOverUi then
                local step = (Config.RotateKeyDegPerSec or 58.0) * GetFrameTime()
                local left = IsDisabledControlPressed(0, 34) or IsControlPressed(0, 34) or IsDisabledControlPressed(0, 63) or IsControlPressed(0, 63)
                local right = IsDisabledControlPressed(0, 35) or IsControlPressed(0, 35) or IsDisabledControlPressed(0, 64) or IsControlPressed(0, 64)
                
                if left and not right then
                    SetEntityHeading(currentVehicle, normalizeHeading(GetEntityHeading(currentVehicle) - step))
                elseif right and not left then
                    SetEntityHeading(currentVehicle, normalizeHeading(GetEntityHeading(currentVehicle) + step))
                end
            end
        end
    end
end)

CreateThread(function()
    local coords = Config.Tuning.coords
    while true do
        local sleep = 1000
        if not isOpen then
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            local dist = #(pedCoords - coords)
            
            if dist < 40.0 then
                sleep = 0
                if dist < Config.InteractDistance then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                        ESX.ShowHelpNotification('Press ~INPUT_CONTEXT~ to tune vehicle')
                        if IsControlJustReleased(0, Config.InteractKey) then
                            openTuning(veh)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocusKeepInput(false)
    destroyCamera()
    if isOpen then
        closeTuning(true)
    end
end)
