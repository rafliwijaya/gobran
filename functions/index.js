const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

async function sendTokens(tokens, notification, data = {}) {
  const clean = [...new Set(tokens.filter(Boolean))];
  if (!clean.length) return;
  await getMessaging().sendEachForMulticast({tokens: clean, notification, data});
}

exports.broadcastNewOrder = onDocumentCreated("orders/{orderId}", async (event) => {
  const order = event.data.data();
  if (!['ojek', 'express'].includes(order.service_type)) return;
  const users = await db.collection("users")
    .where("role", "==", "driver")
    .where("verification_status", "==", "approved")
    .where("zone_id", "==", order.zone_id).get();
  const activeIds = [];
  users.forEach((doc) => activeIds.push(doc.id));
  if (!activeIds.length) return;
  const tokens = [];
  for (let i = 0; i < activeIds.length; i += 30) {
    const part = activeIds.slice(i, i + 30);
    const drivers = await db.collection("drivers")
      .where("user_id", "in", part).where("is_active", "==", true).get();
    drivers.forEach((doc) => tokens.push(doc.data().fcm_token));
  }
  await sendTokens(tokens, {
    title: `Order ${order.service_type === 'ojek' ? 'Ojek' : 'Express'} baru`,
    body: `${order.pickup?.address || 'Lokasi jemput'} → ${order.destination?.address || 'Tujuan'}`,
  }, {order_id: event.params.orderId, type: "new_order"});
});

exports.notifyOrderStatus = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status === after.status) return;
  const labels = {
    searching: "Pesanan siap, GoBran sedang mencari driver",
    accepted: "Order diterima driver",
    heading_to_pickup: "Driver menuju lokasi jemput",
    picked_up: "Penumpang/barang sudah dijemput",
    preparing: "Pesanan sedang disiapkan",
    ready: "Pesanan sudah siap",
    on_delivery: "Pesanan sedang diantar",
    completed: "Pesanan selesai",
    cancelled: "Pesanan dibatalkan",
  };
  const message = labels[after.status] || `Status order: ${after.status}`;
  await db.collection("inbox").doc(`${event.params.orderId}_${after.status}`).set({
    user_id: after.customer_id,
    order_id: event.params.orderId,
    title: "Pembaruan order",
    message,
    is_read: false,
    created_at: FieldValue.serverTimestamp(),
  }, {merge: true});
  const user = await db.collection("users").doc(after.customer_id).get();
  await sendTokens([user.data()?.fcm_token], {title: "GoBran", body: message}, {
    order_id: event.params.orderId,
    type: "order_status",
  });
});

exports.broadcastReadyFood = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data.before.data();
  const order = event.data.after.data();
  if (order.service_type !== "food" || before.status === "searching" || order.status !== "searching") return;
  const users = await db.collection("users")
    .where("role", "==", "driver")
    .where("verification_status", "==", "approved")
    .where("zone_id", "==", order.zone_id).get();
  const tokens = [];
  for (const user of users.docs) {
    const driver = await db.collection("drivers").doc(user.id).get();
    if (driver.data()?.is_active && driver.data()?.fcm_token) tokens.push(driver.data().fcm_token);
  }
  await sendTokens(tokens, {
    title: "Pesanan makanan siap diantar",
    body: `${order.merchant_name || "UMKM"} → ${order.destination?.address || "Pelanggan"}`,
  }, {order_id: event.params.orderId, type: "new_order"});
});
