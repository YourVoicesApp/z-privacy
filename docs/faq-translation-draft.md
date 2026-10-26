# 118 · The FAQ in three languages — translation draft

**Draft, not final.** The owner, 27 October 2026: the English editorial review
is complete for 24 answers and **Q20 waits for paper 119**, so nothing here is
final until that answer exists. Drafting German and Arabic in parallel is his
order; publishing any of it before the English is complete is not.

**This is a translation, not a rewrite.** No answer is reworded, no feature is
added, and nothing is polished for marketing. Where the English is awkward
because a qualifier is doing work, the German and the Arabic are awkward in
the same place on purpose.

## What the meaning check is for

His three tests, which are part of the publishing gate and not proofreading:

1. **Claim limits.** «in this build» must never become permanent, and «as read
   from the source» must never become «shown at runtime».
2. **Protection limits.** «the values Z detected or you marked» must never
   become «all sensitive data».
3. **Certainty.** «may» must never become «will», and «not tested» must never
   become «supported» or «guaranteed».

Each answer below carries a **Limits to watch** line naming which of the three
it is carrying and the phrase that does the work, so the reader checking it
knows what to look for rather than reading three paragraphs for feel.

**And a thing this file cannot do.** A keyword check sees a word; it does not
see a meaning. `scripts/check_the_absolutes.py` can tell us that every
absolute in each language has been classified, and the per-language registers
below it do exactly that — but whether the German sentence *means* what the
English one means is a judgement, and for Arabic the owner is the reader.

---

## Q1 · Is it safe to paste client documents into ChatGPT?

**EN (approved).** That depends on your agreement with the service and on what is in the document, and it is a question about them rather than about us. What is certain either way is that the whole document leaves your machine: the names, the account numbers and the addresses travel with the part you actually wanted help with. The useful question is which of those values the model needs for the task you are asking about — for some tasks it does need them — and Z Privacy is built so that you decide that value by value and see the result before anything is sent.

**DE (draft).** Das hängt von Ihrer Vereinbarung mit dem Dienst ab und davon, was in dem Dokument steht — es ist eine Frage an den Dienst und nicht an uns. Sicher ist in jedem Fall: das ganze Dokument verlässt Ihren Rechner. Die Namen, die Kontonummern und die Adressen reisen mit dem Teil mit, zu dem Sie eigentlich Hilfe wollten. Die nützliche Frage ist, welche dieser Werte das Modell für die Aufgabe braucht, die Sie stellen — für manche Aufgaben braucht es sie —, und Z Privacy ist dafür gebaut, dass Sie das Wert für Wert entscheiden und das Ergebnis sehen, bevor etwas gesendet wird.

**AR (draft).** <div dir="rtl" lang="ar">

هذا يعتمد على اتّفاقك مع الخدمة وعلى ما في الوثيقة، وهو سؤالٌ عنهم لا عنّا. والمؤكَّد في الحالين أنّ الوثيقة كلَّها تغادر جهازك: الأسماءُ وأرقامُ الحسابات والعناوين تسافر مع الجزء الذي أردتَ المساعدة فيه فعلاً. والسؤالُ النافع هو أيُّ هذه القيم يحتاجه النموذج للمهمّة التي تسألُ عنها — وفي بعض المهامّ يحتاجُها — وZ Privacy مبنيٌّ لتقرّر ذلك قيمةً قيمة، ولترى النتيجة قبل أن يُرسَل شيء.

</div>

**Limits to watch — certainty.** depends on your agreement / for some tasks it does need them

## Q2 · Do AI services use my conversations or files for training? And do they keep them?

**EN (approved).** Those are two different questions and each provider answers them separately: training is whether your content is used to improve a model, retention is how long a copy is kept and who may see it. The answers differ by provider, by plan — a consumer account and an API account are often not the same — and they change over time, so the only reliable source is the provider's own current terms. Z Privacy changes neither; what it changes is what is in the text you send.

**DE (draft).** Das sind zwei verschiedene Fragen, und jeder Anbieter beantwortet sie getrennt: Beim Training geht es darum, ob Ihre Inhalte zur Verbesserung eines Modells verwendet werden, bei der Aufbewahrung darum, wie lange eine Kopie liegen bleibt und wer sie sehen darf. Die Antworten unterscheiden sich je nach Anbieter, je nach Tarif — ein Verbraucherkonto und ein API-Konto sind oft nicht dasselbe — und sie ändern sich mit der Zeit; die einzig verlässliche Quelle sind daher die aktuellen Bedingungen des Anbieters selbst. Z Privacy ändert an beidem nichts; es ändert, was in dem Text steht, den Sie senden.

**AR (draft).** <div dir="rtl" lang="ar">

هذان سؤالان مختلفان، وكلُّ مزوّدٍ يجيب عنهما على حدة: التدريبُ هو هل تُستعمل محتوياتُك في تحسين نموذج، والاحتفاظُ هو كم تبقى النسخةُ ومن يجوز له النظرُ فيها. والأجوبةُ تختلف بالمزوّد، وبالاشتراك — فحسابُ المستهلك وحسابُ الواجهة البرمجيّة ليسا الشيءَ نفسَه غالباً — وتتغيّر مع الزمن؛ فالمصدرُ الموثوقُ الوحيد هو شروطُ المزوّد نفسِه السارية. وZ Privacy لا يغيّر واحداً منهما؛ ما يغيّره هو ما في النصّ الذي ترسله.

</div>

**Limits to watch — certainty.** differ by provider, by plan … and they change over time

## Q3 · How can I use AI on documents with personal data without sending the names?

**EN (approved).** You replace each value with a token before the text leaves, and put the real values back when the answer comes home. In Z Privacy that is the whole path — Import, Scan, Review, Protect, Choose who answers, AI, Restore — and before anything is sent you are shown exactly what will leave. The mapping from token back to value lives in your vault and nowhere else, so only your machine can reverse it. That is not the same as being unlinkable: what is left of a document can still point at a person through its content alone (see «anonymisation or pseudonymisation» and «does Z make me anonymous»).

**DE (draft).** Sie ersetzen jeden Wert durch ein Kennzeichen, bevor der Text das Gerät verlässt, und setzen die echten Werte wieder ein, wenn die Antwort zurückkommt. In Z Privacy ist das der ganze Weg — Import, Prüfung, Durchsicht, Schutz, Wer antwortet, KI, Wiederherstellen — und bevor etwas gesendet wird, sehen Sie genau, was Ihr Gerät verlassen würde. Die Zuordnung vom Kennzeichen zurück zum Wert liegt in Ihrem Tresor und nirgendwo sonst, also kann nur Ihr Rechner sie umkehren. Das ist nicht dasselbe wie Unverknüpfbarkeit: Was von einem Dokument übrig bleibt, kann allein durch seinen Inhalt noch auf eine Person zeigen (siehe «Anonymisierung oder Pseudonymisierung» und «macht Z mich gegenüber dem Anbieter anonym»).

**AR (draft).** <div dir="rtl" lang="ar">

تستبدل بكلّ قيمةٍ رمزاً قبل أن يغادر النصُّ، وتُعيد القيم الحقيقيّة حين يعود الجواب. وهذا في Z Privacy هو الطريق كلُّه — إدخال، فحص، مراجعة، حماية، اختيار من يُجيب، الذكاء الاصطناعيّ، استعادة — وقبل أن يُرسَل شيءٌ تُعرَض عليك بالضبط ما سيغادر جهازك. والرابطُ من الرمز إلى القيمة يسكن في خزنتك ولا مكان سواها، فلا يستطيع عكسَه إلّا جهازُك. وليس هذا هو عدمَ القابليّة للربط: فما يبقى من الوثيقة قد يدلّ على شخصٍ بمحتواه وحده (انظر «التعميةُ أم الترميز» و«هل يجعلني Z مجهولاً عند المزوّد»).

</div>

**Limits to watch — protection limits.** that is not the same as being unlinkable

## Q4 · What should I consider under GDPR before sending client data to AI?

