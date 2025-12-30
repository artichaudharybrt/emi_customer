import '../models/help_models.dart';

class HelpController {
  const HelpController();

  List<HelpTopic> getTopics() {
    return const [
      HelpTopic(
        title: 'EMI basics',
        items: [
          'How is my safe EMI limit decided?',
          'When will my first EMI be deducted?',
          'What happens if I pre-close?',
        ],
      ),
      HelpTopic(
        title: 'Managing my locker',
        items: [
          'How do I change my EMI tenure?',
          'Why did my EMI amount change?',
          'Can I remove an item after checkout?',
        ],
      ),
    ];
  }

  List<ContactChannel> getContactChannels() {
    return const [
      ContactChannel(
        title: 'Chat',
        subtitle: 'Start a live chat',
        action: 'Chat now',
      ),
      ContactChannel(
        title: 'Call back',
        subtitle: 'Request a call in 15 min',
        action: 'Request call',
      ),
      ContactChannel(
        title: 'Email',
        subtitle: 'help@emilocker.com',
        action: 'Send email',
      ),
      ContactChannel(
        title: 'WhatsApp',
        subtitle: 'Message support',
        action: 'Start chat',
      ),
    ];
  }

  List<HelpGuide> getGuides() {
    return const [
      HelpGuide(
        title: 'Staying within a safe EMI limit',
        description: 'Why we show usage % and how to use it',
      ),
      HelpGuide(
        title: 'Understanding interest, fees & more',
        description: 'Zero-cost, processing fees, and more',
      ),
      HelpGuide(
        title: 'What if a payment is missed?',
        description: 'Reminders, grace periods, and impact',
      ),
    ];
  }
}

















