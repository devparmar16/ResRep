# Google OAuth Setup Guide

To fix the `Unsupported provider: provider is not enabled` error, you must enable Google Sign-In in your Supabase project. This requires creating a project in Google Cloud Console to get a **Client ID** and **Client Secret**.

## Step 1: Get Redirect URL from Supabase

1.  Go to your **Supabase Dashboard**.
2.  Navigate to **Authentication** -> **Providers**.
3.  Click on **Google** (do not enable it yet).
4.  Copy the **Callback URL** (it looks like `https://<project-ref>.supabase.co/auth/v1/callback`). You will need this in Step 3.

## Step 2: Configure Google Cloud Console

1.  Go to [Google Cloud Console](https://console.cloud.google.com/).
2.  Create a **New Project** (e.g., "ScholarLens Auth").
3.  Select the project.

### Configure Consent Screen
1.  Go to **APIs & Services** -> **OAuth consent screen**.
2.  Select **External** and click **Create**.
3.  Fill in required fields:
    *   **App Name**: ScholarLens
    *   **User Support Email**: Your email
    *   **Developer Contact Email**: Your email
4.  Click **Save and Continue** (skip Scopes and Test Users for now).
5.  Click **Back to Dashboard**.

## Step 3: Create Credentials (Client ID & Secret)

1.  Go to **APIs & Services** -> **Credentials**.
2.  Click **+ CREATE CREDENTIALS** -> **OAuth client ID**.
3.  **Application Type**: Select **Web application**.
4.  **Name**: "Supabase Auth" (or similar).
5.  **Authorized JavaScript origins**:
    *   Add `https://<your-project-ref>.supabase.co` (the base URL of your Callback URL from Step 1).
    *   *Note: For local development, also add `http://localhost:3000` or the port your flutter web app runs on if needed, but usually just the Supabase one is key for the callback.*
6.  **Authorized redirect URIs**:
    *   **IMPORTANT:** Paste the **Callback URL** you copied from Supabase in Step 1.
    *   Also add `http://localhost:3000/auth/v1/callback` if testing locally with Supabase CLI (optional).
7.  Click **Create**.

## Step 4: Configure Supabase

1.  A popup will show your **Client ID** and **Client Secret**.
2.  Go back to **Supabase Dashboard** -> **Authentication** -> **Providers** -> **Google**.
3.  **Paste** the Client ID into "Client ID".
4.  **Paste** the Client Secret into "Client Secret".
5.  Toggle **Enable Sign in with Google** to **ON**.
6.  Click **Save**.

## Step 5: Verify

1.  Restart your Flutter app (`R`).
2.  Click "Continue with Google".
3.  It should now open the Google Sign-In window!
