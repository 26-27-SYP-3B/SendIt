import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../map/models/saved_route.dart';
import '../map/services/route_storage.dart';
import '../map/services/routing_service.dart';
import 'ride.dart';
import 'ride_map_picker.dart';
import 'ride_panel.dart';
import 'ride_social_page.dart';
import 'rides_api.dart';
import 'rides_controller.dart';

class CreateRidePage extends StatefulWidget {
  const CreateRidePage({
    super.key,
    required this.rides,
    required this.routeStorage,
    required this.routing,
  });

  final RidesController rides;
  final RouteStorage routeStorage;
  final RoutingService routing;

  @override
  State<CreateRidePage> createState() => _CreateRidePageState();
}

class _CreateRidePageState extends State<CreateRidePage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  LatLng? _meetingPoint;
  SavedRoute? _route;
  RideVisibility _visibility = RideVisibility.public;
  String? _groupId;
  Future<List<RideGroup>>? _groups;
  RideDraft? _draft;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _change(VoidCallback change) {
    setState(() {
      change();
      _draft = null;
      _error = null;
    });
  }

  Future<DateTime?> _pickDate() {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = _date;
    return _showPicker(
      title: 'Datum auswählen',
      mode: CupertinoDatePickerMode.date,
      initial: date == null || date.isBefore(today) ? today : date,
      minimumDate: today,
    );
  }

  Future<TimeOfDay?> _pickTime() async {
    final time = _time ?? TimeOfDay.now();
    final selected = await _showPicker(
      title: 'Abfahrtszeit auswählen',
      mode: CupertinoDatePickerMode.time,
      initial: DateTime(2000, 1, 15, time.hour, time.minute),
    );
    return selected == null ? null : TimeOfDay.fromDateTime(selected);
  }

  Future<DateTime?> _showPicker({
    required String title,
    required CupertinoDatePickerMode mode,
    required DateTime initial,
    DateTime? minimumDate,
  }) {
    FocusScope.of(context).unfocus();
    var selected = initial;
    return showCupertinoModalPopup<DateTime>(
      context: context,
      semanticsDismissible: true,
      builder: (context) => Localizations.override(
        context: context,
        locale: const Locale('de', 'AT'),
        child: Semantics(
          namesRoute: true,
          label: title,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: ColoredBox(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Abbrechen'),
                        ),
                        CupertinoButton(
                          onPressed: () => Navigator.of(context).pop(selected),
                          child: const Text('Fertig'),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 216,
                      child: CupertinoDatePicker(
                        mode: mode,
                        initialDateTime: initial,
                        minimumDate: minimumDate,
                        minimumYear: minimumDate?.year ?? 1,
                        maximumYear: mode == CupertinoDatePickerMode.date
                            ? 9999
                            : null,
                        dateOrder: DatePickerDateOrder.dmy,
                        use24hFormat: true,
                        showTimeSeparator: mode == CupertinoDatePickerMode.time,
                        onDateTimeChanged: (value) => selected = value,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _planRoute() async {
    final route = await Navigator.of(context).push<SavedRoute>(
      MaterialPageRoute(
        builder: (_) => RoutePlannerPage(
          meetingPoint: _meetingPoint,
          routing: widget.routing,
        ),
      ),
    );
    if (mounted && route != null) _change(() => _route = route);
  }

  Future<void> _selectSavedRoute() async {
    Future<List<SavedRoute>>? routes;
    final route = await showModalBottomSheet<SavedRoute>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .65,
        child: SafeArea(
          child: FutureBuilder<List<SavedRoute>>(
            future: routes ??= widget.routeStorage.load(),
            builder: (context, snapshot) {
              final entries = snapshot.data;
              return Column(
                children: [
                  Text(
                    'Gespeicherte Routen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.hasError)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Gespeicherte Routen konnten nicht geladen werden.',
                      ),
                    )
                  else if (entries == null)
                    const CircularProgressIndicator()
                  else if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Du kannst berechnete Routen im Karten-Tab speichern.',
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final route = entries[index];
                          return ListTile(
                            leading: const Icon(Icons.alt_route),
                            title: Text(route.name),
                            subtitle: Text(route.result.formattedDistance),
                            onTap: () => Navigator.of(context).pop(route),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (mounted && route != null) _change(() => _route = route);
  }

  Future<void> _manageGroups() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => RideSocialPage(api: widget.rides.api)),
    );
    if (mounted) {
      _change(() {
        _groupId = null;
        _groups = null;
      });
      await widget.rides.refresh();
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      await Scrollable.ensureVisible(
        invalid.first.context,
        duration: const Duration(milliseconds: 200),
      );
      return;
    }
    if (_visibility == RideVisibility.group && _groupId == null) {
      setState(() => _error = 'Wähle eine Gruppe für diese Ausfahrt.');
      return;
    }
    final date = _date!;
    final time = _time!;
    final departure = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (departure.hour != time.hour || departure.minute != time.minute) {
      setState(
        () => _error = 'Diese Uhrzeit ist an diesem Datum wegen der Zeitumstellung ungültig.',
      );
      return;
    }
    if (_draft == null && !departure.isAfter(DateTime.now())) {
      setState(() => _error = 'Die Abfahrt muss in der Zukunft liegen.');
      return;
    }

    final draft = _draft ??= RideDraft(
      title: _title.text.trim(),
      departure: departure,
      meetingPoint: _meetingPoint!,
      route: _route,
      visibility: _visibility,
      groupId: _visibility == RideVisibility.group ? _groupId : null,
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ride = await widget.rides.publish(draft);
      if (mounted) Navigator.of(context).pop(ride);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is RidesException
            ? error.message
            : 'Die Ausfahrt konnte nicht gespeichert werden.';
      });
    }
  }

  Widget _groupField() => FutureBuilder<List<RideGroup>>(
    future: _groups ??= widget.rides.api.groups(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (snapshot.hasError) {
        return OutlinedButton(
          onPressed: _saving ? null : () => setState(() => _groups = null),
          child: const Text('Gruppen erneut laden'),
        );
      }
      final groups = snapshot.data;
      if (groups == null) return const LinearProgressIndicator();
      if (groups.isEmpty) {
        return OutlinedButton.icon(
          onPressed: _saving ? null : _manageGroups,
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Gruppe erstellen oder beitreten'),
        );
      }
      return _dropdown<String>(
        selected: _groupId,
        decoration: _inputDecoration('Gruppe *', icon: Icons.group_outlined),
        options: {for (final group in groups) group.id: group.name},
        onSelected: (id) => _change(() => _groupId = id),
        validator: (id) => id == null ? 'Wähle eine Gruppe.' : null,
      );
    },
  );

  Widget _dropdown<T extends Object>({
    required T? selected,
    required InputDecoration decoration,
    required Map<T, String> options,
    required ValueChanged<T> onSelected,
    FormFieldValidator<T>? validator,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        buttonTheme: theme.buttonTheme.copyWith(alignedDropdown: true),
        focusColor: colors.primary.withValues(alpha: .08),
      ),
      child: DropdownButtonFormField<T>(
        initialValue: selected,
        decoration: decoration,
        isExpanded: true,
        icon: const Icon(Icons.expand_more_rounded, size: 20),
        borderRadius: BorderRadius.circular(18),
        dropdownColor: colors.surfaceContainerLow,
        focusColor: colors.surfaceContainerLow,
        elevation: 4,
        menuMaxHeight: 320,
        selectedItemBuilder: (_) => [
          for (final label in options.values)
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        items: [
          for (final entry in options.entries)
            DropdownMenuItem<T>(
              value: entry.key,
              child: Semantics(
                selected: entry.key == selected,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: entry.key == selected
                            ? TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              )
                            : null,
                      ),
                    ),
                    if (entry.key == selected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
        onChanged: _saving
            ? null
            : (value) {
                if (value != null) onSelected(value);
              },
        validator: validator,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    final colors = Theme.of(context).colorScheme;
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: colors.surfaceContainerLow,
      border: border,
      enabledBorder: border.copyWith(
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ausfahrt erstellen')),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error case final error?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(error, style: TextStyle(color: colors.error)),
                  ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _saving ? null : _submit,
                  child: Text(
                    _saving ? 'Wird gespeichert …' : 'Ausfahrt speichern',
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _title,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 100,
                    decoration: _inputDecoration('Titel *')
                        .copyWith(counterText: ''),
                    onChanged: (_) => _change(() {}),
                    validator: (value) {
                      final length = value?.trim().length ?? 0;
                      return length == 0 || length > 100
                          ? 'Gib einen Titel mit bis zu 100 Zeichen ein.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 22),
                  Text('Abfahrt', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  RidePanel(
                    children: [
                      _PickerField<DateTime>(
                        label: 'Datum *',
                        icon: Icons.calendar_today_outlined,
                        enabled: !_saving,
                        pick: _pickDate,
                        display: formatRideDate,
                        onChanged: (value) => _change(() => _date = value),
                        requiredMessage: 'Wähle ein Datum.',
                      ),
                      _PickerField<TimeOfDay>(
                        label: 'Abfahrtszeit *',
                        icon: Icons.access_time,
                        enabled: !_saving,
                        pick: _pickTime,
                        display: (time) =>
                            formatRideTime(time.hour, time.minute),
                        onChanged: (value) => _change(() => _time = value),
                        requiredMessage: 'Wähle eine Abfahrtszeit.',
                      ),
                      _PickerField<LatLng>(
                        label: 'Treffpunkt auf der Karte *',
                        icon: Icons.location_on_outlined,
                        enabled: !_saving,
                        pick: () => Navigator.of(context).push<LatLng>(
                          MaterialPageRoute(
                            builder: (_) =>
                                MeetingPointPage(initial: _meetingPoint),
                          ),
                        ),
                        display: formatCoordinates,
                        onChanged: (value) =>
                            _change(() => _meetingPoint = value),
                        requiredMessage: 'Wähle einen Treffpunkt.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('Route (optional)', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  RidePanel(
                    children: [
                      if (_route case final route?)
                        ListTile(
                          leading: const Icon(Icons.alt_route),
                          title: Text(route.name),
                          subtitle: Text(route.result.formattedDistance),
                          trailing: IconButton(
                            tooltip: 'Route entfernen',
                            icon: const Icon(Icons.close),
                            onPressed: _saving
                                ? null
                                : () => _change(() => _route = null),
                          ),
                        ),
                      ListTile(
                        enabled: !_saving,
                        leading: const Icon(Icons.alt_route),
                        title: const Text('Route planen'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: _saving ? null : _planRoute,
                      ),
                      ListTile(
                        enabled: !_saving,
                        leading: const Icon(Icons.bookmark_outline),
                        title: const Text('Gespeicherte wählen'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: _saving ? null : _selectSavedRoute,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _dropdown<RideVisibility>(
                    selected: _visibility,
                    decoration: _inputDecoration(
                      'Sichtbarkeit',
                      icon: Icons.visibility_outlined,
                    ),
                    options: {
                      for (final visibility in RideVisibility.values)
                        visibility: visibility.label,
                    },
                    onSelected: (visibility) =>
                        _change(() => _visibility = visibility),
                  ),
                  if (_visibility == RideVisibility.group) ...[
                    const SizedBox(height: 12),
                    _groupField(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerField<T> extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.pick,
    required this.display,
    required this.onChanged,
    required this.requiredMessage,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final Future<T?> Function() pick;
  final String Function(T) display;
  final ValueChanged<T> onChanged;
  final String requiredMessage;

  @override
  Widget build(BuildContext context) => FormField<T>(
    validator: (value) => value == null ? requiredMessage : null,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    builder: (field) {
      final value = field.value;
      final error = field.errorText;
      return ListTile(
        enabled: enabled,
        leading: Icon(icon),
        title: Text(label),
        subtitle: error != null
            ? Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            : value == null
            ? null
            : Text(display(value)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: !enabled
            ? null
            : () async {
                final selected = await pick();
                if (!field.mounted || selected == null) return;
                field.didChange(selected);
                onChanged(selected);
              },
      );
    },
  );
}
