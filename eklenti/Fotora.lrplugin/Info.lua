-- Fotora LrC eklentisi. Kimlik bir kez verildi (9 Ekim 2026), değişmez: değişirse kullanıcıda eklenti yeni sayılır.
return {
    LrSdkVersion        = 10.0,
    LrSdkMinimumVersion = 10.0,
    LrToolkitIdentifier = 'com.fotora.lrc',
    LrPluginName        = 'Fotora',
    LrInitPlugin        = 'Baslat.lua',
    LrForceInitPlugin   = true,
    LrEnablePlugin      = 'Baslat.lua',
    LrDisablePlugin     = 'Kapat.lua',

    -- Menü adları İngilizce: LrC bunları açılışta bir kez okur, dile göre değiştiremez; LrC'nin Türkçesi de yok.
    LrLibraryMenuItems = {
        { title = 'Search in Everyday Language…', file = 'Ara.lua' },
        { title = 'Find Similar', file = 'Benzer.lua' },
        { title = 'Find Similar Groups…', file = 'Gruplar.lua' },
        { title = 'Bring Sorted Results to Front', file = 'OneGetir.lua' },
        { title = 'Sync Photo List', file = 'KareListesi.lua' },
    },

    VERSION = { major = 1, minor = 0, revision = 0, build = 1, display = '1.0' }, -- uygulamanın sürümüyle (paketle.sh) aynı tutulur
}
