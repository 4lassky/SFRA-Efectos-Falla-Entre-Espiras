%% ==================================================================================
% Script: SFRA - DEVANADO EXPERIMENTAL
% Descripción: * Este script carga archivos .S2P de referencia y fallas
%              de un Analizador de redes Agilent Technologies E5061B
%              * Filtra las señales y genera gráficas SFRA con 4 zonas de
%                acuerdo con la IEE std C57.149-2012
%              * Crea una malla 3D de las curvas resultantes
%              * Identifica las 5 resonancias
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

discosSeleccionados = 3:6:93;  % Define el disco de falla de acuerdo al archivo cargado

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
title('SFRA: Referencia vs fallas');
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

%% === Detección de resonancias ===
discos = [0,3:6:93];
numDiscos = numel(discos);
magRef_dB = magnitudRefFiltrada;
angRef_deg = rad2deg(unwrap(angle(s21Ref))); %fase de la referencia convertida a grados y con unwrap para eliminar discontinuidades
prominenceMin = 2;
resonancias = {'1ra','2da','3ra','4ta','5ta'};
rango5_resonancia = [87e3 100e3]; %Rango especial para la resonancia problemática
resAll = cell(1,numel(resonancias)); %Contiene tablas con resultados para cada una de las 5 resonancias.

% Detección de resonancias para referencia y fallas
for nRes = 1:5
    resTbl = table('Size',[0 5], 'VariableTypes',{'string','double','double','double','double'},'VariableNames', {'Archivo','Disco',['Freq' num2str(nRes) '_Hz'], ['Mag' num2str(nRes) '_dB'], 'Angulo_deg'});
    for k = 0:numArchivosFalla
        %% === REFERENCIA ===
        if k==0 
            mag_dB = magRef_dB;
            freqData = frecuenciaRef;
            nameNoExt = 'Referencia';
            discoVal = 0;
            [~, locsMinAll] = findpeaks(-mag_dB);
            [~, locsMaxAll] = findpeaks(mag_dB);
            idxR = NaN(1,5);
            if ~isempty(locsMinAll), idxR(1) = locsMinAll(1); end
            if ~isnan(idxR(1))
                idxAfterR1 = find(freqData>freqData(idxR(1)));
                if ~isempty(idxAfterR1)
                    [~,locMax] = max(mag_dB(idxAfterR1));
                    idxR(2) = idxAfterR1(locMax);
                end
            end
            idxR3 = find(freqData>=20e3 & freqData<=50e3);
            if ~isempty(idxR3), [~,locMin] = min(mag_dB(idxR3)); idxR(3)=idxR3(locMin); end
            idxR4 = find(freqData>=50e3 & freqData<=60e3);
            if ~isempty(idxR4), [~,locMax] = max(mag_dB(idxR4)); idxR(4)=idxR4(locMax); end
            idxR5 = find(freqData>=70e3 & freqData<=115e3);
            if ~isempty(idxR5), [~,locMin] = min(mag_dB(idxR5)); idxR(5)=idxR5(locMin); end
            idx_pico = idxR(nRes);
        else
            %% === FALLAS ===
            fname = archivosFalla{k};
            [~,nameNoExt,~] = fileparts(fname);
            discoVal = discosSeleccionados(k);
            Spf = sparameters(fullfile(carpetaFalla,fname));
            s21f = rfparam(Spf,2,1);
            mag_dB = smooth(mag2db(abs(s21f)),0.01);
            freqData = frecuenciaRef;
            idx_pico = NaN;
            switch nRes
                case 1 %Resonancia 1
                    [~, locsMin] = findpeaks(-mag_dB,'MinPeakProminence',prominenceMin);
                    if ~isempty(locsMin), idx_pico = locsMin(1); end
                case 2 %Resonancia 2
                    if ~isempty(resAll{1}) && ~isnan(resAll{1}.Freq1_Hz(k+1))
                        fR1 = resAll{1}.Freq1_Hz(k+1);
                        idx_rango = find(freqData>fR1 & freqData<=38e3);
                        [pks, locsP] = findpeaks(mag_dB(idx_rango),'MinPeakProminence',prominenceMin);
                        if ~isempty(pks), [~,idxMax] = max(pks); idx_pico = idx_rango(locsP(idxMax)); end
                    end
                case 3 %Resonancia 3
                    [~, locsMin] = findpeaks(-mag_dB,'MinPeakProminence',prominenceMin);
                    if numel(locsMin)>=2, idx_pico=locsMin(2); elseif ~isempty(locsMin), idx_pico=locsMin(end); end
                case 4 %Resonancia 4
                    if ~isempty(resAll{3}) && ~isnan(resAll{3}.Freq3_Hz(k+1))
                        fR3 = resAll{3}.Freq3_Hz(k+1);
                        idx_rango = find(freqData>fR3 & freqData<=85e3);
                        [pks, locsP] = findpeaks(mag_dB(idx_rango),'MinPeakProminence',prominenceMin);
                        if ~isempty(pks), [~, idxMax] = max(pks); idx_pico = idx_rango(locsP(idxMax));
                        else
                            [~, idxMaxAbs] = max(mag_dB(idx_rango));
                            idx_pico = idx_rango(idxMaxAbs);
                        end
                    end
                case 5 %Resonancia 5
                    idx_rango = find(freqData >= rango5_resonancia(1) & freqData <= rango5_resonancia(2));
                    if ~isempty(idx_rango)
                        [~, minLoc] = min(mag_dB(idx_rango));  % Busca el mínimo absoluto
                        idx_pico = idx_rango(minLoc);          % Mapea al índice original
                    else
                        idx_pico = NaN;
                    end

            end
        end
        % Guardar resultados
        if ~isnan(idx_pico)
            f = freqData(idx_pico);
            m = mag_dB(idx_pico);
            if k == 0
                ang = rad2deg(angle(s21Ref(idx_pico)));  % referencia
            else
                ang = rad2deg(angle(s21f(idx_pico)));    % fallas
            end

        else
            f = NaN; m = NaN; ang = NaN;
        end
        resTbl = [resTbl; {nameNoExt, discoVal, f, m, ang}]; %tablas de resultados
    end
    resAll{nRes} = resTbl; %tablas de resultados