**EN (approved).** Three separate things, and none of them substitutes for another. **Data minimisation** (Art. 5(1)(c)) asks whether the model needs a given value at all — that is the question a tool like Z Privacy helps with. **Your legal obligations** — a lawful basis, your records, your processor agreements, transfers — are yours, and no tool changes them. And **what Z Privacy does** is replace values in the text you send, which is pseudonymisation: under the GDPR that does not make data anonymous by itself, and the text may still be personal data depending on what is left in it (Art. 4(5), Recital 26). This is information, not legal advice; your controller or DPO decides.

**DE (draft).** Drei getrennte Dinge, und keines ersetzt ein anderes. **Datenminimierung** (Art. 5 Abs. 1 lit. c) fragt, ob das Modell einen bestimmten Wert überhaupt braucht — das ist die Frage, bei der ein Werkzeug wie Z Privacy hilft. **Ihre rechtlichen Pflichten** — eine Rechtsgrundlage, Ihre Verzeichnisse, Ihre Auftragsverarbeitungsverträge, Übermittlungen — sind Ihre, und kein Werkzeug ändert sie. Und **was Z Privacy tut**, ist, Werte in dem Text zu ersetzen, den Sie senden: das ist Pseudonymisierung, und nach der DSGVO macht sie Daten für sich genommen nicht anonym; der Text kann weiterhin personenbezogen sein, je nachdem, was in ihm stehen bleibt (Art. 4 Nr. 5, Erwägungsgrund 26). Dies ist eine Information, keine Rechtsberatung; es entscheidet Ihr Verantwortlicher oder Ihr Datenschutzbeauftragter.

**AR (draft).** <div dir="rtl" lang="ar">

ثلاثةُ أشياءَ منفصلة، ولا يُغني واحدٌ منها عن الآخر. **تقليلُ البيانات** (المادّة ٥/١/ج) يسأل: هل يحتاج النموذجُ هذه القيمةَ أصلاً؟ وهذا هو السؤالُ الذي تُعين فيه أداةٌ مثل Z Privacy. و**التزاماتُك القانونيّة** — أساسٌ قانونيّ، وسجلّاتُك، وعقودُ المعالجة لديك، والنقلُ إلى الخارج — هي التزاماتُك، ولا تغيّرها أداة. و**ما يفعله Z Privacy** هو استبدالُ قيمٍ في النصّ الذي ترسله، وهذا ترميزٌ لا تعمية: فهو بنفسه لا يجعل البياناتِ مجهولةً بحكم اللائحة، وقد يبقى النصُّ بياناتٍ شخصيّةً تبعاً لما بقي فيه (المادّة ٤/٥ والحيثيّة ٢٦). وهذه معلومةٌ لا استشارةٌ قانونيّة؛ والقرارُ لمسؤول المعالجة عندك أو لمسؤول حماية البيانات.

</div>

**Limits to watch — certainty.** does not make data anonymous by itself … may still be personal data

## Q5 · What is the difference between anonymisation and pseudonymisation?

**EN (approved).** Pseudonymisation replaces identifying values with stand-ins while a mapping that can reverse it still exists somewhere; the data can remain personal data (Art. 4(5)). Data counts as anonymous only where the person can no longer be identified by means reasonably likely to be used — a standard that takes account of what others might reasonably do, and not only of what you would do — and then the GDPR no longer applies to it (Recital 26). Z Privacy does the first: the mapping is your vault, on your machine. And a text with every name removed can still be about one identifiable person — a single-patient clinic letter is the standard example.

**DE (draft).** Pseudonymisierung ersetzt identifizierende Werte durch Platzhalter, während eine Zuordnung, die sich umkehren lässt, irgendwo weiter besteht; die Daten können personenbezogen bleiben (Art. 4 Nr. 5). Als anonym gelten Daten nur dort, wo die Person mit Mitteln, die nach allgemeinem Ermessen wahrscheinlich genutzt werden, nicht mehr identifiziert werden kann — ein Maßstab, der berücksichtigt, was andere vernünftigerweise tun könnten, und nicht nur, was Sie selbst tun würden —, und dann gilt die DSGVO für sie nicht mehr (Erwägungsgrund 26). Z Privacy tut das Erste: Die Zuordnung ist Ihr Tresor, auf Ihrem Rechner. Und ein Text, aus dem jeder Name entfernt wurde, kann immer noch von einer identifizierbaren Person handeln — ein Arztbrief über eine einzige Patientin ist das übliche Beispiel.

**AR (draft).** <div dir="rtl" lang="ar">

الترميزُ يستبدل بالقيم المعرِّفة بدائلَ مع بقاء رابطٍ في مكانٍ ما يمكن أن يعكسه؛ وقد تبقى البياناتُ شخصيّة (المادّة ٤/٥). ولا تُعدّ البياناتُ مجهولةً إلّا حيث لم يعد يمكن التعرّفُ على الشخص بوسائلَ يُرجَّح في المعتاد أن تُستعمل — وهو معيارٌ يأخذ في الحسبان ما قد يفعله غيرُك على نحوٍ معقول، لا ما تفعله أنت وحدك — وعندها لا تسري عليها اللائحة (الحيثيّة ٢٦). وZ Privacy يفعل الأوّل: الرابطُ هو خزنتُك، على جهازك. ونصٌّ أُزيل منه كلُّ اسمٍ قد يظلّ عن شخصٍ يمكن التعرّفُ عليه — ورسالةُ عيادةٍ عن مريضةٍ واحدة هي المثالُ المعتاد.

</div>

**Limits to watch — certainty.** can remain personal data / means reasonably likely to be used

## Q6 · How can an accountant use AI without exposing clients' financial data?

**EN (approved).** Work on the document inside Z Privacy: the scan and your own taught values mark what they find, you add anything they did not, and the question goes out with tokens in place of those values. What is replaced is what Z Privacy detected or you marked; everything else stays in the text exactly as you approved it, which is why the review step exists and why it is shown to you before anything is sent. Your professional obligations are not changed by this: Z Privacy reduces what you send, it does not make the sending permissible.

**DE (draft).** Arbeiten Sie an dem Dokument in Z Privacy: Die Prüfung und Ihre eigenen eingelernten Werte markieren, was sie finden, Sie ergänzen, was sie nicht gefunden haben, und die Frage geht mit Kennzeichen an der Stelle dieser Werte hinaus. Ersetzt wird, was Z Privacy erkannt hat oder was Sie markiert haben; alles andere bleibt genau so im Text, wie Sie ihn freigegeben haben — deshalb gibt es den Schritt der Durchsicht, und deshalb wird er Ihnen gezeigt, bevor etwas gesendet wird. Ihre Berufspflichten ändert das nicht: Z Privacy verringert, was Sie senden; es macht das Senden nicht zulässig.

**AR (draft).** <div dir="rtl" lang="ar">

اعمل على الوثيقة داخل Z Privacy: الفحصُ والقيمُ التي علّمتَها تُعلِّم ما تجده، وتضيف أنت ما فاتها، ويخرج السؤالُ وفي مواضع تلك القيم رموز. والمستبدَلُ هو ما كشفه Z Privacy أو ما علَّمتَه أنت؛ وكلُّ ما عدا ذلك يبقى في النصّ كما أقررتَه تماماً — ولهذا توجد خطوةُ المراجعة، ولهذا تُعرَض عليك قبل أن يُرسَل شيء. ولا تتغيّر بهذا التزاماتُك المهنيّة: فZ Privacy يُقلّل ما ترسله، ولا يجعل الإرسالَ جائزاً.

</div>

**Limits to watch — protection limits.** what Z Privacy detected or you marked — never «all sensitive data»

## Q7 · How can a lawyer use AI on case files confidentially?

**EN (approved).** The same path: what Z Privacy detected and what you chose to protect is replaced before anything leaves, the rest of the text goes as you approved it, and the answer is restored on your machine. Z Privacy does not decide whether your professional rules allow an external model to see a matter at all — that judgement is yours and it differs by jurisdiction. What it changes is how much identifying detail is in what you send, and it shows you the exact text before it goes.

