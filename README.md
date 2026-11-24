# Finance Control

Aplicativo de gestão financeira pessoal em **Flutter** + **Firebase** + **Google Gemini AI** (Android, iOS, Web, Windows e Linux).

## Estrutura do Projeto (Feature-First)

- `lib/app/`: composição raiz (`FinanceControlApp`), tema Material 3 claro/escuro e roteamento `GoRouter`.
- `lib/core/`: constantes, erros tipados, guarda de sessão, serviços de bootstrap (`FirebaseBootstrapService` com persistência offline Firestore e App Check, `LocalStorageService` com Hive), anexos no Storage e componentes compartilhados.
- `lib/shared/`: modelos transversais (`Money` em centavos inteiros, `DatePeriod`), providers Riverpod e cards reutilizáveis.
- `lib/features/`: módulos independentes (`authentication`, `profile`, `settings`, `dashboard`, `accounts`, `credit_cards`, `transactions`, `recurring`, `installments`, `categories`, `budgets`, `reports`, `notifications`, `ai_assistant`).
- `functions/`: Firebase Cloud Functions Gen 2 (`scheduledFinanceAutomation`, `syncAutomationOnDemand`, `aiAssistantQuery`, `deleteUserAccountData`).
- Raiz Firebase: `firebase.json`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`.

## Execução e Testes

### 1. Análise estática, testes unitários/widget/integração e Backend

```bash
flutter pub get
flutter analyze
flutter test
npm --prefix functions test
```

### 2. Testes de Regras de Segurança e Integração no Firebase Emulator Suite

Requer Node.js e Java JDK 21+ (`firebase-tools` v15+), ou Java 17 do Android Studio (`jbr\bin` no `PATH`) utilizando `firebase-tools@13.35.1`:

```bash
firebase emulators:exec --project demo-finance-control-e2e --only auth,firestore,storage "npm --prefix functions run test:emulator"
# Alternativa com Android Studio OpenJDK 17:
npx -y firebase-tools@13.35.1 emulators:exec --project demo-finance-control-e2e --only auth,firestore,storage "npm --prefix functions run test:emulator"
```

Para executar o app Flutter conectado localmente aos emuladores:

```bash
firebase emulators:start
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

## Segurança, App Check e Privacidade

- **Isolamento multiusuário**: Todas as coleções ficam sob `users/{userId}/...` protegidas por `firestore.rules` e `storage.rules` (MIME `image/jpeg|png|webp` e `application/pdf` `< 10 MB`, bloqueio contra escrita client-side em `ai_usage` e forja em `ai_interactions`).
- **Gemini API Key protegida**: Nenhuma chave do Gemini ou credencial administrativa reside no app Flutter. Todas as consultas de IA passam pela Cloud Function autenticada `aiAssistantQuery` usando Vertex AI / Google GenAI SDK com rate limit e confirmação manual obrigatória.
- **Exclusão completa (LGPD)**: Ao excluir a conta, o app aciona `deleteUserAccountData` (`db.recursiveDelete` em `users/{uid}` + remoção de objetos no Storage) antes de remover o usuário no Firebase Auth.
- **Android Backup**: `android:allowBackup="false"` ativo em [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml).
- **Firebase App Check**:
  - Android: `AndroidProvider.debug` em debug e `AndroidProvider.playIntegrity` em release.
  - Apple (iOS/macOS): `AppleProvider.debug` em debug e `AppleProvider.appAttestWithDeviceCheckFallback` em release.
  - Web: informe a chave pública reCAPTCHA v3 no build:
    ```bash
    flutter build web --dart-define=APP_CHECK_WEB_RECAPTCHA_KEY=SEU_SITE_KEY
    ```
  - Para ativar bloqueio criptográfico estrito nas Cloud Functions após registrar SHA-256 / reCAPTCHA no Firebase Console, defina `ENFORCE_APP_CHECK=true` no ambiente das Functions.

## Build e Deploy

```bash
# Compila Web e APK Android
flutter build web --release
flutter build apk --debug

# Deploy completo de regras, índices e Cloud Functions no Firebase
firebase deploy --only firestore,storage,functions
```

### Notas de Ambiente

- **Android**: requer Gradle `7.5` (`android/gradle/wrapper/gradle-wrapper.properties`) com Flutter `3.13.7` e `compileSdkVersion 34`.
- **Windows Desktop**: `firebase_cpp_sdk` exige Visual Studio 2022 `17.8+` (MSVC `14.38+`).