end

%% === Subplots de tendencia por resonancia ===
tamanioMarker = 60;
for nRes = 1:5
    T = resAll{nRes};
    if isempty(T), continue; end
    resValidos = T(~isnan(T.(['Freq' num2str(nRes) '_Hz'])) & ~isnan(T.(['Mag' num2str(nRes) '_dB'])) & ~isnan(T.Angulo_deg), :);
    figure('Name',[resonancias{nRes} ' Resonancia'],'NumberTitle','off');

    % --- Magnitud ---
    subplot(3,1,1); hold on; grid on;
    scatter(resValidos.Disco,resValidos.(['Mag' num2str(nRes) '_dB']),tamanioMarker,'k','filled');
    resSinRef = resValidos(resValidos.Disco~=0,:);
    if height(resSinRef)>=2 && numel(unique(resSinRef.Disco))>1
        p = polyfit(resSinRef.Disco,resSinRef.(['Mag' num2str(nRes) '_dB']),1);
        plot(resSinRef.Disco,polyval(p,resSinRef.Disco),'k--','LineWidth',2);
    end
    xlabel('Disco'); ylabel('Magnitud [dB]');

    % --- Frecuencia ---
    subplot(3,1,2); hold on; grid on;
    scatter(resValidos.Disco,resValidos.(['Freq' num2str(nRes) '_Hz']),tamanioMarker,'b','filled');
    if height(resSinRef)>=2 && numel(unique(resSinRef.Disco))>1
        p = polyfit(resSinRef.Disco,resSinRef.(['Freq' num2str(nRes) '_Hz']),1);
        plot(resSinRef.Disco,polyval(p,resSinRef.Disco),'b--','LineWidth',2);
    end
    xlabel('Disco'); ylabel('Frecuencia [Hz]');

    % --- Ángulo ---
    subplot(3,1,3); hold on; grid on;
    scatter(resValidos.Disco,resValidos.Angulo_deg,tamanioMarker,'m','filled');
    if height(resSinRef)>=2 && numel(unique(resSinRef.Disco))>1
        p = polyfit(resSinRef.Disco,resSinRef.Angulo_deg,1);
        plot(resSinRef.Disco,polyval(p,resSinRef.Disco),'m--','LineWidth',2);
    end
    xlabel('Disco'); ylabel('Angulo [°]');
