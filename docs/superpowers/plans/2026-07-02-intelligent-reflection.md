# Intelligent Daily Reflection Engine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static 3-template reflection card with a rich, context-aware reflection engine that analyzes today's log + historical data to produce multi-paragraph spiritual reflections with relevant Scripture verses.

**Architecture:** A `ReflectionService` singleton with a `ReflectionProvider` interface. Ships with `RuleBasedReflectionProvider` (offline). The log screen calls `ReflectionService.generate()` and displays the structured `ReflectionResult` in a collapsible card. Future AI providers slot in without UI changes.

**Tech Stack:** Flutter/Dart, ARB localization, existing `StorageService`/`ReportService` for historical data.

## Global Constraints

- Fully offline — no network calls, no API keys
- All user-facing strings in ARB files (EN + FR)
- Follow existing singleton pattern: `static final instance = Service._()`
- Follow existing theme: `AppTheme` colors, `Cormorant Garamond` display, `Lora` serif
- `flutter analyze` must pass clean (no new warnings)

---

## File Structure

| File | Responsibility |
|------|---------------|
| `lib/data/scripture_library.dart` | **New** — `ScriptureVerse` data class + curated verse library (60 verses, EN/FR, tagged by discipline/situation) |
| `lib/services/reflection_service.dart` | **New** — `ReflectionResult`, `ReflectionContext`, `ReflectionProvider` interface, `RuleBasedReflectionProvider`, `ReflectionService` singleton |
| `lib/l10n/app_en.arb` | **Modify** — Add ~90 reflection template ARB keys |
| `lib/l10n/app_fr.arb` | **Modify** — Add ~90 French translation keys |
| `lib/screens/log_screen.dart` | **Modify** — Replace `_buildReflectionCard`, add debounced reflection regeneration, collapsible UI |

---

### Task 1: Scripture Verse Library

**Files:**
- Create: `lib/data/scripture_library.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `ScriptureVerse` class with `tag`, `reference`, `textEn`, `textFr` fields. `ScriptureLibrary.forTag(String tag, String dateKey)` returns a deterministically-random verse for the given tag and date. `ScriptureLibrary.pickVerse(...)` selects the best tag based on log signals.

- [ ] **Step 1: Create the scripture_library.dart file with ScriptureVerse class and full verse data**

Create `lib/data/scripture_library.dart`:

```dart
/// A single Scripture verse with bilingual text and a category tag.
class ScriptureVerse {
  final String tag;
  final String reference;
  final String textEn;
  final String textFr;

  const ScriptureVerse({
    required this.tag,
    required this.reference,
    required this.textEn,
    required this.textFr,
  });

  /// Returns the text in the given locale ('en' or 'fr').
  String text(String locale) => locale.startsWith('fr') ? textFr : textEn;
}

/// Curated Scripture library for the reflection engine.
/// ~60 verses organized by discipline and situation tags.
class ScriptureLibrary {
  ScriptureLibrary._();

