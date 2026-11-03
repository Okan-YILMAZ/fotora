-- Gündelik dille arama penceresi: menüden (Ara.lua) ve sıralı sonuç penceresinin "Yeni arama" düğmesinden açılır.
local L = require 'Dil'
local LrApplication = import 'LrApplication'
local LrBinding = import 'LrBinding'
local LrPathUtils = import 'LrPathUtils'
local LrDate = import 'LrDate'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local Baglanti = require 'Baglanti'
local Kapsam = require 'Kapsam'
local Sonuclar = require 'Sonuclar'

local M = {}

function M.ac()
LrTasks.startAsyncTask(function()
    LrFunctionContext.callWithContext('FotoraAra', function(context)
        LrDialogs.attachErrorDialogToFunctionContext(context)
        local prefs = LrPrefs.prefsForPlugin()
        local catalog = LrApplication.activeCatalog()
        local k = Kapsam.oku(catalog)
        local secenekler, varsayilan = Kapsam.secenekler(k)
        local p = LrBinding.makePropertyTable(context)
        -- Hatırlanmaz: bir koleksiyondayken bütün katalogda aramak sürpriz oldu (Okan, 10 Ekim 2026).
        p.kapsam = varsayilan
        p.metin = prefs.sonMetin or ''
        p.adet = prefs.adet or 100
        p.siraliPencere = prefs.siraliPencere or false
        local f = LrView.osFactory()
        -- Açıklamalar (?) simgesinin ipucunda; yalnız İngilizce ipucu sürekli görünür (Okan, 12 Ekim 2026).
        local function yardim(metin)
            return f:picture { value = LrPathUtils.child(_PLUGIN.path, 'yardim.png'), width = 16, height = 16, tooltip = metin, place_vertical = 0.5 }
        end
        local function etiket(baslik, metin)
            return f:row { spacing = f:label_spacing(), f:static_text { title = baslik, tooltip = metin }, yardim(metin) }
        end
        -- Yazı, denetim, (?) yan yana; denetim sağa yaslanmaz.
        local function satir(baslik, metin, denetim)
            return f:row { spacing = f:label_spacing(), f:static_text { title = baslik, tooltip = metin }, denetim, yardim(metin) }
        end
        local icerik = f:column {
            bind_to_object = p,
            spacing = f:control_spacing(),
            etiket(L('Katalog: ', 'Catalog: ') .. LrPathUtils.leafName(LrApplication.activeCatalog():getPath()),
                L('Arama yalnız Lightroom\'da açık olan katalogda yapılır.', 'The search runs only in the catalog open in Lightroom.')),
            etiket(L('Ne arıyorsunuz?', 'What are you looking for?'),
                L('Örnek: "sisli ormanda yürüyen biri" gibi gündelik dille arayabilirsiniz.', 'Example: you can search in everyday language, like "someone walking in a misty forest".')),
            f:edit_field { value = LrView.bind('metin'), width_in_chars = 50, immediate = true },
            f:static_text { title = L('İpucu: İngilizce aramak doğru fotoğraflara ulaşma şansını yükseltebilir.', 'Tip: if you don\'t find the right photos, try describing them differently.'),
                font = '<system/small>' },
            satir(L('Nerede:', 'Where:'), L('Arama kapsamını klasör ya da koleksiyonla sınırlayabilirsiniz.', 'You can limit the search to a folder or a collection.'),
                f:popup_menu { value = LrView.bind('kapsam'), items = secenekler }),
            etiket(L('Koleksiyon adı (isteğe bağlı)', 'Collection name (optional)'),
                L('Sonuçlar vereceğiniz adla, boş bırakırsanız arama cümlesiyle Fotora koleksiyonlarına eklenir.', 'Results are added to the Fotora collections under the name you give, or under the search text if left empty.')),
            f:edit_field { value = LrView.bind('koleksiyon'), width_in_chars = 50 },
            -- min/max şart: verilmezse LrC sessizce 0-100 aralığı uygular.
            satir(L('Sonuç sayısı:', 'Number of results:'), L('1 ile 5000 arasında seçebilirsiniz.', 'You can choose between 1 and 5000.'),
                f:edit_field { value = LrView.bind('adet'), width_in_chars = 6, precision = 0, min = 1, max = 5000 }),
            f:row { spacing = f:label_spacing(),
                f:checkbox { title = L('Sonuçları sıralı olarak ayrı pencerede göster', 'Show results in order in a separate window'), value = LrView.bind('siraliPencere') },
                yardim(L('Seçilmezse sonuçlar sırasız olarak Lightroom koleksiyonunda gösterilir.', 'If not selected, results are shown unordered in a Lightroom collection.')),
            },
        }
        if LrDialogs.presentModalDialog { title = L('Fotora: Gündelik Dille Ara', 'Fotora: Search in Everyday Language'), contents = icerik, actionVerb = L('Ara', 'Search') } ~= 'ok' then return end
        local metin = (p.metin or ''):gsub('^%s+', ''):gsub('%s+$', '')
        if metin == '' then return end
        prefs.sonMetin, prefs.adet, prefs.siraliPencere = metin, p.adet, p.siraliPencere
        local t0 = LrDate.currentTime()
        local cevap, hata = Baglanti.istek('/ara', { katalog = Baglanti.katalog(), metin = metin, adet = p.adet,
            numaralar = Kapsam.numaralar(catalog, k, p.kapsam) })
        if not cevap or cevap.hata then
            LrDialogs.message('Fotora', hata or cevap.hata, 'warning')
            return
        end
        require('Gunluk')(string.format('arama: %.1f sn', LrDate.currentTime() - t0))
        local ad = (p.koleksiyon or ''):gsub('^%s+', ''):gsub('%s+$', '')
        Sonuclar.goster(ad ~= '' and ad or (L('Ara: ', 'Search: ') .. metin:sub(1, 60)), cevap, nil, metin)
    end)
end)
end

return M
