--[[ Eklenti yüklenince (LrC açılışı ya da Enable) Fotora uygulamasına "çalışıyorum" haberi bırakır.
Uygulama bu dosyayı göremezse kullanıcıya eklentiyi Plug-in Manager'dan açmasını söyler. ]]
local LrDate = import 'LrDate'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

local klasor = LrPathUtils.getStandardFilePath('home')
for _, ad in ipairs { 'Library', 'Application Support', 'Fotora' } do klasor = LrPathUtils.child(klasor, ad) end
LrFileUtils.createAllDirectories(klasor)
local f = io.open(LrPathUtils.child(klasor, 'eklenti.json'), 'w')
if f then
    f:write(string.format('{"kimlik":"%s","zaman":"%s"}\n', _PLUGIN and _PLUGIN.id or '', LrDate.timeToW3CDate(LrDate.currentTime())))
    f:close()
end

-- LrC açılınca liste arka planda kendiliğinden yenilenir (eklenen/silinen fotoğraflar). Açılışı yavaşlatmamak için
-- LrC yerleştikten sonra başlar; sessizdir (ilerleme çubuğu ve bildirim yok).
local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'
require('Gunluk')('eklenti yüklendi')
LrTasks.startAsyncTask(function()
    -- Bu katalogun listesi hiç yoksa (ilk kurulum) beklemeden başlar: kurulum penceresi listeyi bekliyor ve
    -- kullanıcıdan menüyü istemiyor (Okan, 10 Ekim 2026: iki eşitleme çakışıyordu).
    local LrApplication = import 'LrApplication'
    local LrMD5 = import 'LrMD5'
    local liste = LrPathUtils.child(LrPathUtils.child(LrPathUtils.child(klasor, 'kataloglar'),
        LrMD5.digest(LrApplication.activeCatalog():getPath())), 'liste.json')
    LrTasks.sleep(LrFileUtils.exists(liste) and 30 or 2)
    -- Sessiz: bir hata olursa Lightroom'un "internal error" penceresi yerine günlüğe yazılır; menüden eşitleme yine çalışır.
    local ok, hata = LrTasks.pcall(function()
        LrFunctionContext.callWithContext('FotoraAcilisListesi', function(context)
            require('Liste').hazirla(context, true)
        end)
    end)
    if not ok then require('Gunluk')('açılış eşitlemesi hata verdi: ' .. tostring(hata)) end
end)
