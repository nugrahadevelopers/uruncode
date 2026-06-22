# uruncode

Jalankan Claude Code atau Codex CLI melalui gateway UrunAI dengan satu kali pengaturan API key lokal.

**English guide:** [README.md](README.md)

`uruncode` membantu Anda menyimpan UrunAI API key di komputer sendiri, menyiapkan environment/konfigurasi yang dibutuhkan oleh CLI yang dipilih, lalu membuka `claude` atau `codex` untuk Anda.

> Persyaratan
>
> Install CLI yang ingin Anda gunakan sebelum menjalankan `uruncode`:
>
> - Claude Code: https://docs.claude.com/en/docs/claude-code
> - Codex CLI: https://developers.openai.com/codex

## Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/nugrahadevelopers/uruncode/main/install.sh | bash
```

Perintah ini meng-install `uruncode` ke `~/.local/bin`. Jika folder tersebut belum ada di `PATH`, installer akan menampilkan baris yang perlu Anda tambahkan.

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/nugrahadevelopers/uruncode/main/install.ps1 | iex
```

Perintah ini meng-install `uruncode` ke `%LOCALAPPDATA%\Programs\uruncode` dan menambahkannya ke user `PATH`. Setelah install selesai, buka terminal baru agar `PATH` terbaru terbaca.

## Mulai Cepat

Jalankan `uruncode`:

```bash
uruncode
```

Pada penggunaan pertama, `uruncode` akan meminta UrunAI API key dan menyimpannya secara lokal. Setelah itu, pilih tool yang ingin dibuka:

```text
1) Claude Code
2) Codex CLI
```

Anda juga bisa langsung membuka tool tertentu:

```bash
uruncode claude .
uruncode codex .
```

Catatan:

- `uruncode claude .` membuka Claude Code di direktori saat ini.
- `uruncode codex .` membuka Codex CLI di direktori saat ini menggunakan profil `uruncode`.
- Untuk Codex, jika argumen pertama setelah `codex` adalah direktori, `uruncode` akan menjalankan Codex dengan format `codex --profile uruncode --cd <direktori>`.

## Perintah yang Sering Digunakan

| Perintah | Fungsi |
| --- | --- |
| `uruncode` | Membuka menu interaktif untuk memilih Claude Code atau Codex CLI. |
| `uruncode claude [ARGS...]` | Menjalankan Claude Code melalui UrunAI. |
| `uruncode codex [ARGS...]` | Menjalankan Codex CLI melalui UrunAI. |
| `uruncode config` | Memasukkan dan menyimpan UrunAI API key secara interaktif. |
| `uruncode config <KEY>` | Menyimpan atau mengganti UrunAI API key secara langsung. |
| `uruncode change-key` | Mengganti UrunAI API key yang tersimpan. |
| `uruncode reset` | Mengembalikan backup konfigurasi CLI dan menghapus API key tersimpan. |
| `uruncode update` | Menjalankan ulang installer untuk memperbarui `uruncode`. |
| `uruncode uninstall` | Khusus Windows: menghapus `uruncode`, data tersimpan, dan entri PATH. |

`set-key`, `change`, dan `change-key` adalah alias untuk perilaku pengaturan/penggantian API key.

## API Key

`uruncode` mencari API key dengan urutan berikut:

1. Key yang diberikan melalui `uruncode config <KEY>` atau `uruncode change-key <KEY>`.
2. File konfigurasi yang sudah tersimpan dari penggunaan sebelumnya.
3. `URUNAI_API_KEY` dari environment. Jika ditemukan, key ini akan disimpan untuk penggunaan berikutnya.
4. Prompt interaktif.

Lokasi penyimpanan key:

| Platform | Lokasi |
| --- | --- |
| macOS/Linux | `~/.config/uruncode/config` |
| Windows | `%APPDATA%\uruncode\config` |

API key disimpan dalam bentuk plaintext di komputer Anda dengan izin khusus user jika platform mendukungnya. Perlakukan file ini seperti kredensial lokal lainnya.

## Backup Konfigurasi dan Reset

Sebelum `uruncode` mengubah konfigurasi Claude Code atau Codex CLI, file asli akan disimpan sebagai backup di direktori konfigurasi lokal `uruncode`. Backup dibuat satu kali dan tidak ditimpa oleh penggunaan berikutnya.

File yang di-backup:

- Claude Code: `~/.claude/settings.json`
- Codex CLI: `$CODEX_HOME/config.toml` atau `~/.codex/config.toml`
- Profil `uruncode` untuk Codex CLI: `$CODEX_HOME/uruncode.config.toml` atau `~/.codex/uruncode.config.toml`

Untuk mengembalikan backup dan menghapus UrunAI API key yang tersimpan, jalankan:

```bash
uruncode reset
```

Jika sebuah file belum ada sebelum dibuat oleh `uruncode`, perintah `reset` akan menghapus file tersebut, bukan mengembalikan backup.

