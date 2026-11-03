import SwiftUI

/// Kurulum sihirbazı: kenar çubuğu + adım içeriği (tasarım tuvali, ekran 1-6).
struct Sihirbaz: View {
    @EnvironmentObject var u: Uygulama

    var body: some View {
        HStack(spacing: 0) {
            kenar
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    switch u.adim {
                    case 0: HosGeldiniz()
                    case 1: MacKontrolu()
                    case 2: Gizlilik()
                    case 3: LightroomAdimi()
                    case 4: ModelAdimi()
                    default: IndirmeAdimi()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .background(Renk.zemin)
        }
    }

    var kenar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Logo()
                Text("Fotora").font(.system(size: 17, weight: .bold))
            }
            .padding(.horizontal, 8).padding(.bottom, 18)
            ForEach(Array(Uygulama.adimlar.enumerated()), id: \.offset) { i, ad in
                let bitti = i < u.adim, simdi = i == u.adim
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(bitti ? Renk.yaprak : (simdi ? Renk.aura : Renk.cizgi))
                        Text(bitti ? "✓" : "\(i + 1)").font(.system(size: 11, weight: .bold))
                            .foregroundStyle(bitti ? Renk.zemin : (simdi ? Renk.dugmeYazi : Renk.murekkep))
                    }
                    .frame(width: 18, height: 18)
                    Text(ad).font(.system(size: 13, weight: simdi ? .semibold : .regular))
                        .foregroundStyle(simdi ? Renk.murekkep : Renk.ikincil)
                    Spacer()
                }
                .padding(.vertical, 7).padding(.horizontal, 8)
                .background(simdi ? Renk.seciliAdim : .clear, in: RoundedRectangle(cornerRadius: 7))
            }
            Spacer()
        }
        .padding(.vertical, 20).padding(.horizontal, 14)
        .frame(width: 200)
        .background(Renk.kum)
    }
}

