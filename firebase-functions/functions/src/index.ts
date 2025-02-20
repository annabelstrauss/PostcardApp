import * as dotenv from 'dotenv';
dotenv.config();

import { onRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import fetch from 'node-fetch';

admin.initializeApp();

// Sendblue configuration
const SENDBLUE_CONFIG = {
    apiKey: process.env.FUNCTIONS_CONFIG_SENDBLUE_API_KEY ?? process.env.SENDBLUE_API_KEY,
    apiSecret: process.env.FUNCTIONS_CONFIG_SENDBLUE_API_SECRET ?? process.env.SENDBLUE_API_SECRET,
    fromNumber: '+14152005823'
};

// Validate credentials exist
if (!SENDBLUE_CONFIG.apiKey || !SENDBLUE_CONFIG.apiSecret) {
    throw new Error('Sendblue API credentials not configured');
}

export const handleSendblueWebhook = onRequest(async (request, response) => {
    // Verify the request is POST
    if (request.method !== 'POST') {
        response.status(405).send('Method Not Allowed');
        return;
    }

    try {
        const { 
            from_number,  // Changed from recipient_number to from_number
            content,     // The message content (should contain the address)
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
        const postcardSnapshot = await admin.firestore()
            .collection('postcards')
            .where('recipientPhone', '==', formattedPhone)
            .where('status', '==', 'addressRequested')
            .orderBy('dateCreated', 'desc')
            .limit(1)
            .get();

        if (postcardSnapshot.empty) {
            console.log('No matching postcard found for phone:', formattedPhone);
            response.status(404).send('No matching postcard found');
            return;
        }

        // Update the postcard with the address
        const postcard = postcardSnapshot.docs[0];
        await postcard.ref.update({
            address: content,
            status: 'addressReceived',
            addressReceivedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Send thank you message
        try {
            const thankYouResponse = await fetch('https://api.sendblue.co/api/send-message', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'SB-API-KEY-ID': SENDBLUE_CONFIG.apiKey!,
                    'SB-API-SECRET-KEY': SENDBLUE_CONFIG.apiSecret!
                } as const,
                body: JSON.stringify({
                    from_number: SENDBLUE_CONFIG.fromNumber,
                    number: formattedPhone,
                    content: 'Thank you! Your postcard will be on its way soon! 📬'
                })
            });

            const responseData = await thankYouResponse.text();
            console.log('Sendblue thank you message response:', {
                status: thankYouResponse.status,
                body: responseData
            });

            if (!thankYouResponse.ok) {
                throw new Error(`Failed to send thank you message: ${thankYouResponse.status} ${responseData}`);
            }
        } catch (error) {
            console.error('Error sending thank you message:', error);
            // Don't throw the error so we still return success for the webhook
        }

        console.log(`Updated postcard ${postcard.id} with address from ${formattedPhone} and sent thank you`);
        response.status(200).send('Webhook processed successfully');

    } catch (error) {
        console.error('Error processing webhook:', error);
        response.status(500).send('Internal Server Error');
    }
});

// Helper function to format phone numbers consistently
function formatPhoneNumber(phone: string): string {
    // Remove any non-numeric characters
    const numbers = phone.replace(/\D/g, '');
    
    // If it starts with 1 and has 11 digits, add +, otherwise add +1
    if (numbers.startsWith('1') && numbers.length === 11) {
        return '+' + numbers;
    }
    return '+1' + numbers;
} 