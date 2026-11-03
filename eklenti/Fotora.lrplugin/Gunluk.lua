--[[ Fotora'nın LrC içinde ne zaman ne yaptığının kısa kaydı: ~/Library/Application Support/Fotora/eklenti.log
LrC yavaşladığında "o an Fotora bir şey yapıyor muydu?" sorusunu cevaplamak için (Okan, 10 Ekim 2026).
Fotoğraf adı ya da yol yazılmaz. 1 MB'ı geçince baştan başlar. ]]
local LrDate = import 'LrDate'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

local yol = LrPathUtils.getStandardFilePath('home')
for _, ad in ipairs { 'Library', 'Application Support', 'Fotora', 'eklenti.log' } do yol = LrPathUtils.child(yol, ad) end

return function(metin)
    local kip = (LrFileUtils.fileAttributes(yol) or {}).fileSize or 0
    local f = io.open(yol, kip > 1000000 and 'w' or 'a')
    if f then
        f:write(LrDate.timeToUserFormat(LrDate.currentTime(), '%Y-%m-%d %H:%M:%S'), '  ', metin, '\n')
        f:close()
    end
end