  static const List<ScriptureVerse> _verses = [
    // ── Bible (5) ──
    ScriptureVerse(tag: 'bible', reference: 'Psalm 119:105',
      textEn: 'Your word is a lamp to my feet and a light to my path.',
      textFr: 'Ta parole est une lampe à mes pieds et une lumière sur mon sentier.'),
    ScriptureVerse(tag: 'bible', reference: 'Joshua 1:8',
      textEn: 'Keep this Book of the Law always on your lips; meditate on it day and night.',
      textFr: 'Que ce livre de la loi ne s\'éloigne point de ta bouche ; médite-le jour et nuit.'),
    ScriptureVerse(tag: 'bible', reference: '2 Timothy 3:16',
      textEn: 'All Scripture is God-breathed and is useful for teaching, rebuking, correcting and training in righteousness.',
      textFr: 'Toute Écriture est inspirée de Dieu et utile pour enseigner, pour convaincre, pour corriger, pour instruire dans la justice.'),
    ScriptureVerse(tag: 'bible', reference: 'Hebrews 4:12',
      textEn: 'For the word of God is alive and active. Sharper than any double-edged sword.',
      textFr: 'Car la parole de Dieu est vivante et efficace, plus tranchante qu\'une épée quelconque à deux tranchants.'),
    ScriptureVerse(tag: 'bible', reference: 'Psalm 1:2',
      textEn: 'But whose delight is in the law of the Lord, and who meditates on his law day and night.',
      textFr: 'Mais qui trouve son plaisir dans la loi de l\'Éternel, et qui la médite jour et nuit.'),

    // ── Prayer (5) ──
    ScriptureVerse(tag: 'prayer', reference: 'Philippians 4:6',
      textEn: 'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.',
      textFr: 'Ne vous inquiétez de rien ; mais en toute chose faites connaître vos besoins à Dieu par des prières et des supplications, avec des actions de grâces.'),
    ScriptureVerse(tag: 'prayer', reference: '1 Thessalonians 5:17',
      textEn: 'Pray continually.',
      textFr: 'Priez sans cesse.'),
    ScriptureVerse(tag: 'prayer', reference: 'Matthew 7:7',
      textEn: 'Ask and it will be given to you; seek and you will find; knock and the door will be opened to you.',
      textFr: 'Demandez, et l\'on vous donnera ; cherchez, et vous trouverez ; frappez, et l\'on vous ouvrira.'),
    ScriptureVerse(tag: 'prayer', reference: 'Jeremiah 33:3',
      textEn: 'Call to me and I will answer you and tell you great and unsearchable things you do not know.',
      textFr: 'Invoque-moi, et je te répondrai ; je t\'annoncerai de grandes choses, des choses cachées, que tu ne connais pas.'),
    ScriptureVerse(tag: 'prayer', reference: 'Psalm 145:18',
      textEn: 'The Lord is near to all who call on him, to all who call on him in truth.',
      textFr: 'L\'Éternel est près de tous ceux qui l\'invoquent, de tous ceux qui l\'invoquent avec sincérité.'),

    // ── Evangelism (5) ──
    ScriptureVerse(tag: 'evangelism', reference: 'Matthew 28:19',
      textEn: 'Therefore go and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit.',
      textFr: 'Allez, faites de toutes les nations des disciples, les baptisant au nom du Père, du Fils et du Saint-Esprit.'),
    ScriptureVerse(tag: 'evangelism', reference: 'Romans 10:14',
      textEn: 'How, then, can they call on the one they have not believed in? And how can they believe in the one of whom they have not heard?',
      textFr: 'Comment donc invoqueront-ils celui en qui ils n\'ont pas cru ? Et comment croiront-ils en celui dont ils n\'ont pas entendu parler ?'),
    ScriptureVerse(tag: 'evangelism', reference: 'Acts 1:8',
      textEn: 'But you will receive power when the Holy Spirit comes on you; and you will be my witnesses.',
      textFr: 'Mais vous recevrez une puissance, le Saint-Esprit survenant sur vous, et vous serez mes témoins.'),
    ScriptureVerse(tag: 'evangelism', reference: 'Mark 16:15',
      textEn: 'Go into all the world and preach the gospel to all creation.',
      textFr: 'Allez par tout le monde, et prêchez la bonne nouvelle à toute la création.'),
    ScriptureVerse(tag: 'evangelism', reference: 'Proverbs 11:30',
      textEn: 'The fruit of the righteous is a tree of life, and the one who is wise saves lives.',
      textFr: 'Le fruit du juste est un arbre de vie, et le sage s\'empare des âmes.'),

    // ── Fasting (4) ──
    ScriptureVerse(tag: 'fasting', reference: 'Isaiah 58:6',
      textEn: 'Is not this the kind of fasting I have chosen: to loose the chains of injustice and set the oppressed free?',
      textFr: 'Voici le jeûne auquel je prends plaisir : détache les chaînes de la méchanceté, renvoie libres les opprimés.'),
    ScriptureVerse(tag: 'fasting', reference: 'Matthew 6:17-18',
      textEn: 'But when you fast, put oil on your head and wash your face, so that it will not be obvious to others that you are fasting.',
      textFr: 'Mais quand tu jeûnes, parfume ta tête et lave ton visage, afin de ne pas montrer aux hommes que tu jeûnes.'),
    ScriptureVerse(tag: 'fasting', reference: 'Joel 2:12',
      textEn: '"Even now," declares the Lord, "return to me with all your heart, with fasting and weeping and mourning."',
      textFr: '« Maintenant encore, » dit l\'Éternel, « revenez à moi de tout votre cœur, avec des jeûnes, avec des pleurs et des lamentations. »'),
    ScriptureVerse(tag: 'fasting', reference: 'Acts 13:2-3',
      textEn: 'While they were worshiping the Lord and fasting, the Holy Spirit said, "Set apart for me Barnabas and Saul."',
      textFr: 'Pendant qu\'ils servaient le Seigneur dans leur ministère et qu\'ils jeûnaient, le Saint-Esprit dit : « Mettez-moi à part Barnabas et Saul. »'),

    // ── Giving (4) ──
    ScriptureVerse(tag: 'giving', reference: '2 Corinthians 9:7',
      textEn: 'Each of you should give what you have decided in your heart to give, not reluctantly or under compulsion, for God loves a cheerful giver.',
      textFr: 'Que chacun donne comme il l\'a résolu en son cœur, sans tristesse ni contrainte ; car Dieu aime celui qui donne avec joie.'),
    ScriptureVerse(tag: 'giving', reference: 'Proverbs 3:9',
      textEn: 'Honor the Lord with your wealth, with the firstfruits of all your crops.',
      textFr: 'Honore l\'Éternel avec tes biens, et avec les prémices de tout ton revenu.'),
    ScriptureVerse(tag: 'giving', reference: 'Malachi 3:10',
      textEn: 'Bring the whole tithe into the storehouse, that there may be food in my house. Test me in this, says the Lord Almighty.',
      textFr: 'Apportez à la maison du trésor toutes les dîmes. Mettez-moi de la sorte à l\'épreuve, dit l\'Éternel des armées.'),
    ScriptureVerse(tag: 'giving', reference: 'Luke 6:38',
      textEn: 'Give, and it will be given to you. A good measure, pressed down, shaken together and running over.',
      textFr: 'Donnez, et il vous sera donné : on versera dans votre sein une bonne mesure, serrée, secouée et qui déborde.'),

    // ── Church (4) ──
    ScriptureVerse(tag: 'church', reference: 'Hebrews 10:25',
      textEn: 'Not giving up meeting together, as some are in the habit of doing, but encouraging one another.',
      textFr: 'N\'abandonnons pas notre assemblée, comme c\'est la coutume de quelques-uns ; mais exhortons-nous réciproquement.'),
    ScriptureVerse(tag: 'church', reference: 'Acts 2:42',
      textEn: 'They devoted themselves to the apostles\' teaching and to fellowship, to the breaking of bread and to prayer.',
      textFr: 'Ils persévéraient dans l\'enseignement des apôtres, dans la communion fraternelle, dans la fraction du pain, et dans les prières.'),
    ScriptureVerse(tag: 'church', reference: 'Psalm 133:1',
      textEn: 'How good and pleasant it is when God\'s people live together in unity!',
      textFr: 'Voici, oh ! qu\'il est agréable, qu\'il est doux pour des frères de demeurer ensemble !'),
    ScriptureVerse(tag: 'church', reference: 'Matthew 18:20',
      textEn: 'For where two or three gather in my name, there am I with them.',
      textFr: 'Car là où deux ou trois sont assemblés en mon nom, je suis au milieu d\'eux.'),

    // ── Discipleship (4) ──
    ScriptureVerse(tag: 'discipleship', reference: '2 Timothy 2:2',
      textEn: 'And the things you have heard me say in the presence of many witnesses entrust to reliable people who will also be qualified to teach others.',
      textFr: 'Et ce que tu as entendu de moi en présence de beaucoup de témoins, confie-le à des hommes fidèles, qui soient capables de l\'enseigner aussi à d\'autres.'),
    ScriptureVerse(tag: 'discipleship', reference: 'Proverbs 27:17',
      textEn: 'As iron sharpens iron, so one person sharpens another.',
      textFr: 'Comme le fer aiguise le fer, ainsi un homme aiguise un autre homme.'),
    ScriptureVerse(tag: 'discipleship', reference: 'Colossians 3:16',
      textEn: 'Let the message of Christ dwell among you richly as you teach and admonish one another with all wisdom.',
      textFr: 'Que la parole de Christ habite parmi vous abondamment ; instruisez-vous et exhortez-vous les uns les autres en toute sagesse.'),
    ScriptureVerse(tag: 'discipleship', reference: 'Matthew 28:19-20',
      textEn: 'Go and make disciples of all nations... teaching them to obey everything I have commanded you.',
      textFr: 'Allez, faites de toutes les nations des disciples... et enseignez-leur à observer tout ce que je vous ai prescrit.'),

    // ── Literature (3) ──
    ScriptureVerse(tag: 'literature', reference: 'Proverbs 4:7',
      textEn: 'The beginning of wisdom is this: Get wisdom. Though it cost all you have, get understanding.',
      textFr: 'Voici le commencement de la sagesse : Acquiers la sagesse, et avec tout ce que tu possèdes acquiers l\'intelligence.'),
    ScriptureVerse(tag: 'literature', reference: 'Proverbs 18:15',
      textEn: 'The heart of the discerning acquires knowledge, for the ears of the wise seek it out.',
      textFr: 'Un cœur intelligent acquiert la science, et l\'oreille des sages cherche la science.'),
    ScriptureVerse(tag: 'literature', reference: '2 Timothy 2:15',
      textEn: 'Do your best to present yourself to God as one approved, a worker who does not need to be ashamed and who correctly handles the word of truth.',
      textFr: 'Efforce-toi de te présenter devant Dieu comme un homme éprouvé, un ouvrier qui n\'a point à rougir, qui dispense droitement la parole de la vérité.'),

    // ── DDEG (3) ──
    ScriptureVerse(tag: 'ddeg', reference: 'Psalm 46:10',
      textEn: 'Be still, and know that I am God.',
      textFr: 'Arrêtez, et sachez que je suis Dieu.'),
    ScriptureVerse(tag: 'ddeg', reference: 'Jeremiah 29:13',
      textEn: 'You will seek me and find me when you seek me with all your heart.',
      textFr: 'Vous me chercherez, et vous me trouverez, si vous me cherchez de tout votre cœur.'),
    ScriptureVerse(tag: 'ddeg', reference: 'John 10:27',
      textEn: 'My sheep listen to my voice; I know them, and they follow me.',
      textFr: 'Mes brebis entendent ma voix ; je les connais, et elles me suivent.'),

    // ── Proclamation (3) ──
    ScriptureVerse(tag: 'proclamation', reference: 'Romans 10:9-10',
      textEn: 'If you declare with your mouth, "Jesus is Lord," and believe in your heart that God raised him from the dead, you will be saved.',
      textFr: 'Si tu confesses de ta bouche le Seigneur Jésus, et si tu crois dans ton cœur que Dieu l\'a ressuscité des morts, tu seras sauvé.'),
    ScriptureVerse(tag: 'proclamation', reference: 'Psalm 107:2',
      textEn: 'Let the redeemed of the Lord tell their story — those he redeemed from the hand of the foe.',
      textFr: 'Qu\'ainsi disent les rachetés de l\'Éternel, ceux qu\'il a délivrés de la main de l\'ennemi.'),
    ScriptureVerse(tag: 'proclamation', reference: 'Revelation 12:11',
      textEn: 'They triumphed over him by the blood of the Lamb and by the word of their testimony.',
      textFr: 'Ils l\'ont vaincu à cause du sang de l\'Agneau et à cause de la parole de leur témoignage.'),

    // ── Streak (4) ──
    ScriptureVerse(tag: 'streak', reference: 'Galatians 6:9',
      textEn: 'Let us not become weary in doing good, for at the proper time we will reap a harvest if we do not give up.',
      textFr: 'Ne nous lassons pas de faire le bien ; car nous moissonnerons au temps convenable, si nous ne nous relâchons pas.'),
    ScriptureVerse(tag: 'streak', reference: '1 Corinthians 15:58',
      textEn: 'Therefore, my dear brothers and sisters, stand firm. Let nothing move you. Always give yourselves fully to the work of the Lord.',
      textFr: 'Ainsi, mes frères bien-aimés, soyez fermes, inébranlables, travaillant de mieux en mieux à l\'œuvre du Seigneur.'),
    ScriptureVerse(tag: 'streak', reference: 'Hebrews 12:1',
      textEn: 'Let us run with perseverance the race marked out for us.',
      textFr: 'Courons avec persévérance dans la carrière qui nous est ouverte.'),
    ScriptureVerse(tag: 'streak', reference: 'Philippians 3:14',
      textEn: 'I press on toward the goal to win the prize for which God has called me heavenward in Christ Jesus.',
      textFr: 'Je cours vers le but, pour remporter le prix de la vocation céleste de Dieu en Jésus-Christ.'),

    // ── Comeback (3) ──
    ScriptureVerse(tag: 'comeback', reference: 'Lamentations 3:22-23',
      textEn: 'Because of the Lord\'s great love we are not consumed, for his compassions never fail. They are new every morning.',
      textFr: 'Les bontés de l\'Éternel ne sont pas épuisées, ses compassions ne sont pas à leur terme. Elles se renouvellent chaque matin.'),
    ScriptureVerse(tag: 'comeback', reference: 'Micah 7:8',
      textEn: 'Do not gloat over me, my enemy! Though I have fallen, I will rise.',
      textFr: 'Ne te réjouis pas à mon sujet, mon ennemie ! Car si je suis tombée, je me relèverai.'),
    ScriptureVerse(tag: 'comeback', reference: 'Psalm 37:24',
      textEn: 'Though he may stumble, he will not fall, for the Lord upholds him with his hand.',
      textFr: 'S\'il tombe, il n\'est pas terrassé, car l\'Éternel lui prend la main.'),

    // ── Balanced (3) ──
    ScriptureVerse(tag: 'balanced', reference: 'Colossians 3:17',
      textEn: 'And whatever you do, whether in word or deed, do it all in the name of the Lord Jesus, giving thanks to God the Father through him.',
      textFr: 'Et quoi que vous fassiez, en parole ou en œuvre, faites tout au nom du Seigneur Jésus, en rendant grâces par lui à Dieu le Père.'),
    ScriptureVerse(tag: 'balanced', reference: 'Ecclesiastes 3:1',
      textEn: 'There is a time for everything, and a season for every activity under the heavens.',
      textFr: 'Il y a un temps pour tout, un temps pour toute chose sous les cieux.'),
    ScriptureVerse(tag: 'balanced', reference: '1 Corinthians 10:31',
      textEn: 'So whether you eat or drink or whatever you do, do it all for the glory of God.',
      textFr: 'Soit donc que vous mangiez, soit que vous buviez, soit que vous fassiez quelque autre chose, faites tout pour la gloire de Dieu.'),

    // ── Morning (3) ──
    ScriptureVerse(tag: 'morning', reference: 'Psalm 5:3',
      textEn: 'In the morning, Lord, you hear my voice; in the morning I lay my requests before you and wait expectantly.',
      textFr: 'Éternel ! le matin tu entends ma voix ; le matin je me tourne vers toi, et je regarde.'),
    ScriptureVerse(tag: 'morning', reference: 'Lamentations 3:23',
      textEn: 'Great is your faithfulness. They are new every morning.',
      textFr: 'Grande est ta fidélité. Elles se renouvellent chaque matin.'),
    ScriptureVerse(tag: 'morning', reference: 'Psalm 143:8',
      textEn: 'Let the morning bring me word of your unfailing love, for I have put my trust in you.',
      textFr: 'Fais-moi dès le matin entendre ta bonté, car je me confie en toi.'),

    // ── Evening (3) ──
    ScriptureVerse(tag: 'evening', reference: 'Psalm 4:8',
      textEn: 'In peace I will lie down and sleep, for you alone, Lord, make me dwell in safety.',
      textFr: 'Je me couche et je m\'endors en paix, car toi seul, ô Éternel ! tu me donnes la sécurité.'),
    ScriptureVerse(tag: 'evening', reference: 'Psalm 63:6',
      textEn: 'On my bed I remember you; I think of you through the watches of the night.',
      textFr: 'Lorsque je pense à toi sur ma couche, je médite sur toi pendant les veilles de la nuit.'),
    ScriptureVerse(tag: 'evening', reference: 'Psalm 119:148',
      textEn: 'My eyes stay open through the watches of the night, that I may meditate on your promises.',
      textFr: 'Mes yeux devancent les veilles de la nuit, pour méditer ta parole.'),
  ];

