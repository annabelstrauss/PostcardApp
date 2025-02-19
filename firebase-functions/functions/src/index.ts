import { onRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const handleSendblueWebhook = onRequest(async (request, response) => {
    // Verify the request is POST
    if (request.method !== 'POST') {
        response.status(405).send('Method Not Allowed');
        return;
    }

    try {
        const { 
            from_number, // Phone number of the person who sent the message
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
        await postcard.ref.update({
            address: content,
            status: 'addressReceived'
        });

        console.log(`Updated postcard ${postcard.id} with address from ${formattedPhone}`);
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