end

%% === Superficie 3D SFRA incluyendo referencia ===
Z = NaN(numDiscos, numel(frecuenciaRef));
Z(1,:) = magRef_dB;  % Disco 0 (referencia)

for k = 1:numArchivosFalla
    fname = archivosFalla{k};
    Spf = sparameters(fullfile(carpetaFalla,fname));
    s21f = rfparam(Spf,2,1);
    discoVal = discosSeleccionados(k);
    fila = find(discos == discoVal, 1);
    if ~isempty(fila)
        Z(fila,:) = smooth(mag2db(abs(s21f)),0.01);
    end
end

[X,Y] = meshgrid(frecuenciaRef, discos);
fig3D = figure('Name','SFRA 3D - Referencia y Fallas'); hold on;
% Dibujar superficie
hSurf = surf(X,Y,Z,'EdgeColor','none','FaceAlpha',0.95);
set(gca,'XScale','log');
colormap('parula'); shading interp; colorbar;
view(45,25); grid on;
xlabel('Frecuencia [Hz]'); ylabel('Disco'); zlabel('Magnitud [dB]');
title('SFRA 3D - Referencia y Fallas');

% Colores y marcadores manuales para resonancias
coloresManual = {[1 0 0], [1 0 1], [0 1 1], [1 0.85 0.1], [0.2 1 0.2]};
marcadoresManual = {'o','o','o','o','o'};
tamanioMarker = 8;

% Graficar puntos de resonancias
hRes = gobjects(1,5);
for nRes = 1:5
    T = resAll{nRes};
    if isempty(T), continue; end
    resValidos = T(~isnan(T.(['Freq' num2str(nRes) '_Hz'])) & ~isnan(T.(['Mag' num2str(nRes) '_dB'])) & ~isnan(T.Angulo_deg), :);

    % Graficar puntos individuales
    for r = 1:height(resValidos)
        plot3(resValidos.(['Freq' num2str(nRes) '_Hz'])(r),resValidos.Disco(r),resValidos.(['Mag' num2str(nRes) '_dB'])(r),marcadoresManual{nRes},'MarkerSize',tamanioMarker,'MarkerFaceColor', coloresManual{nRes},'MarkerEdgeColor','k','LineWidth',1.0);
    end

    %Linea de tendencia
    if height(resValidos) >= 2
        plot3(resValidos.(['Freq' num2str(nRes) '_Hz']),resValidos.Disco,resValidos.(['Mag' num2str(nRes) '_dB']),'-', 'Color', coloresManual{nRes}, 'LineWidth',2);
    end

    % Crear puntos "fantasma" solo para la leyenda
    hRes(nRes) = plot3(NaN, NaN, NaN, marcadoresManual{nRes},'MarkerFaceColor', coloresManual{nRes},'MarkerEdgeColor','k','Color', coloresManual{nRes},'LineWidth',1.5);
end
% Crear la leyenda manual
legend([hSurf, hRes], [{'Superficie SFRA'}, {'1ra','2da','3ra','4ta','5ta'}],'Location','bestoutside');

%% === Correlación Pearson excluyendo referencia ===
corrTbl = table('Size',[5 4],'VariableTypes',{'string','double','double','double'},'VariableNames',{'Resonancia','Corr_Mag','Corr_Freq','Corr_Angulo'});

