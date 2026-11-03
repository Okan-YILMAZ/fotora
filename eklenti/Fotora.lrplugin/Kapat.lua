-- Eklenti kapatılınca (Disable) haber dosyası silinir; uygulama eklentinin kapalı olduğunu anlar.
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local yol = LrPathUtils.getStandardFilePath('home')
for _, ad in ipairs { 'Library', 'Application Support', 'Fotora', 'eklenti.json' } do yol = LrPathUtils.child(yol, ad) end
if LrFileUtils.exists(yol) then LrFileUtils.delete(yol) end