  /// Get all verses with the given tag.
  static List<ScriptureVerse> forTag(String tag) =>
      _verses.where((v) => v.tag == tag).toList();

  /// Pick a deterministically-random verse for the given tag and date.
  /// Same date + same tag = same verse (stable within a day).
  static ScriptureVerse? pickFromTag(String tag, String dateKey) {
    final candidates = forTag(tag);
    if (candidates.isEmpty) return null;
    final seed = dateKey.hashCode ^ tag.hashCode;
    return candidates[seed.abs() % candidates.length];
  }
}
```

- [ ] **Step 2: Verify file compiles**

Run: `cd "c:/Users/goodn/Developement/Flutter projects/daily_account" && flutter analyze lib/data/scripture_library.dart`

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/data/scripture_library.dart
git commit -m "feat: add curated Scripture library (60 verses, EN/FR, tagged by discipline)"
```

---

### Task 2: Reflection Service — Data Models + Provider Interface + Rule Engine

**Files:**
- Create: `lib/services/reflection_service.dart`

**Interfaces:**
- Consumes: `ScriptureLibrary.pickFromTag(tag, dateKey)` from Task 1, `DailyLog` from `lib/models/daily_log.dart`, `ReportService._disciplineChecks` (logic duplicated since it's private), `ReportService._parseDurationMinutes` (logic duplicated since it's private)
- Produces: `ReflectionService.instance.generate(DailyLog log, ReflectionContext ctx, String locale) → Future<ReflectionResult>`, `ReflectionResult` (with `toJsonString()`/`fromJsonString()` serialization), `ReflectionContext`

