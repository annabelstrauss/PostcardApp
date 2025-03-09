const fs = require('fs');
const PDFDocument = require('pdfkit');
const crypto = require('crypto');
const axios = require('axios');
const path = require('path');

const client = new PostGrid(process.env.POSTGRID_TEST_API_KEY)

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
async function createContact(addressLine1, provinceOrState, postalOrZip, countryCode, firstName, lastName, phoneNumber) {
  const newContact = await client.contact.create({
    addressLine1,
    provinceOrState,
    postalOrZip,
    countryCode,
    firstName,
    lastName,
    phoneNumber,
  })
  console.log("success:", newContact.success)
  return newContact.id;
}

// Example usage
async function createExampleContact() {
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
  }
}

// Run the example
createExampleContact();

/**
 * Constructs a postcard PDF with an image from Firebase Storage
 * @param {string} message - Message to display on the postcard
 * @param {string} url - Firebase Storage URL of the image
 * @returns {Promise<string>} - Path to the generated PDF file
 */
async function createPostcardAsset(postcardMessage, postcardPictureURL) {
  // PDF units are in points (1 inch = 72 points)
  const pointMult = 72;

  const bleed = 0.125 * pointMult; // Postgrid requires 0.125" bleed around the design
  const width = 6 * pointMult;
  const height = 4 * pointMult;

  const totalPageDim = [width + (bleed * 2), height + (bleed * 2)];

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
      size: totalPageDim
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

    doc.rect(bleed, bleed, width, height).dash(5, { space: 10 }).stroke("blue")
    doc.rect(bleed * 2, bleed * 2, width - bleed * 2, height - bleed * 2).dash(5, { space: 10 }).stroke("red")

    // Add another page
    doc.addPage({
      size: totalPageDim
    })
      .fontSize(14)

    doc.rect(bleed, bleed, width, height).dash(5, { space: 10 }).stroke("blue")
    doc.rect(bleed * 2, bleed * 2, width - bleed * 2, height - bleed * 2).dash(5, { space: 10 }).stroke("red")

    doc.rect(bleed, bleed, 2.0576131688 * pointMult, 1.5740740742 * pointMult).undash().stroke("black")

    doc.rect(3.7294238681 * pointMult, bleed, 2.3919753088 * pointMult, height).stroke()

    doc.text(postcardMessage, bleed * 2, height / 3 * 2, { width: width / 3 * 2, align: 'left' })

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

// Example Firebase Storage URL
const firebaseImageUrl = 'https://firebasestorage.googleapis.com:443/v0/b/postcardapp-9b0eb.firebasestorage.app/o/postcards%2F02755629-8F4B-496D-BF7C-7016022FC9AD.jpg?alt=media&token=99913f76-eb2b-48fd-be3f-5e93fcfe1c6d';

// Example usage
async function createExamplePostcard() {
  try {
    console.log('Creating postcard with Firebase Storage image...');
    const pdfPath = await createPostcardAsset(
      'This is a test message for the postcard!',
      firebaseImageUrl
    );
    console.log(`Postcard created successfully! PDF saved at: ${pdfPath}`);
    return pdfPath;
  } catch (error) {
    console.error('Failed to create postcard:', error);
  }
}

// Run the example
createExamplePostcard(); 