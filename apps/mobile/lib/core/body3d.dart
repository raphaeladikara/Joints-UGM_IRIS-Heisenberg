import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'theme.dart';

/// Tubuh 3D interaktif tanpa aset: mesh lansia pria (peci, kemeja batik, tongkat) atau wanita (sanggul, kebaya,
/// kain jarik) dari elipsoid, kapsul, dan loft; diproyeksikan perspektif, diurutkan kedalamannya, dan diwarnai
/// warna bahan × cahaya Lambert + cahaya tepi hijau. Geser untuk memutar; ketuk titik untuk detail.
/// Jalan sama di Android dan web, tanpa WebView atau file .glb.
class BodySpot {
  const BodySpot({required this.id, required this.label, required this.anchor, required this.level, required this.icon, this.value});
  final String id;
  final String label;

  /// Titik di ruang model (meter, y ke atas, 0 di telapak kaki, z ke depan).
  final (double, double, double) anchor;

  /// green | yellow | red | none (abu-abu: belum ada data).
  final String level;
  final IconData icon;
  final String? value;
}

class Body3D extends StatefulWidget {
  const Body3D({super.key, required this.spots, this.sex = 'F', this.selected, this.onSelect, this.height = 380});
  final List<BodySpot> spots;

  /// 'M' lansia pria, selain itu lansia wanita (kolom `sex` pasien).
  final String sex;
  final String? selected;
  final ValueChanged<String>? onSelect;
  final double height;

  @override
  State<Body3D> createState() => _Body3DState();
}