**DE (draft).** Derselbe Weg: Was Z Privacy erkannt hat und was Sie zu schützen gewählt haben, wird ersetzt, bevor etwas hinausgeht, der übrige Text geht so, wie Sie ihn freigegeben haben, und die Antwort wird auf Ihrem Rechner wiederhergestellt. Z Privacy entscheidet nicht, ob Ihr Berufsrecht es überhaupt erlaubt, dass ein fremdes Modell ein Mandat sieht — diese Beurteilung ist Ihre und sie unterscheidet sich je nach Rechtsordnung. Was es ändert, ist, wie viel identifizierendes Detail in dem steckt, was Sie senden, und es zeigt Ihnen den genauen Text, bevor er geht.

**AR (draft).** <div dir="rtl" lang="ar">

الطريقُ نفسُه: ما كشفه Z Privacy وما اخترتَ أنت حمايتَه يُستبدَل قبل أن يغادر شيء، وبقيّةُ النصّ تذهب كما أقررتَها، ويُستعاد الجوابُ على جهازك. وZ Privacy لا يقرّر هل تسمح قواعدُ مهنتك أصلاً بأن يرى نموذجٌ خارجيٌّ قضيّةً — فذلك تقديرُك أنت ويختلف باختلاف الولاية القضائيّة. وما يغيّره هو مقدارُ التفصيل المعرِّف في ما ترسله، وهو يُريك النصَّ بالضبط قبل أن يذهب.

</div>

**Limits to watch — protection limits.** what Z Privacy detected and what you chose to protect

## Q8 · Can I use AI on medical or HR documents without revealing who they are about?

**EN (approved).** Mechanically yes — names, identifiers and addresses can be replaced before the text leaves. But these are the two kinds of document where the identity is most often inferable from the content itself, and no replacement fixes that. Health data is a special category under Art. 9 and HR data carries its own obligations; whether to process it with an external model at all is the controller's decision, not a tool's. If you do, pseudonymisation is a measure, not a permission.

**DE (draft).** Mechanisch ja — Namen, Kennnummern und Adressen lassen sich ersetzen, bevor der Text hinausgeht. Aber das sind die beiden Dokumentarten, bei denen sich die Identität am häufigsten aus dem Inhalt selbst erschließen lässt, und das behebt keine Ersetzung. Gesundheitsdaten sind eine besondere Kategorie nach Art. 9, und Personaldaten bringen eigene Pflichten mit; ob sie überhaupt mit einem fremden Modell verarbeitet werden, entscheidet der Verantwortliche und nicht ein Werkzeug. Wenn Sie es tun, ist Pseudonymisierung eine Maßnahme, keine Erlaubnis.

**AR (draft).** <div dir="rtl" lang="ar">

نعم من جهة الآليّة — فالأسماءُ والمعرِّفات والعناوين يمكن استبدالُها قبل أن يغادر النصّ. لكنّهما نوعا الوثائق اللذان يُستدَلّ فيهما على الهويّة من المحتوى نفسِه أكثرَ من غيرهما، ولا يُصلح ذلك أيُّ استبدال. والبياناتُ الصحّيّة فئةٌ خاصّةٌ بالمادّة ٩، ولبيانات الموظّفين التزاماتُها؛ وقرارُ معالجتها بنموذجٍ خارجيٍّ أصلاً هو لمسؤول المعالجة لا لأداة. وإن فعلتَ، فالترميزُ تدبيرٌ لا إذن.

</div>

**Limits to watch — protection limits.** the identity is often inferable from the content itself

## Q9 · What happens to my data when I upload a PDF to an AI chatbot?

**EN (approved).** The file leaves your machine and is processed on the provider's servers; what happens next — how long a copy is kept, who may look at it, whether it is used to improve a model — is set by that provider's terms and your plan, and is not visible from the file. The part worth noticing is that a PDF carries every page, including the ones you did not need help with. Z Privacy's answer is to send the text with the values replaced, rather than the file.

**DE (draft).** Die Datei verlässt Ihren Rechner und wird auf den Servern des Anbieters verarbeitet; was danach geschieht — wie lange eine Kopie bleibt, wer sie ansehen darf, ob sie zur Verbesserung eines Modells verwendet wird — regeln die Bedingungen dieses Anbieters und Ihr Tarif, und man sieht es der Datei nicht an. Bemerkenswert ist, dass ein PDF jede Seite mitnimmt, auch die, zu denen Sie keine Hilfe brauchten. Die Antwort von Z Privacy ist, den Text mit ersetzten Werten zu senden statt der Datei.

**AR (draft).** <div dir="rtl" lang="ar">

يغادر الملفُّ جهازَك ويُعالَج على خوادم المزوّد؛ وما يجري بعد ذلك — كم تبقى النسخة، ومن يجوز له النظرُ فيها، وهل تُستعمل في تحسين نموذج — تحكمه شروطُ ذلك المزوّد واشتراكُك، ولا يُرى من الملفّ. والجديرُ بالملاحظة أنّ ملفَّ PDF يحمل كلَّ صفحةٍ فيه، ومنها الصفحاتُ التي لم تكن تريد فيها مساعدة. وجوابُ Z Privacy هو أن تُرسل النصَّ وقيمُه مستبدَلة، بدل الملفّ.

</div>

**Limits to watch — certainty.** is set by that provider’s terms and your plan

## Q10 · Can I use an AI model on my own computer instead of a cloud service?

**EN (approved).** Yes. Z Privacy speaks to any server that answers an OpenAI-compatible request, including one on your own machine — llama.cpp, Ollama, LM Studio — and a local model needs no key at all. Plain `http` is accepted only for a **literal** loopback IP address, never for a name like «localhost», so a hosts file cannot be what decides that plaintext is safe. On that path Z Privacy's request to the model goes to that address and no further; it says nothing about what other programs on your computer do.

**DE (draft).** Ja. Z Privacy spricht mit jedem Server, der eine OpenAI-kompatible Anfrage beantwortet, auch mit einem auf Ihrem eigenen Rechner — llama.cpp, Ollama, LM Studio —, und ein lokales Modell braucht überhaupt keinen Schlüssel. Einfaches `http` wird nur für eine **buchstäbliche** Loopback-IP-Adresse angenommen, nie für einen Namen wie «localhost», damit nicht eine hosts-Datei darüber entscheidet, ob Klartext sicher ist. Auf diesem Weg geht die Anfrage von Z Privacy an das Modell an diese Adresse und nicht weiter; über das, was andere Programme auf Ihrem Rechner tun, sagt sie nichts.

**AR (draft).** <div dir="rtl" lang="ar">

نعم. يتحدّث Z Privacy إلى أيّ خادمٍ يجيب طلباً متوافقاً مع OpenAI، ومنها خادمٌ على جهازك أنت — llama.cpp أو Ollama أو LM Studio — والنموذجُ المحلّيّ لا يحتاج مفتاحاً أصلاً. ولا يُقبل `http` العاديّ إلّا لعنوان loopback **حرفيّ**، ولا يُقبل لاسمٍ مثل «localhost»، حتّى لا يكون ملفُّ hosts هو ما يقرّر أنّ النصّ الصريح آمن. وعلى هذا الطريق يذهب طلبُ Z Privacy إلى النموذج عند ذلك العنوان ولا يتجاوزه؛ ولا يقول شيئاً عمّا تفعله البرامجُ الأخرى على جهازك.

</div>

**Limits to watch — claim limits.** goes to that address and no further; it says nothing about other programs

## Q11 · What does Z Privacy do, in one minute?

**EN (approved).** You open a document or write a question. Z Privacy scans it with its rules, its language packs and the values you have taught it, and shows you two columns: your original, and what would leave. You protect what should not go — by the scan's own finding, by pressing a word, or by selecting a run of text with your hand — and nothing leaves while a suggestion is unanswered. Then you choose who answers, see the exact text before it is sent, and the answer comes back with your names restored on this machine.

