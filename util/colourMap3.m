function [cmap] = colourMap3

%% Colour Map
cp = [0.8 0.1 0.1];
c0 = [0.5 0.5 0.5];
cn = [0.1 0.1 0.8];

n = 100;

cmap = [cell2mat(arrayfun(@(a,b) linspace(a,b,n)', cn, c0, 'UniformOutput', false));
    cell2mat(arrayfun(@(a,b) linspace(a,b,n)', c0, cp, 'UniformOutput', false))];