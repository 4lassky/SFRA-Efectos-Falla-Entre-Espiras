%% ==================================================================================
% Script: SFRA - TRANSFORMADOR DE DISTRIBUCIÓN TRIFÁSICO
% Descripción: * Este script carga archivos .S2P de referencia y fallas
%              de un Analizador de redes Agilent Technologies E5061B
%              * Filtra las señales y genera gráficas SFRA con 4 zonas de
%                acuerdo con la IEE std C57.149-2012
%              * Crea una malla 3D de las curvas resultantes
%              * Identifica las 3 resonancias
%              * Grafica dispersión de magnitud, frecuencia y ángulo con tendencia
%              * Calcula correlación Pearson para cada resonancia
%              * Devuelve una tabla por resonancia
%              * Puede guardar las imagenes generadas
%              * Crea un archivo .gif de la image 3D
%
% Autores: Galindo Barbosa Israel Aldahir - Herrera Godoy Hazael
% Organización: ESIME ZACATENCO - IPN
%% ==================================================================================

%% === Selección de archivos ===
[archivoRef, carpetaRef] = uigetfile('*.s2p', 'Selecciona archivo de REFERENCIA');
if isequal(archivoRef,0)
    disp('No seleccionaste archivo de referencia.');
    return;
end
rutaRef = fullfile(carpetaRef, archivoRef);

[archivosFalla, carpetaFalla] = uigetfile('*.s2p', 'Selecciona archivos de FALLA', 'MultiSelect', 'on');
if isequal(archivosFalla, 0)
    disp('No se seleccionaron archivos de falla.');
    return;
end
if ischar(archivosFalla)
    archivosFalla = {archivosFalla};
end
numArchivosFalla = numel(archivosFalla);
disp(['Se seleccionaron ', num2str(numArchivosFalla), ' archivos de falla.']);

discosSeleccionados = [1,5,9,13,17,21,25];  % Define el disco de falla de acuerdo al archivo cargado

%% === Cargar referencia ===
SparamRef = sparameters(rutaRef);
frecuenciaRef = SparamRef.Frequencies;
s21Ref = rfparam(SparamRef, 2, 1);

%% === Configuración de colores y estilos ===
coloresBase = [ ...
    1.00 0.60 0.80;
    0.00 0.45 0.74;
    0.00 0.70 0.30;
    1.00 0.50 0.00;
    0.93 0.69 0.13;
    0.49 0.18 0.56;
    0.30 0.75 0.93;
    0.75 0.00 0.75;
    0.00 0.85 0.85;
    0.85 0.33 0.10];
estilosLinea = {'-', '--', ':', '-.'};
nombresLeyenda = cell(numArchivosFalla+1,1);

%% === Definir zonas de frecuencia ===
zonasFrecuencia = [min(frecuenciaRef) 2e3; 2e3 20e3; 20e3 1e6; 1e6 max(frecuenciaRef)]; %zonas de acuerdo con la normativa

%% === Función auxiliar: dibujar zonas y configurar ejes ===
function dibujarZonas(zonas, posY, freqDatos)
for i = 2:size(zonas,1)
    xline(zonas(i,1),'--r','', 'LineWidth',2,'HandleVisibility','off');
end
for i = 1:size(zonas,1)
    xPosTexto = sqrt(zonas(i,1)*zonas(i,2));
    text(xPosTexto,posY,sprintf('Zona %d',i),'HorizontalAlignment','center', 'VerticalAlignment','middle','FontWeight','bold','FontSize',12);
end
ejes = gca;
ejes.XScale = 'log';
ejes.XMinorGrid = 'on';
ejes.XAxis.TickLabelFormat = '%.0e';
ejes.TickDir = 'out';
ejes.LineWidth = 1.2;
xlim([min(freqDatos) max(freqDatos)]);
end

%% === FIGURA 1: Referencia filtrada ===
porcSuavizado = 0.01;
magnitudRefFiltrada = smooth(mag2db(abs(s21Ref)), porcSuavizado);
fig1=figure('Name','SFRA: Referencia'); hold on; grid on;
semilogx(frecuenciaRef, magnitudRefFiltrada,'k','LineWidth',2,'DisplayName','Referencia');
xlabel('Frecuencia [Hz]'); ylabel('Magnitud [dB]');
title('SFRA: Referencia');
legend('show','Location','southwest');
limY = ylim;
posYTextoZona = limY(1) + 0.9*(limY(2)-limY(1));
dibujarZonas(zonasFrecuencia, posYTextoZona, frecuenciaRef);
hold off;