**DE (draft).** Sie öffnen ein Dokument oder schreiben eine Frage. Z Privacy prüft sie mit seinen Regeln, seinen Sprachpaketen und den Werten, die Sie ihm beigebracht haben, und zeigt Ihnen zwei Spalten: Ihr Original und das, was hinausgehen würde. Sie schützen, was nicht gehen soll — durch den Fund der Prüfung, durch Druck auf ein Wort oder indem Sie mit der Hand einen Textlauf auswählen —, und nichts geht hinaus, solange ein Vorschlag unbeantwortet ist. Dann wählen Sie, wer antwortet, sehen den genauen Text, bevor er gesendet wird, und die Antwort kommt mit Ihren Namen zurück, wiederhergestellt auf diesem Rechner.

**AR (draft).** <div dir="rtl" lang="ar">

تفتح وثيقةً أو تكتب سؤالاً. ويفحصه Z Privacy بقواعده وحزم لغته والقيم التي علّمتَها إيّاه، ويعرض عليك عمودين: أصلُك، وما سيغادر. وتحمي ما لا ينبغي أن يذهب — بما وجده الفحص، أو بالضغط على كلمة، أو بتحديد مقطعٍ بيدك — ولا يغادر شيءٌ ما دام اقتراحٌ بلا جواب. ثمّ تختار من يُجيب، وترى النصَّ بالضبط قبل إرساله، ويعود الجوابُ وأسماؤك فيه، مُستعادةً على هذا الجهاز.

</div>

**Limits to watch — protection limits.** nothing leaves while a suggestion is unanswered

## Q12 · What does the AI actually receive?

**EN (approved).** Three things are worth separating. **What Z Privacy sends** is one request to the address you configured: the model's name, your protected text, and — inside the app, from the second question on — the exchange before it, in the protected form it left in. That protected text is the document and question as you approved them, so whatever the scan did not find and you did not mark is in it, and the earlier exchange carries whatever it carried. The request also carries the credential you gave for that service. **What the provider can observe anyway**, as with any program that connects to it, is your network address, the time, how large the request was and how often you ask. **And what we measured**, exactly: one request recorded byte for byte against a server on this machine, asserting that the body's content is the protected payload character for character and that no original value and no vault value appears in the body, the headers or the URL. That is a measurement of one request's content, not a proof that no other program or path exists.

**DE (draft).** Drei Dinge lohnt es zu trennen. **Was Z Privacy sendet**, ist eine Anfrage an die Adresse, die Sie eingerichtet haben: den Namen des Modells, Ihren geschützten Text und — innerhalb der Anwendung, ab der zweiten Frage — den vorangegangenen Austausch in der geschützten Form, in der er gegangen ist. Dieser geschützte Text ist das Dokument und die Frage, wie Sie sie freigegeben haben; was die Prüfung nicht gefunden und Sie nicht markiert haben, steht also darin, und der frühere Austausch trägt, was er getragen hat. Die Anfrage trägt außerdem das Zugangsmerkmal, das Sie für diesen Dienst hinterlegt haben. **Was der Anbieter ohnehin beobachten kann**, wie bei jedem Programm, das sich mit ihm verbindet, ist Ihre Netzwerkadresse, die Zeit, wie groß die Anfrage war und wie oft Sie fragen. **Und was wir gemessen haben**, genau: eine Anfrage, Byte für Byte gegen einen Server auf diesem Rechner aufgezeichnet, mit der Feststellung, dass der Inhalt des Rumpfes Zeichen für Zeichen die geschützte Nutzlast ist und dass weder ein Originalwert noch ein Tresorwert im Rumpf, in den Kopfzeilen oder in der URL vorkommt. Das ist eine Messung des Inhalts einer Anfrage und kein Beweis, dass kein anderes Programm und kein anderer Weg existiert.

**AR (draft).** <div dir="rtl" lang="ar">

ثلاثةُ أشياءَ يجدر فصلُها. **ما يُرسله Z Privacy** هو طلبٌ واحدٌ إلى العنوان الذي أعددتَه: اسمُ النموذج، ونصُّك المحميّ، و— داخل التطبيق، ابتداءً من السؤال الثاني — التبادلُ الذي قبله بالصورة المحميّة التي غادر بها. وهذا النصُّ المحميّ هو الوثيقةُ والسؤالُ كما أقررتَهما، فما لم يجده الفحصُ ولم تُعلِّمه أنت موجودٌ فيه، والتبادلُ السابق يحمل ما كان يحمله. ويحمل الطلبُ أيضاً بيانَ الاعتماد الذي أعطيتَه لتلك الخدمة. و**ما يستطيع المزوّد ملاحظتَه على كلّ حال**، كما مع أيّ برنامجٍ يتّصل به، هو عنوانُك الشبكيّ، والوقت، وحجمُ الطلب، وكم مرّةً تسأل. و**ما قِسناه نحن**، بالضبط: طلبٌ واحدٌ سُجّل بايتاً بايتاً أمام خادمٍ على هذا الجهاز، مع إثباتِ أنّ محتوى الجسم هو الحمولةُ المحميّة حرفاً بحرف، وأنّه لا تظهر قيمةٌ أصليّةٌ ولا قيمةٌ من الخزنة في الجسم ولا في الترويسات ولا في العنوان. وهذا قياسُ محتوى طلبٍ واحد، لا برهانٌ على أنّه لا يوجد برنامجٌ آخرُ ولا طريقٌ آخر.

</div>

**Limits to watch — claim limits.** a measurement of one request’s content, not a proof that no other path exists

## Q13 · How do the real names come back into the answer?

**EN (approved).** On your machine, out of your vault. Inside the app the answer is restored as it arrives; if you carried the question to a model yourself, «Add an answer» brings the text back and every token that chat has carried turns back into its name. A protected PDF has its own door: «z-pdf» in Settings reads such a file back into its names and says which session each one came from. A token whose key this vault does not hold stays as text, and the app says so rather than guessing.

**DE (draft).** Auf Ihrem Rechner, aus Ihrem Tresor. Innerhalb der Anwendung wird die Antwort wiederhergestellt, während sie eintrifft; haben Sie die Frage selbst zu einem Modell getragen, holt «Antwort hinzufügen» den Text zurück, und jedes Kennzeichen, das dieser Verlauf getragen hat, wird wieder zu seinem Namen. Ein geschütztes PDF hat seine eigene Tür: «z-pdf» in den Einstellungen liest eine solche Datei in ihre Namen zurück und sagt, aus welcher Sitzung jeder Name stammt. Ein Kennzeichen, dessen Schlüssel dieser Tresor nicht hat, bleibt Text, und die Anwendung sagt das, statt zu raten.

**AR (draft).** <div dir="rtl" lang="ar">

على جهازك، من خزنتك. داخل التطبيق يُستعاد الجوابُ وهو يصل؛ وإن حملتَ السؤالَ إلى نموذجٍ بنفسك فإنّ «أضِف جواباً» تُعيد النصَّ، وكلُّ رمزٍ حمله ذلك الحوار يعود إلى اسمه. ولملفّ PDF المحميّ بابُه: «z-pdf» في الإعدادات يقرأ ملفّاً كهذا إلى أسمائه ويقول من أيّ جلسةٍ جاء كلُّ اسم. والرمزُ الذي لا تملك هذه الخزنةُ مفتاحَه يبقى نصّاً، ويقول التطبيقُ ذلك بدل أن يُخمّن.

</div>

**Limits to watch — protection limits.** a token whose key this vault does not hold stays as text

## Q14 · Does Z Privacy see or store my documents?

**EN (approved).** There is no Z Privacy account, no Z Privacy server and no analytics: the source carries one network client and one send path, the interface cannot open a socket at all, and no Z Privacy address appears anywhere in it — so the only address this program is built to speak to is the provider you configured, with the credential you gave it. On your own machine, **in this build and as read from its source code rather than watched on a running installation**, it writes a known set of files and no others: the encrypted vault, one encrypted file per session, a lock beside them, and a settings file that never holds your work — plus the two documents you ask for by name, a protected copy and a restored plain PDF. The document in the preview is kept in its session's own encrypted file until it leaves by one of the doors that take text out, and leaving takes the copy with it. By that same reading of the source: a file being written exists briefly under a second name beside the finished one, in the same folder, and is renamed into place; nothing is written to the system's temporary directory, and no log file is written at all.

