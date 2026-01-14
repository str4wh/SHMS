const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

// M-Pesa Configuration - Store these in Firebase Config for production
const MPESA_CONFIG = {
  consumerKey: "KLGqesuRo3m8JB4hHLVYeDBgQwgUe0Lef0Gns2owERGHXMt5",
  consumerSecret: "35IGYNKtCGHboszTvMgw8KltKG2dfz3puArHS5hJ7AAAkD9wRDd53wGL4cu0Vb1d",
  shortCode: "174379",
  passkey: "bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919",
  baseUrl: "https://sandbox.safaricom.co.ke",
  callbackUrl: "https://us-central1-shms-7b88d.cloudfunctions.net/mpesaCallback",
};

// Get M-Pesa OAuth token
async function getAccessToken() {
  const auth = Buffer.from(
      `${MPESA_CONFIG.consumerKey}:${MPESA_CONFIG.consumerSecret}`,
  ).toString("base64");

  try {
    const response = await axios.get(
        `${MPESA_CONFIG.baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
        {
          headers: {
            Authorization: `Basic ${auth}`,
          },
          timeout: 10000,
        },
    );
    return response.data.access_token;
  } catch (error) {
    console.error("Token error:", error.response?.data || error.message);
    throw new Error("Failed to get access token");
  }
}

// Initiate STK Push
exports.initiateMpesaPayment = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
    );
  }

  const {phoneNumber, amount, roomNumber} = data;
  const userId = context.auth.uid;

  // Validate inputs
  if (!phoneNumber || !amount || !roomNumber) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields",
    );
  }

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
      PartyA: phoneNumber,
      PartyB: MPESA_CONFIG.shortCode,
      PhoneNumber: phoneNumber,
      CallBackURL: MPESA_CONFIG.callbackUrl,
      AccountReference: `RENT-${roomNumber}`,
      TransactionDesc: "Rent payment",
    };

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
    console.log("STK Push response:", responseData);

    const success = responseData.ResponseCode === "0";

    if (success) {
      // Store pending payment in Firestore
      await admin.firestore().collection("payments").add({
        userId: userId,
        roomNumber: roomNumber,
        amount: amount,
        phoneNumber: phoneNumber,
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
    console.error("STK Push error:", error.response?.data || error.message);
    throw new functions.https.HttpsError(
        "internal",
        error.response?.data?.errorMessage || error.message,
    );
  }
});

// M-Pesa Callback Handler
exports.mpesaCallback = functions.https.onRequest(async (req, res) => {
  console.log("M-Pesa Callback received:", JSON.stringify(req.body));

  try {
    const callbackData = req.body.Body?.stkCallback;

    if (!callbackData) {
      res.status(200).json({ResultCode: 0, ResultDesc: "Success"});
      return;
    }

    const checkoutRequestID = callbackData.CheckoutRequestID;
    const resultCode = callbackData.ResultCode;

    // Find the payment document
    const paymentQuery = await admin
        .firestore()
        .collection("payments")
        .where("checkoutRequestID", "==", checkoutRequestID)
        .limit(1)
        .get();

    if (paymentQuery.empty) {
      console.log("No payment found for:", checkoutRequestID);
      res.status(200).json({ResultCode: 0, ResultDesc: "Success"});
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
      // Payment successful
      const callbackMetadata = callbackData.CallbackMetadata?.Item || [];
      const amount = callbackMetadata.find((i) => i.Name === "Amount")?.Value;
      const mpesaReceiptNumber = callbackMetadata.find(
          (i) => i.Name === "MpesaReceiptNumber",
      )?.Value;
      const transactionDate = callbackMetadata.find(
          (i) => i.Name === "TransactionDate",
      )?.Value;
      const phoneNumber = callbackMetadata.find(
          (i) => i.Name === "PhoneNumber",
      )?.Value;

      updateData.status = "completed";
      updateData.mpesaReceiptNumber = mpesaReceiptNumber;
      updateData.transactionDate = transactionDate;
      updateData.confirmedAmount = amount;
      updateData.confirmedPhone = phoneNumber;
      updateData.completedAt = admin.firestore.FieldValue.serverTimestamp();
    } else {
      // Payment failed
      updateData.status = "failed";
    }

    await paymentDoc.ref.update(updateData);
    console.log("Payment updated:", checkoutRequestID, updateData);

    res.status(200).json({ResultCode: 0, ResultDesc: "Success"});
  } catch (error) {
    console.error("Callback error:", error);
    res.status(200).json({ResultCode: 0, ResultDesc: "Success"});
  }
});

// Query payment status
exports.checkPaymentStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
    );
  }

  const {checkoutRequestID} = data;

  if (!checkoutRequestID) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "checkoutRequestID is required",
    );
  }

  try {
    const paymentQuery = await admin
        .firestore()
        .collection("payments")
        .where("checkoutRequestID", "==", checkoutRequestID)
        .where("userId", "==", context.auth.uid)
        .limit(1)
        .get();

    if (paymentQuery.empty) {
      return {status: "not_found"};
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
    throw new functions.https.HttpsError("internal", error.message);
  }
});