## Konfigurasi yang Diatur

Nilai default:

```sh
URUNAI_BASE_URL="https://api.urunai.my.id/v1"
URUNAI_CLAUDE_MODEL="aim-cdx-mini"
URUNAI_CLAUDE_AUTH_MODE="bearer"
URUNAI_CODEX_MODEL="gpt-5.4-mini"
```

### Claude Code

Secara default, Claude Code dijalankan dengan autentikasi gateway/bearer-token:

```sh
ANTHROPIC_BASE_URL="$URUNAI_BASE_URL"
ANTHROPIC_AUTH_TOKEN="<UrunAI API key Anda>"
ANTHROPIC_MODEL="$URUNAI_CLAUDE_MODEL"
claude --model "$URUNAI_CLAUDE_MODEL" "$@"
```

Gunakan `URUNAI_CLAUDE_AUTH_MODE=api-key` hanya jika gateway Anda membutuhkan autentikasi Anthropic-style `x-api-key`. Pada mode tersebut, `uruncode` memakai `ANTHROPIC_API_KEY`, bukan `ANTHROPIC_AUTH_TOKEN`.

`uruncode` juga menghapus variabel autentikasi Claude yang tidak aktif dari environment/settings saat launch, sehingga Claude Code tidak mencampur autentikasi API key dan bearer token.

Jika Anda memberikan argumen `--model` sendiri, `uruncode` akan menghormatinya dan tidak menambahkan argumen model lain.

### Codex CLI

Saat menjalankan Codex, `uruncode` membuat atau memperbarui `$CODEX_HOME/uruncode.config.toml` atau `~/.codex/uruncode.config.toml`:

```toml
model = "gpt-5.4-mini"
model_provider = "urunai"

[model_providers.urunai]
name = "UrunAI"
base_url = "https://api.urunai.my.id/v1"
wire_api = "responses"
env_key = "URUNAI_API_KEY"
```

Lalu menjalankan:

```bash
codex --profile uruncode --cd .
```

## Update

```bash
uruncode update
```

Di Windows, jika launch Claude masih menampilkan error `[eval]` / `node -e`, kemungkinan `uruncode.ps1` yang ter-install masih versi lama. Jalankan ulang installer untuk menggantinya:

```powershell
irm https://raw.githubusercontent.com/nugrahadevelopers/uruncode/main/install.ps1 | iex
```

Jika perlu memakai URL installer lain, gunakan override berikut:

```bash
URUNCODE_INSTALL_URL=https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh uruncode update
```

## Uninstall

Sebelum menghapus file `uruncode`, sebaiknya kembalikan backup konfigurasi CLI dan hapus UrunAI API key yang tersimpan.

### macOS / Linux

```bash
uruncode reset
rm ~/.local/bin/uruncode
rm -rf ~/.config/uruncode
rm -f ~/.codex/uruncode.config.toml
```

### Windows (PowerShell)

```powershell
uruncode uninstall
```

Satu perintah ini akan mengembalikan/menghapus konfigurasi CLI yang dikelola `uruncode`, menghapus UrunAI API key tersimpan, menghapus direktori install, dan menghapus direktori install dari user `PATH`. Buka terminal baru sebelum install ulang.

Jika `uruncode uninstall` menampilkan `Unknown launcher: uninstall`, berarti `uruncode.ps1` yang ter-install masih versi lama dan belum memiliki perintah uninstall. Refresh installer lalu uninstall dengan satu baris PowerShell berikut:

```powershell
irm https://raw.githubusercontent.com/nugrahadevelopers/uruncode/main/install.ps1 | iex; uruncode uninstall
```

Jika Anda sudah mengikuti instruksi uninstall lama dan menghapus `%APPDATA%\uruncode` terlebih dahulu, hapus secara manual hanya key berikut dari `%USERPROFILE%\.claude\settings.json`:

- `env.ANTHROPIC_BASE_URL`
- `env.ANTHROPIC_MODEL`
- `env.ANTHROPIC_API_KEY`
- `env.ANTHROPIC_AUTH_TOKEN`

Jangan menghapus seluruh file Claude settings kecuali Anda yakin file tersebut tidak berisi pengaturan lain.

## Troubleshooting

### `claude CLI not found on PATH`

Install Claude Code terlebih dahulu, buka terminal baru, lalu jalankan lagi:

```bash
uruncode claude .
```

### `codex CLI not found on PATH`

Install Codex CLI terlebih dahulu, buka terminal baru, lalu jalankan lagi:

```bash
uruncode codex .
```

### API key yang tersimpan salah

Gunakan salah satu perintah berikut:

```bash
uruncode change-key
uruncode change-key <KEY_BARU>
```

### Ingin mengembalikan konfigurasi Claude/Codex seperti semula

Jalankan:

```bash
uruncode reset
```

Perintah ini mengembalikan backup yang dibuat sebelum `uruncode` mengubah konfigurasi CLI.
