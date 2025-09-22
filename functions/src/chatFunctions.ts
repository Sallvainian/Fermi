import * as functions from "firebase-functions/v2";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();
const messaging = admin.messaging();
const storage = admin.storage();

async function ensureConversationMembership(
  conversationId: string,
  userId: string
) {
  const conversationRef = db.collection("conversations").doc(conversationId);
  const conversationDoc = await conversationRef.get();

  if (!conversationDoc.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "Conversation not found"
    );
  }

  const conversationData = conversationDoc.data() ?? {};
  const rawParticipants = conversationData.participants ?? conversationData.participantIds;
  const participants = Array.isArray(rawParticipants)
    ? rawParticipants.filter((participant): participant is string => typeof participant === "string")
    : [];

  if (!participants.includes(userId)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "User does not belong to this conversation"
    );
  }

  return { conversationRef, conversationDoc, conversationData, participants };
}

/**
 * Send a message with server-side validation
 * Ensures sender is authenticated and adds server timestamp
 */
export const sendMessage = functions.https.onCall(
  {
    maxInstances: 10,
    region: "us-east4"
  },
  async (request) => {
    // Check authentication
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to send messages"
      );
    }

    const { conversationId, text, attachments } = request.data;
    const senderId = request.auth.uid;

    // Validate input - allow attachment-only messages
    if (!conversationId || (!text && !attachments)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "conversationId and either text or attachments are required"
      );
    }

    try {
      const { conversationRef, participants } = await ensureConversationMembership(
        conversationId,
        senderId
      );

      // Get sender info
      const senderDoc = await db.collection("users").doc(senderId).get();
      if (!senderDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Sender user not found"
        );
      }

      const senderData = senderDoc.data()!;

      // Create message
      const message = {
        id: db.collection("conversations").doc().id, // Generate unique ID
        authorId: senderId,
        authorName: senderData.name || "Unknown",
        authorRole: senderData.role || "student",
        text: text ? text.trim() : "",
        attachments: attachments || [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {}
      };

      // Add message to conversation
      await conversationRef
        .collection("messages")
        .doc(message.id)
        .set(message);

      // Update conversation metadata
      await conversationRef.update({
        lastMessage: {
          text: message.text,
          authorId: senderId,
          authorName: senderData.name,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        },
        lastActivity: admin.firestore.FieldValue.serverTimestamp(),
        [`unreadCount.${senderId}`]: 0, // Reset sender's unread count
      });

      const otherParticipants = participants.filter((participantId) => participantId !== senderId);

      // Update unread counts for other participants
      const unreadUpdates: Record<string, unknown> = {};
      for (const participantId of otherParticipants) {
        unreadUpdates[`unreadCount.${participantId}`] = admin.firestore.FieldValue.increment(1);
      }

      if (Object.keys(unreadUpdates).length > 0) {
        await conversationRef.update(unreadUpdates);
      }

      // Send push notifications to other participants
      await sendPushNotifications(otherParticipants, senderData.name, message.text, conversationId);

      return { success: true, messageId: message.id };
    } catch (error) {
      logger.error("Error sending message:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to send message"
      );
    }
  }
);

/**
 * Mark messages as read
 * Updates read receipts and clears unread count
 */
export const markMessagesAsRead = functions.https.onCall(
  {
    maxInstances: 10,
    region: "us-east4"
  },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { conversationId, messageIds } = request.data;
    const userId = request.auth.uid;

    if (!conversationId || !messageIds || !Array.isArray(messageIds)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "conversationId and messageIds array are required"
      );
    }

    try {
      const { conversationRef } = await ensureConversationMembership(conversationId, userId);

      // Update messages with seenAt timestamp
      const batch = db.batch();
      const now = admin.firestore.FieldValue.serverTimestamp();

      for (const messageId of messageIds) {
        const messageRef = conversationRef
          .collection("messages")
          .doc(messageId);

        batch.update(messageRef, {
          seenAt: now,
          [`readBy.${userId}`]: now
        });
      }

      // Reset unread count for user
      batch.update(conversationRef, {
        [`unreadCount.${userId}`]: 0
      });

      await batch.commit();

      return { success: true, readCount: messageIds.length };
    } catch (error) {
      logger.error("Error marking messages as read:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to mark messages as read"
      );
    }
  }
);

/**
 * Handle typing indicators
 * Updates user's typing status in conversation
 */
