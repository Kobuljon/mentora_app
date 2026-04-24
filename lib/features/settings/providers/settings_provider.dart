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
  });

  final ThemeMode themeMode;
  final MentoraLanguage language;
  final bool grammarAssistEnabled;
  final bool pronunciationAssistEnabled;
  final bool offlineModeEnabled;
  final bool autoSaveNotesEnabled;
  final DefaultStudyView defaultStudyView;
  final ReaderTextSize readerTextSize;

  bool get darkModeEnabled => themeMode == ThemeMode.dark;

  AppSettings copyWith({
    ThemeMode? themeMode,
    MentoraLanguage? language,
    bool? grammarAssistEnabled,
    bool? pronunciationAssistEnabled,
    bool? offlineModeEnabled,
    bool? autoSaveNotesEnabled,
    DefaultStudyView? defaultStudyView,
    ReaderTextSize? readerTextSize,
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
