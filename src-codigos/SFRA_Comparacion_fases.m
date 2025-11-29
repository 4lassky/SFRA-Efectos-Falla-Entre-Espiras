%% ==============================================================
%  Script: SFRA - Comparación de dos referencias
%  Descripción: Este script pide dos archivos .S2P (correspondientes
%               a dos fases) y grafica sus curvas en el mismo plot,
%               mostrando las zonas IEEE C57.149-2012.
%
%  Autor: Galindo Barbosa Israel Aldahir - Herrera Godoy Hazael
%  Organización: ESIME ZACATENCO - IPN
%% ==============================================================
%% === Selección de archivos ===
[archivoRef1, carpetaRef1] = uigetfile('*.s2p', 'Selecciona la referencia de la primera fase');
if isequal(archivoRef1,0)
    disp('No seleccionaste archivo de referencia 1.');
    return;
end
rutaRef1 = fullfile(carpetaRef1, archivoRef1);

[archivoRef2, carpetaRef2] = uigetfile('*.s2p', 'Selecciona la referencia de la segunda fase');
if isequal(archivoRef2,0)
    disp('No seleccionaste archivo de referencia 2.');
    return;
end
rutaRef2 = fullfile(carpetaRef2, archivoRef2);
%% === Cargar referencias ===
SparamRef1 = sparameters(rutaRef1);
frecuencia = SparamRef1.Frequencies;
s21Ref1 = rfparam(SparamRef1, 2, 1);

SparamRef2 = sparameters(rutaRef2);
s21Ref2 = rfparam(SparamRef2, 2, 1);
%% === Suavizado ===
porcSuavizado = 0.01; % 1% de puntos usados para suavizar
magnitudRef1 = smooth(mag2db(abs(s21Ref1)), porcSuavizado);
magnitudRef2 = smooth(mag2db(abs(s21Ref2)), porcSuavizado);
%% === Definir zonas de frecuencia ===
zonasFrecuencia = [min(frecuencia) 2e3;
                   2e3              20e3;
                   20e3             1e6;
                   1e6              max(frecuencia)];
%% === Función auxiliar: dibujar zonas ===
function dibujarZonas(zonas, posY, freqDatos)
    % Dibujar líneas divisorias
    for i = 2:size(zonas,1)
        xline(zonas(i,1), '--r', '', 'LineWidth', 2, 'HandleVisibility','off');
    end
    % Colocar etiquetas
    for i = 1:size(zonas,1)
        xPosTexto = sqrt(zonas(i,1) * zonas(i,2)); % centro log
        text(xPosTexto, posY, sprintf('Zona %d', i),'HorizontalAlignment','center','VerticalAlignment','middle','FontWeight','bold', 'FontSize',12);
    end
    % Configuración de ejes
    ejes = gca;
    ejes.XScale = 'log';
    ejes.XMinorGrid = 'on';
    ejes.XAxis.TickLabelFormat = '%.0e';
    ejes.TickDir = 'out';
    ejes.LineWidth = 1.2;
    xlim([min(freqDatos) max(freqDatos)]);
end
%% === Graficar ambas referencias con zonas ===
figure; hold on; grid on;
xlabel('Frecuencia [Hz]'); ylabel('Magnitud [dB]');
title('SFRA: Comparación de dos referencias');
semilogx(frecuencia, magnitudRef1, 'b', 'LineWidth', 1.8, 'DisplayName','Referencia Fase 1');
semilogx(frecuencia, magnitudRef2, 'k', 'LineWidth', 1.8, 'DisplayName','Referencia Fase 2');
legend('show','Location','southwest');
% Dibujar zonas
limY = ylim;
posYTextoZona = limY(1) + 0.9*(limY(2)-limY(1));
dibujarZonas(zonasFrecuencia, posYTextoZona, frecuencia);
hold off;
%% === Preguntar al usuario si guardará las figuras ===
guardarFiguras = questdlg('Desea guardar las figuras en formato PNG?','Guardar Figuras', 'Si','No','Si');
if strcmp(guardarFiguras, 'Sí')
    exportgraphics(gcf, 'Figura_Referencias.png', 'Resolution', 300);
    disp('Figura guardada como PNG.');
else
    disp('No se guardó la figura.');
end