%% === FIGURA 2: Referencia vs Fallas ===
fig2 = figure('Name','SFRA: Referencia vs fallas'); hold on; grid on;
semilogx(frecuenciaRef, magnitudRefFiltrada,'k','LineWidth',2);
xlabel('Frecuencia [Hz]'); ylabel('Magnitud [dB]');
title('SFRA: Referencia vs Fallas');
nombresLeyenda{1} = 'Referencia';

for idx = 1:numArchivosFalla
    rutaArchivoFalla = fullfile(carpetaFalla, archivosFalla{idx});
    SparamFalla = sparameters(rutaArchivoFalla);
    s21Falla = rfparam(SparamFalla,2,1);
    magnitudS21Filtrada = smooth(mag2db(abs(s21Falla)), porcSuavizado);
    colorLinea = coloresBase(mod(idx-1,size(coloresBase,1))+1,:);
    estiloLinea = estilosLinea{mod(idx-1,numel(estilosLinea))+1};
    semilogx(frecuenciaRef, magnitudS21Filtrada,'LineWidth',1.6,'Color',colorLinea,'LineStyle',estiloLinea);
    nombresLeyenda{idx+1} = sprintf('Falla %02d', idx);
end

legend(nombresLeyenda,'Interpreter','none','Location','southwest');
limY = ylim;
posYTextoZona = limY(1) + 0.9*(limY(2)-limY(1));
dibujarZonas(zonasFrecuencia, posYTextoZona, frecuenciaRef);
hold off;

%% === ANÁLISIS SFRA y detección de resonancias ===
resonancias = {'1ª','2ª','3ª'};

%NOTA: a continuacion se presentan secciones comentadas, una oertenece a la
%      de circuito corto y la otra a circuito abierto. Para realizar un
%      análisis primero asegurarse que la otra seccion esté comentada.


% Rangos de la referencia para circuito abierto
rangosRef = [ 0       2.5e6;2.5e6   5.5e6;5.5e6   8.4e6];

% Nuevos rangos para fallas para circuito abierto
rangosFalla = [0       610e3;610e3   900e3;900e3   2.4e6];


%{
% Rangos de la referencia para circuito corto
rangosRef = [ 0       620e3;620e3  1.3e6;1.3e6   3e6];

% Nuevos rangos para fallas de circuito corto
rangosFalla = [0       390e3;390e3   1.3e6;1.3e6  3.5e6];
%}


resAll = cell(1, numel(resonancias));
angRef_deg = rad2deg(unwrap(angle(s21Ref)));

for nRes = 1:3
    % === Crear tabla vacía ===
    resTbl = table('Size',[0 5],'VariableTypes',{'string','double','double','double','double'},'VariableNames',{'Archivo','Disco','Frecuencia_Hz','Magnitud_dB','Angulo_deg'});

    %% === REFERENCIA ===
    idxRangoRef = find(frecuenciaRef >= rangosRef(nRes,1) & frecuenciaRef <= rangosRef(nRes,2));
    subMagRef = magnitudRefFiltrada(idxRangoRef);
    switch nRes
        case {1,3}, [~, idxPicoLocalRef] = min(subMagRef);
        case 2, [~, idxPicoLocalRef] = max(subMagRef);
    end
    idxPicoRef = idxRangoRef(idxPicoLocalRef);
    resTbl = [resTbl; {'Referencia', 0, frecuenciaRef(idxPicoRef),magnitudRefFiltrada(idxPicoRef), angRef_deg(idxPicoRef)}];

    %% === FALLAS ===
    for k = 1:numArchivosFalla
        Spf = sparameters(fullfile(carpetaFalla, archivosFalla{k}));
        s21f = rfparam(Spf, 2, 1);
        mag_dB = smooth(mag2db(abs(s21f)), 0.01);
        ang_deg = rad2deg(unwrap(angle(s21f)));

        idxRangoF = find(frecuenciaRef >= rangosFalla(nRes,1) & frecuenciaRef <= rangosFalla(nRes,2));
        subMagF = mag_dB(idxRangoF);

        switch nRes
            case {1,3}, [~, idxPicoLocalF] = min(subMagF);
            case 2, [~, idxPicoLocalF] = max(subMagF);
        end
        idxPicoF = idxRangoF(idxPicoLocalF);

        [~, nameNoExt, ~] = fileparts(archivosFalla{k});
        resTbl = [resTbl; {nameNoExt, discosSeleccionados(k),frecuenciaRef(idxPicoF), mag_dB(idxPicoF), ang_deg(idxPicoF)}];
    end

    resAll{nRes} = resTbl;
