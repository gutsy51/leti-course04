import pandas as pd
import numpy as np
from tqdm import tqdm

# Параметры.
T_obs = np.array([1.0, 2.0, 0.5, 1.4])
C = np.array([np.inf, 3.51, 1.78, 2.73])  # С5 = 1.92 - лишний параметр
T_dop_base = 1.28
ks = [1.0, 0.5, 1.7]
K1_fixed = 4
alpha = np.array([0.28571429, 0.28571429, 0.28571429, 0.14285714])
epsilon = 0.9
max_j = 200
max_struct_iter = 5000


def run_recurrent(K, epsilon=0.95, max_j=500):
    n = len(K)
    L_prev = np.zeros(n)
    j = 1
    T_pr_i = T_obs * (1 + L_prev / K)
    T_pr = np.sum(alpha * T_pr_i)
    Lambda_prev = j / T_pr

    for j in range(2, max_j + 1):
        T_pr_i = T_obs * (1 + L_prev / K)
        T_pr = np.sum(alpha * T_pr_i)
        Lambda_new = j / T_pr
        L_new = Lambda_new * alpha * T_pr_i
        if Lambda_prev / Lambda_new >= epsilon:
            return T_pr, j, True
        L_prev = L_new
        Lambda_prev = Lambda_new
    return T_pr, j, False

def best_gain_index(K):
    base_Tpr, _, _ = run_recurrent(K)
    best_score = -np.inf
    best_idx = None
    for i in range(1, len(K)):
        K_test = K.copy()
        K_test[i] += 1
        Tpr2, _, _ = run_recurrent(K_test)
        gain = base_Tpr - Tpr2
        score = gain / C[i]
        if score > best_score:
            best_score = score
            best_idx = i
    return best_idx

def optimize_structure(T_dop):
    K = np.array([K1_fixed, 1, 1, 1], dtype=float)
    idx = np.argmin(C[1:]) + 1
    K[idx] += 1
    for iteration in range(max_struct_iter):
        T_pr, _, saturated = run_recurrent(K)
        if saturated and T_pr <= T_dop:
            return K.astype(int), T_pr, iteration, True
        idx = best_gain_index(K)
        K[idx] += 1
    T_pr, _, saturated = run_recurrent(K)
    return K.astype(int), T_pr, max_struct_iter, False

results = []
for k in tqdm(ks, desc="k sweep"):
    T_dop = k * T_dop_base
    K_opt, Tpr_res, iters, ok = optimize_structure(T_dop)
    results.append({
        'k': k,
        'kT доп': T_dop,
        'T пр': float(Tpr_res),
        'Структура': K_opt.tolist(),
        'Опт.?': ok,
        'Итераций': iters
    })

df = pd.DataFrame(results)
print(df)