/// Her adımın alt çubuğu: Geri ve ileri düğmesi.
struct AltCubuk: View {
    @EnvironmentObject var u: Uygulama
    var not: String? = nil
    var ileri = L("Devam", "Continue")
    var ileriAcik = true
    var geriVar = true
    var ileriEylem: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Divider().padding(.bottom, 16)
            HStack {
                if geriVar { Button(L("Geri", "Back")) { u.adim -= 1 }.buttonStyle(IkincilDugme()) }
                if let not { Text(not).font(.system(size: 12)).foregroundStyle(Renk.ikincil) }
                Spacer()
                Button(ileri) { if let ileriEylem { ileriEylem() } else { u.adim += 1 } }
                    .buttonStyle(AnaDugme()).disabled(!ileriAcik).opacity(ileriAcik ? 1 : 0.5)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

struct Baslik: View {
    let metin: String
    var body: some View { Text(metin).font(.system(size: 22, weight: .bold)).padding(.bottom, 4) }
}

struct Aciklama: View {
    let metin: String
    var body: some View {
        Text(metin).font(.system(size: 13)).foregroundStyle(Renk.yazi2).lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct Not: View {
    let metin: String
    var uyari = false
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: uyari ? "exclamationmark.circle" : "info.circle")
            Text(metin).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
        .foregroundStyle(uyari ? Renk.uyariYazi : Renk.yazi3)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(uyari ? Renk.uyariZemin : Renk.kum, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct Onay: View {
    let tamam: Bool
    var body: some View {
        Image(systemName: tamam ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(tamam ? Renk.yaprak : Renk.hata)
            .font(.system(size: 17))
    }
}

// MARK: - Adımlar

struct HosGeldiniz: View {
    @EnvironmentObject var u: Uygulama
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Logo(boyut: 64).padding(.top, 12)
                Spacer()
                // Kurulum dili: Mac'in diline göre seçili gelir, burada değişir (Ayarlar › Genel'de de).
                Picker("", selection: Binding(get: { Dil.kod }, set: { u.diliSec($0) })) {
                    Text("Türkçe").tag("tr")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 150)
            }
            Text(L("Arşivinizi kelimelerle arayın", "Search your archive with words")).font(.system(size: 26, weight: .bold))
            Aciklama(metin: L("Fotora, Lightroom Classic kataloğunuzdaki her kareye bir kez bakar. Sonra \"sisli ormanda yürüyen biri\" yazdığınızda ya da bir kareyi seçip \"buna benzeyenleri bul\" dediğinizde, sonuçlar saniyeler içinde Lightroom'da bir koleksiyon olarak açılır.", "Fotora looks at every photo in your Lightroom Classic catalog once. Then, when you type \"someone walking in a misty forest\" or pick a photo and ask to \"find similar\", the results open in Lightroom as a collection within seconds."))
                .frame(maxWidth: 440, alignment: .leading)
            VStack(alignment: .leading, spacing: 10) {
                ForEach([L("Fotoğraflarınız ve kataloğunuz Mac'inizden hiç çıkmaz.", "Your photos and your catalog never leave your Mac."),
                         L("Kataloğunuza ve fotoğraflarınıza hiçbir şey yazılmaz; Fotora yalnız okur.", "Nothing is written to your catalog or photos; Fotora only reads."),
                         L("Tarama arka planda sürer, istediğiniz an durdurup ertesi gün devam edebilirsiniz.", "Scanning runs in the background; pause any time and continue the next day.")], id: \.self) { m in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark").foregroundStyle(Renk.yaprak).font(.system(size: 12, weight: .bold))
                        Text(m).font(.system(size: 13))
                    }
                }
            }
            Spacer()
            AltCubuk(not: L("Kurulum yaklaşık 10 dakika sürer.", "Setup takes about 10 minutes."), ileri: L("Başlayalım", "Let's start"), geriVar: false)
        }
    }
}

struct MacKontrolu: View {
    @EnvironmentObject var u: Uygulama
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Baslik(metin: u.macUygun ? L("Mac'iniz Fotora için uygun", "Your Mac is ready for Fotora") : L("Bu Mac'te bir sorun var", "There is a problem with this Mac"))
            Aciklama(metin: L("Kurulumdan önce bu Mac'i kontrol ettik.", "We checked this Mac before setup."))
            VStack(spacing: 0) {
                ForEach(u.kontroller) { k in
                    HStack(spacing: 12) {
                        Onay(tamam: k.uygun)
                        Text(k.ad).font(.system(size: 13, weight: .semibold)).frame(width: 140, alignment: .leading)
                        Text(k.deger).font(.system(size: 13)).foregroundStyle(Renk.yazi2)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    Divider()
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi))
            if !u.macUygun {
                // Eksik giderilince (ör. Lightroom kuruldu) Fotora'yı kapatıp açmak gerekmesin.
                Button(L("Yeniden kontrol et", "Check again")) { u.macKontrol() }.buttonStyle(IkincilDugme())
            }
            Spacer()
            AltCubuk(ileriAcik: u.macUygun)
        }
        .onAppear { u.macKontrol() }
    }
}

struct Gizlilik: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Baslik(metin: L("Fotoğraflarınız sizde kalır", "Your photos stay with you"))
            HStack(alignment: .top, spacing: 12) {
                kutu(L("MAC'İNİZDE KALAN", "STAYS ON YOUR MAC"), L("Fotoğraflarınız, kataloğunuz, dosya adları ve yolları, anahtar kelimeleriniz, arama sonuçlarınız ve aramada yazdığınız cümleler.", "Your photos, your catalog, file names and paths, your keywords, your search results and the sentences you search with."), Renk.yaprak)
                kutu(L("İNTERNETE ÇIKAN", "GOES TO THE INTERNET"), L("Yalnız yapay zekâ modelinin bir kez indirilmesi ve siz isterseniz güncelleme denetimi. Fotoğraf ya da katalog bilgisi gönderilmez.", "Only the one-time download of the AI model, and update checks when you ask. No photo or catalog data is sent."), Renk.kehribar)
            }
            kutu(L("KATALOĞUNUZA", "YOUR CATALOG"), L("Fotora hiçbir kareye, anahtar kelimeye, yıldıza ya da renk etiketine yazmaz. Yalnız arama sonuçlarını \"Fotora\" başlıklı koleksiyonlar olarak ekler; bunları istediğiniz an silebilirsiniz.", "Fotora never writes to any photo, keyword, star rating or color label. It only adds search results as collections under \"Fotora\"; you can delete them any time."), Renk.yazi3)
            Spacer()
            AltCubuk(ileri: L("Anladım, devam", "Got it, continue"))
        }
    }

    func kutu(_ b: String, _ m: String, _ r: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(b).font(.system(size: 12, weight: .bold)).foregroundStyle(r)
            Text(m).font(.system(size: 13)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi))
    }
}