export const updateTypingStatus = functions.https.onCall(
  {
    maxInstances: 10,
    region: "us-east4"
  },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { conversationId, isTyping } = request.data;
    const userId = request.auth.uid;

    if (!conversationId || isTyping === undefined) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "conversationId and isTyping are required"
      );
    }

    try {
      const { conversationRef } = await ensureConversationMembership(conversationId, userId);

      // Update typing status in conversation metadata
      const typingRef = conversationRef
        .collection("typing")
        .doc(userId);

      if (isTyping) {
        // Set typing with timestamp
        await typingRef.set({
          isTyping: true,
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
          userName: (await db.collection("users").doc(userId).get()).data()?.name || "Unknown"
        });

        // Auto-remove after 10 seconds if not updated
        setTimeout(async () => {
          try {
            const doc = await typingRef.get();
            if (doc.exists) {
              const data = doc.data();
              const startedAt = data?.startedAt?.toDate();
              if (startedAt && Date.now() - startedAt.getTime() > 10000) {
                await typingRef.delete();
              }
            }
          } catch (e) {
            logger.error("Error cleaning up typing status:", e);
          }
        }, 11000);
      } else {
        // Remove typing status
        await typingRef.delete();
      }

      return { success: true };
    } catch (error) {
      logger.error("Error updating typing status:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to update typing status"
      );
    }
  }
);

/**
 * Upload file attachment for chat
 * Handles secure file upload with validation
 */
export const uploadChatFile = functions.https.onCall(
  {
    maxInstances: 10,
    region: "us-east4",
    memory: "512MiB"
  },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { conversationId, fileName, mimeType, base64Data, fileSize } = request.data;
    const userId = request.auth.uid;

    // Validate input
    if (!conversationId || !fileName || !base64Data || !mimeType) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "conversationId, fileName, mimeType, and base64Data are required"
      );
    }

    // File size limit: 10MB
    if (fileSize && fileSize > 10 * 1024 * 1024) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "File size exceeds 10MB limit"
      );
    }

    // Allowed MIME types
    const allowedTypes = [
      "image/jpeg", "image/png", "image/gif", "image/webp",
      "application/pdf", "application/msword",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "application/vnd.ms-excel",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "text/plain", "text/csv"
    ];

    if (!allowedTypes.includes(mimeType)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "File type not allowed"
      );
    }

    try {
      await ensureConversationMembership(conversationId, userId);

      // Generate unique file path
      const timestamp = Date.now();
      const sanitizedFileName = fileName.replace(/[^a-zA-Z0-9.-]/g, "_");
      const filePath = `chat-attachments/${conversationId}/${userId}/${timestamp}_${sanitizedFileName}`;

      // Convert base64 to buffer
      const buffer = Buffer.from(base64Data, "base64");

      // Upload to Firebase Storage
      const bucket = storage.bucket();
      const file = bucket.file(filePath);

      await file.save(buffer, {
        metadata: {
          contentType: mimeType,
          metadata: {
            uploadedBy: userId,
            conversationId: conversationId,
            originalName: fileName
          }
        }
      });

      // Get download URL
      const [url] = await file.getSignedUrl({
        action: "read",
        expires: "03-01-2500" // Far future expiry
      });

      return {
        success: true,
        url: url,
        fileName: fileName,
        mimeType: mimeType,
        fileSize: buffer.length,
        filePath: filePath
      };
    } catch (error) {
      logger.error("Error uploading file:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to upload file"
      );
    }
  }
);

/**
 * Send push notifications to participants
 */
async function sendPushNotifications(
  participantIds: string[],
  senderName: string,
  messageText: string,
  conversationId: string
) {
  try {
    // Get FCM tokens for participants
    const tokens: string[] = [];

    for (const participantId of participantIds) {
      const userDoc = await db.collection("users").doc(participantId).get();
      if (userDoc.exists && userDoc.data()?.fcmToken) {
        tokens.push(userDoc.data()!.fcmToken);
      }
    }

    if (tokens.length === 0) return;

    // Create notification payload
    const payload = {
      notification: {
        title: senderName,
        body: messageText.length > 100 ? messageText.substring(0, 97) + "..." : messageText,
      },
      data: {
        type: "chat",
        conversationId: conversationId,
      },
      tokens: tokens,
    };

    // Send notifications
    const response = await messaging.sendEachForMulticast(payload);
    logger.info(`Successfully sent ${response.successCount} notifications`);

    if (response.failureCount > 0) {
      logger.error(`Failed to send ${response.failureCount} notifications`);
    }
  } catch (error) {
    logger.error("Error sending push notifications:", error);
    // Don't throw - notifications are not critical
  }
}
