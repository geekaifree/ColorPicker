import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

void main() => runApp(const ColorPickerApp());

class ColorPickerApp extends StatelessWidget {
  const ColorPickerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '颜色拾取器', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true, brightness: Brightness.dark),
    home: const ColorPickerHomePage(),
  );
}

class SavedColor {
  String id, name, hex;
  SavedColor({required this.id, required this.name, required this.hex});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'hex': hex};
  factory SavedColor.fromJson(Map<String, dynamic> j) => SavedColor(id: j['id'], name: j['name'], hex: j['hex']);
}

class ColorPickerHomePage extends StatefulWidget {
  const ColorPickerHomePage({super.key});
  @override
  State<ColorPickerHomePage> createState() => _ColorPickerHomePageState();
}

class _ColorPickerHomePageState extends State<ColorPickerHomePage> {
  double _hue = 0, _sat = 1.0, _val = 1.0;
  double _r = 255, _g = 0, _b = 0;
  double _opacity = 1.0;
  List<SavedColor> _saved = [];
  String _format = 'HEX';
  final _formats = ['HEX', 'RGB', 'HSV', 'HSL'];
  final _nameCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final d = p.getString('saved_colors');
    if (d != null) setState(() => _saved = (json.decode(d) as List).map((e) => SavedColor.fromJson(e)).toList());
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('saved_colors', json.encode(_saved.map((e) => e.toJson()).toList()));
  }

  Color get _color => HSVColor.fromAHSV(1, _hue, _sat, _val).toColor();

  void _updateFromHSV() {
    final c = HSVColor.fromAHSV(1, _hue, _sat, _val).toColor();
    setState(() { _r = c.red.toDouble(); _g = c.green.toDouble(); _b = c.blue.toDouble(); });
  }

  void _updateFromRGB() {
    final c = Color.fromARGB(255, _r.toInt(), _g.toInt(), _b.toInt());
    final hsv = HSVColor.fromColor(c);
    setState(() { _hue = hsv.hue; _sat = hsv.saturation; _val = hsv.value; });
  }

  String get _colorString {
    final c = _color;
    switch (_format) {
      case 'HEX': return '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
      case 'RGB': return 'RGB(${c.red}, ${c.green}, ${c.blue})';
      case 'HSV': return 'HSV(${_hue.toInt()}°, ${(_sat * 100).toInt()}%, ${(_val * 100).toInt()}%)';
      case 'HSL': final hsl = HSLColor.fromColor(c); return 'HSL(${hsl.hue.toInt()}°, ${(hsl.saturation * 100).toInt()}%, ${(hsl.lightness * 100).toInt()}%)';
      default: return '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
    }
  }

  void _saveColor() {
    _nameCtrl.text = _colorString;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('保存颜色'),
      content: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '颜色名称', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () { setState(() => _saved.add(SavedColor(id: DateTime.now().millisecondsSinceEpoch.toString(), name: _nameCtrl.text, hex: '#${_color.value.toRadixString(16).substring(2).toUpperCase()}'))); _save(); Navigator.pop(ctx); }, child: const Text('保存')),
      ],
    ));
  }

  void _copyColor() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已复制: $_colorString'), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎨 颜色拾取器'), centerTitle: true, actions: [
        IconButton(icon: const Icon(Icons.save), onPressed: _saveColor, tooltip: '保存颜色'),
        IconButton(icon: const Icon(Icons.copy), onPressed: _copyColor, tooltip: '复制颜色值'),
      ]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 颜色预览
        Container(width: double.infinity, height: 100, decoration: BoxDecoration(color: _color.withOpacity(_opacity), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)), child: Center(child: Text(_colorString, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _val > 0.5 ? Colors.black : Colors.white)))),
        const SizedBox(height: 16),
        // HSV调节
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HSV 调色', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _buildSlider('色相 H', _hue, 0, 360, Colors.transparent, (v) { setState(() => _hue = v); _updateFromHSV(); }, showGradient: true),
          _buildSlider('饱和度 S', _sat, 0, 1, _color, (v) { setState(() => _sat = v); _updateFromHSV(); }),
          _buildSlider('明度 V', _val, 0, 1, _color, (v) { setState(() => _val = v); _updateFromHSV(); }),
          _buildSlider('透明度 A', _opacity, 0, 1, _color, (v) => setState(() => _opacity = v)),
        ]))),
        const SizedBox(height: 12),
        // RGB调节
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('RGB 调色', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _buildSlider('R 红', _r, 0, 255, Colors.red, (v) { setState(() => _r = v); _updateFromRGB(); }),
          _buildSlider('G 绿', _g, 0, 255, Colors.green, (v) { setState(() => _g = v); _updateFromRGB(); }),
          _buildSlider('B 蓝', _b, 0, 255, Colors.blue, (v) { setState(() => _b = v); _updateFromRGB(); }),
        ]))),
        const SizedBox(height: 12),
        // 格式选择
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          const Text('输出格式: '),
          ..._formats.map((f) => Padding(padding: const EdgeInsets.only(left: 4), child: ChoiceChip(label: Text(f), selected: _format == f, onSelected: (_) => setState(() => _format = f)))),
        ]))),
        const SizedBox(height: 12),
        // 预设颜色
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('预设颜色', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [Colors.red, Colors.pink, Colors.purple, Colors.deepPurple, Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen, Colors.lime, Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange, Colors.brown, Colors.grey, Colors.black, Colors.white].map((c) => GestureDetector(
            onTap: () { final hsv = HSVColor.fromColor(c); setState(() { _hue = hsv.hue; _sat = hsv.saturation; _val = hsv.value; _r = c.red.toDouble(); _g = c.green.toDouble(); _b = c.blue.toDouble(); }); },
            child: Container(width: 32, height: 32, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300))),
          )).toList()),
        ]))),
        const SizedBox(height: 12),
        // 已保存颜色
        if (_saved.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('已保存颜色', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), TextButton(onPressed: () { setState(() => _saved.clear()); _save(); }, child: const Text('清空'))]),
          const SizedBox(height: 8),
          ..._saved.map((sc) => ListTile(dense: true, leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: Color(int.parse(sc.hex.replaceFirst('#', '0xFF'))), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300))), title: Text(sc.name), subtitle: Text(sc.hex), trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () { setState(() => _saved.removeWhere((s) => s.id == sc.id)); _save(); }))),
        ]))),
      ])),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Color color, ValueChanged<double> onChanged, {bool showGradient = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
      SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12))),
      Expanded(child: showGradient ? SliderTheme(data: SliderThemeData(activeTrackColor: color, thumbColor: HSVColor.fromAHSV(1, value, 1, 1).toColor()), child: Slider(value: value, min: min, max: max, onChanged: onChanged)) : Slider(value: value, min: min, max: max, activeColor: color, onChanged: onChanged)),
      SizedBox(width: 50, child: Text(value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2), style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
    ]));
  }
}
