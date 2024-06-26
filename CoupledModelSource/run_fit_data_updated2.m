clear all
clc

path = '/Users/brettcardenas/Desktop/Stanford_CVI/Extracted_MCT_Data.xlsx';
% path = '/Users/brettcardenas/Desktop/Stanford_CVI/Extracted_SuHx_Data.xlsx';
sheets = sheetnames(path);
days_run = 40;
inputs = {'Cardiac output (ml/min)','Cardiac index'};
% wt_vars = {'WT (%), >100 um OD', 'WT (%), <100 um OD'};
% stiff_vars = {'Shear mod (kPa), >100 um OD','Shear mod (kPa), <100 um OD'};
% pressure_vars = {'mPAP (mmHg)', 'RVSP (mmHg)'};
% ecs_vars = {'Elastase activity ratio to control','Colagenase activity ratio to control','COL1A1 mRNA'};
% metric_names = [wt_vars,stiff_vars,'mPAP (mmHg)',ecs_vars];
metric_names = "RVSP (mmHG)";
num_mets = numel(metric_names);
exp_data = cell(1,num_mets);
metric_names = [metric_names inputs];
co_data = [];

%Loop over each metric
for metric = 1:num_mets
    curr_metric = metric_names{metric};
    %Store metric values across all literature data
    total_metric = [];

    %Loop over each sheet/article
    for sheet = 1:numel(sheets)
        curr_sheet = sheets(sheet);
        time = 'Time (wks)';
    
        %Keep headers intact
        opts = detectImportOptions( ...
            path, ...
            "VariableNamingRule","preserve", ...
            "Sheet",curr_sheet ...
            );

        column_headers = opts.VariableNames;

        %Check if metric is in current sheet/article, else skip
        if ~any(strcmp(column_headers,curr_metric))
            continue
        end

        %Change time to days if necessary
        if ~any(strcmp(column_headers, time))
            time = 'Time (days)';
        end

        %Select only metric studied now
        if strcmp(curr_metric,'Cardiac index')
            %If cardiac index (CI), we also need body weight
            opts.SelectedVariableNames = {time, curr_metric, 'BW (g)'};
        else
            opts.SelectedVariableNames = {time, curr_metric};
        end

        sheet_metric = readtable(path,opts);

        %Remove -1 values (no data); if error, fix the metrics cell array
        sheet_metric(ismember(sheet_metric{:,curr_metric},-1),:) = [];

        %Normalize CI data by time-matched control (e.g. "Control Day 8")
        if strcmp(curr_metric,'Cardiac index')

            %Convert to cardiac output (CO)
            sheet_metric.CO = sheet_metric{:,2} .* sheet_metric{:,3};
            sheet_metric(:,[2,3]) = [];
            numrows = height(sheet_metric);
            time_pts = 0.5 * numrows;
            treatment_gp = sheet_metric(1:time_pts,'CO');
            ctrl_gp = sheet_metric((time_pts+1):numrows,'CO');
            norm_co = treatment_gp ./ ctrl_gp;
            sheet_metric(1:time_pts,"CO") = norm_co;
        end

        %Normalize CO data to only the "Day 0" control
        if strcmp(curr_metric,'Cardiac output (ml/min)')
            sheet_metric = renamevars(sheet_metric,"Cardiac output (ml/min)","CO");
            ctrl = sheet_metric{1,2};
            numrows = height(sheet_metric);
            for row = 1:numrows
                sheet_metric{row,2} = sheet_metric{row,2} / ctrl;
            end
        end

        %Remove NaN values
        sheet_metric = rmmissing(sheet_metric);

        %If time is in weeks, change units to days
        if strcmp(sheet_metric.Properties.VariableNames{1}, 'Time (wks)')
            sheet_metric{:,1} = 7 * sheet_metric{:,1};
            sheet_metric = renamevars(sheet_metric,"Time (wks)","Time (days)");
        end

        %Add table with information about the current sheet/article
        %to total_metric for values across all the literature data
        %EXCEPT store CO data into its own table to use as input for model
        if any(strcmp(curr_metric,inputs))
            co_data = [co_data; sheet_metric];
        else
            total_metric = [total_metric; sheet_metric];
        end

    end

    %Remove 35 wk data point (only applicable for SuHx data)

    %total_metric(ismember(total_metric{:,"Time (days)"},245),:) = [];

    
    %Take average of all literature data for each day observed
    if ~any(strcmp(curr_metric,inputs))
        %If looking at multiple metrics together
        %[temp,~,idx] = unique(total_metric{:,1});

        %If looking at only one metric
        exp_data{metric} = mean(total_metric);
    end

end


% % Feed input data
% [temp,~,idx] = unique(co_data{:,1});
% input_data = [temp, accumarray(idx,co_data{:,2},[],@mean)];
% 
% Q_exp_time = input_data(:,1);
% dQ_exp = input_data(:,2) - input_data(1,2);
% 
% dQ_interpolated_times = 0:5:84;
% dQ_interpolated = interp1(Q_exp_time,dQ_exp,dQ_interpolated_times,'pchip');
% dQ_smooth = smooth(dQ_interpolated, 5);
% dQ_inputs_times = 0:1:84;
% dQ_inputs = interp1(dQ_interpolated_times,dQ_smooth,dQ_inputs_times,'pchip');


