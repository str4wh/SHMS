const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

const MPESA_CONFIG = {
  consumerKey: "KLGqesuRo3m8JB4hHLVYeDBgQwgUe0Lef0Gns2owERGHXMt5",
  consumerSecret: "35IGYNKtCGHboszTvMgw8KltKG2dfz3puArHS5hJ7AAAkD9wRDd53wGL4cu0Vb1d",
  shortCode: "174379",
  passkey: "bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919",
  baseUrl: "https://sandbox.safaricom.co.ke",
  callbackUrl: "https://us-central1-shms-7b88d.cloudfunctions.net/mpesaCallback",
  // Recipient phone — in production replace shortCode with your real Paybill/Till
  recipientPhone: "254722683135",
};

/** Normalize phone → 2547XXXXXXXX */
function normalizePhone(phone) {
  let p = String(phone).replace(/[^0-9]/g, "");
  if (p.startsWith("0")) p = "254" + p.substring(1);
  if (!p.startsWith("254")) p = "254" + p;
  return p;
}

/** Get fresh M-Pesa OAuth token */
async function getAccessToken() {
  const auth = Buffer.from(
      `${MPESA_CONFIG.consumerKey}:${MPESA_CONFIG.consumerSecret}`,
  ).toString("base64");

  let response;
  try {
    response = await axios.get(
        `${MPESA_CONFIG.baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
        {
          headers: {
            Authorization: `Basic ${auth}`,
            "Content-Type": "application/json",
          },
          timeout: 15000,
        },
    );
  } catch (err) {
    console.error("OAuth request failed:", err.response?.data || err.message);
    throw new Error("OAuth request failed: " + (err.response?.data?.errorMessage || err.message));
  }

  const token = response.data?.access_token;
  if (!token) {
    console.error("No access_token in OAuth response:", JSON.stringify(response.data));
    throw new Error("No access token returned by M-Pesa: " + JSON.stringify(response.data));
  }

  console.log("Access token obtained (first 10 chars):", token.substring(0, 10));
  return token;
}

// Initiate STK Push
exports.initiateMpesaPayment = onCall(
    { cors: true },
    async (request) => {
      const userId = request.auth?.uid ?? request.data.userId ?? null;
      if (!userId) {
        throw new HttpsError("unauthenticated", "User must be authenticated");
      }

      const { phoneNumber, amount, roomNumber } = request.data;
      if (!phoneNumber || !amount || !roomNumber) {
        throw new HttpsError("invalid-argument", "Missing required fields");
      }

      const phone = normalizePhone(phoneNumber);
      console.log(`Payment request: phone=${phone}, amount=${amount}, room=${roomNumber}`);

      try {
        const token = await getAccessToken();

        const timestamp = new Date()
            .toISOString()
            .replace(/[^0-9]/g, "")
            .slice(0, 14);

        const password = Buffer.from(
            `${MPESA_CONFIG.shortCode}${MPESA_CONFIG.passkey}${timestamp}`,
        ).toString("base64");

        const requestBody = {
          BusinessShortCode: MPESA_CONFIG.shortCode,
          Password: password,
          Timestamp: timestamp,
          TransactionType: "CustomerPayBillOnline",
          Amount: Math.floor(amount),
          PartyA: phone,
          PartyB: MPESA_CONFIG.shortCode,
          PhoneNumber: phone,
          CallBackURL: MPESA_CONFIG.callbackUrl,
          AccountReference: `SHMS-${roomNumber}`,
          TransactionDesc: "SHMS Rent Payment",
        };

        console.log("STK Push request body:", JSON.stringify(requestBody));

        const response = await axios.post(
            `${MPESA_CONFIG.baseUrl}/mpesa/stkpush/v1/processrequest`,
            requestBody,
            {
              headers: {
                Authorization: `Bearer ${token}`,
                "Content-Type": "application/json",
              },
              timeout: 15000,
            },
        );

        const responseData = response.data;
        console.log("STK Push response:", JSON.stringify(responseData));

        const success = responseData.ResponseCode === "0";

        if (success) {
          await admin.firestore().collection("payments").add({
            userId: userId,
            roomNumber: roomNumber,
            amount: amount,
            phoneNumber: phone,
            checkoutRequestID: responseData.CheckoutRequestID,
            merchantRequestID: responseData.MerchantRequestID,
            status: "pending",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            responseDescription: responseData.ResponseDescription,
          });
        }

        return {
          success: success,
          checkoutRequestID: responseData.CheckoutRequestID,
          merchantRequestID: responseData.MerchantRequestID,
          message: responseData.ResponseDescription || responseData.CustomerMessage,
        };
      } catch (error) {
        const errMsg = error.response?.data?.errorMessage ||
          error.response?.data?.ResultDesc ||
          error.message;
        console.error("STK Push error:", error.response?.data || error.message);
        throw new HttpsError("internal", errMsg);
      }
    });

// M-Pesa Callback Handler
exports.mpesaCallback = onRequest(async (req, res) => {
  console.log("M-Pesa Callback received:", JSON.stringify(req.body));

  try {
    const callbackData = req.body.Body?.stkCallback;
    if (!callbackData) {
      res.status(200).json({ ResultCode: 0, ResultDesc: "Success" });
      return;
    }

    const checkoutRequestID = callbackData.CheckoutRequestID;
    const resultCode = callbackData.ResultCode;

    const paymentQuery = await admin
        .firestore()
        .collection("payments")
        .where("checkoutRequestID", "==", checkoutRequestID)
        .limit(1)
        .get();

    if (paymentQuery.empty) {
      res.status(200).json({ ResultCode: 0, ResultDesc: "Success" });
      return;
    }

    const paymentDoc = paymentQuery.docs[0];
    const updateData = {
      callbackReceived: true,
      callbackReceivedAt: admin.firestore.FieldValue.serverTimestamp(),
      resultCode: resultCode,
      resultDesc: callbackData.ResultDesc,
    };

    if (resultCode === 0) {
      const items = callbackData.CallbackMetadata?.Item || [];
      updateData.status = "completed";
      updateData.mpesaReceiptNumber =
        items.find((i) => i.Name === "MpesaReceiptNumber")?.Value;
      updateData.transactionDate =
        items.find((i) => i.Name === "TransactionDate")?.Value;
      updateData.confirmedAmount =
        items.find((i) => i.Name === "Amount")?.Value;
      updateData.confirmedPhone =
        items.find((i) => i.Name === "PhoneNumber")?.Value;
      updateData.completedAt = admin.firestore.FieldValue.serverTimestamp();
    } else {
      updateData.status = "failed";
    }

    await paymentDoc.ref.update(updateData);
    res.status(200).json({ ResultCode: 0, ResultDesc: "Success" });
  } catch (error) {
    console.error("Callback error:", error);
    res.status(200).json({ ResultCode: 0, ResultDesc: "Success" });
  }
});

// Query payment status
exports.checkPaymentStatus = onCall(
    { cors: true },
    async (request) => {
      const userId = request.auth?.uid ?? request.data.userId ?? null;
      if (!userId) {
        throw new HttpsError("unauthenticated", "User must be authenticated");
      }

      const { checkoutRequestID } = request.data;
      if (!checkoutRequestID) {
        throw new HttpsError("invalid-argument", "checkoutRequestID is required");
      }

      try {
        const paymentQuery = await admin
            .firestore()
            .collection("payments")
            .where("checkoutRequestID", "==", checkoutRequestID)
            .where("userId", "==", userId)
            .limit(1)
            .get();

        if (paymentQuery.empty) {
          return { status: "not_found" };
        }

        const payment = paymentQuery.docs[0].data();
        return {
          status: payment.status,
          mpesaReceiptNumber: payment.mpesaReceiptNumber,
          amount: payment.amount,
          resultDesc: payment.resultDesc,
        };
      } catch (error) {
        console.error("Status check error:", error);
        throw new HttpsError("internal", error.message);
      }
    });
