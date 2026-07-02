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
