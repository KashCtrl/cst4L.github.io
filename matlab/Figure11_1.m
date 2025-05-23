% Author: Kenji Kashima
% Date  : 2024/10/19
% Note : You should install YALMIP correctly.

function figure11_1(label)
    global_config();  % Define this function to configure global parameters

    % Define parameters
    A = [1, 0.1; -0.3, 1];  % State matrix
    B = [0.7; 0.4];         % Control matrix
    W = 0.1 * eye(2);      % Noise covariance matrix
    Sigma_10 = [2, 0; 0, 0.5];  % Target covariance
    [n, m] = size(B);
    N = 10;  % Time horizon

    % Define optimization variables
    Sigma = cell(N + 1, 1);
    for k = 1:N + 1
        Sigma{k} = sdpvar(n, n, 'symmetric');  % Sigma_k, k=0 to N
    end
    
    P = cell(N, 1);
    for k = 1:N
        P{k} = sdpvar(n, m);  % P_k, k=0 to N-1
    end
    
    M = cell(N, 1);
    for k = 1:N
        M{k} = sdpvar(m, m, 'symmetric');  % M_k, k=0 to N-1, non-negative
    end

    % Initial and terminal conditions
    Constraints = [Sigma{1} == 3 * eye(n)];  % Sigma_0 = 3 * I
    Constraints = [Constraints, Sigma{N + 1} == Sigma_10];  % Sigma_10
    if ~strcmp(label, "a")
        Constraints = [Constraints, Sigma{6}(2, 2) <= 0.5];
    end

    % Recurrence relation constraints
    for k = 1:N
        % Sigma_{k+1} = A * Sigma_k * A' + A * P_k * B' + B * P_k' * A' + B * M_k * B' + W
        Sigma_next = A * Sigma{k} * A' + A * P{k} * B' + B * P{k}' * A' + B * M{k} * B' + W;
        Constraints = [Constraints, Sigma{k + 1} == Sigma_next];

        % Semi-definite constraint: [Sigma_k, P_k; P_k', M_k] >= 0
        LMI = [Sigma{k}, P{k}; P{k}', M{k}];
        Constraints = [Constraints, LMI >= 0];  % Ensure LMI is positive semi-definite
    end

    % Objective function: minimize sum(M_k)
    Objective = sum(cellfun(@(x) trace(x), M));

    % Define and solve the problem
    options = sdpsettings('solver', 'sedumi');  % Or use other SDP solvers
    sol = optimize(Constraints, Objective, options);

    % Check feasibility and output results
    if sol.problem == 0  % Successfully solved
        Sigma_optimal = cellfun(@(x) value(x), Sigma, 'UniformOutput', false);
        P_optimal = cellfun(@(x) value(x), P, 'UniformOutput', false);
        M_optimal = cellfun(@(x) value(x), M, 'UniformOutput', false);
        
        % Number of trajectories
        num_trajectories = 20;
        trajectories = cell(num_trajectories, 1);

        for j = 1:num_trajectories
            % Generate random initial state x_0 ~ N(0, 3I)
            x = mvnrnd(zeros(1, n), 3 * eye(n));
            trajectory = x;

            for k = 1:N
                K_k = (inv(Sigma_optimal{k}) * P_optimal{k})';  % Compute optimal gain K_k
                v_k = mvnrnd(zeros(1, n), W);  % Noise v_k ~ N(0, W)
                u_k = K_k * x';  % Control input based on the state
                x = A * x' + B * u_k + v_k';  % State update
                trajectory = [trajectory; x'];
            end
            
            trajectories{j} = trajectory;
        end

        % Plotting the trajectories in 3D
        figure('Position', [100, 100, 800, 800]);
        hold on;

        % Plot each trajectory
        for j = 1:num_trajectories
            plot3(0:N, trajectories{j}(:, 1), trajectories{j}(:, 2), 'Color', 'gray', 'LineWidth', 0.5);
        end
        
        for k = 1:10
            [x, y] = plot_ellipse(Sigma_optimal{k});
            plot3(ones(100, 1) * (k - 1), x, y, 'Alpha', 0.9);
        end
        
        xlabel('$k$', 'Interpreter', 'latex', 'FontSize', 12);
        ylabel('$(x)_1$', 'Interpreter', 'latex', 'FontSize', 12);
        zlabel('$(x)_2$', 'Interpreter', 'latex', 'FontSize', 12);
        view(68, 6);
        set(gca, 'YTick', -10:5:10);
        set(gca, 'ZTick', -10:5:10);
        set(gca, 'XTick', 0:1:10);
        ylim([-10, 10]);
        zlim([-10, 10]);
        xlim([10, 0]);
        legend('show');
        hold off;

        % Save figure
        print(gcf, sprintf('./chapter11/figures/Figure11_1%s.pdf', label), '-dpdf');
        close(gcf);
    else
        disp('The optimization problem is infeasible.');
    end
end

function [x, y] = plot_ellipse(Sigma)
    % Calculate eigenvalues and eigenvectors
    [V, D] = eig(Sigma);

    % Calculate rotation angle
    rotation_rad = atan2(V(2, 1), V(1, 1));

    % Calculate the lengths of the axes
    axes_lengths = 2 * sqrt(diag(D));

    % Generate theta values
    theta = linspace(0, 2 * pi, 100);

    % Calculate the x and y coordinates of the ellipse
    x = axes_lengths(1) * cos(theta) * cos(rotation_rad) - axes_lengths(2) * sin(theta) * sin(rotation_rad);
    y = axes_lengths(1) * cos(theta) * sin(rotation_rad) + axes_lengths(2) * sin(theta) * cos(rotation_rad);
end

function global_config()
    % Function to configure global parameters
    % You can configure it as needed
end

% Call the function
figure11_1('a');
figure11_1('b');
