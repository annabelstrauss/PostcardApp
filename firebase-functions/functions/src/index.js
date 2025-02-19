"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.handleSendblueWebhook = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
exports.handleSendblueWebhook = (0, https_1.onRequest)((request, response) => __awaiter(void 0, void 0, void 0, function* () {
    // Verify the request is POST
    if (request.method !== 'POST') {
        response.status(405).send('Method Not Allowed');
        return;
    }
    try {
        const { from_number, // Phone number of the person who sent the message
        content, // The message content (should contain the address)
         } = request.body;
        // Log incoming message for debugging
        console.log(`Received message from ${from_number}: ${content}`);
        // Validate required fields
        if (!from_number || !content) {
            console.error('Missing required fields in webhook payload');
            response.status(400).send('Missing required fields');
            return;
        }
        // Format phone number to match our storage format
        const formattedPhone = formatPhoneNumber(from_number);
        // Find the postcard with matching phone number and status addressRequested
        const postcardSnapshot = yield admin.firestore()
            .collection('postcards')
            .where('recipientPhone', '==', formattedPhone)
            .where('status', '==', 'addressRequested')
            .orderBy('dateCreated', 'desc') // Get most recent if multiple exist
            .limit(1)
            .get();
        if (postcardSnapshot.empty) {
            console.log('No matching postcard found for phone:', formattedPhone);
            response.status(404).send('No matching postcard found');
            return;
        }
        // Update the postcard with the address
        const postcard = postcardSnapshot.docs[0];
        yield postcard.ref.update({
            address: content,
            status: 'addressReceived'
        });
        console.log(`Updated postcard ${postcard.id} with address from ${formattedPhone}`);
        response.status(200).send('Webhook processed successfully');
    }
    catch (error) {
        console.error('Error processing webhook:', error);
        response.status(500).send('Internal Server Error');
    }
}));
// Helper function to format phone numbers consistently
function formatPhoneNumber(phone) {
    // Remove any non-numeric characters
    const numbers = phone.replace(/\D/g, '');
    // If it starts with 1 and has 11 digits, add +, otherwise add +1
    if (numbers.startsWith('1') && numbers.length === 11) {
        return '+' + numbers;
    }
    return '+1' + numbers;
}
