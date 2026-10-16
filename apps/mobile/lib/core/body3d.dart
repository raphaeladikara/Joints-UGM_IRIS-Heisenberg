import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'theme.dart';

/// Tubuh 3D interaktif tanpa aset: mesh dibangun dari elipsoid dan kapsul, diproyeksikan perspektif, diurutkan
/// kedalamannya, dan diwarnai dengan cahaya Lambert + cahaya tepi. Geser untuk memutar; ketuk titik untuk detail.
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
  const Body3D({super.key, required this.spots, this.selected, this.onSelect, this.height = 380});
  final List<BodySpot> spots;
  final String? selected;
  final ValueChanged<String>? onSelect;
  final double height;

  @override
  State<Body3D> createState() => _Body3DState();
}

class _Body3DState extends State<Body3D> with SingleTickerProviderStateMixin {
  static final _mesh = _Mesh.human();
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
            painter: _BodyPainter(_mesh, _yaw, _t, widget.spots, widget.selected, (h) => _hits = h),
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
  'yellow' => const Color(0xFFC98A00),
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
      final rim = math.pow(1 - nz2.abs().clamp(0.0, 1.0), 3).toDouble() * 0.55; // tepi biru lembut
      final base = 0.50 + lambert * 0.46 + fill;
      // Porselen biru-krem: gelap ke arah brandDeep, terang ke arah putih krem.
      final r = (196 * base + 120 * rim).clamp(0, 255).toInt();
      final g = (208 * base + 160 * rim).clamp(0, 255).toInt();
      final b = (228 * base + 230 * rim).clamp(0, 255).toInt();
      colors[i] = (0xFF << 24) | (r << 16) | (g << 8) | b;
    }

    // Bayangan lantai.
    final floorY = oy - (0 - _centerY) * cp * focal / _camDist;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(ox, floorY + 4), width: size.height * 0.36, height: size.height * 0.05),
      Paint()
        ..color = const Color(0x22243048)
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

/// Mesh manusia sederhana: daftar verteks (posisi + normal) dan indeks segitiga.
class _Mesh {
  _Mesh(this.vx, this.vy, this.vz, this.nx, this.ny, this.nz, this.tri);
  final Float32List vx, vy, vz, nx, ny, nz;
  final Int32List tri;

  factory _Mesh.human() {
    final b = _MeshBuilder();
    // Kepala, leher, badan (tiga elipsoid bertumpuk supaya ada pinggang).
    b.ellipsoid((0, 1.615, 0.005), (0.092, 0.112, 0.102));
    b.capsule((0, 1.44, -0.005), (0, 1.53, 0), 0.046);
    b.ellipsoid((0, 1.30, 0), (0.185, 0.17, 0.108));
    b.ellipsoid((0, 1.10, 0.005), (0.152, 0.15, 0.098));
    b.ellipsoid((0, 0.93, 0), (0.168, 0.11, 0.104));
    for (final sx in [-1.0, 1.0]) {
      b.ellipsoid((0.175 * sx, 1.385, -0.005), (0.07, 0.062, 0.068)); // bahu
      b.capsule((0.205 * sx, 1.37, -0.01), (0.245 * sx, 1.12, -0.01), 0.047); // lengan atas
      b.capsule((0.245 * sx, 1.12, -0.01), (0.27 * sx, 0.87, 0.02), 0.039); // lengan bawah
      b.ellipsoid((0.275 * sx, 0.80, 0.025), (0.03, 0.06, 0.042)); // tangan
      b.capsule((0.088 * sx, 0.90, 0), (0.098 * sx, 0.50, 0.0), 0.074); // paha
      b.capsule((0.098 * sx, 0.50, 0.0), (0.098 * sx, 0.09, -0.015), 0.052); // betis
      b.ellipsoid((0.098 * sx, 0.04, 0.035), (0.045, 0.032, 0.105)); // kaki
    }
    return b.build();
  }
}

class _MeshBuilder {
  final _p = <double>[];
  final _n = <double>[];
  final _t = <int>[];

  void _grid(int rows, int cols, (double, double, double, double, double, double) Function(int r, int c) at) {
    final start = _p.length ~/ 3;
    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= cols; c++) {
        final (x, y, z, nx, ny, nz) = at(r, c);
        _p.addAll([x, y, z]);
        final len = math.sqrt(nx * nx + ny * ny + nz * nz);
        _n.addAll([nx / len, ny / len, nz / len]);
      }
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final a = start + r * (cols + 1) + c, b2 = a + cols + 1;
        _t.addAll([a, a + 1, b2, a + 1, b2 + 1, b2]);
      }
    }
  }

  void ellipsoid((double, double, double) c, (double, double, double) r, {int rows = 14, int cols = 22}) {
    final (cx, cy, cz) = c;
    final (ax, ay, az) = r;
    _grid(rows, cols, (i, j) {
      final th = math.pi * i / rows, ph = 2 * math.pi * j / cols;
      final ux = math.sin(th) * math.cos(ph), uy = math.cos(th), uz = math.sin(th) * math.sin(ph);
      return (cx + ax * ux, cy + ay * uy, cz + az * uz, ux / ax, uy / ay, uz / az);
    });
  }

  /// Kapsul dari a ke b: dua belahan bola disambung silinder (baris khatulistiwa digandakan).
  void capsule((double, double, double) a, (double, double, double) b, double radius, {int half = 7, int cols = 18}) {
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
    });
  }

  _Mesh build() {
    final n = _p.length ~/ 3;
    final vx = Float32List(n), vy = Float32List(n), vz = Float32List(n), nx = Float32List(n), ny = Float32List(n), nz = Float32List(n);
    for (var i = 0; i < n; i++) {
      vx[i] = _p[i * 3];
      vy[i] = _p[i * 3 + 1];
      vz[i] = _p[i * 3 + 2];
      nx[i] = _n[i * 3];
      ny[i] = _n[i * 3 + 1];
      nz[i] = _n[i * 3 + 2];
    }
    return _Mesh(vx, vy, vz, nx, ny, nz, Int32List.fromList(_t));
  }
}
