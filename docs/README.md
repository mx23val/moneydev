# 📚 Documentación Técnica de MoneyDev — Capítulo VII

Bienvenido a la carpeta de documentación técnica y académica del proyecto **MoneyDev**. Esta sección ha sido estructurada para respaldar la entrega formal del **Capítulo VII: Despliegue y Publicación en GitHub**.

---

## 🗂 Estructura de la Documentación

```text
docs/
├── README.md                      # Este documento: Índice general y lineamientos del Capítulo VII
└── evidencias/                    # Sección 7.1.3: Catálogo formal de evidencias
    ├── README.md                  # Matriz de evidencias, diagramas Mermaid y casos de prueba
    ├── capturas/                  # Capturas de pantalla de la aplicación en ejecución
    ├── diagramas/                 # Diagramas de arquitectura y modelos de datos
    └── pruebas/                   # Reportes de pruebas unitarias, de integración y fallback
```

---

## 📑 Secciones del Capítulo VII

### Sección 7.1.1 — Documentación del Proyecto
Disponible en el archivo raíz [README.md](../README.md), cubriendo:
- Propósito, funcionalidades y valor agregado de MoneyDev.
- Arquitectura híbrida (Cloud LLM con Google Gemini + Motor Local de Respaldo).
- Requisitos del sistema (iOS 17+, Swift 5.9+, Xcode 15+, SwiftData, Swift Charts).
- Instrucciones paso a paso para clonación, configuración segura de API Keys y ejecución.

### Sección 7.1.2 — Gestión del Repositorio y Control de Versiones
- Configuración de exclusión estricta mediante `.gitignore` (exclusión de `DerivedData/`, `.xcuserdata`, `.DS_Store`, dumps de texto y archivos de secretos).
- Uso de plantillas versionadas: `Secrets.plist.example`, `Config.xcconfig.example` y `.env.example`.
- Historial de commits ordenado y trazable siguiendo la convención de commits semánticos (*Conventional Commits*).

### Sección 7.1.3 — Evidencias de Despliegue y Pruebas del Sistema
Detalladas en el directorio [docs/evidencias/README.md](evidencias/README.md):
- **Capturas de Pantalla:** Ejecución en simulador y dispositivo físico de los flujos críticos.
- **Diagramas de Arquitectura:** Diagrama de componentes híbridos, flujo de inferencia y modelo de datos relacional de SwiftData.
- **Casos de Prueba:** Validación del motor local determinista, conmutación automática (fallback) ante desconexión de red y validación de autenticación biométrica.
