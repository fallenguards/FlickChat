"""Builds one language folder's word list (Packs/FlickChat_<code>/Words.lua): every word Tatoeba's sentences in
that language hold at least twice, with its count and its followers, the chat and game words below, the
game's own zone, dungeon, class and race names, and the mature filter's words.

python tools/build_pack.py <code> <folder of downloads> [least count]
The folder holds, for ptBR as the example:
  por_sentences.tsv.bz2, eng_sentences.tsv.bz2   https://tatoeba.org/en/downloads (per language)
  ldnoobw/pt.txt   https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words
  wago/Map_ptBR.csv, AreaTable_ptBR.csv, ChrClasses_ptBR.csv, ChrRaces_ptBR.csv
      the game's own tables: https://wago.tools/db2/<Table>/csv?locale=ptBR
"""
import bz2
import csv
import os
import re
import sys
import unicodedata
import zlib
from array import array
from collections import Counter, defaultdict

CODE, FOLDER = sys.argv[1], sys.argv[2]
LEAST = int(sys.argv[3]) if len(sys.argv) > 3 else 2
PAIR_MIN, NAME_RANK, CORE = 2, 1000, 12000
# A one-letter word counts from this many uses (a, e, o, y): fewer is a stray letter.
ONE_LETTER = 300
# Tatoeba holds drills: one sentence written out for every country, pronoun or tense. Sentences alike but for one
# word count together as this many at most, or a drill's words outrank the language's own.
FAMILY, SLOTS = 5, 1 << 25
# An elided word (l') is one from this many uses onto a next word: fewer is a name or a typo.
ELIDED_LEAST = 20
LETTERS = ["abc", "def", "ghi", "jklm", "nop", "qrs", "tuv", "wxyz"]
TOKEN = re.compile(r"[^\W\d_]+(?:'[^\W\d_]+)*'?")

# Game shorthand players of every language use, by how often chat uses it: the count of the word at that rank.
SHARED = {
    150: "ok lol gg afk brb lfg inv",
    600: """lfm wts wtb oom dps tank healer pst omw bg pvp xp lvl mob mobs aggro loot buff buffs raid pull wipe res
    rez gz ty thx np wp ez noob lag dc relog""",
    4000: """dm wc sfk bfd stocks gnomer sm rfk rfd ulda zf mara brd lbrs ubrs strat scholo dme ony mc bwl zg aq
    naxx rfc boe bop bis cc aoe mats nerf alt alts addon addons macro macros debuff debuffs gamepad controller
    Azeroth Kalimdor""",
}