- [ ] **Step 1: Create reflection_service.dart with all models, interface, rule engine, and service**

Create `lib/services/reflection_service.dart`. This is a large file — it contains: `ReflectionResult`, `ReflectionContext`, the `ReflectionProvider` interface, the full `RuleBasedReflectionProvider` with narrative/encouragement/suggestion/verse logic, and the `ReflectionService` singleton.

```dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/scripture_library.dart';
import '../models/daily_log.dart';

// ═══════════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════════

/// The structured output of the reflection engine.
class ReflectionResult {
  final String narrative;
  final String encouragement;
  final String suggestion;
  final String? verse;
  final String? verseReference;

  const ReflectionResult({
    required this.narrative,
    required this.encouragement,
    required this.suggestion,
    this.verse,
    this.verseReference,
  });

  String toJsonString() => jsonEncode({
    'narrative': narrative,
    'encouragement': encouragement,
    'suggestion': suggestion,
    'verse': verse,
    'verseReference': verseReference,
  });

  factory ReflectionResult.fromJsonString(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return ReflectionResult(
      narrative: m['narrative'] ?? '',
      encouragement: m['encouragement'] ?? '',
      suggestion: m['suggestion'] ?? '',
      verse: m['verse'],
      verseReference: m['verseReference'],
    );
  }

  bool get isEmpty => narrative.isEmpty && encouragement.isEmpty;
}

/// Historical context for the reflection engine.
class ReflectionContext {
  final int streak;
  final int weekDaysFilled;
  final double weeklyAvgCompletion;
  final Map<String, double> disciplineRates;
  final Map<String, double> monthRates;
  final String? bestDiscipline;
  final String? weakDiscipline;
  final int totalBibleChaptersThisWeek;
  final int totalEvangelismContactsThisWeek;
  final int totalPrayerMinutesThisWeek;
  final TimeOfDay timeOfDay;

  const ReflectionContext({
    this.streak = 0,
    this.weekDaysFilled = 0,
    this.weeklyAvgCompletion = 0,
    this.disciplineRates = const {},
    this.monthRates = const {},
    this.bestDiscipline,
    this.weakDiscipline,
    this.totalBibleChaptersThisWeek = 0,
    this.totalEvangelismContactsThisWeek = 0,
    this.totalPrayerMinutesThisWeek = 0,
    this.timeOfDay = const TimeOfDay(hour: 12, minute: 0),
  });
}

// ═══════════════════════════════════════════════════════════
//  PROVIDER INTERFACE
// ═══════════════════════════════════════════════════════════

/// Abstract provider — swap implementations without UI changes.
abstract class ReflectionProvider {
  Future<ReflectionResult> generate(
      DailyLog log, ReflectionContext ctx, String locale);
}

// ═══════════════════════════════════════════════════════════
//  RULE-BASED PROVIDER
// ═══════════════════════════════════════════════════════════

class RuleBasedReflectionProvider implements ReflectionProvider {
  // ── Discipline checks (mirrors ReportService._disciplineChecks) ──
  static const _disciplineNames = [
    'Bible', 'Literature', 'DDEG', 'Prayer', 'Prayer (others)',
    'Evangelism', 'Fasting', 'Giving', 'Church', 'Discipleship', 'Proclamation',
  ];

  static List<bool> _checks(DailyLog l) => [
    l.bibleReference.isNotEmpty || l.bibleChapters.isNotEmpty ||
        l.bibleSessions.any((s) => s.isNotEmpty),
    l.literature.any((e) => e.title.isNotEmpty),
    l.ddegScripture.isNotEmpty || l.ddegNotes.isNotEmpty,
    l.prayerAloneDuration.isNotEmpty,
    l.prayerOthersDuration.isNotEmpty,
    l.evangelismContacts.isNotEmpty,
    l.fastingType.isNotEmpty || l.fastingDuration.isNotEmpty,
    l.givingType.isNotEmpty,
    l.churchType.isNotEmpty,
    l.discipleshipWho.isNotEmpty,
    l.proclamationCount.isNotEmpty,
  ];

  /// Parse duration strings like "45m", "1h 30m", "30 minutes".
  static int _parseMinutes(String s) {
    if (s.isEmpty || s == '\u2713') return 0;
    final hm = RegExp(r'(\d+)\s*h\s*(\d+)\s*m');
    final hmMatch = hm.firstMatch(s);
    if (hmMatch != null) {
      return int.parse(hmMatch.group(1)!) * 60 + int.parse(hmMatch.group(2)!);
    }
    final hOnly = RegExp(r'(\d+)\s*h');
    final hMatch = hOnly.firstMatch(s);
    if (hMatch != null) return int.parse(hMatch.group(1)!) * 60;
    final mOnly = RegExp(r'(\d+)\s*m');
    final mMatch = mOnly.firstMatch(s);
    if (mMatch != null) return int.parse(mMatch.group(1)!);
    final n = int.tryParse(s.trim());
    if (n != null) return n;
    return 0;
  }

  @override
  Future<ReflectionResult> generate(
      DailyLog log, ReflectionContext ctx, String locale) async {
    final checks = _checks(log);
    final filled = checks.where((c) => c).length;
    final isMorning = ctx.timeOfDay.hour < 12;
    final isEvening = ctx.timeOfDay.hour >= 18;
    final seed = log.dateKey.hashCode;
    final rng = Random(seed);

    final narrative = _buildNarrative(log, ctx, checks, filled, isMorning, isEvening, rng, locale);
    final encouragement = _buildEncouragement(log, ctx, checks, filled, rng, locale);
    final suggestion = _buildSuggestion(log, ctx, checks, filled, isMorning, isEvening, locale);
    final verseResult = _pickVerse(log, ctx, checks, filled, isMorning, isEvening, log.dateKey, locale);

    return ReflectionResult(
      narrative: narrative,
      encouragement: encouragement,
      suggestion: suggestion,
      verse: verseResult?.$1,
      verseReference: verseResult?.$2,
    );
  }

  // ── NARRATIVE ─────────────────────────────────────────────

  String _buildNarrative(DailyLog log, ReflectionContext ctx,
      List<bool> checks, int filled, bool isMorning, bool isEvening,
      Random rng, String locale) {
    final isFr = locale.startsWith('fr');

    // Pick main narrative based on priority
    String main;
    if (ctx.streak >= 30) {
      main = _pick(rng, isFr ? [
        'Jour ${ctx.streak} de fidélité ininterrompue — vous bâtissez quelque chose d\'éternel.',
        '${ctx.streak} jours sans interruption. Votre persévérance honore Dieu.',
        'Quelle constance ! ${ctx.streak} jours de marche fidèle avec Dieu.',
      ] : [
        'Day ${ctx.streak} of unbroken faithfulness — you are building something eternal.',
        '${ctx.streak} days without interruption. Your perseverance honors God.',
        'What consistency! ${ctx.streak} days of faithful walk with God.',
      ]);
    } else if (ctx.streak >= 7) {
      main = _pick(rng, isFr ? [
        'Une semaine complète de régularité ! ${ctx.streak} jours et ça continue.',
        '${ctx.streak} jours d\'affilée — votre discipline porte du fruit.',
        'Série de ${ctx.streak} jours ! La constance est le secret de la croissance.',
      ] : [
        'A full week of consistency! ${ctx.streak} days and counting.',
        '${ctx.streak} days in a row — your discipline is bearing fruit.',
        '${ctx.streak}-day streak! Consistency is the secret to growth.',
      ]);
    } else if (ctx.streak <= 1 && ctx.weekDaysFilled > 0 && filled > 0) {
      main = _pick(rng, isFr ? [
        'Bon retour. Chaque nouveau jour est un nouveau départ avec Dieu.',
        'Vous êtes de retour ! La grâce de Dieu est nouvelle chaque matin.',
        'Un nouveau commencement aujourd\'hui. Le passé est derrière, avancez.',
      ] : [
        'Welcome back. Every new day is a fresh start with God.',
        'You\'re back! God\'s grace is new every morning.',
        'A fresh beginning today. The past is behind — press forward.',
      ]);
    } else if (filled >= 9) {
      main = _pick(rng, isFr ? [
        'Une journée extraordinaire — $filled disciplines couvertes. Vous marchez dans la plénitude.',
        '$filled disciplines aujourd\'hui ! Votre autel brûle intensément.',
        'Quel engagement ! $filled disciplines montrent un cœur entièrement dévoué.',
      ] : [
        'An extraordinary day — $filled disciplines covered. You\'re walking in fullness.',
        '$filled disciplines today! Your altar is burning brightly.',
        'What commitment! $filled disciplines show a heart fully devoted.',
      ]);
    } else if (filled >= 6) {
      main = _pick(rng, isFr ? [
        'Bonne journée avec $filled disciplines. Votre régularité grandit.',
        '$filled disciplines — un solide fondement pour la journée.',
        'Bon effort avec $filled disciplines. Vous construisez de bonnes habitudes.',
      ] : [
        'Solid day with $filled disciplines. Your consistency is growing.',
        '$filled disciplines — a strong foundation for the day.',
        'Good effort with $filled disciplines. You\'re building solid habits.',
      ]);
    } else if (filled >= 3) {
      main = _pick(rng, isFr ? [
        'Vous avez bien commencé avec $filled disciplines. Il reste du temps pour en ajouter.',
        '$filled disciplines jusqu\'ici. Chaque pas compte dans votre marche.',
        'Un début prometteur avec $filled disciplines. Continuez sur cette lancée.',
      ] : [
        'You\'ve started well with $filled disciplines. There\'s still time to add more.',
        '$filled disciplines so far. Every step counts in your walk.',
        'A promising start with $filled disciplines. Keep the momentum going.',
      ]);
    } else if (filled >= 1) {
      main = _pick(rng, isFr ? [
        'Chaque pas compte. Vous en avez fait $filled aujourd\'hui — continuez.',
        'Un pas est un pas. $filled discipline enregistrée — la graine est plantée.',
        'Vous avez commencé. C\'est ce qui compte. Ajoutez-en une autre quand vous pouvez.',
      ] : [
        'Every step matters. You\'ve taken $filled today — keep going.',
        'A step is a step. $filled discipline logged — the seed is planted.',
        'You\'ve started. That\'s what matters. Add another when you can.',
      ]);
    } else if (isMorning) {
      main = isFr
          ? 'Bonjour ! Une page blanche attend votre fidélité aujourd\'hui.'
          : 'Good morning! A blank page awaits your faithfulness today.';
    } else if (isEvening) {
      main = isFr
          ? 'La journée n\'est pas finie. Même une seule discipline est une graine plantée.'
          : 'The day isn\'t over yet. Even one discipline logged is a seed planted.';
    } else {
      main = isFr
          ? 'Ouvrez votre cœur aux disciplines d\'aujourd\'hui. Commencez par une.'
          : 'Open your heart to today\'s disciplines. Start with one.';
    }

    // Modifiers
    final weekAvgFilled = ctx.weeklyAvgCompletion * 11;
    if (filled > 0 && filled > weekAvgFilled + 1) {
      main += isFr
          ? ' C\'est au-dessus de votre moyenne — vous progressez.'
          : ' That\'s above your weekly average — you\'re pushing higher.';
    }

    // First-time-this-week detection
    for (int i = 0; i < 11; i++) {
      if (checks[i] && (ctx.disciplineRates[_disciplineNames[i]] ?? 0) == 0) {
        main += isFr
            ? ' Première fois cette semaine pour ${_disciplineNames[i]} — bravo !'
            : ' First time this week for ${_disciplineNames[i]} — well done!';
        break; // Only mention one
      }
    }

    if (filled == 11) {
      main += isFr
          ? ' Une journée parfaite. Chaque discipline touchée. L\'autel brûle pleinement.'
          : ' A perfect day. Every discipline touched. The altar is fully ablaze.';
    }

    return main;
  }

  // ── ENCOURAGEMENT ─────────────────────────────────────────

  String _buildEncouragement(DailyLog log, ReflectionContext ctx,
      List<bool> checks, int filled, Random rng, String locale) {
    final isFr = locale.startsWith('fr');
    final signals = <(int priority, String text)>[];

    // Bible content
    final bibleRef = log.combinedBibleReference(locale);
    if (bibleRef.isNotEmpty) {
      signals.add((1, isFr
          ? 'Lecture de $bibleRef aujourd\'hui — la Parole est un terrain fertile pour la croissance.'
          : 'Reading $bibleRef today — the Word is rich ground for growth.'));
    }
    if (log.totalBibleChapters >= 5) {
      signals.add((2, isFr
          ? '${log.totalBibleChapters} chapitres aujourd\'hui — vous dévorez la Parole !'
          : '${log.totalBibleChapters} chapters today — you\'re devouring the Word!'));
    }

    // DDEG depth
    if (log.ddegNotes.length > 50) {
      signals.add((3, isFr
          ? 'Vos notes RDQD montrent une réflexion profonde. Dieu parle à ceux qui écoutent.'
          : 'Your DDEG notes show deep reflection. God speaks to those who listen.'));
    }

    // Prayer duration
    final prayerMin = _parseMinutes(log.prayerAloneDuration) +
        _parseMinutes(log.prayerOthersDuration);
    if (prayerMin >= 30) {
      final avgPrayer = ctx.totalPrayerMinutesThisWeek ~/
          max(1, ctx.weekDaysFilled);
      final comparison = prayerMin > avgPrayer
          ? (isFr ? 'au-dessus de votre moyenne' : 'above your average')
          : (isFr ? 'un investissement constant' : 'a consistent investment');
      signals.add((4, isFr
          ? '$prayerMin minutes en prière — $comparison.'
          : '$prayerMin minutes in prayer — $comparison.'));
    }

    // Evangelism contacts
    final contacts = int.tryParse(log.evangelismContacts) ?? 0;
    if (contacts >= 2) {
      signals.add((5, isFr
          ? '$contacts âmes atteintes aujourd\'hui. Le champ de la moisson répond.'
          : '$contacts souls reached today. The harvest field is responding.'));
    }

    // Fasting
    if (log.fastingType.isNotEmpty && log.fastingType != '\u2713') {
      signals.add((6, isFr
          ? 'Jeûne aujourd\'hui — renoncer à la chair pour nourrir l\'esprit.'
          : 'Fasting today — denying the flesh to feed the spirit.'));
    }

    // Literature
    final litTitles = log.literature
        .where((l) => l.title.isNotEmpty && l.title != '\u2713')
        .map((l) => l.title)
        .toList();
    if (litTitles.isNotEmpty) {
      final title = litTitles.first;
      signals.add((7, isFr
          ? 'Lecture de « $title » — nourrir l\'esprit aux côtés de l\'âme.'
          : 'Reading \'$title\' — feeding your mind alongside your spirit.'));
    }

    // Discipleship
    if (log.discipleshipWho.isNotEmpty && log.discipleshipWho != '\u2713') {
      signals.add((8, isFr
          ? 'Investir dans ${log.discipleshipWho} — la multiplication est le cœur de la CMFI.'
          : 'Pouring into ${log.discipleshipWho} — multiplication is the heart of CMFI.'));
    }

    // Proclamation
    final procCount = int.tryParse(log.proclamationCount) ?? 0;
    if (procCount >= 3) {
      signals.add((9, isFr
          ? '$procCount proclamations aujourd\'hui — déclarer les promesses de Dieu avec audace.'
          : '$procCount proclamations today — declaring God\'s promises with boldness.'));
    }

    // Total time
    final totalMin = _parseMinutes(log.prayerAloneDuration) +
        _parseMinutes(log.prayerOthersDuration) +
        _parseMinutes(log.ddegTime) +
        _parseMinutes(log.discipleshipDuration) +
        _parseMinutes(log.proclamationDuration) +
        _parseMinutes(log.bibleDuration) +
        _parseMinutes(log.literatureDuration);
    if (totalMin >= 60) {
      final hours = totalMin ~/ 60;
      final mins = totalMin % 60;
      final timeStr = hours > 0 && mins > 0 ? '${hours}h${mins}m'
          : hours > 0 ? '${hours}h' : '${mins}m';
      signals.add((10, isFr
          ? '$timeStr de temps consacré aujourd\'hui. C\'est de la dévotion.'
          : '$timeStr of consecrated time today. That\'s devotion.'));
    }

    if (signals.isEmpty) {
      return isFr
          ? 'Chaque discipline que vous touchez, même brièvement, est une graine plantée dans la bonne terre.'
          : 'Every discipline you touch, however briefly, is a seed planted in good soil.';
    }

    // Sort by priority (lower = higher priority)
    signals.sort((a, b) => a.$1.compareTo(b.$1));

    if (signals.length >= 2) {
      return '${signals[0].$2} ${signals[1].$2}';
    }
    return signals[0].$2;
  }

  // ── SUGGESTION ────────────────────────────────────────────

  String _buildSuggestion(DailyLog log, ReflectionContext ctx,
      List<bool> checks, int filled, bool isMorning, bool isEvening,
      String locale) {
    final isFr = locale.startsWith('fr');

    // Find missing disciplines
    final missing = <String>[];
    for (int i = 0; i < 11; i++) {
      if (!checks[i]) missing.add(_disciplineNames[i]);
    }

    // Priority 1: Weakest monthly discipline is missing today
    if (ctx.weakDiscipline != null && missing.contains(ctx.weakDiscipline)) {
      final d = ctx.weakDiscipline!;
      return isFr
          ? 'Votre $d a été calme dernièrement — même un petit pas aujourd\'hui créerait un élan.'
          : 'Your $d has been quiet lately — even a small step today would build momentum.';
    }

    // Priority 2: A discipline done 0 times this week and missing today
    for (final m in missing) {
      if ((ctx.disciplineRates[m] ?? 0) == 0) {
        return isFr
            ? 'Vous n\'avez pas touché $m cette semaine. Aujourd\'hui pourrait être le jour.'
            : 'You haven\'t touched $m this week. Today could be the day.';
      }
    }

    // Priority 3: Filled < 6 and before evening
    if (filled < 6 && !isEvening && missing.isNotEmpty) {
      return isFr
          ? 'Il vous reste du temps — essayez d\'ajouter ${missing.first} avant la fin de la journée.'
          : 'You still have time — try adding ${missing.first} before the day ends.';
    }

    // Priority 4: Almost perfect
    if (filled >= 9 && filled < 11) {
      final left = missing.length == 1 ? missing.first : '${missing.length} disciplines';
      return isFr
          ? 'Vous êtes si proche d\'une journée parfaite ! Il ne reste que $left.'
          : 'You\'re so close to a perfect day! Just $left left.';
    }

    // Priority 5: All 11 filled
    if (filled == 11) {
      final weak = ctx.weakDiscipline ?? 'prayer';
      return isFr
          ? 'Toutes les disciplines couvertes ! Demain, essayez d\'approfondir $weak.'
          : 'All disciplines covered! Tomorrow, try going deeper in $weak.';
    }

    // Priority 6: Morning, nothing yet
    if (isMorning && filled == 0) {
      final strong = ctx.bestDiscipline ?? 'Bible';
      return isFr
          ? 'Commencez par $strong — construisez l\'élan à partir de votre force.'
          : 'Start with $strong — build momentum from strength.';
    }

    // Default
    return isFr
        ? 'Choisissez une discipline et consacrez-y quelques minutes. Chaque petit pas compte.'
        : 'Pick one discipline and give it a few minutes. Every small step counts.';
  }

  // ── VERSE SELECTION ───────────────────────────────────────

  (String, String)? _pickVerse(DailyLog log, ReflectionContext ctx,
      List<bool> checks, int filled, bool isMorning, bool isEvening,
      String dateKey, String locale) {
    // Determine the best tag based on today's strongest signal
    String tag;

    // Map discipline indices to verse tags
    const indexToTag = [
      'bible', 'literature', 'ddeg', 'prayer', 'prayer',
      'evangelism', 'fasting', 'giving', 'church', 'discipleship', 'proclamation',
    ];

    // Find the discipline with the richest content today
    if (log.ddegNotes.length > 50) {
      tag = 'ddeg';
    } else if (log.totalBibleChapters >= 3) {
      tag = 'bible';
    } else if ((int.tryParse(log.evangelismContacts) ?? 0) >= 2) {
      tag = 'evangelism';
    } else if (_parseMinutes(log.prayerAloneDuration) >= 20) {
      tag = 'prayer';
    } else if (log.fastingType.isNotEmpty && log.fastingType != '\u2713') {
      tag = 'fasting';
    } else if (log.discipleshipWho.isNotEmpty && log.discipleshipWho != '\u2713') {
      tag = 'discipleship';
    } else if (ctx.streak >= 7) {
      tag = 'streak';
    } else if (ctx.streak <= 1 && filled > 0 && ctx.weekDaysFilled > 0) {
      tag = 'comeback';
    } else if (filled >= 7) {
      tag = 'balanced';
    } else if (filled > 0) {
      // Pick tag of the first completed discipline
      for (int i = 0; i < 11; i++) {
        if (checks[i]) {
          tag = indexToTag[i];
          break;
        }
      }
      tag = isMorning ? 'morning' : isEvening ? 'evening' : 'bible';
    } else {
      tag = isMorning ? 'morning' : isEvening ? 'evening' : 'bible';
    }

    final verse = ScriptureLibrary.pickFromTag(tag, dateKey);
    if (verse == null) return null;
    return (verse.text(locale), verse.reference);
  }

  // ── HELPERS ───────────────────────────────────────────────

  String _pick(Random rng, List<String> options) =>
      options[rng.nextInt(options.length)];
}

// ═══════════════════════════════════════════════════════════
//  SERVICE SINGLETON
// ═══════════════════════════════════════════════════════════

class ReflectionService {
  static final ReflectionService instance = ReflectionService._();
  ReflectionService._();

  ReflectionProvider _provider = RuleBasedReflectionProvider();

  /// Swap the provider (for future AI integration).
  void setProvider(ReflectionProvider provider) => _provider = provider;

  /// Generate a reflection for the given log and context.
  Future<ReflectionResult> generate(
      DailyLog log, ReflectionContext ctx, String locale) {
    return _provider.generate(log, ctx, locale);
  }
}
```