x = 0:days_run;

% y(row, column, set)
metric_exp_vals = NaN(numel(metric_names),1);

for metric = 1:num_mets
    % I keep getting an error here
    metric_exp_vals(metric) = exp_results(length(x), exp_data, metric);

end


%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%2. Run the coupled model script and read in the simulated outputs
%--------------------------------------------------------------------------

params_uniform_infl.Ki_Tact = 0.0;
params_uniform_infl.phi_Tact0_min = 1.00;
params_uniform_infl.gamma_i = opt_parameter;
params_uniform_infl.Ki_steady = 1.0; %0.80;
params_uniform_infl.delta_i = 1.00;
params_uniform_infl.K_infl_eff = 1.00;
params_uniform_infl.s_int_infl = 0;
params_uniform_infl.delta_m = 1.00;
params_uniform_infl.K_mech_eff = 0.25;
params_uniform_infl.s_int_mech = 0;
params_uniform_infl.epsilonR_e_min = 1.00;

simulation_settings.tree_diamrat_prev_flag = 1; %Use diameter ratio from a previous solve 1
simulation_settings.tree_solve_prev_flag = 1; %Use down the tree material parameters from a previous solve 1
simulation_settings.tree_gen_prev_flag = 1; %Use a morphometric tree from a previous solve 1
simulation_settings.single_vessels_flag = 0; %Disable hemodynamic feedback 1
simulation_settings.mech_infl_flag = " --mech_infl_flag 0"; %Use inflammation driven by WSS 1
simulation_settings.dQ = 0.00; %Pertubation in inflow
simulation_settings.dP = 0.00; %Pertubation in outlet pressure
simulation_settings.k_ramp = 1/4; %days to ramp hemodynamic changes over
simulation_settings.step_size = 1.0; %size of step in days
simulation_settings.max_days = days_run; %maximum days to run the G&R
simulation_settings.save_steps = 1; %number of steps between hemo->G&R feedback, min 1
simulation_settings.other = "test_run2";

ts = 0: simulation_settings.step_size: simulation_settings.max_days / simulation_settings.step_size - 1;
simulation_settings.dQ_s = simulation_settings.dQ * (1 - exp( -simulation_settings.k_ramp * ts));
%simulation_settings.dQ_s = dQ_inputs;

%Store simulated data
sim_data = cell(1,10);
total_days = days_run + 1;

selected_metrics = [0 0 0 0 1 0 0 0]; %these are 1 if it's included and 0 if not

opt_function = @(opt_parameter) objective_combined(sim_data, selected_metrics, metric_sim_vals, params, opt_parameter);

opt_parameter0 = [1, 1];
opt_gamma = lsqnonlin(opt_function, opt_parameter0);

J = J_combined(objective_combined(selected_metrics, metric_names, opt_parameter));

function J = objective_combined(sim_data, selected_metrics, params, opt_parameter)

    params.Ki_steady = opt_parameter(1);
    
    %run the gnr code with opt_parameters as the input

    [~, ~] = fun_run_tree_GnR(simulation_settings,params_uniform_infl);

    pressure_fold = zeros(1,total_days);

    metric_sim_vals = NaN(numel(metric_names));
    
    for order = 1:10
        file = strcat('GnR_out_ord',num2str(order));
        sim_data{order} = load(file);

        for day = 1:total_days

            order_info = sim_data{order}(day,:);
        
            r_inner = order_info(1) * 10^6;
            h = order_info(2) * 10^6;
            r_outer = r_inner + h;
            od = 2 * r_outer;
    
            % outer = (r_outer)^2;
            % inner = (r_inner)^2;
            % percent_thick = 100 * (outer - inner)/inner;

            new_col = numel(sim_data{order}(day,:)) + 1;

            sim_data{order}(day,new_col) = order_info(21) + order_info(22) + order_info(23) + order_info(24);
            sim_data{order}(day,new_col + 1) = percent_thick;

            if order == 10

                if day == 1
                    pressure_fold(1) = order_info(9);
                end

                pressure_fold(day) = order_info(9) / pressure_fold(1);

            end

        end
    end

    [metric_sim_vals(1), metric_sim_vals(2)] = sim_results(total_days,sim_data,26, od);
    [metric_sim_vals(3), metric_sim_vals(4)] = sim_results(total_days,sim_data,15, od);

    metric_sim_vals(5) = pressure_fold;

    [~, metric_sim_vals(6)] = sim_results(total_days,sim_data,16, od);
    [~, metric_sim_vals(7)] = sim_results(total_days,sim_data,18, od);
    [~, metric_sim_vals(8)] = sim_results(total_days,sim_data,25, od);

    %read in the simulation results
    
    J = zeros(1,length(selected_metrics));

    for i = 1:length(selected_metrics)
        J_curr = 0;
        if selected_metrics(i) > 0
            J_curr = (metric_sim_vals(i) - metric_exp_vals(i)) / metric_exp_vals(i);
        end

        % Make array of J for each of the different metrics
        J(i) = J_curr;

    end

end
