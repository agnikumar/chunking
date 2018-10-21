% analyze behavioral data from chunking experiment

[data, Ts] = load_data;

sem = @(x) std(x) / sqrt(length(x));

s = [];
g = [];
len = [];
group = [];
dir = []; % direction = 2nd state on path
ord = []; % ordinal of trial type within phase (e.g. "first 1->6", "second 1->6", etc)
subj_group = [];
s_id = [];
for subj = 1:size(data,1)
    phase = 2;
    for i = 1:length(data(subj, phase).s)
        which = find(data(subj, phase).s == data(subj, phase).s(i) & data(subj, phase).g == data(subj, phase).g(i));
        clear o;
        o(which) = find(which);
        ord = [ord; o(i)];
        s = [s; data(subj, phase).s(i)];
        g = [g; data(subj, phase).g(i)];
        len = [len; data(subj, phase).len(i)];
        dir = [dir; data(subj, phase).path{i}(2)];
        group = [group; data(subj, phase).group(i)];
        s_id = [s_id; subj];
    end
    subj_group = [subj_group; data(subj,1).group(1)];
end


% show learning
%

figure;
ms = [];
es = [];
for t = 1:length(data(1,1).len)
    l = [];
    for subj = 1:size(data,1)
        l = [l data(subj,1).len(t)];
    end
    m = mean(l);
    e = std(l) / sqrt(length(l));
    ms = [ms m];
    es = [es e];
end

errorbar(ms, es);
xlabel('training trial');
ylabel('path length');

% show test choices
%

start = [6 7 1 2];
goal = [1 2 6 7];
nexts = [
5 7;
6 8;
2 10;
1 3
];

figure;

for t = 1:length(start)
    which = s == start(t) & ord == 1;
    move = dir(which);
    m = nexts(t,:);
    c1 = sum(move == m(1)); % count 1
    c2 = sum(move == m(2)); % count 2
    d = abs(c1 - c2);
    n = sum(which);
    p = 2 * binopdf((n - d) / 2, n, 0.5);

    subplot(2,2,t);
    bar(1:2, [c1 c2]);
    xticklabels({num2str(m(1)), num2str(m(2))});
    title(sprintf('%d -> %d: p = %.3f (d = %d, n = %d)', start(t), goal(t), p, d, n));
    %ylim([4 5]);

    if t == 1
        ylabel('state chunking')
    elseif t == 3
        ylabel('action chunking / S-A')
    end
end