- [ ] **Step 2: Verify file compiles**

Run: `cd "c:/Users/goodn/Developement/Flutter projects/daily_account" && flutter analyze lib/services/reflection_service.dart`

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/reflection_service.dart
git commit -m "feat: add ReflectionService with rule-based provider and provider interface"
```

---

### Task 3: Localization — Reflection ARB Keys

**Files:**
- Modify: `lib/l10n/app_en.arb` (append new keys before final `}`)
- Modify: `lib/l10n/app_fr.arb` (append new keys before final `}`)

**Interfaces:**
- Consumes: nothing
- Produces: ARB keys used by the log screen reflection card UI: `reflectTitle`, `reflectCollapsed`, `reflectNarrativeLabel`, `reflectEncouragementLabel`, `reflectSuggestionLabel`, `reflectVerseLabel`

Note: The rule engine templates are hardcoded in the provider (not in ARB) for this version because they use complex string interpolation with runtime values that ARB placeholder syntax handles poorly. The UI chrome (section labels, card title) is in ARB.

- [ ] **Step 1: Add EN ARB keys**

Add the following keys before the final `}` in `lib/l10n/app_en.arb`:

```json
  "reflectTitle": "Daily Reflection",
  "reflectTapToExpand": "Tap to read more",
  "reflectNarrativeLabel": "YOUR JOURNEY",
  "reflectEncouragementLabel": "ENCOURAGEMENT",
  "reflectSuggestionLabel": "NEXT STEP",
  "reflectVerseLabel": "SCRIPTURE"
