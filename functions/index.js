const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Helper to safely get a count using aggregation when supported, fallback to get().size
async function getCount(collectionRef, query) {
  try {
    // Try aggregation count() API
    const aggQuery = query ? query.count() : collectionRef.count();
    const aggSnap = await aggQuery.get();
    // For aggregation snapshot, count is available via data().count
    if (aggSnap && typeof aggSnap.data === 'function' && aggSnap.data() && aggSnap.data().count !== undefined) {
      return aggSnap.data().count;
    }
  } catch (e) {
    // ignore and fallback
  }

  // Fallback: run a regular query and return size
  try {
    const snap = query ? await query.get() : await collectionRef.get();
    return snap.size;
  } catch (e) {
    console.error('count fallback error', e);
    return 0;
  }
}

// Scheduled function: computes analytics summary and writes to analytics/summary
exports.scheduledAnalytics = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    console.log('Running scheduled analytics aggregation...');
    try {
      const now = admin.firestore.Timestamp.now();

      // total users
      const totalUsers = await getCount(db.collection('users'));

      // DAU: users with lastActive within last 24 hours
      const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const dauQuery = db.collection('users').where('lastActive', '>=', admin.firestore.Timestamp.fromDate(cutoff));
      const dau = await getCount(null, dauQuery);

      // messagesByDay for last 7 days
      const messagesByDay = {};
      for (let i = 6; i >= 0; i--) {
        const d = new Date();
        d.setHours(0, 0, 0, 0);
        d.setDate(d.getDate() - i);
        const start = admin.firestore.Timestamp.fromDate(d);
        const end = admin.firestore.Timestamp.fromDate(new Date(d.getTime() + 24 * 60 * 60 * 1000));
        const q = db.collection('messages').where('timestamp', '>=', start).where('timestamp', '<', end);
        const key = `${d.getMonth() + 1}/${d.getDate()}`;
        messagesByDay[key] = await getCount(null, q);
      }

      // moderation stats
      const totalReports = await getCount(db.collection('reports'));
      const resolvedReports = await getCount(db.collection('reports').where('resolved', '==', true));
      const bans = await getCount(db.collection('bans'));

      const summary = {
        totalUsers: totalUsers,
        dau: dau,
        messagesByDay: messagesByDay,
        moderation: {
          totalReports: totalReports,
          resolvedReports: resolvedReports,
          bans: bans,
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db.doc('analytics/summary').set(summary, { merge: true });

      console.log('analytics summary updated');
      return null;
    } catch (err) {
      console.error('Error computing analytics summary', err);
      return null;
    }
  });
