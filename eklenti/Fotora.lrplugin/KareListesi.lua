-- Library › Plug-in Extras › Fotora › Fotoğraf Listesini Eşitle: listeyi elle yeniler (eklenen/silinen fotoğraflar için).
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'
local Liste = require 'Liste'

LrTasks.startAsyncTask(function()
    LrFunctionContext.callWithContext('KareListesi', function(context)
        LrDialogs.attachErrorDialogToFunctionContext(context)
        Liste.hazirla(context, false)
    end)
end)
