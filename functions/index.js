// Cloud Functions — Attendance Notification Trigger
//
// Deploy this as a Firebase Cloud Function. It watches the
// `notifications` collection and sends emails via SendGrid
// when a new notification record with status 'pending' is created.
//
// Setup:
// 1. cd functions && npm install
// 2. Set SendGrid API key: firebase functions:config:set sendgrid.key="SG.xxx"
// 3. Deploy: firebase deploy --only functions

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const sgMail = require("@sendgrid/mail");

admin.initializeApp();

// Initialize SendGrid
sgMail.setApiKey(functions.config().sendgrid.key);

/**
 * Trigger: when a new notification document is created with status 'pending'.
 * Sends email to all recipients, then marks the notification as 'sent'.
 */
exports.sendAttendanceNotification = functions.firestore
    .document("notifications/{notificationId}")
    .onCreate(async (snap, context) => {
      const notification = snap.data();

      if (notification.status !== "pending") return null;

      const recipients = notification.recipients || [];
      if (recipients.length === 0) return null;

      const msg = {
        to: recipients,
        from: "attendance@yourcollege.edu.in", // Change to your verified sender
        subject: notification.subject || "Attendance Update",
        text: notification.body || "No details available.",
        html: `<pre>${notification.body || "No details available."}</pre>`,
      };

      try {
        await sgMail.send(msg);

        // Mark as sent
        await snap.ref.update({
          status: "sent",
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`Notification ${context.params.notificationId} sent to ${recipients.join(", ")}`);
      } catch (error) {
        console.error("SendGrid error:", error);

        await snap.ref.update({
          status: "failed",
          error: error.message,
        });
      }

      return null;
    });

/**
 * Scheduled function: auto-expire sessions that have passed their endTime.
 * Runs every minute.
 */
exports.expireSessions = functions.pubsub
    .schedule("every 1 minutes")
    .onRun(async () => {
      const now = admin.firestore.Timestamp.now();
      const sessionsRef = admin.firestore().collection("sessions");

      const expiredSessions = await sessionsRef
          .where("status", "==", "active")
          .where("endTime", "<=", now)
          .get();

      const batch = admin.firestore().batch();
      expiredSessions.forEach((doc) => {
        batch.update(doc.ref, { status: "expired" });
      });

      await batch.commit();
      console.log(`Expired ${expiredSessions.size} sessions.`);
      return null;
    });
