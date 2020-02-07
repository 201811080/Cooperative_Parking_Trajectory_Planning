%  MATLAB Source Codes for the book "Cooperative Decision and Planning for
%  Connected and Automated Vehicles" published by Mechanical Industry Press
%  in 2020.
% ��������������Эͬ������滮�������鼮���״���
%  Copyright (C) 2020 Bai Li
%  2020.02.07
% ==============================================================================
%  ������.���ٷǽṹ�������еĶ೵Эͬ������滮����
% ==============================================================================
%  ��ע��
%  //TODO ����MA57ż���ᵼ��IPOPT��������һ����ֵ�ý�һ���Ų�.
%  1. ���ڳ�ʼ���������ߣ�����Эͬ�켣�滮����ʧ�ܣ���һ������о������λһ��Ŭ��.
%  2. ����޸�Nobs��Nv����������.mod�ļ���һ���ֶ�����.
%  3. ���ڸò��ִ�����о��ɹ������������²ο����ף�
%  a) Li, B., Shao, Z., Zhang, Y.M., & Li, P. (2017). Nonlinear programming
%  for multi-vehicle motion planning with Homotopy initialization
%  strategies. 13th IEEE Conference on Automation Science and Engineering,
%  118�C123.
%  b) Li, B., Zhang, Y.M., Shao, Z., & Jia, N. (2017). Simultaneous versus
%  joint computing: a case study of multi-vehicle parking motion planning.
%  Journal of Computational Science, 20, 30�C40.
%  c) B. Li, Y. Zhang, T. Acarman, Q. Kong, and Y. Zhang, ��Trajectory
%  planning for a tractor with multiple trailers in extremely narrow
%  environments: A unified approach��, In Proc. 2019 IEEE International
%  Conference on Robotics and Automation (ICRA), pp. 8557�C8562, 2019.
% ==============================================================================
clear all; close all; clc;

% % ��������
global vehicle_geometrics_ % �����������γߴ磨Ϊ�������㣬�������Ҽ������г�����ʽ��ͬ��
vehicle_geometrics_.vehicle_wheelbase = 2.8;
vehicle_geometrics_.vehicle_front_hang = 0.96;
vehicle_geometrics_.vehicle_rear_hang = 0.929;
vehicle_geometrics_.vehicle_width = 1.942;
vehicle_geometrics_.vehicle_length = vehicle_geometrics_.vehicle_wheelbase + vehicle_geometrics_.vehicle_front_hang + vehicle_geometrics_.vehicle_rear_hang;
vehicle_geometrics_.radius = hypot(0.25 * vehicle_geometrics_.vehicle_length, 0.5 * vehicle_geometrics_.vehicle_width);
vehicle_geometrics_.r2x = 0.25 * vehicle_geometrics_.vehicle_length - vehicle_geometrics_.vehicle_rear_hang;
vehicle_geometrics_.f2x = 0.75 * vehicle_geometrics_.vehicle_length - vehicle_geometrics_.vehicle_rear_hang;
global vehicle_kinematics_ % �����˶�����������Ϊ�������㣬�������Ҽ������г�����ʽ��ͬ��
vehicle_kinematics_.vehicle_v_max = 2.5;
vehicle_kinematics_.vehicle_a_max = 0.5;
vehicle_kinematics_.vehicle_phy_max = 0.7;
vehicle_kinematics_.vehicle_w_max = 0.5;
vehicle_kinematics_.vehicle_kappa_max = tan(vehicle_kinematics_.vehicle_phy_max) / vehicle_geometrics_.vehicle_wheelbase;
vehicle_kinematics_.vehicle_turning_radius_min = 1 / vehicle_kinematics_.vehicle_kappa_max;
global environment_scale_ xyt_graph_search_ % �������ڻ�����Χ
environment_scale_.environment_x_min = -20;
environment_scale_.environment_x_max = 20;
environment_scale_.environment_y_min = -20;
environment_scale_.environment_y_max = 20;
environment_scale_.x_scale = environment_scale_.environment_x_max - environment_scale_.environment_x_min;
environment_scale_.y_scale = environment_scale_.environment_y_max - environment_scale_.environment_y_min;
xyt_graph_search_.max_t = 40;
xyt_graph_search_.num_nodes_t = 200;
xyt_graph_search_.resolution_t = xyt_graph_search_.max_t / (xyt_graph_search_.num_nodes_t - 1);
xyt_graph_search_.num_nodes_x = 150;
xyt_graph_search_.num_nodes_y = 150;
xyt_graph_search_.resolution_x = environment_scale_.x_scale / (xyt_graph_search_.num_nodes_x - 1);
xyt_graph_search_.resolution_y = environment_scale_.y_scale / (xyt_graph_search_.num_nodes_y - 1);

