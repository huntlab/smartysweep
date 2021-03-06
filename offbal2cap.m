function [C, Closs] = offbal2cap(fnum, config, varargin)
% converts off-balance voltages to capacitance
%   fnum            <file number; looks for ###*.dat in usual format>
%   Xcol            <column of offbal voltage X-component in file>
%   Ycol            <column of offbal voltage Y-component in file>
%   balance_matrix  <output of balance_capacitance_bridge(...)>
%   Vex             (optional)<excitation voltage; req for real capacitance>
%   Cstd            (optional)<standard capacitance; req for real capacitance>

% parameters that may change
fname_format         = sprintf('%03d*.dat', fnum);
default_data_directory  = [];
default_Vex          = []; % throw error if empty
default_Cstd         = 1; % if standard capacitance is unknown
default_header_lines = 1;
default_Xdata        = [];
default_Ydata        = [];
default_vppfactor    = 1; % 1.005*sqrt(2) for case where Vex is peak-to-peak voltage; 1 for RMS voltages

% validate required config fields
required_fields = {'balance_matrix', 'Xcol', 'Ycol'};
for field = required_fields
    if ~isfield(config, field)
        error('offbal2cap requires <%s> in supplied config', char(field));
    end
end
balance_matrix = config.balance_matrix;
Xcol = config.Xcol;
Ycol = config.Ycol;

% deal with optional arguments
parser = inputParser;
parser.KeepUnmatched = true; % other args ignored
validScalarNonNeg = @(x) validateattributes(x, {'numeric'}, {'scalar', 'nonnegative'});
validScalarPos = @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'});
validScalarInt = @(x) validateattributes(x, {'numeric'}, {'scalar', 'nonnegative', 'integer'});

% reset defaults based on config entries
if isfield(config, 'Vex'); default_Vex = config.Vex; end
if isfield(config, 'Cstd'); default_Cstd = config.Cstd; end
if isfield(config, 'data_directory'); default_data_directory = config.data_directory; end % reset default based on config entry

% parsed arguments override config fields
addParameter(parser, 'Vex', default_Vex, validScalarNonNeg); % can override
addParameter(parser, 'Cstd', default_Cstd, validScalarPos); % can override
addParameter(parser, 'header_lines', default_header_lines, validScalarInt);
addParameter(parser, 'Xdata', default_Xdata, @(x) isvector(x));
addParameter(parser, 'Ydata', default_Ydata, @(x) isvector(x));
addParameter(parser, 'vppfactor', default_vppfactor, validScalarNonNeg);
addParameter(parser, 'data_directory', default_data_directory); % parsed arguments override config fields

parse(parser, varargin{:});
Cstd = parser.Results.Cstd;
header_lines = parser.Results.header_lines;
Xdata = parser.Results.Xdata;
Ydata = parser.Results.Ydata;
vppfactor = parser.Results.vppfactor;
data_directory = parser.Results.data_directory;

% validate excitation voltage
Vex = parser.Results.Vex;
if isempty(Vex)
    error('offbal2cap requires Vex in supplied config or as optional argument');
end

% load file
if data_directory; fname_format = fullfile(data_directory, fname_format); end % build filepath with wildcards
f = dir(fname_format);
fname = f.name;
if data_directory; fname = fullfile(data_directory, fname); end % build actual filepath
dstr = importdata(fname, '\t', header_lines);
data = dstr.data;

% use provided Xdata or Xdata from file
if isempty(Xdata)
    Xdata = data(:, Xcol);
end
if isempty(Ydata)
    Ydata = data(:, Ycol);
end

% unpack balance matrix
balance_matrix = num2cell(balance_matrix);
[Kc1, Kc2, Kr1, Kr2, Vc0, Vr0] = balance_matrix{:};

% compute all the necessaries
L1prime = vppfactor * Xdata;
L2prime = vppfactor * Ydata;
Vr0prime = Vr0 + (Kc2 * L1prime - Kc1 * L2prime) / (Kc1 * Kr2 - Kr1 * Kc2);
Vc0prime = Vc0 + (Kr1 * L2prime - Kr2 * L1prime) / (Kc1 * Kr2 - Kr1 * Kc2);

% calculate capacitance
C = Cstd * Vc0prime / Vex; % edit on 4/8/2019 to allow negative values
Closs = Cstd * Vr0prime / Vex;
return