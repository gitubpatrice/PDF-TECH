import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  const half = size ~/ 2;
  const r = 180; // rayon des coins arrondis

  final blue  = img.ColorRgb8(21, 101, 192);   // Material Blue 800
  final red   = img.ColorRgb8(198, 40, 40);    // Material Red 800
  final white = img.ColorRgb8(255, 255, 255);

  // Image RGB
  final image = img.Image(width: size, height: size);

  // ── 4 quadrants : diagonale bleu/rouge ───────────────────────────────────
  // haut-gauche = bleu, haut-droit = rouge, bas-gauche = rouge, bas-droit = bleu
  img.fillRect(image, x1: 0,    y1: 0,    x2: half, y2: half, color: blue);
  img.fillRect(image, x1: half, y1: 0,    x2: size, y2: half, color: red);
  img.fillRect(image, x1: 0,    y1: half, x2: half, y2: size, color: red);
  img.fillRect(image, x1: half, y1: half, x2: size, y2: size, color: blue);

  // ── Coins arrondis (masquage en blanc → arrondi visuel dans le PNG) ───────
  // Pixels hors du rond sont repeints en blanc neutre
  // (le lanceur Android appliquera son propre masque adaptatif)
  _roundCorners(image, r, size);

  // ── Filet blanc sur les axes de division (facultatif – 6 px) ─────────────
  img.fillRect(image, x1: half - 3, y1: r,    x2: half + 3, y2: size - r, color: white);
  img.fillRect(image, x1: r,        y1: half - 3, x2: size - r, y2: half + 3, color: white);

  // ── Texte "PDF" centré ────────────────────────────────────────────────────
  _drawPDF(image, white, size);

  // ── Sauvegarde ────────────────────────────────────────────────────────────
  Directory('assets/icon').createSync(recursive: true);
  final bytes = img.encodePng(image);
  File('assets/icon/app_icon.png').writeAsBytesSync(bytes);
  print('✓ Icône générée : assets/icon/app_icon.png (${(bytes.length / 1024).toStringAsFixed(1)} Ko)');
}

// Repeint les 4 coins (hors du cercle de rayon r) avec une couleur de fond.
// On utilise la couleur du quadrant adjacent pour que le masque du lanceur
// soit propre, mais on peut aussi utiliser blanc.
void _roundCorners(img.Image image, int r, int size) {
  final corners = [
    (cx: r,        cy: r,        x0: 0,        y0: 0),
    (cx: size - r, cy: r,        x0: size - r, y0: 0),
    (cx: r,        cy: size - r, x0: 0,        y0: size - r),
    (cx: size - r, cy: size - r, x0: size - r, y0: size - r),
  ];
  for (final c in corners) {
    for (int dy = 0; dy < r; dy++) {
      for (int dx = 0; dx < r; dx++) {
        final px = c.x0 + dx;
        final py = c.y0 + dy;
        final ddx = px - c.cx;
        final ddy = py - c.cy;
        if (ddx * ddx + ddy * ddy > r * r) {
          // Hors du coin arrondi → couleur du quadrant de ce coin
          final isBlue = (px < 512) == (py < 512);
          image.setPixel(
            px, py,
            isBlue ? img.ColorRgb8(21, 101, 192) : img.ColorRgb8(198, 40, 40),
          );
        }
      }
    }
  }
}

void _drawPDF(img.Image image, img.Color white, int size) {
  // Lettres dessinées en rectangles
  // Hauteur H=220, stroke S=40, largeur P&D=135, F=115, gap=22
  const h = 220;   // letter height
  const s = 40;    // stroke width
  const wPD = 135; // width of P and D
  const wF  = 115; // width of F
  const gap = 22;  // gap between letters

  final totalW = wPD + wPD + wF + gap * 2;
  final x0 = size ~/ 2 - totalW ~/ 2;
  final y0 = size ~/ 2 - h ~/ 2;

  // ── P ─────────────────────────────────────────────────────────────────────
  final px = x0;
  _r(image, px,           y0,           px + s,       y0 + h,       white); // stem
  _r(image, px + s,       y0,           px + wPD,     y0 + s,       white); // top bar
  _r(image, px + wPD - s, y0,           px + wPD,     y0 + h ~/ 2, white); // right side (half)
  _r(image, px + s,       y0 + h ~/ 2 - s, px + wPD, y0 + h ~/ 2, white); // mid bar

  // ── D ─────────────────────────────────────────────────────────────────────
  final dx = x0 + wPD + gap;
  _r(image, dx,           y0,           dx + s,       y0 + h,       white); // stem
  _r(image, dx + s,       y0,           dx + wPD - s ~/ 2, y0 + s, white); // top bar
  _r(image, dx + s,       y0 + h - s,   dx + wPD - s ~/ 2, y0 + h, white); // bot bar
  _r(image, dx + wPD - s, y0 + s,       dx + wPD,    y0 + h - s,   white); // right side

  // ── F ─────────────────────────────────────────────────────────────────────
  final fx = x0 + wPD * 2 + gap * 2;
  _r(image, fx,           y0,           fx + s,       y0 + h,       white); // stem
  _r(image, fx + s,       y0,           fx + wF,      y0 + s,       white); // top bar
  _r(image, fx + s,       y0 + h ~/ 2 - s ~/ 2, fx + wF - 20, y0 + h ~/ 2 + s ~/ 2, white); // mid bar
}

void _r(img.Image image, int x1, int y1, int x2, int y2, img.Color color) {
  img.fillRect(image, x1: x1, y1: y1, x2: x2, y2: y2, color: color);
}
