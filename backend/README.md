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
| `WHATSAPP_VERIFY_TOKEN` | A new, private webhook verification token |
| `WHATSAPP_APP_SECRET` | The rotated Meta app secret |
| `WHATSAPP_ACCESS_TOKEN` | The rotated WhatsApp Cloud API access token |
| `WHATSAPP_PHONE_NUMBER_ID` | The WhatsApp Business phone-number ID |
| `WHATSAPP_GRAPH_API_VERSION` | A Graph API version supported by the Meta app |

Enter secret values directly in Render's environment settings. Do not put them
in `render.yaml`, source code, or Git. The startup command creates any missing tables and applies the existing
resolution-column migration before starting FastAPI. Use a service plan that
remains available for production webhooks; free services can sleep and delay
webhook responses.

After deployment, verify the service's `/` endpoint responds. Use
`https://<your-render-service>.onrender.com/webhooks/whatsapp` as the Meta
callback URL, enter the same `WHATSAPP_VERIFY_TOKEN` in Meta, and subscribe to
the `messages` field. Configure SMTP variables separately if password-reset
email delivery is needed.

## WhatsApp Cloud API setup

The WhatsApp webhook is available at `/webhooks/whatsapp`. Configure the
following in the backend `.env` file; never commit the access token, app
secret, or verify token:

```dotenv
WHATSAPP_VERIFY_TOKEN=choose-a-long-random-value
WHATSAPP_APP_SECRET=your-meta-app-secret
WHATSAPP_ACCESS_TOKEN=your-whatsapp-cloud-api-access-token
WHATSAPP_PHONE_NUMBER_ID=your-whatsapp-phone-number-id
WHATSAPP_GRAPH_API_VERSION=v23.0
```

Set `WHATSAPP_GRAPH_API_VERSION` to a Graph API version currently supported by
your Meta app. The webhook must be publicly reachable over HTTPS for Meta to
deliver messages. In the Meta webhook configuration, use
`https://<your-domain>/webhooks/whatsapp` and the same verify token as
`WHATSAPP_VERIFY_TOKEN`, then subscribe to the `messages` field.

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
Meta webhook deliveries are handled idempotently.

The API verifies webhook signatures using `WHATSAPP_APP_SECRET`; do not disable
signature verification. The current milestone sends ticket conversation
replies to the Reporter. Technician notifications and technician status
updates through WhatsApp are not part of this milestone.