```

- [ ] **Step 2: Add FR ARB keys**

Add the following keys before the final `}` in `lib/l10n/app_fr.arb`:

```json
  "reflectTitle": "Réflexion Quotidienne",
  "reflectTapToExpand": "Touchez pour lire la suite",
  "reflectNarrativeLabel": "VOTRE PARCOURS",
  "reflectEncouragementLabel": "ENCOURAGEMENT",
  "reflectSuggestionLabel": "PROCHAINE ÉTAPE",
  "reflectVerseLabel": "ÉCRITURE"
```

- [ ] **Step 3: Regenerate l10n**

Run: `cd "c:/Users/goodn/Developement/Flutter projects/daily_account" && flutter pub get`

Verify: `grep "reflectTitle" lib/l10n/generated/app_localizations.dart` shows the new getter.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_fr.arb lib/l10n/generated/
git commit -m "feat: add reflection card localization keys (EN + FR)"
```

---

### Task 4: Log Screen — Collapsible Reflection Card with Live Updates

**Files:**
- Modify: `lib/screens/log_screen.dart`

**Interfaces:**
- Consumes: `ReflectionService.instance.generate(log, ctx, locale)` from Task 2, `ReflectionResult` from Task 2, `ReflectionContext` from Task 2, `ReportService.instance.computeStreak()`, `ReportService.instance.computeWeekStats()`, `ReportService.instance.computeTrend()`, ARB keys from Task 3
- Produces: Visual reflection card in the log screen, debounced regeneration on field changes