class _Body3DState extends State<Body3D> with SingleTickerProviderStateMixin {
  static final _meshes = <bool, _Mesh>{};
  late final Ticker _ticker;
  double _yaw = -0.45;
  double _vel = 0; // rad/detik setelah jari dilepas
  bool _dragging = false;
  Duration _last = Duration.zero;
  double _t = 0; // waktu untuk denyut titik
  List<_ProjectedSpot> _hits = const [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    setState(() {
      _t += dt;
      if (_dragging) return;
      if (_vel.abs() > 0.02) {
        _yaw += _vel * dt;
        _vel *= math.pow(0.04, dt).toDouble(); // gesekan eksponensial
      } else if (!still) {
        _yaw += 0.22 * dt; // putaran pelan saat diam
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tapAt(Offset p) {
    _ProjectedSpot? best;
    var bestD = 34.0;
    for (final h in _hits) {
      final d = (h.pos - p).distance;
      if (d < bestD) (best, bestD) = (h, d);
    }
    if (best != null) {
      widget.onSelect?.call(best.spot.id);
      _vel = 0;
      // Putar supaya titik terpilih menghadap depan.
      final (x, _, z) = best.spot.anchor;
      final target = -math.atan2(x, z == 0 && x == 0 ? 1 : z);
      var delta = (target - _yaw) % (2 * math.pi);
      if (delta > math.pi) delta -= 2 * math.pi;
      _vel = delta * 3.2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Model tubuh 3D. ${widget.spots.map((s) => '${s.label}: ${s.value ?? 'belum ada data'}').join('. ')}',
      child: SizedBox(
        height: widget.height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => (_dragging = true, _vel = 0),
          onHorizontalDragUpdate: (d) => setState(() => _yaw += d.delta.dx * 0.012),
          onHorizontalDragEnd: (d) {
            _dragging = false;
            _vel = (d.velocity.pixelsPerSecond.dx * 0.012).clamp(-9.0, 9.0);
          },
          onTapUp: (d) => _tapAt(d.localPosition),
          child: CustomPaint(
            size: Size.infinite,
            painter: _BodyPainter(_meshes.putIfAbsent(widget.sex == 'M', () => _Mesh.elder(male: widget.sex == 'M')), _yaw, _t, widget.spots, widget.selected, (h) => _hits = h),
          ),
        ),
      ),
    );
  }
}

class _ProjectedSpot {
  const _ProjectedSpot(this.spot, this.pos, this.front);
  final BodySpot spot;
  final Offset pos;
  final bool front;
}

Color spotColor(String level) => switch (level) {
  'red' => TColors.red,
  'yellow' => const Color(0xFFD99A12),
  'green' => TColors.green,
  _ => TColors.grey,
};

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.mesh, this.yaw, this.t, this.spots, this.selected, this.report);
  final _Mesh mesh;
  final double yaw;
  final double t;
  final List<BodySpot> spots;
  final String? selected;
  final void Function(List<_ProjectedSpot>) report;

  static const _pitch = -0.10;
  static const _camDist = 4.2;
  static const _centerY = 0.86;

  @override
  void paint(Canvas canvas, Size size) {
    final n = mesh.vx.length;
    final cy = math.cos(yaw), sy = math.sin(yaw), cp = math.cos(_pitch), sp = math.sin(_pitch);
    final focal = size.height * 2.15;
    final ox = size.width / 2, oy = size.height * 0.5;

    // Rotasi Y (yaw) lalu X (pitch); kamera di +z menghadap -z.
    final px = Float32List(n), py = Float32List(n), pz = Float32List(n);
    final colors = Int32List(n);
    const lx = -0.45, ly = 0.62, lz = 0.64; // arah cahaya kunci (ternormalisasi kira-kira)
    for (var i = 0; i < n; i++) {
      final x0 = mesh.vx[i], y0 = mesh.vy[i] - _centerY, z0 = mesh.vz[i];
      final x1 = x0 * cy + z0 * sy, z1 = -x0 * sy + z0 * cy;
      final y2 = y0 * cp - z1 * sp, z2 = y0 * sp + z1 * cp;
      final s = focal / (_camDist - z2);
      px[i] = ox + x1 * s;
      py[i] = oy - y2 * s;
      pz[i] = z2;

      final nx0 = mesh.nx[i], ny0 = mesh.ny[i], nz0 = mesh.nz[i];
      final nx1 = nx0 * cy + nz0 * sy, nz1 = -nx0 * sy + nz0 * cy;
      final ny2 = ny0 * cp - nz1 * sp, nz2 = ny0 * sp + nz1 * cp;
      final lambert = math.max(0.0, nx1 * lx + ny2 * ly + nz2 * lz);
      final fill = math.max(0.0, -nx1 * 0.6 + nz2 * 0.4) * 0.25; // cahaya isi dari kanan
      final rim = math.pow(1 - nz2.abs().clamp(0.0, 1.0), 3).toDouble() * 0.55; // tepi hijau lembut
      final base = 0.52 + lambert * 0.50 + fill;
      // Warna bahan × cahaya, ditambah cahaya tepi hijau muda supaya siluet tetap terbaca di latar putih.
      final r = (255 * mesh.cr[i] * base + 150 * rim).clamp(0, 255).toInt();
      final g = (255 * mesh.cg[i] * base + 200 * rim).clamp(0, 255).toInt();
      final b = (255 * mesh.cb[i] * base + 170 * rim).clamp(0, 255).toInt();
      colors[i] = (0xFF << 24) | (r << 16) | (g << 8) | b;
    }

    // Bayangan lantai.
    final floorY = oy - (0 - _centerY) * cp * focal / _camDist;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(ox, floorY + 4), width: size.height * 0.36, height: size.height * 0.05),
      Paint()
        ..color = const Color(0x22243A30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Buang segitiga yang membelakangi kamera, urutkan dari terjauh.
    final tri = mesh.tri;
    final count = tri.length ~/ 3;
    final keep = <int>[];
    final depth = Float32List(count);
    for (var k = 0; k < count; k++) {
      final a = tri[k * 3], b = tri[k * 3 + 1], c = tri[k * 3 + 2];
      final cross = (px[b] - px[a]) * (py[c] - py[a]) - (py[b] - py[a]) * (px[c] - px[a]);
      if (cross >= 0) continue;
      depth[k] = pz[a] + pz[b] + pz[c];
      keep.add(k);
    }
    keep.sort((i, j) => depth[i].compareTo(depth[j]));

    final pos = Float32List(keep.length * 6);
    final col = Int32List(keep.length * 3);
    var w = 0;
    for (final k in keep) {
      for (var m = 0; m < 3; m++) {
        final v = tri[k * 3 + m];
        pos[w * 2] = px[v];
        pos[w * 2 + 1] = py[v];
        col[w] = colors[v];
        w++;
      }
    }
    canvas.drawVertices(ui.Vertices.raw(ui.VertexMode.triangles, pos, colors: col), BlendMode.dst, Paint());

    // Titik organ: posisi diproyeksikan dari ruang model; redup bila di balik badan.
    final hits = <_ProjectedSpot>[];
    for (final s in spots) {
      final (x0, yRaw, z0) = s.anchor;
      final y0 = yRaw - _centerY;
      final x1 = x0 * cy + z0 * sy, z1 = -x0 * sy + z0 * cy;
      final y2 = y0 * cp - z1 * sp, z2 = y0 * sp + z1 * cp;
      final sc = focal / (_camDist - z2);
      final p = Offset(ox + x1 * sc, oy - y2 * sc);
      final front = z2 > -0.02;
      hits.add(_ProjectedSpot(s, p, front));
      final c = spotColor(s.level);
      final sel = s.id == selected;
      final alpha = front ? 1.0 : 0.35;
      final pulse = (math.sin(t * (s.level == 'red' ? 6 : 2.6)) + 1) / 2;
      final ringR = (sel ? 20.0 : 14.0) + pulse * (s.level == 'red' ? 12 : 6);
      canvas.drawCircle(p, ringR, Paint()..color = c.withValues(alpha: 0.18 * alpha * (1 - pulse * 0.6)));
      canvas.drawCircle(p, sel ? 12 : 9, Paint()..color = Colors.white.withValues(alpha: alpha));
      canvas.drawCircle(p, sel ? 8.5 : 6, Paint()..color = c.withValues(alpha: alpha));
      if (sel) {
        canvas.drawCircle(
          p,
          16,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = c.withValues(alpha: alpha),
        );
      }
    }
    report(hits);
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) => true;
}

typedef _Rgb = (double, double, double);
typedef _Paint = _Rgb Function(double x, double y, double z);

/// Palet bahan. Kulit sawo matang, rambut uban, kain dari palet aplikasi (hijau daun, terakota).
abstract final class _Mat {
  static const _Rgb skin = (0.80, 0.62, 0.49);
  static const _Rgb grey = (0.86, 0.86, 0.88);
  static const _Rgb peci = (0.13, 0.14, 0.18);
  static const _Rgb batik = (0.12, 0.42, 0.31);
  static const _Rgb trousers = (0.45, 0.22, 0.16);
  static const _Rgb kebaya = (0.62, 0.79, 0.69); // kebaya hijau muda, jelas beda dari kulit
  static const _Rgb jarik = (0.42, 0.26, 0.15);
  static const _Rgb sandal = (0.36, 0.27, 0.22);
  static const _Rgb wood = (0.56, 0.39, 0.25);
}

_Paint _solid(_Rgb c) => (_, _, _) => c;

/// Mesh lansia: daftar verteks (posisi + normal + warna bahan) dan indeks segitiga.
class _Mesh {
  _Mesh(this.vx, this.vy, this.vz, this.nx, this.ny, this.nz, this.cr, this.cg, this.cb, this.tri);
  final Float32List vx, vy, vz, nx, ny, nz, cr, cg, cb;
  final Int32List tri;