struct LightroomAdimi: View {
    @EnvironmentObject var u: Uygulama
    let saat = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let h = u.eklentiHatasi {
                Baslik(metin: L("Lightroom'a bağlanılamadı", "Could not connect to Lightroom"))
                Not(metin: h, uyari: true)
            } else if let k = u.katalog {
                Baslik(metin: L("Lightroom'a bağlanıldı", "Connected to Lightroom"))
                Aciklama(metin: L("Fotora, Lightroom Classic'e küçük bir eklenti kurdu. Arama menüleri Lightroom'da Library › Plug-in Extras › Fotora altında olacak.", "Fotora installed a small plug-in in Lightroom Classic. The search menus will be under Library › Plug-in Extras › Fotora."))
                satir(L("Eklenti kuruldu", "Plug-in installed"), L("Sürüm ", "Version ") + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L("geliştirme", "development")))
                satir(L("Açık katalog: ", "Open catalog: ") + k.ad, L("\(sayi(k.ozet.toplam)) kare bulundu: \(sayi(k.ozet.asil)) kare, \(sayi(k.ozet.sanal)) sanal kopya", "\(sayi(k.ozet.toplam)) photos found: \(sayi(k.ozet.asil)) photos, \(sayi(k.ozet.sanal)) virtual copies"))
                Not(metin: L("Yalnız bu katalog taranır. Lightroom'da başka bir katalog açtığınızda Fotora onu da taramak isteyip istemediğinizi sorar; \"Hayır\" derseniz o katalog taranmaz. Bu tercihi Ayarlar'dan sonra değiştirebilirsiniz.", "Only this catalog is scanned. When you open another catalog in Lightroom, Fotora asks whether to scan it too; if you say \"No\", it is not scanned. You can change this later in Settings."))
            } else if !u.eklentiAcik {
                Baslik(metin: L("Lightroom'da eklentiyi açalım", "Let's enable the plug-in in Lightroom"))
                Aciklama(metin: L("Fotora eklentisi Lightroom Classic'e kopyalandı. Lightroom'da şunları yapın:", "The Fotora plug-in was copied to Lightroom Classic. In Lightroom, please:"))
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("1. Lightroom Classic açıksa kapatıp yeniden açın (eklenti açılışta yüklenir).", "1. If Lightroom Classic is open, quit and reopen it (plug-ins load at startup)."))
                    Text(L("2. Hâlâ görünmüyorsa File › Plug-in Manager'da Fotora'yı seçip Enable'a basın.", "2. If it still does not appear, select Fotora in File › Plug-in Manager and click Enable."))
                }
                .font(.system(size: 13))
                bekleniyor(L("Eklentinin açılması bekleniyor…", "Waiting for the plug-in…"))
            } else {
                Baslik(metin: L("Lightroom'dan fotoğraf listesi alınıyor", "Getting the photo list from Lightroom"))
                Aciklama(metin: L("Eklenti çalışıyor ve fotoğraf listesini hazırlıyor. Büyük kataloglarda bu birkaç saniye sürebilir. Lütfen bekleyiniz…", "The plug-in is running and is preparing the photo list. In large catalogs this can take a few seconds. Please wait…"))
                bekleniyor(L("Liste bekleniyor…", "Waiting for the list…"))
                Text(L("Bir dakika içinde gelmezse Lightroom'da Library › Plug-in Extras › Fotoğraf Listesini Eşitle'yi seçin.", "If it hasn't arrived within a minute, choose Library › Plug-in Extras › Sync Photo List in Lightroom."))
                    .font(.system(size: 12)).foregroundStyle(Renk.ikincil)
            }
            Spacer()
            AltCubuk(ileriAcik: u.katalog != nil && u.eklentiHatasi == nil)
        }
        .onAppear { u.lightroomHazirla() }
        .onReceive(saat) { _ in if u.katalog == nil { u.listeyiYenile() } }
    }

    func bekleniyor(_ m: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(m).font(.system(size: 13)).foregroundStyle(Renk.ikincil)
        }
        .padding(.top, 6)
    }

    func satir(_ a: String, _ b: String) -> some View {
        HStack(spacing: 12) {
            Onay(tamam: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(a).font(.system(size: 13, weight: .semibold))
                Text(b).font(.system(size: 12)).foregroundStyle(Renk.ikincil)
            }
            Spacer()
        }
        .padding(12).overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi))
    }
}

