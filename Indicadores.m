classdef Indicadores
    
    properties
        timeout = 60 % tiempo maximo para esperar por la respuesta
    end
    properties(Constant)
        HOST = 'https://mindicador.cl/api' % Production server
    end
    
    properties(Dependent)
        options % encabezados o headers del cliente
    end
    
    methods
        
        function self = Indicadores(timeout)
            if nargin == 1
                self.timeout = timeout;
                               
            elseif nargin > 2
                disp('La clase se inicializa sin ningun parametro')
            end
        end
        
        function options_ = get.options(self)
            % headers and settings of the client
            options_ = weboptions('Timeout', self.timeout, ...
                'HeaderFields', {'Accept' 'application/json';...
                                 'Accept-Encoding' 'deflate, gzip'},...
                'ContentType', 'json',...
                'MediaType', 'application/json', ...
                'RequestMethod', 'get', ...
                'ArrayFormat', 'json');
        end
        
        % ----------------------------------------
        % Indicadores económicos diarios
        % ----------------------------------------
        
        function meta_ = metadata(~)
            url = 'https://mindicador.cl/';
            code = webread(url);
            tree = htmlTree(code);
            selector = 'tr';
            meta_ = extractHTMLText(findElement(tree, selector));
        end
        
        function indicador = get_data(self, params)
            arguments
                self
                params.indicador(1,1) string {mustBeNonempty} = ''
                params.fecha(1,1) string {mustBeNonempty} = ''
                params.table_format(1,1) logical {mustBeNumericOrLogical} = true                
            end
            
            % solamente solicitar los valores mas recientes del indicador
            if strcmp(params.fecha, '')
                % todos o un indicador en especifico?
                if strcmp(params.indicador, '')
                    endpoint = '';
                else
                    endpoint = sprintf('/%s', params.indicador);
                end
            % indicador especifico con un rango de fecha determinado
            else
                endpoint = sprintf('/%s/%s', params.indicador, params.fecha);
            end
            
            % uniendo el host con el endpoint solicitado
            url = [self.HOST endpoint];
            
            % devolver la solicitud como una tabla o un struct?
            if params.table_format
                indicador = self.API_handler(params.indicador, params.fecha, ...
                    webread(url, self.options));
            else
                indicador = webread(url, self.options);
            end
        end
    end
    
    methods(Access=private)
        
        function res = API_handler(self, ind, fecha, request)
            
            % caso de todos los indicadores solicitados
            if strcmp(ind, '')
                descr = sprintf('API version %s autor %s, solicitud hecha %s', ...
                    request.version, request.autor, string(datetime('now')));
                
                % creando las variables de respuesta
                names_ = self.endpoint_vars(ind);
                res = self.selectfields(request, names_, false);
                % extrayendo el valor del indicador
                for idx = 1:numel(res)
                    res{idx} = res{idx}.valor;
                end
                
                % transformando a tabla
                res = cell2table(res);
                res.Properties.VariableNames = names_;
                res.Properties.Description = descr;
            
           % caso de indicador especifico, pero SIN fecha
           elseif ~strcmp(ind, '') && strcmp(fecha, '')
               descr = sprintf('Consulta del indicador %s con unidad de medida %s.\n API version %s autor %s, solicitud hecha %s', ...
                    request.nombre, request.unidad_medida, ...
                    request.version, request.autor, string(datetime('now')));
                
                % creando las variables de respuesta
                names_ = self.endpoint_vars(ind);
                
                % filtrar por solo las columnas con datos 
                res = self.selectfields(request.serie, names_, false);
                res = cell2table(res);
                
                % propiedades de la tabla 
                res.Properties.VariableNames = names_;
                res.Properties.Description = descr;
                
                % transformando la fecha de la API a formato legible
                res.fecha = cellfun(@(d) datetime(d(1:10), ...
                    'InputFormat', 'yyyy-MM-dd', 'Format', 'yyyy-MM-dd'),...
                    res.fecha);
                
            % caso de solicitud de algun indicador CON fecha
            elseif ~strcmp(ind, '') && ~strcmp(fecha, '')
               descr = sprintf('Consulta del indicador %s con unidad de medida %s.\n API version %s autor %s, solicitud hecha %s', ...
                    request.nombre, request.unidad_medida, ...
                    request.version, request.autor, string(datetime('now')));
                
                % creando las variables de respuesta
                names_ = self.endpoint_vars(ind);
                                
                res = self.selectfields(request.serie, names_, false);
                res = cell2table(res);
                
                % propiedades de la tabla 
                res.Properties.VariableNames = names_;
                res.Properties.Description = descr;
                
                % transformando la fecha de la API a formato legible
                res.fecha = cellfun(@(d) datetime(d(1:10), ...
                    'InputFormat', 'yyyy-MM-dd', 'Format', 'yyyy-MM-dd'),...
                    res.fecha);
            end
        end
        
        function out = selectfields(~, s, fields, scalarfields)
            % selectfields return the fields of a structure array that 
            % matches the given list of field names
            %
            % syntax:
            %   out = selectfields(s, fields)
            %   out = selectfields(s, fields, asarray)
            %
            % with:
            %   s:              a structure
            %   fields:         a cell array of field names
            %   scalarfields:   logical indicating whether the returned fields 
            %                   are scalar (true, default) or not
            %   out:            a column vector of field values (if scalarfields 
            %                   is true or omitted), a column cell array otherwise
            %
            % source
            % https://la.mathworks.com/matlabcentral/answers/224088-select-specific-data-from-all-fields-in-structure#comment_292470

              validateattributes(s, {'struct'}, {});
              validateattributes(fields, {'cell'}, {});
              if nargin < 3
                  scalarfields = true;
              else
                  validateattributes(scalarfields, {'logical'}, {'scalar'});
              end
              out = arrayfun(@(ss) cellfun(@(f) ss.(f), fields, 'UniformOutput', scalarfields), s, 'UniformOutput', false);
              out = vertcat(out{:});
        end
        
        function names_ = endpoint_vars(~, option)
            % seleccionar los nombres de las variables del endpoint a
            % ocupar en la construccion de la tabla como respuesta a la
            % solicitud de la API

            if strcmp(option, '')
                names_ = {'uf', 'ivp', 'dolar', 'dolar_intercambio', ...
                    'euro', 'ipc', 'utm', 'imacec', 'tpm', ...
                    'libra_cobre', 'tasa_desempleo', 'bitcoin'};
                
            elseif ~strcmp(option, '')
                names_ = {'fecha', 'valor'};
            end
        end
    end
end

