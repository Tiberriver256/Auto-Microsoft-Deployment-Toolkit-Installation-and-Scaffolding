# Download inventory (legacy-2016) — MDTAutoInstall.ps1

> **Status: LEGACY. Most URLs below are 2016-era and are believed dead or
> redirected.** Do not run this script expecting downloads to succeed.
> Before any reuse, replace every entry with a current HTTPS source and fill
> in the SHA256 in `ExpectedFileHashes`. See `README.md`.

| # | File (DestinationPath) | 2016 URI in script | Scheme | Expected SHA256 | Status / note |
|---|------------------------|--------------------|--------|-----------------|---------------|
| 1 | `favicon.ico` | `https://raw.githubusercontent.com/Tiberriver256/Tiberriver256.GitHub.io/master/favicon.ico` | HTTPS | _fill in_ | Cosmetic progress-bar icon. Personal Pages host; may 404. Safe to delete. |
| 2 | `imdiskinst.exe` | `http://www.ltr-data.se/files/imdiskinst.exe` | **HTTP — insecure** | _fill in_ | Legacy vendor host (LTR Data). Assume dead. Needs HTTPS mirror + hash. |
| 3 | `MicrosoftDeploymentToolkit2013_x64.msi` | `https://download.microsoft.com/download/3/0/1/3012B93D-C445-44A9-8BFB-F28EB937B060/MicrosoftDeploymentToolkit2013_x64.msi` | HTTPS | _fill in_ | MDT 2013 Update 2. Microsoft Download Center links from 2016 rot frequently. Modern path: MDT 8456 + matching ADK. |
| 4 | `packer_0.9.0_windows_amd64.zip` | `https://releases.hashicorp.com/packer/0.9.0/packer_0.9.0_windows_amd64.zip` | HTTPS | _fill in_ | Packer 0.9.0 (2016). releases.hashicorp.com keeps old versions, but 0.9.0 is EOL. Use a current Packer release. |
| 5 | `wsusoffline106.zip` | `http://download.wsusoffline.net/wsusoffline106.zip` | **HTTP — insecure** | _fill in_ | WSUS Offline 10.6. Legacy domain; assume dead. Whole WSUS-offline flow is obsolete for supported Windows. |
| 6 | `Win7EnterpriseTrialx64.iso` | `http://care.dlservice.microsoft.com/dl/download/evalx/win7/x64/EN/7600.16385.090713-1255_x64fre_enterprise_en-us_EVAL_Eval_Enterprise-GRMCENXEVAL_EN_DVD.iso` | **HTTP — insecure** | _fill in_ | Windows 7 eval (build 7600). EOL; eval links long dead. |
| 7 | `Win81EnterpriseTrialx64.iso` | `http://care.dlservice.microsoft.com/dl/download/5/3/C/53C31ED0-886C-4F81-9A38-F58CE4CE71E8/9200.16384.WIN8_RTM.120725-1247_X64FRE_ENTERPRISE_EVAL_EN-US-HRM_CENA_X64FREE_EN-US_DV5.ISO` | **HTTP — insecure** | _fill in_ | Windows 8.1 eval (build 9200). EOL; eval links long dead. Updated 2017-06-03 for Issue #1; still legacy. |
| 8 | `Win10EnterpriseTrialx64.iso` | `http://care.dlservice.microsoft.com/dl/download/C/3/9/C399EEA8-135D-4207-92C9-6AAB3259F6EF/10240.16384.150709-1700.TH1_CLIENTENTERPRISEEVAL_OEMRET_X64FRE_EN-US.ISO` | **HTTP — insecure** | _fill in_ | Windows 10 1507 eval (build 10240). Superseded many times over. Use current Eval Center media. |

## Rules for any reuse

1. **HTTPS only.** Never reintroduce `http://` download URIs. The script
   forces TLS 1.2+ via `[Net.ServicePointManager]::SecurityProtocol`.
2. **Hash every binary.** Add `filename -> SHA256` entries to the
   script's `ExpectedFileHashes` parameter and verify with the bundled
   `Assert-FileSHA256` helper before executing or mounting anything.
3. **One entry per file.** If you swap a source (e.g., MDT 2013 -> MDT 8456),
   update this table in the same change.
