classdef Distribution < handle
    
    % Class Distribution
    %
    % Used for defining distributions.
    %
    % The size vector needs to be defined. The distribution can be defined
    % as either a function handle or as a vector. The class checks the
    % inputs, and returns a vector in any case.
    %
    % The class can be called as follows:
    %
    %   dist = Distribution(y,@(x)normalpdf(x,1,0.1));
    %
    % to create a distribution based on the normal distribution, or the
    % properties y and F can be set separately:
    %
    %   dist = Distribution;
    %   dist.y = linspace(0,2,50);
    %   dist.F = @(x) normalpdf(x,1,0.1);
    %
    % This class can be used to define multiple distributions, having their
    % own size vectors, in the following way:
    %
    %   dist(1) = Distribution(linspace(0,2),@(x)normalpdf(x,1,0.1));
    %   dist(2) = Distribution(linspace(0,3),@(x)normalpdf(x,2,0.5));
    %
    
    %% Properties
    
    properties
        
        % Initial grid vector
        % Define as vector
        y = linspace(0,1,20);
        
    end % properties
    
    properties (Dependent)
        
        % Initial distribution
        % Define as either a function or a vector
        F = [];
        
    end % properties
    
    properties (Access=private)
        
        % Private version of F - this is where the data is stored.
        pF = [];
        
    end % properties
    
    methods
        
        %% Method Distribution (constructor)
        
        function O = Distribution(y,F)
            
            % If given, define y and F based on inputs. Otherwise, do
            % nothing
            
            if nargin > 0 && ~isempty(y)
                O.y = y;
            end % if
            
            if nargin > 1 && ~isempty(F)
                O.F = F;
            end % if
            
        end % function
        
        %% Method set.F
        
        function set.F(O,value)
            
            % SET.F
            %
            % Check input: vector, function handle, or empty
            
            if strcmp(class(value),'function_handle') || isvector(value) || isempty(value)
                % Value is ok, set
                
                O.pF = value;
                
            else
                % Value is not OK - display warning
                warning('Distribution:setF0:WrongType',...
                    'F has to be a function handle or a vector');
            end % if
            
        end % function
        
        %% Method get.F
        
        function Fout = get.F(O)
            
            % GET.F
            % Return F, based on what is in y.
            % If F is a function handle: calculate vector using positions
            % at y. If F is a vector, check so that its size is the same
            % as that of y
            
            if strcmp(class(O.pF),'function_handle')
                % Function handle - calculate values
                
                Fout = O.pF(O.y);
                
            elseif isvector(O.pF)
                
                if any( size(O.pF) ~= size(O.y) )
                    warning('Distribution:getF0:WrongSize',...
                        'F is not the same size as y');
                    Fout = [];
                else
                    Fout = O.pF;
                end % if else
                
            else
                Fout = [];
            end % if else
            
        end % function
        
        %% Method plot(F)
        
        function Fpl = plot(O,varargin)
            
            % PLOT Distribution
            %
            % Use plot(F) to plot the distribution in a 2D plot. Axis
            % labels are added automatically.
            %
            % PLOT returns the handles to the plot objects created.
            %
            % To plot the figures into an existing axes object, use:
            %   plot(F,'Parent',axhandle)
            %
            
            % Check if Parent axes are already defined
            useaxpos = find(strcmp(varargin,'Parent'));
            
            if ~isempty(useaxpos) && ishandle(varargin{useaxpos+1})
                % Define this axes as the one to use
                Fax = varargin{useaxpos+1};
                % Remove this parent command from varargin, is added again
                % later
                varargin(useaxpos+(0:1)) = [];
            else
                FFig = figure;
                Fax = axes('Parent',FFig);
                xlabel(Fax,'Size y')
                ylabel(Fax,'Distribution y')
            end % if
            
            % Handles for plots
            Fpl = zeros(size(O));
            
            hold(Fax,'all')
            
            % Plot every distribution
            for i = 1:length(O)
                Fpl(i) = plot(...
                    O(i).y,O(i).F,...
                    'Parent',Fax,'DisplayName',['Dist ' num2str(i)],...
                    varargin{:});
            end % for
            
        end % function
        
    end % methods
    
end % classdef