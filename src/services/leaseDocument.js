/**
 * Renders a rental_agreements row's agreement_terms (see
 * services/leaseTemplate.js) into a downloadable PDF — the document a
 * tenant/owner can print and take to a legal or documentation office
 * once the deal is closed. Deliberately reuses agreement_terms as the
 * single source of truth for the *words* of the agreement (same text
 * shown for "read and accept" in the app before any money moved) —
 * this module only handles turning that fixed text into a nicely laid
 * out file, never generates or alters wording of its own.
 *
 * Only exposed once a deal is 'paid' (see routes/rentalAgreements.js
 * GET /:id/document) — before that there's nothing signed yet to hand
 * anyone.
 */
const PDFDocument = require('pdfkit');

const NUMBERED_SECTION_RE = /^\d{1,2}\. [A-Z]/; // e.g. "4. RENT AND ADVANCE PAYMENT"
const TITLE_LINE_RE = /^STANDARD RESIDENTIAL LEASE AGREEMENT$/;
const GENERATED_LINE_RE = /^Generated on /;

/**
 * @param {object} row - a rental_agreements row (from findById et al),
 *   with agreement_terms already populated (sendAgreement always sets
 *   it before a row can reach 'paid').
 * @returns {Promise<Buffer>} the rendered PDF, ready to stream/attach.
 */
function renderLeaseAgreementPdf(row) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 56, size: 'A4' });
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    const text = row.agreement_terms || '';
    const lines = text.split('\n');

    for (const rawLine of lines) {
      const line = rawLine.trimEnd();

      if (TITLE_LINE_RE.test(line)) {
        doc.font('Helvetica-Bold').fontSize(16).text(line, { align: 'center' });
        continue;
      }
      if (GENERATED_LINE_RE.test(line)) {
        doc.font('Helvetica-Oblique').fontSize(9).fillColor('#555555').text(line, { align: 'center' });
        doc.fillColor('#000000');
        doc.moveDown(1);
        continue;
      }
      if (NUMBERED_SECTION_RE.test(line)) {
        doc.moveDown(0.6);
        doc.font('Helvetica-Bold').fontSize(12).text(line);
        continue;
      }
      if (line === '') {
        doc.moveDown(0.4);
        continue;
      }
      // Signature-line rule ("____ ____") and everything else: plain body text.
      doc.font('Helvetica').fontSize(10.5).text(line, { align: 'left' });
    }

    doc.moveDown(1.5);
    doc
      .font('Helvetica-Oblique')
      .fontSize(8.5)
      .fillColor('#777777')
      .text(
        `Rental agreement ID: ${row.id}${row.paid_at ? ` — confirmed paid ${new Date(row.paid_at).toDateString()}` : ''}`,
        { align: 'left' }
      );

    doc.end();
  });
}

module.exports = { renderLeaseAgreementPdf };
