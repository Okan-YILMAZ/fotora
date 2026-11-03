-- Library › Plug-in Extras › Fotora › Bring Sorted Results to Front
-- LrC tam ekrandayken sıralı sonuç penceresi arkada kalabiliyor; bu menü onu öne getirir.
local LrDialogs = import 'LrDialogs'
local L = require 'Dil'
if not require('Siralama').oneGetir() then
    LrDialogs.showBezel(L('Açık bir sıralı sonuç penceresi yok', 'No sorted results window is open'), 2)
end
