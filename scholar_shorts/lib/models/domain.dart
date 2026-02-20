import 'package:flutter/material.dart';

/// Represents a research paper domain/category.
enum PaperDomain {
  aiMl,
  cloud,
  cyber,
  webMobile,
  dataScience,
  softwareEng,
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
      domain: PaperDomain.aiMl,
      id: 'ai-ml',
      label: 'AI / ML',
      icon: '🤖',
      description:
          'Artificial intelligence, machine learning, deep learning, neural networks, NLP, computer vision, and generative models.',
      color: Color(0xFF7C5CFC),
      badgeBg: Color(0x337C5CFC),
      keywords: [
        'artificial intelligence', 'machine learning', 'deep learning',
        'neural network', 'natural language processing', 'nlp', 'transformer',
        'large language model', 'llm', 'reinforcement learning',
        'computer vision', 'convolutional', 'recurrent neural',
        'generative adversarial', 'diffusion model', 'gan', 'bert', 'gpt',
        'attention mechanism', 'image recognition', 'object detection',
        'speech recognition', 'sentiment analysis', 'classification',
        'regression', 'clustering', 'feature extraction', 'transfer learning',
      ],
    ),
    DomainInfo(
      domain: PaperDomain.cloud,
      id: 'cloud',
      label: 'Cloud',
      icon: '☁️',
      description:
          'Cloud computing, serverless architecture, microservices, containerization, Kubernetes, distributed systems, and edge computing.',
      color: Color(0xFF38BDF8),
      badgeBg: Color(0x3338BDF8),
      keywords: [
        'cloud computing', 'serverless', 'microservices', 'containerization',
        'kubernetes', 'docker', 'distributed system', 'edge computing',
        'virtualization', 'iaas', 'paas', 'saas', 'cloud native',
        'load balancing', 'auto scaling', 'service mesh', 'cloud migration',
        'multi-cloud', 'hybrid cloud', 'cloud orchestration', 'aws', 'azure',
        'google cloud',
      ],
    ),
    DomainInfo(
      domain: PaperDomain.cyber,
      id: 'cyber',
      label: 'Cyber',
      icon: '🔒',
      description:
          'Cybersecurity, intrusion detection, malware analysis, encryption, network security, penetration testing, and threat intelligence.',
      color: Color(0xFFF43F5E),
      badgeBg: Color(0x33F43F5E),
      keywords: [
        'cybersecurity', 'cyber security', 'intrusion detection', 'malware',
        'encryption', 'cryptography', 'vulnerability', 'network security',
        'penetration testing', 'zero trust', 'firewall', 'phishing',
        'ransomware', 'authentication', 'access control', 'threat detection',
        'anomaly detection for security', 'security audit', 'privacy',
        'data breach', 'ddos', 'denial of service', 'botnet', 'exploit',
        'secure software',
      ],
    ),
    DomainInfo(
      domain: PaperDomain.webMobile,
      id: 'web-mobile',
      label: 'Web & Mobile',
      icon: '🌐',
      description:
          'Web development, mobile applications, frontend frameworks, REST APIs, progressive web apps, and cross-platform development.',
      color: Color(0xFFFB923C),
      badgeBg: Color(0x33FB923C),
      keywords: [
        'web development', 'mobile application', 'frontend', 'rest api',
        'progressive web app', 'responsive design', 'react', 'angular',
        'vue.js', 'flutter', 'swift', 'android', 'ios development',
        'single page application', 'web framework', 'node.js',
        'user interface', 'web service', 'graphql', 'web performance',
        'cross-platform', 'mobile computing', 'hybrid application', 'pwa',
      ],
    ),
    DomainInfo(
      domain: PaperDomain.dataScience,
      id: 'data-science',
      label: 'Data Science',
      icon: '📊',
      description:
          'Data science, big data analytics, data mining, ETL pipelines, statistical analysis, data visualization, and predictive modeling.',
      color: Color(0xFF34D399),
      badgeBg: Color(0x3334D399),
      keywords: [
        'data science', 'big data', 'data mining', 'data analytics', 'etl',
        'data pipeline', 'visualization', 'statistical analysis', 'hadoop',
        'spark', 'data warehouse', 'business intelligence', 'dashboard',
        'exploratory data', 'predictive analytics', 'time series',
        'data engineering', 'data lake', 'streaming data', 'batch processing',
        'data cleaning', 'feature engineering', 'dimensionality reduction',
      ],
    ),
    DomainInfo(
      domain: PaperDomain.softwareEng,
      id: 'software-eng',
      label: 'Software Eng',
      icon: '🛠️',
      description:
          'Software engineering, agile methodologies, DevOps, CI/CD, software architecture, design patterns, and code quality.',
      color: Color(0xFFA78BFA),
      badgeBg: Color(0x33A78BFA),
      keywords: [
        'software engineering', 'agile', 'devops', 'ci/cd',
        'continuous integration', 'continuous delivery', 'code review',
        'software architecture', 'design pattern', 'version control',
        'software testing', 'test driven', 'refactoring',
        'microservice architecture', 'api design', 'software maintenance',
        'technical debt', 'scrum', 'kanban', 'software quality',
        'static analysis', 'code smell', 'software development lifecycle',
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
}