end

%% === Subplots de tendencia por resonancia ===
tamanioMarker = 60;
for nRes = 1:3
    T = resAll{nRes};
    if isempty(T), continue; end
    resValidos = T(~isnan(T.Frecuencia_Hz) & ~isnan(T.Magnitud_dB) & ~isnan(T.Angulo_deg),:);
    figure('Name',[resonancias{nRes} ' Resonancia'],'NumberTitle','off');

    % --- Magnitud ---
    subplot(3,1,1); hold on; grid on;
    scatter(resValidos.Disco,resValidos.Magnitud_dB,tamanioMarker,'k','filled');
    resSinRef = resValidos(resValidos.Disco~=0,:);
    if height(resSinRef)>=2 && numel(unique(resSinRef.Disco))>1
        p = polyfit(resSinRef.Disco,resSinRef.Magnitud_dB,1);
        plot(resSinRef.Disco,polyval(p,resSinRef.Disco),'k--','LineWidth',2);
    end
    xlabel('Disco'); ylabel('Magnitud [dB]'); title('Magnitud vs Disco');

    % --- Frecuencia ---
    subplot(3,1,2); hold on; grid on;
    scatter(resValidos.Disco,resValidos.Frecuencia_Hz,tamanioMarker,'b','filled');
    if height(resSinRef)>=2 && numel(unique(resSinRef.Disco))>1
        p = polyfit(resSinRef.Disco,resSinRef.Frecuencia_Hz,1);
        plot(resSinRef.Disco,polyval(p,resSinRef.Disco),'b--','LineWidth',2);
    end
    xlabel('Disco'); ylabel('Frecuencia [Hz]'); title('Frecuencia vs Disco');

    % --- Ángulo ---
    subplot(3,1,3); hold on; grid on;
    scatter(resValidos.Disco,resValidos.Angulo_deg,tamanioMarker,'m','filled');
    if height(resSinRef)>=2 && numel(unique(resSinRef.Disco))>1
        p = polyfit(resSinRef.Disco,resSinRef.Angulo_deg,1);
        plot(resSinRef.Disco,polyval(p,resSinRef.Disco),'m--','LineWidth',2);
    end
    xlabel('Disco'); ylabel('Ángulo [°]'); title('Ángulo vs Disco');
end

%% === Superficie 3D SFRA incluyendo referencia ===
discos = [0 discosSeleccionados];
numDiscos = numel(discos);
Z = NaN(numDiscos,numel(frecuenciaRef));
Z(1,:) = magnitudRefFiltrada; % Disco 0 (referencia)

for k = 1:numArchivosFalla
    Spf = sparameters(fullfile(carpetaFalla, archivosFalla{k}));
    s21f = rfparam(Spf,2,1);
    fila = find(discos == discosSeleccionados(k));
    Z(fila,:) = smooth(mag2db(abs(s21f)),0.01);
end

[X,Y] = meshgrid(frecuenciaRef, discos);
fig3D = figure('Name','SFRA 3D - Referencia y Fallas'); hold on;
% Dibujar superficie
hSurf = surf(X,Y,Z,'EdgeColor','none','FaceAlpha',0.95);
set(gca,'XScale','log'); colormap('parula'); shading interp;
colorbar; grid on; view(45,25);
xlabel('Frecuencia [Hz]'); ylabel('Disco'); zlabel('Magnitud [dB]');
title('SFRA 3D - Referencia y Fallas');