**DE (draft).** Es gibt kein Z-Privacy-Konto, keinen Z-Privacy-Server und keine Analytik: Der Quelltext trägt einen Netzwerk-Client und einen Sendeweg, die Oberfläche kann überhaupt keinen Socket öffnen, und nirgends in ihm steht eine Z-Privacy-Adresse — die einzige Adresse also, für die dieses Programm gebaut ist, mit ihr zu sprechen, ist der Anbieter, den Sie eingerichtet haben, mit dem Zugangsmerkmal, das Sie hinterlegt haben. Auf Ihrem eigenen Rechner schreibt es, **in diesem Build und aus seinem Quelltext gelesen, nicht an einer laufenden Installation beobachtet**, einen bekannten Satz von Dateien und keine anderen: den verschlüsselten Tresor, eine verschlüsselte Datei je Sitzung, eine Sperre daneben und eine Einstellungsdatei, die niemals Ihre Arbeit enthält — dazu die zwei Dokumente, die Sie ausdrücklich verlangen, eine geschützte Kopie und ein wiederhergestelltes einfaches PDF. Das Dokument in der Vorschau liegt in der eigenen verschlüsselten Datei seiner Sitzung, bis es durch eine der Türen geht, die Text hinaustragen; das Hinausgehen nimmt die Kopie mit. Nach derselben Lesung des Quelltextes: Eine Datei, die geschrieben wird, besteht kurz unter einem zweiten Namen neben der fertigen, im selben Ordner, und wird an ihren Platz umbenannt; in das temporäre Verzeichnis des Systems wird nichts geschrieben, und eine Protokolldatei wird überhaupt nicht geschrieben.

**AR (draft).** <div dir="rtl" lang="ar">

لا حساب في Z Privacy، ولا خادم لZ Privacy، ولا تحليلات: الشيفرةُ تحمل عميلَ شبكةٍ واحداً وطريقَ إرسالٍ واحداً، والواجهةُ لا تستطيع فتح مقبسٍ أصلاً، ولا يظهر فيها عنوانٌ لZ Privacy في أيّ موضع — فالعنوانُ الوحيد الذي بُني هذا البرنامج ليتحدّث إليه هو المزوّد الذي أعددتَه، ببيان الاعتماد الذي أعطيتَه. وعلى جهازك أنت، **في هذا البناء، ومقروءاً من شيفرته لا مُراقَباً على تثبيتٍ يعمل**، يكتب مجموعةً معروفةً من الملفّات ولا يكتب غيرها: الخزنةَ المعمّاة، وملفّاً معمّى لكلّ جلسة، وقفلاً بجانبها، وملفَّ إعداداتٍ لا يحمل عملَك أبداً — ومعها الوثيقتان اللتان تطلبهما باسمهما: نسخةٌ محميّة، وملفُّ PDF عاديٌّ مُستعاد. والوثيقةُ التي في المعاينة تبقى في ملفّ جلستها المعمّى حتّى تخرج من بابٍ من الأبواب التي تُخرج النصّ، وخروجُها يأخذ النسخةَ معه. وبالقراءة نفسِها للشيفرة: الملفُّ وهو يُكتَب يوجد لحظةً باسمٍ ثانٍ بجانب الملفّ التامّ، في المجلّد نفسِه، ثمّ يُعاد تسميتُه في موضعه؛ ولا يُكتب شيءٌ في المجلّد المؤقّت للنظام، ولا يُكتب ملفُّ سجلٍّ البتّة.

</div>

**Limits to watch — claim limits.** **in this build and as read from its source code rather than watched on a running installation**

## Q15 · Where are my names kept, and how are they protected?

**EN (approved).** In one encrypted vault file on your device, one block per protected value, opened by a passphrase that never leaves the machine — a test searches the written file for the names it was taught and finds none. The encryption is only as strong as the passphrase you choose, and an unlocked vault is readable by anything running as you on that machine: we protect a file at rest, not a machine already taken. On Linux the folder is narrowed to you and the core refuses to write if it cannot be; on Windows the folder is whatever that machine's own permissions make it.

**DE (draft).** In einer verschlüsselten Tresordatei auf Ihrem Gerät, ein Block je geschütztem Wert, geöffnet mit einer Passphrase, die das Gerät nie verlässt — ein Test durchsucht die geschriebene Datei nach den Namen, die ihr beigebracht wurden, und findet keinen. Die Verschlüsselung ist nur so stark wie die Passphrase, die Sie wählen, und ein entsperrter Tresor ist für alles lesbar, was auf diesem Rechner als Sie läuft: Wir schützen eine Datei im Ruhezustand, nicht einen bereits übernommenen Rechner. Unter Linux wird der Ordner auf Sie eingeschränkt, und der Kern weigert sich zu schreiben, wenn das nicht möglich ist; unter Windows ist der Ordner das, was die Rechte dieses Rechners aus ihm machen.

**AR (draft).** <div dir="rtl" lang="ar">

في ملفّ خزنةٍ معمّى واحدٍ على جهازك، بلوكٌ لكلّ قيمةٍ محميّة، يُفتَح بعبارة مرورٍ لا تغادر الجهاز أبداً — واختبارٌ يبحث في الملفّ المكتوب عن الأسماء التي عُلِّمها فلا يجد منها شيئاً. والتعميةُ ليست أقوى من عبارة المرور التي تختارها، والخزنةُ المفتوحة يقرؤها كلُّ ما يعمل باسمك على ذلك الجهاز: نحن نحمي ملفّاً ساكناً، لا جهازاً سقط أصلاً. وعلى لينكس يُضيَّق المجلّد عليك وحدك، ويرفض القلبُ الكتابةَ إن لم يستطع ذلك؛ وعلى ويندوز المجلّدُ هو ما تجعله صلاحيّاتُ ذلك الجهاز.

</div>

**Limits to watch — claim limits.** only as strong as the passphrase you choose / we protect a file at rest

## Q16 · What happens if I forget my passphrase?

**EN (approved).** The vault cannot be opened — not by you and not by us. This build has no recovery mechanism of any kind: no reset, no escrow, no second key and no copy held anywhere, and nothing on our side could recover the vault without the passphrase. The app says so before you set one: «There is no way back. Nobody holds a copy of this, and no reset exists — the passphrase never leaves this device and nothing on our side could recover the vault without it.»

**DE (draft).** Der Tresor lässt sich nicht öffnen — weder von Ihnen noch von uns. Dieser Build hat keinerlei Wiederherstellungsmechanismus: kein Zurücksetzen, keine Hinterlegung, keinen zweiten Schlüssel und keine irgendwo aufbewahrte Kopie, und nichts auf unserer Seite könnte den Tresor ohne die Passphrase wiederherstellen. Die Anwendung sagt das, bevor Sie eine festlegen: «Es gibt keinen Weg zurück. Niemand hat eine Kopie davon, und ein Zurücksetzen gibt es nicht — die Passphrase verlässt dieses Gerät nie, und nichts auf unserer Seite könnte den Tresor ohne sie wiederherstellen.»

**AR (draft).** <div dir="rtl" lang="ar">

لا تُفتَح الخزنة — لا منك ولا منّا. وهذا البناءُ ليس فيه أيُّ آليّة استرجاع: لا إعادةَ تعيين، ولا إيداعَ لدى أحد، ولا مفتاحَ ثانياً، ولا نسخةً محفوظةً في أيّ مكان، ولا شيءَ في جهتنا يستطيع استرجاع الخزنة بغير عبارة المرور. ويقول التطبيقُ ذلك قبل أن تضع واحدة: «لا طريق للعودة. لا أحد يملك نسخةً من هذه، ولا توجد إعادةُ تعيين — عبارةُ المرور لا تغادر هذا الجهاز أبداً، ولا شيء في جهتنا يستطيع استرجاع الخزنة بدونها.»

</div>

**Limits to watch — certainty.** this build has no recovery mechanism of any kind

## Q17 · Which AI services work with Z Privacy?

