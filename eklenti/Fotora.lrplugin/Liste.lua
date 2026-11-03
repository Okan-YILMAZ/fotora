--[[ Kare listesini LrC'nin kendi yoluyla (SDK) alır ve tarama uygulaması için dosyaya yazar.
Katalog dosyasına dokunmaz, kataloğa yazmaz.

Çıktı: ~/Library/Application Support/Fotora/kataloglar/<katalog yolunun MD5'i>/
  liste.jsonl  her satır bir kare: {"yerel","uuid","yol","bicim","sanal","asil_uuid"} (yerel: LrC'nin kare numarası)
  liste.json   özet: katalog yolu, sayılar, aşama süreleri, tarih
Dosyalar önce .gecici adıyla yazılır, bitince yerine taşınır (yarım liste bırakmamak için).
İki yerden çağrılır: menü (KareListesi.lua) ve LrC açılışı (Baslat.lua, sessiz). ]]

local L = require 'Dil'
local LrApplication = import 'LrApplication'
local LrDate = import 'LrDate'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrMD5 = import 'LrMD5'
local LrPathUtils = import 'LrPathUtils'
local LrProgressScope = import 'LrProgressScope'
local LrTasks = import 'LrTasks'

local PARTI = 5000 -- batchGetRawMetadata başına kare
local SURUM = 2 -- liste biçimi; 2: kare numarası (yerel) eklendi, 10 Ekim 2026

local function js(s)
    if s == nil then return 'null' end
    s = tostring(s):gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == '\\' then return '\\\\' end
        return string.format('\\u%04x', c:byte())
    end)
    return '"' .. s .. '"'
end

local function yerineKoy(gecici, hedef)
    for _ = 1, 3 do
        if LrFileUtils.exists(hedef) then LrFileUtils.delete(hedef) end
        if LrFileUtils.move(gecici, hedef) then return end
        LrTasks.sleep(0.2)
    end
    error('Dosya taşınamadı: ' .. hedef)
end

local M = {}
-- Aynı anda iki eşitleme olmasın: kurulumda açılış eşitlemesi (Baslat.lua) ile menüden eşitleme çakışınca
-- aynı geçici dosyayı yazıp birbirinin dosyasını taşıyordu (Mac Mini, 10 Ekim 2026: "Dosya taşınamadı").
local calisiyor = false

