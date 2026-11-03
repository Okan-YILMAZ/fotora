--[[ Library › Plug-in Extras › Fotora › Find Similar Groups…
Seçili ya da görünen karelerde (ya da bütün katalogda) birbirine çok benzeyen kareleri gruplar. Her grup
"Fotora › Benzer: …" kümesinde bir koleksiyon olur. Fotora hiçbir kareyi silmez ya da işaretlemez; kararı kullanıcı verir. ]]
local L = require 'Dil'
local LrApplication = import 'LrApplication'
local LrBinding = import 'LrBinding'
local LrDate = import 'LrDate'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrPrefs = import 'LrPrefs'
local LrProgressScope = import 'LrProgressScope'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local Baglanti = require 'Baglanti'
local Kapsam = require 'Kapsam'
local Sonuclar = require 'Sonuclar'

local EN_COK = 500 -- koleksiyon olarak gösterilen grup sayısı; Collections paneli boğulmasın

LrTasks.startAsyncTask(function()
    LrFunctionContext.callWithContext('FotoraGruplar', function(context)
        LrDialogs.attachErrorDialogToFunctionContext(context)
        local prefs = LrPrefs.prefsForPlugin()
        local catalog = LrApplication.activeCatalog()
        local k = Kapsam.oku(catalog)
        local secenekler, varsayilan = Kapsam.secenekler(k)
        local p = LrBinding.makePropertyTable(context)
        p.kapsam = varsayilan
        p.esik = prefs.grupEsik or 'sahne'
        local f = LrView.osFactory()
        local icerik = f:column {
            bind_to_object = p,
            spacing = f:control_spacing(),
            f:row {
                f:static_text { title = L('Nerede:', 'Where:') },
                f:popup_menu { value = LrView.bind('kapsam'), items = secenekler },
            },
            f:static_text { title = L('Ne kadar benzer?', 'How similar?') },
            f:radio_button { title = L('Aynı sahnenin kareleri (küçük açı ya da an farkı)', 'Photos of the same scene (small change of angle or moment)'),
                value = LrView.bind('esik'), checked_value = 'sahne' },
            f:radio_button { title = L('Neredeyse aynı kareler (kopyalar, art arda çekilenler)', 'Nearly identical photos (duplicates, burst shots)'),
                value = LrView.bind('esik'), checked_value = 'ayni' },
            f:static_text { title = L('Fotora hiçbir kareyi silmez ya da işaretlemez. Her grup ayrı bir koleksiyon olur; kararı siz verirsiniz.',
                'Fotora never deletes or marks a photo. Each group becomes a collection; you decide what to keep.'),
                width_in_chars = 50, height_in_lines = 2, font = '<system/small>' },
        }
        if LrDialogs.presentModalDialog { title = L('Fotora: Benzer Grupları Bul', 'Fotora: Find Similar Groups'), contents = icerik,
            actionVerb = L('Bul', 'Find') } ~= 'ok' then return end
        prefs.grupEsik = p.esik

        local ilerleme = LrProgressScope { title = L('Fotora: benzer gruplar aranıyor', 'Fotora: finding similar groups'), functionContext = context }
        ilerleme:setIndeterminate()
        local t0 = LrDate.currentTime()
        local numaralar = Kapsam.numaralar(catalog, k, p.kapsam)
        -- Bütün katalog bu Mac'te yaklaşık bir dakika sürer (200 bin kare, 10 Ekim 2026); pay bırakıldı.
        local cevap, hata = Baglanti.istek('/gruplar', { katalog = Baglanti.katalog(), numaralar = numaralar, esik = p.esik }, 900)
        if not cevap or cevap.hata then
            ilerleme:done()
            LrDialogs.message('Fotora', hata or cevap.hata, 'warning')
            return
        end
        local gruplar = cevap.gruplar or {}
        if #gruplar == 0 then
            ilerleme:done()
            LrDialogs.message('Fotora', L('Birbirine bu kadar benzeyen kare bulunamadı.', 'No photos are this similar to each other.'), 'info')
            return
        end

        -- Kareler LrC'de bulunur; kümeyi oluşturmak, içine koleksiyon açmak ve doldurmak ayrı yazma bloklarında (LrC kısıtı).
        local liste, kareSayisi = {}, 0
        for i = 1, math.min(#gruplar, EN_COK) do
            local kareler = {}
            for _, u in ipairs(gruplar[i]) do
                local foto = catalog:findPhotoByUuid(u)
                if foto then kareler[#kareler + 1] = foto end
            end
            if #kareler > 1 then liste[#liste + 1] = kareler; kareSayisi = kareSayisi + #kareler end
        end
        local fotora
        catalog:withWriteAccessDo('Fotora koleksiyon kümesi', function() fotora = catalog:createCollectionSet('Fotora', nil, true) end)
        local kaynak = p.kapsam == 'katalog' and L('bütün katalog', 'whole catalog')
            or p.kapsam == 'secili' and string.format(L('%d seçili kare', '%d selected photos'), #(k.secim or {}))
            or k.ad or L('görünen kareler', 'photos shown')
        local kume = Sonuclar.yeniAdla(L('Benzer: ', 'Similar: ') .. kaynak, function(ad)
            local s
            catalog:withWriteAccessDo('Fotora benzer grupları', function() s = catalog:createCollectionSet(ad, fotora, false) end)
            return s
        end)
        if not kume then ilerleme:done(); return end
        local kollar = {}
        catalog:withWriteAccessDo('Fotora benzer grupları', function()
            for i, kareler in ipairs(liste) do
                kollar[i] = catalog:createCollection(string.format(L('%03d (%d kare)', '%03d (%d photos)'), i, #kareler), kume, false)
            end
        end)
        catalog:withWriteAccessDo('Fotora benzer grupları', function()
            for i, kareler in ipairs(liste) do kollar[i]:addPhotos(kareler) end
        end)
        ilerleme:done()
        require('Gunluk')(string.format('benzer gruplar: %d grup (%.1f sn)', #liste, LrDate.currentTime() - t0))
        if kollar[1] then catalog:setActiveSources { kollar[1] } end
        local mesaj = string.format(L('%d grup, toplam %d kare. Gruplar Collections panelinde Fotora altında.', '%d groups, %d photos in all. The groups are in the Collections panel under Fotora.'),
            #liste, kareSayisi)
        if #gruplar > EN_COK then
            mesaj = mesaj .. '\n\n' .. string.format(L('%d grup bulundu; ilk %d tanesi gösterildi. Daha dar bir alanda (bir klasör ya da koleksiyon) deneyin.',
                '%d groups were found; the first %d are shown. Try a smaller set of photos (a folder or a collection).'), #gruplar, EN_COK)
        end
        if (cevap.taranmamis or 0) > 0 then
            mesaj = mesaj .. '\n\n' .. string.format(L('%d kare henüz taranmadığı için gruplara katılmadı.', '%d photos have not been scanned yet and were left out.'), cevap.taranmamis)
        end
        LrDialogs.message('Fotora', mesaj, 'info')
    end)
end)
