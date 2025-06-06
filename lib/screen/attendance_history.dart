import 'package:attendance_app/modals/mark_attendance_data.dart';
import 'package:attendance_app/service/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceHistory extends StatefulWidget {
  const AttendanceHistory({super.key});

  @override
  State<AttendanceHistory> createState() => _AttendanceHistoryState();
}

class _AttendanceHistoryState extends State<AttendanceHistory> {
  final FirebaseService _firebaseService = FirebaseService();
  final _employeeNameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _employeeMobileNumberController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _specificDate = DateTime.now();
  String _searchType = 'date';
  bool _isLoading = false;
  bool _hasSearched = false;
  List<MarkAttendanceData> _attendanceList = [];
  String _errorMessage = '';
  List<String> _selectedColumns = [
    'Date',
    'Name',
    'ID',
    'Status',
    'Time In',
    'Time Out',
    'Lunch Start',
    'Lunch End',
    'Mobile',
  ];
  bool _sortAscending = true;
  int _sortColumnIndex = 0;

  @override
  void initState() {
    super.initState();
    _employeeNameController.addListener(() => setState(() {}));
    _employeeIdController.addListener(() => setState(() {}));
    _employeeMobileNumberController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _employeeNameController.dispose();
    _employeeIdController.dispose();
    _employeeMobileNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context, {
    bool isStartDate = false,
    bool isEndDate = false,
    bool isSpecificDate = false,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isSpecificDate
          ? _specificDate ?? DateTime.now()
          : isStartDate
          ? _startDate ?? DateTime.now()
          : _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isSpecificDate) {
          _specificDate = picked;
        } else if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _searchAttendanceHistories() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = '';
      _attendanceList.clear();
    });

    try {
      List<MarkAttendanceData> results = [];

      if (_searchType == 'date') {
        if (_specificDate != null) {
          results = await _searchBySpecificDate(_specificDate!);
        } else if (_startDate != null && _endDate != null) {
          results = await _searchByDateRange(_startDate!, _endDate!);
        }
      } else if (_searchType == 'name' &&
          _employeeNameController.text.isNotEmpty) {
        results = await _searchByEmployeeName(
          _employeeNameController.text.trim(),
        );
      } else if (_searchType == 'id' && _employeeIdController.text.isNotEmpty) {
        results = await _searchByEmployeeId(_employeeIdController.text.trim());
      } else if (_searchType == 'mobile' &&
          _employeeMobileNumberController.text.isNotEmpty) {
        results = await _searchByMobileNumber(
          _employeeMobileNumberController.text.trim(),
        );
      }

      setState(() {
        _attendanceList = results;
        if (results.isEmpty) {
          _errorMessage = 'No attendance records found';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching attendance: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<MarkAttendanceData>> _searchBySpecificDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _firebaseService.getAllMarkAttendanceData();
    return snapshot.where((record) {
      final recordDate = record.attendanceDate.toDate();
      return !recordDate.isBefore(startOfDay) && !recordDate.isAfter(endOfDay);
    }).toList();
  }

  Future<List<MarkAttendanceData>> _searchByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);

    final snapshot = await _firebaseService.getAllMarkAttendanceData();
    return snapshot.where((record) {
      final recordDate = record.attendanceDate.toDate();
      return !recordDate.isBefore(startDate) && !recordDate.isAfter(endDate);
    }).toList();
  }

  Future<List<MarkAttendanceData>> _searchByEmployeeName(String name) async {
    final snapshot = await _firebaseService.getAllMarkAttendanceData();
    return snapshot.where((record) {
      return record.employeeName.toLowerCase().contains(name.toLowerCase());
    }).toList();
  }

  Future<List<MarkAttendanceData>> _searchByEmployeeId(String id) async {
    final snapshot = await _firebaseService.getAllMarkAttendanceData();
    return snapshot.where((record) {
      return record.employeeId.toLowerCase().contains(id.toLowerCase());
    }).toList();
  }

  Future<List<MarkAttendanceData>> _searchByMobileNumber(String mobile) async {
    final snapshot = await _firebaseService.getAllMarkAttendanceData();
    return snapshot.where((record) {
      return record.mobileNumber?.contains(mobile) ?? false;
    }).toList();
  }

  Widget _buildSearchTypeSelector() {
    return DropdownButtonFormField<String>(
      value: _searchType,
      decoration: InputDecoration(
        labelText: 'Search By',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: const [
        DropdownMenuItem(value: 'date', child: Text('Date')),
        DropdownMenuItem(value: 'name', child: Text('Employee Name')),
        DropdownMenuItem(value: 'id', child: Text('Employee ID')),
        DropdownMenuItem(value: 'mobile', child: Text('Mobile Number')),
      ],
      onChanged: (value) {
        setState(() {
          _searchType = value!;
          _hasSearched = false;
          _attendanceList.clear();
          _errorMessage = '';
          _employeeNameController.clear();
          _employeeIdController.clear();
          _employeeMobileNumberController.clear();
          _specificDate = null;
          _startDate = null;
          _endDate = null;
        });
      },
    );
  }

  Widget _buildDateSearchOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Specific Date'),
                value: 'specific',
                groupValue:
                    _specificDate != null ||
                        (_startDate == null && _endDate == null)
                    ? 'specific'
                    : 'range',
                onChanged: (value) {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                    if (_specificDate == null) {
                      _specificDate = DateTime.now();
                    }
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date Range'),
                value: 'range',
                groupValue: _startDate != null || _endDate != null
                    ? 'range'
                    : 'specific',
                onChanged: (value) {
                  setState(() {
                    _specificDate = null;
                    if (_startDate == null) _startDate = DateTime.now();
                    if (_endDate == null) _endDate = DateTime.now();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_specificDate != null) _buildSpecificDateSelector(),
        if (_startDate != null && _endDate != null) _buildDateRangeSelector(),
      ],
    );
  }

  Widget _buildDateRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _selectDate(context, isStartDate: true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Start Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  child: Text(
                    _startDate != null
                        ? DateFormat('dd-MM-yyyy').format(_startDate!)
                        : 'Select start date',
                    style: TextStyle(
                      color: _startDate != null
                          ? Colors.black87
                          : Colors.grey[600],
                      fontWeight: _startDate != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _selectDate(context, isEndDate: true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'End Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  child: Text(
                    _endDate != null
                        ? DateFormat('dd-MM-yyyy').format(_endDate!)
                        : 'Select end date',
                    style: TextStyle(
                      color: _endDate != null
                          ? Colors.black87
                          : Colors.grey[600],
                      fontWeight: _endDate != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_startDate != null && _endDate != null)
                ? _searchAttendanceHistories
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Search by Date Range',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecificDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _selectDate(context, isSpecificDate: true),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Select Date',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            child: Text(
              _specificDate != null
                  ? DateFormat('dd-MM-yyyy').format(_specificDate!)
                  : 'Select a date',
              style: TextStyle(
                color: _specificDate != null
                    ? Colors.black87
                    : Colors.grey[600],
                fontWeight: _specificDate != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _specificDate != null
                ? _searchAttendanceHistories
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Search by Specific Date',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextInputField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => controller.clear()),
              )
            : null,
      ),
    );
  }

  Widget _buildSearchInputFields() {
    switch (_searchType) {
      case 'name':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextInputField(
              label: 'Employee Name',
              controller: _employeeNameController,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _employeeNameController.text.trim().isNotEmpty
                    ? _searchAttendanceHistories
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Search by Name',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      case 'id':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextInputField(
              label: 'Employee ID',
              controller: _employeeIdController,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _employeeIdController.text.trim().isNotEmpty
                    ? _searchAttendanceHistories
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Search by ID',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      case 'mobile':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextInputField(
              label: 'Mobile Number',
              controller: _employeeMobileNumberController,
              keyboardType: TextInputType.phone,
              hintText: 'Enter mobile number',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _employeeMobileNumberController.text.trim().isNotEmpty
                    ? _searchAttendanceHistories
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Search by Mobile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      case 'date':
      default:
        return _buildDateSearchOptions();
    }
  }

  Widget _buildAttendanceList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          _errorMessage,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.redAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (_attendanceList.isEmpty && _hasSearched) {
      return const Center(
        child: Text(
          'No attendance records found',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    } else if (_attendanceList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Column selector
        _buildColumnSelector(),
        const SizedBox(height: 10),
        // Excel-like table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DataTable(
              sortColumnIndex: _sortColumnIndex,
              sortAscending: _sortAscending,
              headingRowColor: MaterialStateProperty.resolveWith<Color>(
                (Set<MaterialState> states) => Colors.orange.shade100,
              ),
              columns: _buildDataColumns(),
              rows: _buildDataRows(),
              dividerThickness: 1,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 60,
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              dataTextStyle: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        // Export button
        if (_attendanceList.isNotEmpty) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export functionality coming soon'),
                ),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Export to Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildColumnSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        const Text('Columns:', style: TextStyle(fontWeight: FontWeight.bold)),
        ..._allAvailableColumns.map((column) {
          return FilterChip(
            label: Text(column),
            selected: _selectedColumns.contains(column),
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedColumns.add(column);
                } else {
                  _selectedColumns.remove(column);
                }
              });
            },
            checkmarkColor: Colors.white,
            selectedColor: Colors.orange.shade700,
            labelStyle: TextStyle(
              color: _selectedColumns.contains(column)
                  ? Colors.white
                  : Colors.black87,
            ),
          );
        }).toList(),
      ],
    );
  }

  List<String> get _allAvailableColumns => [
    'Date',
    'Name',
    'ID',
    'Status',
    'Time In',
    'Time Out',
    'Lunch Start',
    'Lunch End',
    'Mobile',
  ];

  List<DataColumn> _buildDataColumns() {
    return _selectedColumns.map((column) {
      return DataColumn(
        label: Text(column),
        tooltip: column,
        onSort: (columnIndex, ascending) {
          _onSort(columnIndex, ascending);
        },
      );
    }).toList();
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;

      String column = _selectedColumns[columnIndex];
      _attendanceList.sort((a, b) {
        int compareResult;
        switch (column) {
          case 'Date':
            compareResult = a.attendanceDate.compareTo(b.attendanceDate);
            break;
          case 'Name':
            compareResult = a.employeeName.compareTo(b.employeeName);
            break;
          case 'ID':
            compareResult = a.employeeId.compareTo(b.employeeId);
            break;
          case 'Status':
            compareResult = (a.status ?? '').compareTo(b.status ?? '');
            break;
          case 'Time In':
            compareResult = (a.officeTimeIn ?? Timestamp(0, 0)).compareTo(
              b.officeTimeIn ?? Timestamp(0, 0),
            );
            break;
          case 'Time Out':
            compareResult = (a.officeTimeOut ?? Timestamp(0, 0)).compareTo(
              b.officeTimeOut ?? Timestamp(0, 0),
            );
            break;
          case 'Lunch Start':
            compareResult = (a.lunchTimeStart ?? Timestamp(0, 0)).compareTo(
              b.lunchTimeStart ?? Timestamp(0, 0),
            );
            break;
          case 'Lunch End':
            compareResult = (a.lunchTimeEnd ?? Timestamp(0, 0)).compareTo(
              b.lunchTimeEnd ?? Timestamp(0, 0),
            );
            break;
          case 'Mobile':
            compareResult = (a.mobileNumber ?? '').compareTo(
              b.mobileNumber ?? '',
            );
            break;
          default:
            compareResult = 0;
        }
        return ascending ? compareResult : -compareResult;
      });
    });
  }

  List<DataRow> _buildDataRows() {
    return _attendanceList.map((attendance) {
      final cells = _selectedColumns.map((column) {
        return DataCell(_buildCellContent(column, attendance));
      }).toList();

      return DataRow(
        cells: cells,
        color: MaterialStateProperty.resolveWith<Color>((
          Set<MaterialState> states,
        ) {
          // Alternate row colors for better readability
          return _attendanceList.indexOf(attendance) % 2 == 0
              ? Colors.white
              : Colors.grey.shade50;
        }),
      );
    }).toList();
  }

  Widget _buildCellContent(String column, MarkAttendanceData attendance) {
    String formatTimestamp(Timestamp? timestamp) {
      return timestamp != null
          ? DateFormat('hh:mm a').format(timestamp.toDate())
          : 'N/A';
    }

    switch (column) {
      case 'Date':
        return Text(
          DateFormat('dd-MM-yyyy').format(attendance.attendanceDate.toDate()),
        );
      case 'Name':
        return Text(attendance.employeeName);
      case 'ID':
        return Text(attendance.employeeId);
      case 'Status':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(attendance.status).withAlpha(51),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getStatusColor(attendance.status),
              width: 1,
            ),
          ),
          child: Text(
            attendance.status?.toUpperCase() ?? 'N/A',
            style: TextStyle(
              color: _getStatusColor(attendance.status),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case 'Time In':
        return Text(formatTimestamp(attendance.officeTimeIn));
      case 'Time Out':
        return Text(formatTimestamp(attendance.officeTimeOut));
      case 'Lunch Start':
        return Text(formatTimestamp(attendance.lunchTimeStart));
      case 'Lunch End':
        return Text(formatTimestamp(attendance.lunchTimeEnd));
      case 'Mobile':
        return Text(attendance.mobileNumber ?? 'N/A');
      default:
        return const Text('N/A');
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'half-day':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E5),
      appBar: AppBar(
        backgroundColor: Colors.orange.shade700,
        title: const Text('Attendance Report'),
        centerTitle: true,
        actions: [
          if (_attendanceList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Select Columns to Display',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildColumnSelector(),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchTypeSelector(),
              const SizedBox(height: 20),
              _buildSearchInputFields(),
              const SizedBox(height: 30),
              _buildAttendanceList(),
            ],
          ),
        ),
      ),
    );
  }
}
