classdef CAT < hgsetget
    %% Class CAT
    % The Crystallization Analysis Toolbox (CAT) class defines numerical
    % settings, initial and operating conditions to set up problems
    % encountered in crystallization science. It furthermore allows to
    % solve this kind of problems using a variety of different solvers.
    % Construct a CAT object and set properties as you see fit. The
    % currently recommended pathway is to fill out protocat and save it as
    % new file.
    
    % Dave Ochsenbein, 15.10.2013
    
    properties ( Access = protected )
        
        % nodes for non-smooth input profiles
        tNodes = [];
        
    end
    
    properties
        
        % Initial distribution (Distribution object, defines size and
        % distribution
        init_dist
        
        % Initial concentration
        init_conc % saturated
        
        % Solubility
        % @(T,xm)
        solubility
        
        % Temperature profile
        Tprofile
        
        % (Anti)solvent added mass profile
        ASprofile

        % Growth rate function This function should be called as
        % growthrate(S,T,y) where S is the current supersaturation, T is the
        % temperature and y is the size. It should return a vector the same
        % size as y
        growthrate
        
        % Nucleation rate function
        % This function should be called as nucleationrate(c,T,m) where S is the current
        % supersaturation, T is the temperature. Optionally, the user can
        % specificy that the nucleation rate depends on a moment m of the
        % passed distribution F
        nucleationrate
        
        % Seed mass
        init_seed
        
        % Initial mass of solvent + antisolvent
        init_massmedium
        
        % Solution time vector
        sol_time
        
        % Crystal density
        rhoc
        
        % Shape factor
        kv
        
        % Method to use - default to central difference
        sol_method
        
        % Solver Options
        sol_options = [];
        
        %% Results
        
        % Vector of actual times returned by solver
        calc_time
        
        % Distributions for each time step
        calc_dist
        
        % Concentrations over time [g solute / g total solvents]
        calc_conc
  
    end % properties
    
    methods
        
        %% Method CAT (constructor)
        
        function O = CAT(varargin)
            
            % CAT
            %
            % Constructor function for CAT class. Called as:
            %	PD = CAT(init_dist,init_conc,sol_time,...
            %      sol_method,growthrate)
            %
            % Leave any of the variables empty to not assign them.
            %
            % The variables which are given are assigned directly to the
            % corresponding property. All of them can also be assigned
            % later.
            
            % Set values, if they are given
            
            if  nargin == 0 || (nargin>0 && ~isempty(find(strcmp(varargin,'empty'))))
                
            elseif  (nargin>0 && ~isempty(find(strcmp(varargin,'default'))))
                
                O.setDefaults;
                
            end
            
            % Initialise paths
            disp('Initializing...')
            
            startstr = pwd;
%             addpath(startstr)
            addpath(strcat(startstr,filesep,'general'))
            addpath(strcat(startstr,filesep,'solvers'))
            addpath(strcat(startstr,filesep,'solvers',filesep,'hires'))
            addpath(strcat(startstr,filesep,'solvers',filesep,'movingpivot'))
            addpath(strcat(startstr,filesep,'solvers',filesep,'centraldifference'))
            
            disp('Done.')
            
        end % function
        
        function setDefaults(O)
            O.init_dist = Distribution(linspace(1,500,200),{'normal',100,20});
            O.init_conc = 1; % saturated
            O.solubility = @(T,xm) 1;
            O.Tprofile = @(t) 25*ones(size(t));
            O.ASprofile = @(t) 0*t;
            O.growthrate = @(S,T,y) ones(size(y));
            O.nucleationrate = @(S,T,m) 0;
            O.init_seed = 1;
            O.init_massmedium = 1000;
            O.sol_time = [0 100];
            O.rhoc = 1e-12;
            O.kv = 1;
            O.sol_method = 'centraldifference'; 
        end
        
        %% Method set.rhoc
        
        function set.rhoc(O,value)
            
            % SET.rhoc
            %
            % Check the crystal density. It must be a scalar
            
            if isempty(value)
                ;
            elseif~isscalar(value)
                warning('CAT:Setrhoct:WrongType',...
                    'The rhoc property must be a scalar.');
            else
                O.rhoc = value;

            end % if else
            
            
        end % function
        
        %% Method set kv
        
        function set.kv(O,value)
            
            % SET.kv
            %
            % Check the shape factor. It must be a scalar
            
            if isempty(value)
                ;
            elseif~isscalar(value)
                warning('CAT:Setkv:WrongType',...
                    'The rhoc property must be a scalar.');
            else
                O.kv = value;
            end % if else
            
        end % function
        
        %% Method set init_dist
        
        function set.init_dist(O,value)
            
            % SET.INIT_DIST
            %
            % Check the initial distribution, it must be a distribution
            % class object
            
            if ~isa(value,'Distribution')
                warning('CAT:SetInit_Dist:WrongType',...
                    'The init_dist property must be a Distribution object');
            else
                O.init_dist = value;
            end % if else
            
            % Extra function - overwritable in subclasses
            O.init_dist_onset;
            
        end % function
        
        function init_dist_onset(O)
            
            % Do nothing - no function in this class, merely something to
            % be overwritten by subclass
            
        end % function
        
        %% Method set.init_seed
        
        function set.init_seed(O,value)
            
            % SET.INIT_SEED
            %
            % Set mass of seeds
            
            if isscalar(value) && ~isnan(value) && value>=0 && ~isinf(value)
                O.init_seed = value;
            else
                warning('CAT:SetInit_Seed:WrongType',...
                    'The init_seed property must be a non-negative scalar');
            end % if else
            
            % Extra function - overwritable in subclasses
            O.init_seed_onset;
            
        end % function
        
        function init_seed_onset(O)
            
            % Do nothing - no function in this class, merely something to
            % be overwritten by subclass
            
        end % function
            
        
        %% Method set/get init_conc
        
        function set.init_conc(O,value)
            
            % SET.INIT_CONC
            %
            % Check the initial concentration, it must be a positive,
            % finite scalar (can be zero)
            
            if (isscalar(value) && value >= 0 && isfinite(value)) || strcmpi(value,'sat')
                O.init_conc = value;
                
            else
                warning('CAT:SetInit_Conc:WrongType',...
                    'The init_conc property must be a positive, finite scalar (may be zero) or the string ''sat''');
            end % if else
            
            % Extra function - overwritable in subclasses
            O.init_conc_onset;
            
        end % function
        
        function init_conc_onset(O)
            
            % Do nothing - no function in this class, merely something to
            % be overwritten by subclass
            
        end % function
        
        function [cinit] = get.init_conc(O)
            
            % GET.INIT_CONC
            %
            % Getter method for init conc
            
            
            if strcmpi('sat',O.init_conc) && ~isempty(O.solubility)
                O.init_conc = O.solubility(O.Tprofile(O.sol_time(1)),O.ASprofile(O.sol_time(1))/O.init_massmedium);
            end
            cinit = O.init_conc;
            
        end % function
        
        %% Method set.init_massmedium
        
        function set.init_massmedium(O,value)
            
            if (isscalar(value) && value >= 0 && isfinite(value))
                O.init_massmedium = value;
            else
                warning('CAT:SetInit_Massmedium:WrongType',...
                    'The init_conc property must be a positive, finite scalar (may be zero)');
            end % if else
            
            % Extra function - overwritable in subclasses
            O.init_massmedium_onset;
            
        end % function
        
        function init_massmedium_onset(O)
            
            % Do nothing - no function in this class, merely something to
            % be overwritten by subclass
            
        end % function
        
        %% Method set.solubility
        
        function set.solubility(O,value)
            
            % SET.solubility
            %
            %  Setter method for solubility Must be a function handle with
            %  1 or 2 inputs
            
            % Check for number - convert to constant function
            if isnumeric(value) && length(value) == 1
                O.solubility = str2func(['@(T,xm)' num2str(value) '*ones(size(T))']);
            elseif ischar(value)
                % Check for string 
                if isempty(findstr(value,'@(T,xm)')) && isempty(findstr(value,'@(T)')) && isempty(findstr(value,'@(xm)'))
                    O.solubility = str2func(['@(T,xm)' value '*ones(size(T))']);
                else
                    O.solubility = str2func([value '*ones(size(T))']);
                end
            elseif isa(value,'function_handle')
                
                if nargin(value) < 2
                    % This is too few, the function needs to accept two
                    % inputs (even if the second isn't used)
                    O.solubility = str2func(['@(T,xm)' anonfunc2str(value)]);
                else
                    % If the function is defined with more inputs, there is
                    % no problem as long as the other values are not
                    % needed. This will give an error later
                    O.solubility = value;
                end % if elseif
                
            else
                warning('CAT:SetSolubility:WrongType',...
                    'The solubility property must be a positive, finite value (may be zero) or a function handle with one or two inputs');
            end % if else
            
            % Extra function - overwritable in subclasses
            O.solubility_onset;
            
        end % function
        
        function solubility_onset(O)
            
            % Do nothing - no function in this class, merely something to
            % be overwritten by subclass
            
        end % function
        
        %% Method set.sol_time
        
        function set.sol_time(O,value)
            
            % SET.SOL_TIME
            %
            % Check the solution time vector. This should be a vector of
            % monotonically increasing values
            
            if length(value) > 1 && isvector(value) && ~any(diff(value)<=0)
                O.sol_time = value;
            elseif isscalar(value)
                O.sol_time = [0 value];
            else
                warning('CAT:SetSol_Time:WrongValue',...
                    'The property sol_time must be a vector of monotonically increasing values');
            end % if else
            
        % Extra function - overwritable in subclasses
            O.sol_time_onset;
            
        end % function
        
        function sol_time_onset(O)
            
            % Do nothing - no function in this class, merely something to
            % be overwritten by subclass
            
        end % function
        
        %% Method set.sol_method
        
        function set.sol_method(O,value)
            
            % SET.SOL_METHOD
            %
            % Check the defined solution method. Should be a string
            %
            % Probable more checks should be carried out at this point in
            % the future
            
            if ischar(value)
                
                % Remove spaces from name first
                value = strrep(value,' ','');
                
                % don't be case sensitive and allow alternative forms
                switch lower(value)
                    case {'cd','centraldifference'}
                        O.sol_method = 'centraldifference';
                    case {'mp','movingpivot'}
                        O.sol_method = 'movingpivot';
                    case {'hr','hires','highresolution'}
                        O.sol_method = 'hires';
                    otherwise
                        error('CAT:SetSol_Method:unknown',...
                            'Unknown solution method');
                end % switch
                
            elseif isempty(value)
                warning('CAT:SetSol_Method:isempty',...
                    'The property sol_method was set to the default value (centraldifference)');
                O.sol_method = 'centraldifference';
            else
                warning('CAT:SetSol_Method:WrongType',...
                    'The property sol_method should be a string or empty (chooses default)');
            end % if else
            
        % Extra function - overwritable in subclasses
            O.sol_method_onset;
            
        end % function
        
        function sol_method_onset(O)
            
            % Do nothing - no function in this class, merely something to
            % be overwritten by subclass
            
        end % function
        
        %% Method set.sol_options
        
        function set.sol_options(O,value)
            
            % SET.SOL_OPTIONS
            %
            % Check the defined OPTIONS. Should be a cell array
            %
            % Probable more checks should be carried out at this point in
            % the future
            
            if iscell(value)
                O.sol_options = value;
            else
                warning('CAT:SetSol_Options:WrongType',...
                    'The property sol_options should be a cell');
            end % if else
            
        % Extra function - overwritable in subclasses
            O.sol_options_onset;
            
        end % function
        
        function sol_options_onset(O)
            
            % Do nothing - no function in this class, merely something to
            % be overwritten by subclass
            
        end % function
        
        %% Method set.Tprofile
        
        function set.Tprofile(O,value)
            
            % SET.Tprofile
            %
            % Check the Temperature profile. It must be a matrix with
            % positive, finite elements. The first row indicates the times
            % of the nodes whereas the second row indicates Temp's

            if ~isempty(value) && ismatrix(value) && length(value(:,1))==2 && all(isfinite(value(:)))
               
                if value(1,end)<O.sol_time(end)
                    value = [value [0;0]];
                    value(1,end) = O.sol_time(end);
                    value(2,end) = value(2,end-1);
                end
%                 O.Tprofile = @(t) interp1(value(1,:),value(2,:),t); %
                O.Tprofile = @(t) piecewiseLinear(value(1,:),value(2,:),t); %
                O.tNodes = unique([O.tNodes value(1,:)]);


            elseif isa(value,'function_handle') && nargin(value)==1
                
                if length(value([0 10]))==1
                    O.Tprofile = @(t) value(t)*ones(size(t)); % output should be a vector of same size as input
                else
                    O.Tprofile = value;
                end
                    
            elseif isscalar(value)
                O.Tprofile = @(t) value*ones(size(t));
                
            elseif isempty(value)
                ;
            else
                warning('CAT:SetTprofile:WrongType',...
                    'The Tprofile property must be a positive, finite matrix (may be zero) or a function handle with one input');
                
            end % if else
            
            % Extra function - overwritable in subclasses
            O.Tprofile_onset;
            
        end % function
        
        function Tprofile_onset(O)
            
            % Do nothing - no function in this class, merely something to
            % be overwritten by subclass
            
        end % function
        
        %% Method set.ASprofile
        
        function set.ASprofile(O,value)
            
            % SET.ASprofile
            %
            % Check the time profile (for added AS profiles). It must be
            % a strictly increasing(!), positive vector
%             keyboard
            if ~isempty(value) &&  ismatrix(value) && length(value(:,1))==2 && all(isfinite(value(:))) && all(diff(value(2,:))>=0)
               
                if value(1,end)<O.sol_time(end)
                    value = [value [0;0]];
                    value(1,end) = O.sol_time(end);
                    value(2,end) = value(2,end-1);
                end
%                 O.ASprofile = @(t) interp1(value(1,:),value(2,:),t); %
                O.ASprofile = @(t) piecewiseLinear(value(1,:),value(2,:),t); %
                O.tNodes = unique([O.tNodes value(1,:)]);


            elseif isa(value,'function_handle') && nargin(value)==1
                O.ASprofile = value;
                
            elseif isempty(value)
                ;
            else
                warning('CAT:SetTprofile:WrongType',...
                    'The ASprofile property must be a positive, finite matrix (may be zero) or a function handle with one input');
                
            end % if else
            
            % Extra function - overwritable in subclasses
            O.ASprofile_onset;
            
        end % function
        
        function ASprofile_onset(O)
            
            % Do nothing - no function in this class, merely something to
            % be overwritten by subclass
            
        end % function
        
        
        %% Method set.tNodes
        
        function set.tNodes(O,value)
            
            % SET.tNodes
            %
            % Set time nodes (make sure integrator covers them correctly)
            if isvector(value) && all(value>=0)

                O.tNodes = value;

            else
                warning('CAT:SettNodes:WrongType',...
                    'The tNodes property must be a non-negative vector');
                
            end % if else
            
        end % function
        
        %% Method set.growthrate
        
        function set.growthrate(O,value)
            
            % SET.GROWTHRATE
            %
            % Check the growth rate: should be a function handle, accept 3
            % arguments: S (scalar), T (temperature), and y (vector). The output should be
            % the same size as y
            
            % If the growth rate is not given as a function, make best
            % choice to convert it into one
            
            if isnumeric(value) && length(value) == 1
                O.growthrate = str2func(['@(S,T,y)' num2str(value) '*ones(size(y))']);
            elseif ischar(value)
                O.growthrate = str2func(['@(S,T,y)' value]);
            elseif isa(value,'function_handle')
                
                % Check the number of inputs
                if nargin(value) == 3
                    
                    % Check the output using 2 example values
                    out = value(1.1,1,linspace(0.1,1,10));
                    
                    % Check size
                    if any( size(out) ~= [1 10] )
                        % Size of output wrong
                        warning('Distribution:setgrowthrate:Wrongsize',...
                            'The growth rate function returns a vector which is not the same size as the input vector');
                    end
                    % Set the growthrate anyway
                    O.growthrate = value;
                    
                elseif nargin(value) == 2 && length(value(1.1,1))==1
                    % assume size independent function
                    O.growthrate = @(S,T,~) value(S,T);
                
                elseif nargin(value) == 2 && length(value(1.1,[1 2]))==2
                    % assume temperature independent function
                    O.growthrate = @(S,~,y) value(S,y);
                    
                else
                    warning('Distribution:setgrowthrate:Wrongnargin',...
                        'The growth rate function must have 3 input arguments (supersaturation, temperature, sizes) or 2 input arguments (S,T) or (S,y)');
                end % if
                
            else % not a function handle
                warning('Distribution:setgrowthrate:Wrongtype',...
                    'The growth rate must be a positive, finite value (may be zero) or a function handle with two or three inputs');
            end %if
            
            % Extra function - overwritable in subclasses
            O.growthrate_onset;
            
        end % function
        
        function growthrate_onset(O)
            
            % Do nothing - no function in this class, merely something to
            % be overwritten by subclass
            
        end % function

        %% Method set.nucleationrate
        
        function set.nucleationrate(O,value)
            
            % SET.nucleationrate
            %
            % Check the nucleationrate rate: should be a function handle,
            % accept max. 3 arguments: S (supersaturation), T (temperature), F (distribution). The output should be
            % a scalar
            
            if isnumeric(value) && length(value) == 1
                O.nucleationrate = str2func(['@(S,T,F)' num2str(value) '*ones(size(S))']);
            elseif ischar(value)
                O.nucleationrate = str2func(['@(S,T,F)' value]);
            elseif isa(value,'function_handle')
                if nargin(value) == 1
                    O.nucleationrate = str2func(['@(S,~,~)' anonfunc2str(value)]);
                elseif nargin(value) == 2
                    O.nucleationrate = str2func(['@(S,T,~)' anonfunc2str(value)]);
                else
                    O.nucleationrate = value;
                end
                
            elseif isempty(value)
                ;

            else % not a function handle
                warning('Distribution:setnucleationrate:Wrongtype',...
                    'The nucleation rate must be a positive, finite value (may be zero) or a function handle with one to three inputs');
            end %if
            
        % Extra function - overwritable in subclasses
            O.nucleationrate_onset;
            
        end % function
        
        function nucleationrate_onset(O)
            
            % Do nothing - no function in this class, merely something to
            % be overwritten by subclass
            
        end % function

        %% Mass solvent + antisolvent at t
        function mscalc = massmedium(O,t)
            if ~exist('t','var')
                t = O.calc_time(:);
            end
            mscalc = O.init_massmedium+O.ASprofile(t)-O.ASprofile(0); % total amount of medium  
        end % function
        
        %% Method massbal
        
        function PDma = massbal(O)
            mass_solute = O.calc_conc(:).*massmedium(O);   % total mass of solute
            m3 = moments(O.calc_dist,3);                            % third moment over time
            mass_crystals = O.rhoc*O.kv*massmedium(O).*m3(:);    % total mass of crystals
            
            PDma = 100*((mass_solute + mass_crystals)/(mass_solute(1)+mass_crystals(1))-1);     % mass balance error   
        end % function
        
        %% Method save
        % This function saves the CAT instance in a mat file
        function save(O,CATname)
            
            if nargin<2 || isempty(CATname{1})
                namestr = 'kitten';
            else
                namestr = CATname{1};
            end
            
            n = 1;
            while exist(strcat(namestr,num2str(n),'.mat'),'file')
                n = n+1;
            end
            
            namestr = strcat(namestr,'_no',num2str(n),'.mat');
 
            superCAT.kitty = O; %#ok<STRNU>
            save(namestr,'-struct','superCAT')
            disp(strcat({'Saved file to '},namestr))
            clear superCAT n
        end % function
        
        %% Method plot
        
        function PDpl = plot(O,plotwhat,varargin)
            
            % Plot function for the results
            %
            % Use plot(PD,plotwhat) to plot the results of the
            % simulation. plotwhat is a string that defines what exactly
            % should be plotted. Possible input:
            % 'results'         -   plot everything
            % 'detailed_results'-   plot everything and more
            %
            % plotted using results
            % 'distributions'   -   plot distributions
            % 'distoverlap'     -   only plot overlapping distributions (2D)
            % 'dist3D'          -   only plot 3D surf plot of distributions
            % 'cumprop'         -   plot cumulative properties (moments)
            % 'process'         -   plot process variables (T, conc)
            %
            % additionally plotted in detailed mode
            % 'moments'         -   plots of the first four moments
            % 'integration'     -   details from the integration
            % (massbalance over time,...)
            % 
            % and any combination thereof.
            %
            % PLOT returns the handles to the plot objects created. (If
            % several plots are created the sequence of handles is the
            % following: PSDs overlapping, PSDs3D, cumulative properties
            % (moments), process variables (temperature, concentration)
            %
            % Graphs can currently not be plotted in existing figures !!
            %
            
            if nargin == 1
                plotwhat = 'detailed_results';
            end
            
            serLen = length(O); % series length
            lineProps = {'b-','r-','k-','g-d','m-s','c-o'}; % line properties for series
            
            PDpl = [];

  
            % 3D plot of distributions over time
            % Note this feature is diasbled for moving pivot
            if serLen==1 && (~isempty(find(strcmp(plotwhat,'distributions'), 1)) ...
                    || ~isempty(find(strcmp(plotwhat,'dist3D'), 1)) ...
                    || ~isempty(find(strcmp(plotwhat,'results'), 1))...
                    || ~isempty(find(strcmp(plotwhat,'detailed_results'), 1))...
                    && ~strcmp(O.sol_method,'movingpivot'))
                    
                
                for i = 1:length(O.calc_dist)
                    Fmat(:,i) = O.calc_dist(i).F;
                end % for
                
                figure(12)
                set(gcf,'numbertitle','off','name','PSDs (3D time evolution)')
                
                % Handles for plots
                PDpl_local = zeros(2,1);

                subplot(1,2,1)
                PDpl_local(1) = surf(O.calc_time(:),O.calc_dist(1).y(:),Fmat,varargin{:});
                ylabel('Mean Char. Length')
                xlabel('Time')
                zlabel('Number Distribution')

                subplot(1,2,2)
                PDpl_local(2) = surf(O.calc_time,O.calc_dist(1).y,...
                    Fmat.*repmat(O.calc_dist(1).y(:).^3,1,length(O.calc_time))...
                    ./repmat(moments(O.calc_dist,3),length(O.calc_dist(1).y),1),...
                    varargin{:});
                ylabel('Mean Char. Length')
                xlabel('Time')
                zlabel('Normalized Volume Distribution')

                PDpl = [PDpl; PDpl_local];
                
            elseif serLen==1 &&(~isempty(find(strcmp(plotwhat,'distributions'), 1)) ...
                    || ~isempty(find(strcmp(plotwhat,'dist3D'), 1)) ...
                    || ~isempty(find(strcmp(plotwhat,'results'), 1))...
                    || ~isempty(find(strcmp(plotwhat,'detailed_results'), 1))...
                    && strcmp(O.sol_method,'movingpivot'...
                    && serLen==1))
                
                figure(12)
                set(gcf,'numbertitle','off','name','PSDs (3D time evolution)')
                
                % Handles for plots
                PDpl_local = zeros(2,1);

                subplot(1,2,1)
                for i = 1:length(O.calc_time)
                    PDpl_local(i) = plot3(repmat(O.calc_time(i),size(O.calc_dist(i).y)),O.calc_dist(i).y(:),O.calc_dist(i).F,varargin{:});
                    hold on
                end
                grid on
                hold off
                ylabel('Mean Char. Length')
                xlabel('Time')
                zlabel('Number Distribution')

                subplot(1,2,2)
                for i = 1:length(O.calc_time)
                    PDpl_local(i+length(O.calc_time)) = plot3(repmat(O.calc_time(i),size(O.calc_dist(i).y)),O.calc_dist(i).y,...
                    O.calc_dist(i).F(:).*O.calc_dist(i).y(:).^3./...
                    moments(O.calc_dist,3,i),...
                    varargin{:});
                hold on
                end
                grid on
                hold off
                ylabel('Mean Char. Length')
                xlabel('Time')
                zlabel('Normalized Volume Distribution')
                set(PDpl_local,'linewidth',1.5,'color','k')
                PDpl = [PDpl; PDpl_local];
                
            end % if
            
            for ii = 1:serLen
                % Cumulative Properties
                if (~isempty(find(strcmp(plotwhat,'results'), 1)) || ...
                    ~isempty(find(strcmp(plotwhat,'detailed_results'), 1)) || ...
                    ~isempty(find(strcmp(plotwhat,'cumprop'), 1)))

                    figure(21)
                    set(gcf,'numbertitle','off','name','PSD cumulative properties')  

                    % Handles for plots
                    PDpl_local = zeros(3,1);

                    subplot(3,1,1)
                    hold on
                    PDpl_local(1) = plot(O(ii).calc_time,moments(O(ii).calc_dist,0),lineProps{ii});                
                    ylabel('0^{th} moment [#/g]')
                    hold off
                    
                    subplot(3,1,2)
                    hold on
                    PDpl_local(2) = plot(O(ii).calc_time,moments(O(ii).calc_dist,3),lineProps{ii});
                    ylabel('3^{rd} moment [\mum^3/g]')
                    hold off
                    
                    subplot(3,1,3)
                    hold on
                    PDpl_local(3) = plot(O(ii).calc_time,moments(O(ii).calc_dist,4)./moments(O(ii).calc_dist,3),lineProps{ii});
                    ylabel('Weight average length [\mum]')
                    xlabel('Time [s]')
                    hold off
                    PDpl = [PDpl; PDpl_local];
                elseif (~isempty(find(strcmp(plotwhat,'detailed_results'), 1)) || ...
                    ~isempty(find(strcmp(plotwhat,'moments'), 1)))

                    figure(22)
                    set(gcf,'numbertitle','off','name','Moments Only')  
                    PDpl_local = zeros(4,1);

                    subplot(2,2,1)
                    hold on
                    PDpl_local(1) = plot(O(ii).calc_time,moments(O(ii).calc_dist,0),lineProps{ii});
                    ylabel('0^{th} moment')
                    xlabel('Time')
                    grid on
                    hold off
                    
                    subplot(2,2,2)
                    hold on
                    PDpl_local(1) = plot(O(ii).calc_time,moments(O(ii).calc_dist,1),lineProps{ii});
                    ylabel('1^{st} moment')
                    xlabel('Time')
                    grid on
                    hold off
                    
                    subplot(2,2,3)
                    hold on
                    PDpl_local(1) = plot(O(ii).calc_time,moments(O(ii).calc_dist,2),lineProps{ii});
                    ylabel('2^{nd} moment')
                    xlabel('Time')
                    grid on
                    hold off
                    
                    subplot(2,2,4)
                    hold on
                    PDpl_local(1) = plot(O(ii).calc_time,moments(O(ii).calc_dist,3),lineProps{ii});
                    ylabel('3^{th} moment')
                    xlabel('Time')
                    grid on
                    hold off
                end % if

                % Process Variables
                if (~isempty(find(strcmp(plotwhat,'results'), 1)) || ...
                    ~isempty(find(strcmp(plotwhat,'detailed_results'), 1)) ||...
                    ~isempty(find(strcmp(plotwhat,'process'), 1)))

                    figure(31)
                    set(gcf,'numbertitle','off','name','Process Variables (I)')

                % Handles for plots
                    PDpl_local = zeros(1,1);

                    nopvit = 1;
                    if ~isempty(O(ii).calc_conc)

                        subplot(2,2,nopvit)
                        hold on
                        PDpl_local = plot(O(ii).calc_time,O(ii).calc_conc,lineProps{ii},'linewidth',1.5);
                        xlim([min(O(ii).calc_time) max(O(ii).calc_time)])
                        xlabel('Time [s]')
                        ylabel('Concentration [g/g]')
                        grid on
                        PDpl = [PDpl; PDpl_local];

                        nopvit = nopvit + 1;
                        hold off
                    end % if

                    if ~isempty(O(ii).calc_conc)
                        subplot(2,2,nopvit);              
                        hold on
                        PDpl_local = plot(O(ii).calc_time(:),O(ii).calc_conc(:)./O(ii).solubility(O(ii).Tprofile(O(ii).calc_time(:))),lineProps{ii},'linewidth',1.5);
                        xlabel('Time [s]')
                        xlim([min(O(ii).calc_time) max(O(ii).calc_time)])
                        ylabel('Supersaturation [-]')
                        grid on
                        PDpl = [PDpl; PDpl_local(:)];
                        hold off
                        nopvit = nopvit + 1;
                    end % if

                    subplot(2,2,nopvit)
                    hold on
                    PDpl_local = plot(O(ii).calc_time,O(ii).Tprofile(O(ii).calc_time),lineProps{ii},'linewidth',1.5);
                    xlabel('Time [s]')
                    xlim([min(O(ii).calc_time) max(O(ii).calc_time)])
                    ylabel('Temperature [^\circC]')
                    grid on
                    PDpl = [PDpl; PDpl_local(:)];
                    hold off
                    nopvit = nopvit + 1;


                    subplot(2,2,nopvit);               
                    hold on
                    PDpl_local = plot(O(ii).calc_time,massmedium(O(ii)),lineProps{ii},'linewidth',1.5);
                    xlabel('Time')
                    xlim([min(O(ii).calc_time) max(O(ii).calc_time)])
                    ylabel('Total mass Solvent + Antisolvent [g]')
                    grid on
                    PDpl = [PDpl; PDpl_local(:)];

                    nopvit = nopvit + 1;
                    hold off

                    if ~isempty(O(ii).calc_conc) && ...
                            (~isempty(find(strcmp(plotwhat,'detailed_results'), 1)) || ...
                            ~isempty(find(strcmp(plotwhat,'process'), 1)))
                        PDpl_local = zeros(1,1);

                        figure(32)
                        hold on
                        set(gcf,'numbertitle','off','name','Process Variables (II)')
                        Tvec = linspace(min(O(ii).Tprofile(O(ii).calc_time))-5,max(O(ii).Tprofile(O(ii).calc_time))+5);
                        plot(Tvec,O(ii).solubility(Tvec),'r--','linewidth',1.5)
                        legend('Solubility','location','southeast')
                        PDpl_local = plot(O(ii).Tprofile(O(ii).calc_time),O(ii).calc_conc,lineProps{ii},'linewidth',1.5);
                        xlabel('Temperature')
                        ylabel('Concentration [g/g]')
                        grid on
                        PDpl = [PDpl; PDpl_local(:)];
                        hold off
                    end

                end % if

                if (~isempty(find(strcmp(plotwhat,'detailed_results'), 1)) || ...
                    ~isempty(find(strcmp(plotwhat,'integration'), 1)))

                    if ~isempty(O(ii).calc_conc)
                        figure(41)
                        hold on
                        set(gcf,'numbertitle','off','name',...
                            'Details from Integration')
                        PDpl_local = zeros(1,1);
                        PDpl_local = semilogy(O(ii).calc_time,massbal(O(ii)));
                        xlabel('Time')
                        ylabel('Mass balance [% error]')
                        grid on
                        PDpl = [PDpl; PDpl_local];
                        hold off
                    end % if


                end
            end
            
        end % function
        
    end % methods
    %% Static Methods
    methods (Static)
        % Compare two CAT objects
        [results,same,different] = compare(CAT1,CAT2,varargin); 
            
        % Fill out the template form
        fillOutForm(setupCat);
    end
    
end % classdef