package com.salessphere.app

import io.flutter.embedding.android.FlutterFragmentActivity

// `local_auth` shows the BiometricPrompt via an Android Fragment, which
// requires the host activity to be a FragmentActivity. `FlutterActivity`
// extends Activity (not FragmentActivity), so we use the
// FragmentActivity-flavored entrypoint instead.
class MainActivity : FlutterFragmentActivity()
