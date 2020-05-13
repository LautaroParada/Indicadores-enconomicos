classdef Indicadores
    % Este es un cliente de la API que entrega los principales indicadores 
    % económicos para Chile en formato JSON. Tanto los indicadores diarios
    % como los históricos pueden ser usados por desarrolladores y/ analistas
    % en aplicaciones, analisis, etc. 
    % La API mapea constantemente el sitio del Banco Central de Chile
    % manteniendo así la base de datos actualizada con los últimos valores
    % del día.
    % 
    % La documentación oficial de la API puede ser encontrada en el
    % siguiente sitio web 
    % https://mindicador.cl/
    % 
    % La documentación del cliente en *Matlab* puede ser encontrada en el
    % siguiente sitio
    % ...
    
    properties
        timeout = 60 % tiempo maximo para esperar por la respuesta
    end
    properties(Constant)
        HOST = 'https://mindicador.cl/api' % Servidor de produccion
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
            % Este método extrae los endpoints disponibles para cliente de 
            % la API, no necesita ningún tipo de parámetros, ya que 
            % descarga la información desde la pagina web de la API.
            %
            % Argumentos
            % -------
            % Ninguno
            %
            % Resultados
            % -------
            % String array con los endpoints/indicadores disponibles para 
            % solicitar desde la API.
            %
            % Ejemplo
            % >> Indicadores().metadata()
            %
            % Autor: Lautaro Parada Opazo.
            
            url = 'https://mindicador.cl/';
            code = webread(url);
            tree = htmlTree(code);
            selector = 'tr';
            meta_ = extractHTMLText(findElement(tree, selector));
        end
        
        function indicador = get_data(self, params)
            % Este método crea la solicitud a la API con respecto a los 
            % datos del indicador referenciado. Actualmente la API es capaz
            % de enviar datos bajo las siguientes modalidades: 
            % - un 'snapshot' al día de hoy de todos los indicadores 
            %   disponibles
            % - Valores para los ultimos 30 doas para algún indicador
            % - Solicitar datos para algún indicador especifico para alguna
            %   fecha específica o año especifico.
            % 
            % Argumentos Name-value
            % -------
            % indicador(char): Indicador económico a solicitar. Para una 
            %                  lista completa de los indicadores disponibles
            %                  ocupe el método metadata o get_data().
            % fecha(char): Fecha para solicitar datos, esta puede tener los
            %              siguientes formatos: 
            %                       - 'yyyy'
            %                       - 'dd-mm-yyyy'
            % table_format(logical): Los valores de la solicitud a la API 
            %                        son presentados en una tabla o struct?
            %                        *true* es el valor predeterminado. 
            %
            % Resultados
            % -------
            % Tabla o struct con los datos solicitados
            %
            % Ejemplos
            % -------
            % % Snapshot con todos los indicadores disponibles con los datos más recientes
            % >> Indicaodres().get_data() 
            % % valor de la UF en los últimos 30 días.
            % >> Indicadores().get_data('indicador', 'uf') 
            % % valores de la libra de cobre para el día 24 de Octubre de 1991
            % >> Indicadores().get_data('indicador', 'ivp', 'fecha', '24-10-1991')
            %
            % Autor: Lautaro Parada Opazo
            
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

