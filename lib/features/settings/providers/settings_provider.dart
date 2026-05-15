import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MentoraLanguage {
  english('English'),
  russian('Russian'),
  uzbek('Uzbek');

  const MentoraLanguage(this.label);

  final String label;
}

enum DefaultStudyView {
  read('Read'),
  chat('Chat'),
  notes('Notes'),
  highlights('Highlights');

  const DefaultStudyView(this.label);

  final String label;
}

enum ReaderTextSize {
  small('Small'),
  medium('Medium'),
  large('Large');

  const ReaderTextSize(this.label);

  final String label;
}

enum AiBackendProvider {
  local('Local model'),
  openAi('OpenAI'),
  azureOpenAi('Azure OpenAI'),
  gemini('Google Gemini');

  const AiBackendProvider(this.label);

  final String label;
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.language = MentoraLanguage.english,
    this.grammarAssistEnabled = true,
    this.pronunciationAssistEnabled = true,
    this.offlineModeEnabled = true,
    this.autoSaveNotesEnabled = true,
    this.defaultStudyView = DefaultStudyView.read,
    this.readerTextSize = ReaderTextSize.medium,
    this.aiBackendProvider = AiBackendProvider.local,
    this.openAiApiKey = '',
    this.openAiModel = 'gpt-5-mini',
    this.azureOpenAiEndpoint = '',
    this.azureOpenAiApiKey = '',
    this.azureOpenAiDeployment = '',
    this.azureOpenAiApiVersion = '2024-10-21',
    this.geminiApiKey = '',
    this.geminiModel = 'gemini-2.5-flash',
  });

  final ThemeMode themeMode;
  final MentoraLanguage language;
  final bool grammarAssistEnabled;
  final bool pronunciationAssistEnabled;
  final bool offlineModeEnabled;
  final bool autoSaveNotesEnabled;
  final DefaultStudyView defaultStudyView;
  final ReaderTextSize readerTextSize;
  final AiBackendProvider aiBackendProvider;
  final String openAiApiKey;
  final String openAiModel;
  final String azureOpenAiEndpoint;
  final String azureOpenAiApiKey;
  final String azureOpenAiDeployment;
  final String azureOpenAiApiVersion;
  final String geminiApiKey;
  final String geminiModel;

  bool get darkModeEnabled => themeMode == ThemeMode.dark;

  bool get selectedCloudBackendConfigured => switch (aiBackendProvider) {
    AiBackendProvider.local => false,
    AiBackendProvider.openAi =>
      openAiApiKey.trim().isNotEmpty && openAiModel.trim().isNotEmpty,
    AiBackendProvider.azureOpenAi =>
      azureOpenAiEndpoint.trim().isNotEmpty &&
          azureOpenAiApiKey.trim().isNotEmpty &&
          azureOpenAiDeployment.trim().isNotEmpty,
    AiBackendProvider.gemini =>
      geminiApiKey.trim().isNotEmpty && geminiModel.trim().isNotEmpty,
  };

  AppSettings copyWith({
    ThemeMode? themeMode,
    MentoraLanguage? language,
    bool? grammarAssistEnabled,
    bool? pronunciationAssistEnabled,
    bool? offlineModeEnabled,
    bool? autoSaveNotesEnabled,
    DefaultStudyView? defaultStudyView,
    ReaderTextSize? readerTextSize,
    AiBackendProvider? aiBackendProvider,
    String? openAiApiKey,
    String? openAiModel,
    String? azureOpenAiEndpoint,
    String? azureOpenAiApiKey,
    String? azureOpenAiDeployment,
    String? azureOpenAiApiVersion,
    String? geminiApiKey,
    String? geminiModel,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      grammarAssistEnabled: grammarAssistEnabled ?? this.grammarAssistEnabled,
      pronunciationAssistEnabled:
          pronunciationAssistEnabled ?? this.pronunciationAssistEnabled,
      offlineModeEnabled: offlineModeEnabled ?? this.offlineModeEnabled,
      autoSaveNotesEnabled: autoSaveNotesEnabled ?? this.autoSaveNotesEnabled,
      defaultStudyView: defaultStudyView ?? this.defaultStudyView,
      readerTextSize: readerTextSize ?? this.readerTextSize,
      aiBackendProvider: aiBackendProvider ?? this.aiBackendProvider,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      openAiModel: openAiModel ?? this.openAiModel,
      azureOpenAiEndpoint: azureOpenAiEndpoint ?? this.azureOpenAiEndpoint,
      azureOpenAiApiKey: azureOpenAiApiKey ?? this.azureOpenAiApiKey,
      azureOpenAiDeployment:
          azureOpenAiDeployment ?? this.azureOpenAiDeployment,
      azureOpenAiApiVersion:
          azureOpenAiApiVersion ?? this.azureOpenAiApiVersion,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  static const _themeModeKey = 'settings.themeMode';
  static const _languageKey = 'settings.language';
  static const _grammarAssistKey = 'settings.grammarAssistEnabled';
  static const _pronunciationAssistKey = 'settings.pronunciationAssistEnabled';
  static const _offlineModeKey = 'settings.offlineModeEnabled';
  static const _autoSaveNotesKey = 'settings.autoSaveNotesEnabled';
  static const _defaultStudyViewKey = 'settings.defaultStudyView';
  static const _readerTextSizeKey = 'settings.readerTextSize';
  static const _aiBackendProviderKey = 'settings.aiBackendProvider';
  static const _openAiApiKeyKey = 'settings.openAiApiKey';
  static const _openAiModelKey = 'settings.openAiModel';
  static const _azureOpenAiEndpointKey = 'settings.azureOpenAiEndpoint';
  static const _azureOpenAiApiKeyKey = 'settings.azureOpenAiApiKey';
  static const _azureOpenAiDeploymentKey = 'settings.azureOpenAiDeployment';
  static const _azureOpenAiApiVersionKey = 'settings.azureOpenAiApiVersion';
  static const _geminiApiKeyKey = 'settings.geminiApiKey';
  static const _geminiModelKey = 'settings.geminiModel';

  Future<void> setThemeMode(ThemeMode themeMode) async {
    await _update(state.copyWith(themeMode: themeMode));
  }

  Future<void> setLanguage(MentoraLanguage language) async {
    await _update(state.copyWith(language: language));
  }

  Future<void> setGrammarAssistEnabled(bool enabled) async {
    await _update(state.copyWith(grammarAssistEnabled: enabled));
  }

  Future<void> setPronunciationAssistEnabled(bool enabled) async {
    await _update(state.copyWith(pronunciationAssistEnabled: enabled));
  }

  Future<void> setOfflineModeEnabled(bool enabled) async {
    await _update(state.copyWith(offlineModeEnabled: enabled));
  }

  Future<void> setAutoSaveNotesEnabled(bool enabled) async {
    await _update(state.copyWith(autoSaveNotesEnabled: enabled));
  }

  Future<void> setDefaultStudyView(DefaultStudyView view) async {
    await _update(state.copyWith(defaultStudyView: view));
  }

  Future<void> setReaderTextSize(ReaderTextSize size) async {
    await _update(state.copyWith(readerTextSize: size));
  }

  Future<void> setAiBackendProvider(AiBackendProvider provider) async {
    await _update(state.copyWith(aiBackendProvider: provider));
  }

  Future<void> setOpenAiConfig({
    required String apiKey,
    required String model,
  }) async {
    await _update(state.copyWith(openAiApiKey: apiKey, openAiModel: model));
  }

  Future<void> setAzureOpenAiConfig({
    required String endpoint,
    required String apiKey,
    required String deployment,
    required String apiVersion,
  }) async {
    await _update(
      state.copyWith(
        azureOpenAiEndpoint: endpoint,
        azureOpenAiApiKey: apiKey,
        azureOpenAiDeployment: deployment,
        azureOpenAiApiVersion: apiVersion,
      ),
    );
  }

  Future<void> setGeminiConfig({
    required String apiKey,
    required String model,
  }) async {
    await _update(state.copyWith(geminiApiKey: apiKey, geminiModel: model));
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    state = AppSettings(
      themeMode: _readEnum(
        preferences,
        _themeModeKey,
        ThemeMode.values,
        ThemeMode.system,
      ),
      language: _readEnum(
        preferences,
        _languageKey,
        MentoraLanguage.values,
        MentoraLanguage.english,
      ),
      grammarAssistEnabled: preferences.getBool(_grammarAssistKey) ?? true,
      pronunciationAssistEnabled:
          preferences.getBool(_pronunciationAssistKey) ?? true,
      offlineModeEnabled: preferences.getBool(_offlineModeKey) ?? true,
      autoSaveNotesEnabled: preferences.getBool(_autoSaveNotesKey) ?? true,
      defaultStudyView: _readEnum(
        preferences,
        _defaultStudyViewKey,
        DefaultStudyView.values,
        DefaultStudyView.read,
      ),
      readerTextSize: _readEnum(
        preferences,
        _readerTextSizeKey,
        ReaderTextSize.values,
        ReaderTextSize.medium,
      ),
      aiBackendProvider: _readEnum(
        preferences,
        _aiBackendProviderKey,
        AiBackendProvider.values,
        AiBackendProvider.local,
      ),
      openAiApiKey: preferences.getString(_openAiApiKeyKey) ?? '',
      openAiModel: preferences.getString(_openAiModelKey) ?? 'gpt-5-mini',
      azureOpenAiEndpoint: preferences.getString(_azureOpenAiEndpointKey) ?? '',
      azureOpenAiApiKey: preferences.getString(_azureOpenAiApiKeyKey) ?? '',
      azureOpenAiDeployment:
          preferences.getString(_azureOpenAiDeploymentKey) ?? '',
      azureOpenAiApiVersion:
          preferences.getString(_azureOpenAiApiVersionKey) ?? '2024-10-21',
      geminiApiKey: preferences.getString(_geminiApiKeyKey) ?? '',
      geminiModel: preferences.getString(_geminiModelKey) ?? 'gemini-2.5-flash',
    );
  }

  Future<void> _update(AppSettings next) async {
    state = next;
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_themeModeKey, next.themeMode.name),
      preferences.setString(_languageKey, next.language.name),
      preferences.setBool(_grammarAssistKey, next.grammarAssistEnabled),
      preferences.setBool(
        _pronunciationAssistKey,
        next.pronunciationAssistEnabled,
      ),
      preferences.setBool(_offlineModeKey, next.offlineModeEnabled),
      preferences.setBool(_autoSaveNotesKey, next.autoSaveNotesEnabled),
      preferences.setString(_defaultStudyViewKey, next.defaultStudyView.name),
      preferences.setString(_readerTextSizeKey, next.readerTextSize.name),
      preferences.setString(_aiBackendProviderKey, next.aiBackendProvider.name),
      preferences.setString(_openAiApiKeyKey, next.openAiApiKey),
      preferences.setString(_openAiModelKey, next.openAiModel),
      preferences.setString(_azureOpenAiEndpointKey, next.azureOpenAiEndpoint),
      preferences.setString(_azureOpenAiApiKeyKey, next.azureOpenAiApiKey),
      preferences.setString(
        _azureOpenAiDeploymentKey,
        next.azureOpenAiDeployment,
      ),
      preferences.setString(
        _azureOpenAiApiVersionKey,
        next.azureOpenAiApiVersion,
      ),
      preferences.setString(_geminiApiKeyKey, next.geminiApiKey),
      preferences.setString(_geminiModelKey, next.geminiModel),
    ]);
  }

  T _readEnum<T extends Enum>(
    SharedPreferences preferences,
    String key,
    List<T> values,
    T fallback,
  ) {
    final name = preferences.getString(key);
    if (name == null) return fallback;

    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);
