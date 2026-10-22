# Remediation 1: release signing and flavor isolation

Implemented against `f835f92`, 2026-10-22. The original release-readiness audit
and all pre-existing working-tree files are preserved. This is not a declaration
that the app is ready for Play; toolchain and privacy remediation remain separate.

## Root causes and changes

1. `android/app/build.gradle` previously substituted debug signing defaults when
   upload environment variables were absent. Both flavors' release variants used
   that configuration. The defaults are removed. A variant-specific security task
   now requires nonblank path/password/alias inputs, rejects known debug defaults,
   and checks file existence/readability **without opening it**. Validation is
   attached to pre-build, Flutter compilation, signing validation and packaging
   paths; no requested-task-name guessing is used.
2. Native `--flavor` and legacy Dart `FLAVOR` previously selected independent
   identities. Gradle now rejects mismatches, duplicates and malformed encoded
   defines. An omitted legacy define is allowed: Flutter supplies the real native
   flavor. `AppFlavorConfig` now gives Flutter's `appFlavor` precedence over the
   legacy define, so the old Dart switch cannot enable QA in native PROD.
3. Secret ignore patterns now cover common signing files and `.env` files outside
   `android/app/` as well. Keys should still stay outside the repository. Ignore
   rules do not protect already tracked files or substitute for secret management.

The installed SDK was inspected: `FlutterPlugin.kt` sets the Flutter compile
task's flavor from `variant.flavorName`; `build_system/targets/common.dart:293-329`
replaces `FLUTTER_APP_FLAVOR` with that native flavor before compilation.
`services/flavor.dart` exposes it as `appFlavor`. The legacy fallback remains for
unflavored host tests/tools, including existing `--dart-define=FLAVOR=prod` QA and
Golden commands. Unknown effective flavors fail closed with a non-sensitive error.

No entry point, routes, screen widgets or repository mutation implementation
needed changing: they already consult the shared gate. It protects registration
of `/dev-qa` in `lib/main.dart`, main-menu/settings QA navigation, direct
`QaScreen` construction and every `ProgressRepository.debug*` mutation through
`_ensureDevQa`. Tests call those mutations directly to check more than hidden UI.
The normal player Reset Progress action remains available as before.

## Variant behavior

| Variant | Signing | QA gate |
| --- | --- | --- |
| DEV Debug | Existing Android debug signing; no upload inputs required | Native DEV enables existing tools |
| PROD Debug | Existing Android debug signing; no upload inputs required | Native PROD disables tools even though this is a debuggable build |
| DEV/PROD Profile | Existing Flutter Profile signing (initialized from Debug); no upload inputs required | Respective native flavor |
| DEV Release | Explicit upload signing required; no former debug fallback | Native DEV retains legitimate tools |
| PROD Release APK/AAB | Explicit upload signing required; non-debuggable, JNI debugging disabled | Native PROD disables tools |

Both release flavors already shared the release signing config. Removing its
fallback intentionally also prevents DEV Release from silently using a debug
key. Normal DEV Debug and physical-device Profile workflows remain secret-free.
Explicitly upload-signed DEV Release remains supported. Matching legacy defines
remain supported. Conflicting flags fail rather than silently choosing a package
different from what the developer requested.

All four inputs are still private environment variables:
`ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`. Use the existing external keystore; no key generation,
copying, rotation or credential hardcoding was added. Prefer an absolute native
Windows path (forward slashes work) from the private environment provider.
Relative paths continue to resolve against `android/app` as before.

The preflight verifies configuration and filesystem metadata, **not** key identity
or authentication. Incorrect nonblank passwords, nonexistent aliases, corrupt
files and non-private-key entries must fail in AGP's actual signing operation;
they cannot be authenticated without opening the keystore. The agent did not
perform such an operation. Known debug markers are rejected, but a renamed
debug key with changed credentials cannot be identified from metadata alone.
Verify the resulting artifact's public upload certificate against Play Console.

The custom checks print fixed diagnostics or missing variable **names**, never
values, decoded Dart defines, file paths or nested file-resolution errors. Do not
enable shell tracing, Gradle debug logging or build scans around signing secrets.
AGP may include file/alias metadata in its own signing diagnostics; handle those
logs privately. No custom keystore reader was introduced to replace AGP.

## Manifest and player data review

