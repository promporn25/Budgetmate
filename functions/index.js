const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {ImageAnnotatorClient} = require('@google-cloud/vision');
const vision = new ImageAnnotatorClient();

exports.scanReceipt = onCall({region: 'asia-southeast1', timeoutSeconds: 60,
  memory: '512MiB', maxInstances: 3}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const content = request.data?.image;
  if (typeof content !== 'string' || content.length > 7 * 1024 * 1024 ||
      !/^[A-Za-z0-9+/]+={0,2}$/.test(content)) {
    throw new HttpsError('invalid-argument', 'Use an image smaller than 5 MB.');
  }
  const bytes = Buffer.from(content, 'base64');
  if (!bytes.length || bytes.length > 5 * 1024 * 1024) {
    throw new HttpsError('invalid-argument', 'Use an image smaller than 5 MB.');
  }
  try {
    const [result] = await vision.documentTextDetection({
      image: {content: bytes}, imageContext: {languageHints: ['th', 'en']},
    }, {timeout: 45000});
    if (result.error?.message) throw new Error('OCR failed');
    return {text: result.fullTextAnnotation?.text || ''};
  } catch (_) {
    // Do not log receipt contents or return internal service details.
    throw new HttpsError('unavailable', 'Receipt scanning is unavailable. Try again later.');
  }
});