struct ModelAdimi: View {
    @EnvironmentObject var u: Uygulama

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Baslik(metin: L("Hangi model?", "Which model?"))
            HStack(alignment: .top, spacing: 12) {
                kart(id: "iyi", ad: L("En iyi sonuç", "Best results"), etiket: L("Önerilen", "Recommended"),
                     aciklama: L("Yazıyla aramada en isabetli model. Çoğu Mac için doğru seçim.", "The most accurate model for text search. The right choice for most Macs."),
                     sure: tahmin(0.1), alan: L("3,2 GB", "3.2 GB"), yazi: L("Çok iyi", "Very good"), acik: true)
                kart(id: "hizli", ad: L("Hızlı ve hafif", "Fast and light"), etiket: L("Hızlı", "Fast"),
                     aciklama: L("Az bellekli Mac'ler için. Yazıyla aramada başarısı görece düşük.", "For Macs with less memory. Relatively lower accuracy in text search."),
                     sure: tahmin(0.02), alan: L("1,1 GB", "1.1 GB"), yazi: L("İyi", "Good"), acik: true)
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Image(systemName: "externaldrive").foregroundStyle(Renk.yazi3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("Model ve arama dizini: ", "Model and search index: ") + u.kayitYeriAdi).font(.system(size: 13, weight: .semibold))
                    Text(String(format: L("%.0f GB boş · Kullanılacak alan: %.1f GB", "%.0f GB free · Space needed: %.1f GB"), Sistem.bosAlanGB(u.kayitYeri.deletingLastPathComponent()), u.gerekenAlanGB))
                        .font(.system(size: 12)).foregroundStyle(Renk.ikincil)
                }
                Spacer()
                Button(L("Başka disk seç…", "Choose another disk…")) { u.kayitYeriSec() }.buttonStyle(IkincilDugme())
            }
            .padding(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi))
            Text(L("Modeli sonra değiştirirseniz bütün katalog yeniden taranır. Yeni tarama bitene kadar eskisi çalışmaya devam eder.", "If you change the model later, the whole catalog is scanned again. The old one keeps working until the new scan finishes."))
                .font(.system(size: 12)).foregroundStyle(Renk.ikincil)
            Spacer()
            AltCubuk(ileri: u.model == "hizli" ? L("Hızlı modelle devam", "Continue with Fast") : L("En iyi sonuçla devam", "Continue with Best results"))
        }
    }

    /// Kesin süre tarama özetinde ölçülür; burada modelin bu Mac'teki ölçümünden kaba tahmin (disk hızı hariç).
    func tahmin(_ kareBasina: Double) -> String {
        guard let k = u.katalog else { return "—" }
        return sure(Double(k.ozet.asil) * kareBasina).replacingOccurrences(of: L("yaklaşık ", "about "), with: "~")
    }

    func kart(id: String, ad: String, etiket: String, aciklama: String, sure: String, alan: String, yazi: String, acik: Bool) -> some View {
        let secili = u.model == id
        return Button { if acik { u.model = id } } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(ad).font(.system(size: 15, weight: .bold))
                    Spacer()
                    Text(etiket).font(.system(size: 11, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(secili ? Renk.etiketZemin : Renk.cizgi, in: Capsule())
                }
                Text(aciklama).font(.system(size: 12)).foregroundStyle(Renk.yazi2).fixedSize(horizontal: false, vertical: true)
                Group {
                    bilgi(L("Tarama süresi", "Scan time"), sure)
                    bilgi(L("Kullanılacak alan", "Space needed"), alan)
                    bilgi(L("Yazıyla arama", "Text search"), yazi)
                    bilgi(L("Benzer kare bulma", "Finding similar photos"), L("Çok iyi", "Very good"))
                }
            }
            .padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(secili ? Renk.seciliZemin : Renk.zemin, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(secili ? Renk.aura : Renk.cizgi, lineWidth: 2))
            .opacity(acik ? 1 : 0.6)
        }
        .buttonStyle(.plain)
    }

    func bilgi(_ a: String, _ b: String) -> some View {
        HStack { Text(a).foregroundStyle(Renk.ikincil); Spacer(); Text(b).fontWeight(.semibold) }.font(.system(size: 12))
    }
}

