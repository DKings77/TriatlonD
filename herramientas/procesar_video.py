"""Saca un ciclo de carrera de un vídeo con fondo verde y genera los
fotogramas corredor_1…corredor_N para el catálogo de la app.

Uso: python3 procesar_video.py video.mp4 salida/ [N=8]
"""
import sys, os, json, subprocess, tempfile
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

def fotogramas(video, carpeta):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-i", video, "-vf", "fps=30",
                    os.path.join(carpeta, "f%04d.png")], check=True)
    return sorted(os.path.join(carpeta, f) for f in os.listdir(carpeta) if f.endswith(".png"))

def recortar(ruta, fondo=None):
    im = np.asarray(Image.open(ruta).convert("RGB")).astype(np.float32)
    h, w, _ = im.shape
    if fondo is None:
        bordes = np.concatenate([im[:20].reshape(-1, 3), im[-20:].reshape(-1, 3),
                                 im[:, :20].reshape(-1, 3), im[:, -20:].reshape(-1, 3)])
        fondo = np.median(bordes, axis=0)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    dist = np.linalg.norm(im - fondo, axis=2)
    alfa = np.clip((dist - 40) / 60, 0, 1)
    verde = (g > r + 30) & (g > b + 30)
    alfa[verde & (dist < 120)] = 0
    # marcas de agua en esquinas
    alfa[: int(h * 0.08), : int(w * 0.12)] = 0
    alfa[int(h * 0.90):, int(w * 0.65):] = 0
    etiquetas, n = ndi.label(alfa > 0.5)
    if n > 1:
        tam = ndi.sum(np.ones_like(etiquetas), etiquetas, range(1, n + 1))
        mayor = ndi.binary_dilation(etiquetas == 1 + int(np.argmax(tam)), iterations=3)
        alfa[~mayor] = 0
    reflejo = np.maximum(0, g - np.maximum(r, b)) * (alfa < 1)
    im[..., 1] = g - reflejo
    rgba = np.dstack([im, alfa * 255]).clip(0, 255).astype(np.uint8)
    return rgba, fondo

def firma(rgba):
    """Silueta de las piernas reducida, para comparar posturas."""
    a = rgba[..., 3] > 128
    ys, xs = np.nonzero(a)
    if len(ys) == 0:
        return np.zeros(64 * 32)
    y0, y1 = ys.min(), ys.max()
    piernas = a[y0 + int((y1 - y0) * 0.55): y1 + 1]
    cx = int(xs.mean())
    ventana = piernas[:, max(0, cx - 300): cx + 300]
    return np.asarray(Image.fromarray(ventana.astype(np.uint8) * 255).resize((64, 32))).ravel() / 255.0

def main():
    video, salida = sys.argv[1], sys.argv[2]
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 8
    os.makedirs(salida, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        rutas = fotogramas(video, tmp)
        fondo = None
        cuadros = []
        for r in rutas:
            rgba, fondo = recortar(r, fondo)
            cuadros.append(rgba)
    firmas = np.array([firma(c) for c in cuadros])
    # Periodo del ciclo: el desfase con menor diferencia de silueta (entre 0,4 y 1,5 s a 30 fps)
    mejor, periodo = 1e9, 20
    for p in range(12, min(45, len(firmas) // 2)):
        d = np.mean(np.abs(firmas[p:] - firmas[:-p]))
        if d < mejor:
            mejor, periodo = d, p
    # Inicio: el tramo de un ciclo más estable (el que mejor cierra el bucle)
    inicio = min(range(0, len(firmas) - periodo - 1),
                 key=lambda i: np.mean(np.abs(firmas[i] - firmas[i + periodo])))
    elegidos = [cuadros[inicio + round(k * periodo / n)] for k in range(n)]
    # Mismo encuadre para todos: caja común y centrado por el tronco
    cajas = [Image.fromarray(c).getbbox() for c in elegidos]
    alto = max(b[3] - b[1] for b in cajas)
    ancho = max(b[2] - b[0] for b in cajas)
    lienzo = (int(ancho * 1.15), int(alto * 1.08))
    escala = min(750 / lienzo[0], 825 / lienzo[1])
    for i, c in enumerate(elegidos, 1):
        im = Image.fromarray(c)
        a = c[..., 3].astype(float)
        ys, xs = np.nonzero(a > 128)
        y0 = ys.min()
        tronco = a[y0: y0 + int(alto * 0.45)]
        cx = (tronco.sum(0) * np.arange(tronco.shape[1])).sum() / tronco.sum()
        fondo_t = Image.new("RGBA", (750, 825), (0, 0, 0, 0))
        reducido = im.resize((int(im.width * escala), int(im.height * escala)), Image.LANCZOS)
        suelo = int(ys.max() * escala)
        fondo_t.alpha_composite(reducido, (int(375 - cx * escala), int(825 * 0.96) - suelo))
        nombre = f"corredor_{i}"
        carpeta = os.path.join(salida, f"{nombre}.imageset")
        os.makedirs(carpeta, exist_ok=True)
        fondo_t.save(os.path.join(carpeta, f"{nombre}.png"), optimize=True)
        json.dump({"images": [{"idiom": "universal", "filename": f"{nombre}.png", "scale": "2x"}],
                   "info": {"author": "xcode", "version": 1}},
                  open(os.path.join(carpeta, "Contents.json"), "w"), indent=2)
    print(f"{len(cuadros)} fotogramas, ciclo de {periodo} ({periodo / 30:.2f} s), desde el {inicio}; {n} guardados")

if __name__ == "__main__":
    main()