for nRes = 1:5
    T = resAll{nRes};
    resFallas = T(T.Disco~=0 & ~isnan(T.(['Mag' num2str(nRes) '_dB'])) & ~isnan(T.(['Freq' num2str(nRes) '_Hz'])) & ~isnan(T.Angulo_deg), :);
    discosF = resFallas.Disco;
    mag = resFallas.(['Mag' num2str(nRes) '_dB']);
    freq = resFallas.(['Freq' num2str(nRes) '_Hz']);
    ang  = resFallas.Angulo_deg;

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
for nRes=1:5
    T = resAll{nRes};
    tablaRes = table(T.Archivo, T.Disco, T.(['Mag' num2str(nRes) '_dB']),T.(['Freq' num2str(nRes) '_Hz']), T.Angulo_deg,'VariableNames', {'Archivo','Disco','Magnitud_dB','Frecuencia_Hz','Angulo_deg'});
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
    figHandles1 = findall(0,'Type','figure','Name','SFRA: Referencia');
    if ~isempty(figHandles1)
        saveas(figHandles1(1), fullfile(rutaGuardarFiguras, 'Figura_Referencia.png'));
    end

    % Guardar la figura 2: Referencia vs Fallas
    figHandles2 = findall(0,'Type','figure','Name','SFRA: Referencia vs fallas');
    if ~isempty(figHandles2)
        saveas(figHandles2(1), fullfile(rutaGuardarFiguras, 'Figura_Ref_vs_Fallas.png'));
    end

    % Guardar las figuras de subplots de resonancias
    for nRes = 1:5
        figName = sprintf('Resonancia_%d.png', nRes);
        figHandles = findall(0,'Type','figure','Name',[resonancias{nRes} ' Resonancia']);
        if ~isempty(figHandles)
            saveas(figHandles(1), fullfile(rutaGuardarFiguras, figName));
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

    % Parámetros de animación
    numFrames = 500;      % Número de fotogramas (más = animación más fluida)
    delayTime = 0.05;     % Tiempo entre fotogramas (segundos)
    az = linspace(0, 360, numFrames);  % Ángulos de rotación horizontal
    elFijo = 50;          % Elevación fija (ángulo vertical)
    nombreGIF = fullfile(carpetaFalla, 'SFRA_3D_Rotating.gif');

    % Generación del GIF
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

%% ==================================================================================
%  ANÁLISIS SEPARADO EN TRES INTERVALOS (PROMEDIOS POR FALLA Y CORRELACIÓN)
%  Se calcula: promedio de magnitud, frecuencia y ángulo por falla
%  y sus coeficientes de correlación con el número de disco
%% ==================================================================================

% === Definición de intervalos de frecuencia IEC ===
intervalos = [10        2e3;     
              2e3      20e3;
              20e3     1e6];

% === Definición de intervalos de frecuencia IEE ===
%intervalos = [20        10e3;     
%              5e3      100e3;
%              50e3     1e6];

nombresIntervalos = {'Inicio a 2kHz', '2kHz a 20kHz', '20kHz a 1MHz'};
%nombresIntervalos = {'20 Hz a 10kHz', '5kHz a 100kHz', '50kHz a 1MHz'};

% === Inicializar tabla de correlaciones ===
corrTbl_intervalos = table('Size',[3 4], ...
    'VariableTypes',{'string','double','double','double'}, ...
    'VariableNames',{'Intervalo','Corr_Mag','Corr_Freq','Corr_Angulo'});

