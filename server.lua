local ESX = exports['es_extended']:getSharedObject()

ESX.RegisterServerCallback('leon:tuning:pay', function(source, cb, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb(false)
        return
    end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 0 then
        cb(false)
        return
    end
    if amount > Config.MaxCharge then
        cb(false)
        return
    end
    if amount == 0 then
        cb(true)
        return
    end
    local cash = xPlayer.getMoney()
    if cash >= amount then
        xPlayer.removeMoney(amount)
        cb(true)
    else
        cb(false)
    end
end)