  factory _Mesh.elder({required bool male}) {
    final b = _MeshBuilder();
    // Punggung sedikit membungkuk: leher condong ke depan, kepala maju ±3 cm.
    const head = (0.0, 1.612, 0.035);
    // Kepala diwarnai per verteks. Pria: uban pendek di belakang/samping (atas tertutup peci). Wanita: rambut uban
    // menutup atas & belakang, wajah tetap kulit.
    b.ellipsoid(head, (0.092, 0.112, 0.102), paint: (x, y, z) {
      final up = y - head.$2, back = z - head.$3;
      final hair = male ? (back < -0.035 && up > -0.06) || up > 0.06 : up > 0.04 + back * 0.45 || (back < -0.03 && up > -0.07);
      return hair ? _Mat.grey : _Mat.skin;
    });
    b.capsule((0, 1.43, -0.012), (0, 1.53, 0.02), 0.046, paint: _solid(_Mat.skin));
    if (male) {
      // Peci hitam: silinder oval rata atas.
      b.loft(const [(1.665, 0.0, 0.0, 0.03), (1.666, 0.097, 0.108, 0.03), (1.742, 0.093, 0.104, 0.03), (1.743, 0.0, 0.0, 0.03)],
          perSeg: 2, paint: _solid(_Mat.peci));
    } else {
      b.ellipsoid((0, 1.64, -0.085), (0.052, 0.048, 0.044), paint: _solid(_Mat.grey)); // sanggul
    }
    final top = male ? _Mat.batik : _Mat.kebaya;
    // Badan: satu loft (pinggul → pinggang → dada → bahu), tanpa garis potong. Pria lebih lebar di bahu dan
    // berperut; wanita lebih lebar di pinggul. dz negatif di atas = punggung membulat.
    b.loft(
      male
          ? const [
              (0.79, 0.0, 0.0, 0.0),
              (0.81, 0.115, 0.08, 0.0),
              (0.86, 0.165, 0.105, 0.0),
              (0.93, 0.172, 0.112, 0.006),
              (1.01, 0.168, 0.118, 0.016),
              (1.08, 0.160, 0.114, 0.018),
              (1.15, 0.160, 0.104, 0.010),
              (1.23, 0.176, 0.106, 0.002),
              (1.31, 0.190, 0.106, -0.010),
              (1.37, 0.184, 0.098, -0.020),
              (1.42, 0.122, 0.074, -0.020),
              (1.455, 0.060, 0.050, -0.016),
              (1.47, 0.0, 0.0, -0.014),
            ]
          : const [
              (0.86, 0.0, 0.0, 0.0),
              (0.88, 0.12, 0.08, 0.0),
              (0.93, 0.176, 0.108, -0.004),
              (0.99, 0.160, 0.100, 0.0),
              (1.06, 0.136, 0.090, 0.006),
              (1.14, 0.144, 0.100, 0.012),
              (1.22, 0.160, 0.112, 0.012),
              (1.30, 0.168, 0.100, -0.008),
              (1.36, 0.164, 0.092, -0.018),
              (1.42, 0.112, 0.070, -0.020),
              (1.455, 0.056, 0.048, -0.016),
              (1.47, 0.0, 0.0, -0.014),
            ],
      // Pria: bagian bawah badan berwarna celana (kemeja dimasukkan), jadi pertemuan paha–badan tidak terlihat bergerigi.
      paint: male ? (_, y, _) => y < 0.9 ? _Mat.trousers : top : _solid(top),
    );
    final sh = male ? 0.178 : 0.160;
    for (final sx in [-1.0, 1.0]) {
      final cane = male && sx > 0; // tangan kanan memegang tongkat, sedikit ke depan
      final elbow = (sh * 1.36 * sx, 1.12, -0.01);
      final wrist = cane ? (0.262, 0.86, 0.11) : (sh * 1.5 * sx, 0.87, 0.02);
      b.ellipsoid((sh * sx, 1.375, -0.014), (0.068, 0.06, 0.066), paint: _solid(top)); // bahu
      b.capsule((sh * 1.15 * sx, 1.36, -0.02), elbow, 0.046, paint: _solid(top)); // lengan atas
      b.capsule(elbow, wrist, 0.038, paint: _solid(top)); // lengan bawah (lengan panjang)
      b.ellipsoid((wrist.$1 + 0.004 * sx, wrist.$2 - 0.06, wrist.$3 + 0.006), (0.03, 0.058, 0.042), paint: _solid(_Mat.skin));
      if (male) {
        b.capsule((0.088 * sx, 0.90, 0), (0.098 * sx, 0.50, 0.0), 0.074, paint: _solid(_Mat.trousers)); // paha
        b.capsule((0.098 * sx, 0.50, 0.0), (0.098 * sx, 0.09, -0.015), 0.054, paint: _solid(_Mat.trousers)); // betis
      } else {
        b.capsule((0.092 * sx, 0.20, -0.01), (0.096 * sx, 0.085, -0.015), 0.042, paint: _solid(_Mat.skin)); // di bawah kain
      }
      b.ellipsoid((0.098 * sx, 0.04, 0.035), (0.046, 0.032, 0.106), paint: _solid(_Mat.sandal)); // kaki + sandal
    }
    if (male) {
      // Tongkat kayu dengan gagang.
      b.capsule((0.268, 0.78, 0.115), (0.30, 0.012, 0.16), 0.013, paint: _solid(_Mat.wood));
      b.capsule((0.268, 0.80, 0.115), (0.268, 0.80, 0.045), 0.014, paint: _solid(_Mat.wood));
    } else {
      // Kain jarik panjang sampai mata kaki, sedikit mengembang.
      b.loft(const [
        (0.15, 0.0, 0.0, 0.01),
        (0.152, 0.150, 0.128, 0.01),
        (0.40, 0.168, 0.130, 0.008),
        (0.70, 0.184, 0.128, 0.002),
        (0.90, 0.186, 0.116, -0.004),
        (0.99, 0.166, 0.104, 0.0),
        (1.0, 0.0, 0.0, 0.0),
      ], paint: _solid(_Mat.jarik));
    }
    return b.build();
  }
}

class _MeshBuilder {
  final _p = <double>[];
  final _n = <double>[];
  final _c = <double>[];
  final _t = <int>[];