# tatoeba: the language's code there; filter: its list's file; accents: its accented letters, for exact letters;
# elide: words are elided onto the next with an apostrophe (l'ami) and count joined and apart; nouns: every noun
# has a capital, so only a word English also writes with one is a name; everyday: words its filter list holds
# that are everyday ones, left out of the filter; chat: its own chat and game words by rank;
# layouts: optional letter groups for a non-Latin alphabet (must match the pack's precomputed rare keys).
LANGS = {
    "ptBR": dict(
        tatoeba="por", name="Portuguese", filter="pt", accents="áàâãçéêíóôõúü", elide=False, nouns=False,
        everyday="""aborto amador aranha ariano bissexual burro cerveja comer consolo heterosexual homosexual
        inferno mama pau pinto saco torneira chupar gozar veado cocaína heroína lésbica corno""",
        chat={
            150: "vlw blz tmj pq vc vcs tb tbm kk kkk rs flw obg pfv bora opa eae mano cara hj td tudo pra pro",
            600: """fmz tlgd glr galera vamo partiu grupo masmorra raide guilda missão missões nível mana ouro
            prata cobre vendedor montaria bolsa banco correio leilão item itens equipamento chefe farmar upar
            dropar convite alguém preciso procuro vendo compro troco ajuda horda aliança guerreiro mago ladino
            caçador bruxo druida paladino xamã sacerdote orc troll tauren humano anão gnomo elfo cura curandeiro
            tanque dano pronto prontos espera esperem puxa sussurro msg add""",
        }),
    "frFR": dict(
        tatoeba="fra", name="French", filter="fr", accents="àâçéèêëîïôùûüÿ", elide=True, nouns=False,
        everyday="""baiser bourré bourrée caca pipi chatte déconne déconner folle gerbe gerber gueule jouir meuf
        pédale péter ramoner tapette tanche trique zizi""",
        chat={
            150: "slt cc bjr bsr mdr ptdr stp svp tkt jsp dsl pk pcq pq oui non ouais nan dac merci mrc re",
            600: """wesh tlm qqn qq bcp tjs tjrs jms mtn ajd dmn groupe donjon guilde quête quêtes niveau mana
            po or argent cuivre vendeur monture sac banque courrier hv hdv objet stuff boss farm farmer pex
            invite recrute cherche vends achète échange aide horde alliance guerrier mage voleur chasseur
            démoniste druide paladin chaman prêtre orc troll tauren humain nain gnome elfe soigneur soin heal
            dégâts prêt prêts attends attendez déco reco mp chuchote wisp""",
        }),
    "deDE": dict(
        tatoeba="deu", name="German", filter="de", accents="äöüß", elide=False, nouns=True,
        everyday="bonze fratze nackt popel rosette mufti pinkeln kimme lümmel vollpfosten reudig",
        chat={
            150: "hi hallo moin servus jo ja ne nee nö okay kp ka vllt evtl danke bitte sry sorry mfg lg wb re bb",
            600: """hdl cya haha nice Gruppe Dungeon ini Instanz Gilde Quest Quests Level Stufe Mana Gold Silber
            Kupfer Händler Mount Reittier Tasche Bank Post ah Auktionshaus Item Items Gear Boss farmen leveln
            invite einladen suche biete verkaufe kaufe tausche Hilfe Horde Allianz Krieger Magier Schurke Jäger
            Hexenmeister Hexer Druide Paladin Schamane Priester Orc Troll Tauren Untoter Mensch Zwerg Gnom Elf
            Heiler Heilung heal dd dds Schaden bereit warten rezz flüstern Port Portal Ruhestein""",
        }),
    "itIT": dict(
        tatoeba="ita", name="Italian", filter="it", accents="àèéìòù", elide=True, nouns=False,
        everyday="""balle battere biga cadavere cesso cozza fava finocchio imbecille mannaggia monta montare
        palle patacca pesce pompa porca porco quaglia regina sbattere sega spagnola tirare topa vacca cagna
        pisello pippa bocchino bagnarsi lecchino ruffiano femminuccia boiata pistolotto pomiciare vangare cacca
        pipì""",
        chat={
            150: "ciao salve si sì no boh mah dai vabbè cmq nn xke perché grz grazie prego scusa raga asp",
            600: """tvb ahah ragazzi bella zio fra qlc qualcuno dove quando aspetta arrivo gruppo dungeon
            spedizione incursione gilda missione missioni livello mana oro argento rame mercante cavalcatura
            borsa banca posta asta oggetto oggetti equip boss farmare livellare invita invito cerco vendo compro
            scambio aiuto orda alleanza guerriero mago ladro cacciatore stregone druido paladino sciamano
            sacerdote orco troll tauren umano nano gnomo elfo curatore cura danno pronto pronti""",
        }),
    "esES": dict(
        tatoeba="spa", name="Spanish", filter="es", accents="áéíñóúü", elide=False, nouns=False,
        everyday="""asesinato asno caca concha drogas heroína idiota imbécil infierno maldito martillo orina pedo
        pis sádico trio maciza""",
        chat={
            150: "hola buenas wenas vale gracias grax jaja jajaja xq porq tb tmb porfa plis oki chao",
            600: """xd xfa pq sip nah tqm bn aki msj finde weno tío wey che compa bro grupo mazmorra mazmorras
            banda gremio hermandad misión misiones nivel maná oro plata cobre vendedor montura bolsa banco
            correo subasta subastas objeto objetos equipo jefe farmear levear lootear invita invitación alguien
            necesito busco vendo compro cambio ayuda horda alianza guerrero mago pícaro cazador brujo druida
            paladín chamán sacerdote orco trol tauren humano enano gnomo elfo sanador cura tanque daño listo
            listos espera esperen esperad susurro susurra""",
        }),
    "ruRU": dict(
        tatoeba="rus", name="Russian", filter="ru", accents="", elide=False, nouns=False,
        layouts={
            "letters": ["абвг", "деёж", "зийк", "лмно", "прст", "уфхц", "чшщъ", "ыьэюя"],
            "vowels": ["ае", "ёи", "оу", "ыэюя", "бвгджз", "йклмн", "прстф", "хцчшщъь"],
        },
        everyday="блин задница дурак идиот",
        chat={
            150: """привет ку спс спасибо пж плз ок ага нет да лол кек афк гц бб ща сек инв го
            мы этот данж знаем кто пойдёт сегодня""",
            600: """хил хила хилы хилер хилить танк танка танки дд дпс агро пул пулить вайп рес
            ресни баф бафы бафни дебаф мана омв лфг лфм пати рейд гильдия ги клан группа
            квест квесты данжи подземелье инст инсты босс босса боссы лут шмот шмотки фарм фармить
            кач качать качаться лвл уровень маунт голд голда золото серебро медь банк почта аук аукцион
            сумка сумки портал порт камень еда вода пить реген готов готовы подожди подождите иду бегу
            ищу нужен нужна нужны возьмите пригласите продам куплю обмен помоги помогите помощь сорри
            орда альянс воин вар маг рога разбойник хант охотник лок чернокнижник друид дру пал паладин
            шам шаман прист жрец орк тролль таурен нежить человек дворф гном эльф хилом танком ддшник
            дискорд войс аддон макрос пвп пве бг арена альт твинк профа крафт реагенты энчант""",
            4000: """Штормград Оргриммар Стальгорн Дарнас Подгород Громовой Утёс Азерот Калимдор
            Элвинн Западный Край Красногорье Сумеречный Лес Тернистая Долина Степи Танарис
            Мёртвые Копи Пещеры Стенаний Крепость Тёмного Клыка Непроглядная Пучина Тюрьма
            Гномреган Монастырь Алого Ордена Ульдаман Зулфаррак Мародон Глубины Чёрной Горы
            Некроситет Стратхольм Забытый Город Логово Ониксии Огненные Недра Наксрамас""",
        }),
}
LANG = LANGS[CODE]
LETTERS = LANG.get("layouts", {}).get("letters", LETTERS)
DIGIT = {c: str(g + 1) for g, letters in enumerate(LETTERS) for c in letters}
# A French word with an apostrophe that is no elision: never taken apart.
WHOLE = {"aujourd'hui", "prud'homme", "prud'hommes", "grand'mère"}


