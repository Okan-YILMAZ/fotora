--[[ Fotora uygulamasıyla konuşma: uygulama bu Mac'te (127.0.0.1) küçük bir sunucu açar ve kapı numarasını
~/Library/Application Support/Fotora/baglanti.json dosyasına yazar. Uygulama kapalıysa arka planda açılır.
Görevler LrTasks içinden çağrılır (LrHttp ve LrTasks.sleep görev ister). ]]
local L = require 'Dil'
local LrApplication = import 'LrApplication'
local LrFileUtils = import 'LrFileUtils'
local LrHttp = import 'LrHttp'
local LrMD5 = import 'LrMD5'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'
local json = require 'json'

local M = {}

local function kapi()
    local yol = LrPathUtils.getStandardFilePath('home')
    for _, ad in ipairs { 'Library', 'Application Support', 'Fotora', 'baglanti.json' } do yol = LrPathUtils.child(yol, ad) end
    if not LrFileUtils.exists(yol) then return nil end
    local ok, b = pcall(json.decode, LrFileUtils.readFile(yol))
    return ok and b and b.kapi or nil
end

local function dene(yol, govde, sure)
    local k = kapi()
    if not k then return nil end
    local cevap = LrHttp.post('http://127.0.0.1:' .. k .. yol, json.encode(govde),
        { { field = 'Content-Type', value = 'application/json' } }, 'POST', sure or 120)
    if not cevap or cevap == '' then return nil end
    local ok, c = pcall(json.decode, cevap)
    return ok and c or nil
end

--- Uygulamaya istek gönderir; cevap tablosu ya da (nil, hata metni) döner. sure: cevap için en çok saniye (120).
function M.istek(yol, govde, sure)
    local c = dene(yol, govde, sure)
    if c then return c end
    -- Uygulama kapalı (ya da eski bir kapı numarası kalmış): arka planda aç ve bekle.
    LrTasks.execute('open -g -b com.fotora.app')
    for _ = 1, 40 do
        LrTasks.sleep(1)
        c = dene(yol, govde, sure)
        if c then return c end
    end
    return nil, L('Fotora uygulamasına ulaşılamadı. Fotora kurulu mu? Uygulamayı açıp yeniden deneyin.', 'Could not reach the Fotora app. Is Fotora installed? Open the app and try again.')
end

--- Açık kataloğun kimliği: eklentinin listeyi yazdığı klasörün adıyla aynı (KareListesi.lua).
function M.katalog()
    return LrMD5.digest(LrApplication.activeCatalog():getPath())
end

return M