**EN (approved).** Two are supported and have been used against the live service: OpenAI and Anthropic. Four more are in the catalogue — xAI, DeepSeek, Moonshot and Google — and have not been tested with a live connection; a provider with no credential reports itself as unavailable rather than as ready. Five of the six go out through the same `chat/completions` request shape and Anthropic has its own, so a service that answers neither shape is not reached by this build however open the address field is. Every connection is made at an address you can change, and a model on your own computer needs no key at all.

**DE (draft).** Zwei werden unterstützt und wurden gegen den laufenden Dienst benutzt: OpenAI und Anthropic. Vier weitere stehen im Katalog — xAI, DeepSeek, Moonshot und Google — und sind mit einer echten Verbindung nicht getestet; ein Anbieter ohne Zugangsmerkmal meldet sich als nicht verfügbar und nicht als bereit. Fünf der sechs gehen über dieselbe Anfrageform `chat/completions` hinaus, und Anthropic hat eine eigene; ein Dienst, der keine der beiden Formen beantwortet, wird von diesem Build nicht erreicht, so offen das Adressfeld auch ist. Jede Verbindung wird an einer Adresse hergestellt, die Sie ändern können, und ein Modell auf Ihrem eigenen Rechner braucht überhaupt keinen Schlüssel.

**AR (draft).** <div dir="rtl" lang="ar">

اثنان مدعومان وقد استُعملا مع الخدمة الحيّة: OpenAI وAnthropic. وأربعةٌ غيرهما في القائمة — xAI وDeepSeek وMoonshot وGoogle — ولم تُختبَر باتّصالٍ حيّ؛ والمزوّدُ الذي لا بيانَ اعتمادٍ له يُبلِّغ عن نفسه أنّه غيرُ متاح لا أنّه جاهز. وخمسةٌ من الستّة تخرج بصيغة الطلب نفسِها `chat/completions`، ولAnthropic صيغتُها؛ فالخدمةُ التي لا تجيب إحدى الصيغتين لا يصل إليها هذا البناء مهما كان حقلُ العنوان مفتوحاً. وكلُّ اتّصالٍ يُجرى عند عنوانٍ تستطيع تغييره، والنموذجُ على جهازك لا يحتاج مفتاحاً أصلاً.

</div>

**Limits to watch — certainty.** have not been tested with a live connection — never «supported»

## Q18 · Does Z Privacy make me anonymous to the AI provider?

**EN (approved).** No. You sign up under your own name with your own credential, and the provider is entitled to know who its customer is; your network address, the time and the size of each request are visible to them as they are to any service you connect to. Z Privacy removes values from inside the text — it does not remove you. What it protects is the people in your documents, who agreed to nothing with your provider.

**DE (draft).** Nein. Sie melden sich unter Ihrem eigenen Namen mit Ihrem eigenen Zugangsmerkmal an, und der Anbieter darf wissen, wer sein Kunde ist; Ihre Netzwerkadresse, die Zeit und die Größe jeder Anfrage sind für ihn sichtbar wie für jeden Dienst, mit dem Sie sich verbinden. Z Privacy entfernt Werte aus dem Text — Sie entfernt es nicht. Was es schützt, sind die Menschen in Ihren Dokumenten, die mit Ihrem Anbieter nichts vereinbart haben.

**AR (draft).** <div dir="rtl" lang="ar">

لا. أنت تشترك باسمك وببيان اعتمادك، وللمزوّد أن يعرف من هو زبونُه؛ وعنوانُك الشبكيّ والوقتُ وحجمُ كلّ طلبٍ ظاهرةٌ له كما تظهر لأيّ خدمةٍ تتّصل بها. وZ Privacy يزيل قيماً من داخل النصّ — ولا يزيلك أنت. والذي يحميه هم الناسُ الذين في وثائقك، ولم يتّفقوا مع مزوّدك على شيء.

</div>

**Limits to watch — protection limits.** removes values from inside the text — it does not remove you

## Q19 · What does Z Privacy detect automatically, and what must I mark myself?

**EN (approved).** Automatically: what its rules describe. The IBAN and BIC rules are not tied to a language pack, so they do not depend on which language a document is in; the language sets add e-mail addresses, telephone numbers, tax and social-insurance numbers, customer, contract and employee references, dates of birth, people, companies and addresses — and every value you have taught it is matched wherever it appears. All of that depends on two things upstream of any rule: that the text reached the scanner as it reads on the page, and that the value is written in a form the rules describe. Anything it is unsure of becomes a suggestion that waits for your word, and the law «nothing leaves while a suggestion is unanswered» is asked of every door that takes text out of the app: sending to a model, copying the protected text, copying the chat, and saving a protected PDF. Those doors are not a list somebody keeps up to date — they are counted from what the functions do, so a new one is caught by the count rather than remembered. What the scanner still misses is written down rather than left to be found: a typographic ligature, a date of birth written out in words, and a payment card from a network whose prefix is not in the published table.

**DE (draft).** Automatisch: was seine Regeln beschreiben. Die Regeln für IBAN und BIC sind an kein Sprachpaket gebunden, hängen also nicht davon ab, in welcher Sprache ein Dokument ist; die Sprachsätze fügen E-Mail-Adressen, Telefonnummern, Steuer- und Sozialversicherungsnummern, Kunden-, Vertrags- und Personalnummern, Geburtsdaten, Personen, Firmen und Adressen hinzu — und jeder Wert, den Sie ihm beigebracht haben, wird überall dort erkannt, wo er vorkommt. All das hängt von zwei Dingen ab, die jeder Regel vorausgehen: dass der Text so bei der Prüfung ankam, wie er auf der Seite zu lesen ist, und dass der Wert in einer Form geschrieben ist, die die Regeln beschreiben. Was sie nicht sicher einordnen kann, wird zu einem Vorschlag, der auf Ihr Wort wartet, und das Gesetz «nichts geht hinaus, solange ein Vorschlag unbeantwortet ist» wird an jeder Tür gestellt, die Text aus der Anwendung trägt: an ein Modell senden, den geschützten Text kopieren, den Verlauf kopieren und ein geschütztes PDF speichern. Diese Türen sind keine Liste, die jemand pflegt — sie werden daraus gezählt, was die Funktionen tun, sodass eine neue von der Zählung erfasst und nicht erinnert wird. Was die Prüfung weiterhin übersieht, ist aufgeschrieben und nicht dem Finden überlassen: eine typografische Ligatur, ein ausgeschriebenes Geburtsdatum und eine Zahlungskarte aus einem Netz, dessen Präfix nicht in der veröffentlichten Tabelle steht.

**AR (draft).** <div dir="rtl" lang="ar">

تلقائيّاً: ما تصفه قواعدُه. وقاعدتا IBAN وBIC غيرُ مربوطتين بحزمة لغة، فلا تتوقّفان على لغة الوثيقة؛ وتضيف حزمُ اللغات عناوينَ البريد وأرقامَ الهواتف والأرقامَ الضريبيّة وأرقامَ التأمين الاجتماعيّ وأرقامَ العملاء والعقود والموظّفين وتواريخَ الميلاد والأشخاصَ والشركاتِ والعناوين — وكلُّ قيمةٍ علَّمتَها إيّاه تُطابَق حيثما وردت. وكلُّ ذلك يتوقّف على أمرين سابقين لأيّ قاعدة: أن يكون النصُّ قد وصل إلى الفحص كما يُقرأ على الصفحة، وأن تكون القيمةُ مكتوبةً بصورةٍ تصفها القواعد. وما لا يتيقّن منه يصير اقتراحاً ينتظر كلمتَك، وقانونُ «لا يغادر شيءٌ ما دام اقتراحٌ بلا جواب» يُسأل عند كلّ بابٍ يُخرج النصَّ من التطبيق: الإرسالُ إلى نموذج، ونسخُ النصّ المحميّ، ونسخُ الحوار، وحفظُ ملفّ PDF محميّ. وهذه الأبوابُ ليست قائمةً يتعهّدها أحد — بل تُحصى ممّا تفعله الدوالّ، فالبابُ الجديد يلتقطه الإحصاءُ ولا يُتذكَّر. وما يفوت الفحصَ مكتوبٌ ولم يُترك ليُكتشَف: رباطٌ طباعيّ، وتاريخُ ميلادٍ مكتوبٌ بالحروف، وبطاقةُ دفعٍ من شبكةٍ ليست بادئتُها في الجدول المنشور.