struct IndirmeAdimi: View {
    @EnvironmentObject var u: Uygulama

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Baslik(metin: u.modelHazir ? L("Model hazır", "Model ready") : L("Model indiriliyor", "Downloading model"))
            Aciklama(metin: L("\"\(u.modelAdi)\" modeli bir kez indirilir, sonra internet gerekmez.", "The \"\(u.modelAdi)\" model is downloaded once; no internet is needed afterwards."))
            ProgressView(value: u.indirme).tint(Renk.aura).padding(.top, 10)
            Text(u.modelHazir ? L("Model bu Mac'te denendi, çalışıyor.", "The model was tested on this Mac and works.") : (u.indirme >= 0.9 ? L("Model bu Mac'te deneniyor…", "Testing the model on this Mac…") : indirilen))
                .font(.system(size: 13)).foregroundStyle(Renk.ikincil)
            if let h = u.modelHatasi {
                Not(metin: h, uyari: true)
                Button(L("Yeniden dene", "Try again")) { u.modeliIndir() }.buttonStyle(IkincilDugme())
            }
            if u.modelHazir {
                Not(metin: L("Sırada fotoğraflarınızı okumak var. Fotoğraflarınız harici bir diskte ya da ağda duruyorsa macOS Fotora için izin isteyecek; \"İzin Ver\" (Allow) düğmesine basın.",
                             "Next, Fotora starts reading your photos. If they are on an external or network disk, macOS will ask for permission for Fotora; click \"Allow\"."))
            }
            Spacer()
            AltCubuk(ileriAcik: u.modelHazir) {
                u.adim = 6
                u.taramayaHazirlan()
            }
        }
        .onAppear { u.modeliIndir() } // model değiştiyse yenisi iner; varsa yalnız denenir
    }

    /// "%40 · 0,8 / 2,1 GB" (indirme ilerlemenin %85'i)
    var indirilen: String {
        let gb = Double(Uygulama.modelDosyalari[u.modelKimligi]?.boyut ?? 0) / 1e9
        let oran = min(u.indirme / 0.85, 1)
        return String(format: "%%%.0f · %.1f / %.1f GB", u.indirme * 100, oran * gb, gb)
    }
}
