--[[ "Nerede?": arama ve benzer grupların hangi karelerde yapılacağı: bütün katalog, seçili kareler ya da LrC'de
görünen kareler (klasör, koleksiyon, akıllı koleksiyon, Library Filter sonucu).
Pencere beklemeden açılsın diye pencereden önce yalnız seçim okunur; görünen kareler "Ara"ya basınca okunur.
SDK görünen kareleri yalnız seçim yokken veriyor (getTargetPhotos); seçim varsa bir anlığına "Select All"
yapılıp okunur ve seçim geri konur. Kullanıcıdan seçimi kaldırması istenmez (Okan, 10 Ekim 2026).
Uygulamaya kimlik yerine LrC'nin kare numarası (localIdentifier) gider: kare başına bilgi okumak 28 bin karede
saniyeler sürüyordu; numara ise hazır. Numaradan kimliğe uygulama, fotoğraf listesiyle çevirir. ]]
local L = require 'Dil'
local LrSelection = import 'LrSelection'
local LrTasks = import 'LrTasks'

local M = {}

--- Pencereden önce: seçim ve kaynağın adı (ucuz). { aktif, secim = seçili kareler ya da nil, ad }
function M.oku(catalog)
    local aktif = catalog:getTargetPhoto()
    local ad
    local kaynak = catalog:getActiveSources()[1]
    if type(kaynak) == 'table' and kaynak.getName then ad = kaynak:getName() end
    return { aktif = aktif, secim = aktif and catalog:getTargetPhotos() or nil, ad = ad }
end

--- popup_menu seçenekleri ve varsayılan: birden çok kare seçiliyse seçililer, değilse görünenler.
function M.secenekler(k)
    local s = { { title = L('Bütün katalogda', 'In the whole catalog'), value = 'katalog' } }
    if k.secim and #k.secim > 1 then
        s[#s + 1] = { title = string.format(L('Seçili %d karede', 'In the %d selected photos'), #k.secim), value = 'secili' }
    end
    s[#s + 1] = { title = L('Görünen karelerde', 'In the photos shown') .. (k.ad and (' (' .. k.ad .. ')') or ''), value = 'gorunen' }
    return s, (k.secim and #k.secim > 1) and 'secili' or 'gorunen'
end

local function gorunenler(catalog, k)
    if not k.aktif then return catalog:getTargetPhotos() end
    local gorunen = k.secim
    LrSelection.selectAll()
    for _ = 1, 20 do -- seçim komutu LrC'de sıraya girer; hemen yansımayabilir
        LrTasks.sleep(0.05)
        gorunen = catalog:getTargetPhotos()
        if #gorunen ~= #k.secim then break end
    end
    catalog:setSelectedPhotos(k.aktif, k.secim)
    return gorunen
end

--- Kapsamdaki karelerin LrC numaraları (görünüm sırasıyla). Bütün katalogsa nil.
function M.numaralar(catalog, k, secim)
    if secim == 'katalog' then return nil end
    local kareler = secim == 'secili' and k.secim or gorunenler(catalog, k)
    local n = {}
    for i, p in ipairs(kareler) do n[i] = p.localIdentifier end
    return n
end

return M
