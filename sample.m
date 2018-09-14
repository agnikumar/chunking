function [samples] = sample(D, h)
    %
    % TODO write out generative model

    nsamples = 100;
    burnin = 100;
    lag = 10;

    H = init_H(D, h);

    % Metropolis-Hastings-within-Gibbs sampling
    % Roberts & Rosenthal (2009)
    for n = 1:nsamples * lag + burnin
        for i = 1:D.G.N
            logpost = @(c_i) logpost_c_i(c_i, i, H, D, h);
            proprnd = @(c_i_old) proprnd_c_i(c_i_old, i, H, D, h);
            logprop = @(c_i_new, c_i_old) logprop_c_i(c_i_new, c_i_old, i, H, D, h);

            [c_i, accept] = mhsample(H.c(i), 1, 'logpdf', logpost, 'proprnd', proprnd, 'logproppdf', logprop);
            H = update_c_i(c_i, i, H);
        end

        logpost = @(p) logpost_p(p, H, D, h);
        proprnd = @(p_old) proprnd_p(p_old, H, D, h);
        logprop = @(p_new, p_old) logprop_p(p_new, p_old, H, D, h);

        [p, accept] = mhsample(H.p, 1, 'logpdf', logpost, 'proprnd', proprnd, 'logproppdf', logprop); % TODO adaptive
        H.p = p;

        [q, accept] = mhsample(H.q, 1, 'logpdf', logpost, 'proprnd', proprnd, 'logproppdf', logprop);
        H.q = q;

        [hp, accept] = mhsample(H.hp, 1, 'logpdf', logpost, 'proprnd', proprnd, 'logproppdf', logprop);
        H.hp = hp;

        [tp, accept] = mhsample(H.tp, 1, 'logpdf', logpost, 'proprnd', proprnd, 'logproppdf', logprop);
        H.tp = tp;

        for k = 1:H.N
            for l = 1:k-1
                logpost = @(e) logpost_E_k_l(e, k, l, H, D, h);
                proprnd = @(e_old) proprnd_E_k_l(e_old, k, l, H, D, h);
                logprop = @(e_new, e_old) logprop_E_k_l(e_new, e_old, k, l, H, D, h);

                [e, accept] = mhsample(H.E(k,l), 1, 'logpdf', logpost, 'proprnd', proprnd, 'logproppdf', logprop);  % TODO adaptive
                H.E(k,l) = e;
                H.E(l,k) = e;
            end
        end

        % TODO bridges

        samples(n) = H;
    end

    %samples = samples(burnin:lag:end);
end



% P(H|D) up to proportionality constant
%
function logp = logpost(H, D, h)
    logp = loglik(H, D, h) + logprior(H, D, h);
end

% Update H.c(i) and counts
% TODO makes copy of H -- super slow...
%
function H = update_c_i(c_i, i, H)
    H.cnt(H.c(i)) = H.cnt(H.c(i)) - 1;
    H.c(i) = c_i;
    if c_i <= length(H.cnt)
        H.cnt(H.c(i)) = H.cnt(H.c(i)) + 1;
    else
        H.cnt = [H.cnt 1];
    end
end


% P(H|D) for updates of c_i
% i.e. with new c's up to c_i, the candidate c_i, then old c's after (and old rest of H)
%
function logp = logpost_c_i(c_i, i, H, D, h)
    H = update_c_i(c_i, i, H);
    logp = logpost(H, D, h);
end

% proposal PMF for c_i
% inspired by Algorithm 5 from Neal 1998: MCMC for DP mixtures
%
function P = propP_c_i(c_i_old, i, H, D, h)
    cnt = H.cnt;
    cnt(H.c(i)) = cnt(H.c(i)) - 1;
    z = find(cnt == 0); % reuse empty bins TODO is this legit?
    if isempty(z)
        cnt = [cnt h.alpha];
    else
        cnt(z) = h.alpha;
    end
    P = cnt / sum(cnt);
end

% propose c_i
%
function c_i_new = proprnd_c_i(c_i_old, i, H, D, h)
    P = propP_c_i(c_i_old, i, H, D, h);
    c_i_new = find(mnrnd(1, P));

    % TODO bridges
end

function [logP, P] = logprop_c_i(c_i_new, c_i_old, i, H, D, h) % TODO merge w/ proprnd
    P = propP_c_i(c_i_old, i, H, D, h);
    logP = log(P(c_i_new));
end


% P(H|D) for updates of p
%
function logp = logpost_p(p, H, D, h)
    H.p = p;
    logp = logpost(H, D, h);
end

% proposals for p; random walk 
%
function p_new = proprnd_p(p_old, H, D, h)
    while true % TODO can use universality of uniform inverse CDF thingy
        p_new = normrnd(p_old, 0.1); % TODO const TODO adaptive
        if p_new <= 1 && p_new >= 0
            break; % keep params within bounds
        end
    end
end

% account for truncating that keeps params within bounds 
%
function logp = logprop_p(p_new, p_old, H, D, h)
    Z = normcdf(1, p_old, 0.1) - normcdf(0, p_old, 0.1); % TODO consts TODO adaptive
    logp = log(normpdf(p_new, p_old, 1)) - log(Z);
end


% P(H|D) for updates of E
%
function logp = logpost_E_k_l(e, k, l, H, D, h)
    H.E(k,l) = e;
    H.E(l,k) = e;
    logp = logpost(H, D, h);
end

% proposal PMF for E
% keep the same, or draw from prior w/ some small prob
%
function P = propP_E_k_l(e_old, k, l, H, D, h)
    P = [1 - H.hp, H.hp] * 0.3; % draw from prior w/ some small prob
    P(e_old + 1) = P(e_old + 1) + 0.7; % or keep the same TODO consts
end

% proposal for E
%
function e_new = proprnd_E_k_l(e_old, k, l, H, D, h)
    P = propP_E_k_l(e_old, k, l, H, D, h);
    e_new = find(mnrnd(1, P)) - 1;
end

function logp = logprop_E_k_l(e_new, e_old, k, l, H, D, h) % TODO merge w/ proprnd
    P = propP_E_k_l(e_old, k, l, H, D, h);
    logp = log(P(e_new + 1));
end