% Colores y marcadores manuales para resonancias
coloresManual = {[1 0 0],[0 0 1],[0 1 0]};
marcadoresManual = {'o','o','o'};

% Graficar puntos de resonancias
hRes = gobjects(1,3);
for nRes = 1:3
    T = resAll{nRes};

    % Graficar puntos individuales
    for r = 1:height(T)
        plot3(T.Frecuencia_Hz(r),T.Disco(r),T.Magnitud_dB(r),marcadoresManual{nRes},'MarkerSize',8,'MarkerFaceColor',coloresManual{nRes},'MarkerEdgeColor','k','LineWidth',1.0);
    end

    %Linea de tendencia
    plot3(T.Frecuencia_Hz,T.Disco,T.Magnitud_dB,'-','Color',coloresManual{nRes},'LineWidth',2);

    % Crear puntos "fantasma" solo para la leyenda
    hRes(nRes) = plot3(NaN,NaN,NaN,marcadoresManual{nRes},'MarkerFaceColor',coloresManual{nRes},'MarkerEdgeColor','k','Color',coloresManual{nRes},'LineWidth',1.5);
end
% Crear la leyenda manual
legend([hSurf,hRes],[{'Superficie SFRA'},resonancias],'Location','bestoutside');

%% === Correlación Pearson excluyendo referencia ===
corrTbl = table('Size',[3 4],'VariableTypes',{'string','double','double','double'},'VariableNames',{'Resonancia','Corr_Mag','Corr_Freq','Corr_Angulo'});
for nRes = 1:3
    T = resAll{nRes};
    resFallas = T(T.Disco~=0,:);
    discosF = resFallas.Disco; mag = resFallas.Magnitud_dB; freq = resFallas.Frecuencia_Hz; ang = resFallas.Angulo_deg;
    corrTbl.Resonancia(nRes) = resonancias{nRes};
    if numel(discosF)>=2
        corrTbl.Corr_Mag(nRes) = corr(discosF, mag,'Rows','complete');
        corrTbl.Corr_Freq(nRes)= corr(discosF, freq,'Rows','complete');
        corrTbl.Corr_Angulo(nRes)= corr(discosF, ang,'Rows','complete');
    else
        corrTbl.Corr_Mag(nRes) = NaN;
        corrTbl.Corr_Freq(nRes)= NaN;
        corrTbl.Corr_Angulo(nRes)= NaN;
    end
end
disp('=== Correlación Pearson entre Disco y Resonancias (solo fallas) ===');
disp(corrTbl);

%% === Tablas finales por resonancia ===
for nRes = 1:3
    T = resAll{nRes};
    tablaRes = table(T.Archivo, T.Disco, T.Magnitud_dB, T.Frecuencia_Hz, T.Angulo_deg,'VariableNames',{'Archivo','Disco','Magnitud_dB','Frecuencia_Hz','Angulo_deg'});
    fprintf('=== Tabla de la %s Resonancia ===\n', resonancias{nRes});
    disp(tablaRes);
