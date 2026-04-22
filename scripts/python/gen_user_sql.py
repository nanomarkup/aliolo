import json
import os

data_str = """
{
  "en": {
    "default_language": "Default Language",
    "created_at": "Created At",
    "updated_at": "Updated At",
    "status": "Status",
    "provider": "Provider",
    "expiry_date": "Expiry Date",
    "purchase_token": "Purchase Token",
    "order_id": "Order ID",
    "product_id": "Product ID"
  },
  "id": {
    "default_language": "Bahasa Default",
    "created_at": "Dibuat Pada",
    "updated_at": "Diperbarui Pada",
    "status": "Status",
    "provider": "Penyedia",
    "expiry_date": "Tanggal Kedaluwarsa",
    "purchase_token": "Token Pembelian",
    "order_id": "ID Pesanan",
    "product_id": "ID Produk"
  },
  "bg": {
    "default_language": "Език по подразбиране",
    "created_at": "Създадено на",
    "updated_at": "Актуализирано на",
    "status": "Статус",
    "provider": "Доставчик",
    "expiry_date": "Дата на изтичане",
    "purchase_token": "Токен за покупка",
    "order_id": "ID на поръчка",
    "product_id": "ID на продукт"
  },
  "cs": {
    "default_language": "Výchozí jazyk",
    "created_at": "Vytvořeno",
    "updated_at": "Aktualizováno",
    "status": "Stav",
    "provider": "Poskytovatel",
    "expiry_date": "Datum vypršení platnosti",
    "purchase_token": "Token nákupu",
    "order_id": "ID objednávky",
    "product_id": "ID produktu"
  },
  "da": {
    "default_language": "Standardsprog",
    "created_at": "Oprettet den",
    "updated_at": "Opdateret den",
    "status": "Status",
    "provider": "Udbyder",
    "expiry_date": "Udløbsdato",
    "purchase_token": "Købstoken",
    "order_id": "Ordre-ID",
    "product_id": "Produkt-ID"
  },
  "de": {
    "default_language": "Standardsprache",
    "created_at": "Erstellt am",
    "updated_at": "Aktualisiert am",
    "status": "Status",
    "provider": "Anbieter",
    "expiry_date": "Ablaufdatum",
    "purchase_token": "Kauftoken",
    "order_id": "Bestell-ID",
    "product_id": "Produkt-ID"
  },
  "et": {
    "default_language": "Vaikimisi keel",
    "created_at": "Loodud",
    "updated_at": "Uuendatud",
    "status": "Olek",
    "provider": "Pakkuja",
    "expiry_date": "Aegumiskuupäev",
    "purchase_token": "Ostu tunnus",
    "order_id": "Tellimuse ID",
    "product_id": "Toote ID"
  },
  "es": {
    "default_language": "Idioma predeterminado",
    "created_at": "Creado el",
    "updated_at": "Actualizado el",
    "status": "Estado",
    "provider": "Proveedor",
    "expiry_date": "Fecha de caducidad",
    "purchase_token": "Token de compra",
    "order_id": "ID de pedido",
    "product_id": "ID de producto"
  },
  "fr": {
    "default_language": "Langue par défaut",
    "created_at": "Créé le",
    "updated_at": "Mis à jour le",
    "status": "Statut",
    "provider": "Fournisseur",
    "expiry_date": "Date d'expiration",
    "purchase_token": "Jeton d'achat",
    "order_id": "ID de commande",
    "product_id": "ID de produit"
  },
  "ga": {
    "default_language": "Teanga Réamhshocraithe",
    "created_at": "Cruthaithe ag",
    "updated_at": "Nuashonraithe ag",
    "status": "Stádas",
    "provider": "Soláthraí",
    "expiry_date": "Dáta Éaga",
    "purchase_token": "Cód Ceannaigh",
    "order_id": "Aitheantas Ordaithe",
    "product_id": "Aitheantas Táirge"
  },
  "hr": {
    "default_language": "Zadani jezik",
    "created_at": "Kreirano",
    "updated_at": "Ažurirano",
    "status": "Status",
    "provider": "Davatelj usluga",
    "expiry_date": "Datum isteka",
    "purchase_token": "Token za kupnju",
    "order_id": "ID narudžbe",
    "product_id": "ID proizvoda"
  },
  "it": {
    "default_language": "Lingua predefinita",
    "created_at": "Creato il",
    "updated_at": "Aggiornato il",
    "status": "Stato",
    "provider": "Fornitore",
    "expiry_date": "Data di scadenza",
    "purchase_token": "Token di acquisto",
    "order_id": "ID ordine",
    "product_id": "ID prodotto"
  },
  "lv": {
    "default_language": "Noklusējuma valoda",
    "created_at": "Izveidots",
    "updated_at": "Atjaunināts",
    "status": "Statuss",
    "provider": "Pakalpojumu sniedzējs",
    "expiry_date": "Derīguma termiņš",
    "purchase_token": "Pirkuma pilnvara",
    "order_id": "Pasūtījuma ID",
    "product_id": "Produkta ID"
  },
  "lt": {
    "default_language": "Numatytoji kalba",
    "created_at": "Sukurta",
    "updated_at": "Atnaujinta",
    "status": "Būsena",
    "provider": "Teikėjas",
    "expiry_date": "Galiojimo pabaigos data",
    "purchase_token": "Pirkimo žetonas",
    "order_id": "Užsakymo ID",
    "product_id": "Produkto ID"
  },
  "hu": {
    "default_language": "Alapértelmezett nyelv",
    "created_at": "Létrehozva",
    "updated_at": "Frissítve",
    "status": "Állapot",
    "provider": "Szolgáltató",
    "expiry_date": "Lejárati dátum",
    "purchase_token": "Vásárlási token",
    "order_id": "Rendelésazonosító",
    "product_id": "Termékazonosító"
  },
  "mt": {
    "default_language": "Lingwa Default",
    "created_at": "Maħluq fi",
    "updated_at": "Aġġornat fi",
    "status": "Status",
    "provider": "Fornitur",
    "expiry_date": "Data ta' Skadenza",
    "purchase_token": "Token tax-Xiri",
    "order_id": "ID tal-Ordni",
    "product_id": "ID tal-Prodott"
  },
  "nl": {
    "default_language": "Standaardtaal",
    "created_at": "Gemaakt op",
    "updated_at": "Bijgewerkt op",
    "status": "Status",
    "provider": "Aanbieder",
    "expiry_date": "Vervaldatum",
    "purchase_token": "Aankooptoken",
    "order_id": "Bestellings-ID",
    "product_id": "Product-ID"
  },
  "pl": {
    "default_language": "Język domyślny",
    "created_at": "Utworzono",
    "updated_at": "Zaktualizowano",
    "status": "Status",
    "provider": "Dostawca",
    "expiry_date": "Data wygaśnięcia",
    "purchase_token": "Token zakupu",
    "order_id": "ID zamówienia",
    "product_id": "ID produktu"
  },
  "pt": {
    "default_language": "Idioma Padrão",
    "created_at": "Criado em",
    "updated_at": "Atualizado em",
    "status": "Status",
    "provider": "Provedor",
    "expiry_date": "Data de Expiração",
    "purchase_token": "Token de Compra",
    "order_id": "ID do Pedido",
    "product_id": "ID do Produto"
  },
  "ro": {
    "default_language": "Limba implicită",
    "created_at": "Creat la",
    "updated_at": "Actualizat la",
    "status": "Stare",
    "provider": "Furnizor",
    "expiry_date": "Data expirării",
    "purchase_token": "Token de achiziție",
    "order_id": "ID comandă",
    "product_id": "ID produs"
  },
  "sk": {
    "default_language": "Predvolený jazyk",
    "created_at": "Vytvorené",
    "updated_at": "Aktualizované",
    "status": "Stav",
    "provider": "Poskytovateľ",
    "expiry_date": "Dátum vypršania platnosti",
    "purchase_token": "Nákupný token",
    "order_id": "ID objednávky",
    "product_id": "ID produktu"
  },
  "sl": {
    "default_language": "Privzeti jezik",
    "created_at": "Ustvarjeno",
    "updated_at": "Posodobljeno",
    "status": "Stanje",
    "provider": "Ponudnik",
    "expiry_date": "Datum poteka",
    "purchase_token": "Žeton nakupa",
    "order_id": "ID naročila",
    "product_id": "ID izdelka"
  },
  "fi": {
    "default_language": "Oletuskieli",
    "created_at": "Luotu",
    "updated_at": "Päivitetty",
    "status": "Tila",
    "provider": "Tarjoaja",
    "expiry_date": "Päättymispäivä",
    "purchase_token": "Ostotunnus",
    "order_id": "Tilaustunnus",
    "product_id": "Tuotetunnus"
  },
  "sv": {
    "default_language": "Standardspråk",
    "created_at": "Skapad",
    "updated_at": "Uppdaterad",
    "status": "Status",
    "provider": "Leverantör",
    "expiry_date": "Utgångsdatum",
    "purchase_token": "Köptoken",
    "order_id": "Order-ID",
    "product_id": "Produkt-ID"
  },
  "tl": {
    "default_language": "Default na Wika",
    "created_at": "Nagawa Noong",
    "updated_at": "Na-update Noong",
    "status": "Status",
    "provider": "Provider",
    "expiry_date": "Petsa ng Pag-expire",
    "purchase_token": "Token ng Pagbili",
    "order_id": "ID ng Order",
    "product_id": "ID ng Produkto"
  },
  "vi": {
    "default_language": "Ngôn ngữ mặc định",
    "created_at": "Được tạo lúc",
    "updated_at": "Được cập nhật lúc",
    "status": "Trạng thái",
    "provider": "Nhà cung cấp",
    "expiry_date": "Ngày hết hạn",
    "purchase_token": "Mã mua hàng",
    "order_id": "ID đơn hàng",
    "product_id": "ID sản phẩm"
  },
  "tr": {
    "default_language": "Varsayılan Dil",
    "created_at": "Oluşturulma Tarihi",
    "updated_at": "Güncellenme Tarihi",
    "status": "Durum",
    "provider": "Sağlayıcı",
    "expiry_date": "Son Kullanma Tarihi",
    "purchase_token": "Satın Alma Jetonu",
    "order_id": "Sipariş Kimliği",
    "product_id": "Ürün Kimliği"
  },
  "el": {
    "default_language": "Προεπιλεγμένη Γλώσσα",
    "created_at": "Δημιουργήθηκε στις",
    "updated_at": "Ενημερώθηκε στις",
    "status": "Κατάσταση",
    "provider": "Πάροχος",
    "expiry_date": "Ημερομηνία Λήξης",
    "purchase_token": "Διακριτικό Αγοράς",
    "order_id": "Αναγνωριστικό Παραγγελίας",
    "product_id": "Αναγνωριστικό Προϊόντος"
  },
  "uk": {
    "default_language": "Мова за замовчуванням",
    "created_at": "Створено",
    "updated_at": "Оновлено",
    "status": "Статус",
    "provider": "Постачальник",
    "expiry_date": "Термін дії",
    "purchase_token": "Токен покупки",
    "order_id": "ID замовлення",
    "product_id": "ID продукту"
  },
  "ar": {
    "default_language": "اللغة الافتراضية",
    "created_at": "تاريخ الإنشاء",
    "updated_at": "تاريخ التحديث",
    "status": "الحالة",
    "provider": "المزود",
    "expiry_date": "تاريخ الانتهاء",
    "purchase_token": "رمز الشراء",
    "order_id": "معرف الطلب",
    "product_id": "معرف المنتج"
  },
  "hi": {
    "default_language": "डिफ़ॉल्ट भाषा",
    "created_at": "बनाया गया",
    "updated_at": "अपडेट किया गया",
    "status": "स्थिति",
    "provider": "प्रदाता",
    "expiry_date": "समाप्ति तिथि",
    "purchase_token": "खरीद टोकन",
    "order_id": "ऑर्डर आईडी",
    "product_id": "उत्पाद आईडी"
  },
  "zh": {
    "default_language": "默认语言",
    "created_at": "创建时间",
    "updated_at": "更新时间",
    "status": "状态",
    "provider": "提供商",
    "expiry_date": "到期时间",
    "purchase_token": "购买凭证",
    "order_id": "订单 ID",
    "product_id": "产品 ID"
  },
  "ja": {
    "default_language": "デフォルト言語",
    "created_at": "作成日",
    "updated_at": "更新日",
    "status": "ステータス",
    "provider": "プロバイダー",
    "expiry_date": "有効期限",
    "purchase_token": "購入トークン",
    "order_id": "注文ID",
    "product_id": "製品ID"
  },
  "ko": {
    "default_language": "기본 언어",
    "created_at": "생성일",
    "updated_at": "수정일",
    "status": "상태",
    "provider": "제공자",
    "expiry_date": "만료일",
    "purchase_token": "구매 토큰",
    "order_id": "주문 ID",
    "product_id": "제품 ID"
  }
}
"""

translations = json.loads(data_str)

sql_commands = []
for lang, keys in translations.items():
    for key, translation in keys.items():
        escaped_translation = translation.replace("'", "''")
        sql_commands.append(f"INSERT OR REPLACE INTO ui_translations (key, lang, value, updated_at) VALUES ('{key}', '{lang}', '{escaped_translation}', CURRENT_TIMESTAMP);")

full_sql = "\n".join(sql_commands)
with open("scripts/sql/update_user_ui.sql", "w") as f:
    f.write(full_sql)

print("SQL script generated at scripts/sql/update_user_ui.sql")
