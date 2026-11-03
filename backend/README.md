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
| `META_VERIFY_TOKEN` | A secret phrase you choose and also enter in Meta's webhook setup |
| `META_APP_SECRET` | App Secret from Meta App settings, used to validate webhook requests |
| `META_ACCESS_TOKEN` | Meta access token with WhatsApp messaging permissions |
| `META_PHONE_NUMBER_ID` | Phone Number ID for the WhatsApp Business sender |
| `META_GRAPH_API_VERSION` | Optional Graph API version, defaults to `v23.0` |
| `TWILIO_AUTH_TOKEN` | Optional; required only when using the Twilio webhook |
| `TWILIO_ACCOUNT_SID` | Optional; used for Twilio outbound WhatsApp updates |
| `TWILIO_WHATSAPP_FROM` | Optional; Twilio sender, e.g. `whatsapp:+15551234567` |

Enter secret values directly in Render's environment settings. Do not put them
in `render.yaml`, source code, or Git. The startup command creates any missing
tables and applies the existing resolution and WhatsApp conversation-field
migrations before starting FastAPI. Use a service plan that remains available
for production webhooks; free services can sleep and delay webhook responses.

After deployment, verify the service's `/` endpoint responds. The WhatsApp
webhook URL is
`https://<your-render-service>.onrender.com/webhooks/whatsapp`.
Configure SMTP variables separately if password-reset email delivery is
needed.

## Meta WhatsApp Cloud API setup

Use the webhook URL above as the callback URL in your Meta app's WhatsApp
configuration. Choose a secret phrase for the **Verify token** and set the
same value as `META_VERIFY_TOKEN` in the backend environment. Meta performs
the GET verification request automatically; incoming events use POST. Subscribe
the WhatsApp Business Account webhook to the `messages` field.

Set `META_APP_SECRET`, `META_ACCESS_TOKEN`, and `META_PHONE_NUMBER_ID` in the
backend environment. Find the App Secret in the Meta app's **Settings > Basic**,
and the Phone Number ID and access token in the app's WhatsApp API setup. Keep
all credentials private and configure them in Render's environment settings,
not in source control. Incoming webhook signatures are validated using the App
Secret. The same access token and Phone Number ID are used to send replies and
ticket updates. Linked WhatsApp Reporters receive status notifications when a
ticket is opened, accepted and moved to In Progress, resolved, or reopened.
Notifications refer to the support technician generically and do not reveal
their name. The API version defaults to `v23.0`; set
`META_GRAPH_API_VERSION` if your app uses another supported version.

## Twilio WhatsApp setup

The same webhook URL continues to accept Twilio requests. Configure the
following in the backend `.env` file; never commit the Twilio credentials:

```dotenv
TWILIO_AUTH_TOKEN=your-twilio-auth-token
```

For initial testing, you can use the Twilio WhatsApp Sandbox; production use
requires an approved WhatsApp sender. In the Twilio
Console, configure the sender's **A message comes in** webhook as
`https://<your-domain>/webhooks/whatsapp` with the HTTP method set to `POST`.
The webhook must be publicly reachable over HTTPS. Incoming requests are
authenticated using Twilio's `X-Twilio-Signature`; do not disable signature
validation.
Replies are returned directly as TwiML from the incoming-message webhook, so
the app does not need the Twilio Account SID or sender number configured.
Free-form replies are supported during WhatsApp's 24-hour customer service
window after a Reporter messages the Sandbox.

To send ticket acceptance, status, and technician-note updates to a linked
Reporter, configure `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and
`TWILIO_WHATSAPP_FROM` in the backend environment. The sender must be enabled
for WhatsApp. These outbound messages are attempted after the ticket update is
committed; delivery failures are logged and do not undo the ticket change.
WhatsApp may require an approved message template when messaging outside the
24-hour customer service window.

Create the new WhatsApp tables in the configured database before using the
webhook:

```powershell
python init_db.py
```

To associate a WhatsApp number with an existing Reporter account, an
administrator can link that active, approved Reporter using their phone number
in international E.164 format (including `+`):

```http
PUT /admin/users/{user_id}/whatsapp
Authorization: Bearer <administrator-access-token>
Content-Type: application/json

{"phone_number": "+15551234567"}
```

The corresponding unlink endpoint is
`DELETE /admin/users/{user_id}/whatsapp`. Both endpoints require an
Administrator access token.

WhatsApp ticket creation collects a separate title, full issue description,
optional device, category, impact, and urgency. Location remains blank for
WhatsApp tickets. The sender's WhatsApp number identifies the Reporter; an unlinked
number gets a guest Reporter record, while an administrator can link a number
to an existing Reporter account using the endpoint above. The ticket is saved
to the same database as app-created tickets, appears as an unassigned Open
ticket for technicians to accept, and its details expose the requester's name
and WhatsApp number to technicians and administrators.

Send `CANCEL` to stop an in-progress ticket conversation. Duplicate webhook
deliveries from either provider are handled idempotently.

The Administrator dashboard checks the WhatsApp ticket notification feed
every 30 seconds and displays newly created WhatsApp tickets in its in-app
notifications and ticket list. Reporter and Technician dashboards also check
ticket history notifications every 30 seconds, including tickets created via
WhatsApp and technician updates. These are in-app notifications, not mobile
push or email alerts.
