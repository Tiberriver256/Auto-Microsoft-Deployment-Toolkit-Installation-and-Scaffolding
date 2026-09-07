# Auto Microsoft Deployment Toolkit — Installation and Scaffolding

> ⚠️ **LEGACY-2016 — unmaintained reference. Do not run expecting it to work.**
>
> This is a 2016-era script for **MDT 2013 Update 2** targeting
> **Windows 7 / 8.1 / 10 (1507-era)** eval media, Packer 0.9.0, WSUS Offline
> 10.6, and DSC module `xPSDesiredStateConfiguration`. Last substantive change
> was **2017-06-03**. Download links are believed dead, the OS targets are
> end-of-life, and the dependency set is obsolete. Kept for reference and as a
> scaffolding example. **There is no revival plan on this branch** — see
> “Modernization path” below if you want to port it.

> 🖥️ **Prerequisites (non-negotiable, enforced by `#Requires`):**
>
> - **Windows only**, elevated shell — **Run as Administrator**.
> - **Windows PowerShell 5.1 only** — not pwsh 6/7 (the script uses a
>   Windows-PS-5.1 DSC `Configuration` block).
> - **MDT 2013 Update 2** installed (or installable) + period-correct ADK/WinPE.
>
> If any of these is not true, stop — the script cannot work for you.

## What it does (when its 2016 dependencies existed)

Single script `MDTAutoInstall.ps1` that:

1. Installs helper DSC/progress modules (`xPSDesiredStateConfiguration`, `PoshProgressBar`).
2. Downloads MDT 2013, IMDisk, Packer 0.9.0, WSUS Offline 10.6, and Win
   7/8.1/10 eval ISOs into a staging folder.
3. Installs MDT 2013 via DSC, mounts each ISO with IMDisk, and imports the
   OS images into a new deployment share (`DS001:`).
4. Writes a starter `CustomSettings.ini`, scaffolds folder structure (Base OS,
   Custom OS, drivers, language packs, patches, task sequences), creates
   “Fully Patch OS” task sequences, and enables the Windows Update steps.
5. Downloads offline updates via WSUS Offline and imports the packages.

## Requirements (original, 2016)

- Windows with Windows PowerShell 5.0+, **elevated (Run as Administrator)**.
- MDT 2013 Update 2 installable on the host; ADK/WinPE of the era.
- Several GB free for ISOs, deployment share, and update content.
- Internet access to the (now mostly dead) sources in `docs/DOWNLOADS.md`.

## Usage

```powershell
# Elevated Windows PowerShell 5.1. Review docs/DOWNLOADS.md FIRST —
# legacy URLs are dead and ExpectedFileHashes must be filled in.
$cred = Get-Credential -Message 'Local admin password for MDT task sequences'

.\MDTAutoInstall.ps1 `
  -ISOPath 'C:\MDT\ISOs' `
  -DeploymentSharePath 'C:\DeploymentShare' `
  -DeploymentShareNetworkPath '\\MYHOST\DeploymentShare$' `
  -RegisteredFullName 'Your Name' `
  -RegisteredOrgName 'Your Org' `
  -RegisteredHomePage 'https://example.com' `
  -TaskSequenceAdminCredential $cred
```

With hash pinning (recommended before any real run):

```powershell
.\MDTAutoInstall.ps1 `
  -ISOPath 'C:\MDT\ISOs' `
  -TaskSequenceAdminCredential $cred `
  -ExpectedFileHashes @{
    'imdiskinst.exe' = '<SHA256>'
  }
```

Parameters:

| Parameter | Default | Notes |
|---|---|---|
| `ISOPath` | `C:\MDT\ISOs` | Staging dir for downloads/DSC output. Created if missing. |
| `DeploymentSharePath` | `C:\DeploymentShare` | Local deployment-share root. No more `C:\My\DSCTesting` default. |
| `DeploymentShareName` | `DeploymentShare$` | SMB share name. |
| `DeploymentShareNetworkPath` | `\\<computername>\DeploymentShare$` | Replaces the old hardcoded `\\NAHOLLLO39872N\…` host. |
| `Servers` | `localhost` | DSC target nodes. |
| `RegisteredFullName` / `RegisteredOrgName` / `RegisteredHomePage` | — | Replaces hardcoded `Tiberriver256` / `http://www.google.com`. |
| `TaskSequenceAdminCredential` (**mandatory**) | — | `PSCredential`; its password becomes the task-sequence local-admin password. **No default, nothing hardcoded.** |
| `ExpectedFileHashes` | `@{}` | `filename -> SHA256` map, verified by `Assert-FileSHA256`. |

## Security notes

- **No embedded passwords.** Earlier revisions hardcoded `-AdminPassword "Imaging123"`;
  that literal is gone. Pass `-TaskSequenceAdminCredential` explicitly and keep
  it out of logs/transcripts.
- `CustomSettings.ini` is written with **empty** `UserID`/`UserPassword` fields —
  fill them in through your own secrets handling, never commit them.
- Downloads: 4 of 8 legacy sources use plain **HTTP** with no verification
  (see `docs/DOWNLOADS.md`). The script now forces **TLS 1.2+** and ships an
  `Assert-FileSHA256` helper — populate `ExpectedFileHashes` before running.
- The script creates an SMB share and runs installers/mounted ISOs with
  elevation. Review every line before executing.

## Known issues / limitations

- Download inventory is stale by ~9 years; expect 404s or dead hosts
  (`ltr-data.se`, `wsusoffline.net`, `care.dlservice.microsoft.com`).
- `xPSDesiredStateConfiguration` is deprecated (successor: `PSDscResources` / PS 7 DSC v3 patterns).
- `PoshProgressBar` favicon fetch is cosmetic; delete it if the Pages URL 404s.
- `Enable-TaskSequenceStep` edits `ts.xml` by group index — fragile across MDT versions.
- No automated test run on Windows exists in this repo; CI covers syntax + lint only.

## Modernization path (not started)

MDT 8456 + current ADK/WinPE, supported Windows 10/11 Eval Center media,
current Packer, `PSDscResources`, Pester tests on a Windows runner, and a
maintained `docs/DOWNLOADS.md` with live HTTPS + hashes.

## CI

`.github/workflows/ci.yml` runs a PowerShell parser syntax check plus
`PSScriptAnalyzer` (rules in `PSScriptAnalyzerSettings.psd1`) on every push/PR.

## License

MIT — see [LICENSE](LICENSE).
