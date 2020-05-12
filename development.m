clear; clc;

api = Indicadores();

api.metadata()
todos = api.get_data();
% summary(todos)
ind = api.get_data('indicador', 'ipc');
% summary(ind)
range = api.get_data('indicador', 'ipc', 'fecha', '1991');