- `release` explicitly sets `debuggable false` and `jniDebuggable false`. A
  release security task also rejects a debug-enabled build type or a signing
  config other than the named release config.
- `src/profile/AndroidManifest.xml` contributes INTERNET only to Profile source
  sets. The main manifest and inspected plugin manifests do not request it.
  No source-set remapping was found. That pre-existing untracked file is untouched.
  A final merged release manifest must still be checked locally; no merge/build
  was run and future dependencies can introduce permissions.
- No backup, network security, exported component or permission change was made.
- Application IDs, namespace, version, SDK targets, toolchain versions and package
  dependencies are unchanged. Save keys, progression, rewards, achievements,
  cosmetics and settings code are unchanged; no reset/migration is introduced.

## Files changed by this remediation

- `.gitignore`
- `android/app/build.gradle`
- `android/release-security.gradle` (new shared policy)
- `lib/core/app_flavor.dart`
- `qa/release_security_checks.gradle` (new isolated synthetic policy checks)
- `test/qa/release_flavor_test.dart` (new behavior regression tests)
- `qa/RELEASE_SECURITY_REMEDIATION.md` (this document)

No existing test assertion or Golden PNG was edited. No Flutter/Gradle checks,
tests, analysis, builds, emulator or ADB were executed. Only Dart formatting and
source/diff inspection were performed. No private signing material was opened.

## Local verification — Windows Git Bash

Use the existing JDK/Gradle setup. These commands are for the owner; none were
executed by the agent. The first command loads the normal Android Gradle project
and adds a synthetic policy-check task through an init script. The task reads no
signing environment variables, creates no key file, and uses a `File` test double
whose metadata responses are synthetic. It tests missing/blank fields, both flavor
directions, duplicate/reserved defines, malformed encoding, known debug defaults,
unreadable/missing files and redacted errors. This synthetic task does not test AGP
task wiring or authenticate an upload key. The separate graph mode below checks
the actual scheduled Android tasks without executing their build actions.

```bash
cd '/c/Gra - telefon/game'
./android/gradlew.bat -p android -I "$PWD/qa/release_security_checks.gradle" checkReleaseSecurity --no-configuration-cache
```

### Variant task wiring regression

The latest verified DEV Debug graph includes both `compileFlutterBuildDevDebug`
and `compileFlutterBuildProdDebug`, and both corresponding security guards. The
previous String/GString correction made task-name matching work, but exposed a
second integration defect: treating every scheduled Flutter compile task as a
selected Android artifact. Its name alone does not establish that relationship.

The confirmed guard-introducing dependency is:

```text
:app:assembleDevDebug
  -> [transitive Flutter dependency chain]
  -> :app:compileFlutterBuildProdDebug
  -> :app:verifyProdDebugSecurity
```

The final edge was added directly by `android/app/build.gradle`. The supplied
dry-run establishes that the foreign compile task is scheduled; it does not
include enough dependency edges to identify the full preceding chain. The
harness now prints the exact chain using Gradle's populated graph rather than
guessing it from the order of task names. This distinction is deliberate: no
Gradle invocation was run during this investigation.

Installed Flutter source evidence:

- `FlutterPluginUtils.kt:243-267`: `shouldConfigureFlutterTask` permits all
  variants with the requested build-mode suffix, including both Debug flavors.
  This proves registration eligibility, not by itself a transitive dependency.
- `FlutterPlugin.kt:669-700`: registers the variant-named compile task, giving
  it the invocation-wide Dart defines and its own native flavor.
- `FlutterPlugin.kt:709-739`: `packJniLibsflutterBuild<Variant>` depends on the
  compile task and is registered as an API file dependency.
- `FlutterPlugin.kt:744-790`: `copyFlutterAssets<Variant>` depends on that compile
  task and is consumed by Android resource processing. These are possible
  upstream routes; the new graph trace identifies the route actually selected.

The corrected artifact guards use AGP's public `assembleProvider` and
`packageApplicationProvider`, configured lazily. Inspected AGP 8.6.1 bytecode
shows `BaseVariantImpl.getAssembleProvider()` and
`ApkVariantImpl.getPackageApplicationProvider()` returning providers from that
variant's own component task container. APK packaging therefore directly depends
on its corresponding guard, including signing performed inside APK packaging.

