# Triatlón D

App personal de iPhone tipo videojuego para mis entrenos de triatlón ("La Travesía").
El personaje soy yo: sube o baja según lo que entreno, cómo duermo y cómo me recupero.

## Cómo se compila

Igual que MotoTestA2: no hace falta Mac.

1. Cada push a `main` lanza el workflow **Compilar IPA** en un Mac de GitHub.
2. En la pestaña Actions se descarga el artifact `TriatlonD-ipa`.
3. Se instala en el iPhone con Sideloadly y el Apple ID gratuito (caduca a los 7 días).

## Estructura

- `TriatlonD/App`: punto de entrada y pestañas.
- `TriatlonD/Modelos`: los datos del día tal como los entrega el servidor del portátil.
- `TriatlonD/Servicios`: colores, reglas del juego y datos de ejemplo.
- `TriatlonD/Vistas`: las cinco pantallas (Base, Travesía, Semana, Lesión, Ficha).

## Estado

Versión 0.1: esqueleto con datos de ejemplo guardados en la app. Aún no se conecta al servidor.
En el repositorio no hay claves ni datos personales: viven en el servidor del portátil.
