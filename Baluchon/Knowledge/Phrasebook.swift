import Foundation

struct Phrase: Identifiable, Hashable {
    let id: String
    let french: String
    let local: String
    /// Prononciation approximative (alphabets non latins).
    let romanization: String?

    /// Remplace les champs `{nom}` et `{allergie}` par les infos du profil.
    func personalized(name: String, allergy: String) -> Phrase {
        func fill(_ s: String) -> String {
            s.replacingOccurrences(of: "{nom}", with: name.isEmpty ? "…" : name)
                .replacingOccurrences(of: "{allergie}", with: allergy.isEmpty ? "…" : allergy)
        }
        return Phrase(id: id, french: fill(french), local: fill(local), romanization: romanization.map(fill))
    }
}

/// Phrases utiles préécrites, disponibles hors ligne et lisibles par la synthèse vocale.
enum Phrasebook {
    static let frenchPrompts: [(id: String, text: String)] = [
        ("hello", "Bonjour"),
        ("thanks", "Merci"),
        ("reservation", "J'ai une réservation au nom de {nom}"),
        ("price", "Combien ça coûte ?"),
        ("toilets", "Où sont les toilettes ?"),
        ("bill", "L'addition, s'il vous plaît"),
        ("allergy", "Je suis allergique à : {allergie}"),
        ("address", "Pouvez-vous m'emmener à cette adresse ?"),
        ("help", "À l'aide !"),
        ("nospeak", "Je ne parle pas la langue, désolé(e)"),
    ]

    /// Traductions : (texte local, romanisation éventuelle), dans l'ordre de `frenchPrompts`.
    private static let tables: [String: [(String, String?)]] = [
        "vi": [
            ("Xin chào", nil),
            ("Cảm ơn", nil),
            ("Tôi có đặt chỗ tên là {nom}", nil),
            ("Cái này bao nhiêu tiền?", nil),
            ("Nhà vệ sinh ở đâu?", nil),
            ("Làm ơn tính tiền", nil),
            ("Tôi bị dị ứng với {allergie}", nil),
            ("Làm ơn chở tôi đến địa chỉ này", nil),
            ("Cứu tôi với!", nil),
            ("Xin lỗi, tôi không nói được tiếng Việt", nil),
        ],
        "en": [
            ("Hello", nil),
            ("Thank you", nil),
            ("I have a reservation under the name {nom}", nil),
            ("How much is it?", nil),
            ("Where is the restroom?", nil),
            ("Could I have the check, please?", nil),
            ("I'm allergic to {allergie}", nil),
            ("Could you take me to this address?", nil),
            ("Help!", nil),
            ("Sorry, I don't speak English very well", nil),
        ],
        "ja": [
            ("こんにちは", "Konnichiwa"),
            ("ありがとうございます", "Arigatō gozaimasu"),
            ("{nom}の名前で予約しています", "{nom} no namae de yoyaku shite imasu"),
            ("いくらですか？", "Ikura desu ka ?"),
            ("トイレはどこですか？", "Toire wa doko desu ka ?"),
            ("お会計をお願いします", "Okaikei o onegai shimasu"),
            ("{allergie}のアレルギーがあります", "{allergie} no arerugī ga arimasu"),
            ("この住所までお願いします", "Kono jūsho made onegai shimasu"),
            ("助けて！", "Tasukete !"),
            ("すみません、日本語が話せません", "Sumimasen, nihongo ga hanasemasen"),
        ],
        "th": [
            ("สวัสดีครับ/ค่ะ", "Sawatdee khrap/kha"),
            ("ขอบคุณครับ/ค่ะ", "Khop khun khrap/kha"),
            ("จองไว้ในชื่อ {nom}", "Jong wai nai chue {nom}"),
            ("ราคาเท่าไหร่", "Rakha thao rai ?"),
            ("ห้องน้ำอยู่ที่ไหน", "Hong nam yu thi nai ?"),
            ("เช็คบิลด้วย", "Check bin duai"),
            ("แพ้ {allergie}", "Phae {allergie}"),
            ("ไปที่อยู่นี้ได้ไหม", "Pai thi yu ni dai mai ?"),
            ("ช่วยด้วย!", "Chuai duai !"),
            ("ขอโทษ พูดภาษาไทยไม่ได้", "Kho thot, phut phasa thai mai dai"),
        ],
        "es": [
            ("Hola", nil),
            ("Gracias", nil),
            ("Tengo una reserva a nombre de {nom}", nil),
            ("¿Cuánto cuesta?", nil),
            ("¿Dónde está el baño?", nil),
            ("La cuenta, por favor", nil),
            ("Soy alérgico/a a {allergie}", nil),
            ("¿Puede llevarme a esta dirección?", nil),
            ("¡Ayuda!", nil),
            ("Lo siento, no hablo español", nil),
        ],
        "it": [
            ("Buongiorno", nil),
            ("Grazie", nil),
            ("Ho una prenotazione a nome di {nom}", nil),
            ("Quanto costa?", nil),
            ("Dov'è il bagno?", nil),
            ("Il conto, per favore", nil),
            ("Sono allergico/a a {allergie}", nil),
            ("Può portarmi a questo indirizzo?", nil),
            ("Aiuto!", nil),
            ("Mi dispiace, non parlo italiano", nil),
        ],
        "pt": [
            ("Olá, bom dia", nil),
            ("Obrigado / Obrigada", nil),
            ("Tenho uma reserva em nome de {nom}", nil),
            ("Quanto custa?", nil),
            ("Onde é a casa de banho?", nil),
            ("A conta, por favor", nil),
            ("Sou alérgico/a a {allergie}", nil),
            ("Pode levar-me a esta morada?", nil),
            ("Socorro!", nil),
            ("Desculpe, não falo português", nil),
        ],
        "el": [
            ("Γεια σας", "Yia sas"),
            ("Ευχαριστώ", "Efcharistó"),
            ("Έχω κράτηση στο όνομα {nom}", "Écho krátisi sto ónoma {nom}"),
            ("Πόσο κοστίζει;", "Póso kostízi ?"),
            ("Πού είναι η τουαλέτα;", "Pou íne i toualéta ?"),
            ("Τον λογαριασμό, παρακαλώ", "Ton logariasmó, parakaló"),
            ("Είμαι αλλεργικός/ή σε {allergie}", "Íme alergikós/í se {allergie}"),
            ("Μπορείτε να με πάτε σε αυτή τη διεύθυνση;", "Boríte na me páte se aftí ti diéfthinsi ?"),
            ("Βοήθεια!", "Voíthia !"),
            ("Συγγνώμη, δεν μιλάω ελληνικά", "Signómi, den miláo elliniká"),
        ],
        "id": [
            ("Halo, selamat pagi", nil),
            ("Terima kasih", nil),
            ("Saya punya reservasi atas nama {nom}", nil),
            ("Berapa harganya?", nil),
            ("Di mana toiletnya?", nil),
            ("Minta bonnya, ya", nil),
            ("Saya alergi {allergie}", nil),
            ("Bisa antar saya ke alamat ini?", nil),
            ("Tolong!", nil),
            ("Maaf, saya tidak bisa berbahasa Indonesia", nil),
        ],
    ]

    static func phrases(for languageCode: String?) -> [Phrase] {
        guard let languageCode,
              let prefix = languageCode.split(separator: "-").first.map(String.init),
              let table = tables[prefix] else { return [] }
        return zip(frenchPrompts, table).map { prompt, translation in
            Phrase(id: prompt.id, french: prompt.text, local: translation.0, romanization: translation.1)
        }
    }

    static var supportedLanguagePrefixes: [String] { Array(tables.keys) }
}