The legacy variant API has no equivalent public bundle/signing providers, so
`tasks.configureEach` matches complete, String-normalized AGP 8.6.1 task names:
`bundle<Variant>`, `validateSigning<Variant>`, `build<Variant>PreBundle`,
`package<Variant>Bundle`, and `sign<Variant>Bundle`. The installed AGP creation
actions confirm these names: `PerModuleBundleTask.CreationAction` computes
`build...PreBundle`, `PackageBundleTask.CreationAction` computes `package...Bundle`,
`FinalizeBundleTask.CreationAction` computes `sign...Bundle`, and
`ValidateSigningTask.CreationAction` computes `validateSigning...`. Each name is
computed from its own variant component. No internal AGP classes are imported
into the production build script. Changes to these names on a future AGP upgrade
must be checked against the regression harness.

There are no guards on Flutter compile, asset-copy/JNI, or prebuild tasks. An
auxiliary PROD compile in a DEV graph therefore cannot pull in the PROD guard
through the former compile edge. Guards remain mandatory before sensitive APK
packaging/signing, module-bundle generation, AAB packaging/signing, and final
assemble/bundle lifecycle actions. Some compilation may run before rejection;
no APK/AAB packaging or signing action may run first. Invocation-wide flavor
defines are still strictly checked against the variant whose artifact is built.
No security task is disabled or filtered by requested command-line task names.

The init script only observes the app graph and registers the separate synthetic
policy task. It does not mutate app dependencies. Synthetic policy checks retain
every missing-input, debug-credential, flavor-mismatch and redaction assertion.
The graph test still requires exactly one selected guard; it additionally rejects
guards attached to Flutter compile tasks, requires the real packaging stages to
exist, and checks direct dependency edges and ordering at every artifact stage.
The old requirement that a guard precede Flutter compilation is intentionally
replaced by protection of Android artifacts, not by skipping a failing guard.

Execution limit: the new graph/build results, the complete upstream Flutter path,
and real signing behavior require local verification. No Flutter, Gradle, build,
test or device command was run. No signing material was accessed. The prior
prebuild removal and String/GString fix are preserved.

Run from the repository root. The test-only `securityExpectedVariant` property
is an independent oracle and never alters production task wiring or policy.
Assertions run when Gradle has constructed the actual graph, including during
`--dry-run`; merely realizing a task does not count as scheduling it. Each
invocation retains Flutter's normal single-entry-point task-selection context.
The expected guard must be the only scheduled app security task, must be a direct
dependency of each selected protected task, and must precede those tasks. The
dependency assertion prevents an accidentally favorable task order from passing.
Gradle configuration still requires the normal local SDK/plugin setup.

Compare the DEV Debug graph without and with the observer. Both must schedule
`:app:verifyDevDebugSecurity` and no other app security guard. The observed run
also checks the dependency edges and execution order. No build actions run in
either dry-run; output paths and task names contain no signing credentials.

```bash
(
  unset ANDROID_KEYSTORE_PATH ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD
  ./android/gradlew.bat -p android :app:assembleDevDebug \
    --dry-run --no-configuration-cache --console=plain
  ./android/gradlew.bat -p android -I "$PWD/qa/release_security_checks.gradle" \
    :app:assembleDevDebug -PsecurityExpectedVariant=DevDebug \
    --dry-run --no-configuration-cache --console=plain
)
```

```bash
(
  unset ANDROID_KEYSTORE_PATH ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD
  for variant in DevDebug DevProfile DevRelease ProdDebug ProdProfile ProdRelease; do
    for artifact in assemble bundle; do
      ./android/gradlew.bat -p android -I "$PWD/qa/release_security_checks.gradle" \
        ":app:${artifact}${variant}" "-PsecurityExpectedVariant=${variant}" \
        --dry-run --no-configuration-cache --console=plain || exit $?
    done
  done
)
```

Dry-run checks validate scheduling, not signing inputs. Actual preflight policy
actions below must also be checked. For the real DEV Debug acceptance build,
use this subshell to leave the parent shell's signing settings untouched:

```bash
(
  unset ANDROID_KEYSTORE_PATH ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD
  flutter run --debug --flavor dev --dart-define=FLAVOR=dev -d RZCTA0TPGDD
)
```

DEV Profile uses the same command with `--profile` instead of `--debug`. Neither
mode requires upload-signing inputs. PROD Debug uses only its own guard and keeps
QA disabled. PROD Release still requires the explicit upload configuration,
rejects debug signing defaults, and leaves alias/password/private-key validation
to AGP during actual signing. No signing policy or Dart flavor gate was changed.

