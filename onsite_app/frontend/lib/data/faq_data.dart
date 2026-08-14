class FaqItem {
  final String question;
  final String answer;
  const FaqItem(this.question, this.answer);
}

const faqItems = <FaqItem>[
  FaqItem(
    'How does EBN verification work?',
    'You submit a request for the property, vehicle, or piece of machinery you want verified. '
    'The system dispatches it to online field agents nearby, based on priority tier and '
    'availability. An agent accepts, visits the location, and uploads photos, video, and a '
    'report \u2014 usually within hours.',
  ),
  FaqItem(
    'What can I get verified?',
    'Today: residential and commercial property, vehicles, heavy machinery, and land / real '
    'estate. We\u2019re expanding into more asset types as the agent network grows.',
  ),
  FaqItem(
    'How much does a verification cost?',
    'Pricing depends on asset type, location, and how quickly you need the report. You\u2019ll see '
    'an estimate before you confirm a request.',
  ),
  FaqItem(
    'How do I become a field agent?',
    'Sign up and choose the Agent role. New agents start at Bronze tier and can move up to '
    'Silver, Gold, or Diamond based on performance \u2014 higher tiers get priority leads and can '
    'assign work to a team.',
  ),
  FaqItem(
    'Is EBN available outside Addis Ababa?',
    'We\u2019re live in Addis Ababa now, with more cities planned as our agent coverage grows. '
    'Check back or contact us for updates on your area.',
  ),
  FaqItem(
    'How is my data and payment handled?',
    'Reports, photos, and video are tied to your account and only shared with people involved '
    'in your request. Payment and wallet details are covered in your account settings once '
    'you\u2019re signed in.',
  ),
];
