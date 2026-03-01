import 'package:flutter/material.dart';

/// Represents a research paper domain/category.
enum PaperDomain {
  cs,
  engineering,
  math,
  physics,
  chemistry,
  biology,
  medicine,
  environmental,
  economics,
  psychology,
  business,
  dsAi,
  sociology,
  political,
  law,
  interdisciplinary,
  other,
}

class DomainInfo {
  final PaperDomain domain;
  final String id;
  final String label;
  final String icon;
  final String description;
  final Color color;
  final Color badgeBg;
  final List<String> keywords;

  const DomainInfo({
    required this.domain,
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
    required this.color,
    required this.badgeBg,
    required this.keywords,
  });

  static const List<DomainInfo> allDomains = [
    DomainInfo(
      domain: PaperDomain.cs,
      id: 'cs',
      label: 'Computer Science',
      icon: '💻',
      description: 'Computer Science, AI, Cybersecurity, Software Engineering, and more.',
      color: Color(0xFF38BDF8),
      badgeBg: Color(0x3338BDF8),
      keywords: [
        'Artificial Intelligence', 'Machine Learning', 'Cybersecurity',
        'Software Engineering', 'Computer Vision', 'Natural Language Processing',
        'Distributed Systems'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.engineering,
      id: 'engineering',
      label: 'Engineering',
      icon: '⚙️',
      description: 'Mechanical, civil, electrical, aerospace, and robotics engineering.',
      color: Color(0xFFF97316),
      badgeBg: Color(0x33F97316),
      keywords: [
        'Civil Engineering', 'Mechanical Engineering', 'Electrical Engineering',
        'Robotics', 'Aerospace Engineering', 'Materials Engineering'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.math,
      id: 'math',
      label: 'Mathematics',
      icon: '➗',
      description: 'Pure and applied mathematics, statistics, and modeling.',
      color: Color(0xFF6366F1),
      badgeBg: Color(0x336366F1),
      keywords: [
        'Pure Mathematics', 'Applied Mathematics', 'Statistics',
        'Probability', 'Mathematical Modeling'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.physics,
      id: 'physics',
      label: 'Physics',
      icon: '🌌',
      description: 'Quantum physics, astrophysics, optics, and particle physics.',
      color: Color(0xFF8B5CF6),
      badgeBg: Color(0x338B5CF6),
      keywords: [
        'Quantum Physics', 'Astrophysics', 'Particle Physics',
        'Condensed Matter Physics', 'Optics & Photonics'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.chemistry,
      id: 'chemistry',
      label: 'Chemistry',
      icon: '🧪',
      description: 'Organic, inorganic, analytical, and biochemistry.',
      color: Color(0xFF14B8A6),
      badgeBg: Color(0x3314B8A6),
      keywords: [
        'Organic Chemistry', 'Inorganic Chemistry', 'Analytical Chemistry',
        'Biochemistry', 'Materials Chemistry'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.biology,
      id: 'biology',
      label: 'Biology',
      icon: '🌿',
      description: 'Molecular biology, genetics, microbiology, and ecology.',
      color: Color(0xFF22C55E),
      badgeBg: Color(0x3322C55E),
      keywords: [
        'Molecular Biology', 'Genetics', 'Microbiology',
        'Biotechnology', 'Neuroscience', 'Ecology'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.medicine,
      id: 'medicine',
      label: 'Medicine & Healthcare',
      icon: '⚕️',
      description: 'Cardiology, oncology, neurology, and public health.',
      color: Color(0xFFEF4444),
      badgeBg: Color(0x33EF4444),
      keywords: [
        'Cardiology', 'Oncology', 'Neurology',
        'Public Health', 'Epidemiology', 'Clinical Research'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.environmental,
      id: 'environmental',
      label: 'Environmental Science',
      icon: '🌍',
      description: 'Climate science, sustainability, and renewable energy.',
      color: Color(0xFF10B981),
      badgeBg: Color(0x3310B981),
      keywords: [
        'Climate Science', 'Sustainability', 'Renewable Energy',
        'Conservation', 'Water Resource Management'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.economics,
      id: 'economics',
      label: 'Economics',
      icon: '📈',
      description: 'Microeconomics, macroeconomics, finance, and econometrics.',
      color: Color(0xFFEAB308),
      badgeBg: Color(0x33EAB308),
      keywords: [
        'Microeconomics', 'Macroeconomics', 'Econometrics',
        'Development Economics', 'Financial Economics'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.psychology,
      id: 'psychology',
      label: 'Psychology',
      icon: '🧠',
      description: 'Cognitive, clinical, behavioral, and social psychology.',
      color: Color(0xFFEC4899),
      badgeBg: Color(0x33EC4899),
      keywords: [
        'Cognitive Psychology', 'Clinical Psychology',
        'Behavioral Psychology', 'Social Psychology'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.business,
      id: 'business',
      label: 'Business & Management',
      icon: '🏢',
      description: 'Finance, marketing, operations, and entrepreneurship.',
      color: Color(0xFFF59E0B),
      badgeBg: Color(0x33F59E0B),
      keywords: [
        'Finance', 'Marketing', 'Operations Management',
        'Entrepreneurship', 'Supply Chain Management'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.dsAi,
      id: 'ds-ai',
      label: 'Data Science & AI',
      icon: '🤖',
      description: 'Deep learning, big data analytics, and generative AI.',
      color: Color(0xFF7C5CFC),
      badgeBg: Color(0x337C5CFC),
      keywords: [
        'Deep Learning', 'Big Data Analytics', 'Data Engineering',
        'AI Ethics', 'Generative AI'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.sociology,
      id: 'sociology',
      label: 'Sociology',
      icon: '🏛️',
      description: 'Social theory, urban studies, gender studies, and social policy.',
      color: Color(0xFFD946EF),
      badgeBg: Color(0x33D946EF),
      keywords: [
        'Social Theory', 'Urban Studies', 'Gender Studies', 'Social Policy'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.political,
      id: 'political',
      label: 'Political Science',
      icon: '🗳️',
      description: 'International relations, public policy, and comparative politics.',
      color: Color(0xFF06B6D4),
      badgeBg: Color(0x3306B6D4),
      keywords: [
        'International Relations', 'Public Policy',
        'Comparative Politics', 'Governance'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.law,
      id: 'law',
      label: 'Law',
      icon: '⚖️',
      description: 'Constitutional, criminal, corporate, and intellectual property law.',
      color: Color(0xFF64748B),
      badgeBg: Color(0x3364748B),
      keywords: [
        'Constitutional Law', 'Criminal Law', 'Corporate Law',
        'Intellectual Property Law', 'Cyber Law'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.interdisciplinary,
      id: 'interdisciplinary',
      label: 'Interdisciplinary',
      icon: '🔗',
      description: 'Bioinformatics, computational biology, and cognitive science.',
      color: Color(0xFFBE185D),
      badgeBg: Color(0x33BE185D),
      keywords: [
        'Bioinformatics', 'Computational Biology', 'Cognitive Science',
        'Environmental Economics', 'Digital Humanities'
      ],
    ),
    DomainInfo(
      domain: PaperDomain.other,
      id: 'other',
      label: 'Other',
      icon: '🧬',
      description:
          'General computing, interdisciplinary research, and topics not covered by other domains.',
      color: Color(0xFF94A3B8),
      badgeBg: Color(0x3394A3B8),
      keywords: [],
    ),
  ];

  /// Selectable domains (excludes "Other" for onboarding).
  static List<DomainInfo> get selectableDomains =>
      allDomains.where((d) => d.domain != PaperDomain.other).toList();

  /// Look up DomainInfo by PaperDomain enum.
  static DomainInfo getInfo(PaperDomain domain) {
    return allDomains.firstWhere(
      (d) => d.domain == domain,
      orElse: () => allDomains.last,
    );
  }

  /// Look up DomainInfo by string id.
  static DomainInfo getById(String id) {
    return allDomains.firstWhere(
      (d) => d.id == id,
      orElse: () => allDomains.last,
    );
  }

  /// Get multiple DomainInfos by their IDs.
  static List<DomainInfo> getByIds(List<String> ids) {
    return ids.map((id) => getById(id)).toList();
  }

  /// Reverse lookup: find the string id for a PaperDomain enum.
  static String? findIdByDomain(PaperDomain domain) {
    if (domain == PaperDomain.other) return null;
    return allDomains.firstWhere(
      (d) => d.domain == domain,
      orElse: () => allDomains.last,
    ).id;
  }
}
