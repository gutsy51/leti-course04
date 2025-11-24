import numpy as np
import matplotlib.pyplot as plt
import pandas as pd

# Исходные данные (вариант 1).
x_vals = np.array([-73.4, -70.7, -51.5, -43.9, 13.3, 73.0, 73.8])
p_vals = np.array([0.241, 0.023, 0.166, 0.078, 0.272, 0.192, 0.028])

# Теоретические M и D по формулам.
theoretical_M = np.sum(p_vals * x_vals)
theoretical_D = np.sum(p_vals * x_vals**2) - theoretical_M**2

# Функция генерации ДСВ на основе кумулятивных правых границ.
def generate_discrete_sample(x, p, n=500, seed=42):
    rng = np.random.default_rng(seed)
    cum = np.cumsum(p)
    u = rng.random(n)
    indices = np.searchsorted(cum, u, side='right')
    return x[indices]

# Генерация выборки n=500.
n = 500
sample = generate_discrete_sample(x_vals, p_vals, n=n, seed=42)

# Первые 30 значений.
first_30 = sample[:30]

# Эмпирические оценки M и D.
empirical_M = sample.mean()
empirical_D = (sample**2).mean() - empirical_M**2

# Эмпирические вероятности для каждого значения x_j.
empirical_counts = np.array([np.count_nonzero(sample == xv) for xv in x_vals])
empirical_probs = empirical_counts / n

print('=== Первые 30 значений выборки x_i ===\n')
print(np.array2string(first_30, precision=3, separator=', '))

print('\n=== Теоретические значения ===')
print(f'M_th = {theoretical_M:.6f}')
print(f'D_th = {theoretical_D:.6f}')

print('\n=== Эмпирические оценки (по выборке n={}) ==='.format(n))
print(f'M_emp = {empirical_M:.6f}')
print(f'D_emp = {empirical_D:.6f}')

print('\n=== Теоретические вероятности p_j ===')
for x, p in zip(x_vals, p_vals):
    print(f'x={x:6.2f}  p={p:.3f}')

print('\n=== Эмпирические вероятности (частоты) ===')
for x, pc in zip(x_vals, empirical_probs):
    print(f'x={x:6.2f}  p_emp={pc:.3f}')

# Гистограммы.
indices = np.arange(len(x_vals))
width = 0.35
plt.figure(figsize=(10,6))
plt.bar(indices - width/2, empirical_probs, width, label='Эмпирические')
plt.bar(indices + width/2, p_vals, width, label='Теоретические')
plt.xticks(indices, [f'{x:.1f}' for x in x_vals], rotation=45)
plt.xlabel('Значения x_j')
plt.ylabel('Вероятность')
plt.legend()
plt.tight_layout()
plt.show()

df = pd.DataFrame({
    'x_j': x_vals,
    'p_theoretical': p_vals,
    'count': empirical_counts,
    'p_empirical': empirical_probs
})
print('\n', df)
