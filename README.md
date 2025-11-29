# Análisis de Fallas entre Espiras en Transformadores mediante SFRA

Este repositorio contiene los códigos fuente en MATLAB y los datos experimentales para el análisis de la respuesta en frecuencia de barrido (SFRA) en devanados de transformadores. El estudio se centra en la detección y diferenciación de fallas (cortocircuitos francos y resistivos) mediante técnicas de correlación estadística.

## 📂 Estructura del Repositorio

El proyecto se organiza en dos directorios principales para separar la lógica de procesamiento de los datos:

### 1. `src-codigos/`
Contiene los scripts de MATLAB para el procesamiento de señales:
* **`SFRA_transformado_trif.m`**: Análisis de la respuesta en frecuencia del transformador trifásico.
* **`SFRA_Comparacion_fases.m`**: Comparación entre referencias de 2 fases.
* **`SFRA_Devanado_exp.m`**: Análisis de un devanado experimental con fallas controladas.

### 2. `data-datos_experimentales/`
Contiene los registros de medición en formato **Touchstone (.s2p)**.
* Los archivos `.S2P` contienen los parámetros de dispersión (S-parameters) obtenidos directamente del VNA (Analizador de Redes Vectorial)
* Incluye mediciones de cortocircuito franco, resistivo y configuraciones de circuito abierto/corto.

---

## 📝 Nomenclatura de Archivos

Los archivos experimentales siguen una codificación sistemática (ej. `23072501.S2P`) basada en la fecha de la prueba y el tipo de falla inducida.

**Importante:** Para interpretar correctamente el significado de cada archivo (tipo de conexión, número de espiras en corto, fase analizada, etc.), consulte los archivos de texto de referencia (`Nomenclatura*.txt`) que se encuentran alojados dentro de la carpeta `data-datos_experimentales`.

---

## Instrucciones de Uso

Para ejecutar los análisis, es necesario vincular la carpeta de datos con los scripts de código.

1.  **Clonar el repositorio:**
    ```bash
    git clone [https://github.com/tu-usuario/SFRA-Efectos-Falla-Entre-Espiras.git](https://github.com/tu-usuario/SFRA-Efectos-Falla-Entre-Espiras.git)
    ```
2.  **Abrir MATLAB** y situarse en la carpeta `src-codigos`.
3.  **Configurar el Path:**
    Los scripts requieren acceso a la carpeta de datos. Puede agregar la ruta manualmente o ejecutar:
    ```matlab
    addpath('../data-datos_experimentales');
    savepath;
    ```
4.  **Ejecutar el análisis:**
    Abra `SFRA_transformado_trif.m` y ejecute el script para visualizar las curvas de respuesta.

## 🛠 Requisitos

* **MATLAB** (R2020b o superior recomendado).
* **RF Toolbox**: Necesaria para la función `sparameters` (lectura de archivos .s2p).
* **Signal Processing Toolbox**.

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles.
