--[[ Arama sonucunu "Fotora" koleksiyon kümesinde bir koleksiyon olarak gösterir.
Aynı adla koleksiyon varsa üstüne yazılmaz, adına sıra numarası eklenir. Oluşturma ve doldurma ayrı yazma bloklarında (LrC kısıtı). ]]
local L = require 'Dil'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'
local Siralama = require 'Siralama'

local M = {}

--- Var olanın üstüne yazmadan yeni koleksiyon (ya da küme) oluşturur: ad doluysa "(2)", "(3)"... denenir.
--- olustur(ad) kendi yazma bloğunda oluşturup nesneyi döndürür. Doluluğu LrC'ye sorarız (Türkçe harf ve
--- büyük/küçük harf karşılaştırmasını LrC farklı yapıyor; Vektörel Arama'da görüldü). Dolu adda LrC bazen
--- "not unique" hatası verir, bazen nil döner; ikisi de dolu sayılır. LrTasks.pcall yazma bloğunu sarabilir (düz pcall saramaz).
--- Dönen: nesne ve kullanılan ad; olmazsa kullanıcıya söylenir ve nil döner.
function M.yeniAdla(ad, olustur)
    for n = 1, 50 do
        local denenen = n == 1 and ad or string.format('%s (%d)', ad, n)
        local nesne
        local ok, hata = LrTasks.pcall(function() nesne = olustur(denenen) end)
        if ok and nesne then return nesne, denenen end
        if not ok and not tostring(hata):find('not unique', 1, true) then error(hata, 0) end
    end
    LrDialogs.message('Fotora', L('Oluşturulamadı: "' .. ad .. '" adıyla 50 koleksiyon zaten var.', 'Could not create it: 50 collections named "' .. ad .. '" already exist.'), 'warning')
end

--- ad: koleksiyon adı; arama: pencerede gösterilecek arama metni; onde: (Benzer) seçili kare, listenin başına
function M.goster(ad, cevap, onde, arama)
    local catalog = LrApplication.activeCatalog()
    local kareler, etiketler = { onde }, { onde and L('seçili kare', 'selected photo') or nil }
    for _, u in ipairs(cevap.sonuc or {}) do
        local p = catalog:findPhotoByUuid(u)
        if p then
            kareler[#kareler + 1] = p
            etiketler[#etiketler + 1] = '' -- oran gösterilmez: düşük sayılar (%8-15) güven sarsıyor
        end
    end
    if #kareler == 0 then
        LrDialogs.message('Fotora', L('Sonuç bulunamadı.', 'No results found.'), 'info')
        return
    end
    local kume
    catalog:withWriteAccessDo('Fotora koleksiyon kümesi', function()
        kume = catalog:createCollectionSet('Fotora', nil, true)
    end)
    local kol
    kol, ad = M.yeniAdla(ad, function(denenen)
        local k
        catalog:withWriteAccessDo('Fotora koleksiyonu', function() k = catalog:createCollection(denenen, kume, false) end)
        return k
    end)
    if not kol then return end
    catalog:withWriteAccessDo('Fotora sonuçları', function()
        kol:addPhotos(kareler)
    end)
    catalog:setActiveSources { kol }
    if cevap.toplam and cevap.taranan and cevap.toplam > 0 and cevap.taranan < cevap.toplam then
        LrDialogs.showBezel(string.format(L('Kataloğun %%%d kadarı tarandı; sonuçlar eksik olabilir', 'Only %d%% of the catalog is scanned; results may be incomplete'),
            math.floor(100 * cevap.taranan / cevap.toplam)), 3)
    end
    if LrPrefs.prefsForPlugin().siraliPencere then Siralama.goster(kareler, etiketler, { arama = arama or ad, koleksiyon = ad }, kol) end
end

return M
