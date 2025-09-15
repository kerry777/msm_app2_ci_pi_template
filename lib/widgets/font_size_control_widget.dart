import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/font_size_provider.dart';

class FontSizeControlWidget extends StatefulWidget {
  final bool isExpanded;
  
  const FontSizeControlWidget({
    super.key,
    this.isExpanded = false,
  });
  
  @override
  _FontSizeControlWidgetState createState() => _FontSizeControlWidgetState();
}

class _FontSizeControlWidgetState extends State<FontSizeControlWidget> {
  bool _isExpanded = false;
  
  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<FontSizeProvider>(
      builder: (context, fontProvider, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: _isExpanded ? _buildExpandedView(fontProvider) : _buildCompactView(fontProvider),
        );
      },
    );
  }
  
  Widget _buildCompactView(FontSizeProvider fontProvider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.text_decrease, size: 20),
          onPressed: fontProvider.scalePercentage > 50 ? fontProvider.decreaseFontSize : null,
          tooltip: '글자 크기 축소',
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${fontProvider.scalePercentage}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.text_increase, size: 20),
          onPressed: fontProvider.scalePercentage < 300 ? fontProvider.increaseFontSize : null,
          tooltip: '글자 크기 확대',
        ),
      ],
    );
  }
  
  Widget _buildExpandedView(FontSizeProvider fontProvider) {
    return Container(
      width: 300,
      padding: EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '글자 크기 조절',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 16),
                onPressed: () {
                  setState(() {
                    _isExpanded = false;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 8),
          
          // 슬라이더
          Row(
            children: [
              Text('50%', style: TextStyle(fontSize: 10)),
              Expanded(
                child: Slider(
                  value: fontProvider.scalePercentage.toDouble(),
                  min: 50,
                  max: 300,
                  divisions: 25, // 10% 단위
                  label: '${fontProvider.scalePercentage}%',
                  onChanged: (value) {
                    fontProvider.setScalePercentage(value.round());
                  },
                ),
              ),
              Text('300%', style: TextStyle(fontSize: 10)),
            ],
          ),
          
          SizedBox(height: 8),
          
          // 빠른 선택 버튼들
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildQuickButton(fontProvider, 75, '작게'),
              _buildQuickButton(fontProvider, 100, '보통'),
              _buildQuickButton(fontProvider, 125, '크게'),
              _buildQuickButton(fontProvider, 150, '매우 크게'),
            ],
          ),
          
          SizedBox(height: 8),
          
          // 미리보기
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '미리보기',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '샘플 텍스트 ABC 123 한글',
                  style: fontProvider.scaleTextStyle(
                    TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickButton(FontSizeProvider fontProvider, int percentage, String label) {
    final isSelected = fontProvider.scalePercentage == percentage;
    
    return GestureDetector(
      onTap: () => fontProvider.setScalePercentage(percentage),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[100],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
          ),
        ),
        child: Text(
          '$label ($percentage%)',
          style: TextStyle(
            fontSize: 10,
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// 플로팅 버튼 형태의 폰트 크기 조절
class FloatingFontSizeControl extends StatefulWidget {
  const FloatingFontSizeControl({super.key});

  @override
  _FloatingFontSizeControlState createState() => _FloatingFontSizeControlState();
}

class _FloatingFontSizeControlState extends State<FloatingFontSizeControl> {
  bool _isVisible = true;
  
  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return Positioned(
        top: 10,
        right: 10,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isVisible = true;
            });
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.text_fields,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      );
    }
    
    return Positioned(
      top: 10,
      right: 10,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FontSizeControlWidget(),
          SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _isVisible = false;
              });
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}