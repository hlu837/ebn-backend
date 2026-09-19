/**
 * Standard residential lease agreement template.
 *
 * The owner used to hand-type the "agreement terms" for every single
 * deal (see the old `terms` param on rentalAgreements.sendAgreement).
 * That meant no two agreements read the same way, nothing guaranteed
 * the owner's obligations were even mentioned, and there was no fixed
 * document a tenant could actually be asked to "read and accept" the
 * way one accepts Terms & Conditions.
 *
 * This module is the single place that produces that fixed text. Every
 * agreement sent through the app now gets the *same* clause structure,
 * with only the deal-specific facts (names, address, rent, dates)
 * filled in from data the platform already knows — never re-typed by
 * the owner, so it can't drift from what sendAgreement() actually
 * computed and stored.
 *
 * To swap in a real legal template later (e.g. one drafted by counsel
 * or supplied by the business), this is the only file that needs to
 * change — [buildStandardLeaseTerms] is the sole export the rest of
 * the app calls, and its signature can stay the same.
 */

/** 'Month D, YYYY' in plain English — no external date library needed. */
const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
function formatDate(d) {
  const date = d instanceof Date ? d : new Date(d);
  return `${MONTHS[date.getUTCMonth()]} ${date.getUTCDate()}, ${date.getUTCFullYear()}`;
}

function formatMoney(amount, currency) {
  const n = Number(amount);
  const formatted = Number.isFinite(n) ? n.toLocaleString('en-US', { maximumFractionDigits: 2 }) : String(amount);
  return `${formatted} ${currency}`;
}

/**
 * @param {object} p
 * @param {string} p.ownerName
 * @param {string} p.requesterName
 * @param {string} p.propertyTitle
 * @param {string} [p.addressLine]
 * @param {string} [p.city]
 * @param {number} p.monthlyRent
 * @param {string} p.currency
 * @param {number} p.advanceMonths
 * @param {number} p.totalDue          - advanceMonths * monthlyRent, already computed by the caller
 * @param {number|null} [p.depositAmount]
 * @param {number|null} [p.leaseTermMonths] - null = month-to-month
 * @param {Date} [p.sentDate]          - defaults to now
 * @returns {string} the full agreement text, ready to store in agreement_terms
 */
