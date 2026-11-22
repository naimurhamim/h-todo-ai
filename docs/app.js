(function () {
  'use strict';

  const GITHUB_LATEST_API = 'https://api.github.com/repos/naimurhamim/h-todo-ai/releases/latest';
  const FALLBACK_RELEASE_URL = 'https://github.com/naimurhamim/h-todo-ai/releases/latest';

  const I18N = {
    en: {
      navExplore: 'Explore App',
      navWhy: 'Why H-TODO AI',
      navDownload: 'Download',
      navDeveloper: 'Developer',
      headerDownload: 'Download',
      heroEyebrow: 'Android App • Free & Open Source',
      heroTitle: 'Turn Raw Notices & Natural Speech into an Exact Daily Plan',
      heroSubtitle:
        'Built with frosted Light and Dark glassmorphism, H-TODO AI extracts assignments, exams, syllabi, and up to 400 recurring tasks in English, Bengali, or Banglish — backed by a 99-alarm rolling exact reminder engine and private Google Drive sync.',
      heroPrimaryCta: 'Download Latest APK',
      heroSecondaryCta: 'Explore Live Interface',
      metricRecurring: 'Recurring Tasks / Cmd',
      metricAlarms: 'Rolling Exact Alarms',
      metricZeroCostVal: 'Free',
      metricZeroCost: 'BYOK & Private Drive',
      exploreKicker: 'Interactive Interface Tour',
      exploreTitle: 'Explore Every Screen Like Running the Real Software',
      exploreDesc:
        'Switch tabs, test Light/Dark glass themes, run AI commands, check tasks off, and inspect every arrowed callout to see where each feature lives and why it works reliably.',
      tabOverview: 'Overview',
      tabPlan: 'Plan Your Day',
      tabAi: 'AI Auto-Plan',
      tabProfile: 'Profile & Security',
      stepPrev: 'Prev',
      stepNext: 'Next',
      stepHint: 'Tap pins or cards to inspect',
      whyKicker: 'Engineered for Reliability',
      whyTitle: 'Why H-TODO AI Stands Out',
      whyDesc:
        'Designed to eliminate missed exams, slow manual form-filling, free AI token timeouts, and privacy compromises.',
      why1Title: '1-Second Recurring & Bulk Rule Engine',
      why1Body:
        'Instead of waiting for slow 80-task JSON outputs, AI generates a compact rule and the app expands up to 400 tasks (366 days) locally — plus bulk delete, reschedule, and instant Undo.',
      why2Title: 'Multilingual Notices & Commands',
      why2Body:
        'Paste raw university notices or type natural instructions in English, Bengali script, or Banglish. Extracts course titles, deadlines, times, and syllabus checklists with smart duplicate merging.',
      why3Title: 'Strict Date-Based 99-Alarm Window',
      why3Body:
        'Custom due times override default alerts so tasks never double-fire. Respects Android OS alarm caps by queueing the soonest 99 exact alarms chronologically and rolling automatically on launch.',
      why4Title: 'Zero-Server Google Drive Sync',
      why4Body:
        'Your tasks stay offline on your phone and sync privately to your personal Google Drive appDataFolder with offline delete tombstones, plus portable JSON Export and Merge/Replace Import.',
      why5Title: '100% Free BYOK + Key Guidebook',
      why5Body:
        'No ads or paywalls. Bring your own free key from Groq (Recommended Fast), Gemini, OpenRouter, xAI Grok, or any custom endpoint using the built-in step-by-step API Key Guidebook.',
      why6Title: 'PIN + Biometric Glass Experience',
      why6Body:
        'Lock your plans and API keys behind a 4-digit PIN and fingerprint unlock on app launch or resume, inside a crafted Light & Dark Glass UI with built-in GitHub update checks.',
      downloadTitle: 'Download H-TODO AI for Android',
      downloadDesc:
        'Install the latest verified release APK directly from GitHub Releases. Includes in-app update checking so future upgrades notify you inside Profile.',
      downloadApkBtn: 'Download Android APK',
      releaseNotesBtn: 'Release Notes',
      sourceRepoBtn: 'GitHub Source',
      quickStepsHeading: '3-Step Quick Start',
      qs1Title: 'Install the APK',
      qs1Body: 'Download the release APK above and allow app installation on your Android device.',
      qs2Title: 'Paste Free API Key',
      qs2Body: 'Open Profile -> Active AI and follow the built-in Guidebook to add a free Groq or Gemini key.',
      qs3Title: 'Auto-Plan & Sync',
      qs3Body: 'Paste class notices or type recurring goals in English or Bengali, then enable optional Google Drive backup.',
      devKicker: 'Developer & Creator',
      devRole: 'Creator of H-TODO AI & Independent Software Developer',
      devBio:
        'Building clean, privacy-respecting productivity and AI-assisted mobile tools focused on fast offline UX, reliable local alarms, and practical student and personal workflows.'
    },
    bn: {
      navExplore: 'অ্যাপ এক্সপ্লোর',
      navWhy: 'কেন সেরা',
      navDownload: 'ডাউনলোড',
      navDeveloper: 'ডেভেলপার',
      headerDownload: 'ডাউনলোড',
      heroEyebrow: 'অ্যান্ড্রয়েড অ্যাপ • সম্পূর্ণ ফ্রি ও ওপেন সোর্স',
      heroTitle: 'যেকোনো নোটিশ বা সাধারণ কথায় তৈরি করুন নিখুঁত দৈনিক প্ল্যান',
      heroSubtitle:
        'আধুনিক লাইট ও ডার্ক গ্লাসমরফিজম ডিজাইনে তৈরি H-TODO AI বাংলা, ইংরেজি বা বাংলিশ নোটিশ থেকে অ্যাসাইনমেন্ট, পরীক্ষা, সিলেবাস এবং এক কমান্ডেই ৪০০টি পর্যন্ত রিকারিং টাস্ক তৈরি করে — সাথে ৯৯-অ্যালার্ম এক্স্যাক্ট রিমাইন্ডার ও প্রাইভেট Google Drive ব্যাকআপ।',
      heroPrimaryCta: 'সর্বশেষ APK ডাউনলোড করুন',
      heroSecondaryCta: 'ইন্টারফেস ডেমো দেখুন',
      metricRecurring: 'টাস্ক প্রতি কমান্ডে',
      metricAlarms: 'রোলিং এক্স্যাক্ট অ্যালার্ম',
      metricZeroCostVal: 'ফ্রি',
      metricZeroCost: 'BYOK ও প্রাইভেট ড্রাইভ',
      exploreKicker: 'ইন্টারেক্টিভ ইন্টারফেস ট্যুর',
      exploreTitle: 'অ্যাপটি চালানোর মতোই প্রতিটি স্ক্রিন ঘুরে দেখুন',
      exploreDesc:
        'ট্যাব পরিবর্তন করুন, লাইট/ডার্ক থিম বদলান, AI কমান্ড চালিয়ে দেখুন এবং প্রতিটি অ্যারো ও বাবল বক্সে ক্লিক করে জানুন কোথায় কী ফিচার আছে ও কেন তা নির্ভরযোগ্য।',
      tabOverview: 'Overview',
      tabPlan: 'Plan Your Day',
      tabAi: 'AI Auto-Plan',
      tabProfile: 'Profile ও নিরাপত্তা',
      stepPrev: 'আগেরটি',
      stepNext: 'পরেরটি',
      stepHint: 'পিন বা কার্ডে ট্যাপ করে দেখুন',
      whyKicker: 'নির্ভরযোগ্যতার জন্য তৈরি',
      whyTitle: 'H-TODO AI কেন অন্যদের চেয়ে আলাদা',
      whyDesc:
        'পরীক্ষা মিস হওয়া, হাতে সময়সূচি টাইপ করার ঝামেলা, ফ্রি AI টোকেন টাইমআউট এবং ডেটা প্রাইভেসির ভয় দূর করতে তৈরি।',
      why1Title: '১ সেকেন্ডে রিকারিং ও বাল্ক রুল ইঞ্জিন',
      why1Body:
        '৮০+ টাস্কের দীর্ঘ JSON-এ আটকে না গিয়ে AI একটি সংক্ষিপ্ত রুল পাঠায় আর অ্যাপ নিজেই ১ সেকেন্ডে ৪০০টি পর্যন্ত টাস্ক (৩৬৬ দিন) বানিয়ে দেয় — সাথে বাল্ক ডিলিট, রিসিডিউল ও ইনস্ট্যান্ট Undo।',
      why2Title: 'বাংলা, ইংরেজি ও বাংলিশ সাপোর্ট',
      why2Body:
        'ক্লাসের নোটিশ পেস্ট করুন বা স্বাভাবিক ভাষায় লিখুন। কোর্স, তারিখ, নির্দিষ্ট সময় ও সিলেবাস চেকলিস্ট আলাদা করে নেয় এবং ডুপ্লিকেট নোটিশ বুদ্ধিমত্তার সাথে মার্জ করে।',
      why3Title: 'সঠিক তারিখের ৯৯-অ্যালার্ম রোলিং ইঞ্জিন',
      why3Body:
        'কাস্টম সময় থাকলে ডিফল্ট অ্যালার্ট বন্ধ থাকে যাতে ডাবল অ্যালার্ম না বাজে। অ্যান্ড্রয়েডের সীমা মেনে আসন্ন ৯৯টি এক্স্যাক্ট অ্যালার্ম আগে থেকে কিউ করে এবং অ্যাপ খুললেই আপনাআপনি আপডেট হয়।',
      why4Title: 'জিরো-সার্ভার প্রাইভেট Google Drive সিঙ্ক',
      why4Body:
        'কোনো থার্ড-পার্টি সার্ভার নেই। সব ডেটা ফোনে এবং আপনার নিজের ব্যক্তিগত Google Drive appDataFolder-এ থাকে; সাথে ডিলিট টম্বস্টোন এবং অফলাইন JSON এক্সপোর্ট ও ইমপোর্ট সুবিধা।',
      why5Title: '১০০% ফ্রি BYOK ও API Key Guidebook',
      why5Body:
        'কোনো বিজ্ঞাপন বা মাসিক চার্জ নেই। অ্যাপের ভেতরের API Key Guidebook দেখে সহজেই ফ্রি Groq (Recommended Fast), Gemini, OpenRouter বা xAI Grok কী সেট করুন।',
      why6Title: 'PIN + ফিঙ্গারপ্রিন্ট ও গ্লাস UI',
      why6Body:
        'অ্যাপ ও API কী সুরক্ষিত রাখতে ৪-ডিজিট PIN ও ফিঙ্গারপ্রিন্ট লক, সাথে স্মুথ Light ও Dark Glass থিম এবং বিল্ট-ইন GitHub আপডেট চেকার।',
      downloadTitle: 'অ্যান্ড্রয়েডের জন্য H-TODO AI ডাউনলোড করুন',
      downloadDesc:
        'GitHub Releases থেকে সরাসরি সর্বশেষ ভেরিফায়েড APK ডাউনলোড করুন। অ্যাপের Profile সেকশন থেকেই ভবিষ্যতের নতুন ভার্সন চেক ও আপডেট করা যায়।',
      downloadApkBtn: 'অ্যান্ড্রয়েড APK ডাউনলোড',
      releaseNotesBtn: 'রিলিজ নোটস',
      sourceRepoBtn: 'GitHub সোর্স',
      quickStepsHeading: '৩ ধাপে দ্রুত শুরু করুন',
      qs1Title: 'APK ইনস্টল করুন',
      qs1Body: 'ওপরের বাটন থেকে APK ডাউনলোড করে আপনার অ্যান্ড্রয়েড ফোনে ইনস্টল করুন।',
      qs2Title: 'ফ্রি API কী দিন',
      qs2Body: 'Profile -> Active AI খুলে ভেতরের Guidebook দেখে একটি ফ্রি Groq বা Gemini কী বসান।',
      qs3Title: 'অটো-প্ল্যান ও সিঙ্ক',
      qs3Body: 'বাংলা বা ইংরেজি নোটিশ ও রিকারিং রুটিন লিখুন, আর চাইলে Google Drive ব্যাকআপ চালু রাখুন।',
      devKicker: 'ডেভেলপার ও নির্মাতা',
      devRole: 'H-TODO AI-এর নির্মাতা ও সফটওয়্যার ডেভেলপার',
      devBio:
        'অফলাইন-ফার্স্ট গতির UI, নির্ভরযোগ্য লোকাল অ্যালার্ম এবং শিক্ষার্থী ও ব্যক্তিগত কাজের জন্য প্রাইভেসি-সুরক্ষিত ও AI-চালিত মোবাইল অ্যাপ্লিকেশন তৈরি করা হচ্ছে।'
    }
  };

  const CALLOUTS = [
    // Tab 0: Overview
    [
      {
        id: 'ov-top-actions',
        side: 'right',
        anchor: 'ov-top-actions',
        where: { en: 'Top Bar Controls', bn: 'টপ বার কন্ট্রোল' },
        title: { en: 'Theme Toggle & Read-Only Bell', bn: 'থিম সুইচ ও রিড-অনলি বেল' },
        body: {
          en: 'Instant Light/Dark Glass switcher paired with a live upcoming Notifications drawer that clears completed tasks automatically.',
          bn: 'এক ক্লিকে লাইট/ডার্ক গ্লাস থিম বদলান; সাথে বেল আইকনে আসন্ন ও ওভারডিউ কাজের রিড-অনলি তালিকা (কমপ্লিট করলে অটো সরে যায়)।'
        }
      },
      {
        id: 'ov-week-strip',
        side: 'left',
        anchor: 'ov-week-strip',
        where: { en: 'Date Navigator', bn: 'ডেট নেভিগেটর' },
        title: { en: '7-Day Interactive Strip', bn: '৭-দিনের ডেট স্ট্রিপ' },
        body: {
          en: 'Orange dots highlight dates with deadlines. Tap any day pill to preview its scheduled tasks right below.',
          bn: 'যেসব দিনে কাজ আছে সেগুলোতে ডট চিহ্ন থাকে। যেকোনো দিনে ট্যাপ করলেই নিচে ওই দিনের টাস্ক দেখা যায়।'
        }
      },
      {
        id: 'ov-progress',
        side: 'left',
        anchor: 'ov-progress',
        where: { en: 'Daily Focus Ring', bn: 'দৈনিক প্রগ্রেস' },
        title: { en: 'Live Ring & Next Up Countdown', bn: 'প্রগ্রেস রিং ও কাউন্টডাউন' },
        body: {
          en: 'Automatically calculates daily completion % and highlights your nearest deadline or custom time alert.',
          bn: 'প্রতিদিন কত শতাংশ কাজ শেষ হয়েছে তার রিং এবং সামনে সবচেয়ে কাছের পরীক্ষা বা কাজের কাউন্টডাউন একসাথে দেখায়।'
        }
      },
      {
        id: 'ov-tasks',
        side: 'right',
        anchor: 'ov-tasks',
        where: { en: 'Smart Filters', bn: 'স্মার্ট ফিল্টার' },
        title: { en: 'Category Filter Chips & Checklists', bn: 'ক্যাটাগরি ফিল্টার ও চেকলিস্ট' },
        body: {
          en: 'Filter by Assignment, Class Test, Exam, or Done. Tap any checkbox to mark complete and update progress live.',
          bn: 'Assignment, Quiz, Exam বা Done ফিল্টার করে কাজ দেখুন; চেকবক্সে টিক দিলে প্রগ্রেস রিং সাথে সাথে আপডেট হয়।'
        }
      }
    ],
    // Tab 1: Plan Your Day
    [
      {
        id: 'pl-view-mode',
        side: 'right',
        anchor: 'pl-view-mode',
        where: { en: 'Layout Switcher', bn: 'ভিউ সুইচার' },
        title: { en: 'Week Grid & Full Timeline View', bn: 'উইক গ্রিড ও ফুল টাইমলাইন' },
        body: {
          en: 'Switch seamlessly between day-by-day grid browsing and a lazy-loaded chronological timeline handling 400+ tasks smoothly.',
          bn: 'সপ্তাহভিত্তিক গ্রিড ভিউ অথবা ৪০০+ টাস্কের জন্য দ্রুতগতির লেজি-লোডেড ফুল টাইমলাইন ভিউতে সহজেই পরিবর্তন করুন।'
        }
      },
      {
        id: 'pl-segmented',
        side: 'left',
        anchor: 'pl-segmented',
        where: { en: 'Status Filter', bn: 'স্ট্যাটাস ফিল্টার' },
        title: { en: 'All Tasks / Completed Segment', bn: 'All Tasks বনাম Completed' },
        body: {
          en: 'Inspect every upcoming task or audit completed work in a single frosted glass pill.',
          bn: 'এক ক্লিকে সব সক্রিয় টাস্ক বা শুধুমাত্র শেষ হওয়া কাজগুলো আলাদা করে দেখুন।'
        }
      },
      {
        id: 'pl-shortcuts',
        side: 'right',
        anchor: 'pl-shortcuts',
        where: { en: 'Quick Actions', bn: 'কুইক অ্যাকশন' },
        title: { en: '1-Tap AI Auto-Plan & Add', bn: 'AI Auto-Plan ও +Add শর্টকাট' },
        body: {
          en: 'Jump straight into natural-language AI scheduling or add a manual task with custom date and exact alarm time.',
          bn: 'সরাসরি AI চ্যাটে গিয়ে রুটিন বানান অথবা ম্যানুয়ালি নির্দিষ্ট তারিখ ও কাস্টম সময় দিয়ে নতুন টাস্ক যোগ করুন।'
        }
      },
      {
        id: 'pl-syllabus',
        side: 'left',
        anchor: 'pl-syllabus',
        where: { en: 'Interactive Card', bn: 'সিলেবাস কার্ড' },
        title: { en: 'Expandable Syllabus Checklists', bn: 'সিলেবাস সাব-টাস্ক চেকলিস্ট' },
        body: {
          en: 'Each exam or assignment stores topic checkboxes parsed by AI so you can track chapter-by-chapter study progress.',
          bn: 'প্রতিটি পরীক্ষা বা অ্যাসাইনমেন্টের ভেতরে AI থেকে পাওয়া সিলেবাসের অধ্যায়গুলো টিক দিয়ে প্রিপারেশন ট্র্যাক করা যায়।'
        }
      }
    ],
    // Tab 2: AI Auto-Plan
    [
      {
        id: 'ai-provider',
        side: 'right',
        anchor: 'ai-provider',
        where: { en: 'Provider Pill', bn: 'AI প্রোভাইডার পিল' },
        title: { en: 'Groq Recommended Fast Engine', bn: 'Groq ফাস্ট ও ফ্রি ইঞ্জিন' },
        body: {
          en: 'Shows your active BYOK provider (Groq, Gemini, OpenRouter, Grok) with automatic model fallback and one-tap switching.',
          bn: 'বর্তমান ফ্রি BYOK প্রোভাইডার ও অটো মডেল ফলব্যাক স্ট্যাটাস দেখায়; ট্যাপ করেই প্রোভাইডার বা কী পরিবর্তন করা যায়।'
        }
      },
      {
        id: 'ai-undo',
        side: 'left',
        anchor: 'ai-undo',
        where: { en: 'Safety Popup', bn: 'সেফটি পপআপ' },
        title: { en: 'Top Floating Undo / OK Banner', bn: 'ওপরের ভাসমান Undo / OK' },
        body: {
          en: 'Every bulk delete or massive recurring creation shows an instant top Undo pill so mistakes are reversed in one tap.',
          bn: 'বাল্ক ডিলিট বা রিকারিং টাস্ক তৈরি করার সাথে সাথে ওপরে Undo বাটন আসে; ভুল হলেই ১ ক্লিকে আগের অবস্থায় ফেরা যায়।'
        }
      },
      {
        id: 'ai-recurring',
        side: 'left',
        anchor: 'ai-recurring',
        where: { en: 'Rule Expansion', bn: 'রুল ইঞ্জিন' },
        title: { en: '1-Second 400-Task Rule Engine', bn: '১ সেকেন্ডে ৪০০ টাস্ক অটোমেশন' },
        body: {
          en: 'Prompts like "Next 40 days twice daily" return a tiny JSON rule that expands locally — zero free-API token limits or timeouts.',
          bn: 'আগামী ৪০ দিন বা ৬ মাসের দৈনিক রুটিন চাইলে ফ্রি AI-তে টোকেন শেষ না হয়েই অ্যাপ নিজেই সর্বোচ্চ ৪০০টি টাস্ক ১ সেকেন্ডে সাজিয়ে দেয়।'
        }
      },
      {
        id: 'ai-input',
        side: 'right',
        anchor: 'ai-input',
        where: { en: 'Chat Composer', bn: 'মেসেজ বক্স' },
        title: { en: 'English, Bengali & Banglish Input', bn: 'বাংলা, ইংরেজি ও বাংলিশ কমান্ড' },
        body: {
          en: 'Paste notices or type bulk reschedule/delete commands in any language. Try tapping the demo prompt chips inside the phone!',
          bn: 'যেকোনো ভাষায় নোটিশ পেস্ট করুন বা রিসিডিউল/ডিলিট বলুন। ওপরের ডেমো চিপগুলোতে ক্লিক করে এখনই পরীক্ষা করে দেখুন!'
        }
      }
    ],
    // Tab 3: Profile & Security
    [
      {
        id: 'pr-drive',
        side: 'left',
        anchor: 'pr-drive',
        where: { en: 'Cloud & Offline Sync', bn: 'ড্রাইভ ও অফলাইন সিঙ্ক' },
        title: { en: 'Private Google Drive & JSON', bn: 'প্রাইভেট Drive ও JSON ব্যাকআপ' },
        body: {
          en: 'Auto-backs up to your personal Drive appDataFolder with offline delete tombstones, plus portable JSON Export/Import.',
          bn: 'আপনার নিজস্ব Google Drive appDataFolder-এ অটো ব্যাকআপ হয় (ডিলিট টম্বস্টোন সহ), সাথে অফলাইন JSON এক্সপোর্ট ও ইমপোর্ট।'
        }
      },
      {
        id: 'pr-apikeys',
        side: 'left',
        anchor: 'pr-apikeys',
        where: { en: 'BYOK Settings', bn: 'API কী গাইডবুক' },
        title: { en: 'Built-In API Key Guidebook', bn: 'বিল্ট-ইন API Key Guidebook' },
        body: {
          en: 'Explains how to grab free Groq or Gemini keys step-by-step and tests models live inside the app.',
          bn: 'কীভাবে সম্পূর্ণ ফ্রিতে Groq বা Gemini API কী নিতে হয় তার ধাপে ধাপে গাইড এবং লাইভ মডেল ফেচ সুবিধা।'
        }
      },
      {
        id: 'pr-reminders',
        side: 'right',
        anchor: 'pr-reminders',
        where: { en: 'Alarm Engine', bn: 'অ্যালার্ম ইঞ্জিন' },
        title: { en: '99-Alarm Rolling Exact Window', bn: '৯৯-অ্যালার্ম রোলিং ইঞ্জিন' },
        body: {
          en: 'Custom task times disable default 4 PM / 10 PM alerts automatically. Tap Test 10s inside the phone to trigger a sample alert.',
          bn: 'টাস্কে নির্দিষ্ট সময় থাকলে ডিফল্ট অ্যালার্ট বন্ধ থাকে। আসন্ন ৯৯টি এক্স্যাক্ট অ্যালার্ম অটো-রোল হয়; ফোনের ভেতরের Test 10s বাটন চেপে দেখুন।'
        }
      },
      {
        id: 'pr-security',
        side: 'right',
        anchor: 'pr-security',
        where: { en: 'Device Privacy', bn: 'ডিভাইস প্রাইভেসি' },
        title: { en: '4-Digit PIN & Fingerprint Lock', bn: 'PIN + ফিঙ্গারপ্রিন্ট লক' },
        body: {
          en: 'Auto-locks on launch and resume so your personal schedules and API keys stay protected offline.',
          bn: 'অ্যাপ চালু ও মিনিমাইজ থেকে ফিরলেই ৪-ডিজিট PIN বা ফিঙ্গারপ্রিন্ট দিয়ে সুরক্ষিত রাখে আপনার সব ডেটা ও API কী।'
        }
      }
    ]
  ];

  // App simulator state
  const state = {
    lang: 'en',
    theme: 'dark',
    tab: 0,
    activeCalloutId: CALLOUTS[0][0].id,
    selectedDayIdx: 2,
    overviewFilter: 'all',
    planMode: 'week', // 'week' | 'timeline'
    planCompletedOnly: false,
    notifOpen: false,
    undoBanner: null, // { textEn, textBn, onUndo }
    toastMsg: null,
    toastTimer: null,
    pinEnabled: true,
    bioEnabled: true,
    tasks: [
      {
        id: 't1',
        dayIdx: 2,
        dateLabel: 'Today, Nov 22',
        title: 'IRE 415 — Computer Vision Class Test',
        type: 'classTest',
        typeLabel: 'Class Test',
        time: '10:00 AM',
        customTime: true,
        done: false,
        syllabus: [
          { text: 'Image Enhancement & Histogram', checked: true },
          { text: 'Gaussian & Median Filtering', checked: false },
          { text: 'Morphological Operations', checked: false }
        ]
      },
      {
        id: 't2',
        dayIdx: 2,
        dateLabel: 'Today, Nov 22',
        title: 'AI Morning Study Session (Daily)',
        type: 'study',
        typeLabel: 'Recurring',
        time: '08:00 AM',
        customTime: true,
        done: true,
        syllabus: []
      },
      {
        id: 't3',
        dayIdx: 3,
        dateLabel: 'Sun, Nov 23',
        title: 'CSE 301 — Database Normalization Assignment',
        type: 'assignment',
        typeLabel: 'Assignment',
        time: 'Default (4 PM / 10 PM)',
        customTime: false,
        done: false,
        syllabus: [
          { text: '1NF to BCNF Decomposition PDF', checked: false }
        ]
      },
      {
        id: 't4',
        dayIdx: 5,
        dateLabel: 'Tue, Nov 25',
        title: 'Midterm Exam — Distributed Systems',
        type: 'exam',
        typeLabel: 'Exam',
        time: '09:30 AM',
        customTime: true,
        done: false,
        syllabus: [
          { text: 'Lamport Clocks & Vector Timestamps', checked: true },
          { text: 'Raft Consensus Walkthrough', checked: false }
        ]
      }
    ],
    chatHistory: [
      {
        sender: 'ai',
        textEn: 'Paste any class notice in English, Bengali, or Banglish — or ask for recurring daily routines.',
        textBn: 'বাংলা, ইংরেজি বা বাংলিশে যেকোনো নোটিশ পেস্ট করুন অথবা দৈনিক রিকারিং রুটিন লিখুন।',
        batch: null
      }
    ],
    snapshotBeforeAi: null
  };

  const WEEK_DAYS = [
    { label: 'Thu', num: '20' },
    { label: 'Fri', num: '21' },
    { label: 'Sat', num: '22' },
    { label: 'Sun', num: '23' },
    { label: 'Mon', num: '24' },
    { label: 'Tue', num: '25' },
    { label: 'Wed', num: '26' }
  ];

  // Cached DOM nodes
  const htmlEl = document.documentElement;
  const exploreStage = document.getElementById('explore-stage');
  const arrowSvg = document.getElementById('callout-arrows');
  const leftCol = document.getElementById('callout-left');
  const rightCol = document.getElementById('callout-right');
  const mobileList = document.getElementById('mobile-callout-list');
  const phoneViewport = document.getElementById('phone-viewport');
  const phoneOverlay = document.getElementById('phone-overlay-host');
  const stepBadgeText = document.getElementById('step-badge-text');

  function escapeHtml(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function applyStaticI18n() {
    const dict = I18N[state.lang];
    document.querySelectorAll('[data-i18n]').forEach((el) => {
      const key = el.getAttribute('data-i18n');
      if (dict[key] !== undefined) {
        el.textContent = dict[key];
      }
    });
  }

  function setLanguage(lang) {
    if (state.lang === lang) return;
    state.lang = lang;
    htmlEl.setAttribute('data-lang', lang);
    htmlEl.setAttribute('lang', lang === 'bn' ? 'bn' : 'en');
    document.querySelectorAll('[data-set-lang]').forEach((btn) => {
      btn.classList.toggle('is-active', btn.getAttribute('data-set-lang') === lang);
    });
    applyStaticI18n();
    renderAll(false);
  }

  function toggleTheme() {
    state.theme = state.theme === 'dark' ? 'light' : 'dark';
    htmlEl.setAttribute('data-theme', state.theme);
    const metaTheme = document.querySelector('meta[name="theme-color"]');
    if (metaTheme) {
      metaTheme.setAttribute('content', state.theme === 'dark' ? '#0B0E14' : '#ECEFF4');
    }
    renderPhone();
    scheduleArrowUpdate();
  }

  function showToast(msgEn, msgBn) {
    clearTimeout(state.toastTimer);
    state.toastMsg = state.lang === 'bn' ? msgBn : msgEn;
    renderOverlay();
    state.toastTimer = setTimeout(() => {
      state.toastMsg = null;
      renderOverlay();
    }, 3600);
  }

  function switchTab(nextTab) {
    const tabIdx = Number(nextTab);
    if (Number.isNaN(tabIdx) || tabIdx < 0 || tabIdx > 3) return;
    state.tab = tabIdx;
    state.notifOpen = false;
    state.activeCalloutId = CALLOUTS[tabIdx][0].id;
    document.querySelectorAll('.screen-tab').forEach((btn) => {
      const active = Number(btn.getAttribute('data-tab')) === tabIdx;
      btn.classList.toggle('is-active', active);
      btn.setAttribute('aria-selected', String(active));
    });
    document.querySelectorAll('.dock-btn').forEach((btn) => {
      btn.classList.toggle('is-active', Number(btn.getAttribute('data-tab')) === tabIdx);
    });
    renderAll(true);
  }

  function selectCallout(calloutId, scrollIntoPhone) {
    state.activeCalloutId = calloutId;
    syncCalloutHighlight();
    if (scrollIntoPhone) {
      const item = CALLOUTS[state.tab].find((c) => c.id === calloutId);
      if (item) {
        const target = phoneViewport.querySelector(`[data-anchor="${item.anchor}"]`);
        if (target) {
          target.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }
      }
    }
    drawArrows();
  }

  function syncCalloutHighlight() {
    const tabCallouts = CALLOUTS[state.tab];
    const activeIdx = Math.max(
      0,
      tabCallouts.findIndex((c) => c.id === state.activeCalloutId)
    );
    const activeItem = tabCallouts[activeIdx];
    stepBadgeText.textContent = `${activeIdx + 1} / ${tabCallouts.length}`;

    document.querySelectorAll('.callout-bubble').forEach((card) => {
      card.classList.toggle('is-active', card.getAttribute('data-callout-id') === activeItem.id);
    });

    phoneViewport.querySelectorAll('[data-anchor]').forEach((el) => {
      const match = el.getAttribute('data-anchor') === activeItem.anchor;
      el.classList.toggle('is-highlighted', match);
      const pin = el.querySelector('.anchor-pin');
      if (pin) pin.classList.toggle('is-active', match);
    });
  }

  function createCalloutCard(item, num) {
    const activeClass = item.id === state.activeCalloutId ? ' is-active' : '';
    return `
      <button type="button" class="callout-bubble${activeClass}" data-callout-id="${item.id}" data-anchor-ref="${item.anchor}">
        <div class="callout-head">
          <div class="callout-badge-row">
            <span class="callout-num">${num}</span>
            <span class="callout-where">${escapeHtml(item.where[state.lang])}</span>
          </div>
        </div>
        <h3 class="callout-title">${escapeHtml(item.title[state.lang])}</h3>
        <p class="callout-body">${escapeHtml(item.body[state.lang])}</p>
      </button>
    `;
  }

  function renderCalloutColumns() {
    const list = CALLOUTS[state.tab];
    leftCol.innerHTML = '';
    rightCol.innerHTML = '';
    mobileList.innerHTML = '';

    list.forEach((item, idx) => {
      const html = createCalloutCard(item, idx + 1);
      if (item.side === 'left') {
        leftCol.insertAdjacentHTML('beforeend', html);
      } else {
        rightCol.insertAdjacentHTML('beforeend', html);
      }
      mobileList.insertAdjacentHTML('beforeend', html);
    });

    document.querySelectorAll('.callout-bubble').forEach((card) => {
      card.addEventListener('click', () => {
        selectCallout(card.getAttribute('data-callout-id'), true);
      });
      card.addEventListener('mouseenter', () => {
        if (window.innerWidth >= 1024) {
          selectCallout(card.getAttribute('data-callout-id'), false);
        }
      });
    });
  }

  function renderOverlay() {
    let html = '';

    if (state.undoBanner) {
      const msg = state.lang === 'bn' ? state.undoBanner.textBn : state.undoBanner.textEn;
      html += `
        <div class="phone-undo-popup" role="status">
          <span class="undo-text">${escapeHtml(msg)}</span>
          <div class="undo-btns">
            <button type="button" class="undo-pill-btn is-undo" id="sim-undo-btn">Undo</button>
            <button type="button" class="undo-pill-btn is-ok" id="sim-ok-btn">OK</button>
          </div>
        </div>
      `;
    } else if (state.toastMsg) {
      html += `
        <div class="phone-undo-popup" role="status">
          <span class="undo-text">${escapeHtml(state.toastMsg)}</span>
          <div class="undo-btns">
            <button type="button" class="undo-pill-btn is-ok" id="sim-toast-close">OK</button>
          </div>
        </div>
      `;
    }

    if (state.notifOpen && state.tab === 0) {
      const pending = state.tasks.filter((t) => !t.done);
      html += `
        <div class="phone-notif-drawer" role="dialog" aria-label="Upcoming Notifications">
          <div class="notif-drawer-head">
            <strong>${state.lang === 'bn' ? 'আসন্ন নোটিফিকেশন' : 'Upcoming Notifications'} (${pending.length})</strong>
            <button type="button" class="undo-pill-btn is-ok" id="close-notif-drawer">${state.lang === 'bn' ? 'বন্ধ' : 'Close'}</button>
          </div>
          <p class="notif-drawer-note">
            ${
              state.lang === 'bn'
                ? 'রিড-অনলি প্যানেল: টাস্ক কমপ্লিট করলেই অটো মুছে যায়।'
                : 'Read-only panel: tasks disappear automatically when completed.'
            }
          </p>
          ${
            pending.length === 0
              ? `<div class="notif-row">${state.lang === 'bn' ? 'সব কাজ শেষ!' : 'All caught up!'}</div>`
              : pending
                  .slice(0, 4)
                  .map(
                    (t) => `
                <div class="notif-row">
                  <span class="notif-row-title">${escapeHtml(t.title)}</span>
                  <span class="notif-row-meta">${escapeHtml(t.dateLabel)} • ${escapeHtml(t.time)}</span>
                </div>
              `
                  )
                  .join('')
          }
        </div>
      `;
    }

    phoneOverlay.innerHTML = html;

    const undoBtn = document.getElementById('sim-undo-btn');
    if (undoBtn && state.undoBanner) {
      undoBtn.addEventListener('click', () => {
        if (state.undoBanner.onUndo) state.undoBanner.onUndo();
        state.undoBanner = null;
        if (state.tab === 2) {
          state.chatHistory.push({
            sender: 'ai',
            textEn: 'Undone cleanly: restored previous schedule state.',
            textBn: 'বাতিল করা হয়েছে: আগের টাস্ক তালিকা পুনরুদ্ধার করা হয়েছে।',
            batch: null
          });
        }
        renderPhone();
        renderOverlay();
        phoneViewport.scrollTop = phoneViewport.scrollHeight;
        showToast('Previous state restored!', 'আগের অবস্থা ফিরিয়ে আনা হয়েছে!');
        scheduleArrowUpdate();
      });
    }

    const okBtn = document.getElementById('sim-ok-btn');
    if (okBtn) {
      okBtn.addEventListener('click', () => {
        state.undoBanner = null;
        renderOverlay();
      });
    }

    const toastClose = document.getElementById('sim-toast-close');
    if (toastClose) {
      toastClose.addEventListener('click', () => {
        state.toastMsg = null;
        renderOverlay();
      });
    }

    const closeNotif = document.getElementById('close-notif-drawer');
    if (closeNotif) {
      closeNotif.addEventListener('click', () => {
        state.notifOpen = false;
        renderOverlay();
      });
    }
  }

  function pinBadge(anchorId) {
    const idx = CALLOUTS[state.tab].findIndex((c) => c.anchor === anchorId);
    if (idx === -1) return '';
    return `<span role="button" tabindex="0" class="anchor-pin" data-pin-callout="${CALLOUTS[state.tab][idx].id}" aria-label="Feature ${idx + 1}">${idx + 1}</span>`;
  }

  function renderOverviewScreen() {
    const dayTasks = state.tasks.filter((t) => t.dayIdx === state.selectedDayIdx);
    const total = dayTasks.length || state.tasks.length;
    const completed = (dayTasks.length ? dayTasks : state.tasks).filter((t) => t.done).length;
    const pct = total === 0 ? 0 : Math.round((completed / total) * 100);
    const circ = 2 * Math.PI * 27;
    const dashOffset = circ - (pct / 100) * circ;
    const nextTask = state.tasks.find((t) => !t.done);
    const pendingCount = state.tasks.filter((t) => !t.done).length;

    const visibleTasks = (dayTasks.length ? dayTasks : state.tasks).filter((t) => {
      if (state.overviewFilter === 'done') return t.done;
      if (state.overviewFilter === 'all') return true;
      return t.type === state.overviewFilter;
    });

    return `
      <div class="app-topbar">
        <button type="button" class="app-avatar-btn" data-jump-tab="3" title="Open Profile">NR</button>
        <h3 class="app-screen-title">Overview</h3>
        <div class="app-top-actions" data-anchor="ov-top-actions">
          ${pinBadge('ov-top-actions')}
          <button type="button" class="app-circle-btn" id="phone-theme-btn" title="Toggle Glass Theme" aria-label="Toggle theme">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
              ${
                state.theme === 'dark'
                  ? '<circle cx="12" cy="12" r="4"></circle><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2"></path>'
                  : '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>'
              }
            </svg>
          </button>
          <button type="button" class="app-circle-btn" id="phone-bell-btn" title="Notifications" aria-label="Notifications">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
              <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path>
              <path d="M13.73 21a2 2 0 0 1-3.46 0"></path>
            </svg>
            <span class="bell-badge">${pendingCount}</span>
          </button>
        </div>
      </div>

      <div class="week-strip" data-anchor="ov-week-strip">
        ${pinBadge('ov-week-strip')}
        ${WEEK_DAYS.map((d, idx) => {
          const hasTasks = state.tasks.some((t) => t.dayIdx === idx && !t.done);
          return `
            <button type="button" class="day-pill${state.selectedDayIdx === idx ? ' is-selected' : ''}" data-select-day="${idx}">
              <span>${d.label}</span>
              <strong>${d.num}</strong>
              ${hasTasks ? '<span class="day-dot"></span>' : ''}
            </button>
          `;
        }).join('')}
      </div>

      <div class="progress-next-grid" data-anchor="ov-progress">
        ${pinBadge('ov-progress')}
        <div class="ring-box">
          <svg class="ring-svg" viewBox="0 0 68 68">
            <circle class="ring-track" cx="34" cy="34" r="27"></circle>
            <circle class="ring-fill" cx="34" cy="34" r="27" stroke-dasharray="${circ.toFixed(1)}" stroke-dashoffset="${dashOffset.toFixed(1)}"></circle>
            <text x="34" y="38" text-anchor="middle" class="ring-pct">${pct}%</text>
          </svg>
          <span class="ring-cap">${completed}/${total} Done</span>
        </div>
        <div class="next-up-card">
          <span class="next-up-kicker">Next Up</span>
          <p class="next-up-title">${nextTask ? escapeHtml(nextTask.title) : 'No pending tasks'}</p>
          <span class="next-up-meta">${nextTask ? `${escapeHtml(nextTask.dateLabel)} • ${escapeHtml(nextTask.time)}` : 'Ready for new plan'}</span>
        </div>
      </div>

      <div data-anchor="ov-tasks">
        ${pinBadge('ov-tasks')}
        <div class="filter-row">
          ${[
            ['all', 'All'],
            ['assignment', 'Assign'],
            ['classTest', 'Quiz'],
            ['exam', 'Exam'],
            ['done', 'Done']
          ]
            .map(
              ([val, lbl]) => `
            <button type="button" class="chip-btn${state.overviewFilter === val ? ' is-active' : ''}" data-ov-filter="${val}">${lbl}</button>
          `
            )
            .join('')}
        </div>
        ${
          visibleTasks.length === 0
            ? `<div class="app-card" style="text-align:center;font-size:0.78rem;color:var(--text-secondary);">No matching tasks for this day.</div>`
            : visibleTasks
                .map(
                  (t) => `
              <div class="task-item-card${t.done ? ' is-done' : ''}">
                <button type="button" class="task-check-btn" data-toggle-task="${t.id}" aria-label="Toggle complete">
                  ${t.done ? '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="3"><polyline points="20 6 9 17 4 12"></polyline></svg>' : ''}
                </button>
                <div class="task-item-body">
                  <div class="task-item-title">${escapeHtml(t.title)}</div>
                  <div class="task-meta-pills">
                    <span class="meta-pill is-accent">${escapeHtml(t.typeLabel)}</span>
                    <span class="meta-pill">${escapeHtml(t.time)}</span>
                    ${t.syllabus.length ? `<span class="meta-pill">${t.syllabus.length} Syllabus</span>` : ''}
                  </div>
                </div>
              </div>
            `
                )
                .join('')
        }
      </div>
    `;
  }

  function renderPlanScreen() {
    const filtered = state.tasks.filter((t) => (state.planCompletedOnly ? t.done : true));
    const listToShow =
      state.planMode === 'timeline'
        ? filtered
        : filtered.filter((t) => t.dayIdx === state.selectedDayIdx).length > 0
        ? filtered.filter((t) => t.dayIdx === state.selectedDayIdx)
        : filtered;

    return `
      <div class="plan-header-row">
        <h3 class="app-screen-title">Plan Your Day</h3>
        <div class="view-mode-group" data-anchor="pl-view-mode">
          ${pinBadge('pl-view-mode')}
          <button type="button" class="view-mode-btn${state.planMode === 'week' ? ' is-active' : ''}" data-plan-mode="week">Week Grid</button>
          <button type="button" class="view-mode-btn${state.planMode === 'timeline' ? ' is-active' : ''}" data-plan-mode="timeline">Timeline</button>
        </div>
      </div>

      <div class="plan-actions-row">
        <div class="seg-control" data-anchor="pl-segmented">
          ${pinBadge('pl-segmented')}
          <button type="button" class="seg-btn${!state.planCompletedOnly ? ' is-active' : ''}" data-plan-done="0">All Tasks</button>
          <button type="button" class="seg-btn${state.planCompletedOnly ? ' is-active' : ''}" data-plan-done="1">Completed</button>
        </div>
        <div style="display:flex;gap:5px;" data-anchor="pl-shortcuts">
          ${pinBadge('pl-shortcuts')}
          <button type="button" class="shortcut-pill" data-jump-tab="2">AI Plan</button>
          <button type="button" class="shortcut-pill" id="plan-quick-add">+ Add</button>
        </div>
      </div>

      <div data-anchor="pl-syllabus">
        ${pinBadge('pl-syllabus')}
        ${listToShow
          .map((t, idx) => {
            const showHeader = state.planMode === 'timeline' && (idx === 0 || listToShow[idx - 1].dateLabel !== t.dateLabel);
            return `
              ${showHeader ? `<div class="timeline-date-label">${escapeHtml(t.dateLabel)}</div>` : ''}
              <div class="task-item-card${t.done ? ' is-done' : ''}" style="flex-direction:column;">
                <div style="display:flex;gap:9px;width:100%;align-items:flex-start;">
                  <button type="button" class="task-check-btn" data-toggle-task="${t.id}" aria-label="Toggle complete">
                    ${t.done ? '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="3"><polyline points="20 6 9 17 4 12"></polyline></svg>' : ''}
                  </button>
                  <div class="task-item-body">
                    <div class="task-item-title">${escapeHtml(t.title)}</div>
                    <div class="task-meta-pills">
                      <span class="meta-pill is-accent">${escapeHtml(t.typeLabel)}</span>
                      <span class="meta-pill">${escapeHtml(t.dateLabel)}</span>
                      <span class="meta-pill">${escapeHtml(t.time)}</span>
                    </div>
                  </div>
                </div>
                ${
                  t.syllabus.length
                    ? `<div class="syllabus-list" style="width:100%;">
                        ${t.syllabus
                          .map(
                            (s, sIdx) => `
                          <label class="syl-item${s.checked ? ' is-checked' : ''}">
                            <input type="checkbox" ${s.checked ? 'checked' : ''} data-toggle-syl="${t.id}:${sIdx}" />
                            <span>${escapeHtml(s.text)}</span>
                          </label>
                        `
                          )
                          .join('')}
                      </div>`
                    : ''
                }
              </div>
            `;
          })
          .join('')}
      </div>
    `;
  }

  function renderAiChatScreen() {
    return `
      <div class="app-topbar">
        <h3 class="app-screen-title">AI Auto-Plan</h3>
        <button type="button" class="provider-badge-btn" data-anchor="ai-provider" data-jump-tab="3">
          ${pinBadge('ai-provider')}
          <span class="provider-dot"></span>
          <span>Groq • Fast</span>
        </button>
      </div>

      <div class="app-card" data-anchor="ai-undo" style="padding:9px 11px;">
        ${pinBadge('ai-undo')}
        <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:0.72rem;">
          <span><strong>Undo Protection:</strong> Bulk actions trigger a top Undo/OK bar.</span>
          <button type="button" class="mini-action-btn" id="demo-undo-preview">Preview</button>
        </div>
      </div>

      <div class="chat-stream" data-anchor="ai-recurring">
        ${pinBadge('ai-recurring')}
        ${state.chatHistory
          .map((msg) => {
            const txt = state.lang === 'bn' ? msg.textBn : msg.textEn;
            const batchHtml = msg.batch
              ? `<div class="batch-preview-box">
                  ${msg.batch.items
                    .map(
                      (row) => `
                    <div class="batch-item-row">
                      <span>${escapeHtml(row.title)}</span>
                      <span style="color:var(--primary);font-weight:700;">${escapeHtml(row.time)}</span>
                    </div>
                  `
                    )
                    .join('')}
                  ${msg.batch.moreCount > 0 ? `<div class="batch-more">+ ${msg.batch.moreCount} more tasks in Plan</div>` : ''}
                </div>`
              : '';
            return `
              <div class="chat-bubble ${msg.sender === 'user' ? 'is-user' : 'is-ai'}">
                <div>${escapeHtml(txt)}</div>
                ${batchHtml}
              </div>
            `;
          })
          .join('')}
      </div>

      <div data-anchor="ai-input">
        ${pinBadge('ai-input')}
        <div class="ai-prompt-chips">
          <button type="button" class="prompt-chip" data-demo-cmd="recurring">Next 40d: 8 AM &amp; 9 PM Daily</button>
          <button type="button" class="prompt-chip" data-demo-cmd="bengali">কাল ১০টায় CSE কুইজ</button>
          <button type="button" class="prompt-chip" data-demo-cmd="bulk_delete">Bulk Delete &amp; Undo</button>
        </div>
        <form class="ai-input-bar" id="sim-ai-form">
          <input type="text" id="sim-ai-input" placeholder="Paste notice or recurring rule..." aria-label="Simulated AI Prompt Input" />
          <button type="submit" class="ai-send-btn">Plan</button>
        </form>
      </div>
    `;
  }

  function renderProfileScreen() {
    return `
      <div class="app-topbar">
        <h3 class="app-screen-title">Profile</h3>
        <span class="version-pill" data-release-tag>v1.0.8</span>
      </div>

      <div class="app-card app-card-elevated" data-anchor="pr-drive">
        ${pinBadge('pr-drive')}
        <div class="profile-drive-row">
          <img src="assets/Naimur_Hamim.jpg" alt="Profile" width="42" height="42" style="border-radius:12px;object-fit:cover;" />
          <div>
            <strong>Google Drive Sync Active</strong>
            <span>Private appDataFolder + Offline JSON Backup</span>
          </div>
        </div>
        <div style="display:flex;gap:6px;margin-top:9px;">
          <button type="button" class="mini-action-btn" id="sim-drive-sync">Backup Now</button>
          <button type="button" class="mini-action-btn" id="sim-json-export">Export JSON</button>
        </div>
      </div>

      <div class="ai-gradient-card" data-anchor="pr-apikeys">
        ${pinBadge('pr-apikeys')}
        <div class="setting-row-head">
          <strong>Active AI: Groq (Recommended)</strong>
          <span class="version-pill">Free BYOK</span>
        </div>
        <p class="setting-sub">Built-in API Key Guidebook + live model discovery for Groq, Gemini, OpenRouter &amp; Grok.</p>
      </div>

      <div class="app-card app-card-elevated" data-anchor="pr-reminders">
        ${pinBadge('pr-reminders')}
        <div class="setting-row-head">
          <strong>Reminders (99-Alarm Rolling)</strong>
          <button type="button" class="mini-action-btn" id="sim-test-alarm">Test 10s</button>
        </div>
        <p class="setting-sub">Day-before 4:00 PM &amp; Due-day 10:00 PM defaults. Custom task times disable defaults.</p>
      </div>

      <div class="app-card app-card-elevated" data-anchor="pr-security">
        ${pinBadge('pr-security')}
        <strong style="font-size:0.8rem;">Privacy &amp; App Lock</strong>
        <div class="mini-stat-row">
          <span>4-Digit Pass Lock</span>
          <button type="button" class="toggle-switch${state.pinEnabled ? ' is-on' : ''}" id="toggle-pin" aria-label="Toggle 4-Digit Pass Lock"></button>
        </div>
        <div class="mini-stat-row">
          <span>Fingerprint Unlock</span>
          <button type="button" class="toggle-switch${state.bioEnabled ? ' is-on' : ''}" id="toggle-bio" aria-label="Toggle Fingerprint Unlock"></button>
        </div>
      </div>
    `;
  }

  function runAiCommand(kind, rawText) {
    if (kind === 'recurring') {
      state.snapshotBeforeAi = JSON.parse(JSON.stringify(state.tasks));
      state.chatHistory.push({
        sender: 'user',
        textEn: 'Next 40 days: 8:00 AM Study and 9:00 PM Revision every day',
        textBn: 'আগামী ৪০ দিন প্রতিদিন সকাল ৮টায় Study ও রাত ৯টায় Revision'
      });
      state.tasks.unshift({
        id: 't_rec_' + Date.now(),
        dayIdx: 2,
        dateLabel: 'Next 40 Days',
        title: 'Daily Study & Night Revision (80 Tasks)',
        type: 'study',
        typeLabel: 'Series',
        time: '08:00 AM / 09:00 PM',
        customTime: true,
        done: false,
        syllabus: []
      });
      state.chatHistory.push({
        sender: 'ai',
        textEn: 'Rule expanded locally in 1.1s: 80 recurring tasks created and soonest 99 alarms updated.',
        textBn: '১.১ সেকেন্ডে ৮০টি রিকারিং টাস্ক তৈরি হয়েছে এবং আসন্ন ৯৯টি এক্স্যাক্ট অ্যালার্ম আপডেট হয়েছে।',
        batch: {
          items: [
            { title: 'Nov 22 • Morning Study', time: '08:00 AM' },
            { title: 'Nov 22 • Night Revision', time: '09:00 PM' },
            { title: 'Nov 23 • Morning Study', time: '08:00 AM' }
          ],
          moreCount: 77
        }
      });
      state.undoBanner = {
        textEn: 'Created 80 recurring tasks',
        textBn: '৮০টি রিকারিং টাস্ক যোগ হয়েছে',
        onUndo: () => {
          if (state.snapshotBeforeAi) state.tasks = state.snapshotBeforeAi;
        }
      };
    } else if (kind === 'bengali') {
      state.snapshotBeforeAi = JSON.parse(JSON.stringify(state.tasks));
      state.chatHistory.push({
        sender: 'user',
        textEn: 'কাল সকাল ১০টায় CSE-301 কুইজ, সিলেবাস Ch 1 & Ch 2',
        textBn: 'কাল সকাল ১০টায় CSE-301 কুইজ, সিলেবাস Ch 1 & Ch 2'
      });
      state.tasks.unshift({
        id: 't_bn_' + Date.now(),
        dayIdx: 3,
        dateLabel: 'Sun, Nov 23',
        title: 'CSE-301 Quiz',
        type: 'classTest',
        typeLabel: 'Quiz',
        time: '10:00 AM (Custom Only)',
        customTime: true,
        done: false,
        syllabus: [
          { text: 'Chapter 1 Core Concepts', checked: false },
          { text: 'Chapter 2 Problem Set', checked: false }
        ]
      });
      state.chatHistory.push({
        sender: 'ai',
        textEn: 'Parsed Bengali notice: CSE-301 Quiz tomorrow at 10:00 AM (default alerts disabled).',
        textBn: 'বাংলা নোটিশ থেকে টাস্ক তৈরি হয়েছে: আগামীকাল সকাল ১০:০০ (ডিফল্ট অ্যালার্ট বন্ধ)।',
        batch: {
          items: [{ title: 'CSE-301 Quiz (2 syllabus items)', time: '10:00 AM' }],
          moreCount: 0
        }
      });
      state.undoBanner = {
        textEn: 'Added CSE-301 Quiz',
        textBn: 'CSE-301 কুইজ যোগ হয়েছে',
        onUndo: () => {
          if (state.snapshotBeforeAi) state.tasks = state.snapshotBeforeAi;
        }
      };
    } else if (kind === 'bulk_delete') {
      state.snapshotBeforeAi = JSON.parse(JSON.stringify(state.tasks));
      const beforeCount = state.tasks.length;
      state.tasks = state.tasks.filter((t) => t.type !== 'study');
      const removed = beforeCount - state.tasks.length;
      state.chatHistory.push({
        sender: 'user',
        textEn: 'Delete all recurring Study tasks safely',
        textBn: 'সব রিকারিং Study টাস্ক ডিলিট করো'
      });
      state.chatHistory.push({
        sender: 'ai',
        textEn: `Removed ${removed} Study task(s) cleanly and updated rolling alarms. Tap Undo above anytime.`,
        textBn: `${removed}টি Study টাস্ক মুছে অ্যালার্ম সিঙ্ক করা হয়েছে। চাইলে ওপরের Undo চাপুন।`,
        batch: null
      });
      state.undoBanner = {
        textEn: `Removed ${removed} task(s)`,
        textBn: `${removed}টি টাস্ক মুছে ফেলা হয়েছে`,
        onUndo: () => {
          if (state.snapshotBeforeAi) state.tasks = state.snapshotBeforeAi;
        }
      };
    } else if (rawText) {
      state.snapshotBeforeAi = JSON.parse(JSON.stringify(state.tasks));
      state.chatHistory.push({ sender: 'user', textEn: rawText, textBn: rawText });
      state.tasks.unshift({
        id: 't_custom_' + Date.now(),
        dayIdx: 2,
        dateLabel: 'Today, Nov 22',
        title: rawText.slice(0, 42),
        type: 'assignment',
        typeLabel: 'AI Task',
        time: '07:30 PM',
        customTime: true,
        done: false,
        syllabus: []
      });
      state.chatHistory.push({
        sender: 'ai',
        textEn: `Planned "${rawText.slice(0, 32)}" with exact local reminder.`,
        textBn: `"${rawText.slice(0, 32)}" টাস্কটি এক্স্যাক্ট রিমাইন্ডারসহ যোগ হয়েছে।`,
        batch: null
      });
      state.undoBanner = {
        textEn: 'Added custom AI task',
        textBn: 'কাস্টম AI টাস্ক যোগ হয়েছে',
        onUndo: () => {
          if (state.snapshotBeforeAi) state.tasks = state.snapshotBeforeAi;
        }
      };
    }

    renderPhone();
    renderOverlay();
    phoneViewport.scrollTop = phoneViewport.scrollHeight;
    scheduleArrowUpdate();
  }

  function bindPhoneEvents() {
    phoneViewport.querySelectorAll('[data-pin-callout]').forEach((pin) => {
      pin.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        selectCallout(pin.getAttribute('data-pin-callout'), false);
      });
      pin.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          e.stopPropagation();
          selectCallout(pin.getAttribute('data-pin-callout'), false);
        }
      });
    });

    phoneViewport.querySelectorAll('[data-jump-tab]').forEach((btn) => {
      btn.addEventListener('click', () => switchTab(btn.getAttribute('data-jump-tab')));
    });

    const phoneThemeBtn = document.getElementById('phone-theme-btn');
    if (phoneThemeBtn) phoneThemeBtn.addEventListener('click', toggleTheme);

    const bellBtn = document.getElementById('phone-bell-btn');
    if (bellBtn) {
      bellBtn.addEventListener('click', () => {
        state.notifOpen = !state.notifOpen;
        renderOverlay();
      });
    }

    phoneViewport.querySelectorAll('[data-select-day]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.selectedDayIdx = Number(btn.getAttribute('data-select-day'));
        renderPhone();
        scheduleArrowUpdate();
      });
    });

    phoneViewport.querySelectorAll('[data-ov-filter]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.overviewFilter = btn.getAttribute('data-ov-filter');
        renderPhone();
        scheduleArrowUpdate();
      });
    });

    phoneViewport.querySelectorAll('[data-toggle-task]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-toggle-task');
        const task = state.tasks.find((t) => t.id === id);
        if (task) task.done = !task.done;
        renderPhone();
        scheduleArrowUpdate();
      });
    });

    phoneViewport.querySelectorAll('[data-toggle-syl]').forEach((chk) => {
      chk.addEventListener('change', () => {
        const [id, idxStr] = chk.getAttribute('data-toggle-syl').split(':');
        const task = state.tasks.find((t) => t.id === id);
        if (task && task.syllabus[Number(idxStr)]) {
          task.syllabus[Number(idxStr)].checked = chk.checked;
        }
        renderPhone();
        scheduleArrowUpdate();
      });
    });

    phoneViewport.querySelectorAll('[data-plan-mode]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.planMode = btn.getAttribute('data-plan-mode');
        renderPhone();
        scheduleArrowUpdate();
      });
    });

    phoneViewport.querySelectorAll('[data-plan-done]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.planCompletedOnly = btn.getAttribute('data-plan-done') === '1';
        renderPhone();
        scheduleArrowUpdate();
      });
    });

    const quickAdd = document.getElementById('plan-quick-add');
    if (quickAdd) {
      quickAdd.addEventListener('click', () => {
        state.tasks.unshift({
          id: 't_man_' + Date.now(),
          dayIdx: state.selectedDayIdx,
          dateLabel: 'Sat, Nov 22',
          title: 'Lab Report Review Session',
          type: 'assignment',
          typeLabel: 'Manual',
          time: '06:00 PM',
          customTime: true,
          done: false,
          syllabus: [{ text: 'Verify circuit diagrams', checked: false }]
        });
        renderPhone();
        scheduleArrowUpdate();
        showToast('Task added with custom 6:00 PM alarm', 'কাস্টম সন্ধ্যা ৬:০০ অ্যালার্মসহ টাস্ক যোগ হয়েছে');
      });
    }

    const demoUndo = document.getElementById('demo-undo-preview');
    if (demoUndo) {
      demoUndo.addEventListener('click', () => {
        state.undoBanner = {
          textEn: 'Preview: 1-tap Undo safety banner',
          textBn: 'প্রিভিউ: ১ ক্লিকে Undo সেফটি পপআপ',
          onUndo: () => showToast('Action restored cleanly!', 'আগের ডেটা পুনরুদ্ধার হয়েছে!')
        };
        renderOverlay();
      });
    }

    phoneViewport.querySelectorAll('[data-demo-cmd]').forEach((btn) => {
      btn.addEventListener('click', () => runAiCommand(btn.getAttribute('data-demo-cmd'), ''));
    });

    const aiForm = document.getElementById('sim-ai-form');
    if (aiForm) {
      aiForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const input = document.getElementById('sim-ai-input');
        const val = input ? input.value.trim() : '';
        if (val) {
          input.value = '';
          runAiCommand('custom', val);
        }
      });
    }

    const driveSync = document.getElementById('sim-drive-sync');
    if (driveSync) {
      driveSync.addEventListener('click', () =>
        showToast('Synced to Private Drive appDataFolder', 'প্রাইভেট Google Drive-এ ব্যাকআপ সম্পন্ন')
      );
    }

    const jsonExport = document.getElementById('sim-json-export');
    if (jsonExport) {
      jsonExport.addEventListener('click', () =>
        showToast('Exported portable JSON backup', 'অফলাইন JSON ব্যাকআপ এক্সপোর্ট হয়েছে')
      );
    }

    const testAlarm = document.getElementById('sim-test-alarm');
    if (testAlarm) {
      testAlarm.addEventListener('click', () =>
        showToast('Exact test notification scheduled for 10s!', '১০ সেকেন্ডের জন্য এক্স্যাক্ট টেস্ট অ্যালার্ম সেট হয়েছে!')
      );
    }

    const togglePin = document.getElementById('toggle-pin');
    if (togglePin) {
      togglePin.addEventListener('click', () => {
        state.pinEnabled = !state.pinEnabled;
        renderPhone();
        scheduleArrowUpdate();
      });
    }

    const toggleBio = document.getElementById('toggle-bio');
    if (toggleBio) {
      toggleBio.addEventListener('click', () => {
        state.bioEnabled = !state.bioEnabled;
        renderPhone();
        scheduleArrowUpdate();
      });
    }
  }

  function renderPhone() {
    if (state.tab === 0) phoneViewport.innerHTML = renderOverviewScreen();
    else if (state.tab === 1) phoneViewport.innerHTML = renderPlanScreen();
    else if (state.tab === 2) phoneViewport.innerHTML = renderAiChatScreen();
    else phoneViewport.innerHTML = renderProfileScreen();

    bindPhoneEvents();
    syncCalloutHighlight();
  }

  function renderAll(resetScroll) {
    renderCalloutColumns();
    renderPhone();
    renderOverlay();
    if (resetScroll) phoneViewport.scrollTop = 0;
    scheduleArrowUpdate();
  }

  // Draw desktop cubic Bezier SVG arrows connecting bubble cards to exact phone widgets
  function drawArrows() {
    if (!arrowSvg || !exploreStage) return;
    if (window.innerWidth < 1024) {
      arrowSvg.innerHTML = '';
      return;
    }

    const stageRect = exploreStage.getBoundingClientRect();
    const vpRect = phoneViewport.getBoundingClientRect();
    if (stageRect.width <= 0 || stageRect.height <= 0) return;

    arrowSvg.setAttribute('viewBox', `0 0 ${stageRect.width} ${stageRect.height}`);

    let svgMarkup = `
      <defs>
        <marker id="ah-idle" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
          <path d="M0,0.8 L7,4 L0,7.2 Z" fill="var(--text-secondary)" fill-opacity="0.72"></path>
        </marker>
        <marker id="ah-active" markerWidth="9" markerHeight="9" refX="7.5" refY="4.5" orient="auto">
          <path d="M0,0.8 L7.8,4.5 L0,8.2 Z" fill="var(--primary)"></path>
        </marker>
      </defs>
    `;

    const tabItems = CALLOUTS[state.tab];
    const cards = Array.from(exploreStage.querySelectorAll('.callout-col .callout-bubble'));

    cards.forEach((card) => {
      const id = card.getAttribute('data-callout-id');
      const item = tabItems.find((c) => c.id === id);
      if (!item) return;

      const target = phoneViewport.querySelector(`[data-anchor="${item.anchor}"]`);
      if (!target) return;

      const cRect = card.getBoundingClientRect();
      const tRect = target.getBoundingClientRect();

      const fromLeft = item.side === 'left';
      const x1 = (fromLeft ? cRect.right : cRect.left) - stageRect.left;
      const y1 = cRect.top + cRect.height * 0.5 - stageRect.top;

      // Clamp Y smoothly inside visible phone viewport so scrolled anchors still point cleanly
      const minTargetY = vpRect.top + 14;
      const maxTargetY = vpRect.bottom - 14;
      const rawTy = tRect.top + tRect.height * 0.5;
      const clampedTy = Math.max(minTargetY, Math.min(maxTargetY, rawTy));

      const x2 = (fromLeft ? tRect.left - 4 : tRect.right + 4) - stageRect.left;
      const y2 = clampedTy - stageRect.top;

      const dx = Math.abs(x2 - x1) * 0.52;
      const cx1 = fromLeft ? x1 + dx : x1 - dx;
      const cx2 = fromLeft ? x2 - dx : x2 + dx;

      const active = id === state.activeCalloutId;
      const activeCls = active ? ' is-active' : '';
      const marker = active ? 'url(#ah-active)' : 'url(#ah-idle)';

      svgMarkup += `
        <path class="arrow-path${activeCls}" d="M ${x1.toFixed(1)} ${y1.toFixed(1)} C ${cx1.toFixed(1)} ${y1.toFixed(1)}, ${cx2.toFixed(1)} ${y2.toFixed(1)}, ${x2.toFixed(1)} ${y2.toFixed(1)}" marker-end="${marker}"></path>
        <circle class="arrow-dot${activeCls}" cx="${x1.toFixed(1)}" cy="${y1.toFixed(1)}" r="${active ? 4.5 : 3.5}"></circle>
      `;
    });

    arrowSvg.innerHTML = svgMarkup;
  }

  let arrowRaf = 0;
  function scheduleArrowUpdate() {
    cancelAnimationFrame(arrowRaf);
    arrowRaf = requestAnimationFrame(drawArrows);
  }

  // GitHub Latest Release Fetch (with graceful fallback to v1.0.8)
  async function loadLatestRelease() {
    try {
      const res = await fetch(GITHUB_LATEST_API, {
        headers: { Accept: 'application/vnd.github+json' }
      });
      if (!res.ok) return;
      const data = await res.json();
      const tag = data.tag_name || 'v1.0.8';
      document.querySelectorAll('[data-release-tag]').forEach((el) => {
        el.textContent = tag;
      });

      const apkAsset = Array.isArray(data.assets)
        ? data.assets.find((a) => a.name && a.name.toLowerCase().endsWith('.apk'))
        : null;

      if (apkAsset && apkAsset.browser_download_url) {
        document.querySelectorAll('[data-apk-download]').forEach((a) => {
          a.setAttribute('href', apkAsset.browser_download_url);
        });
        const sizeMb = (apkAsset.size / (1024 * 1024)).toFixed(1);
        const sizeEl = document.getElementById('release-size');
        if (sizeEl) sizeEl.textContent = `${sizeMb} MB APK`;
      }

      if (data.published_at) {
        const d = new Date(data.published_at);
        const dateEl = document.getElementById('release-date');
        if (dateEl && !Number.isNaN(d.getTime())) {
          dateEl.textContent = d.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
          });
        }
      }

      if (data.html_url) {
        const notesEl = document.getElementById('release-notes-link');
        if (notesEl) notesEl.setAttribute('href', data.html_url);
      }
    } catch (_) {
      document.querySelectorAll('[data-apk-download]').forEach((a) => {
        if (!a.getAttribute('href')) a.setAttribute('href', FALLBACK_RELEASE_URL);
      });
    }
  }

  function init() {
    applyStaticI18n();
    renderAll(true);
    loadLatestRelease();

    document.getElementById('theme-toggle-btn').addEventListener('click', toggleTheme);

    document.querySelectorAll('[data-set-lang]').forEach((btn) => {
      btn.addEventListener('click', () => setLanguage(btn.getAttribute('data-set-lang')));
    });

    document.querySelectorAll('.screen-tab, .dock-btn').forEach((btn) => {
      btn.addEventListener('click', () => switchTab(btn.getAttribute('data-tab')));
    });

    const mobileMenuBtn = document.getElementById('mobile-menu-btn');
    const mobileNav = document.getElementById('mobile-nav');
    mobileMenuBtn.addEventListener('click', () => {
      const open = !mobileNav.hasAttribute('hidden');
      if (open) {
        mobileNav.setAttribute('hidden', '');
        mobileMenuBtn.setAttribute('aria-expanded', 'false');
      } else {
        mobileNav.removeAttribute('hidden');
        mobileMenuBtn.setAttribute('aria-expanded', 'true');
      }
    });
    mobileNav.querySelectorAll('a').forEach((a) => {
      a.addEventListener('click', () => {
        mobileNav.setAttribute('hidden', '');
        mobileMenuBtn.setAttribute('aria-expanded', 'false');
      });
    });

    document.getElementById('step-prev-btn').addEventListener('click', () => {
      const list = CALLOUTS[state.tab];
      const cur = list.findIndex((c) => c.id === state.activeCalloutId);
      const next = (cur - 1 + list.length) % list.length;
      selectCallout(list[next].id, true);
    });

    document.getElementById('step-next-btn').addEventListener('click', () => {
      const list = CALLOUTS[state.tab];
      const cur = list.findIndex((c) => c.id === state.activeCalloutId);
      const next = (cur + 1) % list.length;
      selectCallout(list[next].id, true);
    });

    phoneViewport.addEventListener('scroll', scheduleArrowUpdate, { passive: true });
    window.addEventListener('resize', scheduleArrowUpdate);

    if (window.ResizeObserver && exploreStage) {
      const ro = new ResizeObserver(scheduleArrowUpdate);
      ro.observe(exploreStage);
    }

    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(scheduleArrowUpdate);
    }
  }

  document.addEventListener('DOMContentLoaded', init);
})();
