--[[ Sonuçları benzerlik sırasıyla gösteren yüzen pencere (Vektörel Arama'nın SortedView.lua'sından uyarlandı).
LrC koleksiyonun sırasını belirlemeye izin vermiyor; sıralı sonucu göstermenin yolu kendi penceremiz.
Açıkken LrC kullanılabilir. Küçük resme tıklamak kareyi LrC'de seçer (gerekirse önce sonuç koleksiyonuna döner).
Sayfa değişince pencere kapanıp yeni sayfayla aynı yerde açılır. goster() bir görev içinden çağrılır (blockTask). ]]
local L = require 'Dil'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'

local M = {}
local SAYFA, SUTUN, BOY = 60, 5, 150
local acikKapat = nil -- yeni arama eskisinin penceresini kapatır
local acikOne = nil  -- açık pencereyi öne getirir (LrC tam ekrandayken pencere arkada kalabiliyor)

--- Açık sıralı sonuç penceresini öne getirir; açık değilse false döner (menü: OneGetir.lua).
function M.oneGetir()
    if acikOne then acikOne(); return true end
    return false
end

-- Tıklanan kare görünüm nesnesinden çözülür: LrC bir penceredeki bütün catalog_photo'lar için
-- son tanımlanan mouse_down'ı çağırıyor (LrSkorer'da görüldü).
local function sec(gorunum, kareOf, kol)
    local kare = kareOf[gorunum]
    if not kare then return end
    LrTasks.startAsyncTask(function()
        local catalog = LrApplication.activeCatalog()
        local aktif = catalog:getActiveSources()
        if not (#aktif == 1 and type(aktif[1]) == 'table' and aktif[1].localIdentifier == kol.localIdentifier) then
            catalog:setActiveSources { kol }
        end
        catalog:setSelectedPhotos(kare, {})
        -- Seçim ızgarayı öne alır; tam ekranda pencere arkada kalmasın diye yeniden öne getirilir.
        if acikOne then acikOne() end
    end)
end

-- Sihirbazın renkleri (tasarım tuvali, onaylı kimlik)
local LrColor = import 'LrColor'
local MUREKKEP = LrColor(0x1A / 255, 0x1B / 255, 0x1F / 255)
local IKINCIL = LrColor(0x5C / 255, 0x5F / 255, 0x66 / 255)
local KUM = LrColor(0xF4 / 255, 0xF3 / 255, 0xF1 / 255)
local BEYAZ = LrColor(1, 1, 1)

--- kareler: sıralı LrPhoto listesi; etiketler: her karenin altındaki yazı;
--- bilgi: { arama = arama metni, koleksiyon = koleksiyon adı }; kol: sonuç koleksiyonu
function M.goster(kareler, etiketler, bilgi, kol)
    if acikKapat then LrTasks.pcall(acikKapat); acikKapat = nil end
    local sayfaSayisi = math.max(1, math.ceil(#kareler / SAYFA))
    local sayfa = 1
    local genislik = SUTUN * (BOY + 12) + 24
    while sayfa do
        local f = LrView.osFactory()
        local ilk, son = (sayfa - 1) * SAYFA + 1, math.min(sayfa * SAYFA, #kareler)
        local sonraki, kapat = nil, nil
        local satirlar, kareOf = {}, {}
        local function tikla(g) sec(g, kareOf, kol) end
        for i = ilk, son do
            if (i - ilk) % SUTUN == 0 then satirlar[#satirlar + 1] = { spacing = 12 } end
            -- Yalnız çalıştığı bilinen özellikler: çerçeve/zemin rengi verilince tıklama kayboldu (9 Ekim 2026).
            local k = f:catalog_photo { photo = kareler[i], width = BOY, height = BOY, mouse_down = tikla }
            kareOf[k] = kareler[i]
            local satir = satirlar[#satirlar]
            satir[#satir + 1] = f:column { spacing = 4, k,
                f:static_text { title = etiketler[i] ~= '' and etiketler[i] or tostring(i), width = BOY, alignment = 'center',
                    font = '<system/small>', text_color = IKINCIL } }
        end
        local izgara = { spacing = 14, margin = 12 }
        for _, r in ipairs(satirlar) do izgara[#izgara + 1] = f:row(r) end
        local function git(p) return function() sonraki = p; if kapat then kapat() end end end
        local function etiketli(etiket, deger, uzunluk)
            return f:row { spacing = 4,
                f:static_text { title = etiket, font = '<system/bold>', text_color = MUREKKEP },
                f:static_text { title = deger, text_color = MUREKKEP, width_in_chars = uzunluk, truncation = 'middle' } }
        end

        local ust = f:column {
            spacing = 6, margin_horizontal = 16, margin_vertical = 12,
            f:row { spacing = 10,
                f:picture { value = LrPathUtils.child(_PLUGIN.path, 'logo.png'), width = 44, height = 44 },
                -- Genişlikler açık verilir: fill_horizontal düğmeyi pencere sınırının dışına itiyordu (10 Ekim 2026).
                f:static_text { title = 'Fotora', font = { name = '<system/bold>', size = 26 }, text_color = MUREKKEP,
                    width = genislik - 32 - 44 - 20 - 150 },
                f:push_button { title = L('Yeni arama…', 'New search…'), width = 150, action = function() require('Arama').ac() end } },
            etiketli(L('Arama Metni:', 'Search text:'), bilgi.arama, 60),
            f:row { spacing = 24,
                etiketli(L('Sonuç Sayısı:', 'Results:'), string.format(L('%d (en benzer kare en başta)', '%d (most similar first)'), #kareler), 26),
                etiketli(L('Koleksiyon Adı:', 'Collection:'), bilgi.koleksiyon, 28) },
            f:static_text { title = L('Bir kareye tıklayınca Lightroom\'da seçilir.', 'Click a photo to select it in Lightroom.'), font = '<system/small>', text_color = IKINCIL },
        }
        local icerik = f:column {
            spacing = 0,
            f:scrolled_view { width = genislik, height = 150, background_color = BEYAZ,
                horizontal_scroller = false, vertical_scroller = false, ust },
            sayfaSayisi > 1 and f:row { margin = 8,
                f:static_text { title = string.format(L('Sayfa %d / %d', 'Page %d / %d'), sayfa, sayfaSayisi), fill_horizontal = 1, text_color = IKINCIL },
                f:push_button { title = L('‹ Önceki', '‹ Previous'), enabled = sayfa > 1, action = git(sayfa - 1) },
                f:push_button { title = L('Sonraki ›', 'Next ›'), enabled = sayfa < sayfaSayisi, action = git(sayfa + 1) } } or f:spacer { height = 1 },
            f:scrolled_view { width = genislik, height = 600, background_color = KUM, horizontal_scroller = false, f:column(izgara) },
        }
        LrDialogs.presentFloatingDialog(_PLUGIN, {
            title = L('Fotora: Sıralı Sonuçlar', 'Fotora: Sorted Results'),
            contents = icerik,
            blockTask = true,
            save_frame = 'fotora_sirali_sonuclar',
            onShow = function(ctl) kapat = ctl.close; acikKapat = ctl.close; acikOne = ctl.toFront end,
        })
        if acikKapat == kapat then acikKapat = nil; acikOne = nil end
        sayfa = sonraki -- elle ya da yeni aramayla kapandıysa nil: döngü biter
    end
end

return M