- [ ] **Step 1: Add imports and state fields**

In `lib/screens/log_screen.dart`, add import at the top (after existing imports):

```dart
import '../services/reflection_service.dart';
import '../services/report_service.dart';
```

Add state fields in `_LogScreenState` (after `Timer? _persistDebounce;`):

```dart
  // Reflection
  ReflectionResult? _reflection;
  bool _reflectionExpanded = false;
  Timer? _reflectionDebounce;
```

- [ ] **Step 2: Add reflection generation methods**

Add these methods in `_LogScreenState` (after `_persist()` method):

```dart
  /// Build the ReflectionContext from current data.
  Future<ReflectionContext> _buildReflectionContext() async {
    final rs = ReportService.instance;
    final streak = await rs.computeStreak();
    final stats = await rs.computeWeekStats();
    final trend = await rs.computeTrend();
    return ReflectionContext(
      streak: streak,
      weekDaysFilled: stats.daysLogged,
      weeklyAvgCompletion: trend.hasData ? trend.currentConsistency : 0,
      disciplineRates: trend.disciplineRates,
      monthRates: trend.hasData
          ? trend.disciplineRates // approximate — uses week data
          : const {},
      bestDiscipline: trend.bestDiscipline,
      weakDiscipline: trend.weakDiscipline,
      totalBibleChaptersThisWeek: stats.totalBibleChapters,
      totalEvangelismContactsThisWeek: stats.totalEvangelismContacts,
      totalPrayerMinutesThisWeek: stats.totalPrayerMinutes,
      timeOfDay: TimeOfDay.now(),
    );
  }

  /// Generate (or regenerate) the reflection. Debounced — called after _persist.
  void _scheduleReflectionUpdate() {
    _reflectionDebounce?.cancel();
    _reflectionDebounce = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final locale = Localizations.localeOf(context).languageCode;
      final ctx = await _buildReflectionContext();
      final result = await ReflectionService.instance.generate(_log, ctx, locale);
      if (mounted) {
        setState(() => _reflection = result);
        // Cache in log
        _log.aiReflection = result.toJsonString();
        StorageService.instance.saveLog(_log);
      }
    });
  }
```

