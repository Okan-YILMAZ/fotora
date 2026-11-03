--[[ Fotora'nın okuyamadığı kareler (uygulama okunamayanlar.json'a yazar; ör. macOS'un açamadığı eski RAW'lar):
1. LrC'nin kendi önizlemesi onizleme/<uuid>.jpg olarak bırakılır; Fotora bir sonraki taramada kareyi ondan tarar.
   Önizleme LrC'deki düzenlemeleri de içerir; yalnız okunamayan karelerde kullanılır.
2. Kareler "Fotora" kümesinde "Okunamayanlar" koleksiyonunda toplanır (kullanıcı LrC'de görsün diye).
Eşitlemede (menü ya da LrC açılışı) çağrılır; görev içinden. ]]
local LrApplication = import 'LrApplication'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'
local json = require 'json'
local L = require 'Dil'

local M = {}

function M.isle(klasor)
    local dosya = LrPathUtils.child(klasor, 'okunamayanlar.json')
    if not LrFileUtils.exists(dosya) then return end
    local ok, kimlikler = pcall(json.decode, LrFileUtils.readFile(dosya))
    if not ok or type(kimlikler) ~= 'table' then return end
    local catalog = LrApplication.activeCatalog()
    local onizleme = LrPathUtils.child(klasor, 'onizleme')
    LrFileUtils.createAllDirectories(onizleme)

    local kareler, bekleyen, istekler = {}, 0, {}
    for _, u in ipairs(kimlikler) do
        local p = catalog:findPhotoByUuid(u)
        if p then
            kareler[#kareler + 1] = p
            local hedef = LrPathUtils.child(onizleme, u .. '.jpg')
            if not LrFileUtils.exists(hedef) then
                bekleyen = bekleyen + 1
                -- Dönen nesne tutulmalı; yoksa istek iptal olabilir.
                istekler[#istekler + 1] = p:requestJpegThumbnail(1024, 1024, function(veri)
                    if veri then
                        local f = io.open(hedef, 'wb')
                        if f then f:write(veri); f:close() end
                    end
                    bekleyen = bekleyen - 1
                end)
            end
        end
    end
    local sure = 0
    while bekleyen > 0 and sure < 60 do LrTasks.sleep(0.5); sure = sure + 0.5 end

    if #kareler == 0 then
        -- Okunamayan kalmadı (ör. hepsi önizlemeden tarandı): eski "Okunamayanlar" koleksiyonu silinir.
        for _, kume in ipairs(catalog:getChildCollectionSets()) do
            if kume:getName() == 'Fotora' then
                for _, kol in ipairs(kume:getChildCollections()) do
                    if kol:getName() == L('Okunamayanlar', 'Unreadable') or kol:getName() == 'Okunamayanlar' or kol:getName() == 'Unreadable' then
                        catalog:withWriteAccessDo('Fotora okunamayanlar', function() kol:delete() end)
                    end
                end
            end
        end
        return
    end
    local kume, kol
    catalog:withWriteAccessDo('Fotora koleksiyon kümesi', function()
        kume = catalog:createCollectionSet('Fotora', nil, true)
    end)
    catalog:withWriteAccessDo('Fotora okunamayanlar', function()
        kol = catalog:createCollection(L('Okunamayanlar', 'Unreadable'), kume, true)
    end)
    catalog:withWriteAccessDo('Fotora okunamayanlar', function()
        kol:removeAllPhotos()
        kol:addPhotos(kareler)
    end)
end

return M
