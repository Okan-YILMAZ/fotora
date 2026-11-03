--[[ Eklentinin dili Fotora uygulamasının seçimini izler (~/Library/Application Support/Fotora/ayarlar.json).
LrC'nin dili izlenmez: LrC'nin Türkçesi yok. Dosya yoksa İngilizce. Kullanım: local L = require 'Dil'; L('Türkçe', 'English') ]]
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

local function ingilizce()
    local yol = LrPathUtils.getStandardFilePath('home')
    for _, ad in ipairs { 'Library', 'Application Support', 'Fotora', 'ayarlar.json' } do yol = LrPathUtils.child(yol, ad) end
    local s = LrFileUtils.exists(yol) and LrFileUtils.readFile(yol) or ''
    return s:match('"dil"%s*:%s*"(%a+)"') ~= 'tr'
end

-- Her çağrıda dosyaya bakılır (küçük dosya): dil uygulamadan değişince eklenti yeniden yüklenmeden izler.
return function(tr, en) return ingilizce() and en or tr end