- [ ] **Step 3: Hook reflection generation into _load and _persist**

In the `_load()` method, after `if (mounted) setState(() => _loading = false);`, add:

```dart
    // Load cached reflection or generate fresh
    if (_log.aiReflection.isNotEmpty) {
      try {
        _reflection = ReflectionResult.fromJsonString(_log.aiReflection);
      } catch (_) {
        _scheduleReflectionUpdate();
      }
    }
    // Always regenerate for today (live updates); use cache for past days
    if (_key == DateFormat('yyyy-MM-dd').format(DateTime.now())) {
      _scheduleReflectionUpdate();
    }
```

In the `_persist()` method, after `widget.onChanged();` (inside the Timer callback), add:

```dart
      _scheduleReflectionUpdate();
```

In `dispose()`, add cleanup:

```dart
    _reflectionDebounce?.cancel();
```

- [ ] **Step 4: Replace _buildReflectionCard with the new collapsible card**

Replace the entire `_buildReflectionCard` method (from `Widget _buildReflectionCard(S t) {` to its closing `}`) with:

```dart
  Widget _buildReflectionCard(S t) {
    final accent = AppTheme.accentGold(context);
    final r = _reflection;

    // Empty state — no data yet
    if (r == null || r.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.isDark(context)
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Text('\u{1F4AD}', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.reflectTitle,
                        style: AppTheme.display(16, color: accent)),
                    const SizedBox(height: 4),
                    Text(t.reflectionEmpty,
                        style: AppTheme.serif(12, color: AppTheme.mutedColor(context))),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 540.ms),
      );
    }

    // Rich reflection card
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _reflectionExpanded = !_reflectionExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.12),
                accent.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row — always visible
              Row(
                children: [
                  const Text('\u2728', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t.reflectTitle,
                        style: AppTheme.display(16, color: accent)),
                  ),
                  AnimatedRotation(
                    turns: _reflectionExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more,
                        color: AppTheme.faintColor(context), size: 20),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Collapsed: first sentence preview
              if (!_reflectionExpanded) ...[
                Text(
                  _firstSentence(r.narrative),
                  style: AppTheme.serif(13, color: AppTheme.textColor(context)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(t.reflectTapToExpand,
                    style: AppTheme.label(9, color: AppTheme.faintColor(context))),
              ],

              // Expanded: full reflection
              if (_reflectionExpanded) ...[
                // Narrative
                _reflectSection(t.reflectNarrativeLabel, r.narrative, accent),

                const SizedBox(height: 12),

                // Encouragement
                _reflectSection(t.reflectEncouragementLabel, r.encouragement, accent,
                    italic: true),

                const SizedBox(height: 12),

                // Suggestion
                _reflectSection(t.reflectSuggestionLabel, r.suggestion, accent,
                    icon: Icons.lightbulb_outline),

                // Verse
                if (r.verse != null && r.verseReference != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.reflectVerseLabel,
                            style: AppTheme.label(9, color: accent)),
                        const SizedBox(height: 6),
                        Text('"${r.verse}"',
                            style: AppTheme.serif(13,
                                color: AppTheme.textColor(context),
                                style: FontStyle.italic)),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('— ${r.verseReference}',
                              style: AppTheme.label(10, color: AppTheme.mutedColor(context))),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ).animate().fadeIn(delay: 540.ms),
    );
  }

  Widget _reflectSection(String label, String text, Color accent,
      {bool italic = false, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
            ],
            Text(label, style: AppTheme.label(9, color: accent)),
          ],
        ),
        const SizedBox(height: 4),
        Text(text,
            style: AppTheme.serif(13,
                color: AppTheme.textColor(context),
                style: italic ? FontStyle.italic : FontStyle.normal)),
      ],
    );
  }

  String _firstSentence(String text) {
    final dotIndex = text.indexOf('. ');
    if (dotIndex > 0 && dotIndex < 120) return text.substring(0, dotIndex + 1);
    if (text.length > 100) return '${text.substring(0, 100)}...';
    return text;
  }
```

- [ ] **Step 5: Clean up old reflection ARB keys (optional)**

The old keys (`reflectionGreatDay`, `reflectionGoodDay`, `reflectionStartDay`, `reflectionPrayerFocus`, `reflectionBibleFocus`, `reflectionEvangelismFocus`, `reflectionBalanced`, `reflectionStreakEncouragement`) are no longer used by the new card. They can be removed from both ARB files, or left for backward safety. Remove them to keep ARB clean.

- [ ] **Step 6: Regenerate l10n and verify compilation**

Run: `cd "c:/Users/goodn/Developement/Flutter projects/daily_account" && flutter pub get && flutter analyze`

Expected: No errors from our changes.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/log_screen.dart lib/l10n/
git commit -m "feat: intelligent collapsible reflection card with live updates"
```

---

### Task 5: Final Verification

**Files:**
- All files from Tasks 1-4

- [ ] **Step 1: Run flutter analyze**

Run: `cd "c:/Users/goodn/Developement/Flutter projects/daily_account" && flutter analyze`

Expected: No new errors or warnings from our changes.

- [ ] **Step 2: Verify all spec requirements**

Check against spec:
- [ ] Reflection updates live as disciplines are filled (debounced 2s after _persist)
- [ ] Collapsed/expanded toggle works (AnimatedContainer + AnimatedRotation)
- [ ] Past days show cached reflection (checks `_key != today` → skips regeneration)
- [ ] French locale shows French templates (locale passed to provider)
- [ ] Verse is relevant to today's activity pattern (tag selection logic)
- [ ] Streak, comeback, and time-of-day awareness work (narrative priority table)
- [ ] Provider interface exists for future AI swap (`ReflectionProvider` abstract class)

- [ ] **Step 3: Final commit (if any cleanup needed)**

```bash
git add -A
git commit -m "chore: final cleanup for intelligent reflection engine"
```
