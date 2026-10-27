# TriageDesk backend

## Run the API

From this directory, activate the virtual environment and start FastAPI:

```powershell
.\.venv\Scripts\Activate.ps1
python -m uvicorn main:app --reload
```

## Migrate the current database to Render

Create a Render PostgreSQL database in the intended API region and choose the
same PostgreSQL major version as the current database or newer. In the
database's Connect page, allow your current IP if Render requires an IP
allow-list entry, and copy the **External Database URL**. Do not share that URL.

From PowerShell, run the migration utility from the backend directory:

```powershell
.\.venv\Scripts\Activate.ps1
python migrate_to_render.py
```

Paste the External Database URL at the hidden prompt. The script checks that
the destination is empty, shows the PostgreSQL versions and source row counts,
and requires typing `MIGRATE` before copying. It uses `pg_dump` and
`pg_restore` without putting passwords in command arguments, creates a
temporary local dump that is removed afterward, creates the WhatsApp tables,
applies the existing resolution-column migration, and compares source and
destination table row counts. It never modifies the source database.

Do not continue if the script reports an error or a row-count mismatch.

## Deploy the API to Render

Use the PostgreSQL database that was populated by `migrate_to_render.py`; do
not create a replacement database. Keep the API service in the same region as
that database. In Render, create a Python web service connected to this
repository's `main` branch. Set the web service's **Root Directory** to
`backend`, then use:

```text
Build command: pip install -r requirements.txt
Start command: python init_db.py && python migrate_resolution.py && uvicorn main:app --host 0.0.0.0 --port $PORT
```

Add these environment variables to the web service in the Render dashboard:

| Name | Value |
| --- | --- |
| `PYTHON_VERSION` | `3.13.14` (the Python version used to validate this backend) |
| `DATABASE_URL` | Internal connection string from the migrated Render PostgreSQL database |
| `JWT_SECRET_KEY` | A new, randomly generated secret |
| `TWILIO_ACCOUNT_SID` | Twilio Account SID |
| `TWILIO_AUTH_TOKEN` | Twilio Auth Token |
| `TWILIO_WHATSAPP_FROM` | Your Twilio WhatsApp sender, in `whatsapp:+<E.164 number>` format |

Enter secret values directly in Render's environment settings. Do not put them
in `render.yaml`, source code, or Git. The startup command creates any missing tables and applies the existing
resolution-column migration before starting FastAPI. Use a service plan that
remains available for production webhooks; free services can sleep and delay
webhook responses.

After deployment, verify the service's `/` endpoint responds. Configure the
Twilio WhatsApp sender's incoming-message webhook to
`https://<your-render-service>.onrender.com/webhooks/whatsapp` using `POST`.
Configure SMTP variables separately if password-reset email delivery is
needed.

## Twilio WhatsApp setup

The WhatsApp webhook is available at `/webhooks/whatsapp`. Configure the
following in the backend `.env` file; never commit the Twilio credentials:

```dotenv
TWILIO_ACCOUNT_SID=your-twilio-account-sid
TWILIO_AUTH_TOKEN=your-twilio-auth-token
TWILIO_WHATSAPP_FROM=whatsapp:+14155238886
```

Use your actual Twilio WhatsApp sender in place of the example above. For
initial testing, you can use the Twilio WhatsApp Sandbox and its sender
number; production use requires an approved WhatsApp sender. In the Twilio
Console, configure the sender's **A message comes in** webhook as
`https://<your-domain>/webhooks/whatsapp` with the HTTP method set to `POST`.
The webhook must be publicly reachable over HTTPS. Incoming requests are
authenticated using Twilio's `X-Twilio-Signature`; do not disable signature
validation.

Create the new WhatsApp tables in the configured database before using the
webhook:

```powershell
python init_db.py
```

An administrator must link an active, approved Reporter to their WhatsApp
number in international E.164 format (including `+`) before messages from that
number can create tickets:

```http
PUT /admin/users/{user_id}/whatsapp
Authorization: Bearer <administrator-access-token>
Content-Type: application/json

{"phone_number": "+15551234567"}
```

The corresponding unlink endpoint is
`DELETE /admin/users/{user_id}/whatsapp`. Both endpoints require an
Administrator access token.

Reporters can send a text message describing their issue. TriageDesk then
collects category, impact, and urgency in the WhatsApp conversation, creates
the ticket in the existing database, and replies with its ticket number and
priority. Send `CANCEL` to stop an in-progress ticket conversation. Duplicate
Twilio webhook deliveries are handled idempotently.

The current milestone sends ticket conversation replies to the Reporter.
Technician notifications and technician status updates through WhatsApp are
not part of this milestone.