% % ���������ֵ�Լ������ϰ���
global vehicle_TPBV_ obstacles_
Nv = 5; Nobs = 1;
[vehicle_TPBV_, obstacles_] = GenerateTask(Nv, Nobs);

% % ����X-Y-Tͼ������A���㷨�漰�Ĳ���
xyt_graph_search_.multiplier_H_for_A_star = 2.0;
xyt_graph_search_.weight_for_time = 2.0;
xyt_graph_search_.max_iter = 3000;

% % ȷ�������ߵ�Nrank��˳��
Nrank = 10;
single_fitness = zeros(1,Nv);
global original_obstacle_layers
original_obstacle_layers = GenerateOriginalObstacleLayers();
backup_original_obstacle_layers_ = original_obstacle_layers;
tic
for ii = 1 : Nv
    [~, ~, ~, single_fitness(ii)] = SearchTrajectoryInXYTGraph(vehicle_TPBV_{1,ii});
end
toc
ranklist = zeros(Nrank, Nv);
[~, ranklist(1,:)] = sort(single_fitness);
[~, ranklist(2,:)] = sort(single_fitness,'descend');
for ii = 3 : Nrank
    ranklist(ii,:) = randperm(Nv);
end
tic
% ��Nrank��˳����ѡ��һ��
sequence_cost = zeros(1,Nrank);
for ranking_attempt = 1 : Nrank
    original_obstacle_layers = backup_original_obstacle_layers_;
    for ii = 1 : Nv
        iv = ranklist(ranking_attempt,ii);
        [x, y, theta, cost] = SearchTrajectoryInXYTGraph(vehicle_TPBV_{1,iv});
        UpdateObstacleLayers(x, y, theta);
        sequence_cost(ranking_attempt) = sequence_cost(ranking_attempt) + cost;
    end
end
toc
[~,ranking_attempts] = sort(sequence_cost);
selected_rank = ranklist(ranking_attempts(1),:);

% NLP�����ʼ�⹹��
global Opti_
Opti_.Nfe = 100;
decision_x = zeros(Nv, Opti_.Nfe);
decision_y = zeros(Nv, Opti_.Nfe);
decision_theta = zeros(Nv, Opti_.Nfe);
original_obstacle_layers = backup_original_obstacle_layers_;
cost_all = 0;
for ind = 1 : Nv
    iv = selected_rank(ind);
    [x, y, theta, cost] = SearchTrajectoryInXYTGraph(vehicle_TPBV_{1,iv});
    cost_all = cost_all + cost;
    UpdateObstacleLayers(x, y, theta);
    decision_x(iv,1 : Opti_.Nfe) = ResampleProfile(x, Opti_.Nfe);
    decision_y(iv,1 : Opti_.Nfe) = ResampleProfile(y, Opti_.Nfe);
    decision_theta(iv,1 : Opti_.Nfe) = ResampleProfile(theta, Opti_.Nfe);
end
[x, y, theta, v, a, phy, w, xf, yf, xr, yr] = FormInitialGuess2(decision_x, decision_y, decision_theta);
WriteInitialGuessForNLP2(x, y, theta, v, a, phy, w, xf, yf, xr, yr);
original_obstacle_layers = backup_original_obstacle_layers_;
WriteObstacleSetupsForNLP2();
WriteBoundaryValues2();

!ampl rr.run
load opti_flag.txt
if (opti_flag)
    DemonstrateDynamicProcess();
end