function [s12mag, s12pha, freq]=Get_RSVNA_S12() 
close all;

% Used to iterate the measurement 20 times per configuration
for i = 1:1:20 

visa_brand = 'tek'; 
visa_address = 'TCPIP::192.168.10.229::INSTR'; % VNA IP
buffer = 20 * 1024;   % 20 KB.

% Establish connection with the VNA using VISA protocol
% Creating a VISA object with specified buffer size, then open the connection
rsvna = visa(visa_brand, visa_address, 'InputBuffer', buffer, 'OutputBuffer', buffer);
fopen(rsvna);

% Querying the instrument identity and then using it to confirm successful communication
idn = query(rsvna, '*IDN?');
fprintf('Connected to %s\n', idn);

% ############################ Parameters #############################

% Frequency range of the measurement
fminGHz = 0.5; % GHz
fmaxGHz = 3.5; % GHz

npoints = 301; % Number of points of the measurement
num1 = 1;      % Antenna 1 value
num2 = 1;      % Antenna 2 value

phantomAngle = "nottilted";             % tilted|nottilted
patientStatus = "HEALTHY";              % ISCH|HEM|HEALTHY
placementNumber = 1;                    % 1=0°, 2=90°, 3=180°, 4=270°
height = 1;                             % 1 = Stroke is placed above antennas, 2 = Stroke is placed between antennas
int_ext = "int";                        % int = internal position of the stroke |o , ext = external position of the stroke o|

% ####################################################################


% The VNA is configured as follows:
% - Channel 1 measures the S12 parameter between antenna num1 and num2.
% - Channel 2 measures the S11 parameter of antenna num1.

if(num1~=num2)      % S12
    cha = 1;
elseif(num1==num2)  % S11
    cha = 2;
end

if any([num1, num2] < 1) || any([num1, num2] > 8)
    error('Error: num1 and num2 must be between 1 and 8 (inclusive).');
end

% Checks if the number of points of the measurement is less or equal to zero
if npoints <= 0
    error('Error: Number of points must be a positive integer.');
end



% ### Setting and data acquisition from VNA
% 1. Configuration of the channel and data format
% 2. Acquisition of magnitude and phase
% 3. Acquisition of the frequency vector
% 4. Restoration of continuous measurement mode
% 5. Closure  of the connection and cleanup of the variables

%fwrite(rsvna, '*RST');
fprintf(rsvna, 'INITIATE%d:CONTINUOUS OFF', cha);
fprintf(rsvna, 'SENSE%d:FREQUENCY START %fGHz', [cha fminGHz]);
fprintf(rsvna, 'SENSE%d:FREQUENCY STOP %fGHz', [cha fmaxGHz]);
fprintf(rsvna, 'SENSE%d:SWEEP:POINTS %d', [cha npoints]);
%fprintf(rsvna, 'INITIATE%d:IMMEDIATE:SCOPE SINGLE', chn);
%fprintf(rsvna, 'INITIATE%d:IMMEDIATE:DUMMY', chn);
fwrite(rsvna, 'FORMAT:DATA ASCII');

fprintf(rsvna, 'CALCULATE%d:FORMAT MLOGARITHMIC', cha);
s12mag = (str2num(query(rsvna, ['CALCULATE' num2str(cha) ':DATA? FDATA'])))';
ndata = size(s12mag,1);

s12pha = zeros(ndata, 'double');
freq = zeros(ndata, 'double');
fprintf(rsvna, 'CALCULATE%d:FORMAT PHASE', cha);
s12pha = (str2num(query(rsvna, ['CALCULATE' num2str(cha) ':DATA? FDATA'])))';


freq = (str2num(query(rsvna, ['CALCULATE' num2str(cha) ':DATA:STIMULUS?'])))';
freq = freq/1.e9;   % Conversion in [GHz].

fprintf(rsvna, 'INITIATE%d:CONTINUOUS ON', cha);
fprintf(rsvna, 'CALCULATE%d:FORMAT MLOGARITHMIC', cha);
pause(1); 

% Close the communication with the instrument
fclose(rsvna);   % Close VISA connection.
delete(rsvna);   % Delete instrument control object.
clear rsvna;     % Clear the local MATLAB variable from the workspace.

% #### PLOTTING MAGNITUDE AND PHASE ####
% % PLOT of the magnitude
% figure(1);
% plot(freq, s12mag, 'b');
% %axis([freq(1) freq(ndata) min(s11mag) max(s11mag)]);
% grid on;
% xlabel('Frequency [GHz]');
% ylabel('S12 Magnitude [dB]');

% % PLOT of the phase
% figure(2);
% plot(freq, s12pha, 'r');
% %axis([freq(1) freq(ndata) min(s11pha) max(s11pha)]);
% grid on;
% xlabel('Frequency [GHz]');
% ylabel('S12 Phase [deg]');


% Saving the measurements in the folders
if patientStatus == "HEALTHY"
    fileName = sprintf('measurements/%s/%s/S%d%d/S12_Ant%d-Ant%d_%s_%02d.mat', phantomAngle, patientStatus, num1, num2, num1, num2, patientStatus, i);

    % Extract path folder
    folderPath = sprintf('measurements/%s/%s/S%d%d',phantomAngle, patientStatus, num1, num2);

elseif patientStatus == "HEM" | patientStatus == "ISCH"
    fileName = sprintf('measurements/%s/%s/height%d_point%d_%s/S%d%d/S12_Ant%d-Ant%d_%s_point%d_%02d.mat', phantomAngle, patientStatus, height, placementNumber, int_ext, num1, num2, num1, num2, patientStatus, placementNumber, i);
    
    % Extract path folder
    folderPath = sprintf('measurements/%s/%s/height%d_point%d_%s/S%d%d',phantomAngle, patientStatus, height, placementNumber, int_ext, num1, num2);

else
    error("Error: Variable patientStatus can only be one of the following: HEALTHY, HEM, ISCH")
end

% Automatically creates the folder in case it doesn't exist
if ~exist(folderPath, 'dir')
    mkdir(folderPath);
end

save(fileName, 's12mag', 's12pha');

end

clear;