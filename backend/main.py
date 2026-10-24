
from fastapi import FastAPI

from admin import router as admin_router

from auth import router as auth_router
from tickets import router as tickets_router
from whatsapp import router as whatsapp_router
from fastapi.responses import HTMLResponse
from fastapi import Request
from fastapi.middleware.cors import CORSMiddleware




app = FastAPI(
    title="TriageDesk API",
    description="Backend API for the TriageDesk IT Support Ticketing System",
    version="1.0.0",
)

app.add_middleware(
  CORSMiddleware,
  allow_origins=[
    "http://localhost:61209",
    "http://127.0.0.1:61209",
  ],
  allow_credentials=True,
  allow_methods=["*"],
  allow_headers=["*"],
)
@app.get("/reset-password", response_class=HTMLResponse)
def reset_password_page():
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Reset Password | TriageDesk</title>
      <style>
        body {
          margin: 0;
          padding: 24px;
          min-height: 100vh;
          box-sizing: border-box;
          display: flex;
          align-items: center;
          justify-content: center;
          background: #fffdf5;
          font-family: Arial, sans-serif;
          color: #3d0a11;
        }
        .card {
          width: 100%;
          max-width: 420px;
          box-sizing: border-box;
          padding: 32px;
          background: white;
          border-radius: 18px;
          box-shadow: 0 8px 30px rgba(128, 0, 32, 0.12);
        }
        h1 { color: #800020; margin-top: 0; }
        p { color: #80545b; line-height: 1.5; }
        label { display: block; margin-top: 18px; font-weight: bold; }
        input {
          width: 100%;
          box-sizing: border-box;
          padding: 13px;
          margin-top: 8px;
          border: 1px solid #f1d4d7;
          border-radius: 9px;
          font-size: 15px;
        }
        input:focus {
          outline: 2px solid #800020;
          outline-offset: 1px;
        }
        button {
          width: 100%;
          padding: 14px;
          margin-top: 24px;
          background: #800020;
          color: white;
          border: 0;
          border-radius: 9px;
          font-size: 16px;
          font-weight: bold;
          cursor: pointer;
        }
        button:hover:not(:disabled) { background: #a52a2a; }
        button:disabled { opacity: 0.6; cursor: wait; }
        #message { margin-top: 18px; overflow-wrap: anywhere; }
      </style>
    </head>
    <body>
      <main class="card">
        <h1>Reset your password</h1>
        <p>Choose a new password for your TriageDesk account.</p>

        <form id="resetForm">
          <label for="password">New password</label>
          <input id="password" type="password" minlength="12"
                 maxlength="128" required autocomplete="new-password"
                 placeholder="At least 12 characters">

          <label for="confirmPassword">Confirm new password</label>
          <input id="confirmPassword" type="password" minlength="12"
                 maxlength="128" required autocomplete="new-password"
                 placeholder="Enter the password again">

          <button id="submitButton" type="submit">Save New Password</button>
        </form>

        <p id="message" role="status"></p>
      </main>

<script>
  const form = document.getElementById('resetForm');
  const message = document.getElementById('message');
  const button = document.getElementById('submitButton');
  const token = new URLSearchParams(window.location.search).get('token');

  if (!token) {
    form.hidden = true;
    message.textContent =
      'This reset link is missing its token. Request a new reset email.';
  }

  form.addEventListener('submit', async (event) => {
    event.preventDefault();

    const password = document.getElementById('password').value;
    const confirmation =
      document.getElementById('confirmPassword').value;

    if (!token) {
      message.textContent =
        'This reset link is missing its token. Request a new reset email.';
      return;
    }

    if (password.length < 12) {
      message.textContent =
        'Your password must contain at least 12 characters.';
      return;
    }

    if (password !== confirmation) {
      message.textContent = 'The passwords do not match.';
      return;
    }

    button.disabled = true;
    button.textContent = 'Saving...';
    message.textContent = 'Saving your new password...';

    try {
      const response = await fetch('/auth/reset-password', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          token: token,
          new_password: password
        })
      });

      const rawBody = await response.text();
      let result = {};

      try {
        result = JSON.parse(rawBody);
      } catch {
        result = { detail: rawBody };
      }

      if (!response.ok) {
        const errorMessage =
          typeof result.detail === 'string'
            ? result.detail
            : Array.isArray(result.detail)
              ? result.detail.map(item =>
                  `${item.loc ? item.loc.join('.') : 'Request'}: ${item.msg || 'Invalid value'}`
                ).join('; ')
              : 'Unable to reset the password. Please try again.';

        throw new Error(errorMessage);
      }

      form.hidden = true;
      message.textContent =
        typeof result.message === 'string'
          ? result.message
          : 'Password reset successfully! You can now sign in to TriageDesk.';

      const loginButton = document.createElement('button');
      loginButton.type = 'button';
      loginButton.textContent = 'Return to Login';
      loginButton.addEventListener('click', () => {
        window.location.href = '/';
      });

      form.parentNode.insertBefore(loginButton, message);

    } catch (error) {
      message.textContent =
        error.message || 'Could not connect to TriageDesk. Please try again.';
      button.disabled = false;
      button.textContent = 'Save New Password';
    }
  });
</script>

    </body>
    </html>
    """

app.include_router(auth_router)
app.include_router(tickets_router)
app.include_router(admin_router)
app.include_router(whatsapp_router)


@app.get("/")
def root():
    return {
        "application": "TriageDesk",
        "message": "Backend is running",
    }


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "TriageDesk API",
    }
