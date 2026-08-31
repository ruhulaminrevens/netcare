class AppStrings {
  const AppStrings(this.isBangla);

  final bool isBangla;

  String t(String key) => (_values[key]?[isBangla ? 0 : 1]) ?? key;

  static const Map<String, List<String>> _values = {
    'overview': ['ওভারভিউ', 'Overview'],
    'diagnostics': ['ডায়াগনস্টিকস', 'Diagnostics'],
    'history': ['ইতিহাস', 'History'],
    'settings': ['সেটিংস', 'Settings'],
    'speedTest': ['ইন্টারনেট স্পিড টেস্ট', 'Internet speed test'],
    'startTest': ['টেস্ট শুরু করুন', 'Start test'],
    'stopTest': ['টেস্ট বন্ধ করুন', 'Stop test'],
    'ready': ['টেস্টের জন্য প্রস্তুত', 'Ready to test'],
    'latency': ['পিং', 'Ping'],
    'jitter': ['জিটার', 'Jitter'],
    'download': ['ডাউনলোড', 'Download'],
    'upload': ['আপলোড', 'Upload'],
    'packetLoss': ['প্যাকেট লস', 'Packet loss'],
    'server': ['টেস্ট সার্ভার', 'Test server'],
    'provider': ['আইএসপি', 'ISP'],
    'publicIp': ['পাবলিক আইপি', 'Public IP'],
    'localIp': ['লোকাল আইপি', 'Local IP'],
    'gateway': ['গেটওয়ে/রাউটার', 'Gateway/router'],
    'dns': ['ডিএনএস', 'DNS'],
    'quick': ['কুইক', 'Quick'],
    'balanced': ['ব্যালান্সড', 'Balanced'],
    'deep': ['ডিপ', 'Deep'],
    'dataUse': ['আনুমানিক ডাটা ব্যবহার', 'Estimated data use'],
    'networkSnapshot': ['নেটওয়ার্ক অবস্থা', 'Network snapshot'],
    'refresh': ['রিফ্রেশ', 'Refresh'],
    'checking': ['পরীক্ষা চলছে…', 'Checking…'],
    'internet': ['ইন্টারনেট', 'Internet'],
    'available': ['সংযুক্ত', 'Available'],
    'unavailable': ['সংযোগ নেই', 'Unavailable'],
    'tailscale': ['টেইলস্কেল', 'Tailscale'],
    'detected': ['সনাক্ত হয়েছে', 'Detected'],
    'notDetected': ['সনাক্ত হয়নি', 'Not detected'],
    'profile': ['নিজস্ব নেটওয়ার্ক প্রোফাইল', 'Custom network profile'],
    'profileHint': [
      'শুধু নিজের বা পরিচালিত নেটওয়ার্ক পরীক্ষা করুন',
      'Test only networks you own or administer'
    ],
    'profileName': ['প্রোফাইলের নাম', 'Profile name'],
    'switchIp': ['সুইচ আইপি', 'Switch IP'],
    'serverIp': ['সার্ভার আইপি', 'Server IP'],
    'remoteHost': ['রিমোট/Tailscale হোস্ট', 'Remote/Tailscale host'],
    'remotePort': ['রিমোট পোর্ট', 'Remote port'],
    'saveAndRun': ['সংরক্ষণ করে পরীক্ষা করুন', 'Save and run checks'],
    'results': ['পরীক্ষার ফলাফল', 'Check results'],
    'reachable': ['সচল', 'Reachable'],
    'blocked': ['পাওয়া যায়নি', 'Not reachable'],
    'noHistory': ['এখনো কোনো টেস্ট নেই', 'No tests yet'],
    'clearHistory': ['ইতিহাস মুছুন', 'Clear history'],
    'copyReport': ['রিপোর্ট কপি করুন', 'Copy report'],
    'copied': ['রিপোর্ট কপি হয়েছে', 'Report copied'],
    'privacy': ['গোপনীয়তা', 'Privacy'],
    'privacyBody': [
      'কোনো অ্যাকাউন্ট, বিজ্ঞাপন বা ট্র্যাকিং নেই। ফলাফল এই ডিভাইসেই থাকে।',
      'No account, ads, or tracking. Results stay on this device.'
    ],
    'language': ['ভাষা', 'Language'],
    'appearance': ['থিম', 'Appearance'],
    'darkMode': ['ডার্ক মোড', 'Dark mode'],
    'about': ['অ্যাপ সম্পর্কে', 'About'],
    'aboutBody': [
      'Ruhul NetCare হলো Windows ও Android-এর জন্য privacy-first network diagnostic tool।',
      'Ruhul NetCare is a privacy-first network diagnostic tool for Windows and Android.'
    ],
    'cancelled': ['টেস্ট বাতিল হয়েছে', 'Test cancelled'],
    'testFailed': ['টেস্ট সম্পন্ন হয়নি', 'Test failed'],
    'mbps': ['Mbps', 'Mbps'],
    'ms': ['ms', 'ms'],
    'unknown': ['অজানা', 'Unknown'],
    'liveStatus': ['লাইভ স্ট্যাটাস', 'Live status'],
    'runAgain': ['আবার পরীক্ষা করুন', 'Run again'],
    'profileSaved': ['প্রোফাইল সংরক্ষিত হয়েছে', 'Profile saved'],
    'invalidPort': ['সঠিক port দিন', 'Enter a valid port'],
    'version': ['সংস্করণ ১.০.০', 'Version 1.0.0'],
  };
}