function M.hazirla(context, sessiz)
    if calisiyor then
        if sessiz then return end -- açılış eşitlemesi: menüden başlatılan zaten yapıyor
        while calisiyor do LrTasks.sleep(0.5) end -- menü: süren eşitleme bitsin, sonra yeniden yaz
    end
    calisiyor = true
    context:addCleanupHandler(function() calisiyor = false end)
    local catalog = LrApplication.activeCatalog()
    local katalogYolu = catalog:getPath()
    -- 'appData' LrC'nin kendi klasörünü verir (Adobe/Lightroom); Fotora'nın verisi kendi klasöründe durur.
    local klasor = LrPathUtils.getStandardFilePath('home')
    for _, ad in ipairs { 'Library', 'Application Support', 'Fotora', 'kataloglar', LrMD5.digest(katalogYolu) } do
        klasor = LrPathUtils.child(klasor, ad)
    end
    LrFileUtils.createAllDirectories(klasor)

    -- Sessizde ilerleme çubuğu yok; iptal edilemez ama kısa sürer (200 bin karede ~8 sn).
    local ilerleme = sessiz and { isCanceled = function() return false end, setPortionComplete = function() end, done = function() end }
        or LrProgressScope { title = L('Fotora: fotoğraf listesi eşitleniyor', 'Fotora: syncing photo list') }
    if not sessiz then ilerleme:attachToFunctionContext(context) end

    local gunluk = require 'Gunluk'
    gunluk(sessiz and 'eşitleme başladı (Lightroom açılışı)' or 'eşitleme başladı (menü)')
    -- Fotora'nın okuyamadığı kareler: LrC önizlemesi ve "Okunamayanlar" koleksiyonu (sayı değişmese de).
    require('Okunamayanlar').isle(klasor)

    local t0 = LrDate.currentTime()
    local kareler = catalog:getAllPhotos()
    local t1 = LrDate.currentTime()
    -- LrC açılışında (sessiz) fotoğraf sayısı son listeyle aynıysa liste yeniden yazılmaz: açılışa yük bindirmemek için.
    -- Elle "Eşitle" her zaman yazar.
    if sessiz then
        local o = LrPathUtils.child(klasor, 'liste.json')
        local eski = LrFileUtils.exists(o) and LrFileUtils.readFile(o) or ''
        -- Liste biçimi değiştiyse (SURUM) sayı aynı olsa da yeniden yazılır.
        if tonumber(eski:match('"toplam":(%d+)')) == #kareler and tonumber(eski:match('"surum":(%d+)')) == SURUM then
            gunluk(string.format('eşitleme bitti: değişiklik yok (%.1f sn)', LrDate.currentTime() - t0))
            return
        end
    end

    local listeYolu = LrPathUtils.child(klasor, 'liste.jsonl')
    -- Her eşitleme kendi geçici adını kullanır: kilit iki görev arasında paylaşılmasa da dosyalar çakışmaz.
    local ek = string.format('.%d.gecici', math.floor(LrDate.currentTime() * 1000) % 1000000000)
    local f = assert(io.open(listeYolu .. ek, 'w'))
    local sayi = { toplam = #kareler, sanal = 0, video = 0, yazilan = 0 }
    local sanallar = {}
    local tOkuma = 0

    for bas = 1, #kareler, PARTI do
        if ilerleme:isCanceled() then
            f:close()
            LrFileUtils.delete(listeYolu .. ek)
            return
        end
        local parti = {}
        for i = bas, math.min(bas + PARTI - 1, #kareler) do parti[#parti + 1] = kareler[i] end
        local ta = LrDate.currentTime()
        local md = catalog:batchGetRawMetadata(parti, { 'uuid', 'path', 'fileFormat', 'isVirtualCopy' })
        tOkuma = tOkuma + (LrDate.currentTime() - ta)
        for _, p in ipairs(parti) do
            local m = md[p]
            if m.fileFormat == 'VIDEO' then
                sayi.video = sayi.video + 1
            elseif m.isVirtualCopy then
                sayi.sanal = sayi.sanal + 1
                sanallar[#sanallar + 1] = { p, m }
            else
                f:write('{"yerel":', p.localIdentifier, ',"uuid":', js(m.uuid), ',"yol":', js(m.path), ',"bicim":', js(m.fileFormat),
                    ',"sanal":false,"asil_uuid":null}\n')
                sayi.yazilan = sayi.yazilan + 1
            end
        end
        ilerleme:setPortionComplete(math.min(bas + PARTI - 1, #kareler), #kareler)
        LrTasks.yield()
    end

    -- Sanal kopyalar taranmaz; asıl karenin vektörünü kullanır. Asıl karenin kimliği tek tek okunur (az sayıda).
    local t2 = LrDate.currentTime()
    for _, x in ipairs(sanallar) do
        local p, m = x[1], x[2]
        local asil = p:getRawMetadata('masterPhoto')
        f:write('{"yerel":', p.localIdentifier, ',"uuid":', js(m.uuid), ',"yol":', js(m.path), ',"bicim":', js(m.fileFormat),
            ',"sanal":true,"asil_uuid":', js(asil and asil:getRawMetadata('uuid')), '}\n')
    end
    f:close()
    local t3 = LrDate.currentTime()
    yerineKoy(listeYolu .. ek, listeYolu)

    local ozet = string.format(
        '{"surum":%d,"katalog":%s,"tarih":%s,"toplam":%d,"asil":%d,"sanal":%d,"video":%d,' ..
        '"sure_sn":{"kareleri_al":%.1f,"bilgi_oku":%.1f,"sanal_kopyalar":%.1f,"toplam":%.1f}}\n',
        SURUM, js(katalogYolu), js(LrDate.timeToW3CDate(LrDate.currentTime())), sayi.toplam, sayi.yazilan,
        sayi.sanal, sayi.video, t1 - t0, tOkuma, t3 - t2, t3 - t0)
    local o = assert(io.open(LrPathUtils.child(klasor, 'liste.json' .. ek), 'w'))
    o:write(ozet)
    o:close()
    yerineKoy(LrPathUtils.child(klasor, 'liste.json' .. ek), LrPathUtils.child(klasor, 'liste.json'))

    gunluk(string.format('eşitleme bitti: liste yeniden yazıldı (%.1f sn)', t3 - t0))
    ilerleme:done()
    -- Onay penceresi yok: Fotora uygulaması listeyi görüp kendiliğinden ilerler.
    if not sessiz then LrDialogs.showBezel(string.format(L('Fotora: %d fotoğraf eşitlendi', 'Fotora: %d photos synced'), sayi.yazilan), 2) end
end

return M
