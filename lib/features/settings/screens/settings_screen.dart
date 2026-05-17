import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart' as file_selector;

import '../../../core/services/android_file_share_service.dart';
import '../../models/screens/downloaded_models_screen.dart';
import '../../onboarding/services/model_download_service.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isDarkActive = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SettingsSection(
            title: 'Models',
            children: [
              _SettingsTile(
                icon: Icons.memory_rounded,
                title: 'AI Model',
                subtitle: 'Manage E2B, E4B, and multimodal local engines',
                trailing: const _TrailingText('Local'),
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => const DownloadedModelsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.file_upload_outlined),
                        label: const Text('Import'),
                        onPressed: () => _importModel(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Export'),
                        onPressed: () => _exportModel(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Cloud AI (BYOK)',
            children: [
              _SettingsTile(
                icon: Icons.cloud_outlined,
                title: 'AI provider',
                subtitle: settings.aiBackendProvider == AiBackendProvider.local
                    ? 'Use the downloaded on-device model'
                    : settings.selectedCloudBackendConfigured
                    ? 'Using ${settings.aiBackendProvider.label}'
                    : '${settings.aiBackendProvider.label} needs configuration',
                trailing: _ChoiceChipMenu<AiBackendProvider>(
                  value: settings.aiBackendProvider,
                  values: AiBackendProvider.values,
                  labelFor: (value) => value.label,
                  onSelected: notifier.setAiBackendProvider,
                ),
              ),
              if (settings.aiBackendProvider == AiBackendProvider.openAi) ...[
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.key_rounded,
                  title: 'OpenAI',
                  subtitle:
                      'Model: ${settings.openAiModel}; key ${_secretStatus(settings.openAiApiKey)}',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _configureOpenAi(context, ref),
                ),
              ],
              if (settings.aiBackendProvider ==
                  AiBackendProvider.azureOpenAi) ...[
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.key_rounded,
                  title: 'Azure OpenAI',
                  subtitle:
                      'Deployment: ${_emptyFallback(settings.azureOpenAiDeployment)}; key ${_secretStatus(settings.azureOpenAiApiKey)}',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _configureAzureOpenAi(context, ref),
                ),
              ],
              if (settings.aiBackendProvider == AiBackendProvider.gemini) ...[
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.key_rounded,
                  title: 'Google Gemini',
                  subtitle:
                      'Model: ${settings.geminiModel}; key ${_secretStatus(settings.geminiApiKey)}',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _configureGemini(context, ref),
                ),
              ],
            ],
          ),
          _SettingsSection(
            title: 'For language learners',
            children: [
              _SettingsSwitchTile(
                icon: Icons.spellcheck_rounded,
                title: 'Grammar',
                subtitle: 'Include grammar notes in answers and feedback',
                value: settings.grammarAssistEnabled,
                onChanged: notifier.setGrammarAssistEnabled,
              ),
              const Divider(height: 1),
              _SettingsSwitchTile(
                icon: Icons.record_voice_over_rounded,
                title: 'Pronunciation',
                subtitle: 'Show pronunciation help when it is useful',
                value: settings.pronunciationAssistEnabled,
                onChanged: notifier.setPronunciationAssistEnabled,
              ),
            ],
          ),
          _SettingsSection(
            title: 'My data',
            children: [
              _SettingsTile(
                icon: Icons.history_rounded,
                title: 'My sessions',
                subtitle: 'Review local study and chat sessions',
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Clear sessions',
                  onPressed: () => _confirmClearSessions(context),
                ),
                onTap: () => _showInfo(
                  context,
                  'Session history will appear here after study sessions are saved.',
                ),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.storage_rounded,
                title: 'Data & Storage',
                subtitle: 'Downloaded models and offline files',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => const DownloadedModelsScreen(),
                  ),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'General',
            children: [
              _SettingsSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: 'Dark mode',
                subtitle: 'Use the dark Mentora theme',
                value: isDarkActive,
                onChanged: (enabled) => notifier.setThemeMode(
                  enabled ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: 'App interface language',
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<MentoraLanguage>(
                    value: settings.language,
                    alignment: AlignmentDirectional.centerEnd,
                    items: [
                      for (final language in MentoraLanguage.values)
                        DropdownMenuItem(
                          value: language,
                          child: Text(language.label),
                        ),
                    ],
                    onChanged: (language) {
                      if (language != null) notifier.setLanguage(language);
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              _SettingsSwitchTile(
                icon: Icons.wifi_off_rounded,
                title: 'Offline mode',
                subtitle: 'Prefer local files and downloaded AI models',
                value: settings.offlineModeEnabled,
                onChanged: notifier.setOfflineModeEnabled,
              ),
            ],
          ),
          _SettingsSection(
            title: 'Study',
            children: [
              _SettingsTile(
                icon: Icons.menu_book_outlined,
                title: 'Default view',
                subtitle: 'Reader tab opened for study material',
                trailing: _ChoiceChipMenu<DefaultStudyView>(
                  value: settings.defaultStudyView,
                  values: DefaultStudyView.values,
                  labelFor: (value) => value.label,
                  onSelected: notifier.setDefaultStudyView,
                ),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.format_size_rounded,
                title: 'Text size',
                subtitle: 'Reader text scale',
                trailing: _ChoiceChipMenu<ReaderTextSize>(
                  value: settings.readerTextSize,
                  values: ReaderTextSize.values,
                  labelFor: (value) => value.label,
                  onSelected: notifier.setReaderTextSize,
                ),
              ),
              const Divider(height: 1),
              _SettingsSwitchTile(
                icon: Icons.note_alt_outlined,
                title: 'Auto save notes',
                subtitle: 'Keep notes saved locally while studying',
                value: settings.autoSaveNotesEnabled,
                onChanged: notifier.setAutoSaveNotesEnabled,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _secretStatus(String value) {
    return value.trim().isEmpty ? 'not set' : 'saved';
  }

  String _emptyFallback(String value) {
    return value.trim().isEmpty ? 'not set' : value.trim();
  }

  Future<void> _configureOpenAi(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final apiKeyController = TextEditingController(text: settings.openAiApiKey);
    final modelController = TextEditingController(text: settings.openAiModel);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('OpenAI'),
        content: _ProviderConfigFields(
          children: [
            _ConfigTextField(
              controller: apiKeyController,
              label: 'API key',
              obscureText: true,
            ),
            _ConfigTextField(controller: modelController, label: 'Model'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await ref
          .read(settingsProvider.notifier)
          .setOpenAiConfig(
            apiKey: apiKeyController.text.trim(),
            model: modelController.text.trim(),
          );
    }
    apiKeyController.dispose();
    modelController.dispose();
  }

  Future<void> _configureAzureOpenAi(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final settings = ref.read(settingsProvider);
    final endpointController = TextEditingController(
      text: settings.azureOpenAiEndpoint,
    );
    final apiKeyController = TextEditingController(
      text: settings.azureOpenAiApiKey,
    );
    final deploymentController = TextEditingController(
      text: settings.azureOpenAiDeployment,
    );
    final apiVersionController = TextEditingController(
      text: settings.azureOpenAiApiVersion,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Azure OpenAI'),
        content: _ProviderConfigFields(
          children: [
            _ConfigTextField(
              controller: endpointController,
              label: 'Endpoint',
              hintText: 'https://resource.openai.azure.com',
            ),
            _ConfigTextField(
              controller: apiKeyController,
              label: 'API key',
              obscureText: true,
            ),
            _ConfigTextField(
              controller: deploymentController,
              label: 'Deployment name',
            ),
            _ConfigTextField(
              controller: apiVersionController,
              label: 'API version',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await ref
          .read(settingsProvider.notifier)
          .setAzureOpenAiConfig(
            endpoint: endpointController.text.trim(),
            apiKey: apiKeyController.text.trim(),
            deployment: deploymentController.text.trim(),
            apiVersion: apiVersionController.text.trim(),
          );
    }
    endpointController.dispose();
    apiKeyController.dispose();
    deploymentController.dispose();
    apiVersionController.dispose();
  }

  Future<void> _configureGemini(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final apiKeyController = TextEditingController(text: settings.geminiApiKey);
    final modelController = TextEditingController(text: settings.geminiModel);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Google Gemini'),
        content: _ProviderConfigFields(
          children: [
            _ConfigTextField(
              controller: apiKeyController,
              label: 'API key',
              obscureText: true,
            ),
            _ConfigTextField(controller: modelController, label: 'Model'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await ref
          .read(settingsProvider.notifier)
          .setGeminiConfig(
            apiKey: apiKeyController.text.trim(),
            model: modelController.text.trim(),
          );
    }
    apiKeyController.dispose();
    modelController.dispose();
  }

  Future<void> _importModel(BuildContext context) async {
    final variant = await _chooseModelVariant(
      context,
      title: 'Import model',
      message: 'Choose which local model slot this .litertlm file should use.',
    );
    if (variant == null || !context.mounted) return;

    var progressDialogShown = false;
    final progress = ValueNotifier<DownloadProgress?>(null);
    try {
      final selectedFile = await file_selector.openFile(
        confirmButtonText: 'Import',
      );
      if (selectedFile == null || !context.mounted) return;

      _showProgressDialog(
        context,
        message: 'Importing model...',
        progress: progress,
      );
      progressDialogShown = true;
      final imported = await ModelDownloadService.instance.importModelFile(
        variant: variant,
        fileName: selectedFile.name,
        bytes: selectedFile.openRead(),
        onProgress: (value) => progress.value = value,
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showInfo(
        context,
        'Imported ${imported.variant.displayName} (${imported.sizeLabel}).',
      );
    } on FormatException catch (error) {
      if (!context.mounted) return;
      if (progressDialogShown) _closeProgressDialog(context);
      _showInfo(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      if (progressDialogShown) _closeProgressDialog(context);
      _showInfo(context, 'Import failed: $error');
    } finally {
      progress.dispose();
    }
  }

  Future<void> _exportModel(BuildContext context) async {
    try {
      final models = await ModelDownloadService.instance.getDownloadedModels();
      if (!context.mounted) return;

      if (models.isEmpty) {
        _showInfo(context, 'No local models are available to export.');
        return;
      }

      final selected = models.length == 1
          ? models.first
          : await _chooseDownloadedModel(context, models);
      if (selected == null || !context.mounted) return;

      final action = await _chooseExportAction(context);
      if (action == null || !context.mounted) return;

      switch (action) {
        case _ExportAction.share:
          await AndroidFileShareService.shareFile(
            path: selected.path,
            fileName: selected.variant.fileName,
          );
        case _ExportAction.copyToFolder:
          await _copyModelToFolder(context, selected);
      }
    } catch (error) {
      if (!context.mounted) return;
      _showInfo(context, 'Export failed: $error');
    }
  }

  Future<void> _copyModelToFolder(
    BuildContext context,
    DownloadedModelInfo model,
  ) async {
    final directoryPath = await file_selector.getDirectoryPath(
      confirmButtonText: 'Export here',
    );
    if (directoryPath == null || !context.mounted) return;

    final progress = ValueNotifier<DownloadProgress?>(null);
    _showProgressDialog(
      context,
      message: 'Exporting model...',
      progress: progress,
    );

    try {
      final exportedPath = await ModelDownloadService.instance
          .exportModelToDirectory(
            model: model,
            directoryPath: directoryPath,
            onProgress: (value) => progress.value = value,
          );
      if (!context.mounted) return;
      _closeProgressDialog(context);
      _showInfo(context, 'Exported to $exportedPath');
    } catch (error) {
      if (!context.mounted) return;
      _closeProgressDialog(context);
      _showInfo(context, 'Export failed: $error');
    } finally {
      progress.dispose();
    }
  }

  Future<_ExportAction?> _chooseExportAction(BuildContext context) {
    return showDialog<_ExportAction>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Export model'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, _ExportAction.share),
            child: const _ExportActionOption(
              icon: Icons.ios_share_rounded,
              title: 'Share to another app',
              subtitle: 'Send the .litertlm file to chatbots or file apps',
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, _ExportAction.copyToFolder),
            child: const _ExportActionOption(
              icon: Icons.drive_folder_upload_outlined,
              title: 'Copy to folder',
              subtitle: 'Save the .litertlm file to a different path',
            ),
          ),
        ],
      ),
    );
  }

  Future<ModelVariant?> _chooseModelVariant(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<ModelVariant>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(title),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              message,
              style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final variant in ModelVariant.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, variant),
              child: _ModelOption(variant: variant),
            ),
        ],
      ),
    );
  }

  Future<DownloadedModelInfo?> _chooseDownloadedModel(
    BuildContext context,
    List<DownloadedModelInfo> models,
  ) {
    return showDialog<DownloadedModelInfo>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Export model'),
        children: [
          for (final model in models)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, model),
              child: _ModelOption(
                variant: model.variant,
                trailing: model.sizeLabel,
              ),
            ),
        ],
      ),
    );
  }

  void _showProgressDialog(
    BuildContext context, {
    required String message,
    required ValueNotifier<DownloadProgress?> progress,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<DownloadProgress?>(
            valueListenable: progress,
            builder: (context, value, _) {
              final progressValue = value == null || value.total <= 0
                  ? null
                  : value.fraction.clamp(0.0, 1.0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: progressValue,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Text(message)),
                    ],
                  ),
                  if (value != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      value.total > 0
                          ? '${value.receivedLabel} / ${value.totalLabel}'
                          : value.receivedLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _closeProgressDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _confirmClearSessions(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Clear sessions?'),
        content: const Text(
          'This will remove saved study sessions from this device once session storage is enabled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    _showInfo(context, 'No saved sessions to clear yet.');
  }
}

enum _ExportAction { share, copyToFolder }

class _ProviderConfigFields extends StatelessWidget {
  const _ProviderConfigFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _ConfigTextField extends StatelessWidget {
  const _ConfigTextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        enableSuggestions: !obscureText,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _ExportActionOption extends StatelessWidget {
  const _ExportActionOption({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyLarge),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModelOption extends StatelessWidget {
  const _ModelOption({required this.variant, this.trailing});

  final ModelVariant variant;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(Icons.memory_rounded, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(variant.displayName, style: theme.textTheme.bodyLarge),
              Text(
                variant.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Text(
            trailing!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: _LeadingIcon(icon: icon),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      secondary: _LeadingIcon(icon: icon),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: colorScheme.primary, size: 22),
    );
  }
}

class _TrailingText extends StatelessWidget {
  const _TrailingText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ChoiceChipMenu<T> extends StatelessWidget {
  const _ChoiceChipMenu({
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onSelected,
  });

  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final item in values)
          PopupMenuItem(value: item, child: Text(labelFor(item))),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(labelFor(value)),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