end
%{
%% === GUARDAR FIGURAS Y ANIMACIÓN SFRA ===
respuestaGuardar = questdlg('¿Deseas guardar las figuras en PNG?','Guardar Figuras', 'Sí', 'No', 'Sí');

if strcmp(respuestaGuardar, 'Sí')

    % Crear carpeta donde se guardarán las imágenes
    rutaGuardarFiguras = fullfile(carpetaFalla, 'Graficas_SFRA');
    if ~exist(rutaGuardarFiguras, 'dir')
        mkdir(rutaGuardarFiguras);
    end

    % Guardar la figura 1: Referencia
    figRef = findall(0, 'Type', 'figure', 'Name', 'SFRA: Referencia');
    if ~isempty(figRef)
        saveas(figRef(1), fullfile(rutaGuardarFiguras, 'Figura_Referencia.png'));
    end

    % Guardar la figura 2: Referencia vs Fallas
    figRefFallas = fig2;
    if ~isempty(figRefFallas)
        saveas(figRefFallas(1), fullfile(rutaGuardarFiguras, 'Figura_Ref_vs_Fallas.png'));
    end

    % Guardar las figuras de subplots de resonancias
    for nRes = 1:3
        figName = sprintf('Resonancia_%d.png', nRes);
        figHandle = findall(0, 'Type', 'figure', 'Name',sprintf('%s Resonancia', resonancias{nRes}));
        if ~isempty(figHandle)
            saveas(figHandle(1), fullfile(rutaGuardarFiguras, figName));
        end
    end
    disp(['Todas las figuras se guardaron en: ', rutaGuardarFiguras]);
else
    disp('Guardado de figuras cancelado por el usuario.');
end

%% === GUARDAR ANIMACIÓN 3D SFRA ===
hFig3D = findall(0, 'Type', 'figure', 'Name', 'SFRA 3D - Referencia y Fallas');
if isempty(hFig3D)
    warning('No se encontró la figura 3D.');
else
    hFig3D = hFig3D(1);
    hAx = hFig3D.CurrentAxes;
    drawnow;

    % === Parámetros de animación ===
    numFrames = 500;        % Número de fotogramas (más = animación más fluida)
    delayTime = 0.05;       % Tiempo entre fotogramas (segundos)
    az = linspace(0, 360, numFrames);  % Ángulos de rotación horizontal
    elFijo = 45;            % Elevación fija (ángulo vertical)
    nombreGIF = fullfile(carpetaFalla, 'SFRA_3D_Rotacion.gif');

    % === Generación del GIF ===
    axis tight
    for k = 1:numFrames
        view(hAx, az(k), elFijo);
        drawnow;

        frame = getframe(hFig3D);
        im = frame2im(frame);
        [A, map] = rgb2ind(im, 256);

        if k == 1
            imwrite(A, map, nombreGIF, 'gif', 'LoopCount', Inf, 'DelayTime', delayTime);
        else
            imwrite(A, map, nombreGIF, 'gif', 'WriteMode', 'append', 'DelayTime', delayTime);
        end
    end
    disp(['GIF de rotación horizontal guardado en: ', nombreGIF]);
end
%}


%% === Subplots de tendencia para la 1ª resonancia (sin graficar referencia) ===
nRes = 1;  % Solo resonancia 1

T = resAll{nRes};
if ~isempty(T)

    % Excluir referencia
    resFallas = T(T.Disco ~= 0, :);  

    figure('Name','1ª Resonancia - Solo Fallas','NumberTitle','off');
    tamanioMarker = 60;

    % --- Magnitud ---
    subplot(3,1,1); hold on; grid on;
    scatter(resFallas.Disco, resFallas.Magnitud_dB, tamanioMarker, 'k', 'filled');

    if height(resFallas) >= 2 && numel(unique(resFallas.Disco)) > 1
        p_mag = polyfit(resFallas.Disco, resFallas.Magnitud_dB, 1);
        plot(resFallas.Disco, polyval(p_mag, resFallas.Disco), 'k--', 'LineWidth', 2);
    end
    xlabel('Disco'); ylabel('Magnitud [dB]');
    title('Magnitud vs Disco (sin referencia)');

    % --- Frecuencia ---
    subplot(3,1,2); hold on; grid on;
    scatter(resFallas.Disco, resFallas.Frecuencia_Hz, tamanioMarker, 'b', 'filled');

    if height(resFallas) >= 2 && numel(unique(resFallas.Disco)) > 1
        p_freq = polyfit(resFallas.Disco, resFallas.Frecuencia_Hz, 1);
        plot(resFallas.Disco, polyval(p_freq, resFallas.Disco), 'b--', 'LineWidth', 2);
    end
    xlabel('Disco'); ylabel('Frecuencia [Hz]');
    title('Frecuencia vs Disco (sin referencia)');

    % --- Ángulo ---
    subplot(3,1,3); hold on; grid on;
    scatter(resFallas.Disco, resFallas.Angulo_deg, tamanioMarker, 'm', 'filled');

    if height(resFallas) >= 2 && numel(unique(resFallas.Disco)) > 1
        p_ang = polyfit(resFallas.Disco, resFallas.Angulo_deg, 1);
        plot(resFallas.Disco, polyval(p_ang, resFallas.Disco), 'm--', 'LineWidth', 2);
    end
    xlabel('Disco'); ylabel('Ángulo [°]');
    title('Ángulo vs Disco (sin referencia)');

end
