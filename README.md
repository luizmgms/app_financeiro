# Finance Control

Aplicativo de gestão financeira pessoal em Flutter + Firebase + Gemini AI.

## Estrutura do Projeto (Feature-First)

- `lib/app/`: composição raiz (`FinanceControlApp`), tema e roteamento.
- `lib/core/`: constantes, erros, rotas (`GoRouter` com guarda de sessão), serviços de bootstrap (`FirebaseBootstrapService`, `LocalStorageService` com Hive), tema Material 3, formatadores (`intl`) e widgets compartilhados (`AppShellScaffold`).
- `lib/shared/`: modelos transversais (`Money` em centavos inteiros, `DatePeriod`), providers Riverpod e cards reutilizáveis.
- `lib/features/`: módulos independentes (`authentication`, `profile`, `settings`, `dashboard`, `accounts`, `credit_cards`, `transactions`, `recurring`, `installments`, `categories`, `budgets`, `reports`, `notifications`, `ai_assistant`).
- Raiz Firebase: `firebase.json`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`.

## Execução e Testes

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

## Conexão ao Firebase (Etapa 1)

1. Instale os CLIs e autentique sua conta Google:
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```
2. Gere `lib/firebase_options.dart` e `android/app/google-services.json`:
   ```bash
   flutterfire configure
   ```
   O `FirebaseBootstrapService` detecta automaticamente as chaves reais geradas pelo `flutterfire configure`.
3. No Firebase Console, habilite **Authentication -> Sign-in method -> E-mail/senha** e **Google**.
4. Publique as regras de segurança e índices:
   ```bash
   firebase deploy --only firestore,storage
   ```
5. Para testar localmente com o **Firebase Emulator Suite**:
   ```bash
   firebase emulators:start
   flutter run --dart-define=USE_FIREBASE_EMULATOR=true
   ```

### Notas de Ambiente

- **Android**: requer Gradle `7.5` (`android/gradle/wrapper/gradle-wrapper.properties`) com Flutter `3.13.7` e `compileSdkVersion 34`.
- **Windows Desktop**: `firebase_cpp_sdk` exige Visual Studio 2022 `17.8+` (MSVC `14.38+`).