</div>

**Limits to watch — protection limits.** depends on two things upstream of any rule

## Q20 · Which file types and languages does it support?

**EN (written from 119's measurement, awaiting the owner's word).** Files: plain text (`.txt`, `.md`, `.csv`), Word documents (`.docx`) and PDFs. A PDF with no text layer — a photograph of a document — is refused by name rather than guessed at, and so is an encrypted one. Detection has four language packs today — English, German, Swedish and Arabic — beside rule sets that are not bound to a language, and the interface itself speaks those four. Arabic inside a PDF is a case of its own: a file that carries its text in the shapes a layout program drew is refused by name, because the order read would be the drawing’s and the words would come out backwards, and you are pointed to `.docx` or `.txt`; an Arabic PDF written in reading order is not refused and reads as well as the same text as plain text. Two limits remain there: a file drawn backwards that still carries ordinary letters is not caught by this, and a protected PDF that Z Privacy itself wrote in Arabic can no longer be brought in as a document to protect.

**DE (draft).** Dateien: reiner Text (`.txt`, `.md`, `.csv`), Word-Dokumente (`.docx`) und PDFs. Eine PDF-Datei ohne Textebene — ein Foto eines Dokuments — wird mit Namen zurückgewiesen statt erraten, und eine verschlüsselte ebenso. Die Erkennung hat heute vier Sprachpakete — Englisch, Deutsch, Schwedisch und Arabisch — neben Regelsätzen, die an keine Sprache gebunden sind, und die Oberfläche selbst spricht diese vier. Arabisch in einer PDF-Datei ist ein Fall für sich: Eine Datei, die ihren Text in den Anzeigeformen führt, die ein Layoutprogramm gezeichnet hat, wird mit Namen zurückgewiesen — die gelesene Reihenfolge wäre die der Zeichnung und die Wörter kämen rückwärts heraus —, und Sie werden auf `.docx` oder `.txt` verwiesen; eine arabische PDF-Datei, die in Leserichtung geschrieben ist, wird nicht zurückgewiesen und ebenso gut gelesen wie derselbe Text als reiner Text. Zwei Einschränkungen bleiben dort: eine rückwärts gezeichnete Datei, die dennoch gewöhnliche Buchstaben führt, wird davon nicht erfasst, und eine geschützte PDF-Datei, die Z Privacy selbst auf Arabisch geschrieben hat, kann nicht mehr als zu schützendes Dokument hereingeholt werden.

**AR (draft).** <div dir="rtl" lang="ar">

الملفّات: النصّ العاديّ (`.txt` و`.md` و`.csv`)، ووثائق Word (`.docx`)، وملفّات PDF. وملفّ PDF بلا طبقة نصّ — صورةٌ لوثيقة — يُرفض باسمِه لا يُخمّن، وكذلك الملفّ المعمّى. وللكشف اليوم أربعُ حزم لغويّة — الإنجليزيّة والألمانيّة والسويديّة والعربيّة — إلى جانب مجموعات قواعدَ غيرِ مرتبطةٍ بلغة، والواجهةُ نفسُها تتكلّم هذه الأربع. والعربيّة داخل ملفّ PDF حالةٌ قائمةٌ بذاتِها: فالملفّ الذي يحمل نصَّه بأشكال العرض التي رسمها برنامجُ التنسيق يُرفض باسمِه، لأنّ الترتيبَ المقروء سيكون ترتيبَ الرسم وتخرج الكلماتُ مقلوبةً، وتُوجَّه إلى `.docx` أو `.txt`؛ أمّا ملفّ PDF العربيّ المكتوب بترتيب القراءة فلا يُرفض، ويُقرأ كما يُقرأ النصُّ نفسُه نصّاً عاديّاً. ويبقى هناك حدّان: ملفٌّ مرسومٌ مقلوباً ومع ذلك يحمل حروفاً عاديّةً لا يلتقطُه هذا، وملفّ PDF محميّ كتبه Z Privacy نفسُه بالعربيّة لم يعد يُمكن إدخالُه وثيقةً لتُحمى.

</div>

**Limits to watch — protection limits and certainty.** «is refused by name» must stay a refusal and not become «is handled»; «an Arabic PDF written in reading order is **not** refused» must survive, because without it the answer condemns a format that works; and the two remaining limits must not be softened into a reassurance. **Not stated in any language:** whether the z-pdf read-back door returns reversed Arabic — paper 119 says «may» and calls it another door and another paper, so it is an acknowledged unknown and writing it down would be inventing a measurement.

## Q21 · Is Z Privacy free?

**EN (approved).** Yes. There is no paid tier, no account and nothing to subscribe to, and the source is under the Apache License 2.0. What can cost money is the model you choose: a credential from OpenAI or Anthropic is billed by them at their prices, and a model running on your own computer costs nothing at all.

**DE (draft).** Ja. Es gibt keine kostenpflichtige Stufe, kein Konto und nichts zu abonnieren, und der Quelltext steht unter der Apache-Lizenz 2.0. Geld kosten kann das Modell, das Sie wählen: Ein Zugangsmerkmal von OpenAI oder Anthropic wird von dort zu deren Preisen abgerechnet, und ein Modell, das auf Ihrem eigenen Rechner läuft, kostet überhaupt nichts.

**AR (draft).** <div dir="rtl" lang="ar">

نعم. لا توجد نسخةٌ مدفوعة، ولا حساب، ولا شيءَ يُشترَك فيه، والشيفرةُ تحت رخصة أباتشي ٢٫٠. والذي قد يكلّف مالاً هو النموذجُ الذي تختاره: بيانُ اعتمادٍ من OpenAI أو Anthropic يُحاسبانك عليه بأسعارهما، والنموذجُ الذي يعمل على جهازك لا يكلّف شيئاً البتّة.

</div>

**Limits to watch — certainty.** what can cost money is the model you choose

## Q22 · Is it open source, and can companies use it?

**EN (approved).** Yes — Apache License 2.0, with the source repository linked from this site. Use it as you like, in a company or alone, and ask nobody. This project ships a `NOTICE` file, and §4(d) of the licence says what a distributed derivative work must do with the notices such a file contains; the licence and the file are both published here, and they are the text that governs rather than anything said on this page. It is attribution carried forward, not an advertisement you owe us.

**DE (draft).** Ja — Apache-Lizenz 2.0, mit dem Quelltext-Repository, das von dieser Website aus verlinkt ist. Nutzen Sie ihn, wie Sie wollen, in einem Unternehmen oder allein, und fragen Sie niemanden. Dieses Projekt liefert eine `NOTICE`-Datei mit, und § 4 Buchst. d der Lizenz sagt, was ein verbreitetes abgeleitetes Werk mit den Hinweisen tun muss, die eine solche Datei enthält; die Lizenz und die Datei sind beide hier veröffentlicht, und sie sind der maßgebliche Text und nicht das, was auf dieser Seite steht. Es ist weitergetragene Namensnennung, keine Werbung, die Sie uns schulden.

**AR (draft).** <div dir="rtl" lang="ar">

نعم — رخصةُ أباتشي ٢٫٠، ومستودعُ الشيفرة موصولٌ من هذا الموقع. استعمله كما تشاء، في شركةٍ أو وحدك، ولا تستأذن أحداً. ويشحن هذا المشروعُ ملفَّ `NOTICE`، والبندُ ٤(د) من الرخصة يقول ما على العمل المشتقّ المنشور أن يفعله بالإشعارات التي يحويها مثلُ هذا الملفّ؛ والرخصةُ والملفُّ منشوران هنا كلاهما، وهما النصُّ الحاكم لا ما يُقال في هذه الصفحة. وهي نسبةٌ تُحمَل إلى الأمام، لا إعلانٌ تدين لنا به.