function buildStandardLeaseTerms({
  ownerName,
  requesterName,
  propertyTitle,
  addressLine,
  city,
  monthlyRent,
  currency,
  advanceMonths,
  totalDue,
  depositAmount,
  leaseTermMonths,
  sentDate,
}) {
  const propertyDescription = [propertyTitle, addressLine, city].filter(Boolean).join('፣ ');
  const termLine = leaseTermMonths
    ? `ይህ ኪራይ ክፍያው ከተረጋገጠበት ቀን ጀምሮ ለ${leaseTermMonths} ወር(ት) የሚቆይ ሲሆን፣ ከዚያ በኋላ በሁለቱም ወገኖች ስምምነት ሊታደስ ይችላል።`
    : `ይህ ኪራይ በወር ላወር (month-to-month) መሰረት የሚቆይ ሲሆን፣ ከዚህ በታች በተገለጸው “የውል ማቋረጥ” አንቀጽ መሰረት አንደኛው ወገን እስከሚያቋርጠው ጊዜ ድረስ ይቀጣል።`;
  const depositLine = depositAmount
    ? `ተመላሽ የሚደረግ የ${formatMoney(depositAmount, currency)} ተቀማጭ ገንዘብ ከዚህ በታች ከተጠቀሰው ቅድሚያ ኪራይ ክፍያ ጋር ተያይዞ ይከፈላል፣ አከራዩም ይህንን ገንዘብ ከመደበኛ ብልጠት ውጪ በሚደርስ ጉዳት ወይም ኪራይ ማብቂያ ላይ ባልተከፈለ ዕዳ ላይ ለመያዝ ይይዘዋል።`
    : `ለዚህ ኪራይ የተለየ ተቀማጭ ገንዘብ አያስፈልግም።`;

  return `የዲጂታል የኪራይ ስምምነት ውል (Rental Service Agreement)
በ${formatDate(sentDate || new Date())} በመድረኩ ላይ የተዘጋጀ።

ወገኖች
  አከራይ፡ ${ownerName}
  ተከራይ፡ ${requesterName}

ንብረት
  ${propertyDescription || propertyTitle}

የኪራይ ክፍያ
የወራዊ ኪራይ ዋጋ ${formatMoney(monthlyRent, currency)} ነው። አከራዩ ${advanceMonths} ወር(ት) ኪራይ በቅድሚያ እንዲከፈል ይጠይቃል፣ በአጠቃላይ ${formatMoney(totalDue, currency)}፣ ተከራዩ ንብረቱን ከመያዙ በፊት መከፈል ያለበት። ይህ ቅድሚያ ክፍያ ካለቀ በኋላ፣ ተከታይ ክፍያዎች በተመሳሳይ የጊዜ ሰሌዳ በሁለቱ ወገኖች መካከል በቀጥታ ይሰማማሉ።

የቆይታ ጊዜ
${termLine}

ተቀማጭ ገንዘብ
${depositLine}

1. መግቢያ እና ስምምነት
ይህ የአከራይ እና ተከራይ የዲጂታል ስምምነት በአፕሊኬሽኑ መድረክ ላይ ባሉ አገልግሎቶች እና ውሎች ተጠቃሚዎች መካከል የሚፈጸም ሕጋዊ ስምምነት (Binding Agreement) ነው። ተከራዩ እና አከራዩ በአፕሊኬሽኑ በኩል ማንኛውንም የኪራይ ግብይት ሲፈጽሙ በዚህ ውል ሁኔታዎች ይስማማሉ።

2. የውሉ ዓላማ
ይህ ስምምነት አከራዩ ንብረቱን (ቤት፣ ንግድ ቦታ፣ ወዘተ) ለተከራዩ በውል ስምምነት ለማስተላለፍ፣ ተከራዩ ደግሞ ለተገለጸው ጊዜ እና ዋጋ ንብረቱን ተቀብሎ ለመጠቀም የሚስማሙበትን ሕጋዊ ማዕቀፍ ይዘረጋል።

3. የክፍያ እና የኮሚሽን ሁኔታዎች
የኪራይ ክፍያው በየወሩ/በተስማሙበት የጊዜ ሰሌዳ መሰረት በቀጥታ በአፕሊኬሽኑ በጸደቁ የክፍያ መንገዶች (ለምሳሌ፡ በባንክ ወይም በዲጂታል ክፍያ) መፈጸም አለበት።
አፕሊኬሽኑ በመድረኩ አማካኝነት ለሚደረጉ ግብይቶች ተስማሚ የሆነ የአገልግሎት ክፍያ ወይም ኮሚሽን ሊወስድ ይችላል።

4. የንብረት አያያዝ እና ኃላፊነት
የአከራይ ግዴታዎች፡ አከራዩ ንብረቱ ሕጋዊ ባለቤት መሆኑን ወይም ንብረቱን ለማከራየት ሙሉ ሕጋዊ መብት እንዳለው ያረጋግጣል። ንብረቱ ለዕለት ተዕለት ኑሮ ወይም ለታለመለት አገልግሎት ምቹ እና ዝግጁ መሆን አለበት።
የተከራይ ግዴታዎች፡ ተከራዩ ንብረቱን እንደ የራሱ ንብረት በመንከባከብ የመጠቀም ግዴታ አለበት። በንብረቱ ላይ የሚደርስ ማንኛውንም ሐሰተኛ ጉዳት ተከራዩ በራሱ ወጪ ይጠግናል ወይም ይተካል።

5. የውል ማቋረጥ እና ማስጠንቀቂያ
ከወገኖች አንዱ ውሉን ማቋረጥ ሲፈልግ ቢያንስ ከ 30 ቀናት በፊት አስቀድሞ በጽሁፍ ወይም በአፕሊኬሽኑ ማሳወቂያ በኩል ማሳወቅ አለበት።
ማንኛኛውንም የውል ግዴታዎች መጣስ ሲከሰት አከራዩ ወይም አፕሊኬሽኑ ውሉን ያለ ቅድመ ማስጠንቀቂያ የማቋረጥ መብቱ የተጠበቀ ነው።

6. የኃላፊነት ገደብ (Limitation of Liability)
ይህ አፕሊኬሽን አከራይን እና ተከራይን የሚያገናኝ መድረክ ብቻ ነው። በአከራዩ እና ተከራዩ መካከል በሚፈጠሩ ማናቸውም ውዝግቦች፣ የክፍያ መዘግየቶች ወይም የንብረት ውድድሮች ላይ አፕሊኬሽኑ ቀጥተኛ ሕጋዊ ኃላፊነትን አይወስድም፤ ሆኖም አስፈላጊውን የውሂብ ማስረጃ ድጋፍ ያደርጋል።

7. ሕግ ተፈጻሚነት
ይህ ስምምነት በኢትዮጵያ ሕግጋት መሠረት ይተረጎማል እንዲሁም ይተገበራል።

_______________________________          _______________________________
የአከራይ ፊርማ / ቀን                              የተከራይ ፊርማ / ቀን
(${ownerName})                             (${requesterName})`;
}

module.exports = { buildStandardLeaseTerms, formatDate, formatMoney };