def fold(c):
    # Russian й and ё are letters in their own right, not accented и and е.
    if c in DIGIT:
        return c
    return "s" if c == "ß" else unicodedata.normalize("NFD", c)[0]


def key_of(word):
    out = []
    for c in word.lower():
        if c == "'":
            continue
        d = DIGIT.get(fold(c))
        if not d:
            return None
        out.append(d)
    return "".join(out)


def tokens_of(text):
    """A sentence's words as written, each with its parts when it is an elision (l'ami: l' and ami)."""
    text = text.replace("’", "'").replace("œ", "oe").replace("Œ", "Oe").replace("æ", "ae").replace("Æ", "Ae")
    out = []
    for tok in TOKEN.findall(text):
        parts = None
        if LANG["elide"] and "'" in tok.rstrip("'"):
            # d'aujourd'hui: only what stands before the whole word is taken off it
            tail = next((tok[-len(w):] for w in WHOLE if tok.lower().endswith(w)), "")
            pieces = tok[:len(tok) - len(tail)].split("'")
            parts = [p + "'" for p in pieces[:-1] if p] + ([pieces[-1] + tail] if pieces[-1] + tail else [])
            if len(parts) < 2:
                parts = None
        out.append((tok, parts))
    return out


def sentences(lang):
    with bz2.open(os.path.join(FOLDER, lang + "_sentences.tsv.bz2"), "rt", encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 3:
                yield parts[2]


def families(text):
    """A short sentence with each of its words left out in turn: where each such shape falls in the table."""
    words = [w.lower() for tok, parts in tokens_of(text) for w in (parts or [tok])]
    if not 3 <= len(words) <= 12:
        return ()
    return [zlib.crc32(" ".join(words[:i] + ["*"] + words[i + 1:]).encode("utf-8")) % SLOTS for i in range(len(words))]


shapes = array("H", bytes(2 * SLOTS))
for text in sentences(LANG["tatoeba"]):
    for slot in families(text):
        if shapes[slot] < 65535:
            shapes[slot] += 1

# Every word counts, an elision's parts each on their own and the elision as one word as well; what follows an
# elision follows it both as one word (l'ami) and as its last part (ami).
counts, capmid, lowmid, pairs = Counter(), Counter(), Counter(), Counter()
elided, spaced = Counter(), Counter()
drills = 0
for text in sentences(LANG["tatoeba"]):
    alike = max((shapes[slot] for slot in families(text)), default=1)
    weight = min(1, FAMILY / alike)
    drills += weight < 1
    prev, prev_joined, first = "<s>", None, True
    for tok, parts in tokens_of(text):
        if parts:
            counts[tok.lower()] += weight
            pairs[(prev, tok.lower())] += weight
        for i, word in enumerate(parts or [tok]):
            low = word.lower()
            counts[low] += weight
            if not first:
                (capmid if word[0].isupper() else lowmid)[low] += weight
            if low.endswith("'"):
                (elided if parts and i < len(parts) - 1 else spaced)[low] += weight
            pairs[(prev, low)] += weight
            if prev_joined and i == 0:
                pairs[(prev_joined, low)] += weight
            prev, first = low, False
        prev_joined = tok.lower() if parts else None
del shapes

# Names: mostly written with a capital mid-sentence. Where every noun has one, only those English writes so too.
english_names = set()
if LANG["nouns"]:
    en_cap, en_low = Counter(), Counter()
    for text in sentences("eng"):
        for i, tok in enumerate(re.findall(r"[A-Za-z]+", text)):
            if i:
                (en_cap if tok[0].isupper() else en_low)[tok.lower()] += 1
    english_names = {w for w, c in en_cap.items() if c >= 20 and c / (c + en_low[w]) > 0.9}


def capital(low):
    mid = capmid[low] + lowmid[low]
    return mid >= 3 and capmid[low] / mid > 0.6


def is_name(low):
    return capital(low) and (not LANG["nouns"] or low in english_names)


ranked = [w for w, _ in counts.most_common()]
name_cap = counts[ranked[NAME_RANK]]
words, forms, scale = {}, {}, {}
for low in ranked:
    if counts[low] < LEAST:
        break
    letters = low.replace("'", "")
    if len(low) > 20 or not letters or not key_of(low) or (len(letters) == 1 and counts[low] < ONE_LETTER):
        continue
    if low.endswith("'") and elided[low] < ELIDED_LEAST and spaced[low] < ELIDED_LEAST:
        continue
    if is_name(low):
        words[low] = min(counts[low], name_cap)
        if counts[low] > name_cap:
            scale[low] = name_cap / counts[low]
    else:
        words[low] = counts[low]
    if capital(low):
        forms[low] = low[0].upper() + low[1:]

by_rank = sorted(words.values(), reverse=True)
for source in (SHARED, LANG["chat"]):
    for rank, chat in source.items():
        for w in chat.split():
            low = w.lower()
            if not key_of(low):
                continue  # Latin shorthand cannot be typed on a Cyrillic-only layout.
            words[low] = max(words.get(low, 0), by_rank[rank])
            if w != low:
                forms[low] = w
            elif not LANG["nouns"]:
                forms.pop(low, None)

# The game's own names in this language: each word of a classic dungeon, raid, zone, class or race name the
# list lacks, with its capital.
game = set()


def table(name, keep, columns):
    with open(os.path.join(FOLDER, "wago", "%s_%s.csv" % (name, CODE)), encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            if keep(row):
                for column in columns:
                    for tok, parts in tokens_of(row[column]):
                        for word in parts or [tok]:
                            if len(word) >= 4 and word[0].isupper() and not word.endswith("'"):
                                game.add(word)


table("Map", lambda r: r["InstanceType"] in ("1", "2") and r["ExpansionID"] == "0", ["MapName_lang"])
table("AreaTable", lambda r: r["ContinentID"] in ("0", "1") and r["ParentAreaID"] == "0", ["AreaName_lang"])
table("ChrClasses", lambda r: True, ["Name_male_lang", "Name_female_lang"])
table("ChrRaces", lambda r: True, ["Name_lang", "Name_female_lang"])
added = 0
for word in sorted(game):
    low = word.lower()
    if low not in words and key_of(low):
        words[low], forms[low] = by_rank[4000], word
        added += 1
    elif low in words and low not in forms and not lowmid[low]:
        # a rare word the sentences never wrote small: the game's capital
        forms[low] = word

# Words the repo's commit checks refuse in a tracked file, one per line, when the list is there.
try:
    with open("dev/leave_out.txt", encoding="utf-8") as f:
        for w in f.read().split():
            words.pop(w.lower(), None)
except FileNotFoundError:
    pass

everyday = set(LANG["everyday"].split())
with open(os.path.join(FOLDER, "ldnoobw", LANG["filter"] + ".txt"), encoding="utf-8") as f:
    mature = sorted({w.strip().lower() for w in f if w.strip() and " " not in w.strip()} - everyday)
joins = sorted(w for w in words if w.endswith("'") and elided[w] > spaced[w])

ranked_all = sorted(words, key=lambda w: (-words[w], w))
order = [w for i, w in enumerate(ranked_all) if i < CORE or len(w.replace("'", "")) < 3]
index = {w: i + 1 for i, w in enumerate(order)}
index["<s>"] = 0
followers = defaultdict(list)
context_total, context_kinds = Counter(), Counter()
for (a, b), c in pairs.items():
    if a not in index:
        continue
    c = c * scale.get(a, 1) * scale.get(b, 1)
    context_total[a] += c
    context_kinds[a] += 1
    if b in index and b != "<s>" and int(c) >= PAIR_MIN:
        followers[a].append((int(c), index[b]))
kept = 0
for a in followers:
    followers[a].sort(key=lambda f: (-f[0], f[1]))
    kept += len(followers[a])

buckets = defaultdict(list)
for w in ranked_all:
    if w not in index:
        key = key_of(w)
        buckets[key[:4]].append((key, -words[w], forms.get(w, w)))

out_dir = os.path.join("Packs", "FlickChat_" + CODE)
os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, "Words.lua"), "w", encoding="utf-8", newline="\n") as out:
    out.write("-- %s words for FlickChat's keyboard: tools/build_pack.py writes this file. Words and counts from\n"
              % LANG["name"])
    out.write("-- Tatoeba's %s sentences, the filter's words from LDNOOBW (see FlickChat's CREDITS.txt).\n" % LANG["name"])
    out.write("-- words: word and count lines, commonest first; pairs: each word's followers by the word lines' numbers\n")
    out.write("-- (0 starts a message): times followed, by how many different words, then follower and count pairs;\n")
    out.write("-- rare: the rarer words by key, lines of key, word, count.\n")
    out.write('FlickChat_AddWords("%s", {\n' % CODE)
    if "layouts" in LANG:
        out.write("layouts = {\n")
        for name, groups in LANG["layouts"].items():
            out.write('    %s = { %s },\n' % (name, ", ".join('"%s"' % g for g in groups)))
        out.write("},\n")
    out.write('accents = "%s",\n' % LANG["accents"])
    out.write('joins = "%s",\n' % " ".join(joins))
    out.write("mature = [[\n%s\n]],\n" % "\n".join(mature))
    out.write("words = [[\n")
    for w in order:
        out.write(f"{forms.get(w, w)} {max(1, round(words[w]))}\n")
    out.write("]],\npairs = {\n")
    for a in sorted(context_total, key=lambda w: index[w]):
        items = " ".join(f"{b} {c}" for c, b in followers[a])
        out.write(f'[{index[a]}] = "{int(context_total[a])} {context_kinds[a]} {items}",\n')
    out.write("},\nrare = {\n")
    for head in sorted(buckets):
        out.write(f'["{head}"] = [[\n\n')
        for key, neg, form in sorted(buckets[head]):
            out.write(f"{key} {form} {max(1, round(-neg))}\n")
        out.write("]],\n")
    out.write("},\n})\n")
print(CODE, len(order), "common words,", sum(len(b) for b in buckets.values()), "rarer in", len(buckets), "blocks,",
      kept, "pairs;", added, "game names added;", len(mature), "filter words;", len(joins), "elided words;",
      drills, "drill sentences counted down")
print("top:", " ".join(forms.get(w, w) for w in order[:50]))
if joins:
    print("elided:", " ".join(joins[:60]))