</div>

**Limits to watch — certainty.** they are the text that governs rather than anything said on this page

## Q23 · How can I check Z Privacy's claims myself?

**EN (approved).** `docs/CLAIMS.md` lists every claim with the same four lines each: the sentence we actually show, what it does **not** cover, the test or gate that proves it, and the command you run yourself. It is worth knowing what those two kinds of proof are: a **test** runs this product's code and measures what it does, while a **gate** reads the source and measures its shape — that there is one network client, that the interface cannot open a socket, that every door obeys a law. A shape check shows that the code satisfies the constraint it checks; it is not a recording of the program running, and no number of them adds up to a network capture, an installation or a security audit — which is why some claims in that file carry the word «unproven» rather than being removed from it.

**DE (draft).** `docs/CLAIMS.md` führt jede Aussage mit denselben vier Zeilen auf: den Satz, den wir tatsächlich zeigen, was er **nicht** abdeckt, den Test oder die Prüfung, die ihn belegt, und den Befehl, den Sie selbst ausführen. Es lohnt sich zu wissen, was diese zwei Arten von Beleg sind: Ein **Test** führt den Code dieses Produkts aus und misst, was er tut, während eine **Prüfung** den Quelltext liest und seine Form misst — dass es einen Netzwerk-Client gibt, dass die Oberfläche keinen Socket öffnen kann, dass jede Tür einem Gesetz folgt. Eine Formprüfung zeigt, dass der Code die Bedingung erfüllt, die sie prüft; sie ist keine Aufzeichnung des laufenden Programms, und keine Zahl von ihnen ergibt zusammen einen Netzwerkmitschnitt, eine Installation oder ein Sicherheitsaudit — deshalb tragen manche Aussagen in dieser Datei das Wort «unbelegt», statt aus ihr entfernt zu werden.

**AR (draft).** <div dir="rtl" lang="ar">

يُحصي `docs/CLAIMS.md` كلَّ ادّعاءٍ بالأسطر الأربعة نفسِها: الجملةُ التي نعرضها فعلاً، وما **لا** يغطّيه، والاختبارُ أو البوّابةُ التي تثبته، والأمرُ الذي تشغّله بنفسك. ويجدر أن تعرف ما هذان النوعان من الإثبات: **الاختبارُ** يشغّل شيفرة هذا المنتَج ويقيس ما تفعله، و**البوّابةُ** تقرأ الشيفرة وتقيس شكلَها — أنّ عميل الشبكة واحد، وأنّ الواجهة لا تستطيع فتح مقبس، وأنّ كلّ بابٍ يخضع لقانون. والبوّابةُ الشكليّة تُظهر أنّ الشيفرة تستوفي الشرط الذي تفحصه؛ وليست تسجيلاً للبرنامج وهو يعمل، ولا يجتمع أيُّ عددٍ منها ليساوي التقاطَ شبكةٍ أو تثبيتاً أو تدقيقاً أمنيّاً — ولهذا تحمل بعضُ الادّعاءات في ذلك الملفّ كلمةَ «غير مُثبَت» بدل أن تُحذف منه.

</div>

**Limits to watch — claim limits.** satisfies the constraint it checks — never «cannot be»

## Q24 · Which operating systems does it run on, and why does Windows warn me?

**EN (approved).** Linux x86_64 with GTK3, and Windows 10 or 11 on x86_64; macOS, iOS and Android are not built. On Windows the first start shows a blue «Windows protected your PC» page, because nothing has signed this installer: that page means Windows has no basis to treat the file as trusted, not that it has examined it and found it safe or unsafe. The SHA-256 printed on the download page tells you the file you have is the file that fingerprint describes, provided the fingerprint itself comes from a source you trust — it says nothing about who published the file, and if the site serving both were compromised both could change together. It is not a substitute for a signature, and the download page's own paragraph says what the screen looks like and how it is got through.

**DE (draft).** Linux x86_64 mit GTK3 und Windows 10 oder 11 auf x86_64; macOS, iOS und Android werden nicht gebaut. Unter Windows zeigt der erste Start eine blaue Seite «Der Computer wurde durch Windows geschützt», weil dieses Installationsprogramm von nichts signiert ist: Diese Seite bedeutet, dass Windows keine Grundlage hat, die Datei als vertrauenswürdig zu behandeln, und nicht, dass es sie geprüft und für sicher oder unsicher befunden hätte. Die auf der Download-Seite abgedruckte SHA-256 sagt Ihnen, dass die Datei, die Sie haben, die Datei ist, die dieser Fingerabdruck beschreibt — vorausgesetzt, der Fingerabdruck selbst stammt aus einer Quelle, der Sie vertrauen. Über den Herausgeber der Datei sagt er nichts, und wäre die Website, die beides ausliefert, kompromittiert, könnten sich beide zugleich ändern. Er ist kein Ersatz für eine Signatur, und der eigene Absatz der Download-Seite sagt, wie der Bildschirm aussieht und wie man durch ihn hindurchkommt.

**AR (draft).** <div dir="rtl" lang="ar">

لينكس x86_64 بواجهة GTK3، وويندوز ١٠ أو ١١ على x86_64؛ وماك أو إس وiOS وأندرويد غيرُ مبنيّة. وعلى ويندوز يعرض أوّلُ تشغيلٍ صفحةً زرقاء «حمى ويندوز جهازك»، لأنّ هذا المثبِّت لم يوقّعه شيء: ومعنى تلك الصفحة أنّ ويندوز لا يملك أساساً ليعدّ الملفّ موثوقاً، لا أنّه فحصه فوجده سليماً أو غيرَ سليم. وبصمةُ SHA-256 المطبوعةُ في صفحة التنزيل تقول لك إنّ الملفّ الذي بين يديك هو الملفُّ الذي تصفه تلك البصمة، بشرط أن تكون البصمةُ نفسُها من مصدرٍ تثق به — ولا تقول شيئاً عمّن نشر الملفّ، ولو اختُرق الموقعُ الذي يقدّم الاثنين لتغيّرا معاً. وهي ليست بديلاً عن توقيع، وفِقرةُ صفحة التنزيل نفسُها تقول كيف تبدو الشاشة وكيف يُمضى منها.

</div>

**Limits to watch — certainty.** provided the fingerprint itself comes from a source you trust

## Q25 · Who makes Z Privacy?

**EN (approved).** Faruk AB, Aktiebolag (AB), Sweden. Company registration (Org.nr) 559473-3494. Hotellgatan 3, 311 31 Falkenberg, Sweden. Contact and support: zprivacy@mono-peak.com — there is no form and nothing is collected on this site.

**DE (draft).** Faruk AB, Aktiebolag (AB), Schweden. Handelsregisternummer (Org.nr) 559473-3494. Hotellgatan 3, 311 31 Falkenberg, Schweden. Kontakt und Unterstützung: zprivacy@mono-peak.com — es gibt kein Formular, und auf dieser Website wird nichts erhoben.

**AR (draft).** <div dir="rtl" lang="ar">

Faruk AB، شركةُ مساهمةٍ (Aktiebolag) في السويد. رقمُ السجلّ التجاريّ (Org.nr) ‏559473-3494. Hotellgatan 3, 311 31 Falkenberg, Sweden. للتواصل والدعم: zprivacy@mono-peak.com — لا يوجد نموذجُ إرسال، ولا يُجمَع شيءٌ في هذا الموقع.

</div>

**Limits to watch — certainty.** nothing is collected on this site

---

## What is still owed before any of this publishes

1. **Q20**, from paper 119's measurement, in all three languages, written the
   same day as the download card so the two cannot drift.
2. **A per-language absolutes register.** `scripts/check_the_absolutes.py`
   holds one for English today; German and Arabic need their own, because the
   absolute words are different words and the qualifier that saves one is in a
   different place in the sentence.
3. **The semantic review**, which no script does: the German read by somebody
   who reads German, and the Arabic by the owner.

*Branch `feat/the-questions-before-the-name`. No page, no engine change, no
app feature.*