% === Bucle principal para cada intervalo ===
for iInt = 1:3
    fMin = intervalos(iInt,1);
    fMax = intervalos(iInt,2);

    %% === Filtro de frecuencias ===
    idxFreq = frecuenciaRef >= fMin & frecuenciaRef <= fMax;
    freqIntervalo = frecuenciaRef(idxFreq);
    magRef_Int = magnitudRefFiltrada(idxFreq);

    %% === Figura de referencia vs fallas ===
    figInt = figure('Name',['SFRA - Intervalo ' nombresIntervalos{iInt}]);
    hold on; grid on;
    semilogx(freqIntervalo, magRef_Int, 'k', 'LineWidth', 2, 'DisplayName', 'Referencia');

    % Inicializar listas de resultados
    discosValidos = [];
    magProm = [];
    freqProm = [];
    angProm = [];

    % --- Procesar cada archivo de falla ---
    for k = 1:numArchivosFalla
        rutaArchivoFalla = fullfile(carpetaFalla, archivosFalla{k});
        SparamFalla = sparameters(rutaArchivoFalla);
        s21Falla = rfparam(SparamFalla, 2, 1);

        % Obtener datos dentro del intervalo
        mag_dB = mag2db(abs(s21Falla(idxFreq)));
        ang_deg = rad2deg(unwrap(angle(s21Falla(idxFreq))));
        freq_sub = freqIntervalo;

        % Calcular promedios
        magProm(k) = mean(mag_dB, 'omitnan');
        freqProm(k) = mean(freq_sub, 'omitnan');
        angProm(k) = mean(ang_deg, 'omitnan');
        discosValidos(k) = discosSeleccionados(k);

        % Graficar curva individual
        semilogx(freq_sub, smooth(mag_dB,0.01), 'LineWidth', 1.5, ...
            'DisplayName', sprintf('Falla %02d', k));
    end

    xlabel('Frecuencia [Hz]');
    ylabel('Magnitud [dB]');
    title(['SFRA: Intervalo ' nombresIntervalos{iInt}]);
    legend('show', 'Location', 'southwest');
    xlim([fMin fMax]);
    hold off;

    %% === Cálculo de correlaciones ===
    discosValidos = discosValidos(:);
    magProm = magProm(:);
    freqProm = freqProm(:);
    angProm = angProm(:);

    if numel(discosValidos) > 2
        Rmag = corr(discosValidos, magProm, 'Rows', 'complete');
        Rfreq = corr(discosValidos, freqProm, 'Rows', 'complete');
        Rang = corr(discosValidos, angProm, 'Rows', 'complete');
    else
        Rmag = NaN; Rfreq = NaN; Rang = NaN;
    end

    % Guardar resultados en la tabla
    corrTbl_intervalos.Intervalo(iInt) = nombresIntervalos{iInt};
    corrTbl_intervalos.Corr_Mag(iInt) = Rmag;
    corrTbl_intervalos.Corr_Freq(iInt) = Rfreq;
    corrTbl_intervalos.Corr_Angulo(iInt) = Rang;

    % Mostrar en consola
    disp(['=== Correlaciones - Intervalo ' nombresIntervalos{iInt} ' ===']);
    fprintf('Magnitud promedio vs disco: %.4f\n', Rmag);
    fprintf('Frecuencia promedio vs disco: %.4f\n', Rfreq);
    fprintf('Ángulo promedio vs disco: %.4f\n\n', Rang);

    %% === Subgráficas de tendencia ===
    figure('Name',['Tendencias - ' nombresIntervalos{iInt}],'NumberTitle','off');

    % Subplot 1: Magnitud promedio
    subplot(3,1,1); hold on; grid on;
    scatter(discosValidos, magProm, 60, 'k', 'filled');
    if numel(discosValidos) > 2
        p = polyfit(discosValidos, magProm, 1);
        plot(discosValidos, polyval(p, discosValidos), 'r--', 'LineWidth', 2);
    end
    xlabel('Disco'); ylabel('Magnitud promedio [dB]');
    title(sprintf('Magnitud promedio - r = %.3f', Rmag));

    % Subplot 2: Frecuencia promedio
    subplot(3,1,2); hold on; grid on;
    scatter(discosValidos, freqProm, 60, 'b', 'filled');
    if numel(discosValidos) > 2
        p = polyfit(discosValidos, freqProm, 1);
        plot(discosValidos, polyval(p, discosValidos), 'r--', 'LineWidth', 2);
    end
    xlabel('Disco'); ylabel('Frecuencia promedio [Hz]');
    title(sprintf('Frecuencia promedio - r = %.3f', Rfreq));

    % Subplot 3: Ángulo promedio
    subplot(3,1,3); hold on; grid on;
    scatter(discosValidos, angProm, 60, 'm', 'filled');
    if numel(discosValidos) > 2
        p = polyfit(discosValidos, angProm, 1);
        plot(discosValidos, polyval(p, discosValidos), 'r--', 'LineWidth', 2);
    end
    xlabel('Disco'); ylabel('Ángulo promedio [°]');
    title(sprintf('Ángulo promedio - r = %.3f', Rang));

    %% === NUEVO BLOQUE: Mostrar vectores promedio ===
    fprintf('\n=== Vectores promedio - %s ===\n', nombresIntervalos{iInt});
    fprintf('n = %d\n', numel(discosValidos));
    fprintf('x = [%s]\n', num2str(discosValidos', '%g '));
    fprintf('y_MAG = [%s]\n', num2str(magProm', '%.3f '));
    fprintf('y_FREQ = [%s]\n', num2str(freqProm', '%.3f '));
    fprintf('y_ANG = [%s]\n\n', num2str(angProm', '%.3f '));
end

%% === Tabla resumen final ===
disp('=== Tabla de coeficientes de correlación por intervalo ===');
disp(corrTbl_intervalos);
