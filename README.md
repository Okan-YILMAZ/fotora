# Fotora

Search the photos in your Lightroom Classic catalog in everyday language: "someone walking in a misty forest", "woman with a red umbrella". Everything runs on your Mac; your photos are never uploaded. Free and open source (Apache 2.0).

**[Download Fotora 1.0 (.dmg)](https://indir.getfotora.com/Fotora-1.0.dmg)** · Website: [getfotora.com](https://getfotora.com) · [Türkçe özet](#türkçe)

## What it does

- **Text search:** describe the scene you have in mind, in English or Turkish, and the matching photos appear.
- **Find similar:** the photos most similar to the selected one (duplicates, other shots of the same place).
- **Find similar groups:** groups photos that are very similar (bursts, duplicates). Nothing is deleted.

Fotora never writes keywords, ratings, flags or colors to your catalog, and never changes or deletes photos. It only adds collections to the "Fotora" collection set.

## Requirements

- Mac with Apple silicon (M1 or later), macOS 14 (Sonoma) or later
- Lightroom Classic (tested with 15.6)
- 4-5 GB free space for the model and the search index (an external disk is fine)
- Internet during setup: the model is downloaded once (2.1 GB or 0.7 GB, depending on the model you choose)

## Installation

1. Download [Fotora-1.0.dmg](https://indir.getfotora.com/Fotora-1.0.dmg), open it and drag Fotora to the Applications folder.
2. Open Fotora. The app is not signed by Apple, so macOS says it "could not be verified". Close the warning, go to **System Settings › Privacy & Security**, click **Open Anyway** next to "Fotora" and enter your password. You only do this once.
3. Follow the setup window: language, Mac check, privacy, Lightroom plug-in (Fotora installs it; if Lightroom is open, quit and reopen it), model choice and download, scan.
4. The first scan depends on the size of your archive and the speed of your disk; a large archive is scanned overnight. You can keep using Lightroom meanwhile.

If the plug-in doesn't show up in Lightroom: **File › Plug-in Manager** › Fotora › **Enable**, then reopen Lightroom.

## Use

In Lightroom's Library module, open **Library › Plug-in Extras**. Menu names follow Fotora's language (they change after Lightroom is reopened):

| English | Türkçe | What it does |
|---|---|---|
| Search in Everyday Language… | Gündelik Dille Ara… | Text search. "Where:" lets you search the whole catalog, the selected photos or the photos shown |
| Find Similar | Benzerlerini Bul | Photos similar to the selected one |
| Find Similar Groups… | Benzer Grupları Bul… | Groups very similar photos; nothing is deleted |
| Bring Sorted Results to Front | Sıralı Sonuçları Öne Getir | Brings the sorted results window to the front |
| Sync Photo List | Fotoğraf Listesini Eşitle | Syncs new and removed photos by hand (normally not needed) |

Tips: describe a scene rather than a single word. If a Turkish search finds nothing, try the same sentence in English (the model is strongest in English). You can narrow down first with Lightroom's Library Filter, then search "In the photos shown".

## Known limits

- Apple silicon and macOS 14+ only; no Windows, no Intel.
- No search while Lightroom is closed (scanning continues). Search works in the catalog currently open in Lightroom.
- No face recognition; it searches scenes, not people.
- Some Turkish words can be misread; try English.
- No similarity percentage, only rank.
- Changing the model rescans the whole catalog.
- Not signed by Apple (Open Anyway needed on first launch).
- Tested only with Lightroom Classic 15.6.

## Support

- **Bug or question:** open an [issue](../../issues/new/choose), or email destek@getfotora.com.
- **Diagnostic report:** Fotora › Settings (⌘,) › Maintenance › Diagnostic report › Create. The report is saved to your Desktop and a ready email to destek@getfotora.com opens in your mail app (it contains no photo names, paths or catalog names); just press Send. You can also attach it to an issue.
- **New version:** Fotora › Settings › Maintenance › Check for updates (Fotora goes online only when you press it).
- **Uninstall:** Fotora › Settings › Maintenance › Remove. Your photos and catalog are not touched.

## Building from source

Requires the Xcode command line tools (Swift 5.9+).

```bash
cd uygulama && swift build -c release
./paket/paketle.sh --dmg      # creates uygulama/paket/Fotora.app and Fotora-<version>.dmg
```

Folders (names are Turkish):

- `uygulama/` ("app"): the Mac app (SwiftUI) and its core `FotoraCore` (model, scanning, index, search)
- `eklenti/Fotora.lrplugin` ("plug-in"): the Lightroom Classic plug-in (Lua)
- `kesif/` ("exploration"): Python scripts that convert the models to Core ML

The model files are not in this repository; they are downloaded from `indir.getfotora.com` during setup.

## License

Apache 2.0 ([LICENSE](LICENSE)). Attributions for the models and libraries are in [NOTICE](NOTICE). Models: Google SigLIP 2 (Apache 2.0). The name "Fotora" and its logo are not covered by the license.

---

<a id="türkçe"></a>

## Türkçe

Fotora, Lightroom Classic kataloğunuzdaki fotoğrafları gündelik dille aramanızı sağlar ("sisli ormanda yürüyen biri"). Her şey Mac'inizde çalışır, fotoğraflarınız hiçbir yere gönderilmez. Ücretsiz ve açık kaynaktır.

- **İndir:** [Fotora-1.0.dmg](https://indir.getfotora.com/Fotora-1.0.dmg) · [getfotora.com](https://getfotora.com)
- **İlk açılış:** Apple imzası olmadığı için macOS uyarı verir. **System Settings › Privacy & Security** bölümünde "Fotora" satırındaki **Open Anyway** düğmesine basın (bir kez).
- **Kullanım:** Lightroom'da **Library › Plug-in Extras** › Gündelik Dille Ara… Bulamazsanız aynı cümleyi İngilizce deneyin.
- **Destek:** destek@getfotora.com ya da Fotora › Ayarlar › Bakım › Tanı raporu.
