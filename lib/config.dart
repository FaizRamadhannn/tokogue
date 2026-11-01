/// Koneksi Supabase.
///
/// Publishable key memang dibuat untuk ditaruh di aplikasi (aman dibagikan);
/// keamanan data dijaga oleh Row Level Security di database.
///
/// Mode demo (data contoh, tanpa server): build/run dengan --dart-define=DEMO=true
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://sinxdbpbmodmtxzphgyx.supabase.co',
);
const supabaseKey = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_U5HceSNvRDj79SWxYugpPg_UfRvCpnC',
);
const _demo = bool.fromEnvironment('DEMO');

bool get liveMode => supabaseKey.isNotEmpty && !_demo;

/// Login pakai nomor HP; Supabase butuh email, jadi nomor diubah jadi email.
String phoneToEmail(String phone) => '${phone.replaceAll(RegExp(r'\D'), '')}@tokogue.app';
