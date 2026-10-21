# 099 — The company vault: one vault on the company's own machine, many Z devices, one writer

**Owner, 21 October (rule 82, «نعم»):** «الخزنة الشبكية تسكن داخل كمبيوتر أو سيرفر في الشركة. ما نريده إمكانية وصول جميع أو بعض أجهزة الشركة إلى نفس الخزنة، تتشارك البلوكات الموجودة داخل الخزنة.» A sub-application of Z opens the company's vault and nothing else; the private Z keeps its private vault; one app, one vault. The vault sits on a machine or server inside the company; each device has its own passphrase, added and removed by the vault's administrator; a device works connected, with no local copy; values travel only inside a closed channel within the company, never over the internet. Windows and Linux from day one.
**When:** after publishing Z (rule 82-هـ). This paper is the plan the owner asked for during the wait; no branch, no build before his word.
**Law:** every claim in `docs/CLAIMS.md` stays true or is rewritten honestly — «no server of ours» (C-03) stays true because the host is the company's machine, and a new claim is written: **the company's host machine sees the values**; «one vault, one writer» (secure_file.rs) becomes structure; protection is permanent (089); a block is one per value and crosses profiles (rules 58–59); nothing leaves while a word waits (C-11); the exit law lives at the door text leaves by.

## 1 · The shape, in one page

```
company machine (Windows or Linux)          company devices (Windows or Linux)
┌──────────────────────────────┐             ┌─────────────────────────────┐
│  z-host  (z_core in service  │◄── LAN ────►│  Z company edition          │
│  mode, the ONE writer of     │  mutual TLS │  discovery, hand, screens   │
│  vault.zv on this machine)   │             │  mint/restore ask the host  │
└──────────────────────────────┘             └─────────────────────────────┘
```

- **z-host** is `z_core` run as a service: it opens the one `vault.zv` with the vault passphrase (the administrator's), holds it unlocked while the service runs, and is the only process that ever writes it. The lock law of `secure_file.rs` is then structural: no second writer exists on the network.
- **Z company edition** is the same app with one difference at the vault seam: where the private Z calls the vault in-process, the company edition calls the host over the channel. Discovery (the scanner), the hand, the three parts, the chat and the AI door stay on the device, unchanged. What leaves the device to the AI is the protected text, as today; what leaves the device to the host is a value to mint or a token to restore, inside the channel.
- **The channel**: mutual TLS between the device and the host, both ends holding a key the administrator issued; no third party, no internet, no discovery service — the host's address is typed once into the device's settings. (The provider door already carries one HTTP client; the host door is a second, separate client with its own census line, G1/G5 extended by name.)

## 2 · Devices and passphrases (rule 82-ب)

- The administrator runs z-host with the vault passphrase and **enrols** a device: the host prints a one-time enrolment code; the device types it once and receives its device key; the administrator names the device. The device's own passphrase (typed by the person at each start, as the private vault's is) unlocks the device key, not the vault — so a stolen laptop without its passphrase holds nothing the host will answer.
- **Removing a device** is one act on the host: its key is refused from the next call; the vault, the blocks and every other device are untouched.
- The vault passphrase lives only on the host machine; the devices never see it and cannot read `vault.zv` directly.

## 3 · What travels (rule 82-د)

| device → host | host → device |
|---|---|
| mint: (kind, value) | the token (new or existing — one value, one block, rule 49) |
| restore: a list of tokens | the values, for the device to put back locally |
| is-token / find: a token | yes/no and its kind |
| list for the screens: nothing secret | kinds, counts, token names — never values |

Values travel only inside the TLS channel and only between the company's own machines. The host logs nothing of the values (same law as the private vault's audit: records of acts, no secrets in a log line — the gate that reads log lines for secrets covers the host's).

## 4 · Connected, no local copy (rule 82-ج, lead's assumption)

A device with no host in reach shows the host's absence as a sentence and refuses the acts that need it (mint, restore); reading already-protected text and typing continue. No cached vault, no merge, no conflict — the price of this assumption is honesty when the network is down, which the sentence pays. If the owner later wants an offline cache, that is its own paper, because it reopens «one writer».

## 5 · The sub-application (rule 82)

One binary, two editions decided at build or at first run? **At build**: `zprivacy-company` is the same Flutter app with the company seam compiled in and the private vault seam compiled out, so the wrong state (one app with two vaults) cannot be built. Its first run asks for the host address and the enrolment code instead of «Create a vault». Packaging: a second artefact beside the private one on both platforms, the same scripts, the same stamps and needles (098).

## 6 · What this changes in the core

- A `VaultDoor` trait with two implementations: `Local` (today's code, unchanged) and `Remote` (the channel). Every caller that mints, restores or lists goes through the trait — a census gate counts the callers so no path reaches the local file in the company edition.
- `z-host`: a thin binary over `z_core` with the service loop, the enrolment acts and the device table (device name, public key, added/removed dates) kept beside the vault as a sealed file like the sessions.
- Claims: C-03 unchanged; a new C-17 «the company's host sees the values and the devices' addresses; nothing of ours does»; C-06's folder law applies to the host's folder on both platforms (the Windows half named in 098 item 5 becomes real work here).

## 7 · Measurement

Rust: the trait's two implementations pass the same contract tests (the vault file contracts, G22, run against both doors); the enrolment, removal and refusal paths each a test; a wire capture of the channel (as `wire_capture.rs` does for the provider) proving values appear only inside TLS and never in a log. Dart: the company edition's first run; the host-absent sentence; the census that no screen reaches the local vault. Both platforms: the host service installed and started on Windows and Linux, one device of each enrolled, a word protected on one device restored on the other — the owner's own eyes, written into the INBOX.

## Not decided here

The host's own update path; more than one host (a second company site); an offline cache; the administrator's screen (a command line is enough for the first round).
