# Publishing Z — Windows and Apple

A study written 15 October 2026 on the owner's question. Sources are at the
end. The owner's ruling on money: «نبدأ بالمجاني أو 10 دولارات في الشهر».

## Windows

No licence from Microsoft is needed to publish. Signing exists for one reason:
SmartScreen's warning in front of an unsigned file. Our installer has been live
on beta since 4 October. A user opens it today with «More info → Run anyway».

| Road | Cost | Warning |
|---|---|---|
| **Microsoft Store, MSIX** | free | **none**: Microsoft re-signs the package |
| SignPath Foundation (OSS) | free | builds with reputation; the publisher shown is «SignPath Foundation» |
| Azure Artifact Signing | about $9.99 a month | builds with reputation; EU organisations qualify; a 3-year business history is unclear (Faruk AB, 2024) |
| OV / EV certificate | $150–400+ a year | out by the owner's ruling. EV has not bypassed SmartScreen since 2024 |

**Reputation.** SmartScreen judges a publisher by its history. A signed file
from a new publisher still warns until enough people have run that
publisher's files without harm. The reputation then carries to every later
version signed by the same identity. An unsigned file starts from zero with
every version.

**Chosen order:**
1. The Store with MSIX.
2. SignPath.
3. Azure.

**The steps of the Store road:**
1. **The owner's hand:** a free company account for Faruk AB at
   storedeveloper.microsoft.com (D-U-N-S, or registry documents, plus a
   company-domain e-mail). In Partner Center, reserve the name «Z Privacy».
   The listing needs a privacy-policy URL; Z's privacy pages are live.
2. **A builder:**
   - **Measure first:** where `%LOCALAPPDATA%\ZPrivacy` (the vault) lands
     inside an MSIX package. Windows virtualises a packaged app's AppData,
     and removing the app removes it.
   - Then package as MSIX in the Windows CI.
   - Never certify a package whose vault place was not measured.
3. Submit, certify, publish.

## Apple (macOS)

Z is a desktop app, so the target is the Mac. iPhone is not on the road.

**What we already have.**
- A paid Apple Developer membership. It is in the name of the owner's company
  and is the one YourVoices uses.
- An App Store Connect API key, which needs no 2FA or person in the loop.
- A working GitHub workflow on `macos-15` from YourVoices' iOS build. The Z
  repository is public, so macOS runner minutes are free.
- In the core, `data_dir.rs` already names the Mac's place:
  `~/Library/Application Support/ZPrivacy`.

**What we do not have.**
- **The Flutter app has no `macos/` target yet.** The folder does not exist.
- No Mac build of the Rust core or the bridge has ever run.
- Nobody owns a Mac to open the app on. A runner can build and test, but only
  a person on a Mac sees it.

**Two roads, both inside the membership already paid:**

| Road | Cost | What the user sees | What it demands |
|---|---|---|---|
| **Developer ID + notarisation** (download from z-privacy.com) | in the membership | opens with Apple's ordinary «downloaded from the internet» question. No reputation phase: notarised is trusted at once | a Developer ID Application certificate; hardened runtime; `notarytool` with the API key; staple |
| **Mac App Store** | in the membership | installs from the Store, no question | **App Sandbox is mandatory**; Apple review; the App Privacy label |

**The App Privacy label is a gift for Doha.** Z collects nothing, so its
Store page can carry Apple's own words: **«Data Not Collected»**.

**What the sandbox changes, and must be measured before anything is
submitted:**
- **The vault.** Under the sandbox, `HOME` points into the app's container,
  so the vault moves into `~/Library/Containers/<bundle>/…`. This is probably
  good isolation, but it is measured, not assumed.
- **Saved PDFs.** `$HOME/Documents/zprivacy` would land inside the container,
  where the person cannot find it. A save needs the user-selected-file
  entitlement and a save panel.
- **The network.** Calls to the AI providers need the network-client
  entitlement.

**The trap YourVoices already paid for (9 September).** `fastlane cert`
creates a new certificate on every run, and its private key dies with the
runner. Apple's certificate cap then fills with dead certificates. So for Z:
- generate the key and CSR **once**, on our own machine;
- keep one `.p12` in the repository secrets;
- use `import_certificate` in CI;
- never `cert` per run.

**Steps, in order:**
1. A builder adds the macOS target and a `macos-15` workflow: build, Rust
   tests, Dart tests. Nothing is signed yet.
2. Developer ID + notarisation, so that z-privacy.com offers a Mac download.
3. Measure the sandbox (vault, saved PDFs, network), then the Mac App Store.

## Sources
- [Microsoft Learn — Code signing options for Windows app developers (29 Aug 2026)](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options)
- [Windows Developer Blog — company registration free (7 May 2026)](https://blogs.windows.com/windowsdeveloper/2026/05/07/publish-to-microsoft-store-as-a-company-now-with-free-registration-and-faster-onboarding/)
- [SignPath Foundation terms](https://signpath.org/terms)
- [Microsoft Q&A — Trusted Signing history verification](https://learn.microsoft.com/en-us/answers/questions/5496353/how-do-i-verify-history-for-trusted-signing-servic)
- [pub.dev `dmg` — Flutter macOS notarisation with an API key](https://pub.dev/packages/dmg)
- [ITNext — Flutter macOS distribution outside the App Store](https://itnext.io/complete-guide-to-flutter-macos-distribution-outside-the-app-store-e382c6d7db47)
- [KeepCoding — notarisation in practice (May 2026)](https://keepcoding.io/blog-frr/notarizacion-macos-guia-linter/)

## The owner's ruling on Apple (15 October)

«نستأجر مستودعاً من أمازون ونقوم بالعمل على ما يحتاجه آبل وتجربته، وربما نجهّز
قائمة عمل لكلٍّ من التطبيق والمنصّة لإعدادات آبل، ولكن نؤجّلها لمرحلة ما بعد
الانتهاء الكامل من ويندوز ولينكس».

- **Apple is DEFERRED** until Windows and Linux are completely finished.
- **The place to work and test is a rented Mac at Amazon (EC2 Mac).** It answers
  «nobody owns a Mac».
- When the time comes, there is one work list for the **app** and one for the
  **platform**.

**EC2 Mac, measured on 15 October (check again before renting):**
- It is a **Dedicated Host** with a **24-hour minimum**, because of Apple's
  licence.
- Billing is per second after that. The host is billed while it is allocated,
  even when the instance is stopped, so **release the host** when done.
- A third-party page (June 2026) gives the price as **about $1.23 an hour** for
  mac-m4, which is about $30 for the first day. This is not verified on AWS's
  own page, and availability in Stockholm (eu-north-1) is not confirmed.
- Sources: [AWS EC2 Mac FAQ](https://aws.amazon.com/ec2/instance-types/mac/faqs/) ·
  [AWS docs — EC2 Mac instances](https://docs.aws.amazon.com/en_eu/AWSEC2/latest/UserGuide/ec2-mac-instances.html) ·
  [re:Post — billed while stopped](https://repost.aws/questions/QURgjEEC8GTeKiGfJ8b46rkA/billing-and-cost-mac-m2-istance) ·
  [Green Mini comparison](https://www.greenmini.nl/compare/aws-ec2-mac-alternative/)
