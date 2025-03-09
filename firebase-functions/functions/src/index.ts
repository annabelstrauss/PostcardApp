import * as dotenv from 'dotenv';
dotenv.config();

import axios from 'axios';
import * as crypto from 'crypto';
import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import * as fs from 'fs';
import fetch from 'node-fetch';
import * as path from 'path';
import PDFDocument from 'pdfkit';

// Type definition for PostGrid
// @ts-ignore
import PostGrid from 'postgrid';

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

// Initialize PostGrid client
const postGridClient = new PostGrid(process.env.POSTGRID_API_KEY || '');

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

/**
 * Creates a new contact with the provided contact details
 * @param {string} addressLine1 - The street address of the contact
 * @param {string} provinceOrState - The province or state of the contact
 * @param {string} postalOrZip - The postal or zip code of the contact
 * @param {string} countryCode - The country code of the contact
 * @param {string} firstName - The first name of the contact
 * @param {string} lastName - The last name of the contact
 * @param {string} phoneNumber - The phone number of the contact
 * @returns {Promise<string>} The ID of the newly created contact
 */
export async function createContact(
    addressLine1: string,
    provinceOrState: string,
    postalOrZip: string,
    countryCode: string,
    firstName: string,
    lastName: string,
    phoneNumber: string
): Promise<string> {
    const newContact = await postGridClient.contact.create({
        addressLine1,
        provinceOrState,
        postalOrZip,
        countryCode,
        firstName,
        lastName,
        phoneNumber,
    });
    console.log("success:", newContact.success);
    return newContact.id;
}

/**
 * Example usage of createContact function
 */
export async function createExampleContact(): Promise<string | undefined> {
    try {
        console.log('Creating new contact...');
        const contactId = await createContact(
            '123 Main St',
            'California',
            '90210',
            'US',
            'John',
            'Doe',
            '555-555-5555'
        );
        console.log(`Contact created successfully! Contact ID: ${contactId}`);
        return contactId;
    } catch (error) {
        console.error('Failed to create contact:', error);
        return undefined;
    }
}

/**
 * Constructs a postcard PDF with an image from Firebase Storage
 * @param {string} postcardMessage - Message to display on the postcard
 * @param {string} postcardPictureURL - Firebase Storage URL of the image
 * @returns {Promise<string>} - Path to the generated PDF file
 */
export async function createPostcardAsset(postcardMessage: string, postcardPictureURL: string): Promise<string> {
    // PDF units are in points (1 inch = 72 points)
    const pointMult = 72;

    const bleed = 0.125 * pointMult; // Postgrid requires 0.125" bleed around the design
    const width = 6 * pointMult;
    const height = 4 * pointMult;

    const totalPageDim: [number, number] = [width + (bleed * 2), height + (bleed * 2)];

    try {
        // Download the image from Firebase Storage
        const response = await axios({
            method: 'GET',
            url: postcardPictureURL,
            responseType: 'arraybuffer'
        });

        // Save the image temporarily
        const tempImagePath = path.join(__dirname, `temp_image_${crypto.randomUUID()}.jpg`);
        fs.writeFileSync(tempImagePath, response.data);

        // Create a document
        const doc = new PDFDocument({
            size: totalPageDim as [number, number]
        });

        const pdfPath = `${crypto.randomUUID()}.pdf`;
        doc.pipe(fs.createWriteStream(pdfPath));

        // Use the downloaded image
        doc.image(tempImagePath, 0, 0, {
            width,
            height,
            cover: totalPageDim,
            align: "center",
            valign: "center"
        });

        doc.rect(bleed, bleed, width, height).dash(5, { space: 10 }).stroke("blue");
        doc.rect(bleed * 2, bleed * 2, width - bleed * 2, height - bleed * 2).dash(5, { space: 10 }).stroke("red");

        // Add another page
        doc.addPage({
            size: totalPageDim
        })
            .fontSize(14);

        doc.rect(bleed, bleed, width, height).dash(5, { space: 10 }).stroke("blue");
        doc.rect(bleed * 2, bleed * 2, width - bleed * 2, height - bleed * 2).dash(5, { space: 10 }).stroke("red");

        doc.rect(bleed, bleed, 2.0576131688 * pointMult, 1.5740740742 * pointMult).undash().stroke("black");

        doc.rect(3.7294238681 * pointMult, bleed, 2.3919753088 * pointMult, height).stroke();

        doc.text(postcardMessage, bleed * 2, height / 3 * 2, { width: width / 3 * 2, align: 'left' });

        doc.end();

        // Clean up the temporary image file after PDF is created
        doc.on('end', () => {
            fs.unlinkSync(tempImagePath);
        });

        return pdfPath;
    } catch (error) {
        console.error('Error creating postcard:', error);
        throw error;
    }
}

/**
 * Example usage of createPostcardAsset function
 */
export async function createExamplePostcard(): Promise<string | undefined> {
    try {
        // Example Firebase Storage URL
        const firebaseImageUrl = 'https://firebasestorage.googleapis.com:443/v0/b/postcardapp-9b0eb.firebasestorage.app/o/postcards%2F02755629-8F4B-496D-BF7C-7016022FC9AD.jpg?alt=media&token=99913f76-eb2b-48fd-be3f-5e93fcfe1c6d';

        console.log('Creating postcard with Firebase Storage image...');
        const pdfPath = await createPostcardAsset(
            'This is a test message for the postcard!',
            firebaseImageUrl
        );
        console.log(`Postcard created successfully! PDF saved at: ${pdfPath}`);
        return pdfPath;
    } catch (error) {
        console.error('Failed to create postcard:', error);
        return undefined;
    }
}

/**
 * Creates a postcard using PostGrid API
 */
export const createAndSendPostcard = onRequest(async (request, response) => {
    // Verify the request is POST
    if (request.method !== 'POST') {
        response.status(405).send('Method Not Allowed');
        return;
    }

    try {
        const {
            message,
            imageUrl,
            recipientDetails: {
                addressLine1,
                provinceOrState,
                postalOrZip,
                countryCode,
                firstName,
                lastName,
                phoneNumber
            }
        } = request.body;

        // Validate required fields
        if (!message || !imageUrl || !addressLine1 || !provinceOrState ||
            !postalOrZip || !countryCode || !firstName || !lastName) {
            console.error('Missing required fields in request payload');
            response.status(400).send('Missing required fields');
            return;
        }

        // Step 1: Create the contact
        console.log('Creating a new contact...');
        const contactId = await createContact(
            addressLine1,
            provinceOrState,
            postalOrZip,
            countryCode,
            firstName,
            lastName,
            phoneNumber || '' // Make phone number optional
        );

        // Step 2: Create the postcard PDF
        console.log('Creating the postcard asset...');
        const pdfPath = await createPostcardAsset(message, imageUrl);

        // Step 3: Save the reference to Firestore
        await admin.firestore().collection('postcards').add({
            contactId,
            pdfPath,
            message,
            imageUrl,
            recipientDetails: {
                addressLine1,
                provinceOrState,
                postalOrZip,
                countryCode,
                firstName,
                lastName,
                phoneNumber: phoneNumber || ''
            },
            status: 'created',
            dateCreated: admin.firestore.FieldValue.serverTimestamp()
        });

        response.status(200).json({
            success: true,
            contactId,
            pdfPath
        });
    } catch (error) {
        console.error('Error creating postcard:', error);
        response.status(500).send('Internal Server Error');
    }
}); 