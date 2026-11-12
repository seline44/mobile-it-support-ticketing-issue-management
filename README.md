# TriageDesk

TriageDesk is a Flutter app with a FastAPI backend and PostgreSQL database.
These steps run the backend locally and connect Flutter from Chrome, an Android
emulator, or a physical Android device.

By default, the Flutter app connects to the deployed Render API at
`https://mobile-it-support-ticketing-issue.onrender.com`. This lets the
emulator, browser, and physical devices see the same tickets and accounts.

## Requirements

- Flutter SDK and Chrome (for the web app)
- Python 3.13 and PostgreSQL
- Android Studio with an Android emulator (for Android testing)

## 1. Configure and start the backend

Open PowerShell in the repository root, then prepare the backend environment:

```powershell
cd backend
py -3.13 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

If `backend\.env` does not already exist, copy the example and edit it with
your local PostgreSQL credentials:

```powershell
Copy-Item .env.example .env
notepad .env
```

Set `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD` for your
PostgreSQL instance. Set `JWT_SECRET_KEY` to a new random value; generate one
with:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Keep `.env` private and do not replace an existing `.env` without saving its
values. From the `backend` directory, initialize/update the database and create
the initial users:

```powershell
python init_db.py
python migrate_resolution.py
python migrate_reset_tokens.py
python create_users.py
```

`create_users.py` prompts for passwords; use at least 12 characters. It creates
an approved Administrator and Reporter/Technician accounts that require
approval. Start the API in this same PowerShell window:

```powershell
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Keep it running. Verify the API in another PowerShell window:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

The interactive API documentation is at `http://127.0.0.1:8000/docs`.

## 2. Run Flutter in Chrome

Open a second PowerShell window in the repository root:

```powershell
flutter pub get
flutter run -d chrome --web-port 61209 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

The backend permits Chrome's local Flutter development origin, including
different local ports.

## 3. Run on Android

Start an emulator in Android Studio, or connect a phone with USB debugging
enabled. In PowerShell at the repository root, list available device IDs:

```powershell
flutter devices
```

For the Android emulator, use its special host address to reach the backend on
your computer:

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Replace `emulator-5554` if `flutter devices` shows a different emulator ID.
For a physical Android phone, connect the phone and computer to the same
network, find the computer's IPv4 address with `ipconfig`, and use that address
instead:

```powershell
$deviceId = "YOUR_DEVICE_ID"
flutter run -d $deviceId --dart-define=API_BASE_URL=http://192.168.1.25:8000
```

Set `$deviceId` to the phone's ID from `flutter devices` and replace
`192.168.1.25` with your computer's actual LAN IPv4 address. If the phone
cannot connect, allow inbound TCP port 8000 on the computer's private network
in Windows Firewall. The development server must remain running.

## Sign-in and account approval

Sign in with the Administrator email/password created by `create_users.py`.
Register Reporter and Technician accounts in the app; they cannot sign in
until approved by an Administrator in the app. Public registration does not
allow creating Administrator accounts. If an initial Administrator was
previously created by the seed script but left Pending, running the updated
`create_users.py` approves that Pending seed administrator.

Administrators can export ticket reports as PDF, Word (`.docx`), or Excel
(`.xlsx`) from the Reports tab.

The commands above explicitly override the default API URL to use your local
development backend. For a deployed app or devices on an untrusted network,
use an HTTPS API URL. iOS builds require macOS and Xcode; a physical iOS device
also needs an HTTPS-accessible API for normal secure networking.