  void _grid(int rows, int cols, (double, double, double, double, double, double) Function(int r, int c) at, _Paint paint) {
    final start = _p.length ~/ 3;
    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= cols; c++) {
        final (x, y, z, nx, ny, nz) = at(r, c);
        _p.addAll([x, y, z]);
        final len = math.sqrt(nx * nx + ny * ny + nz * nz);
        _n.addAll([nx / len, ny / len, nz / len]);
        final (cr, cg, cb) = paint(x, y, z);
        _c.addAll([cr, cg, cb]);
      }
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final a = start + r * (cols + 1) + c, b2 = a + cols + 1;
        _t.addAll([a, a + 1, b2, a + 1, b2 + 1, b2]);
      }
    }
  }

  void ellipsoid((double, double, double) c, (double, double, double) r, {required _Paint paint, int rows = 16, int cols = 26}) {
    final (cx, cy, cz) = c;
    final (ax, ay, az) = r;
    _grid(rows, cols, (i, j) {
      final th = math.pi * i / rows, ph = 2 * math.pi * j / cols;
      final ux = math.sin(th) * math.cos(ph), uy = math.cos(th), uz = math.sin(th) * math.sin(ph);
      return (cx + ax * ux, cy + ay * uy, cz + az * uz, ux / ax, uy / ay, uz / az);
    }, paint);
  }

  /// Kapsul dari a ke b: dua belahan bola disambung silinder (baris khatulistiwa digandakan).
  void capsule((double, double, double) a, (double, double, double) b, double radius,
      {required _Paint paint, int half = 9, int cols = 26}) {
    final (ax, ay, az) = a;
    final (bx, by, bz) = b;
    var dx = ax - bx, dy = ay - by, dz = az - bz; // sumbu lokal "atas" = menuju a
    final len = math.sqrt(dx * dx + dy * dy + dz * dz);
    dx /= len;
    dy /= len;
    dz /= len;
    // Basis tegak lurus sumbu.
    var (ex, ey, ez) = dz.abs() < 0.9 ? (dy, -dx, 0.0) : (0.0, dz, -dy);
    final el = math.sqrt(ex * ex + ey * ey + ez * ez);
    (ex, ey, ez) = (ex / el, ey / el, ez / el);
    // f = e × d: basis (e, d, f) setangan dengan (x, y, z) elipsoid, jadi urutan segitiga sama.
    final fx = ey * dz - ez * dy, fy = ez * dx - ex * dz, fz = ex * dy - ey * dx;
    final rows = half * 2 + 1;
    _grid(rows, cols, (i, j) {
      final top = i <= half;
      final th = top ? (math.pi / 2) * i / half : math.pi / 2 + (math.pi / 2) * (i - half - 1) / half;
      final ph = 2 * math.pi * j / cols;
      final s = math.sin(th), co = math.cos(th);
      final nx = dx * co + (ex * math.cos(ph) + fx * math.sin(ph)) * s;
      final ny = dy * co + (ey * math.cos(ph) + fy * math.sin(ph)) * s;
      final nz = dz * co + (ez * math.cos(ph) + fz * math.sin(ph)) * s;
      final (cx, cy, cz) = top ? a : b;
      return (cx + nx * radius, cy + ny * radius, cz + nz * radius, nx, ny, nz);
    }, paint);
  }

  /// Permukaan putar berpenampang elips. [profile]: (y, rx, rz, geser-z) dari bawah ke atas; nilai di antaranya
  /// dihaluskan Catmull-Rom. Normal dihitung dari tetangga grid lalu diarahkan keluar.
  void loft(List<(double, double, double, double)> profile, {required _Paint paint, int perSeg = 6, int cols = 40}) {
    double cr(double p0, double p1, double p2, double p3, double t) =>
        0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t);
    final rows = <(double, double, double, double)>[];
    for (var i = 0; i < profile.length - 1; i++) {
      final a = profile[math.max(0, i - 1)], b = profile[i], c = profile[i + 1], d = profile[math.min(profile.length - 1, i + 2)];
      for (var s = 0; s < perSeg; s++) {
        final t = s / perSeg;
        rows.add((
          b.$1 + (c.$1 - b.$1) * t,
          math.max(0, cr(a.$2, b.$2, c.$2, d.$2, t)),
          math.max(0, cr(a.$3, b.$3, c.$3, d.$3, t)),
          cr(a.$4, b.$4, c.$4, d.$4, t),
        ));
      }
    }
    rows.add(profile.last);
    // Urutan baris dari atas ke bawah supaya arah putar segitiga sama dengan elipsoid (θ dari kutub atas).
    final top = rows.reversed.toList();
    (double, double, double) pos(int r, int c) {
      final (y, rx, rz, dz) = top[r.clamp(0, top.length - 1)];
      final ph = 2 * math.pi * c / cols;
      return (rx * math.cos(ph), y, dz + rz * math.sin(ph));
    }

    _grid(top.length - 1, cols, (r, c) {
      final (x, y, z) = pos(r, c);
      final (x1, y1, z1) = pos(r, c + 1);
      final (x0, y0, z0) = pos(r, c - 1);
      final (xu, yu, zu) = pos(r - 1, c);
      final (xd, yd, zd) = pos(r + 1, c);
      final tx = x1 - x0, ty = y1 - y0, tz = z1 - z0; // keliling
      final vx = xd - xu, vy = yd - yu, vz = zd - zu; // ke bawah
      var nx = ty * vz - tz * vy, ny = tz * vx - tx * vz, nz = tx * vy - ty * vx;
      final (_, _, _, dz) = top[r];
      if (nx * x + nz * (z - dz) < 0 || (nx == 0 && nz == 0)) (nx, ny, nz) = (-nx, -ny, -nz);
      if (nx.abs() + ny.abs() + nz.abs() < 1e-9) (nx, ny, nz) = (0.0, r < top.length / 2 ? 1.0 : -1.0, 0.0);
      return (x, y, z, nx, ny, nz);
    }, paint);
  }

  _Mesh build() {
    final n = _p.length ~/ 3;
    final vx = Float32List(n), vy = Float32List(n), vz = Float32List(n), nx = Float32List(n), ny = Float32List(n), nz = Float32List(n);
    final cr = Float32List(n), cg = Float32List(n), cb = Float32List(n);
    for (var i = 0; i < n; i++) {
      vx[i] = _p[i * 3];
      vy[i] = _p[i * 3 + 1];
      vz[i] = _p[i * 3 + 2];
      nx[i] = _n[i * 3];
      ny[i] = _n[i * 3 + 1];
      nz[i] = _n[i * 3 + 2];
      cr[i] = _c[i * 3];
      cg[i] = _c[i * 3 + 1];
      cb[i] = _c[i * 3 + 2];
    }
    return _Mesh(vx, vy, vz, nx, ny, nz, cr, cg, cb, Int32List.fromList(_t));
  }
}
