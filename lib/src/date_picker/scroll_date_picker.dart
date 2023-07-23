import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:scroll_datetime_picker/src/widget/picker_widget.dart';

part 'date_picker_helper.dart';
part 'date_picker_option.dart';
part 'date_picker_style.dart';

class ScrollDatePicker extends StatefulWidget {
  const ScrollDatePicker({
    super.key,
    required this.itemExtent,
    this.style,
    this.onChange,
    this.visibleItem = 3,
    this.infiniteScroll = true,
    this.dateOption = const DatePickerOption(),
  });

  final double itemExtent;
  final int visibleItem;
  final bool infiniteScroll;

  final void Function(DateTime datetime)? onChange;

  final DatePickerOption dateOption;
  final DatePickerStyle? style;

  @override
  State<ScrollDatePicker> createState() => _ScrollDatePickerState();
}

class _ScrollDatePickerState extends State<ScrollDatePicker> {
  final _controllers = List.generate(3, (index) => ScrollController());
  late final ValueNotifier<DateTime> _activeDate;

  late final DatePickerStyle _style;
  late _Helper _helper;

  @override
  void initState() {
    super.initState();

    initializeDateFormatting(widget.dateOption.locale.languageCode);

    _activeDate = ValueNotifier<DateTime>(widget.dateOption.getInitialDate);
    _helper = _Helper(widget.dateOption);
    _style = widget.style ?? DatePickerStyle();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _initDate();
    });
  }

  @override
  void dispose() {
    _activeDate.dispose();
    for (final ctrl in _controllers) {
      ctrl.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: widget.itemExtent * widget.visibleItem,
      child: Row(
        children: List.generate(
          3,
          (colIndex) => Expanded(
            child: PickerWidget(
              itemExtent: widget.itemExtent,
              infiniteScroll: widget.infiniteScroll,
              controller: _controllers[colIndex],
              onChange: (rowIndex) => _onChange(colIndex, rowIndex),
              itemCount: _helper.itemCount(colIndex),
              centerWidget: Container(
                height: widget.itemExtent,
                width: double.infinity,
                decoration: _style.centerDecoration,
              ),
              inactiveBuilder: (rowIndex) {
                final itemCount = _helper.itemCount(colIndex);
                final value = rowIndex % itemCount + 1;
                final disabled = _getDisabled(colIndex, value);

                return Text(
                  _helper.getText(colIndex, rowIndex % itemCount),
                  style: disabled ? _style.disabledStyle : _style.inactiveStyle,
                );
              },
              activeBuilder: (rowIndex) {
                final itemCount = _helper.itemCount(colIndex);
                final value = rowIndex % itemCount + 1;
                final disabled = _getDisabled(colIndex, value);

                return Text(
                  _helper.getText(colIndex, rowIndex % itemCount),
                  style: disabled ? _style.disabledStyle : _style.activeStyle,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _initDate() {
    for (var i = 0; i < 3; i++) {
      late double extent;

      switch (i) {
        case 0:
          extent = _activeDate.value.day - 1;
          break;
        case 1:
          extent = _activeDate.value.month - 1;
          break;
        case 2:
          extent = (_helper.years.indexOf(_activeDate.value.year)).toDouble();
          break;
        default:
          break;
      }

      _controllers[i].animateTo(
        widget.itemExtent * extent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  bool _getDisabled(int colIndex, int value) {
    var disabled = false;

    var date = _activeDate.value;
    if (colIndex == 0) {
      final maxDate = _helper.maxDate(date.month, date.year);
      if (value > maxDate) return true;
      date = DateTime(date.year, date.month, value);
    } else if (colIndex == 1) {
      date = DateTime(date.year, value, date.day);
    } else if (colIndex == 2) {
      final year = widget.dateOption.getMinDate.year + value - 1;
      date = DateTime(year, date.month, date.day);
    }

    if (date.isBefore(widget.dateOption.getMinDate)) {
      disabled = true;
    } else if (date.isAfter(widget.dateOption.getMaxDate)) {
      disabled = true;
    }

    return disabled;
  }

  void _onChange(int colIndex, int rowIndex) {
    late DateTime newDate;

    switch (colIndex) {
      case 0:
        var newDay = rowIndex + 1;
        final maxDate = _helper.maxDate(
          _activeDate.value.month,
          _activeDate.value.year,
        );

        if (newDay > maxDate) newDay = maxDate;

        newDate = DateTime(
          _activeDate.value.year,
          _activeDate.value.month,
          newDay,
        );
        break;
      case 1:
        var newDay = _activeDate.value.day;
        final newMonth = rowIndex + 1;
        final maxDate = _helper.maxDate(newMonth, _activeDate.value.year);

        if (newDay > maxDate) newDay = maxDate;

        newDate = DateTime(_activeDate.value.year, newMonth, newDay);
        break;
      case 2:
        var newDay = _activeDate.value.day;
        final newYear = _helper.years[rowIndex];
        final maxDate = _helper.maxDate(_activeDate.value.month, newYear);

        if (newDay > maxDate) newDay = maxDate;

        newDate = DateTime(newYear, _activeDate.value.month, newDay);
        break;
      default:
        break;
    }

    /* ReCheck day value */
    if (_controllers[0].hasClients) {
      final dayScrollPosition =
          (_controllers[0].offset / widget.itemExtent).floor() % 31 + 1;

      if (newDate.day != dayScrollPosition) {
        final difference = dayScrollPosition - newDate.day;
        final endOffset =
            _controllers[0].offset - (difference * widget.itemExtent);

        if (!_controllers[0].position.isScrollingNotifier.value) {
          Future.delayed(Duration.zero, () {
            _controllers[0].animateTo(
              endOffset,
              duration: const Duration(milliseconds: 500),
              curve: Curves.bounceOut,
            );
          });
        }
      }
    }

    /* Set new date */
    _activeDate.value = newDate;
    widget.onChange?.call(newDate);

    return;
  }
}
