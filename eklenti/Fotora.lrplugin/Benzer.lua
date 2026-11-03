-- Library › Plug-in Extras › Fotora › Find Similar (seçili kareye benzeyenler)
local L = require 'Dil'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'
local Baglanti = require 'Baglanti'
local Sonuclar = require 'Sonuclar'

LrTasks.startAsyncTask(function()
    LrFunctionContext.callWithContext('FotoraBenzer', function(context)
        LrDialogs.attachErrorDialogToFunctionContext(context)
        local kare = LrApplication.activeCatalog():getTargetPhoto()
        if not kare then
            LrDialogs.message('Fotora', L('Önce bir kare seçin.', 'Select a photo first.'), 'info')
            return
        end
        -- Sanal kopyanın vektörü asıl karesininkidir.
        local asil = kare:getRawMetadata('isVirtualCopy') and kare:getRawMetadata('masterPhoto') or kare
        local cevap, hata = Baglanti.istek('/benzer', { katalog = Baglanti.katalog(), uuid = asil:getRawMetadata('uuid'),
            adet = LrPrefs.prefsForPlugin().adet or 100 })
        if not cevap or cevap.hata then
            LrDialogs.message('Fotora', hata or cevap.hata, 'warning')
            return
        end
        Sonuclar.goster(L('Benzer: ', 'Similar: ') .. kare:getFormattedMetadata('fileName'), cevap, kare,
            L(kare:getFormattedMetadata('fileName') .. ' karesine benzeyenler', 'Photos similar to ' .. kare:getFormattedMetadata('fileName')))
    end)
end)
