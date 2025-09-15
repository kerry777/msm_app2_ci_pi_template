import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';

class EmployeeSelector extends StatefulWidget {
  final String? selectedEmployeeCode;
  final String? selectedEmployeeName;
  final Function(String employeeCode, String employeeName) onEmployeeSelected;
  final String label;
  final String trCd;
  final bool isRequired; // 필수 입력 여부 추가

  const EmployeeSelector({
    super.key,
    this.selectedEmployeeCode,
    this.selectedEmployeeName,
    required this.onEmployeeSelected,
    required this.label,
    required this.trCd,
    this.isRequired = false, // 기본값은 false
  });

  @override
  State<EmployeeSelector> createState() => _EmployeeSelectorState();
}

class _EmployeeSelectorState extends State<EmployeeSelector> {
  // 인스턴스별 캐시로 변경
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = false;
  bool _isLoadingState = false; // 로딩 상태를 인스턴스별로 관리

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    // 캐시 비활성화 - 항상 새로운 데이터 로드
    // if (_employeeCache.containsKey(widget.trCd)) {
    //   setState(() {
    //     _employees = _employeeCache[widget.trCd]!;
    //     _isLoading = false;
    //   });
    //   return;
    // }

    print('=== EmployeeSelector 로딩 시작 ===');
    print('Label: ${widget.label}');
    print('trCd: ${widget.trCd}');
    print('trCd 길이: ${widget.trCd.length}');

    // 이미 로딩 중이면 중복 호출 방지
    if (_isLoadingState) {
      print('이미 로딩 중: ${widget.label}');
      return;
    }

    _isLoadingState = true;
    setState(() => _isLoading = true);
    
    try {
      final api = ApiService();
      print('API 호출 시작: ${widget.label}');
      final employees = await api.getAgencyEmployees(trCd: widget.trCd);
      print('API 응답: ${widget.label} - ${employees.length}개 직원');
      
      if (mounted) {
        setState(() {
          _employees = employees;
          _isLoading = false;
        });
        print('setState 완료: ${widget.label}');
      }
    } catch (e) {
      print('오류 발생: ${widget.label} - $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.get('failed_to_load_employee_list') ?? '직원 목록을 불러오는데 실패했습니다'}: $e')),
        );
      }
    } finally {
      _isLoadingState = false;
    }
  }

  void _showEmployeeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).get('select_label').replaceAll('{label}', widget.label) ?? '${widget.label} 선택'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final employee = _employees[index];
                    final empCode = employee['EMP_CD']?.toString() ?? '';
                    final empName = employee['KOR_NM']?.toString() ?? '';
                    
                    return ListTile(
                      title: Text(empName),
                      subtitle: Text(empCode),
                      trailing: Text(empCode, style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        widget.onEmployeeSelected(empCode, empName);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).get('cancel') ?? '취소'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 필수 입력이면서 선택되지 않은 경우 빨간색 테두리
    final bool isError = widget.isRequired && widget.selectedEmployeeCode == null;
    
    return InkWell(
      onTap: _showEmployeeDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isError ? Colors.red : Colors.grey.shade400,
            width: isError ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.label + (widget.isRequired ? AppLocalizations.of(context).get('required_field') ?? '(*필수입력)' : ''),
                        style: TextStyle(
                          fontSize: 12,
                          color: isError ? Colors.red : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.selectedEmployeeName ?? (AppLocalizations.of(context).get('select_employee') ?? '직원을 선택하세요'),
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.selectedEmployeeName != null 
                          ? Colors.black 
                          : (isError ? Colors.red : Colors.grey.shade500),
                    ),
                  ),
                  if (widget.selectedEmployeeCode != null)
                    Text(
                      '(${widget.selectedEmployeeCode})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
} 