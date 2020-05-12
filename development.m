clear; clc;

api = Indicadores();

todos = api.get_data();
% summary(todos)
ind = api.get_data('indicador', 'ipc');
% summary(ind)
range = api.get_data('indicador', 'ipc', 'fecha', '24-10-1991');