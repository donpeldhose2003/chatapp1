This folder contains a Cloud Function that computes analytics summary for the Flutter app.

Files:
- index.js: scheduled Cloud Function that aggregates Firestore counts and writes to `analytics/summary`.
- package.json: function dependencies.

Deploy instructions:
1. Install Firebase CLI and login: `npm install -g firebase-tools` then `firebase login`.
2. From this repo, initialize functions if you haven't: `firebase init functions` (choose existing project).
3. Change directory to the functions folder and install dependencies:
   ```bash
   cd functions
   npm install
   ```
4. Deploy the scheduled function (Cloud Scheduler requires Blaze billing plan for schedules):
   ```bash
   firebase deploy --only functions:scheduledAnalytics
   ```

Notes:
- The function writes summary data to `analytics/summary` with an `updatedAt` server timestamp. The mobile app reads that doc first for instant dashboard loads.
- If you prefer a manual trigger for testing, you can call the function locally with `firebase functions:shell` or temporarily expose an HTTP function wrapper.