Check actual variant preflight wiring without creating an APK/AAB. The subshell
temporarily unsets signing inputs; your parent shell's private settings remain
unchanged. DEV Debug must succeed; PROD Release must fail with missing variable
names. An unrelated AGP/Kotlin configuration failure is not a passing security
test: the audit's toolchain issue remains outside this patch.

```bash
(
  unset ANDROID_KEYSTORE_PATH ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD
  ./android/gradlew.bat -p android :app:verifyDevDebugSecurity :app:verifyDevProfileSecurity -Pdart-defines=RkxBVk9SPWRldg== --no-configuration-cache
  ./android/gradlew.bat -p android :app:verifyProdDebugSecurity -Pdart-defines=RkxBVk9SPXByb2Q= --no-configuration-cache
  ./android/gradlew.bat -p android :app:verifyProdReleaseSecurity -Pdart-defines=RkxBVk9SPXByb2Q= --no-configuration-cache
  # The final command above must fail with the missing release-signing variables diagnostic.
)

# Must reject a PROD package with legacy Dart DEV, even in Debug.
./android/gradlew.bat -p android :app:verifyProdDebugSecurity -Pdart-defines=RkxBVk9SPWRldg== --no-configuration-cache

# Matching DEV configuration must pass without requiring release secrets.
./android/gradlew.bat -p android :app:verifyDevDebugSecurity -Pdart-defines=RkxBVk9SPWRldg== --no-configuration-cache
```

The base64 above encodes only the non-secret `FLAVOR=dev` / `FLAVOR=prod` values. Do not pass
passwords in command-line arguments. Run checks without `--debug`, `--info`,
`--scan` or shell `set -x`.

Run the behavior matrix. `EXPECT_QA` is a test-only oracle, never read by app code.
The deliberately mismatched host-test case bypasses Gradle to verify the Dart
defense independently. It is not a supported Android build configuration.

```bash
# Existing unflavored host workflow: PROD
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/qa/release_flavor_test.dart

# Native PROD cannot be changed to DEV by the old switch
flutter test --no-pub --concurrency=1 --dart-define=FLUTTER_APP_FLAVOR=prod --dart-define=FLAVOR=dev test/qa/release_flavor_test.dart

# Native DEV, including when no legacy define was supplied
flutter test --no-pub --concurrency=1 --dart-define=FLUTTER_APP_FLAVOR=dev --dart-define=EXPECT_QA=true test/qa/release_flavor_test.dart
flutter test --no-pub --concurrency=1 --dart-define=FLUTTER_APP_FLAVOR=dev --dart-define=FLAVOR=dev --dart-define=EXPECT_QA=true test/qa/release_flavor_test.dart

# Existing host-side DEV workflow
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=dev --dart-define=EXPECT_QA=true test/qa/release_flavor_test.dart

# Full unchanged QA and Golden comparisons
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/qa
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/goldens
```

## Manual Android acceptance still required

Using the owner's normal release workflow, verify both APK and AAB task graphs
run the security guard, including repeated/incremental builds and aggregate
assemble/bundle entry points. Build a secret-free DEV Debug; test DEV/PROD Profile
without upload credentials. Confirm a PROD build with mismatched Dart defines is
rejected. Do not exclude verification tasks with `-x` or reuse an old artifact as
evidence of a new successful build. Explicit task exclusion or source tampering
is outside a build-time policy's security boundary.

Privately verify AGP rejects invalid alias/password/key files, then build with
the existing correct upload inputs and verify the artifact's public certificate.
Do not change/delete the actual key to test failures. Inspect merged release
manifest and delivered artifact for the correct package, debuggable false/absent,
no JNI debugging and expected permissions (Profile INTERNET must not leak).
Test direct QA navigation and a returning save in PROD, and QA controls in DEV.

The existing AGP 8.6.1/API 36 and Kotlin compatibility risks can prevent these
checks from reaching the new guard; they were not changed here. This uses the
legacy variant API already supported by the installed AGP/Flutter plugin. Task
wiring and configuration-cache behavior have not been executed; the supplied
verification commands explicitly disable configuration cache. Resolve failures
with evidence rather than removing security checks or weakening tests.
